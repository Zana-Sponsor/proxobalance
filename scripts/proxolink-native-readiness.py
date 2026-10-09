#!/usr/bin/env python3
"""Disposable-runner KVM diagnostics. Preserve every original setup command/gate.
No emulator, rendering configuration, account, environment variable or credential
is inspected. Evidence records readiness only, never native verification.
"""
import errno
import fcntl
import json
import os
import platform
import stat
import subprocess
import sys
import time
from pathlib import Path

RULE = 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"'
COMMANDS = (
    ("write_kvm_rule", ["sudo", "tee", "/etc/udev/rules.d/99-kvm4all.rules"], (RULE + "\n").encode()),
    ("reload_udev_rules", ["sudo", "udevadm", "control", "--reload-rules"], None),
    ("trigger_kvm_udev", ["sudo", "udevadm", "trigger", "--name-match=kvm"], None),
    ("original_readability_check", ["test", "-r", "/dev/kvm"], None),
)
SETTLE = ("diagnostic_settle_after_failure", ["sudo", "udevadm", "settle", "--timeout=5"], None)
ALLOWED_ERRNO = {"EACCES", "EPERM", "ENOENT", "ENODEV", "ENXIO", "ENOTTY", "EBUSY", "EINVAL", "EIO"}

def safe_errno(error):
    name = errno.errorcode.get(getattr(error, "errno", None), "OTHER")
    return name if name in ALLOWED_ERRNO else "OTHER"

def snapshot(probe=False):
    out = {
        "observed_monotonic_ms": time.monotonic_ns() / 1000000,
        "uid": os.getuid(), "euid": os.geteuid(), "groups": sorted(os.getgroups()),
        "exists": os.path.exists("/dev/kvm"),
        "readable": os.access("/dev/kvm", os.R_OK),
        "writable": os.access("/dev/kvm", os.W_OK),
        "module_kvm": os.path.isdir("/sys/module/kvm"),
        "module_kvm_intel": os.path.isdir("/sys/module/kvm_intel"),
        "module_kvm_amd": os.path.isdir("/sys/module/kvm_amd"),
    }
    arch = platform.machine()
    out["architecture"] = arch if arch in ("x86_64", "aarch64") else "other"
    try:
        info = os.stat("/dev/kvm")
        out.update(character_device=stat.S_ISCHR(info.st_mode), mode=stat.S_IMODE(info.st_mode),
                   owner_uid=info.st_uid, owner_gid=info.st_gid, inode=info.st_ino,
                   device_major=os.major(info.st_rdev), device_minor=os.minor(info.st_rdev))
    except OSError as error:
        out["stat_errno"] = safe_errno(error)
    try:
        flags = Path("/proc/cpuinfo").read_text()
        out["cpu_vmx"] = "vmx" in flags.split()
        out["cpu_svm"] = "svm" in flags.split()
    except OSError:
        out["cpu_flags_unavailable"] = True
    if probe:
        try:
            descriptor = os.open("/dev/kvm", os.O_RDWR | os.O_CLOEXEC)
            try:
                # KVM_GET_API_VERSION: read-only query, no VM/vCPU is created.
                out["kvm_api_version"] = fcntl.ioctl(descriptor, 0xAE00)
                out["open_read_write"] = True
            finally:
                os.close(descriptor)
        except OSError as error:
            out["open_read_write"] = False
            out["open_or_ioctl_errno"] = safe_errno(error)
    return out

def execute(command):
    label, argv, data = command
    try:
        result = subprocess.run(argv, input=data, stdout=subprocess.DEVNULL,
                                stderr=subprocess.DEVNULL, timeout=15, check=False)
        return result.returncode, None
    except subprocess.TimeoutExpired:
        return 124, "command_timeout"
    except OSError:
        return 127, "command_unavailable"

def run_readiness(output, run=execute, observe=snapshot):
    directory = Path(output)
    directory.mkdir(parents=True, exist_ok=True)
    report = {
        "scope": "Disposable-runner readiness only; no Android/WebView cases executed by this step",
        "root_cause": "NOT PROVEN",
        "commands": [], "status": "SETUP_RUNNING",
        "acceptance_or_protection_changed": False,
        "native_verification_claimed": False,
    }
    def persist():
        temporary = directory / "runner-readiness.json.next"
        temporary.write_text(json.dumps(report, indent=2) + "\n")
        temporary.replace(directory / "runner-readiness.json")

    def observation(probe):
        try:
            return observe(probe)
        except Exception:
            # Diagnostic failure must not erase an original command failure or
            # serialize exception text from a runner. The setup gate is intact.
            return {"diagnostic": "observation_unavailable"}

    # Commit a safe checkpoint before observations and every original command.
    # Cancellation/termination can leave SETUP_RUNNING, never a native pass.
    persist()
    report["before"] = observation(False)
    persist()
    original_code = 0
    for command in COMMANDS:
        started = time.monotonic_ns() / 1000000
        report["active_step"] = command[0]
        persist()
        code, diagnostic = run(command)
        entry = {"step": command[0], "exit_code": code, "started_monotonic_ms": started,
                 "completed_monotonic_ms": time.monotonic_ns() / 1000000}
        if diagnostic:
            entry["diagnostic"] = diagnostic
        report["commands"].append(entry)
        report.pop("active_step", None)
        print("KVM setup: " + command[0] + " exit=" + str(code), flush=True)
        if code != 0:
            original_code = code
            report["failed_step"] = command[0]
            report["status"] = "FAILED"
            report["original_exit_code"] = code
            persist()
            break
        persist()
    report["after_original_gate"] = observation(True)
    persist()
    if original_code:
        # Observe readiness after the ORIGINAL failure. Never rerun its test,
        # turn a later readable device into success, or launch the emulator.
        code, diagnostic = run(SETTLE)
        report["diagnostic_settle"] = {"exit_code": code}
        if diagnostic:
            report["diagnostic_settle"]["diagnostic"] = diagnostic
        report["after_diagnostic_settle"] = observation(True)
        report["readability_changed_after_failure"] = (
            report["after_original_gate"].get("readable") != report["after_diagnostic_settle"].get("readable")
        )
    report["status"] = "FAILED" if original_code else "SETUP_PASSED"
    report["original_exit_code"] = original_code
    persist()
    return original_code if original_code > 0 else (1 if original_code else 0)

if __name__ == "__main__":
    output = sys.argv[1] if len(sys.argv) == 2 else "proxo_app/build/native-verification"
    sys.exit(run_readiness(output))
