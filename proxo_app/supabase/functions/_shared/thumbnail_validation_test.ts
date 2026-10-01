import { Image } from "https://deno.land/x/imagescript@1.2.15/mod.ts";
import { validateThumbnail } from "./thumbnail_validation.ts";

async function mustReject(bytes: Uint8Array, mime = "image/jpeg", maxBytes = 1048576, maxPixels = 16777216) {
  let rejected = false;
  try { await validateThumbnail(bytes, mime, maxBytes, maxPixels); } catch { rejected = true; }
  if (!rejected) throw new Error("Invalid thumbnail was accepted");
}

Deno.test("valid binary JPEG and PNG pass; serialized Buffer never passes", async () => {
  const image = new Image(4, 4).fill(0x046cfaff);
  const jpeg = await image.encodeJPEG(80);
  const png = await image.encode();
  await validateThumbnail(jpeg, "image/jpeg", 1048576, 16777216);
  await validateThumbnail(png, "image/png", 1048576, 16777216);
  const json = new TextEncoder().encode(JSON.stringify({ type: "Buffer", data: Array.from(jpeg) }));
  await mustReject(json);
  await mustReject(new Uint8Array());
  await mustReject(new TextEncoder().encode("not an image"));
  await mustReject(new Uint8Array([255, 216, 255]));
  await mustReject(jpeg, "image/png");
  await mustReject(jpeg, "image/jpeg", 2);
  await mustReject(jpeg, "image/jpeg", 1048576, 1);
});

Deno.test("WebP bytes decode, MIME mismatch and HTML/JSON arrays fail", async () => {
  const webp = Uint8Array.from([82, 73, 70, 70, 60, 0, 0, 0, 87, 69, 66, 80, 86, 80, 56, 32, 48, 0, 0, 0, 16, 2, 0, 157, 1, 42, 4, 0, 4, 0, 1, 64, 38, 37, 160, 2, 116, 186, 1, 248, 1, 248, 0, 3, 200, 0, 254, 239, 189, 87, 254, 250, 1, 110, 115, 247, 251, 169, 255, 236, 102, 32, 174, 107, 239, 228, 0, 0]);
  if (await validateThumbnail(webp, "image/webp", 1024 * 1024, 16 * 1024 * 1024) !== "image/webp") throw new Error("WebP failed");
  for (const text of ["<html>upstream error</html>", "[255,216,255]", '{ "data": [255,216,255] }']) {
    let rejected = false;
    try { await validateThumbnail(new TextEncoder().encode(text), "image/jpeg", 1024 * 1024, 16 * 1024 * 1024); } catch (_) { rejected = true; }
    if (!rejected) throw new Error("text accepted");
  }
});
