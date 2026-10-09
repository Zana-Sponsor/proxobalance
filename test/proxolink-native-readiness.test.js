import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
test('KVM readiness diagnostics preserve failure, bound observation and never certify missing native evidence',()=>{
 const program=String.raw`
import importlib.util, json, tempfile, unittest
from pathlib import Path
from unittest.mock import patch
spec=importlib.util.spec_from_file_location("readiness", "scripts/proxolink-native-readiness.py")
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class Checks(unittest.TestCase):
 def observe(self, readable=False):
  return {"readable":readable,"writable":readable,"exists":True,"uid":1001,"euid":1001}
 def run_case(self, failing=None, later=False, exception=None):
  calls=[];counter=[0]
  def execute(command):
   calls.append(command[0]);return (1,exception) if command[0]==failing else (0,None)
  def snapshot(probe):
   counter[0]+=1;return self.observe(later and counter[0]>=3)
  with tempfile.TemporaryDirectory() as directory:
   code=m.run_readiness(directory,execute,snapshot)
   report=json.loads((Path(directory)/"runner-readiness.json").read_text())
   self.assertFalse((Path(directory)/"results.json").exists())
   return code,report,calls
 def test_pass_keeps_all_original_commands_and_no_settle(self):
  code,report,calls=self.run_case()
  self.assertEqual(code,0);self.assertEqual(calls,[x[0] for x in m.COMMANDS])
  self.assertEqual(report["status"],"SETUP_PASSED")
  self.assertFalse(report["native_verification_claimed"])
 def test_later_readability_never_changes_original_failure(self):
  code,report,calls=self.run_case("original_readability_check",True)
  self.assertEqual(code,1);self.assertEqual(report["status"],"FAILED")
  self.assertEqual(report["failed_step"],"original_readability_check")
  self.assertTrue(report["readability_changed_after_failure"])
  self.assertEqual(calls.count("original_readability_check"),1)
  self.assertEqual(calls[-1],"diagnostic_settle_after_failure")
  self.assertEqual(report["root_cause"],"NOT PROVEN")
 def test_reload_failure_never_runs_trigger_or_gate(self):
  code,report,calls=self.run_case("reload_udev_rules")
  self.assertEqual(code,1);self.assertEqual(report["failed_step"],"reload_udev_rules")
  self.assertNotIn("trigger_kvm_udev",calls);self.assertNotIn("original_readability_check",calls)
 def test_original_rule_and_check_are_unchanged(self):
  self.assertEqual(m.RULE,'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"')
  self.assertEqual(m.COMMANDS[-1][1],["test","-r","/dev/kvm"])
  self.assertEqual(m.SETTLE[1],["sudo","udevadm","settle","--timeout=5"])
 def test_safe_error_codes_never_retain_exception_text(self):
  self.assertEqual(m.safe_errno(PermissionError(13,"private token value")),"EACCES")
  self.assertEqual(m.safe_errno(OSError(999,"private token value")),"OTHER")
  with patch.object(m.subprocess,"run",side_effect=m.subprocess.TimeoutExpired("private",15)):
   self.assertEqual(m.execute(m.COMMANDS[0]),(124,"command_timeout"))
 def test_failure_evidence_is_atomic_and_contains_no_native_pass(self):
  code,report,calls=self.run_case("write_kvm_rule",exception="command_unavailable")
  self.assertEqual(code,1);self.assertFalse(report["acceptance_or_protection_changed"])
  self.assertEqual(report["commands"][0]["diagnostic"],"command_unavailable")
  self.assertEqual(report["native_verification_claimed"],False)
unittest.main()
`;
 const result=spawnSync('python3',['-c',program],{encoding:'utf8',timeout:15000});
 assert.equal(result.status,0,result.stderr);
 assert.match(result.stderr,/Ran 6 tests/);
});
