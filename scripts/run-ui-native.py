"""Hosted-CI-only Android input orchestration; no credentials or network data."""
import json
import os
import re
import signal
from pathlib import Path
import subprocess
import sys
import threading

OUTPUT = Path('build/ui-native')
OUTPUT.mkdir(parents=True, exist_ok=True)

def adb(*args):
    return subprocess.check_output(['adb', *args], text=True, timeout=20).strip()

def stop_drive(group_id, metadata):
    metadata['drive_timed_out'] = True
    print('Android fixture driver exceeded its 600-second limit', flush=True)
    try:
        os.killpg(group_id, signal.SIGKILL)
    except ProcessLookupError:
        pass

configurations = [('phone', '1179x2556', '480'),
                  ('narrow', '840x2556', '480'),
                  ('tablet', '1536x1704', '320')]
selected = os.environ.get('UI_CONFIG')
if selected:
    if selected not in {item[0] for item in configurations}:
        raise ValueError('Unknown native fixture configuration')
    configurations = [item for item in configurations if item[0] == selected]

for name, size, density in configurations:
    # Each CI matrix job has a fresh emulator; clear stale app/VM discovery
    # state as well when this script is used sequentially during debugging.
    adb('shell', 'am', 'force-stop', 'com.proxo.proxoapp')
    adb('forward', '--remove-all')
    adb('logcat', '-c')
    adb('shell', 'wm', 'size', size)
    adb('shell', 'wm', 'density', density)
    adb('shell', 'settings', 'put', 'secure', 'show_ime_with_hard_keyboard', '1')
    metadata = {'size': adb('shell', 'wm', 'size'),
                'density': adb('shell', 'wm', 'density'), 'adb_back_events': 0,
                'adb_tap_events': [],
                'adb_screenshots': [], 'drive_timeout_seconds': 600,
                'drive_timed_out': False}
    command = ['flutter', 'drive', '--debug', '-d', 'emulator-5554',
               '--driver=test_driver/ui_iconography_driver.dart',
               '--target=integration_test/ui_iconography_test.dart',
               f'--dart-define=UI_CONFIG={name}']
    with (OUTPUT / f'{name}.log').open('w') as log:
        process = subprocess.Popen(command, stdout=subprocess.PIPE,
                                   stderr=subprocess.STDOUT, text=True, bufsize=1,
                                   start_new_session=True)
        watchdog = threading.Timer(600, stop_drive, args=(process.pid, metadata))
        watchdog.daemon = True
        watchdog.start()
        for line in process.stdout:
            log.write(line)
            log.flush()
            print(line, end='', flush=True)
            if 'PROXO_UI_NATIVE_NOTIFICATIONS_READY' in line:
                adb('shell', 'pm', 'grant', 'com.proxo.proxoapp',
                    'android.permission.POST_NOTIFICATIONS')
            match = re.search(r'PROXO_UI_NATIVE_SCREENSHOT:([a-z0-9.\-]+)', line)
            if match:
                shot_name = match.group(1)
                if not shot_name.startswith(name + '-chrome-'):
                    raise RuntimeError('Unexpected screenshot checkpoint')
                png = subprocess.check_output(['adb', 'exec-out', 'screencap', '-p'], timeout=20)
                if not png.startswith(b'\x89PNG\r\n\x1a\n'):
                    raise RuntimeError('Android screenshot was not PNG')
                (OUTPUT / f'{shot_name}-adb.png').write_bytes(png)
                metadata['adb_screenshots'].append(shot_name)
            if 'PROXO_UI_NATIVE_BACK_READY' in line:

                adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
                metadata['adb_back_events'] += 1
            tap = re.search(r'PROXO_UI_NATIVE_TAP:(\d+):(\d+)', line)
            if tap:
                x, y = map(int, tap.groups())
                width, height = map(int, re.findall(r'(\d+)x(\d+)', metadata['size'])[-1])
                if not (0 < x < width and 0 < y < height):
                    raise RuntimeError('Native tap checkpoint is outside the device')
                adb('shell', 'input', 'tap', str(x), str(y))
                metadata['adb_tap_events'].append([x, y])
        result = process.wait()
        watchdog.cancel()
    (OUTPUT / f'{name}-device.json').write_text(json.dumps(metadata, indent=2))
    if result:
        # Preserve OS focus/IME evidence when the driver cannot finish. These
        # disposable emulators contain only the credential-free test fixtures.
        for label, args in [('input-method', ('shell', 'dumpsys', 'input_method')),
                            ('window', ('shell', 'dumpsys', 'window', 'windows')),
                            ('logcat', ('logcat', '-d', '-t', '1500'))]:
            try:
                (OUTPUT / f'{name}-{label}.log').write_text(adb(*args))
            except (subprocess.SubprocessError, OSError) as error:
                metadata[f'{label}_capture_error'] = str(error)
        (OUTPUT / f'{name}-device.json').write_text(json.dumps(metadata, indent=2))
    if (result or metadata['adb_back_events'] != 1 or
            len(metadata['adb_tap_events']) != 2 or len(metadata['adb_screenshots']) != 2):
        sys.exit(result or 1)
