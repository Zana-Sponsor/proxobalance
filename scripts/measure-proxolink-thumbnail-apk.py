"""Compare only the thumbnail bundle in two release builds of the same revision.

Runs in disposable, credential-free source CI. Restores the current PNGs and APK
even if the old-assets build fails. Never changes renderer acceptance.
"""
import hashlib
import json
import pathlib
import subprocess
import tempfile
import zipfile

root = pathlib.Path(__file__).resolve().parents[1]
app = root / 'proxo_app'
assets = app / 'assets/proxolink_thumbnails'
apk = app / 'build/app/outputs/flutter-apk/app-release.apk'
reference = '3c4a92834ac5249858b299911bece93edb665fc2'


def inventory(path):
    with zipfile.ZipFile(path) as archive:
        entries = [i for i in archive.infolist() if '/assets/proxolink_thumbnails/' in i.filename and i.filename.endswith('.png')]
        assert len(entries) == 12
        return {'apk_bytes': path.stat().st_size,
                'thumbnail_compressed_bytes': sum(i.compress_size for i in entries),
                'thumbnail_uncompressed_bytes': sum(i.file_size for i in entries)}


subprocess.run(['git', 'fetch', '--depth=1', 'origin', reference], cwd=root, check=True)
current = inventory(apk)
with tempfile.TemporaryDirectory(prefix='proxolink-thumbnail-size-') as directory:
    saved = pathlib.Path(directory)
    saved_apk = saved / 'current.apk'
    saved_apk.write_bytes(apk.read_bytes())
    originals = {p: p.read_bytes() for p in assets.glob('*.png')}
    assert len(originals) == 12
    try:
        for path in originals:
            relative = path.relative_to(root).as_posix()
            path.write_bytes(subprocess.check_output(['git', 'show', f'{reference}:{relative}'], cwd=root))
        subprocess.run(['flutter', 'build', 'apk', '--release', '--no-tree-shake-icons'], cwd=app, check=True)
        old = inventory(apk)
    finally:
        for path, data in originals.items():
            path.write_bytes(data)
        apk.write_bytes(saved_apk.read_bytes())

result = {'method': 'same current code and release configuration; only twelve PNG assets replaced',
          'reference_assets_revision': reference,
          'current_revision': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip(),
          'before': old, 'after': current,
          'delta': {key: current[key] - old[key] for key in current},
          'note': 'APK byte delta includes any rebuild packaging variation; ZIP thumbnail byte deltas directly measure assets.',
          'restored_current_assets_and_apk': True,
          'asset_sha256': {p.name: hashlib.sha256(data).hexdigest() for p, data in originals.items()}}
target = app / 'build/ui-verification/thumbnail-apk-size.json'
target.parent.mkdir(parents=True, exist_ok=True)
target.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result))
