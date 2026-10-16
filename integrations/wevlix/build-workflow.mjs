import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';

const shared = readFileSync(new URL('./contracts.mjs', import.meta.url), 'utf8').replace(/^export /gm, '');
// Optional project URL produces an importable export without paid n8n Variables.
// This is a public origin only; credentials remain in n8n Credentials.
const configuredUrl = process.argv[2];
if (process.argv.length > 3 || (configuredUrl && !/^https:\/\/[a-z0-9]{20}\.supabase\.co\/?$/.test(configuredUrl))) {
  throw new Error('Usage: node build-workflow.mjs [https://<project-ref>.supabase.co]');
}
const supabaseBase = configuredUrl
  ? JSON.stringify(configuredUrl.replace(/\/$/, '')) : '$vars.PROXO_SUPABASE_URL';
const nodes = [], connections = {};
const id = name => name.toLowerCase().replace(/[^a-z0-9]+/g, '-');
function node(name, type, parameters, version = 2, extra = {}) {
  const result = { name, id: id(name), type: `n8n-nodes-base.${type}`, typeVersion: version,
    position: [nodes.length % 7 * 240, Math.floor(nodes.length / 7) * 260], parameters, ...extra };
  nodes.push(result); return name;
}
function link(from, to, output = 0) {
  connections[from] ??= { main: [] };
  connections[from].main[output] ??= [];
  connections[from].main[output].push({ node: to, type: 'main', index: 0 });
}
function code(name, expression) {
  return node(name, 'code', { mode: 'runOnceForEachItem', jsCode: `${shared}\nreturn {json: ${expression}};` });
}
function webhook(name, path, method = 'POST', internal = false) {
  return node(name, 'webhook', { httpMethod: method, path, responseMode: 'responseNode',
    ...(internal ? { authentication: 'headerAuth' } : {}), options: {} }, 2,
    { webhookId: id(name), ...(internal ? { credentials: { httpHeaderAuth: { name: 'Proxo internal webhook' } } } : {}) });
}
function http(name, path, body, provider = false, method = 'POST') {
  return node(name, 'httpRequest', { method,
    url: provider ? path : `={{ ${supabaseBase} + ${JSON.stringify(path)} }}`,
    authentication: 'genericCredentialType', genericAuthType: provider ? 'httpHeaderAuth' : 'httpCustomAuth',
    ...(body ? { sendBody: true, specifyBody: 'json', jsonBody: `={{ ${body} }}` } : {}),
    options: { timeout: 15000, response: { response: { fullResponse: true, neverError: true, responseFormat: 'json' } } },
  }, 4.2, { onError: 'continueRegularOutput', credentials: provider
    ? { httpHeaderAuth: { name: 'Proxo Wevlix server' } }
    : { httpCustomAuth: { name: 'Proxo Supabase service role' } } });
}
function gate(name, next, response) {
  const gateName = node(name + ' valid', 'if', { conditions: { options: { caseSensitive: true, typeValidation: 'strict', version: 2 },
    conditions: [{ id: id(name)+'-condition', leftValue: '={{ $json.proceed }}', rightValue: true,
      operator: { type: 'boolean', operation: 'true', singleValue: true } }], combinator: 'and' }, options: {} }, 2.2);
  link(name, gateName); link(gateName, next); link(gateName, response, 1);
}
function respond(name) { return node(name, 'respondToWebhook', { respondWith: 'json', responseBody: '={{ $json.response }}',
  options: { responseCode: '={{ $json.httpStatus }}' } }, 1.4); }

const sendResponse = respond('Respond send');
webhook('Send webhook', 'wevlix/otp/send');
code('Validate send', 'sendInput($json.body)'); link('Send webhook', 'Validate send');
http('Reserve OTP', '/rest/v1/rpc/get_or_generate_otp_whatsapp', '{p_phone: $json.phone, p_purpose: $json.purpose}');
gate('Validate send', 'Reserve OTP', sendResponse);
code('Prepare OTP', "reservation($json, $('Validate send').item.json)"); link('Reserve OTP','Prepare OTP');
http('Send OTP template','https://api.wevlix.com/v1/messages/template','$json.payload',true);
gate('Prepare OTP','Send OTP template',sendResponse);
code('Check OTP delivery','providerResult($json)');link('Send OTP template','Check OTP delivery');
http('Record delivery','/rest/v1/rpc/pa_finish_whatsapp_otp_send',
  "{p_otp_id: $('Prepare OTP').item.json.otpId, p_send_count: $('Prepare OTP').item.json.sendCount, p_message_id: $json.messageId, p_status: $json.status}");
gate('Check OTP delivery','Record delivery',sendResponse);
code('Finish send',"sendResult($json, $('Prepare OTP').item.json, $('Check OTP delivery').item.json)");
link('Record delivery','Finish send');link('Finish send',sendResponse);

const statusResponse=respond('Respond status');
webhook('Status webhook','wevlix/otp/status','GET',true);
code('Validate status','statusInput($json.query)');link('Status webhook','Validate status');
http('Read delivery',"={{ 'https://api.wevlix.com/v1/messages/' + encodeURIComponent($json.messageId) }}",null,true,'GET');
gate('Validate status','Read delivery',statusResponse);
code('Finish status','statusResult($json)');link('Read delivery','Finish status');link('Finish status',statusResponse);

const verifyResponse=respond('Respond verify');
webhook('Verify webhook','wevlix/otp/verify','POST',true);
code('Validate verify','verifyInput($json.body)');link('Verify webhook','Validate verify');
http('Verify code','/rest/v1/rpc/pa_verify_whatsapp_otp','{p_phone: $json.phone, p_code: $json.code, p_purpose: $json.purpose}');
gate('Validate verify','Verify code',verifyResponse);
code('Finish verify','verifyResult($json)');link('Verify code','Finish verify');link('Finish verify',verifyResponse);

const accountResponse=respond('Respond account');
webhook('Account webhook','wevlix/account/created','POST',true);
code('Validate account','accountInput($json.body)');link('Account webhook','Validate account');
http('Read new account','/auth/v1/admin/users/',null,false,'GET');
nodes.find(n=>n.name==='Read new account').parameters.url=`={{ ${supabaseBase} + '/auth/v1/admin/users/' + $json.userId }}`;
gate('Validate account','Read new account',accountResponse);
code('Prepare account',"accountPayload($json, $('Validate account').item.json)");link('Read new account','Prepare account');
http('Send account template','https://api.wevlix.com/v1/messages/template','$json.payload',true);
gate('Prepare account','Send account template',accountResponse);
code('Finish account',"(() => { const result = providerResult($json); return result.proceed ? {httpStatus: 200, response: {success: true, messageId: result.messageId, status: result.status}} : result; })()");
link('Send account template','Finish account');link('Finish account',accountResponse);

const workflow = { name: 'Proxo - Wevlix OTP and account confirmation (reviewed)', nodes, connections,
  active: false, settings: { executionOrder: 'v1', saveDataErrorExecution: 'none', saveDataSuccessExecution: 'none',
    saveManualExecutions: false, saveExecutionProgress: false }, pinData: {}, tags: [] };
const output = configuredUrl ? './proxo-wevlix-configured.json' : './proxo-wevlix.json';
writeFileSync(fileURLToPath(new URL(output, import.meta.url)), JSON.stringify(workflow,null,2)+'\n');
console.log(`${nodes.length} nodes; no embedded credentials; inactive export: ${output}`);
