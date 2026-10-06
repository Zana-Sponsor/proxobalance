import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Lets an authenticated admin set a NEW password for another user's account.
// Runs server-side because it needs the service-role key (auth.admin API) —
// that key must never reach the browser, since it bypasses every RLS policy.
//
// NOTE on auth: platform-level JWT verification is OFF for this function
// because that gate also blocks the CORS OPTIONS preflight browsers send
// first (preflight never carries an Authorization header), which caused
// "Failed to fetch" in the admin panel. Auth is NOT skipped — it is done
// below, and is stricter than the platform's: a valid session AND
// ex_profiles.is_admin = true.
//
// Every failure path returns JSON with { error, stage, message } so the admin
// panel can show exactly which step broke instead of a generic message.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

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

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }

  // Whatever blows up, the caller still gets JSON + CORS headers back —
  // an uncaught throw here would return an HTML/plain 500 with no CORS,
  // which the browser reports as the useless "Failed to fetch".
  try {
    if (req.method !== "POST") {
      return json({ error: "method_not_allowed", stage: "method" }, 405);
    }

    if (!SUPABASE_URL || !ANON_KEY || !SERVICE_ROLE_KEY) {
      return json({
        error: "missing_env",
        stage: "config",
        message: "کلیلی service-role لە سێرڤەردا دانەنراوە",
      }, 500);
    }

    const authHeader = req.headers.get("Authorization") || "";
    const jwt = authHeader.replace(/^Bearer\s+/i, "").trim();
    if (!jwt) {
      return json({ error: "missing_authorization", stage: "auth_header" }, 401);
    }

    let body: { target_user_id?: string; new_password?: string };
    try {
      body = await req.json();
    } catch {
      return json({ error: "invalid_json_body", stage: "body" }, 400);
    }

    const targetUserId = (body.target_user_id || "").trim();
    const newPassword = body.new_password || "";

    if (!targetUserId) {
      return json({ error: "target_user_id_required", stage: "body" }, 400);
    }
    if (newPassword.length < 8) {
      return json({
        error: "password_too_short",
        stage: "body",
        message: "وشەی نهێنی دەبێت لانیکەم ٨ پیت بێت",
      }, 400);
    }

    // Client scoped to the CALLER's own JWT — identifies who is calling and
    // confirms they are an admin. Cannot bypass RLS.
    const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${jwt}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: userData, error: userErr } = await callerClient.auth.getUser();
    if (userErr || !userData?.user) {
      return json({
        error: "invalid_session",
        stage: "caller_session",
        message: "چوونەژوورەوەت بەسەرچووە — دووبارە بچۆرەوە ژوورەوە",
      }, 401);
    }
    const callerId = userData.user.id;

    const { data: callerProfile, error: profErr } = await callerClient
      .from("ex_profiles")
      .select("is_admin,is_banned,role,staff_permissions")
      .eq("id", callerId)
      .maybeSingle();

    if (profErr) {
      return json({
        error: "profile_lookup_failed",
        stage: "admin_check",
        message: profErr.message,
      }, 500);
    }
    if (!callerProfile?.is_admin || callerProfile.is_banned || (callerProfile.role !== "super_admin" && callerProfile.staff_permissions != null)) {
      return json({
        error: "forbidden",
        stage: "admin_check",
        message: "تۆ مافی ئەم کردارە نییت",
      }, 403);
    }

    // Service-role client — the ONLY place in this system that touches the
    // service-role key, and it never leaves this server-side function.
    const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const {data: targetProfile,error:targetProfileError}=await adminClient.from("ex_profiles")
      .select("is_admin,role").eq("id",targetUserId).single();
    if(targetProfileError || (targetProfile?.is_admin && callerProfile.role!=="super_admin")){
      return json({error:"forbidden",message:"SUPER_ADMIN_REQUIRED_FOR_STAFF_PASSWORD"},403);
    }

    const { data: targetUser, error: getErr } = await adminClient.auth.admin
      .getUserById(targetUserId);
    if (getErr || !targetUser?.user) {
      return json({
        error: "user_not_found",
        stage: "target_lookup",
        message: getErr?.message || "ئەم بەکارهێنەرە نەدۆزرایەوە",
      }, 404);
    }

    const { error: updateErr } = await adminClient.auth.admin.updateUserById(
      targetUserId,
      { password: newPassword },
    );

    if (updateErr) {
      console.error("updateUserById failed", updateErr);
      return json({
        error: "update_failed",
        stage: "password_update",
        message: updateErr.message,
        status: (updateErr as { status?: number }).status ?? null,
      }, 500);
    }

    // ── Everything below is best-effort: the password IS already changed, so
    // ── a hiccup here must NOT turn a successful reset into an error toast.
    let sessionsRevoked: number | null = null;
    let warning: string | null = null;

    try {
      const { data: killed, error: revokeErr } = await adminClient.rpc(
        "ex_revoke_user_sessions",
        { target: targetUserId },
      );
      if (revokeErr) {
        warning = `sessions_not_revoked: ${revokeErr.message}`;
        console.error("revoke sessions failed", revokeErr);
      } else {
        sessionsRevoked = typeof killed === "number" ? killed : 0;
      }
    } catch (e) {
      warning = `sessions_not_revoked: ${(e as Error).message}`;
    }

    try {
      const { error: auditErr } = await adminClient
        .from("ex_admin_audit_log")
        .insert({
          admin_id: callerId,
          action: "password_reset",
          target_user_id: targetUserId,
          // never stores the password itself, only that a reset happened
          detail: `target_email=${targetUser.user.email || ""}`,
        });
      if (auditErr) {
        warning = `${warning ? warning + " | " : ""}audit_not_logged: ${auditErr.message}`;
        console.error("audit insert failed", auditErr);
      }
    } catch (e) {
      warning = `${warning ? warning + " | " : ""}audit_not_logged: ${(e as Error).message}`;
    }

    return json({
      success: true,
      email: targetUser.user.email || null,
      sessions_revoked: sessionsRevoked,
      warning,
    });
  } catch (e) {
    console.error("unhandled", e);
    return json({
      error: "unhandled_exception",
      stage: "server",
      message: (e as Error)?.message || String(e),
    }, 500);
  }
});


