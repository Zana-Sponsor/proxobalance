"""Compare the unchanged capture harness outputs; never approve golden images.

Usage: python tool/compare_ui_evidence.py BASELINE_DIR CANDIDATE_DIR OUTPUT_JSON
Requires Pillow and PyMuPDF for pixel and PDF measurements.
"""
import collections
import csv
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
with destination.with_suffix('.csv').open('w') as handle:
    columns = ['capture', 'component', 'before_bounds_dp', 'after_bounds_dp',
               'delta_xywh_dp', 'before_font_sp', 'after_font_sp', 'acceptance']
    writer = csv.DictWriter(handle, fieldnames=columns)
    writer.writeheader()
    def index_components(snapshot):
        indexed = {}
        seen = collections.Counter()
        for node in snapshot.get('components', []):
            kind, key = node['widget'], node.get('key') or ''
            if kind not in components and kind != 'RichText' and not key.startswith("[<'home-"):
                continue
            identity = key if key.startswith("[<'home-") else kind + ':' + node.get('text', '')
            seen[identity] += 1
            indexed[f'{identity}#{seen[identity]}'] = node
        return indexed
    for capture, data in report['screens'].items():
        before = index_components(data.get('before', {}))
        after = index_components(data['after'])
        for identity in dict.fromkeys([*before, *after]):
            old, new = before.get(identity, {}), after.get(identity, {})
            a, b = old.get('bounds_dp'), new.get('bounds_dp')
            writer.writerow({
                'capture': capture, 'component': identity,
                'before_bounds_dp': json.dumps(a), 'after_bounds_dp': json.dumps(b),
                'delta_xywh_dp': json.dumps([y-x for x,y in zip(a,b)]) if a and b else '',
                'before_font_sp': old.get('font_size', ''), 'after_font_sp': new.get('font_size', ''),
                'acceptance': 'review required; measured, not approved',
            })
print(json.dumps({'screens': len(report['screens']), 'pdfs': len(report['pdfs']), 'output': str(destination)}))
