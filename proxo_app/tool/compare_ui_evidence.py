"""Compare the unchanged capture harness outputs; never approve golden images.

Usage: python tool/compare_ui_evidence.py BASELINE_DIR CANDIDATE_DIR OUTPUT_JSON
Requires Pillow and PyMuPDF for pixel and PDF measurements.
"""
import collections
import hashlib
import json
from pathlib import Path
import sys

import fitz
from PIL import Image, ImageChops

baseline, candidate, destination = map(Path, sys.argv[1:])
components = {
    'ReceiptAppBar', 'ReceiptSurface', 'ReceiptCard', 'ReceiptHeader',
    'ReceiptRow', 'ReceiptDivider', 'ReceiptSectionHeading', 'ReceiptPdfButton',
    'TxHistoryCard', 'ProxoBottomNav', 'HomeQuickActions', 'ProxoBanner',
    'BestMetricsHomeSection', 'Icon',
}


def geometry(path):
    data = json.loads(path.read_text())
    counts = collections.Counter()
    result = []
    for node in data['nodes']:
        kind = node['widget']
        if kind not in components and not node.get('key') and kind != 'RichText':
            continue
        counts[kind] += 1
        result.append({**node, 'occurrence': counts[kind]})
    return {**{k: v for k, v in data.items() if k != 'nodes'}, 'components': result}


report = {
    'method': 'Raw RenderBox bounds in logical pixels, unrounded; pixel diff counts exact RGB inequality. Changes are not pass/fail thresholds. RichText font_size is the style size before text scaling. Off-viewport nodes remain recorded.',
    'runtime': 'Flutter 3.47.2 Linux widget-test renderer; fictional records; not native Android',
    'screens': {}, 'pdfs': {},
}
for after in sorted(candidate.glob('*.json')):
    before = baseline / after.name
    row = {'after': geometry(after)}
    if before.exists():
        row['before'] = geometry(before)
        a = Image.open(before.with_suffix('.png')).convert('RGB')
        b = Image.open(after.with_suffix('.png')).convert('RGB')
        row['png_size_px'] = list(b.size)
        if a.size == b.size:
            diff = ImageChops.difference(a, b)
            row['pixel_diff'] = {
                'changed_pixels': sum(p != (0, 0, 0) for p in diff.getdata()),
                'bounding_box_px': diff.getbbox(),
                'total_pixels': a.width * a.height,
            }
    report['screens'][after.stem] = row

for source, directory in [('before', baseline), ('after', candidate)]:
    for path in sorted(directory.glob('*.pdf')):
        document = fitz.open(path)
        report['pdfs'].setdefault(path.name, {})[source] = {
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'pages': [{
                'size_pt': [page.rect.width, page.rect.height],
                'image_bounds_pt': [list(image['bbox']) for image in page.get_image_info()],
            } for page in document],
        }

destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'screens': len(report['screens']), 'pdfs': len(report['pdfs']), 'output': str(destination)}))
