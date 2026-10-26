import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { buildRuntimeHarness } from '../integrations/legacy-fastpay/runtime-harness.mjs';

const read = name => JSON.parse(fs.readFileSync(new URL('../integrations/legacy-fastpay/' + name, import.meta.url), 'utf8'));

test('runtime harness remains a reproducible manual-only artifact without external execution capabilities', () => {
  const source = read('proxo_fastpay_durable_sandbox.json');
  const harness = read('proxo_fastpay_runtime_harness.json');
  assert.deepEqual(harness, buildRuntimeHarness(source));
  assert.equal(harness.active, false);
  assert.equal(harness.nodes.length, 2);
  assert.deepEqual(harness.nodes.map(node => node.type), ['n8n-nodes-base.manualTrigger', 'n8n-nodes-base.code']);
  for (const node of harness.nodes) {
    assert.equal(node.credentials, undefined);
    assert.equal(node.webhookId, undefined);
    assert.equal(node.parameters.url, undefined);
  }
  assert.equal(harness.settings.saveManualExecutions, false);
  assert.equal(harness.settings.saveDataSuccessExecution, 'none');
  const code = harness.nodes[1].parameters.jsCode;
  assert.doesNotMatch(code, /\b(?:require|import|eval|fetch)\s*\(|new\s+Function\b|\$helpers\b|\$http\b|\$getWorkflowStaticData\b/);
  const sourceNode = source.nodes.find(node => node.name === 'Legacy Dispatch Verified');
  assert(code.includes(sourceNode.parameters.jsCode), 'Actual source snippet must be embedded without rewriting');
});

test('runtime harness locally rehearses synthetic scenarios and never reports live acceptance', () => {
  const harness = read('proxo_fastpay_runtime_harness.json');
  const result = vm.runInNewContext('(function(){' + harness.nodes[1].parameters.jsCode + '})()', {}, { timeout: 1000 });
  assert.equal(result.length, 1);
  const summary = result[0].json;
  assert.equal(summary.result, 'PASS');
  assert.equal(summary.passedChecks, summary.checks.length);
  assert(summary.passedChecks >= 50);
  assert.equal(new Set(summary.checks).size, summary.passedChecks);
  assert.equal(summary.syntheticOnly, true);
  assert.equal(summary.providerRequests, 0);
  assert.equal(summary.ledgerWrites, 0);
  assert.equal(summary.livePaymentAccepted, false);
  assert.match(summary.provenance.sourceSha256, /^[a-f0-9]{64}$/);
  assert.equal(summary.provenance.codeNodes.length, 16);
});
