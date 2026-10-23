/** Prepare reviewable RFC6902 patches only. No network, credentials or live writes.
 * node integrations/legacy-isolation/prepare-patches.mjs FASTPAY_JSON BUDGET_JSON OUTPUT_JSON
 * Input can retain credential references: none are copied into the patch bundle.
 */
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { fileURLToPath } from 'node:url';

const pointer = value => value.replace(/~/g, '~0').replace(/\//g, '~1');
const digest = value => createHash('sha256').update(JSON.stringify(value)).digest('hex');
const edge = node => ({ node, type: 'main', index: 0 });
const main = (...names) => ({ main: names.map(name => [edge(name)]) });
const id = name => `legacy-isolation-${createHash('sha256').update(name).digest('hex').slice(0, 24)}`;
const clone = value => structuredClone(value);

export const GUARD_ASSERTION = `const guard = $input.item.json;
if (!guard || guard.ok !== true || typeof guard.legacy_allowed !== 'boolean' ||
    typeof guard.immutable_ad_payment !== 'boolean' || guard.immutable_ad_payment === guard.legacy_allowed ||
    guard.code !== (guard.legacy_allowed ? 'LEGACY_ALLOWED' : 'AD_PAYMENT_IMMUTABLE')) {
  throw new Error('LEGACY_FASTPAY_GUARD_UNAVAILABLE');
}
return [{ json: guard }];`;

export const FASTPAY_ROUTES = [
  { key: 'Checkout', source: 'App User Valid?', output: 0, target: 'Ad Checkout?', orderNode: 'Validate & Prepare', orderField: 'orderId' },
  { key: 'IPN', source: 'Extract IPN Data', output: 0, target: 'FastPay Config2', orderNode: 'Extract IPN Data', orderField: 'merchant_order_id', acknowledgement: true },
  { key: 'Poll', source: 'Loop Orders', output: 1, target: 'FastPay Config3', orderNode: 'Loop Orders', orderField: 'fastpay_order_id', transactionField: 'id', loop: true },
  { key: 'App Status', source: 'Status User Valid?', output: 0, target: 'Get App Payment (Supabase)', orderNode: 'Validate Status Request', orderField: 'orderId' },
  { key: 'Refund', source: 'Refund Input Valid?', output: 0, target: 'Get Refund Target (Supabase)', orderNode: 'Validate Refund Input', orderField: 'orderId' },
];

function nodeIndex(workflow, name, type) {
  const indices = workflow.nodes.map((node, index) => node.name === name ? index : -1).filter(index => index >= 0);
  assert.equal(indices.length, 1, `Expected exactly one reviewed node: ${name}`);
  const index = indices[0];
  if (type) assert.equal(workflow.nodes[index].type, `n8n-nodes-base.${type}`, `Unexpected node type: ${name}`);
  return index;
}

function basePatch(workflow, kind) {
  assert(Array.isArray(workflow?.nodes) && workflow.connections && typeof workflow.active === 'boolean', 'Expected complete workflow snapshot');
  assert.equal(new Set(workflow.nodes.map(node => node.name)).size, workflow.nodes.length, 'Duplicate node names');
  return { kind, source_name: workflow.name, source_sha256: digest(workflow), source_active: workflow.active,
    apply_to: 'Existing workflow after review; pause and drain relevant executions first',
    changes_activation: false, operations: [] };
}

function addNode(patch, workflow, node) {
  assert(!workflow.nodes.some(existing => existing.name === node.name), `Already patched: ${node.name}`);
  patch.operations.push({ op: 'add', path: '/nodes/-', value: node });
}

export function prepareFastPayPatch(workflow) {
  const patch = basePatch(workflow, 'fastpay-v12-immutable-order-isolation');
  for (const route of FASTPAY_ROUTES) {
    const sourceIndex = nodeIndex(workflow, route.source);
    nodeIndex(workflow, route.target);
    nodeIndex(workflow, route.orderNode);
    const connectionPath = `/connections/${pointer(route.source)}/main/${route.output}`;
    assert.deepEqual(workflow.connections[route.source]?.main?.[route.output], [edge(route.target)], `Unexpected reviewed route: ${route.key}`);
    const stem = `Legacy ${route.key}`;
    const lookup = `${stem} Order Guard`, assertion = `${stem} Guard Valid`, allowed = `${stem} Allowed?`, denied = `${stem} Immutable Order`;
    const [x, y] = workflow.nodes[sourceIndex].position || [0, 0];
    const orderExpression = `$(${JSON.stringify(route.orderNode)}).item.json.${route.orderField}`;
    const transactionExpression = route.transactionField ? `$(${JSON.stringify(route.orderNode)}).item.json.${route.transactionField}` : 'null';
    const jsonBody = `={{ (() => { const order = ${orderExpression}; if (typeof order !== 'string' || !/^[A-Za-z0-9_-]{8,32}$/.test(order)) throw new Error('LEGACY_FASTPAY_ORDER_INVALID'); return { p_order_id: order, p_transaction_id: ${transactionExpression} }; })() }}`;
    addNode(patch, workflow, { id: id(lookup), name: lookup, type: 'n8n-nodes-base.httpRequest', typeVersion: 4.2, position: [x + 160, y + 120],
      parameters: { method: 'POST', url: "={{ $env.PROXO_SUPABASE_URL.replace(/\\/+$/, '') + '/rest/v1/rpc/pa_legacy_fastpay_guard' }}",
        authentication: 'genericCredentialType', genericAuthType: 'httpCustomAuth', sendHeaders: true,
        headerParameters: { parameters: [{ name: 'Content-Type', value: 'application/json' }, { name: 'Accept', value: 'application/json' }] },
        sendBody: true, specifyBody: 'json', jsonBody,
        options: { timeout: 15000, response: { response: { responseFormat: 'json', neverError: false } } } },
      credentials: { httpCustomAuth: { name: 'Proxo Supabase service role' } }, retryOnFail: false, onError: 'stopWorkflow' });
    addNode(patch, workflow, { id: id(assertion), name: assertion, type: 'n8n-nodes-base.code', typeVersion: 2, position: [x + 320, y + 120], parameters: { jsCode: GUARD_ASSERTION } });
    addNode(patch, workflow, { id: id(allowed), name: allowed, type: 'n8n-nodes-base.if', typeVersion: 2.2, position: [x + 480, y + 120],
      parameters: { conditions: { options: { caseSensitive: true, leftValue: '', typeValidation: 'strict', version: 2 }, conditions: [
        { id: id(`${allowed}:condition`), leftValue: '={{ $json.legacy_allowed }}', rightValue: true, operator: { type: 'boolean', operation: 'true' } },
      ], combinator: 'and' }, options: {} } });
    let allowTarget = route.target;
    if (route.loop) {
      // The HTTP node replaced the item. Restore this exact loop item's fields
      // before FastPay Config3, which reads $json.fastpay_order_id.
      allowTarget = `${stem} Restore Item`;
      addNode(patch, workflow, { id: id(allowTarget), name: allowTarget, type: 'n8n-nodes-base.code', typeVersion: 2, position: [x + 640, y + 120],
        parameters: { jsCode: "return [{ json: $('Loop Orders').item.json }];" } });
      patch.operations.push({ op: 'add', path: `/connections/${pointer(allowTarget)}`, value: main(route.target) });
    } else {
      addNode(patch, workflow, { id: id(denied), name: denied, type: 'n8n-nodes-base.respondToWebhook', typeVersion: 1.1, position: [x + 640, y + 280],
        parameters: { respondWith: 'json', responseBody: route.acknowledgement
          ? '={{ { received: true, ignored: true, code: "AD_PAYMENT_IMMUTABLE" } }}'
          : '={{ { success: false, code: "AD_PAYMENT_IMMUTABLE", message: "This order uses the immutable advertisement payment service." } }}',
        options: { responseCode: route.acknowledgement ? 200 : 409 } } });
    }
    patch.operations.push(
      { op: 'test', path: `/nodes/${sourceIndex}/name`, value: route.source },
      { op: 'test', path: connectionPath, value: [edge(route.target)] },
      { op: 'replace', path: connectionPath, value: [edge(lookup)] },
      { op: 'add', path: `/connections/${pointer(lookup)}`, value: main(assertion) },
      { op: 'add', path: `/connections/${pointer(assertion)}`, value: main(allowed) },
      { op: 'add', path: `/connections/${pointer(allowed)}`, value: main(allowTarget, route.loop ? 'Loop Orders' : denied) },
    );
  }
  return patch;
}

export function prepareBudgetPatch(workflow) {
  const patch = basePatch(workflow, 'tiktok-v23-automatic-fulfillment-isolation');
  const readIndex = nodeIndex(workflow, 'Get Active Ads', 'supabase');
  const read = workflow.nodes[readIndex].parameters;
  assert.equal(read.operation, 'getAll'); assert.equal(read.tableId, 'pa_ads'); assert.equal(read.filterType, 'string');
  const filter = 'or=(status.eq.active,status.eq.completed)';
  assert.equal(read.filterString, filter, 'Selection drifted; review before adapting this patch');
  patch.operations.push(
    { op: 'test', path: `/nodes/${readIndex}/name`, value: 'Get Active Ads' },
    { op: 'test', path: `/nodes/${readIndex}/parameters/filterString`, value: filter },
    { op: 'replace', path: `/nodes/${readIndex}/parameters/filterString`, value: `${filter}&fulfillment_kind=neq.tiktok_conversation_auto` },
  );
  for (const name of ['Update Spend', 'Update Spend Only', 'Mark Completed']) {
    const index = nodeIndex(workflow, name, 'supabase'), parameters = workflow.nodes[index].parameters;
    assert.equal(parameters.operation, 'update'); assert.equal(parameters.tableId, 'pa_ads'); assert.equal(parameters.matchType, 'allFilters');
    assert(Array.isArray(parameters.filters?.conditions) && parameters.filters.conditions.length === 1 && parameters.filters.conditions[0].condition === 'eq', `Unexpected update filter: ${name}`);
    patch.operations.push(
      { op: 'test', path: `/nodes/${index}/name`, value: name },
      { op: 'test', path: `/nodes/${index}/parameters/matchType`, value: 'allFilters' },
      { op: 'add', path: `/nodes/${index}/parameters/filters/conditions/-`, value: { keyName: 'fulfillment_kind', condition: 'neq', keyValue: 'tiktok_conversation_auto' } },
    );
  }
  return patch;
}

/** In-memory verifier used in tests; never writes a workflow or calls n8n. */
export function applyReviewedPatch(source, patch) {
  assert.equal(digest(source), patch.source_sha256, 'Source snapshot changed; regenerate and review the minimal patch');
  const result = clone(source);
  for (const operation of patch.operations) {
    const parts = operation.path.slice(1).split('/').map(part => part.replace(/~1/g, '/').replace(/~0/g, '~'));
    const key = parts.pop();
    const parent = parts.reduce((value, part) => value[part], result);
    if (operation.op === 'test') assert.deepEqual(parent[key], operation.value, `Patch precondition failed: ${operation.path}`);
    else if (operation.op === 'add' && key === '-') { assert(Array.isArray(parent)); parent.push(clone(operation.value)); }
    else if (operation.op === 'add' || operation.op === 'replace') parent[key] = clone(operation.value);
    else throw new Error('Unsupported patch operation');
  }
  assert.equal(result.active, source.active, 'Review patch must never change activation');
  const names = new Set(result.nodes.map(node => node.name));
  assert.equal(names.size, result.nodes.length, 'Patch introduced duplicate node names');
  for (const [from, connections] of Object.entries(result.connections)) {
    assert(names.has(from), `Missing connection source: ${from}`);
    for (const outputs of Object.values(connections)) for (const output of outputs) for (const connection of output) assert(names.has(connection.node), `Missing connection target: ${connection.node}`);
  }
  return result;
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  const [fastpayPath, budgetPath, outputPath, ...extra] = process.argv.slice(2);
  assert(fastpayPath && budgetPath && outputPath && !extra.length, 'Usage: prepare-patches.mjs FASTPAY_JSON BUDGET_JSON OUTPUT_JSON');
  assert(outputPath !== fastpayPath && outputPath !== budgetPath, 'Do not overwrite workflow snapshots');
  const fastpay = JSON.parse(await fs.readFile(fastpayPath, 'utf8'));
  const budget = JSON.parse(await fs.readFile(budgetPath, 'utf8'));
  const patches = [prepareFastPayPatch(fastpay), prepareBudgetPatch(budget)];
  applyReviewedPatch(fastpay, patches[0]); applyReviewedPatch(budget, patches[1]);
  await fs.writeFile(outputPath, JSON.stringify({ format: 'proxo-reviewed-legacy-isolation-v1', live_mutations: false,
    note: 'Review-only RFC6902 operations, not an n8n workflow import. Credential mapping and staging verification are required before application.', patches }, null, 2) + '\n', { flag: 'wx' });
  console.log(`Prepared ${patches.length} review-only patches; no live workflow changed.`);
}
