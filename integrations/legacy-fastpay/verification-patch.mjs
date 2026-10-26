/** In-memory, review-only amendment. The caller owns cloning, snapshot drift
 * checks, credential sanitization and serialization. Never executes a workflow.
 */
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { legacyProviderContract } from './contracts.mjs';

const edge = node => ({ node, type: 'main', index: 0 });
const id = name => 'legacy-fastpay-verification-' + createHash('sha256').update(name).digest('hex').slice(0, 20);
const factory = `const contract = (${legacyProviderContract.toString()})();`;
const binding = name => `$('${name}').item.json`;
const failed = `return [{json:{ok:false,verified:false,creditConfirmed:false,orderId:expected.orderId,transactionId:expected.transactionId,userId:expected.userId,paymentStatus:'',code:'FASTPAY_RECONCILIATION_UNAVAILABLE'}}];`;

export function patchVerification(workflow) {
  assert(Array.isArray(workflow?.nodes) && workflow.connections, 'Expected a complete reviewed workflow');
  const get = (name, type) => {
    const nodes = workflow.nodes.filter(node => node.name === name);
    assert.equal(nodes.length, 1, `Expected one reviewed node: ${name}`);
    if (type) assert.equal(nodes[0].type, `n8n-nodes-base.${type}`, `Unexpected node type: ${name}`);
    return nodes[0];
  };
  const connect = (from, ...targets) => { workflow.connections[from] = { main: targets.map(target => [edge(target)]) }; };
  const add = (name, type, parameters, anchor, dx = 200, dy = 0) => {
    assert(!workflow.nodes.some(node => node.name === name), `Already patched: ${name}`);
    const [x, y] = get(anchor).position || [0, 0];
    const node = { id: id(name), name, type: `n8n-nodes-base.${type}`, typeVersion: { code: 2, if: 2.2, httpRequest: 4.2, respondToWebhook: 1.1 }[type],
      position: [x + dx, y + dy], parameters };
    workflow.nodes.push(node);
    return node;
  };
  const bool = (name, expression) => {
    get(name, 'if').parameters = { conditions: { options: { caseSensitive: true, leftValue: '', typeValidation: 'strict', version: 2 },
      conditions: [{ id: id(name + '-condition'), leftValue: expression, rightValue: true, operator: { type: 'boolean', operation: 'true' } }], combinator: 'and' }, options: {} };
  };
  const addBool = (name, expression, anchor) => {
    add(name, 'if', {}, anchor);
    bool(name, expression);
  };
  const fullResponse = node => {
    node.retryOnFail = false;
    node.onError = 'continueRegularOutput';
    node.parameters.options = { ...(node.parameters.options || {}), timeout: 15000,
      redirect: { redirect: { followRedirects: false } },
      response: { response: { fullResponse: true, neverError: true, responseFormat: 'text' } } };
  };
  const providerRequest = (node, expectedNode, operation) => {
    node.parameters.method = 'POST';
    node.parameters.url = `={{ ${binding(expectedNode)}.baseUrl + '/api/v1/public/vending/${operation}' }}`;
    node.parameters.sendBody = true; node.parameters.specifyBody = 'json';
    node.parameters.jsonBody = `={{ {orderId:${binding(expectedNode)}.orderId} }}`;
    fullResponse(node);
  };
  const code = (name, source) => { get(name, 'code').parameters = { jsCode: source }; };
  const publicUnavailable = 'Legacy App Payment Unavailable';
  add(publicUnavailable, 'respondToWebhook', { respondWith: 'json',
    responseBody: '={{ {success:false,paid:false,terminal:false,code:"FASTPAY_RECONCILIATION_UNAVAILABLE"} }}', options: { responseCode: 503 } }, 'Respond App Payment Pending', 0, 220);

  // IPNs select an order; all receipt authority comes from the independent
  // server-to-server validation response and the bound database record.
  providerRequest(get('Validate Payment', 'httpRequest'), 'Legacy IPN Binding', 'validate');
  code('Compare & Decide', `${factory}\nconst expected=${binding('Legacy IPN Binding')};\ntry {\n const verified=contract.validate($('Validate Payment').item.json,expected);\n return [{json:{...verified,match:true,duplicate:false,transactionId:expected.transactionId,userId:expected.userId}}];\n} catch { return [{json:{match:false,duplicate:false,retryable:true,orderId:expected.orderId,code:'FASTPAY_RECONCILIATION_UNAVAILABLE'}}]; }`);
  bool('Match & Success?', '={{ $json.match === true && $json.verified === true }}');
  bool('Already Processed?', '={{ $json.duplicate === true }}');
  connect('Match & Success?', 'Mark PAID + Credit Wallet + Notify (Supabase)', 'Ack IPN (Not Matched)');
  for (const name of ['Ack IPN (Matched)', 'Ack IPN (Not Matched)', 'Ack IPN (Duplicate)']) {
    get(name, 'respondToWebhook').parameters = { respondWith: 'json', responseBody: '={{ {received:true} }}', options: { responseCode: 200 } };
  }

  const routes = [
    { key: 'Poll', expected: 'Legacy Poll Binding', http: 'Get Status', parse: 'Parse Status Response', paidIf: 'Is PAID?',
      declineIf: 'Is DECLINED?', credit: 'Mark PAID from Poll (Supabase)', success: 'Loop Orders', failure: 'Loop Orders', source: 'poll' },
    { key: 'App', expected: 'Normalize App Payment', http: 'Check FastPay From App', parse: 'Parse FastPay App Status', paidIf: 'FastPay App Paid?',
      declineIf: 'FastPay App Declined?', credit: 'Mark PAID From App (Supabase)', success: 'Respond App Payment Paid', failure: publicUnavailable, source: 'app_resume' },
  ];
  bool('Status Call OK?', '={{ $json.ok === true }}');
  for (const route of routes) {
    providerRequest(get(route.http, 'httpRequest'), route.expected, 'status');
    code(route.parse, `${factory}\nconst expected=${binding(route.expected)};\ntry { return [{json:{...contract.status($input.item.json,expected),transactionId:expected.transactionId,userId:expected.userId}}]; } catch { ${failed} }`);
    bool(route.paidIf, '={{ $json.ok === true && $json.paymentStatus === "PAID" }}');
    bool(route.declineIf, '={{ $json.ok === true && $json.paymentStatus === "DECLINED" }}');
    const validateHttp = `Legacy ${route.key} Validate Payment`, validateCode = `Legacy ${route.key} Validation`, validateIf = `Legacy ${route.key} Validation OK?`;
    const request = add(validateHttp, 'httpRequest', { authentication: 'genericCredentialType', genericAuthType: 'httpCustomAuth',
      sendHeaders: true, headerParameters: { parameters: [{ name: 'Content-Type', value: 'application/json' }, { name: 'Accept', value: 'application/json' }] } }, route.paidIf, 180, -180);
    request.credentials = { httpCustomAuth: { id: null, name: 'UNCONFIGURED — Proxo FastPay validation' } };
    providerRequest(request, route.expected, 'validate');
    add(validateCode, 'code', { jsCode: `${factory}\nconst expected=${binding(route.expected)};\ntry {\n const observed=$('${route.parse}').item.json;\n if(observed.ok!==true||observed.paymentStatus!=='PAID'||typeof observed.gwTransactionId!=='string') throw new Error('FASTPAY_STATUS_REQUIRED');\n const verified=contract.validate($input.item.json,{...expected,gwTransactionId:observed.gwTransactionId});\n return [{json:{...verified,transactionId:expected.transactionId,userId:expected.userId}}];\n} catch { ${failed} }` }, validateHttp);
    addBool(validateIf, '={{ $json.ok === true && $json.verified === true }}', validateCode);
    connect(route.paidIf, validateHttp, route.declineIf);
    connect(validateHttp, validateCode); connect(validateCode, validateIf); connect(validateIf, route.credit, route.failure);
    if (route.key === 'App') {
      addBool('Legacy App Status OK?', '={{ $json.ok === true }}', route.parse);
      connect(route.parse, 'Legacy App Status OK?'); connect('Legacy App Status OK?', route.paidIf, publicUnavailable);
    }
  }

  // Only a confirmed credit response may reach fulfillment or advertise paid.
  // A rejected/ambiguous RPC result leaves the original order in recovery.
  const creditRoutes = [{ key: 'IPN', expected: 'Legacy IPN Binding', credit: 'Mark PAID + Credit Wallet + Notify (Supabase)',
    success: 'Trigger Fulfillment (dispense / confirm)', failure: 'Ack IPN (Not Matched)', source: 'ipn' }, ...routes];
  for (const route of creditRoutes) {
    const node = get(route.credit, 'httpRequest');
    fullResponse(node);
    node.parameters.jsonBody = `={{ (()=>{const value=$json,expected=${binding(route.expected)};if(value.ok!==true||value.verified!==true||value.orderId!==expected.orderId)throw new Error('FASTPAY_VERIFICATION_REQUIRED');return {p_order_id:expected.orderId,p_gw_transaction_id:value.gwTransactionId,p_received_amount:value.receivedAmount,p_currency:value.currency,p_source:'${route.source}',p_payload:{merchant_order_id:value.orderId,gw_transaction_id:value.gwTransactionId,received_amount:value.receivedAmount,currency:value.currency,status:'success'}};})() }}`;
    const guard = `Legacy ${route.key} Credit Confirmed`, gate = `Legacy ${route.key} Credit OK?`;
    add(guard, 'code', { jsCode: `${factory}\nconst expected=${binding(route.expected)};\ntry { return [{json:{...contract.credited($input.item.json,expected),creditConfirmed:true}}]; } catch { ${failed} }` }, route.credit);
    addBool(gate, '={{ $json.creditConfirmed === true && $json.paid === true }}', guard);
    connect(route.credit, guard); connect(guard, gate); connect(gate, route.success, route.failure);
  }
  get('Respond App Payment Paid', 'respondToWebhook').parameters = { respondWith: 'json',
    responseBody: '={{ {success:$json.creditConfirmed===true,orderId:$json.orderId,transactionId:$json.transactionId,status:$json.status,gatewayStatus:$json.gatewayStatus,paid:$json.paid===true,terminal:$json.creditConfirmed===true} }}', options: { responseCode: 200 } };

  // Non-paid observations cannot prove irreversible finality. A declined or
  // locally expired order still reaches later independent payment verification.
  bool('App Payment Final?', '={{ ($json.tx.status === "approved" && $json.tx.gateway_status === "PAID" && $json.tx.wallet_credited === true) || ($json.tx.gateway_status === "REFUNDED" && $json.tx.wallet_debited === true) }}');
  get('Respond Stored Payment Status', 'respondToWebhook').parameters = { respondWith: 'json', responseBody: '={{ {success:true,orderId:$json.orderId,transactionId:$json.transactionId,status:$json.tx.status,gatewayStatus:$json.tx.gateway_status,paid:$json.tx.status==="approved"&&$json.tx.gateway_status==="PAID"&&$json.tx.wallet_credited===true,terminal:true,adId:$json.tx.ad_id} }}', options: { responseCode: 200 } };
  const select = get('Get App Payment (Supabase)', 'httpRequest').parameters.queryParameters?.parameters?.find(parameter => parameter.name === 'select');
  // The caller may already have replaced this legacy read by the bound journal
  // RPC. Only extend the original select when that query is still present.
  if (select && typeof select.value === 'string' && !select.value.split(',').includes('wallet_debited')) select.value += ',wallet_debited';
  for (const [name, expectedNode, sourceNode] of [
    ['Mark Declined / Expired (Supabase)', 'Legacy Poll Binding', 'Parse Status Response'],
    ['Mark Declined From App (Supabase)', 'Normalize App Payment', 'Parse FastPay App Status'],
  ]) {
    const node = get(name, 'httpRequest'); fullResponse(node);
    node.parameters.jsonBody = `={{ (()=>{const value=$('${sourceNode}').item.json,expected=${binding(expectedNode)};if(value.ok!==true||value.paymentStatus!=='DECLINED'||value.orderId!==expected.orderId)throw new Error('FASTPAY_DECLINE_NOT_VERIFIED');return {p_order_id:expected.orderId,p_gateway_status:'DECLINED',p_payload:{merchant_order_id:expected.orderId,payment_status:'DECLINED'}};})() }}`;
  }
  const declineGuard = 'Legacy App Decline Confirmed', declineGate = 'Legacy App Decline OK?';
  add(declineGuard, 'code', { jsCode: `const expected=${binding('Normalize App Payment')};\ntry {\n const response=$input.item.json;\n if(response.statusCode!==200)throw new Error('FASTPAY_DECLINE_UNAVAILABLE');\n const body=typeof response.body==='string'?JSON.parse(response.body):response.body;\n if(!body||body.ok!==true||body.transaction_id!==expected.transactionId||!['DECLINED','EXPIRED'].includes(body.gateway_status))throw new Error('FASTPAY_DECLINE_UNAVAILABLE');\n return [{json:{ok:true,orderId:expected.orderId,transactionId:body.transaction_id,gatewayStatus:body.gateway_status}}];\n} catch { return [{json:{ok:false}}]; }` }, 'Mark Declined From App (Supabase)');
  addBool(declineGate, '={{ $json.ok === true }}', declineGuard);
  connect('Mark Declined From App (Supabase)', declineGuard); connect(declineGuard, declineGate); connect(declineGate, 'Respond App Payment Declined', publicUnavailable);
  get('Respond App Payment Declined', 'respondToWebhook').parameters = { respondWith: 'json', responseBody: '={{ {success:$json.ok===true,orderId:$json.orderId,transactionId:$json.transactionId,gatewayStatus:$json.gatewayStatus,paid:false,terminal:false} }}', options: { responseCode: 200 } };
  get('Respond App Payment Pending', 'respondToWebhook').parameters = { respondWith: 'json', responseBody: '={{ {success:$json.ok===true,orderId:$json.orderId,transactionId:$json.transactionId,gatewayStatus:$json.paymentStatus,paid:false,terminal:false} }}', options: { responseCode: 200 } };
  return workflow;
}
