import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

// Lets an authenticated admin create a brand-new user account. Same CORS /
// auth pattern as admin-set-password — see the note there about why
// platform-level JWT verification is off and re-implemented here manually.

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);

  const authHeader = req.headers.get("Authorization") || "";
  const jwt = authHeader.replace(/^Bearer\s+/i, "");
  if (!jwt) return json({ error: "missing_authorization" }, 401);

  let body: { email?: string; password?: string; full_name?: string; phone?: string; is_admin?: boolean };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid_json_body" }, 400);
  }

  const email = (body.email || "").trim().toLowerCase();
  const password = body.password || "";
  const fullName = (body.full_name || "").trim();
  const phone = (body.phone || "").trim();
  const makeAdmin = !!body.is_admin;

  if (!email || !email.includes("@")) return json({ error: "invalid_email", message: "ئیمەیلی دروست بنووسە" }, 400);
  if (password.length < 8) return json({ error: "password_too_short", message: "وشەی نەھینی لانیکەم ٨ پیت/ژمارە" }, 400);

  const callerClient = createClient(SUPABASE_URL, ANON_KEY, {
    global: { headers: { Authorization: `Bearer ${jwt}` } },
  });

  const { data: userData, error: userErr } = await callerClient.auth.getUser();
  if (userErr || !userData?.user) return json({ error: "invalid_session" }, 401);
  const callerId = userData.user.id;

  const { data: callerProfile, error: profErr } = await callerClient
    .from("ex_profiles")
    .select("is_admin,is_banned,role,staff_permissions")
    .eq("id", callerId)
    .single();

  if (profErr || !callerProfile?.is_admin || callerProfile.is_banned || callerProfile.role !== "super_admin") {
    return json({ error: "forbidden", message: "تەنها سوپەر ئادمین مافی زیادکردنی هەژمار هەیە" }, 403);
  }


  const adminClient = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  const { data: created, error: createErr } = await adminClient.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName },
  });

  if (createErr || !created?.user) {
    const msg = /already.*(registered|exists)/i.test(createErr?.message || "")
      ? "ئەم ئیمەیلە پێشتر تۆمارکراوە"
      : (createErr?.message || "create_failed");
    return json({ error: "create_failed", message: msg }, 500);
  }

  const newUserId = created.user.id;

  await adminClient.from("ex_profiles").update({ phone: phone || null, is_admin: makeAdmin }).eq("id", newUserId);

  await adminClient.from("ex_admin_audit_log").insert({
    admin_id: callerId,
    action: "user_create",
    target_user_id: newUserId,
    detail: `email=${email}`,
  });

  return json({ success: true, user_id: newUserId });
});


