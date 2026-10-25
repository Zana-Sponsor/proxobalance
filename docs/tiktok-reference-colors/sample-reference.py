"""Reproduce palette samples from the original JPEG, without modifying it.

Run with Python 3 and Pillow from any directory. Coordinates are physical pixels
inside the embedded app, excluding the blue marketing background/device frame.
"""
from pathlib import Path
from statistics import median
import hashlib
import json

from PIL import Image

root = Path(__file__).resolve().parents[2]
source = root / "docs/evidence/tiktok-reference-colors-2026-10-25/reference-user.jpg"
image = Image.open(source).convert("RGB")
regions = [
    ("primary", (590, 972, 810, 988), "all", "#0278FE"),
    ("secondary_fill", (460, 1415, 805, 1436), "all", "#EEF7FF"),
    ("secondary_border", (470, 1402, 790, 1403), "all", "#2663B4"),
    ("secondary_text", (565, 1440, 702, 1465), "blue_core", "#3D7EC2"),
    ("heading_ink", (318, 772, 623, 817), "dark_core", "#121215"),
    ("inactive_text", (140, 991, 255, 1024), "gray_core", "#747578"),
    ("inactive_border", (113, 984, 116, 1031), "all", "#EEEEEE"),
    ("new_badge", (370, 1397, 405, 1405), "all", "#FE6F61"),
    ("page_fill", (250, 1696, 650, 1714), "all", "#F6F9FE"),
    ("page_border", (208, 1680, 725, 1681), "all", "#CCD9E6"),
    ("white_surface", (500, 590, 650, 700), "all", "#FFFFFF"),
]
samples = []
for role, bounds, filter_name, implemented in regions:
    crop = image.crop(bounds)
    pixels = [crop.getpixel((x, y)) for y in range(crop.height) for x in range(crop.width)]
    if filter_name == "blue_core":
        pixels = [p for p in pixels if p[2] - p[0] > 65 and p[0] < 70]
    elif filter_name in ("dark_core", "gray_core"):
        limit = 60 if filter_name == "dark_core" else 130
        pixels = [p for p in pixels if max(p) - min(p) < 12 and max(p) < limit]
    rgb = [median(p[channel] for p in pixels) for channel in range(3)]
    measured_hex = "#" + "".join(f"{int(value):02X}" for value in rgb)
    assert measured_hex == implemented, (role, measured_hex, implemented)
    samples.append(dict(role=role, bounds_xyxy=bounds, filter=filter_name,
                        pixel_count=len(pixels), median_rgb=rgb,
                        measured_hex=measured_hex, implemented_hex=implemented))
result = dict(reference=source.name, sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
              size=list(image.size), method="Median of interior/core pixels; JPEG and antialiasing vary at edges.",
              samples=samples)
target = Path(__file__).with_name("palette-samples.json")
target.write_text(json.dumps(result, indent=2) + "\n")
print(f"Verified {len(samples)} sampled palette roles.")
