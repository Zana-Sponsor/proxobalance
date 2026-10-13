// supabase/functions/send-push-notification/index.ts
//
// ── FCM V1 API (نوێترین — Legacy داخراوە ژوئن 2024) ──────────────────────────
//
//   ١. ئادمین ڕیکۆرد دەخاتە pa_notifications
//   ٢. Database Trigger ئەم Edge Function دەبانگێشێت
//   ٣. Edge Function توکێنی دیوایسی یوزەر لە pa_device_tokens دەخوێنێتەوە
//   ٤. FCM V1 push notification دەنێرێت بۆ هەموو دیوایسەکانی ئەو یوزەرە
//
// ── Secrets (supabase secrets set ...) ───────────────────────────────────────
//   FIREBASE_PROJECT_ID   — firebase project id
//   FIREBASE_CLIENT_EMAIL — service account email
//   FIREBASE_PRIVATE_KEY  — private key (-----BEGIN PRIVATE KEY-----\n...)
//
// ── deploy ────────────────────────────────────────────────────────────────────
//   supabase functions deploy send-push-notification --no-verify-jwt
//
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── جۆری ئاگاداری → ناوی کوردی ───────────────────────────────────────────────
const TYPE_TITLE: Record<string, string> = {
  ad_approved:        "ڕیکلامەکەت پەسەندکرا ✅",
  ad_rejected:        "ڕیکلامەکەت ڕەتکرا ❌",
  ad_active:          "ڕیکلامەکەت چالاکبوو 🟢",
  ad_completed:       "ڕیکلامەکەت تەواوبوو 🏁",
  ad_paused:          "ڕیکلامەکەت وەستاوە ⏸",
  ad_pending:         "ڕیکلامەکەت چاوەڕوانە ⏳",
  new_ad:             "ڕیکلامی نوێ دروستکرا",
  deposit_approved:   "پارەدانەکەت پەسەندکرا ✅",
  deposit_rejected:   "پارەدانەکەت ڕەتکرا ❌",
  deposit_pending:    "پارەدانەکەت چاوەڕوانە ⏳",
  balance_added:      "💰 باڵانسی زیادکرا",
  balance_deducted:   "⚠️ باڵانسەکەت کەم کرایەوە",
  refund:             "پارەکەت گەڕایەوە 💸",
  refund_rejected_ad: "گەڕانەوەی پارەی ڕیکلامی ڕەتکراو 💸",
  admin_msg:          "نامەی ئادمین 📢",
  system_update:      "نوێکردنەوەی سیستەم 🔔",
  general:            "ئاگاداری 🔔",
  warning:            "ئاگاداری ⚠️",
  error:              "هەڵە 🔴",
};

// ── FCM OAuth2 Token (V1) ──────────────────────────────────────────────────────
async function getFcmAccessToken(
  clientEmail: string,
  privateKey: string
): Promise<string> {
  const scope = "https://www.googleapis.com/auth/firebase.messaging";
  const now = Math.floor(Date.now() / 1000);

  const header  = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = btoa(JSON.stringify({
    iss: clientEmail, sub: clientEmail,
    aud: "https://oauth2.googleapis.com/token",
    iat: now, exp: now + 3600, scope,
  }));
  const unsigned = `${header}.${payload}`;

  const pemContents = privateKey
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const keyBuffer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", keyBuffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false, ["sign"]
  );

  const sigBuf = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5", cryptoKey,
    new TextEncoder().encode(unsigned)
  );
  const sig = btoa(String.fromCharCode(...new Uint8Array(sigBuf)));
  const jwt = `${unsigned}.${sig}`;

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });
  const data = await res.json();
  return data.access_token as string;
}

// ── FCM V1 Send ────────────────────────────────────────────────────────────────
async function sendFcmV1(opts: {
  token:       string;
  title:       string;
  body:        string;
  data:        Record<string, string>;
  projectId:   string;
  accessToken: string;
  platform:    string;
}): Promise<boolean> {
  const message: Record<string, unknown> = {
    token: opts.token,
    // notification payload — پێویستە بۆ باکگراوند و داخستنی ئەپ
    notification: { title: opts.title, body: opts.body },
    // data payload — بەکاردێت بۆ navigate کردن کاتی کلیک
    data: opts.data,
    android: {
      priority: "high",
      notification: {
        channel_id:              "proxo_high_importance",
        click_action:            "FLUTTER_NOTIFICATION_CLICK",
        default_sound:           true,
        default_vibrate_timings: true,
      },
    },
  };

  if (opts.platform === "ios") {
    (message as Record<string, unknown>).apns = {
      headers: { "apns-priority": "10" },
      payload: { aps: { sound: "default", badge: 1 } },
    };
  }

  try {
    const res = await fetch(
      `https://fcm.googleapis.com/v1/projects/${opts.projectId}/messages:send`,
      {
        method:  "POST",
        headers: {
          Authorization:  `Bearer ${opts.accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({ message }),
      }
    );

    const json = await res.json();
    if (!res.ok) {
      const errCode = json?.error?.details
        ?.find((d: Record<string, string>) => d["@type"]?.includes("ErrorInfo"))
        ?.errorCode ?? "";
      if (errCode === "UNREGISTERED" || errCode === "INVALID_ARGUMENT") {
        return false; // توکێنی کۆن — سڕینەوە
      }
      console.error("[FCM V1] Error:", JSON.stringify(json));
      return false;
    }
    return true;
  } catch (e) {
    console.error("[FCM V1] Send error:", e);
    return false;
  }
}

// ── Main Handler ─────────────────────────────────────────────────────────────
serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin":  "*",
        "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
      },
    });
  }

  try {
    const {
      user_id,
      title:  customTitle,
      body:   customBody,
      type    = "general",
      ad_id,
      screen: customScreen,
    } = await req.json();

    if (!user_id) {
      return new Response(JSON.stringify({ ok: false, error: "user_id پێویستە" }), {
        status: 400, headers: { "Content-Type": "application/json" },
      });
    }

    // ── Firebase secrets ──────────────────────────────────────────────────────
    const projectId   = Deno.env.get("FIREBASE_PROJECT_ID");
    const clientEmail = Deno.env.get("FIREBASE_CLIENT_EMAIL");
    const privateKey  = Deno.env.get("FIREBASE_PRIVATE_KEY")?.replace(/\\n/g, "\n");

    if (!projectId || !clientEmail || !privateKey) {
      console.warn("[FCM] Firebase env vars missing — skip push");
      return new Response(
        JSON.stringify({ ok: true, push: false, reason: "no_firebase_config" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // ── Supabase admin client ─────────────────────────────────────────────────
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ── توکێنەکانی ئەو یوزەرە وەربگرە ──────────────────────────────────────
    const { data: tokens, error: tokErr } = await supabase
      .from("pa_device_tokens")
      .select("token, platform")
      .eq("user_id", user_id);

    if (tokErr) {
      console.error("[FCM] Token fetch error:", tokErr);
      return new Response(
        JSON.stringify({ ok: false, error: "token fetch failed" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    if (!tokens || tokens.length === 0) {
      console.log("[FCM] No tokens for user:", user_id);
      return new Response(
        JSON.stringify({ ok: true, push: false, reason: "no_token" }),
        { headers: { "Content-Type": "application/json" } }
      );
    }

    // ── ناوی ئاگاداری ─────────────────────────────────────────────────────────
    const notifTitle = customTitle || TYPE_TITLE[type] || "Proxo 🔔";
    const notifBody  = customBody  || "";
    const adTypes    = ["ad_approved","ad_rejected","ad_active","ad_completed",
                        "ad_paused","ad_pending","new_ad","refund_rejected_ad"];
    const walletTypes = ["deposit_approved","deposit_rejected","deposit_pending",
                         "balance_added","balance_deducted","refund"];
    const screen = customScreen
      || (adTypes.includes(type) ? "my-ads"
          : walletTypes.includes(type) ? "wallet"
          : "notifications");

    // ── FCM access token ──────────────────────────────────────────────────────
    const accessToken = await getFcmAccessToken(clientEmail, privateKey);

    let sent = 0;

    for (const { token, platform } of tokens) {
      const ok = await sendFcmV1({
        token,
        title: notifTitle,
        body:  notifBody,
        data: {
          type,
          screen,
          title: notifTitle,
          body:  notifBody,
          ...(ad_id ? { ad_id: String(ad_id) } : {}),
        },
        projectId,
        accessToken,
        platform: platform ?? "android",
      });

      if (ok) {
        sent++;
      } else {
        // توکێنی کارناکردن سڕینەوە
        await supabase
          .from("pa_device_tokens")
          .delete()
          .eq("token", token);
        console.log("[FCM] Removed stale token:", token.slice(-10));
      }
    }

    console.log(
      `[FCM] Sent: ${sent}/${tokens.length} — user=${user_id} type=${type}`
    );

    return new Response(
      JSON.stringify({ ok: true, push: true, sent }),
      { headers: { "Content-Type": "application/json" } }
    );

  } catch (e) {
    console.error("[send-push-notification] Error:", e);
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});
