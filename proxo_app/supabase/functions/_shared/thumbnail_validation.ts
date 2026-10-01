import { decode, Image } from "https://deno.land/x/imagescript@1.2.15/mod.ts";

import createWebpDecoder from "./vendor/webp_dec.js";
import { webpWasm } from "./vendor/webp_wasm.ts";

let webpDecoder: Promise<any> | undefined;
export async function decodeThumbnail(bytes: Uint8Array): Promise<Image> {
  if (thumbnailMime(bytes) !== "image/webp") {
    const image = await decode(bytes);
    if (!(image instanceof Image)) throw new Error("thumbnail_not_still_image");
    return image;
  }
  // The pinned WebP decoder is bundled, so production needs no codec download.
  // Deno may not provide the DOM ImageData constructor used by libwebp's glue.
  const globals = globalThis as unknown as { ImageData?: unknown };
  globals.ImageData ??= class {
    data: Uint8ClampedArray; width: number; height: number;
    constructor(data: Uint8ClampedArray, width: number, height: number) {
      this.data = data; this.width = width; this.height = height;
    }
  };
  webpDecoder ??= (async () => {
    const binary = Uint8Array.from(atob(webpWasm), c => c.charCodeAt(0));
    const module = await WebAssembly.compile(binary);
    return await createWebpDecoder({
      noInitialRun: true,
      instantiateWasm(imports: WebAssembly.Imports, ready: (instance: WebAssembly.Instance) => void) {
        const instance = new WebAssembly.Instance(module, imports);
        ready(instance);
        return instance.exports;
      },
    });
  })();
  const result = (await webpDecoder).decode(bytes);
  if (!result || result.width <= 0 || result.height <= 0 || result.width * result.height > 16 * 1024 * 1024) {
    throw new Error("thumbnail_invalid_webp");
  }
  const image = new Image(result.width, result.height);
  image.bitmap.set(result.data);
  return image;
}

export type ThumbnailMime = "image/jpeg" | "image/png" | "image/webp";

export function thumbnailMime(bytes: Uint8Array): ThumbnailMime | null {
  if (!(bytes instanceof Uint8Array)) return null;
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  const png = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
  if (bytes.length >= 8 && png.every((b, i) => bytes[i] === b)) return "image/png";
  if (bytes.length >= 12 && bytes[0] === 0x52 && bytes[1] === 0x49 &&
    bytes[2] === 0x46 && bytes[3] === 0x46 && bytes[8] === 0x57 &&
    bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) return "image/webp";
  return null;
}

/** Reject JSON/text, empty, oversized, mislabeled and undecodable payloads.
 * Validation applies to actual bytes, never the filename or MIME alone.
 */
export async function validateThumbnail(
  bytes: Uint8Array,
  declaredMime: string,
  maxBytes: number,
  maxPixels: number,
): Promise<ThumbnailMime> {
  if (!(bytes instanceof Uint8Array) || bytes.byteLength === 0 || bytes.byteLength > maxBytes) {
    throw new Error("thumbnail_invalid_size_or_type");
  }
  const mime = thumbnailMime(bytes);
  if (!mime) throw new Error("thumbnail_invalid_image_signature");
  if (mime !== declaredMime) throw new Error("thumbnail_mime_mismatch");
  const image = await decodeThumbnail(bytes);
  if (!(image instanceof Image) || image.width <= 0 || image.height <= 0 || image.width * image.height > maxPixels) {
    throw new Error("thumbnail_invalid_dimensions");
  }
  return mime;
}
