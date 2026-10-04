/**
 * delete-user Edge Function
 *
 * Pure Supabase — no n8n, no external automation.
 * Deploy: supabase functions deploy delete-user --no-verify-jwt
 *
 * Flow:
 *  1. Verify caller JWT
 *  2. Delete storage objects owned by the user
 *  3. Delete ALL public table rows (FK child-first order)
 *  4. Hard-delete the auth user  ← frees email immediately
 *
 * Why storage must be deleted first:
 *   storage.objects has an "owner" column that FK-references auth.users.
 *   If the user uploaded any files (profile photo, etc.), deleteUser()
 *   will fail with "Database error deleting user" (500) until those
 *   storage rows are removed.
 *
 * Why no signOut call:
 *   admin.auth.admin.signOut() before deleteUser caused the "signin OTP"
 *   side-effect: when the global signOut fired, Flutter detected the
 *   invalidated session and redirected to AuthScreen which sent an OTP.
 *   After a hard deleteUser, Supabase invalidates all tokens automatically,
 *   so an explicit signOut is unnecessary and harmful.
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const TABLE_NOT_FOUND_CODES = new Set(["42P01", "PGRST106", "PGRST200", "PGRST204"]);
const TABLE_NOT_FOUND_MESSAGES = [
  "schema cache",
  "Could not find the table",
  "relation",
  "does not exist",
];

function isTableNotFound(error: { code?: string; message?: string }): boolean {
  if (error.code && TABLE_NOT_FOUND_CODES.has(error.code)) return true;
  const msg = error.message ?? "";
  return TABLE_NOT_FOUND_MESSAGES.some((s) => msg.includes(s));
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return json({ ok: true }, 200, corsHeaders);
  }
  if (req.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  try {
    // ── Step 1: Verify caller JWT ─────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return json({ error: "Missing or invalid Authorization header" }, 401);
    }

    const userClient = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_ANON_KEY")!,
      { global: { headers: { Authorization: authHeader } } }
    );

    const {
      data: { user },
      error: authError,
    } = await userClient.auth.getUser();
    if (authError || !user) {
      return json({ error: "Unauthorized: session is invalid or expired" }, 401);
    }

    const userId = user.id;

    // ── Step 2: Service-role client ───────────────────────────────────────
    const admin = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
      { auth: { autoRefreshToken: false, persistSession: false } }
    );

    // ── Step 3: Delete storage objects owned by the user ─────────────────
    //   storage.objects has owner → auth.users FK.
    //   If ANY file exists for this user, auth.admin.deleteUser() will return
    //   "Database error deleting user" (500) because the FK is still there.
    //   We must list every bucket and delete files owned by this user.
    try {
      const { data: buckets, error: bucketsError } = await admin.storage.listBuckets();
      if (bucketsError) {
        console.warn("[delete-user] could not list buckets:", bucketsError.message);
      } else if (buckets && buckets.length > 0) {
        for (const bucket of buckets) {
          // List all files owned by this user in this bucket.
          // Common pattern: files are stored under userId/ prefix.
          const { data: files } = await admin.storage
            .from(bucket.name)
            .list(userId, { limit: 1000 });

          if (files && files.length > 0) {
            if (bucket.name === "proxolink-assets") {
              // ProxoLink avatars use user/card/immutable-file paths.
              // Remove nested files before deleting their auth owner.
              const paths: string[] = [];
              async function visit(prefix: string, depth = 0): Promise<void> {
                if (depth > 4) throw new Error("Unexpected avatar folder depth");
                for (let offset = 0; ; offset += 1000) {
                  const { data, error } = await admin.storage.from(bucket.name)
                    .list(prefix, { limit: 1000, offset });
                  if (error) throw error;
                  for (const file of data ?? []) {
                    const path = `${prefix}/${file.name}`;
                    if (file.id == null) await visit(path, depth + 1);
                    else paths.push(path);
                  }
                  if ((data?.length ?? 0) < 1000) break;
                }
              }
              await visit(userId);
              for (let offset = 0; offset < paths.length; offset += 100) {
                const { error } = await admin.storage.from(bucket.name)
                  .remove(paths.slice(offset, offset + 100));
                if (error) throw error;
              }
              continue;
            }
            const paths = files.map((f) => `${userId}/${f.name}`);
            const { error: removeError } = await admin.storage
              .from(bucket.name)
              .remove(paths);
            if (removeError) {
              console.warn(
                `[delete-user] could not remove files from "${bucket.name}":`,
                removeError.message
              );
            } else {
              console.log(
                `[delete-user] removed ${paths.length} file(s) from bucket "${bucket.name}"`
              );
            }
          }
        }
      }
    } catch (storageErr) {
      // Storage cleanup failure is non-fatal if no files actually exist.
      // Log it but continue — the real FK check happens at deleteUser time.
      console.warn("[delete-user] storage cleanup skipped:", String(storageErr));
    }

    // Explicit account deletion removes the owner's contact history first.
    // Normal card/ad deletion remains restricted so history is preserved.
    for (let offset = 0; ; offset += 1000) {
      const { data: links, error: linksError } = await admin
        .from("pa_ad_contact_links").select("id").eq("owner_user_id", userId)
        .order("id").range(offset, offset + 999);
      if (linksError && !isTableNotFound(linksError)) throw linksError;
      for (const link of links ?? []) {
        const { error } = await admin.from("pa_contact_events")
          .delete().eq("ad_contact_link_id", link.id);
        if (error) throw error;
      }
      if ((links?.length ?? 0) < 1000) break;
    }
    const { error: contactLinksError } = await admin.from("pa_ad_contact_links")
      .delete().eq("owner_user_id", userId);
    if (contactLinksError && !isTableNotFound(contactLinksError)) throw contactLinksError;

    // ── Step 4: Delete ALL public rows (child tables before parents) ───────
    // Single-column tables
    const publicTables: Array<{ table: string; column: string }> = [
      { table: "pa_transactions",     column: "user_id" },
      { table: "pa_notifications",    column: "user_id" },
      { table: "pa_device_tokens",    column: "user_id" },
      { table: "pa_ads",              column: "user_id" },
      { table: "pa_support",          column: "user_id" },
      { table: "proxo_cards",         column: "user_id" },
      { table: "notifications",       column: "user_id" },
      { table: "pa_wallets",          column: "user_id" },
      { table: "pa_assets",           column: "user_id" },
      { table: "proxolink_cards",     column: "user_id" },
      { table: "pa_coin_transactions",column: "user_id" },
      { table: "pa_banned_devices",   column: "banned_user_id" },
      { table: "live_chat_history",   column: "user_id" },
      { table: "otp_codes",           column: "user_id" },
      { table: "promo_codes",         column: "restricted_to_user_id" },
      { table: "users",               column: "id" },  // has send_to_n8n trigger — before profiles
      { table: "profiles",            column: "id" },  // parent — must be last
    ];

    for (const { table, column } of publicTables) {
      const { error } = await admin.from(table).delete().eq(column, userId);
      if (error) {
        if (isTableNotFound(error as any)) {
          console.warn(`[delete-user] table "${table}" not found (${(error as any).code}), skipping`);
          continue;
        }
        console.error(`[delete-user] failed to clean "${table}":`, error);
        return json(
          {
            error: "Cleanup failed — account was NOT deleted",
            detail: `Could not delete rows from "${table}": ${error.message}`,
            hint: "Fix the FK or RLS issue for this table, then retry.",
          },
          500
        );
      }
      console.log(`[delete-user] cleaned "${table}" for user ${userId}`);
    }

    // ── Step 4b: Multi-column FK tables ───────────────────────────────────
    // pa_referrals: referrer_id and referred_id both reference auth.users
    const { error: refErr } = await admin
      .from("pa_referrals")
      .delete()
      .or(`referrer_id.eq.${userId},referred_id.eq.${userId}`);
    if (refErr && !isTableNotFound(refErr as any)) {
      console.error("[delete-user] failed to clean pa_referrals:", refErr);
      return json({ error: "Cleanup failed", detail: refErr.message }, 500);
    }
    console.log(`[delete-user] cleaned "pa_referrals" for user ${userId}`);

    // pa_vouchers: used_by and created_by both reference auth.users
    const { error: voucherErr } = await admin
      .from("pa_vouchers")
      .delete()
      .or(`used_by.eq.${userId},created_by.eq.${userId}`);
    if (voucherErr && !isTableNotFound(voucherErr as any)) {
      console.error("[delete-user] failed to clean pa_vouchers:", voucherErr);
      return json({ error: "Cleanup failed", detail: voucherErr.message }, 500);
    }
    console.log(`[delete-user] cleaned "pa_vouchers" for user ${userId}`);

    // ── Step 5: Hard-delete the auth user ─────────────────────────────────
    const userEmail = user.email ?? '';

    const { error: deleteError } = await admin.auth.admin.deleteUser(
      userId,
      false // shouldSoftDelete = false → email freed immediately
    );
    if (deleteError) {
      console.error("[delete-user] auth.admin.deleteUser failed:", deleteError);
      return json(
        {
          error: "Failed to delete auth user",
          detail: deleteError.message,
          hint: "Public rows were removed, but the auth record remains. Check for remaining FK references (e.g. storage.objects owner, database triggers referencing auth.users, or non-public schema tables).",
        },
        500
      );
    }

    // ── Step 6: Record deleted email so login screen shows correct message ─
    //   The Flutter app checks deleted_accounts before attempting signIn,
    //   so deleted users see "email not registered" instead of "wrong password"
    //   and no OTP is sent to deleted emails.
    if (userEmail) {
      const { error: logErr } = await admin
        .from("deleted_accounts")
        .upsert({ email: userEmail, deleted_at: new Date().toISOString() });
      if (logErr) {
        console.warn("[delete-user] could not record deleted email:", logErr.message);
      } else {
        console.log(`[delete-user] recorded deleted email: ${userEmail}`);
      }
    }

    console.log(`[delete-user] successfully deleted user ${userId}`);
    return json({ success: true, deleted_user_id: userId }, 200);
  } catch (err) {
    console.error("[delete-user] unexpected error:", err);
    return json({ error: "Internal server error", detail: String(err) }, 500);
  }
});

function json(body: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
      ...extraHeaders,
    },
  });
}
