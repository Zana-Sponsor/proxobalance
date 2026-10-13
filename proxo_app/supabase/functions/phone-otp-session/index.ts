/**
 * phone-otp-session Edge Function
 *
 * Turns a verified WhatsApp OTP into a real Supabase session.
 * Deploy: supabase functions deploy phone-otp-session --no-verify-jwt
 *
 *   POST { phone, code, full_name, password }
 *     200 { ok: true,  token_hash, email, is_new }
 *     401 { ok: false, error: "invalid_code" }
 *     403 { ok: false, error: "banned", reason }
 *     400 { ok: false, error: "bad_request" }
 *
 * ── Why this function verifies the code itself ──────────────────────────────
 *
 * It would be simpler for the client to call the n8n verify webhook and then
 * call this function with just a phone number. That design is broken: this
 * function mints a session, so "give me a session for +964…" with no proof
 * would be an open door — anyone could POST any phone number and be logged in
 * as that user.
 *
 * So verification and session issuance are ONE call. The client never gets to
 * stand between them.
 *
 * This also fixes a second problem. `verify_otp_whatsapp` sets `is_used =
 * true` on the matching row, so a code can only be verified once. If the
 * client called the n8n webhook first and this function second, the second
 * call would always fail with "code already used".
 *
 * ⚠ `verify_otp_whatsapp` returns `success: true` for a WRONG code — it means
 * "the function ran", not "the code matched". The only correct check is
 * `data.verified === true`. Do not loosen this.
 *
 * ── How the session is minted ───────────────────────────────────────────────
 *
 * Supabase has no admin API for "create a session for user X". The supported
 * path is `admin.generateLink({ type: 'magiclink' })`, which returns a
 * `hashed_token` the client redeems with `verifyOTP(tokenHash:, type:
 * magiclink)` to get real access + refresh tokens.
 *
 * `generateLink` is email-only, which is why phone-provisioned users get a
 * synthetic address (see PHONE_EMAIL_DOMAIN). Two alternatives were rejected:
 *
 *   • Rotating the user's password and calling signInWithPassword.
 *     Proxo accounts sign in with email + password. Overwriting the password
 *     on every phone login would silently break email login for anyone who
 *     uses both.
 *
 *   • Hand-signing a JWT with the project secret.
 *     Produces an access token but no valid refresh token — refresh tokens
 *     live in auth.refresh_tokens. The user would be signed out at the first
 *     refresh, roughly an hour later, with no obvious cause.
 *
 * The token_hash is single-use and short-lived, so returning it to the client
 * is safe; it is not a session on its own.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

/**
 * Domain for users who sign up by phone and have no real email.
 *
 * ⚠ Use a domain you control and that can never receive mail. A real domain
 * would mean magic-link emails are deliverable to someone else's inbox.
 */
const PHONE_EMAIL_DOMAIN = "phone.proxopages.com";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

/** Normalises to E.164 for Iraq. Must match the client's `_phoneE164`. */
function normalisePhone(raw: string): string | null {
  let d = (raw ?? "").replace(/[^0-9]/g, "");
  while (d.startsWith("0")) d = d.slice(1);
  if (d.startsWith("964")) d = d.slice(3);
  if (d.length !== 10 || !d.startsWith("7")) return null;
  return `+964${d}`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return json({ ok: false, error: "method_not_allowed" }, 405);
  }

  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  try {
    const body = await req.json().catch(() => ({}));
    const phone = normalisePhone(String(body?.phone ?? ""));
    const code = String(body?.code ?? "").trim();
    const fullName = String(body?.full_name ?? "").trim();
    const password = String(body?.password ?? "");

    const strongPassword = password.length >= 8 &&
      /[A-Z]/.test(password) && /[0-9]/.test(password) &&
      /[@#$%&!?*^~]/.test(password);

    if (!phone || !/^\d{6}$/.test(code) || fullName.length < 3) {
      return json({ ok: false, error: "bad_request" }, 400);
    }
    if (!strongPassword) {
      return json({ ok: false, error: "weak_password" }, 400);
    }

    // ── 1. Verify the OTP ───────────────────────────────────────────────────
    // Consumes the code (is_used = true) when it matches.
    const { data: verifyRes, error: verifyErr } = await admin.rpc(
      "verify_otp_whatsapp",
      { p_phone: phone, p_code: code },
    );
    if (verifyErr) {
      console.error("verify_otp_whatsapp failed", verifyErr);
      return json({ ok: false, error: "verify_failed" }, 500);
    }

    // ⚠ `data.verified`, never `success`. See the header note.
    const verified = verifyRes?.data?.verified === true;
    if (!verified) return json({ ok: false, error: "invalid_code" }, 401);

    // ── 2. Resolve the user ─────────────────────────────────────────────────
    const { data: profile, error: profileErr } = await admin
      .from("profiles")
      .select("id, email, is_banned, ban_reason")
      .eq("phone", phone)
      .maybeSingle();

    if (profileErr) {
      console.error("profile lookup failed", profileErr);
      return json({ ok: false, error: "lookup_failed" }, 500);
    }

    let userId: string;
    let email: string;
    if (profile) {
      return json({ ok: false, error: "already_registered" }, 409);
    }

    // ── 3. Provision only after the OTP has been consumed successfully ─────
    email = `${phone.replace("+", "")}@${PHONE_EMAIL_DOMAIN}`;

    const { data: created, error: createErr } =
      await admin.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        phone,
        phone_confirm: true,
        user_metadata: {
          signup_channel: "whatsapp",
          phone,
          full_name: fullName,
        },
      });

    if (createErr || !created?.user) {
      console.error("createUser failed", createErr);
      const detail = String(createErr?.message ?? "").toLowerCase();
      if (detail.includes("already") || detail.includes("unique")) {
        return json({ ok: false, error: "already_registered" }, 409);
      }
      return json({ ok: false, error: "provision_failed" }, 500);
    }
    userId = created.user.id;

    // The project may already create a profile row via an on-signup trigger,
    // so this upserts rather than inserts. A phone-only account intentionally
    // has no public/profile email; the synthetic address stays Auth-internal.
    const { error: upsertErr } = await admin
      .from("profiles")
      .upsert(
        { id: userId, phone, email: null, full_name: fullName },
        { onConflict: "id" },
      );

    if (upsertErr) {
      console.error("profile upsert failed, rolling back", upsertErr);
      await admin.auth.admin.deleteUser(userId).catch(() => {});
      return json({ ok: false, error: "provision_failed" }, 500);
    }

    // Link the consumed OTP row to the user for the audit trail. Best-effort:
    // the session must not fail because a bookkeeping write did.
    const { error: linkErr2 } = await admin
      .from("otp_whatsapp")
      .update({ user_id: userId })
      .eq("phone", phone)
      .is("user_id", null);
    if (linkErr2) console.error("otp user_id backfill failed", linkErr2);

    // ── 4. Mint the session ─────────────────────────────────────────────────
    const { data: link, error: linkErr } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email,
    });

    const tokenHash = link?.properties?.hashed_token;
    if (linkErr || !tokenHash) {
      console.error("generateLink failed", linkErr);
      return json({ ok: false, error: "session_failed" }, 500);
    }

    return json({ ok: true, token_hash: tokenHash, email, is_new: true });
  } catch (e) {
    console.error("unhandled", e);
    return json({ ok: false, error: "server_error" }, 500);
  }
});
