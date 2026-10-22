#!/usr/bin/env python3
"""Compare actual Flutter receipt pixels with the immutable original artwork.

Requires Pillow and NumPy. Writes JSON only; never changes or generates images.
Run from any directory: python verify_reference.py
Optional --actual, --reference, --uploaded and --output override the inputs.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path

import numpy as np
from PIL import Image


EVIDENCE = Path(__file__).resolve().parent
REPO = EVIDENCE.parents[2]
APP = REPO / "proxo_app"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def describe(path: Path) -> dict:
    with Image.open(path) as image:
        return {
            "file": str(path.relative_to(REPO)) if path.is_relative_to(REPO) else path.name,
            "sha256": sha256(path),
            "width_px": image.width,
            "height_px": image.height,
            "mode": image.mode,
        }


def rgba(path: Path) -> np.ndarray:
    with Image.open(path) as image:
        return np.asarray(image.convert("RGBA"))


def difference(actual: np.ndarray, expected: np.ndarray) -> dict:
    if actual.shape != expected.shape:
        raise ValueError(f"Image shapes differ: {actual.shape} != {expected.shape}")
    delta = np.abs(actual.astype(np.int16) - expected.astype(np.int16))
    changed = np.any(delta != 0, axis=2)
    within_one = np.all(delta <= 1, axis=2)
    return {
        "pixels_compared": int(changed.size),
        "channels_compared": int(delta.size),
        "differing_pixels": int(changed.sum()),
        "exact_pixels": int((~changed).sum()),
        "exact_pixel_fraction": float((~changed).mean()),
        "mean_absolute_channel_error": float(delta.mean()),
        "maximum_channel_error": int(delta.max()),
        "pixels_within_one_channel_level": int(within_one.sum()),
        "fraction_within_one_channel_level": float(within_one.mean()),
    }


def uniform_bilinear(source: np.ndarray, width: int, height: int) -> tuple[np.ndarray, float]:
    """In-memory comparison model: uniform height scale, pixel-center sampling.

    The fractional final column is omitted, matching the attachment dimensions.
    Round final RGB samples to nearest integer. This is a comparison model,
    not a claim about the upload service's unknown implementation.
    """
    scale = height / source.shape[0]
    x = (np.arange(width) + 0.5) / scale - 0.5
    y = (np.arange(height) + 0.5) / scale - 0.5
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    fx, fy = x - x0, y - y0
    x1 = np.clip(x0 + 1, 0, source.shape[1] - 1)
    y1 = np.clip(y0 + 1, 0, source.shape[0] - 1)
    x0 = np.clip(x0, 0, source.shape[1] - 1)
    y0 = np.clip(y0, 0, source.shape[0] - 1)
    result = np.empty((height, width, 3), dtype=np.uint8)
    for start in range(0, height, 128):
        stop = min(start + 128, height)
        top = (
            source[y0[start:stop, None], x0[None, :], :3] * (1 - fx)[None, :, None]
            + source[y0[start:stop, None], x1[None, :], :3] * fx[None, :, None]
        )
        bottom = (
            source[y1[start:stop, None], x0[None, :], :3] * (1 - fx)[None, :, None]
            + source[y1[start:stop, None], x1[None, :], :3] * fx[None, :, None]
        )
        result[start:stop] = np.rint(
            top * (1 - fy[start:stop, None, None])
            + bottom * fy[start:stop, None, None]
        ).astype(np.uint8)
    return result, scale


def divider_bands(image: np.ndarray) -> list[dict]:
    color = np.array([229, 231, 235])
    mask = np.all(image[:, :, :3] == color, axis=2)
    lines = np.flatnonzero(mask.sum(axis=1) > image.shape[1] * 0.65)
    groups: list[list[int]] = []
    for y in lines:
        if not groups or y != groups[-1][-1] + 1:
            groups.append([int(y)])
        else:
            groups[-1].append(int(y))
    bands = []
    for group in groups:
        xs = np.flatnonzero(mask[group[len(group) // 2]])
        bands.append({
            "x_start_px": int(xs.min()), "x_end_exclusive_px": int(xs.max() + 1),
            "y_start_px": group[0], "y_end_exclusive_px": group[-1] + 1,
        })
    return bands


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--actual", type=Path, default=EVIDENCE / "ad-reference-393dp-4x.png")
    parser.add_argument("--reference", type=Path, default=APP / "docs/receipt_preview.png")
    parser.add_argument("--uploaded", type=Path, default=EVIDENCE / "reference-upload.png")
    parser.add_argument("--output", type=Path, default=EVIDENCE / "comparison.json")
    args = parser.parse_args()
    actual, reference, uploaded = (rgba(path) for path in (args.actual, args.reference, args.uploaded))
    upload_model, scale = uniform_bilinear(reference, uploaded.shape[1], uploaded.shape[0])
    exact = difference(actual, reference)
    source_files = [
        "lib/widgets/receipt/receipt_kit.dart",
        "lib/widgets/receipt/ad_receipt_card.dart",
        "test/receipt_reference_match_test.dart",
    ]
    report = {
        "schema_version": 1,
        "inputs": {
            "actual_flutter_capture": describe(args.actual),
            "immutable_repository_reference": describe(args.reference),
            "provided_attachment": describe(args.uploaded),
        },
        "actual_vs_reference_rgba": exact,
        "png_bytes_identical": args.actual.read_bytes() == args.reference.read_bytes(),
        "provided_attachment_resize_comparison": {
            "model": "Uniform height scale; pixel-center bilinear RGB interpolation; round to nearest; omit fractional final column",
            "scale": scale,
            "full_scaled_width": reference.shape[1] * scale,
            "attachment_width": uploaded.shape[1],
            "rgb_difference": difference(uploaded[:, :, :3], upload_model),
            "attachment_alpha_min_max": [int(uploaded[:, :, 3].min()), int(uploaded[:, :, 3].max())],
            "limit": "The attachment is resized. Its original upload-resampler implementation is unknown; this comparison is near-equivalence, not a claim of exact resized-byte reproduction.",
        },
        "canonical_geometry_dp": {
            "surface_size": [393, 627], "capture_scale": 4,
            "card_rect_xywh": [16, 16, 361, 591], "card_radius": 16,
            "card_padding_horizontal_vertical": [16, 20],
            "data_row_x_start_end": [32, 361], "data_row_height": 20,
            "data_row_gap": 8, "label_value_gap": 8,
            "data_row_tops": [79, 107, 180, 208, 236, 264, 292, 365, 393, 421, 494, 539, 567],
            "data_rows": 13, "section_headings": 3, "dividers": 5,
            "divider_x_start_end": [40, 353], "divider_thickness": 1,
            "divider_tops": [66, 139, 324, 453, 526],
            "divider_gap_before_after": [12, 12], "heading_gap_after": 12,
            "logo_rect_xywh": [32, 36, 18 * 1200 / 345, 18],
            "surface_bottom_margin": 20,
        },
        "measured_original_divider_pixel_bands": divider_bands(reference),
        "measured_attachment_divider_pixel_bands": divider_bands(uploaded),
        "typography_and_colors": {
            "font_asset": "assets/fonts/Rabar_021.ttf", "font_sha256": sha256(APP / "assets/fonts/Rabar_021.ttf"),
            "font_metadata_family_subfamily_weight": ["Rabar_021", "Bold", 700],
            "flutter_weight": 400, "line_height": 1.25,
            "heading_sp": 13, "field_and_identifier_sp": 11, "total_sp": 12,
            "page_and_card": "#FFFFFF", "text": "#111111",
            "section_heading": "#046CFA", "divider": "#E5E7EB",
            "shadow_argb_blur_offset": ["#0F000000", 18, [0, 5]],
            "logo_asset": "assets/images/proxo_logo.png", "logo_source_pixels": [1200, 345],
            "logo_sha256": sha256(APP / "assets/images/proxo_logo.png"),
        },
        "provenance": {
            "reference_first_committed": "f539e7e",
            "exact_geometry_reference_commit": "a4149de503ae0e9d487a31cabc536fb51ee6c533",
            "reference_git_blob": "ddf44b9182fca85047f0591dc8bbab22a0f74c7c",
            "capture_test": "proxo_app/test/receipt_reference_match_test.dart",
            "capture_method": "Actual AdReceiptCard inside ReceiptSurface; real bundled font and logo; fictional fixture; RepaintBoundary.toImage(pixelRatio: 4)",
            "reference_not_regenerated": True,
            "source_base_head_at_comparison": subprocess.check_output(["git", "-C", str(REPO), "rev-parse", "HEAD"], text=True).strip(),
            "source_file_sha256": {f"proxo_app/{path}": sha256(APP / path) for path in source_files},
        },
        "limits": [
            "Exact pixel match applies to this 393dp, 100% text, fictional advertisement fixture and Flutter capture renderer.",
            "The reference excludes the app bar and PDF button. Payment receipts use the shared design but contain different data and are not compared to advertisement pixels.",
            "No image was edited to create a match. Uploaded resize comparison is performed in memory only.",
        ],
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({"report": str(args.output), "exact_rgba": exact["differing_pixels"] == 0,
                      "differing_pixels": exact["differing_pixels"],
                      "uploaded_rgb_mae": report["provided_attachment_resize_comparison"]["rgb_difference"]["mean_absolute_channel_error"]}))
    return 0 if exact["differing_pixels"] == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
