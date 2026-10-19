"""Disposable Android profile fixture: real rendering, no hosted operations."""
from pathlib import Path
import json
import os
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[1]
app = root / 'proxo_app'
output = app / 'build/polish-runtime'
output.mkdir(parents=True, exist_ok=True)
package = 'com.proxo.proxoapp'

def adb(*args, check=True):
    return subprocess.run(['adb', *args], check=check, capture_output=True).stdout

def screenshot(name):
    data = adb('exec-out', 'screencap', '-p')
    assert data.startswith(b'\x89PNG'), name
    (output / f'{name}.png').write_bytes(data)

adb('shell', 'wm', 'size', '1080x2340')
adb('shell', 'wm', 'density', '440')
adb('shell', 'settings', 'put', 'system', 'font_scale', '1.0')
adb('shell', 'settings', 'put', 'global', 'heads_up_notifications_enabled', '1')
metadata = {
    'fixture_only': True, 'mode': 'profile',
    'device': adb('shell', 'getprop', 'ro.product.model').decode().strip(),
    'android': adb('shell', 'getprop', 'ro.build.version.release').decode().strip(),
    'wm_size': adb('shell', 'wm', 'size').decode().strip(),
    'wm_density': adb('shell', 'wm', 'density').decode().strip(),
    'transport': 'Local Firebase builder fixture; FCM network delivery is not tested',
}
command = ['flutter', 'drive', '--profile', '--no-pub', '--keep-app-running',
           '--target=integration_test/polish_runtime_test.dart',
           '--driver=test_driver/polish_runtime_driver.dart', '-d', 'emulator-5554']
process = subprocess.Popen(command, cwd=app, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, text=True, bufsize=1,
                           env={**os.environ, 'FLUTTER_SUPPRESS_ANALYTICS':'true',
                                'DART_SUPPRESS_ANALYTICS':'true'})
with (output / 'driver.log').open('w') as log:
    for line in process.stdout:
        print(line, end='', flush=True)
        log.write(line); log.flush()
        if 'PROXO_POLISH_PERMISSION_READY' in line:
            adb('shell', 'pm', 'grant', package, 'android.permission.POST_NOTIFICATIONS')
        if 'PROXO_POLISH_KEYBOARD_READY' in line:
            screenshot('auth-keyboard-android')
            (output/'keyboard.log').write_bytes(adb('shell','dumpsys','input_method'))
            adb('shell','input','keyevent','KEYCODE_BACK')
            metadata['keyboard_captured'] = True
        if 'PROXO_POLISH_NOTIFICATION_VISIBLE' in line:
            screenshot('background-heads-up-android')
            adb('shell','cmd','statusbar','expand-notifications')
            time.sleep(.7)
            screenshot('background-notification-shade-android')
            (output/'notifications.log').write_bytes(adb('shell','dumpsys','notification','--noredact'))
            adb('shell','cmd','statusbar','collapse')
            adb('shell','am','start','-n',f'{package}/.PolishRuntimeActivity')
            metadata['background_notification_captured'] = True
result = process.wait()
metadata['exit_code'] = result
pull = subprocess.run(['adb', 'pull',
    f'/sdcard/Android/data/{package}/files/polish-runtime', str(output/'screens')],
    capture_output=True, text=True)
(output/'screenshot-transfer.log').write_text(pull.stdout + pull.stderr)
metadata['screenshot_transfer_exit_code'] = pull.returncode
captures = list((output/'screens').rglob('*.png'))
metadata['native_screenshot_count'] = len(captures)
assert all(p.read_bytes().startswith(b'\x89PNG') for p in captures)
(output/'device.json').write_text(json.dumps(metadata,indent=2))
if result:
    (output/'failure-logcat.log').write_bytes(adb('logcat','-d','-t','1500'))
    sys.exit(result)
data=json.loads((output/'runtime.json').read_text())
assert data['observations']['completed']
assert metadata.get('background_notification_captured')
assert metadata.get('keyboard_captured')
assert pull.returncode == 0, 'Android screenshots could not be pulled; see screenshot-transfer.log'
assert len(captures) >= 30, f'Only {len(captures)} native screenshots retained'
rows=[]
for name, summary in data.items():
    if not name.startswith('frames_'): continue
    row={'screen':name.removeprefix('frames_'),**summary}
    rows.append(row)
assert len(rows)>=30, len(rows)
(output/'performance-summary.json').write_text(json.dumps(rows,indent=2))
print(f'Profile runtime verified: {len(rows)} screen/action measurements; background logo captured.')
