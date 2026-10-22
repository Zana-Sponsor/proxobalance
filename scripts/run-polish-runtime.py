"""Disposable Android profile fixture: real rendering, no hosted operations."""
from pathlib import Path
import codecs
import json
import os
import selectors
import signal
import subprocess
import sys
import threading
import time
import traceback

root = Path(__file__).resolve().parents[1]
app = root / 'proxo_app'
package = 'com.proxo.proxoapp'
DRIVE_TIMEOUT_SECONDS = 20 * 60
MENU_BACK_ACK_TIMEOUT_SECONDS = 15
COMMAND = ['flutter', 'drive', '--profile', '--no-pub', '--keep-app-running',
           '--target=integration_test/polish_runtime_test.dart',
           '--driver=test_driver/polish_runtime_driver.dart', '-d', 'emulator-5554']


def adb(*args, check=True):
    return subprocess.run(['adb', *args], check=check, capture_output=True, timeout=30).stdout


def screenshot(output, name):
    data = adb('exec-out', 'screencap', '-p')
    assert data.startswith(b'\x89PNG'), name
    (output / f'{name}.png').write_bytes(data)


def configure(metadata):
    adb('shell', 'wm', 'size', '1080x2340')
    adb('shell', 'wm', 'density', '440')
    adb('shell', 'settings', 'put', 'system', 'font_scale', '1.0')
    adb('shell', 'settings', 'put', 'secure', 'show_ime_with_hard_keyboard', '1')
    adb('shell', 'settings', 'put', 'global', 'heads_up_notifications_enabled', '1')
    metadata.update({
        'device': adb('shell', 'getprop', 'ro.product.model').decode().strip(),
        'android': adb('shell', 'getprop', 'ro.build.version.release').decode().strip(),
        'wm_size': adb('shell', 'wm', 'size').decode().strip(),
        'wm_density': adb('shell', 'wm', 'density').decode().strip(),
        'transport': 'Local Firebase builder fixture; FCM network delivery is not tested',
    })


def capture_event(line, output, metadata):
    if 'PROXO_POLISH_PERMISSION_READY' in line:
        adb('shell', 'pm', 'grant', package, 'android.permission.POST_NOTIFICATIONS')
    if 'PROXO_POLISH_PHONE_INPUT_READY' in line:
        adb('shell', 'input', 'text', '7501234567')
        metadata['phone_input_injected'] = True
    if 'PROXO_POLISH_MENU_BACK_READY' in line:
        adb('shell', 'input', 'keyevent', 'KEYCODE_BACK')
        metadata['menu_android_back_injected'] = True
    if 'PROXO_POLISH_AD_INPUT_READY' in line:
        adb('shell', 'input', 'text', 'Recovered-ad')
        metadata['ad_error_input_injected'] = True
    if 'PROXO_POLISH_AD_KEYBOARD_READY' in line:
        screenshot(output, 'ad-error-keyboard-android')
        (output/'ad-keyboard.log').write_bytes(adb('shell','dumpsys','input_method'))
        adb('shell','input','keyevent','KEYCODE_BACK')
        metadata['ad_error_keyboard_captured'] = True
    if 'PROXO_POLISH_KEYBOARD_READY' in line:
        screenshot(output, 'auth-keyboard-android')
        (output/'keyboard.log').write_bytes(adb('shell','dumpsys','input_method'))
        adb('shell','input','keyevent','KEYCODE_BACK')
        metadata['keyboard_captured'] = True
    if 'PROXO_POLISH_NOTIFICATION_VISIBLE' in line:
        screenshot(output, 'background-heads-up-android')
        adb('shell','cmd','statusbar','expand-notifications')
        time.sleep(.7)
        screenshot(output, 'background-notification-shade-android')
        (output/'notifications.log').write_bytes(adb('shell','dumpsys','notification','--noredact'))
        adb('shell','cmd','statusbar','collapse')
        adb('shell','am','start','-n',f'{package}/.PolishRuntimeActivity')
        metadata['background_notification_captured'] = True


def drive(command, log, on_line, timeout_seconds, metadata):
    """Bound even silent/unterminated output, and reap the whole driver group."""
    process = subprocess.Popen(command, cwd=app, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT, start_new_session=True,
                               env={**os.environ, 'FLUTTER_SUPPRESS_ANALYTICS': 'true',
                                    'DART_SUPPRESS_ANALYTICS': 'true',
                                    'DASH__SUPPRESS_ANALYTICS': 'true'})
    metadata['driver_pid'] = process.pid
    expired = threading.Event()

    def stop_group():
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass

    def expire(reason):
        metadata['timeout_reason'] = reason
        expired.set()
        stop_group()

    # Independent of stdout and adb checkpoint handlers, including a stopped VM.
    watchdog = threading.Timer(timeout_seconds, expire, args=('driver_wall_clock',))
    watchdog.daemon = True
    watchdog.start()
    decoder = codecs.getincrementaldecoder('utf-8')(errors='replace')
    pending = ''
    back_watchdog = None

    def dispatch(line):
        nonlocal back_watchdog
        if 'PROXO_POLISH_MENU_BACK_READY' in line and back_watchdog is None:
            back_watchdog = threading.Timer(MENU_BACK_ACK_TIMEOUT_SECONDS, expire,
                                            args=('menu_android_back_ack',))
            back_watchdog.daemon = True
            back_watchdog.start()
        if 'PROXO_POLISH_MENU_BACK_DISMISSED' in line:
            metadata['menu_android_back_acknowledged'] = True
            if back_watchdog is not None:
                back_watchdog.cancel()
        on_line(line)

    try:
        with selectors.DefaultSelector() as selector:
            selector.register(process.stdout, selectors.EVENT_READ)
            while not expired.is_set():
                if not selector.select(timeout=.25):
                    continue
                data = os.read(process.stdout.fileno(), 65536)
                text = decoder.decode(data, final=not data)
                print(text, end='', flush=True)
                log.write(text)
                log.flush()
                pending += text
                while '\n' in pending and not expired.is_set():
                    line, pending = pending.split('\n', 1)
                    dispatch(line)
                if not data:
                    if pending and not expired.is_set():
                        dispatch(pending)
                    break
        # A child can close stdout but keep running. The watchdog also bounds wait.
        while process.poll() is None and not expired.wait(.05):
            pass
        if expired.is_set():
            log.write(f"\nProfile driver deadline exceeded: {metadata['timeout_reason']}.\n")
            log.flush()
            return 124
        return process.returncode
    finally:
        watchdog.cancel()
        watchdog.join()
        if back_watchdog is not None:
            back_watchdog.cancel()
            back_watchdog.join()
        metadata['drive_timed_out'] = expired.is_set()
        # Also stop descendants after callback/host failures or early parent exit.
        stop_group()
        process.wait(timeout=5)
        process.stdout.close()


def retain_evidence(output, metadata):
    """Attempt every capture independently; a broken adb must not hide the cause."""
    errors = metadata.setdefault('cleanup_errors', {})
    try:
        pull = subprocess.run(['adb', 'pull',
            f'/sdcard/Android/data/{package}/files/polish-runtime', str(output/'screens')],
            capture_output=True, text=True, timeout=30)
        (output/'screenshot-transfer.log').write_text(pull.stdout + pull.stderr)
        metadata['screenshot_transfer_exit_code'] = pull.returncode
        if pull.returncode:
            errors['native_pull'] = f'adb exited {pull.returncode}'
    except Exception as error:
        errors['native_pull'] = str(error)
        (output/'screenshot-transfer.log').write_text(str(error))
    for name, args in [
        ('logcat.log', ('logcat', '-d', '-t', '1500')),
        ('window.log', ('shell', 'dumpsys', 'window', 'windows')),
        ('input-method.log', ('shell', 'dumpsys', 'input_method')),
    ]:
        try:
            (output/name).write_bytes(adb(*args))
        except Exception as error:
            errors[name] = str(error)
    for name, args in [
        ('device', ('shell', 'getprop', 'ro.product.model')),
        ('android', ('shell', 'getprop', 'ro.build.version.release')),
        ('wm_size', ('shell', 'wm', 'size')),
        ('wm_density', ('shell', 'wm', 'density')),
    ]:
        if name in metadata:
            continue
        try:
            metadata[name] = adb(*args).decode().strip()
        except Exception as error:
            errors[name] = str(error)
    captures = list((output/'screens').rglob('*.png'))
    metadata['native_screenshot_count'] = len(captures)
    try:
        assert all(p.read_bytes().startswith(b'\x89PNG') for p in captures), 'Invalid native PNG'
    except Exception as error:
        errors['native_screenshots'] = str(error)


def validate(output, metadata):
    data=json.loads((output/'runtime.json').read_text())
    assert data['observations'].get('completed') is True, 'Profile fixture incomplete; inspect runtime.json'
    assert metadata.get('background_notification_captured')
    assert metadata.get('keyboard_captured')
    assert metadata.get('phone_input_injected')
    assert metadata.get('menu_android_back_injected')
    assert metadata.get('menu_android_back_acknowledged'), 'Android Back dismissal was not acknowledged'
    assert metadata.get('ad_error_input_injected')
    assert metadata.get('ad_error_keyboard_captured')
    assert metadata['screenshot_transfer_exit_code'] == 0, 'Android screenshots could not be pulled; see screenshot-transfer.log'
    captures = list((output/'screens').rglob('*.png'))
    assert len(captures) >= 30, f'Only {len(captures)} native screenshots retained'
    rows=[]
    for name, summary in data.items():
        if not name.startswith('frames_'): continue
        row={'screen':name.removeprefix('frames_'),**summary}
        rows.append(row)
    assert len(rows)>=30, len(rows)
    (output/'performance-summary.json').write_text(json.dumps(rows,indent=2))
    print(f'Profile runtime verified: {len(rows)} screen/action measurements; background logo captured.')


def run(output=None, command=None, timeout_seconds=DRIVE_TIMEOUT_SECONDS):
    output = Path(output) if output is not None else app / 'build/polish-runtime'
    output.mkdir(parents=True, exist_ok=True)
    metadata = {
        'fixture_only': True, 'mode': 'profile',
        'drive_timeout_seconds': timeout_seconds, 'drive_timed_out': False,
        'exit_code': 1,
    }
    started = time.monotonic()
    result = 1
    try:
        # Persist a readable status even if setup or Popen itself fails.
        (output/'device.json').write_text(json.dumps(metadata, indent=2))
        configure(metadata)
        with (output/'driver.log').open('w') as log:
            result = drive(command or COMMAND, log,
                           lambda line: capture_event(line, output, metadata),
                           max(.001, timeout_seconds - (time.monotonic() - started)), metadata)
    except (Exception, KeyboardInterrupt) as error:
        metadata['host_error'] = f'{type(error).__name__}: {error}'
        (output/'host-error.log').write_text(traceback.format_exc())
        result = 130 if isinstance(error, KeyboardInterrupt) else 1
    finally:
        metadata['exit_code'] = result
        try:
            retain_evidence(output, metadata)
        except Exception as error:
            metadata.setdefault('cleanup_errors', {})['capture'] = str(error)
        metadata['elapsed_seconds'] = round(time.monotonic() - started, 3)
        (output/'device.json').write_text(json.dumps(metadata, indent=2))
    if metadata.get('drive_timed_out'):
        result = 124
    if result == 0:
        try:
            assert not metadata.get('cleanup_errors'), 'Incomplete diagnostics; inspect device.json'
            validate(output, metadata)
        except Exception as error:
            metadata['validation_error'] = f'{type(error).__name__}: {error}'
            result = 1
    metadata['exit_code'] = result
    (output/'device.json').write_text(json.dumps(metadata, indent=2))
    return result


if __name__ == '__main__':
    sys.exit(run())
