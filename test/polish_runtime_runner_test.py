"""Host-runner failure paths; no Flutter SDK, Android device, or network needed."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    'polish_runtime_runner', Path(__file__).resolve().parents[1] / 'scripts/run-polish-runtime.py')
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


class PolishRuntimeRunnerTest(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.output = Path(temporary.name)
        self.adb_calls = []
        self.pull_fails = False

    def fake_adb_process(self, command, **kwargs):
        self.assertEqual(command[0], 'adb')
        self.assertLessEqual(kwargs['timeout'], 30)
        self.adb_calls.append(command[1:])
        if command[1] == 'pull':
            if self.pull_fails:
                raise subprocess.TimeoutExpired(command, kwargs['timeout'])
            screens = Path(command[-1])
            screens.mkdir()
            (screens / 'partial.png').write_bytes(b'\x89PNG\r\n\x1a\nfixture')
            (screens / 'runtime-partial.json').write_text('{"completed":false}')
            return subprocess.CompletedProcess(command, 0, 'partial evidence copied', '')
        return subprocess.CompletedProcess(command, 0, b'fixture diagnostic\n', b'')

    def run_driver(self, program, **kwargs):
        with patch.object(runner.subprocess, 'run', side_effect=self.fake_adb_process), \
                contextlib.redirect_stdout(io.StringIO()):
            result = runner.run(self.output, [sys.executable, '-c', program], **kwargs)
        metadata = json.loads((self.output / 'device.json').read_text())
        self.assertEqual(metadata['exit_code'], result)
        self.assertTrue((self.output / 'logcat.log').exists())
        self.assertTrue((self.output / 'window.log').exists())
        self.assertTrue((self.output / 'input-method.log').exists())
        self.assertTrue(any(call[0] == 'pull' for call in self.adb_calls))
        return result, metadata

    def test_silent_driver_deadline_kills_group_and_keeps_partial_evidence(self):
        # Both parent and descendant hold stdout open. No complete trailing line
        # exists, which previously made the host wait for the CI job deadline.
        program = ("import subprocess,sys,time; "
                   "child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(60)']); "
                   "print('child='+str(child.pid),flush=True); "
                   "print('unfinished',end='',flush=True); time.sleep(60)")
        started = time.monotonic()
        with patch.object(runner.os, 'killpg', wraps=os.killpg) as kill:
            result, metadata = self.run_driver(program, timeout_seconds=.3)
        self.assertEqual(result, 124)
        self.assertTrue(metadata['drive_timed_out'])
        self.assertLess(time.monotonic() - started, 3)
        kill.assert_any_call(metadata['driver_pid'], runner.signal.SIGKILL)
        with self.assertRaises(ProcessLookupError):
            os.kill(metadata['driver_pid'], 0)
        log = (self.output / 'driver.log').read_text()
        self.assertIn('unfinished', log)
        child_pid = int(log.split('child=')[1].splitlines()[0])
        status = Path(f'/proc/{child_pid}/status')
        try:
            child_status = status.read_text()
        except FileNotFoundError:
            pass  # Already reaped by init.
        else:
            self.assertIn('State:\tZ', child_status)  # Exited, awaiting init reaping.
        self.assertTrue((self.output / 'screens/partial.png').exists())
        self.assertTrue((self.output / 'screens/runtime-partial.json').exists())
        self.assertEqual(metadata['native_screenshot_count'], 1)

    def test_android_back_requires_native_ack_before_short_host_deadline(self):
        with patch.object(runner, 'MENU_BACK_ACK_TIMEOUT_SECONDS', .1):
            result, metadata = self.run_driver(
                "import time; print('PROXO_POLISH_MENU_BACK_READY',flush=True); time.sleep(60)",
                timeout_seconds=2)
        self.assertEqual(result, 124)
        self.assertEqual(metadata['timeout_reason'], 'menu_android_back_ack')
        self.assertTrue(metadata['menu_android_back_injected'])
        self.assertNotIn('menu_android_back_acknowledged', metadata)
        self.assertTrue((self.output / 'screens/runtime-partial.json').exists())

    def test_native_back_ack_cancels_its_watchdog(self):
        with patch.object(runner, 'MENU_BACK_ACK_TIMEOUT_SECONDS', .1):
            result, metadata = self.run_driver(
                "import sys,time; print('PROXO_POLISH_MENU_BACK_READY',flush=True); "
                "print('PROXO_POLISH_MENU_BACK_DISMISSED',flush=True); time.sleep(.2); sys.exit(7)",
                timeout_seconds=2)
        self.assertEqual(result, 7)
        self.assertTrue(metadata['menu_android_back_acknowledged'])
        self.assertFalse(metadata['drive_timed_out'])

    def test_checkpoint_exception_reaps_driver_and_still_pulls_and_captures(self):
        with patch.object(runner, 'capture_event', side_effect=RuntimeError('checkpoint failed')):
            result, metadata = self.run_driver(
                "import time; print('READY',flush=True); time.sleep(60)", timeout_seconds=2)
        self.assertEqual(result, 1)
        self.assertIn('checkpoint failed', metadata['host_error'])
        self.assertFalse(metadata['drive_timed_out'])
        self.assertTrue((self.output / 'host-error.log').exists())
        with self.assertRaises(ProcessLookupError):
            os.kill(metadata['driver_pid'], 0)
        self.assertEqual(metadata['screenshot_transfer_exit_code'], 0)

    def test_pull_timeout_does_not_skip_other_diagnostics_or_hide_driver_status(self):
        self.pull_fails = True
        result, metadata = self.run_driver('import sys; sys.exit(7)', timeout_seconds=2)
        self.assertEqual(result, 7)
        self.assertIn('native_pull', metadata['cleanup_errors'])
        self.assertTrue((self.output / 'screenshot-transfer.log').exists())
        self.assertTrue(any(call[0] == 'logcat' for call in self.adb_calls))

    def test_success_validation_requires_durable_android_back_ack(self):
        (self.output / 'runtime.json').write_text('{"observations":{"completed":true}}')
        metadata = {key: True for key in [
            'background_notification_captured', 'keyboard_captured',
            'phone_input_injected', 'menu_android_back_injected',
        ]}
        with self.assertRaisesRegex(AssertionError, 'Back dismissal was not acknowledged'):
            runner.validate(self.output, metadata)

    def test_setup_exception_still_writes_metadata_and_attempts_all_captures(self):
        with patch.object(runner, 'configure', side_effect=OSError('adb disconnected')):
            result, metadata = self.run_driver('raise AssertionError("must not launch")')
        self.assertEqual(result, 1)
        self.assertIn('adb disconnected', metadata['host_error'])
        self.assertNotIn('driver_pid', metadata)
        self.assertEqual(metadata['device'], 'fixture diagnostic')
        self.assertEqual(metadata['native_screenshot_count'], 1)


if __name__ == '__main__':
    unittest.main()
