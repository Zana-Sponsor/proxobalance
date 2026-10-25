#!/usr/bin/env python3
"""Inventory opt-in Flutter captures without altering image pixels."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from datetime import datetime, timezone
from pathlib import Path

from PIL import Image


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument('evidence_directory', type=Path)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    base = args.evidence_directory.resolve()
    files = []
    for path in sorted(base.rglob('*')):
        if not path.is_file() or path.suffix.lower() not in {'.png', '.pdf'}:
            continue
        relative = path.relative_to(base).as_posix()
        match = re.search(r'-(\d+)x(\d+)$', path.stem)
        viewport = [int(match[1]), int(match[2])] if match else None
        label_stem = path.stem[:match.start()] if match else path.stem
        item = {
            'file': relative,
            'label': label_stem.replace('-', ' ').replace('_', ' ').title(),
            'format': path.suffix.lower().lstrip('.'),
            'viewport_logical_pixels': viewport,
            'synthetic_sample_data': True,
            'bytes': path.stat().st_size,
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
        }
        if path.suffix.lower() == '.png':
            with Image.open(path) as picture:
                item['image_pixels'] = list(picture.size)
            item['capture_extent'] = (
                'screen' if viewport and item['image_pixels'] == [2 * n for n in viewport]
                else 'component_or_export'
            )
        if path.parent.name == 'receipt-pdfs':
            metadata_path = path.with_suffix('.json')
            metadata = json.loads(metadata_path.read_text()) if metadata_path.exists() else {}
            narrow = 'narrow' in path.stem
            item['viewport_logical_pixels'] = [280 if narrow else 393, 640]
            item['text_scale'] = 2 if narrow else 1
            item['capture_extent'] = 'actual_full_receipt_export'
            item['component_logical_pixels'] = [metadata.get('width'), metadata.get('height')]
            item['language'] = 'ar' if narrow and 'transaction' in path.stem else 'ckb'
            kind = 'Payment' if 'transaction' in path.stem else 'Advertisement'
            state = 'narrow, 200 percent text' if narrow else 'standard, 100 percent text'
            item['label'] = f'{kind} receipt actual export ({state})'
            if item['format'] == 'png':
                item['render_pixels_per_logical_pixel'] = 4
        else:
            item['text_scale'] = 1.5 if 'profile-missing-large-text' in path.stem else 1
            item['language'] = 'ckb'
            item['render_pixels_per_logical_pixel'] = 2
        files.append(item)
    manifest = {
        'generated_at_utc': datetime.now(timezone.utc).isoformat(),
        'flutter_version': '3.47.2',
        'dart_version': '3.13.2',
        'renderer': 'Flutter test engine; actual production widget trees',
        'fixture_notice': 'Synthetic local data. No live payment, OTP, or account deletion.',
        'limitations': [
            'Widget captures are not screenshots from a physical Android/iOS device.',
            'Pages reopen behavior uses a controlled repository, not a live database.',
            'Template preview fixture deliberately shows retrieval failure and retry.',
            'Full Home combines production widgets with fixture records, excluding remote initialization.',
            'Operating-system share/print sheets, real keyboards, and payment settlement are not tested.',
        ],
        'png_count': sum(item['format'] == 'png' for item in files),
        'pdf_count': sum(item['format'] == 'pdf' for item in files),
        'files': files,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    print(json.dumps({key: manifest[key] for key in ('png_count', 'pdf_count')}))


if __name__ == '__main__':
    main()
