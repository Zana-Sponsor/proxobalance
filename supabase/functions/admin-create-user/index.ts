import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// User creation remains server-side and is gated by a single-use n8n email OTP.
// Platform JWT verification stays off for CORS preflight; this function verifies
// the caller's Supabase session and super-admin role itself on every operation.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const OTP_WEBHOOK = Deno.env.get("N8N_OTP_WEBHOOK") || "https://email.proxopages.com/webhook/otp_exchange";
const OTP_PURPOSE = "signup";

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Max-Age": "86400",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
  });
}

function validEmail(value: string) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) && value.length <= 320;
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: CORS_HEADERS });
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!SUPABASE_URL || !ANON_KEY || !SERVICE_ROLE_KEY) return json({ error: "missing_env" }, 500);

  const match = (req.headers.get("Authorization") || "").match(/^Bearer\s+(.+)$/i);
  const jwt = match?.[1]?.trim() || "";
  if (!jwt) return json({ error: "missing_authorization" }, 401);

  let body: {
    action?: string; email?: string; password?: string; full_name?: string;
    phone?: string; is_admin?: boolean; otp_code?: string;
  };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json_body" }, 400);
  }

  const action = body.action;
  if (action !== "request_otp" && action !== "create") return json({ error: "action_required" }, 400);
  const email = String(body.email || "").trim().toLowerCase();
  if (!validEmail(email)) return json({ error: "invalid_email", message: "ئیمەیلی دروست بنووسە" }, 400);

  const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userErr } = await callerClient.auth.getUser();
  if (userErr || !userData?.user) return json({ error: "invalid_session" }, 401);
  const callerId = userData.user.id;

  const { data: callerProfile, error: profErr } = await callerClient
    .from("ex_profiles")
    .select("is_admin,is_banned,role")
    .eq("id", callerId)
    .maybeSingle();
  if (profErr || !callerProfile?.is_admin || callerProfile.is_banned || callerProfile.role !== "super_admin") {
    console.warn("admin_create_user_forbidden", { stage: "admin_check" });
    return json({ error: "forbidden", message: "تەنها سوپەر ئادمین مافی زیادکردنی هەژمار هەیە" }, 403);
  }

  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  if (action === "request_otp") {
    const { data: liveUntil, error: expiryErr } = await adminClient.rpc(
      "ex_auth_email_code_expiry",
      { p_email: email, p_purpose: OTP_PURPOSE },
    );
    if (expiryErr) {
      console.error("admin_create_user_otp_expiry_lookup_failed");
      return json({ error: "otp_service_unavailable" }, 503);
    }
    if (liveUntil) return json({ success: true, already_sent: true, expires_at: liveUntil });

    let response: Response;
    try {
      response = await fetch(OTP_WEBHOOK, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action: "request_otp", email, purpose: OTP_PURPOSE }),
        signal: AbortSignal.timeout(15000),
      });
    } catch {
      console.warn("admin_create_user_otp_delivery_failed", { stage: "n8n_request" });
      return json({ error: "otp_delivery_failed", message: "هەڵەی ناردنی کۆد" }, 502);
    }
    const result = await response.json().catch(() => ({}));
    if (/CODE_STILL_VALID/.test(String(result?.message || ""))) {
      const { data: expiry } = await adminClient.rpc("ex_auth_email_code_expiry", {
        p_email: email, p_purpose: OTP_PURPOSE,
      });
      return json({ success: true, already_sent: true, expires_at: expiry || null });
    }
    if (!response.ok || result?.success === false) {
      const tooMany = /TOO_MANY_CODES|rate.?limit/i.test(String(result?.message || ""));
      console.warn("admin_create_user_otp_delivery_failed", { stage: "n8n_response", status: response.status });
      return json({ error: tooMany ? "otp_rate_limited" : "otp_delivery_failed", message: tooMany ? "کۆدی زۆر داواکراوە؛ دواتر هەوڵ بدەوە" : "هەڵەی ناردنی کۆد" }, tooMany ? 429 : 502);
    }
    const { data: expiresAt } = await adminClient.rpc("ex_auth_email_code_expiry", {
      p_email: email, p_purpose: OTP_PURPOSE,
    });
    return json({ success: true, expires_at: expiresAt || null });
  }

  const password = String(body.password || "");
  const otpCode = String(body.otp_code || "").trim();
  const fullName = String(body.full_name || "").trim().replace(/\s+/g, " ");
  const phone = String(body.phone || "").trim();
  const makeAdmin = body.is_admin === true;
  if (password.length < 8 || password.length > 72) {
    return json({ error: "password_invalid", message: "وشەی نهێنی لانیکەم ٨ پیت بێت" }, 400);
  }
  if (!/^\d{6}$/.test(otpCode)) return json({ error: "otp_required", message: "کۆدی ٦ ژمارەیی بنووسە" }, 400);
  if (fullName.length < 3 || fullName.length > 80) return json({ error: "name_invalid" }, 400);

  // This service-role-only RPC validates the exact email + signup purpose,
  // locks the OTP row, increments failures and consumes the code atomically.
  const { data: otpValid, error: otpErr } = await adminClient.rpc("ex_verify_otp", {
    p_email: email,
    p_code: otpCode,
    p_purpose: OTP_PURPOSE,
  });
  if (otpErr) {
    console.error("admin_create_user_otp_verification_unavailable");
    return json({ error: "otp_service_unavailable" }, 503);
  }
  if (otpValid !== true) {
    console.warn("admin_create_user_otp_rejected", { stage: "otp_verification" });
    return json({ error: "invalid_otp", message: "کۆدەکە هەڵەیە یان کاتی تەواو بووە" }, 401);
  }

  const { data: created, error: createErr } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });
  if (createErr || !created?.user) {
    const duplicate = /already.*(registered|exists)/i.test(createErr?.message || "");
    console.warn("admin_create_user_auth_create_failed", { stage: "auth_create", duplicate });
    return json({ error: duplicate ? "email_already_registered" : "create_failed", message: duplicate ? "ئەم ئیمەیلە پێشتر تۆمارکراوە" : "دروستکردنی هەژمار سەرکەوتوو نەبوو" }, duplicate ? 409 : 500);
  }

  const newUserId = created.user.id;
  const { error: profileErr } = await adminClient.from("ex_profiles")
    .update({ phone: phone || null, is_admin: makeAdmin })
    .eq("id", newUserId);
  if (profileErr) {
    console.error("admin_create_user_profile_update_failed", { stage: "profile_update" });
    await adminClient.auth.admin.deleteUser(newUserId).catch(() => {});
    return json({ error: "create_failed", message: "دروستکردنی هەژمار سەرکەوتوو نەبوو" }, 500);
  }

  const { error: auditErr } = await adminClient.from("ex_admin_audit_log").insert({
    admin_id: callerId,
    action: "user_create",
    target_user_id: newUserId,
    detail: "email_verified_by_signup_otp",
  });
  if (auditErr) console.warn("admin_create_user_audit_log_failed", { stage: "audit" });
  console.info("admin_create_user_success", { caller_id: callerId, target_user_id: newUserId });
  return json({ success: true, user_id: newUserId });
});
