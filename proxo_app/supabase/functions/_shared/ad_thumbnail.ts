import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";
import { Image } from "https://deno.land/x/imagescript@1.2.15/mod.ts";

import { decodeThumbnail, thumbnailMime, validateThumbnail } from "./thumbnail_validation.ts";

const BUCKET = "ad-thumbnails";
const TARGET_WIDTH = 360;
const JPEG_QUALITY = 78;
const MAX_SOURCE_BYTES = 8 * 1024 * 1024;
const MAX_SOURCE_PIXELS = 16 * 1024 * 1024;
const MAX_OUTPUT_BYTES = 1024 * 1024;
const FETCH_TIMEOUT_MS = 8000;
const MAX_REDIRECTS = 6;
const MAX_RESOLVE_HTML_BYTES = 2 * 1024 * 1024;

const USER_AGENT =
  "Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 " +
  "(KHTML, like Gecko) Chrome/124.0 Mobile Safari/537.36 ProxoApp/1.0";
const TIKTOK_HOSTS = new Set([
  "tiktok.com",
  "www.tiktok.com",
  "m.tiktok.com",
  "vt.tiktok.com",
  "vm.tiktok.com",
  "t.tiktok.com",
]);
const TIKTOK_CANONICAL_RE =
  /^https:\/\/(?:www|m)\.tiktok\.com\/@[^/]+\/(?:video|photo)\/\d+/i;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

function bearerToken(req: Request): string | null {
  const header = req.headers.get("Authorization")?.trim() ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  return match?.[1]?.trim() || null;
}

function isTikTokVideoUrl(value: string): boolean {
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase().replace(/\.$/, "");
    return url.protocol === "https:" && TIKTOK_HOSTS.has(host);
  } catch (_) {
    return false;
  }
}

function isTrustedPosterUrl(value: string): boolean {
  try {
    const url = new URL(value);
    if (url.protocol !== "https:") return false;
    const host = url.hostname.toLowerCase().replace(/\.$/, "");
    const allowedSuffixes = [
      ".tiktok.com",
      ".tiktokcdn.com",
      ".tiktokcdn-us.com",
      ".ttwstatic.com",
      ".ibytedtos.com",
      ".byteoversea.com",
    ];
    return host === "tiktok.com" ||
      allowedSuffixes.some((suffix) => host.endsWith(suffix));
  } catch (_) {
    return false;
  }
}

async function fetchWithTimeout(
  initialUrl: string,
  isAllowed: (url: string) => boolean,
): Promise<Response> {
  let currentUrl = initialUrl;
  for (let redirectCount = 0; redirectCount <= MAX_REDIRECTS; redirectCount++) {
    if (!isAllowed(currentUrl)) throw new Error("untrusted_redirect");

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    try {
      const response = await fetch(currentUrl, {
        redirect: "manual",
        signal: controller.signal,
        headers: { "User-Agent": USER_AGENT },
      });
      if (response.status < 300 || response.status >= 400) return response;

      const location = response.headers.get("location");
      if (!location) return response;
      currentUrl = new URL(location, currentUrl).toString();
    } finally {
      clearTimeout(timeout);
    }
  }
  throw new Error("too_many_redirects");
}

async function resolveCanonicalTikTokUrl(value: string): Promise<string | null> {
  if (!isTikTokVideoUrl(value)) return null;
  if (TIKTOK_CANONICAL_RE.test(value)) return value.split("?", 1)[0];

  let currentUrl = value;
  for (let redirectCount = 0; redirectCount <= MAX_REDIRECTS; redirectCount++) {
    if (!isTikTokVideoUrl(currentUrl)) return null;

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
    let response: Response;
    try {
      response = await fetch(currentUrl, {
        method: "GET",
        redirect: "manual",
        signal: controller.signal,
        headers: { "User-Agent": USER_AGENT, "Accept": "text/html,*/*" },
      });
    } finally {
      clearTimeout(timeout);
    }

    if (response.status >= 300 && response.status < 400) {
      const location = response.headers.get("location");
      if (!location) return null;
      const nextUrl = new URL(location, currentUrl).toString();
      if (!isTikTokVideoUrl(nextUrl)) return null;
      if (TIKTOK_CANONICAL_RE.test(nextUrl)) {
        return nextUrl.split("?", 1)[0];
      }
      currentUrl = nextUrl;
      continue;
    }

    if (!response.ok) return null;
    const statedLength = Number(response.headers.get("content-length") ?? "0");
    if (Number.isFinite(statedLength) &&
      statedLength > MAX_RESOLVE_HTML_BYTES) {
      return null;
    }
    const html = await response.text();
    if (html.length > MAX_RESOLVE_HTML_BYTES) return null;

    const canonicalTag =
      /<link[^>]+rel=["']canonical["'][^>]+href=["']([^"']+)["']/i
        .exec(html)?.[1];
    const embeddedUrl =
      /https:\/\/(?:www|m)\.tiktok\.com\/@[^"'\s\\]+\/(?:video|photo)\/\d+/i
        .exec(html)?.[0];
    const candidate = canonicalTag ?? embeddedUrl;
    return candidate &&
        isTikTokVideoUrl(candidate) &&
        TIKTOK_CANONICAL_RE.test(candidate)
      ? candidate.split("?", 1)[0]
      : null;
  }
  return null;
}

async function tiktokPosterUrl(videoUrl: string): Promise<string | null> {
  const endpoint =
    `https://www.tiktok.com/oembed?url=${encodeURIComponent(videoUrl)}`;
  const response = await fetchWithTimeout(endpoint, isTikTokVideoUrl);
  if (!response.ok) {
    console.warn("[ad-thumbnail] TikTok oEmbed failed:", response.status);
    return null;
  }

  const data = await response.json().catch(() => null);
  const poster = typeof data?.thumbnail_url === "string"
    ? data.thumbnail_url.trim()
    : "";
  return poster.length > 0 && isTrustedPosterUrl(poster) ? poster : null;
}

async function buildThumbnail(posterUrl: string): Promise<Uint8Array | null> {
  const response = await fetchWithTimeout(posterUrl, isTrustedPosterUrl);
  if (!response.ok) {
    console.warn("[ad-thumbnail] Poster download failed:", response.status);
    return null;
  }

  const contentType = (response.headers.get("content-type") ?? "")
    .split(";", 1)[0]
    .trim()
    .toLowerCase();
  if (contentType &&
    contentType !== "application/octet-stream" &&
    !["image/jpeg", "image/png", "image/webp"].includes(contentType)) {
    console.warn("[ad-thumbnail] Unsupported content type:", contentType);
    return null;
  }

  const statedLength = Number(response.headers.get("content-length") ?? "0");
  if (Number.isFinite(statedLength) && statedLength > MAX_SOURCE_BYTES) {
    console.warn("[ad-thumbnail] Poster is too large:", statedLength);
    return null;
  }

  const source = new Uint8Array(await response.arrayBuffer());
  if (source.byteLength === 0 || source.byteLength > MAX_SOURCE_BYTES) {
    console.warn("[ad-thumbnail] Poster size is out of range:", source.byteLength);
    return null;
  }

  const actualMime = thumbnailMime(source);
  if (!actualMime || (contentType && contentType !== "application/octet-stream" && contentType !== actualMime)) {
    console.warn("[ad-thumbnail] Poster bytes/MIME are invalid");
    return null;
  }

  try {
    const decoded = await decodeThumbnail(source);
    if (!(decoded instanceof Image) ||
      decoded.width <= 0 ||
      decoded.height <= 0 ||
      decoded.width * decoded.height > MAX_SOURCE_PIXELS) {
      return null;
    }

    const image = decoded.width > TARGET_WIDTH
      ? decoded.resize(TARGET_WIDTH, Image.RESIZE_AUTO)
      : decoded;
    const jpeg = await image.encodeJPEG(JPEG_QUALITY);
    return jpeg.byteLength > 0 && jpeg.byteLength <= MAX_OUTPUT_BYTES
      ? jpeg
      : null;
  } catch (error) {
    console.warn("[ad-thumbnail] Image decode failed:", error);
    return null;
  }
}

type AdminClient = ReturnType<typeof createClient>;
let bucketReady: Promise<void> | null = null;

async function prepareBucket(admin: AdminClient): Promise<void> {
  const { data: existing } = await admin.storage.getBucket(BUCKET);
  const options = {
    public: true,
    fileSizeLimit: MAX_OUTPUT_BYTES,
    allowedMimeTypes: ["image/jpeg"],
  };

  if (existing) {
    if (!existing.public) {
      const { error } = await admin.storage.updateBucket(BUCKET, options);
      if (error) throw error;
    }
    return;
  }

  const { error } = await admin.storage.createBucket(BUCKET, options);
  if (!error) return;

  // Two first-time requests may race to create the bucket. If another request
  // won, the bucket now exists and the current request can continue safely.
  const { data: racedBucket } = await admin.storage.getBucket(BUCKET);
  if (!racedBucket) throw error;
}

function ensureBucket(admin: AdminClient): Promise<void> {
  bucketReady ??= prepareBucket(admin).catch((error) => {
    bucketReady = null;
    throw error;
  });
  return bucketReady;
}

async function verifyStoredThumbnail(
  admin: AdminClient,
  path: string,
  expected?: Uint8Array,
): Promise<void> {
  const { data: stored, error } = await admin.storage.from(BUCKET).download(path);
  if (error || !stored || stored.size === 0 || stored.size > MAX_OUTPUT_BYTES) {
    throw new Error("thumbnail_storage_download_failed");
  }
  const bytes = new Uint8Array(await stored.arrayBuffer());
  await validateThumbnail(bytes, stored.type.split(";", 1)[0].trim().toLowerCase(), MAX_OUTPUT_BYTES, MAX_SOURCE_PIXELS);
  if (expected && (bytes.length !== expected.length || !bytes.every((v, i) => v === expected[i]))) {
    throw new Error("thumbnail_storage_bytes_mismatch");
  }
}

function storagePathFromPublicUrl(
  value: string,
  supabaseUrl: string,
  expectedPrefix: string,
): string | null {
  try {
    const url = new URL(value);
    if (url.origin !== new URL(supabaseUrl).origin) return null;
    const marker = `/storage/v1/object/public/${BUCKET}/`;
    const index = url.pathname.indexOf(marker);
    if (index < 0) return null;
    const path = decodeURIComponent(url.pathname.substring(index + marker.length));
    return path.startsWith(expectedPrefix) ? path : null;
  } catch (_) {
    return null;
  }
}

async function shortSha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value),
  );
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("")
    .substring(0, 32);
}

export async function handleAdThumbnailRequest(req: Request): Promise<Response> {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return json({ ok: false, reason: "method_not_allowed" }, 405);
  }

  try {
    const token = bearerToken(req);
    if (!token) return json({ ok: false, reason: "unauthorized" }, 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !anonKey || !serviceRoleKey) {
      console.error("[ad-thumbnail] Missing Supabase environment variables");
      return json({ ok: false, reason: "server_configuration" }, 500);
    }

    const authClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: authData, error: authError } =
      await authClient.auth.getUser(token);
    if (authError || !authData.user) {
      return json({ ok: false, reason: "unauthorized" }, 401);
    }

    const body = await req.json().catch(() => null);
    const adId = typeof body?.ad_id === "string" ? body.ad_id.trim() : "";
    const force = body?.force === true;
    if (!adId) return json({ ok: false, reason: "ad_id_required" }, 400);

    const admin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: ad, error: lookupError } = await admin
      .from("pa_ads")
      .select("id,user_id,video_link,thumbnail_url")
      .eq("id", adId)
      .maybeSingle();

    if (lookupError) {
      console.error("[ad-thumbnail] Ad lookup failed:", lookupError);
      return json({ ok: false, reason: "lookup_failed" }, 500);
    }
    if (!ad) return json({ ok: false, reason: "not_found" }, 404);
    if (ad.user_id !== authData.user.id) {
      return json({ ok: false, reason: "forbidden" }, 403);
    }

    const existingUrl = typeof ad.thumbnail_url === "string"
      ? ad.thumbnail_url.trim()
      : "";
    const ownerPrefix = `${authData.user.id}/${ad.id}/`;
    const existingPath = storagePathFromPublicUrl(
      existingUrl,
      supabaseUrl,
      ownerPrefix,
    );
    let replaceInvalidObject = false;
    if (!force && existingPath) {
      try {
        await verifyStoredThumbnail(admin, existingPath);
        return json({ ok: true, skipped: "already_has_thumbnail", thumbnail_url: existingUrl });
      } catch (_) {
        // A name is not evidence of a valid image. Preserve corrupt evidence
        // and regenerate at a new immutable path instead of reusing the cache.
        replaceInvalidObject = true;
      }
    }

    const videoUrl = typeof ad.video_link === "string"
      ? ad.video_link.trim()
      : "";
    if (!isTikTokVideoUrl(videoUrl)) {
      return json({ ok: false, reason: "invalid_tiktok_url" }, 422);
    }

    const canonicalUrl = await resolveCanonicalTikTokUrl(videoUrl);
    if (!canonicalUrl) {
      return json({ ok: false, reason: "video_unavailable" }, 422);
    }

    const posterUrl = await tiktokPosterUrl(canonicalUrl);
    if (!posterUrl) return json({ ok: false, reason: "poster_unavailable" }, 422);

    const jpeg = await buildThumbnail(posterUrl);
    if (!jpeg) return json({ ok: false, reason: "image_unavailable" }, 422);

    // Validate the encoded output immediately before Storage receives bytes.
    // Never pass JSON.stringify(jpeg), a serialized Buffer, or a byte array object.
    await validateThumbnail(jpeg, "image/jpeg", MAX_OUTPUT_BYTES, MAX_SOURCE_PIXELS);
    await ensureBucket(admin);
    const videoHash = await shortSha256(canonicalUrl);
    const objectName = force || replaceInvalidObject
      ? `${videoHash}-${crypto.randomUUID()}`
      : videoHash;
    let objectPath = `${ownerPrefix}${objectName}.jpg`;
    const { error: uploadError } = await admin.storage
      .from(BUCKET)
      .upload(objectPath, jpeg, {
        contentType: "image/jpeg",
        cacheControl: "31536000",
        upsert: false,
      });
    const uploadErrorText = uploadError == null
      ? ""
      : uploadError.message ?? "";
    const alreadyExists = /already exists|asset exists|resource exists|duplicate|409/i
      .test(uploadErrorText);
    if (uploadError && !alreadyExists) {
      console.error("[ad-thumbnail] Upload failed:", uploadError);
      return json({ ok: false, reason: "upload_failed" }, 500);
    }

    try {
      await verifyStoredThumbnail(admin, objectPath, alreadyExists ? undefined : jpeg);
    } catch (_) {
      if (!alreadyExists) {
        return json({ ok: false, reason: "stored_image_verification_failed" }, 502);
      }
      // A corrupt deterministic object must not block retries or be published.
      objectPath = `${ownerPrefix}${videoHash}-${crypto.randomUUID()}.jpg`;
      const { error: retryError } = await admin.storage.from(BUCKET).upload(objectPath, jpeg, {
        contentType: "image/jpeg", cacheControl: "31536000", upsert: false,
      });
      if (retryError) return json({ ok: false, reason: "upload_failed" }, 500);
      try {
        await verifyStoredThumbnail(admin, objectPath, jpeg);
      } catch (_) {
        return json({ ok: false, reason: "stored_image_verification_failed" }, 502);
      }
    }

    const publicUrl = admin.storage.from(BUCKET).getPublicUrl(objectPath)
      .data.publicUrl;
    let update = admin
      .from("pa_ads")
      .update({ thumbnail_url: publicUrl })
      .eq("id", ad.id)
      .eq("user_id", authData.user.id)
      .eq("video_link", ad.video_link);
    // Compare-and-set prevents stale in-flight work replacing a newer result.
    update = ad.thumbnail_url == null
      ? update.is("thumbnail_url", null)
      : update.eq("thumbnail_url", ad.thumbnail_url);
    const { data: updated, error: updateError } = await update
      .select("id")
      .maybeSingle();

    if (updateError || !updated) {
      console.error("[ad-thumbnail] Database update failed:", updateError);
      return json({ ok: false, reason: "update_failed" }, 500);
    }

    // Keep prior and unreferenced objects for an explicit, separately approved
    // cleanup. Generation/repair must never delete legacy evidence.

    return json({ ok: true, thumbnail_url: publicUrl });
  } catch (error) {
    const timedOut = error instanceof DOMException && error.name === "AbortError";
    console.error("[ad-thumbnail] Unexpected failure:", error);
    return json(
      { ok: false, reason: timedOut ? "upstream_timeout" : "unexpected_error" },
      timedOut ? 504 : 500,
    );
  }
}
