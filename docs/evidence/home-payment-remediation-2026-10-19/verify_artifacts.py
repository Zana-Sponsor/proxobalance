"""Recheck published screenshot hashes and actual PDF/source pixel parity.

Run: python verify_artifacts.py
Dependencies for PDF comparison: PyMuPDF, Pillow, numpy.
This reads local evidence only and makes no network requests or changes.
"""
from pathlib import Path
import hashlib
import io
import json

import fitz
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent


def rgb_on_white(image):
    rgba = image.convert('RGBA')
    background = Image.new('RGBA', rgba.size, 'white')
    background.alpha_composite(rgba)
    return np.asarray(background.convert('RGB'))


manifest = json.loads((ROOT / 'capture-manifest.json').read_text())
for record in manifest['files']:
    for path_key, digest_key in [('path', 'sha256'),
                                 ('geometry', 'geometry_sha256')]:
        path = ROOT / record[path_key]
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        assert actual == record[digest_key], f'Hash mismatch: {path.name}'
    geometry = json.loads((ROOT / record['geometry']).read_text())
    assert geometry['layout_exceptions'] == 0, record['geometry']

parity = json.loads((ROOT / 'receipt-export-parity.json').read_text())
source_pixels = 0
page_count = 0
for record in parity['pdfs']:
    path = ROOT / record['pdf']
    assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256']
    source = rgb_on_white(Image.open(ROOT / record['source_png']))
    slices = []
    with fitz.open(path) as document:
        for page in document:
            images = page.get_images(full=True)
            assert len(images) == 1, (path.name, page.number)
            xref, mask, *_ = images[0]
            image = Image.open(io.BytesIO(document.extract_image(xref)['image']))
            if mask:
                image = image.convert('RGBA')
                alpha = Image.open(io.BytesIO(document.extract_image(mask)['image']))
                image.putalpha(alpha.convert('L'))
            slices.append(rgb_on_white(image))
            page_count += 1
    reconstructed = np.concatenate(slices)
    assert reconstructed.shape == source.shape, path.name
    assert np.array_equal(reconstructed, source), f'Pixel mismatch: {path.name}'
    source_pixels += source.shape[0] * source.shape[1]

print(json.dumps({'screenshots_and_geometry_validated': len(manifest['files']),
                  'pdfs_validated': len(parity['pdfs']),
                  'pdf_pages': page_count,
                  'exact_matching_source_pixels': source_pixels,
                  'changed_pixels': 0}, indent=2))
