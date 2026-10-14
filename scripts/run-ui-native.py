"""Hosted-CI-only Android input orchestration; no credentials or network data."""
import json
from pathlib import Path
import subprocess
import sys

OUTPUT = Path('build/ui-native')
OUTPUT.mkdir(parents=True, exist_ok=True)

def adb(*args):
    return subprocess.check_output(['adb', *args], text=True, timeout=20).strip()

for name, size, density in [('phone', '1179x2556', '480'),
                            ('narrow', '840x2556', '480'),
                            ('tablet', '1536x1704', '320')]:
    adb('shell', 'wm', 'size', size)
    adb('shell', 'wm', 'density', density)
    adb('shell', 'settings', 'put', 'secure', 'show_ime_with_hard_keyboard', '1')
    metadata = {'size': adb('shell', 'wm', 'size'),
                'density': adb('shell', 'wm', 'density'), 'adb_back_events': 0}
    command = ['flutter', 'drive', '--debug', '-d', 'emulator-5554',
               '--driver=test_driver/ui_iconography_driver.dart',
               '--target=integration_test/ui_iconography_test.dart',
               f'--dart-define=UI_CONFIG={name}']
    with (OUTPUT / f'{name}.log').open('w') as log:
        process = subprocess.Popen(command, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, bufsize=1)
        for line in process.stdout:
            log.write(line)
            print(line, end='', flush=True)
            if 'PROXO_UI_NATIVE_BACK_READY' in line:
                adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
                metadata['adb_back_events'] += 1
        result = process.wait()
    (OUTPUT / f'{name}-device.json').write_text(json.dumps(metadata, indent=2))
    if result or metadata['adb_back_events'] != 1:
        sys.exit(result or 1)
