// supabase/functions/send-notification/index.ts
//
// Supabase Edge Function — ئاگادارکردنەوەی FCM + تۆمارکردن لە pa_notifications
//
// ── دامەزراندن ───────────────────────────────────────────────────────────────
//   supabase functions deploy send-notification --no-verify-jwt
//
// ── سیکرێتەکان (supabase secrets set ...) ───────────────────────────────────
//   FIREBASE_PROJECT_ID    — پرۆجەی Firebase (مێسلا: proxo-app-12345)
//   FIREBASE_CLIENT_EMAIL  — service account email
//   FIREBASE_PRIVATE_KEY   — private key (-----BEGIN PRIVATE KEY-----\n...)
//
// ── بەکارهێنان لە admin_notifier.dart ───────────────────────────────────────
//   await supabase.functions.invoke('send-notification', body: {
//     'user_id': userId,
//     'type':    'ad_approved',
//     'data':    {'ad_id': adId},
//   });
//
// ─────────────────────────────────────────────────────────────────────────────

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── تایپەکانی ئاگاداری ────────────────────────────────────────────────────────
const NOTIFICATION_TYPES: Record<string, { title: string; body: string }> = {
  // ڕیکلام
  ad_approved:        { title: "✅ ڕیکلامەکەت پەسەند کرا",       body: "ڕیکلامەکەت پەسەند کرا و ئێستا چالاکە" },
  ad_rejected:        { title: "❌ ڕیکلامەکەت ڕەتکرایەوە",      body: "ببورە، ڕیکلامەکەت پەسەند نەکرا. بۆ زانیاری زیاتر سەردانی ئەپ بکە " },
  ad_active:          { title: "🟢 ڕیکلامەکەت چالاکە",           body: "ڕیکلامەکەت ئێستا چالاکە و بەشێوەی ڕاستەوخۆ داتاکان ببینە" },
  ad_completed:       { title: "🏁 ڕیکلامەکەت تەواو بوو",        body: "ڕیکلامەکەت بە سەرکەوتوویی تەواو بوو" },
  ad_paused:          { title: "⏸️ ڕیکلامەکەت وەستا",           body: "ڕیکلامەکەت بۆ ماوەیەک وەستێنرا" },
  new_ad:             { title: "📢 ڕیکلامی نوێ تۆمار کرا",       body: "ڕیکلامی نوێت بەسەرکەوتی تۆمار کرا" },
  refund_rejected_ad: { title: "❌ داواکاری گەڕانەوەی پارە ڕەتکرایەوە", body: "داواکاری گەڕانەوەی پارەت پەسەند نەکرا" },

  // پارەدان
  deposit_approved:   { title: "✅ پارەدانەکەت پەسەند کرا",     body: "باڵانسەکەت نوێ کرایەوە" },
  deposit_rejected:   { title: "❌ پارەدانەکەت ڕەتکرایەوە",    body: "ببورە، پارەدانەکەت پەسەند نەکرا. پەیوەندیمان پێوەبکە" },
  balance_added:      { title: "💰 باڵانسی زیادکرا",            body: "پارەی نوێ زیادکرا بۆ باڵانسی هەژمارەکەت" },
  refund:             { title: "💸 گەڕانەوەی پارە",             body: "پارەکەت گەڕایەوە بۆ باڵانسی هەژمارەکەت" },

  // گشتی
  admin_msg:          { title: "📬 پەیامی پرۆکسۆ",              body: "پەیامی نوێت هەیە لەلایەن تیمی پرۆکسۆ" },
  system_update:      { title: "🔔 نوێکردنەوەی سیستەم",         body: "پرۆکسۆ نوێکرایەوە" },
  general:            { title: "🔔 ئاگاداری پرۆکسۆ",            body: "" },
  warning:            { title: "⚠️ ئاگاداری",                   body: "" },
  error:              { title: "🔴 هەڵە",                        body: "" },
};

// ── Navigate routes ────────────────────────────────────────────────────────────
const ROUTE_MAP: Record<string, string> = {
  ad_approved: "my-ads",   ad_rejected: "my-ads",
  ad_active:   "my-ads",   ad_completed: "my-ads",
  ad_paused:   "my-ads",   ad_pending: "my-ads",
  new_ad:      "my-ads",   refund_rejected_ad: "my-ads",
  deposit_approved: "wallet", deposit_rejected: "wallet",
  deposit_pending:  "wallet", balance_added:    "wallet",
  balance_deducted: "wallet", refund:           "wallet",
  admin_msg:        "notifications",
  system_update:    "notifications",
  general:          "notifications",
};

// ── Base64url helpers (JWT requires base64url, NOT standard base64) ───────────
// BUG FIX: btoa() produces standard base64 (+, /, =) but JWT needs base64url
// (-, _, no padding). Using standard base64 causes OAuth2 token requests to
// fail with 400, leaving access_token undefined and FCM push silently broken.

function strToBase64url(str: string): string {
  return btoa(unescape(encodeURIComponent(str)))
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
}

function bufToBase64url(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=/g, "");
}

// ── FCM OAuth2 Token ──────────────────────────────────────────────────────────
async function getFcmAccessToken(
  clientEmail: string,
  privateKey: string
): Promise<string> {
  const scope = "https://www.googleapis.com/auth/firebase.messaging";
  const now = Math.floor(Date.now() / 1000);

  // FIX: use base64url encoding for JWT header and payload
  const header  = strToBase64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payload = strToBase64url(
    JSON.stringify({
      iss: clientEmail,
      sub: clientEmail,
      aud: "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
      scope,
    })
  );

  const unsigned = `${header}.${payload}`;

  // Private key parse
  const pemContents = privateKey
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");

  const keyBuffer = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBuffer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signatureBuffer = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsigned)
  );

  // FIX: use base64url for signature too; also avoid spread operator on large
  // Uint8Array which can overflow the call stack on some runtimes.
  const signature = bufToBase64url(signatureBuffer);

  const jwt = `${unsigned}.${signature}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) {
    console.error("[FCM] OAuth2 token error:", JSON.stringify(tokenData));
    throw new Error("FCM OAuth2 failed: " + (tokenData.error_description ?? tokenData.error));
  }
  return tokenData.access_token as string;
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
      type    = "general",
      title:  customTitle,
      body:   customBody,
      data:   extraData = {},
      push_only = false,
    } = await req.json();

    if (!user_id) {
      return new Response(JSON.stringify({ error: "user_id required" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // ── Supabase Admin Client ─────────────────────────────────────────────
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    );

    // ── تایپی تیبل بەدەستبهێنە ──────────────────────────────────────────────
    const defaults = NOTIFICATION_TYPES[type] ?? NOTIFICATION_TYPES["general"];
    const finalTitle = customTitle ?? defaults.title;
    const finalBody  = customBody  ?? defaults.body;
    const screen     = extraData.screen ?? ROUTE_MAP[type] ?? "notifications";

    // ── 1. تۆمارکردن لە pa_notifications (تەنها کاتی push_only نەبێت) ─────────
      if (!push_only) {
        const { error: insertErr } = await supabase
        .from("pa_notifications")
        .insert({
          user_id,
          type,
          title:      finalTitle,
          body:       finalBody,
          meta:       { ...extraData },
          is_read:    false,
          created_at: new Date().toISOString(),
        });
  
      if (insertErr) {
        console.error("[Notif] Insert error:", insertErr);
      }
  
    }

    // ── 2. FCM Push ───────────────────────────────────────────────────────────
    const projectId    = Deno.env.get("FIREBASE_PROJECT_ID");
    const clientEmail  = Deno.env.get("FIREBASE_CLIENT_EMAIL");
    const privateKey   = Deno.env.get("FIREBASE_PRIVATE_KEY")?.replace(/\\n/g, "\n");

    if (!projectId || !clientEmail || !privateKey) {
      console.warn("[FCM] Firebase env vars missing — skip push");
      return new Response(JSON.stringify({ ok: true, push: false }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    // FCM توکێنەکان بەدەستبهێنە
    const { data: tokens } = await supabase
      .from("pa_device_tokens")
      .select("token, platform")
      .eq("user_id", user_id);

    if (!tokens || tokens.length === 0) {
      console.log("[FCM] No tokens for user:", user_id);
      return new Response(JSON.stringify({ ok: true, push: false, reason: "no_token" }), {
        headers: { "Content-Type": "application/json" },
      });
    }

    const accessToken = await getFcmAccessToken(clientEmail, privateKey);
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    const pushResults: Array<{ token: string; success: boolean }> = [];

    for (const { token, platform } of tokens) {
      const message: Record<string, unknown> = {
        token,
        notification: { title: finalTitle, body: finalBody },
        data: {
          type,
          screen,
          title: finalTitle,
          body:  finalBody,
          ...Object.fromEntries(
            Object.entries(extraData).map(([k, v]) => [k, String(v)])
          ),
        },
        android: {
          priority: "high",
          notification: {
            channel_id:   "proxo_high_importance",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            default_sound: true,
            default_vibrate_timings: true,
          },
        },
      };

      if (platform === "ios") {
        (message as Record<string, unknown>).apns = {
          headers: { "apns-priority": "10" },
          payload: { aps: { sound: "default", badge: 1 } },
        };
      }

      try {
        const res = await fetch(fcmUrl, {
          method:  "POST",
          headers: {
            Authorization:  `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ message }),
        });

        const result = await res.json();

        if (!res.ok) {
          // توکێنی کۆن/هەڵەیە — سڕینەوە
          if (result?.error?.details?.some((d: Record<string, string>) =>
              d.errorCode === "UNREGISTERED" || d.errorCode === "INVALID_ARGUMENT"
          )) {
            await supabase
              .from("pa_device_tokens")
              .delete()
              .eq("token", token);
            console.log("[FCM] Removed stale token:", token.slice(-10));
          } else {
            console.error("[FCM] Error:", result);
          }
          pushResults.push({ token: token.slice(-10), success: false });
        } else {
          pushResults.push({ token: token.slice(-10), success: true });
        }
      } catch (e) {
        console.error("[FCM] Send error:", e);
        pushResults.push({ token: token.slice(-10), success: false });
      }
    }

    return new Response(
      JSON.stringify({ ok: true, push: true, results: pushResults }),
      { headers: { "Content-Type": "application/json" } }
    );
  } catch (e) {
    console.error("[send-notification] Unexpected error:", e);
    return new Response(JSON.stringify({ error: String(e) }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
