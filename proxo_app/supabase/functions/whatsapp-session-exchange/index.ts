/**
 * whatsapp-session-exchange Edge Function
 *
 * Exchanges a verified WhatsApp OTP for a session on an EXISTING account.
 * Deploy: supabase functions deploy whatsapp-session-exchange --no-verify-jwt
 *
 *   POST { phone: "+9647xxxxxxxxx", code: "123456" }
 *     200 { ok: true,  access_token, refresh_token, expires_at, user_id }
 *     401 { ok: false, error: "invalid_code" }
 *     404 { ok: false, error: "user_not_found" }
 *     403 { ok: false, error: "banned", reason }
 *     400 { ok: false, error: "bad_request" }
 *
 * ── This function NEVER creates accounts ────────────────────────────────────
 *
 * Phone login is a lookup mechanism, not a signup path. If no `profiles` row
 * matches the verified phone, it returns 404 and stops. It does not call
 * `admin.createUser`, and it does not write to `profiles`.
 *
 * The client also pre-checks with `pa_phone_exists` before sending the OTP, to
 * avoid paying for a WhatsApp message that could never be redeemed. That check
 * is a cost optimisation and NOT a security control — it runs on the client
 * and can be skipped by anyone calling this endpoint directly. The 404 below
 * is the control. Both must exist.
 *
 * ── Why this function verifies the code itself ──────────────────────────────
 *
 * A function that takes a phone number and returns a session must prove the
 * caller owns that number, or it is an open door: anyone could POST any number
 * and be logged in as that user. So verification and session issuance are ONE
 * call and the client never sits between them.
 *
 * It also has to be one call for a mechanical reason: `verify_otp_whatsapp`
 * sets `is_used = true` on the matching row, so a code verifies exactly once.
 * A client that called the n8n verify webhook first would find the code
 * already spent by the time it reached this function.
 *
 * ⚠ `verify_otp_whatsapp` returns `success: true` for a WRONG code — it means
 * "the function ran", not "the code matched". The only correct check is
 * `data.verified === true`. Do not loosen this.
 *
 * ── How the tokens are produced ─────────────────────────────────────────────
 *
 * Supabase has no admin API for "create a session for user X", so this is a
 * two-step redemption done entirely server-side:
 *
 *   1. `admin.generateLink({ type: 'magiclink' })` → a single-use hashed_token
 *   2. an anon client redeems that token with `verifyOtp(...)` → a real
 *      session with access_token AND refresh_token
 *
 * Redeeming here rather than on the client is what lets us hand back a genuine
 * refresh token, which is what `setSession` needs. Two alternatives were
 * rejected:
 *
 *   • Rotating the user's password and calling signInWithPassword.
 *     Proxo accounts sign in with email + password. Overwriting the password
 *     on every phone login would silently break email login for anyone who
 *     uses both.
 *
 *   • Hand-signing a JWT with the project secret.
 *     Produces an access token but no valid refresh token — those live in
 *     auth.refresh_tokens. The user would be signed out at the first refresh,
 *     roughly an hour later, with no obvious cause.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

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

  const url = Deno.env.get("SUPABASE_URL")!;
  const admin = createClient(
    url,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { autoRefreshToken: false, persistSession: false } },
  );

  try {
    const body = await req.json().catch(() => ({}));
    const phone = normalisePhone(String(body?.phone ?? ""));
    const code = String(body?.code ?? "").trim();

    if (!phone || !/^\d{6}$/.test(code)) {
      return json({ ok: false, error: "bad_request" }, 400);
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
    if (verifyRes?.data?.verified !== true) {
      return json({ ok: false, error: "invalid_code" }, 401);
    }

    // ── 2. Resolve the EXISTING user ────────────────────────────────────────
    const { data: profile, error: profileErr } = await admin
      .from("profiles")
      .select("id, email, is_banned, ban_reason")
      .eq("phone", phone)
      .maybeSingle();

    if (profileErr) {
      console.error("profile lookup failed", profileErr);
      return json({ ok: false, error: "lookup_failed" }, 500);
    }

    // No account for this number. Stop here — do not provision.
    if (!profile) {
      return json({ ok: false, error: "user_not_found" }, 404);
    }

    // ⚠ A verified phone must not bypass a ban. The email path enforces this
    // elsewhere; without this check, phone login would be the way around it.
    if (profile.is_banned === true) {
      return json(
        { ok: false, error: "banned", reason: profile.ban_reason ?? null },
        403,
      );
    }

    const userId = profile.id as string;

    // The auth record is the source of truth for the address — `profiles.email`
    // can be stale or empty, and generateLink needs the real one.
    const { data: authUser, error: authErr } =
      await admin.auth.admin.getUserById(userId);
    if (authErr) {
      console.error("getUserById failed", authErr);
      return json({ ok: false, error: "lookup_failed" }, 500);
    }

    const email = authUser?.user?.email ?? "";
    if (!email) {
      // A profile that matches by phone but whose auth user has no email
      // cannot be issued a magic link. This is a data problem, not a wrong
      // code, so it gets its own error rather than a misleading 401/404.
      console.error("user has no email, cannot mint session", userId);
      return json({ ok: false, error: "no_email_on_account" }, 409);
    }

    // Audit trail: link the consumed OTP row to the user it authenticated.
    // Best-effort — a bookkeeping write must not fail a login.
    const { error: backfillErr } = await admin
      .from("otp_whatsapp")
      .update({ user_id: userId })
      .eq("phone", phone)
      .is("user_id", null);
    if (backfillErr) console.error("otp user_id backfill", backfillErr);

    // ── 3. Mint the session ─────────────────────────────────────────────────
    const { data: link, error: linkErr } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email,
    });

    const tokenHash = link?.properties?.hashed_token;
    if (linkErr || !tokenHash) {
      console.error("generateLink failed", linkErr);
      return json({ ok: false, error: "session_failed" }, 500);
    }

    // Redeem server-side with an anon client. This is the step that turns the
    // single-use hash into an access_token + refresh_token pair.
    //
    // ⚠ Anon key, not service_role: `verifyOtp` is a normal auth call and the
    // service-role client has `persistSession: false` plus elevated claims that
    // would not produce a user session.
    const anon = createClient(url, Deno.env.get("SUPABASE_ANON_KEY")!, {
      auth: { autoRefreshToken: false, persistSession: false },
    });

    const { data: sess, error: sessErr } = await anon.auth.verifyOtp({
      type: "magiclink",
      token_hash: tokenHash,
    });

    const session = sess?.session;
    if (sessErr || !session?.refresh_token) {
      console.error("verifyOtp redemption failed", sessErr);
      return json({ ok: false, error: "session_failed" }, 500);
    }

    return json({
      ok: true,
      access_token: session.access_token,
      refresh_token: session.refresh_token,
      expires_at: session.expires_at ?? null,
      user_id: userId,
    });
  } catch (e) {
    console.error("unhandled", e);
    return json({ ok: false, error: "server_error" }, 500);
  }
});
