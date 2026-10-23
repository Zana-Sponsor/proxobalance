/** Disposable PostgreSQL verification; no deployed DB, credentials or provider calls.
 * PGLITE_MODULE=/absolute/path/@electric-sql/pglite/dist/index.js node scripts/test-tiktok-oauth-database.mjs
 */
import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import { randomUUID, randomBytes, createHash } from 'node:crypto';
import { pathToFileURL } from 'node:url';
import { encryptPrivate, decryptPrivate } from '../api/_lib/tiktok/oauth.js';
const { PGlite } = await import(process.env.PGLITE_MODULE ? pathToFileURL(process.env.PGLITE_MODULE).href : '@electric-sql/pglite');
const db = new PGlite();
let checks = 0;
const check = (value, message) => { assert.ok(value, message); checks++; };
const read = path => fs.readFile(new URL('../' + path, import.meta.url), 'utf8');
const scalar = async (sql, args = []) => (await db.query(sql, args)).rows[0]?.v;
const user = randomUUID(), other = randomUUID();
const cryptoConfig = { key: randomBytes(32), kid: 'test-key' };
async function role(name, run) { await db.exec(`set role ${name}`); try { return await run(); } finally { await db.exec('reset role'); } }
const service = (action, { userId = null, id = null, token = null, payload = {} } = {}) => role('service_role', () => scalar('select public.pa_tiktok_dm_service($1,$2,$3,$4,$5::jsonb) v', [action, userId, id, token, JSON.stringify(payload)]));
async function denied(sql, name = 'authenticated') { await assert.rejects(role(name, () => db.exec(sql)), { code: '42501' }); checks++; }
function startPayload(key, owner = user) {
  const state = randomBytes(32).toString('base64url');
  return { requested_username: 'fixture_user', state_hash: createHash('sha256').update(state).digest('hex'),
    state_ciphertext: encryptPrivate({ state }, `tiktok:state:${owner}:${key}`, cryptoConfig),
    app_id: '123456', redirect_uri: 'https://example.test/tiktok/oauth/', expires_at: new Date(Date.now() + 600000).toISOString() };
}
async function start(owner = user) { const key = randomUUID(), payload = startPayload(key, owner); const row = await service('oauth_start', { userId: owner, id: key, payload }); check(row.ok, 'start fixture authorized'); return { row, payload, key }; }
const claim = fixture => service('oauth_claim', { payload: { state_hash: fixture.payload.state_hash } });
const complete = (row, payload) => service('oauth_complete', { id: row.id, token: row.lease_token, payload });
function credentials(row, { openId = 'provider-open-id', username = row.requested_username, status = 'VERIFIED_UNLINKED' } = {}) {
  return { status, authorized_username: username, open_id: openId, scope: ['user.info.basic', 'user.info.username'],
    credential_ciphertext: encryptPrivate({ access_token: 'synthetic-access', refresh_token: 'synthetic-refresh', open_id: openId }, `tiktok:oauth:${row.user_id}:${row.id}`, cryptoConfig),
    access_expires_at: new Date(Date.now() + 300000).toISOString(), refresh_expires_at: new Date(Date.now() + 86400000).toISOString(),
    evidence: { app_id: row.app_id, token_creator_id: openId, profile_username: username, verified_at: new Date().toISOString(), request_ids: { exchange: 'exchange-1', token_info: 'info-1', profile: 'profile-1' } } };
}
async function resetLimit() { await db.query("delete from app_finance.request_limits where operation='tiktok_oauth_start'"); }
async function expiredLease(id) { await db.query("update app_tiktok_dm.oauth_requests set lease_until=now()-interval '1 minute' where id=$1", [id]); }
try {
  await db.exec(await read('test/fixtures/secure-operations-database.sql'));
  await db.exec(await read('proxo_app/supabase/migrations/20261016174350_secure_financial_operations.sql'));
  const checkout = await read('proxo_app/supabase/migrations/20260913210000_fastpay_ad_checkout.sql');
  await db.exec(checkout.slice(checkout.indexOf('create or replace function public.pa_quote_ad_checkout('), checkout.indexOf('revoke all on function public.pa_quote_ad_checkout(')));
  const migrationDirectory = new URL('../proxo_app/supabase/migrations/', import.meta.url);
  for (const file of (await fs.readdir(migrationDirectory)).filter(file => file >= '20261022235825_' && file.endsWith('.sql')).sort()) {
    await db.exec(await read('proxo_app/supabase/migrations/' + file));
  }
  await db.query('insert into auth.users(id,email_confirmed_at) values($1,now()),($2,now())', [user, other]);
  await db.query('insert into public.profiles(id) values($1),($2)', [user, other]);
  const key = randomUUID(), input = startPayload(key);
  check((await service('oauth_start', { userId: user, id: key, payload: input })).code === 'TIKTOK_CONNECTION_DISABLED', 'connection default OFF');
  await db.exec('update app_tiktok_dm.settings set connection_enabled=true');
  check((await service('oauth_start', { userId: user, id: key, payload: input })).code === 'TIKTOK_CONNECTION_DISABLED', 'connection needs private tester');
  await db.query('insert into app_tiktok_dm.testers(user_id,enabled) values($1,true),($2,true)', [user, other]);
  check(await scalar('select not enabled and not activation_enabled v from app_tiktok_dm.settings'), 'connection does not enable paid creation or activation');
  let pending = await service('oauth_start', { userId: user, id: key, payload: input });
  check(pending.ok && pending.status === 'PENDING' && pending.user_id === user && pending.idempotency_key === key, 'private pending request bound to user/idempotency');
  check(!('state_hash' in pending), 'state hash excluded from private return');
  const retried = await service('oauth_start', { userId: user, id: key, payload: startPayload(key) });
  assert.deepEqual(retried, pending); checks++;
  check((await service('oauth_start', { userId: user, id: key, payload: { ...input, requested_username: 'different' } })).code === 'IDEMPOTENCY_CONFLICT', 'idempotency mismatch rejected');
  check((await service('oauth_status', { userId: other, id: pending.id })).code === 'TIKTOK_OAUTH_REQUEST_NOT_FOUND', 'status owner isolated');
  check((await service('oauth_revoke', { userId: other, id: pending.id })).code === 'TIKTOK_OAUTH_REQUEST_NOT_FOUND', 'revoke owner isolated');
  check((await service('list_accounts', { userId: user })).pending_request.id === pending.id, 'private pending request listed for owner');
  check((await service('list_accounts', { userId: other })).pending_request === null, 'pending request never cross-owner');
  for (const table of ['oauth_requests', 'oauth_events']) for (const name of ['anon', 'authenticated', 'service_role']) await denied(`select * from app_tiktok_dm.${table}`, name);
  await denied("select public.pa_tiktok_dm_service('oauth_start')");
  await denied("select app_tiktok_dm.service_before_oauth('list_accounts')", 'service_role');
  check(await scalar("select bool_and(relrowsecurity) v from pg_class where oid in ('app_tiktok_dm.oauth_requests'::regclass,'app_tiktok_dm.oauth_events'::regclass)"), 'private tables RLS enabled');
  check((await service('oauth_start', { userId: user, id: randomUUID(), payload: { ...startPayload(randomUUID()), access_token: 'plaintext-secret' } })).code === 'INVALID_INPUT', 'plaintext unexpected field rejected');
  check((await service('oauth_start', { userId: user, id: randomUUID(), payload: { ...startPayload(randomUUID()), state_ciphertext: { v: 1, token: 'plaintext-secret' } } })).code === 'INVALID_INPUT', 'unencrypted envelope rejected');
  await resetLimit();
  for (let i = 0; i < 5; i++) await start(other);
  const excessKey = randomUUID();
  check((await service('oauth_start', { userId: other, id: excessKey, payload: startPayload(excessKey, other) })).code === 'RATE_LIMITED', 'starts rate limited');
  await resetLimit();
  await db.exec('update app_tiktok_dm.settings set connection_enabled=false');
  assert.deepEqual(await service('oauth_start', { userId: user, id: key, payload: input }), pending); checks++;
  const first = await service('oauth_claim', { payload: { state_hash: input.state_hash } });
  check(first.status === 'EXCHANGING' && first.lease_token, 'existing callback survives gate OFF and consumes state');
  check((await service('oauth_claim', { payload: { state_hash: input.state_hash } })).code === 'TIKTOK_AUTHORIZATION_REPLAY', 'second callback cannot re-exchange');
  check((await service('oauth_claim', { payload: { state_hash: 'f'.repeat(64) } })).code === 'TIKTOK_CALLBACK_INVALID', 'unknown state rejected');
  check((await service('oauth_complete', { id: first.id, token: randomUUID(), payload: credentials(first) })).code === 'STALE_LEASE', 'wrong callback lease rejected');
  let credential = credentials(first);
  const saving = await complete(first, { ...credential, status: 'VERIFYING', evidence: { app_id: first.app_id, verified_at: new Date().toISOString(), request_ids: { exchange: 'exchange-1' } } });
  check(saving.ok, `grant save succeeds: ${saving.code || ''}`);
  check(saving.status === 'VERIFYING' && saving.credential_ciphertext && saving.lease_token === first.lease_token, 'encrypted grant durable immediately while callback lease retained');
  check((await complete(first, { ...credential, evidence: { ...credential.evidence, token_creator_id: 'wrong' } })).code === 'INVALID_OAUTH_EVIDENCE', 'provider open ID evidence required');
  check((await complete(first, { ...credential, authorized_username: 'wrong' })).code === 'INVALID_OAUTH_EVIDENCE', 'username cannot independently authorize');
  const verified = await complete(first, credential);
  check(verified.status === 'VERIFIED_UNLINKED' && verified.grant_status === 'ACTIVE' && !verified.lease_token, 'verified user grant remains unlinked');
  check(await scalar('select count(*)=0 v from app_tiktok_dm.accounts'), 'OAuth never creates CONNECTED advertising account');
  const plaintext = decryptPrivate(verified.credential_ciphertext, `tiktok:oauth:${user}:${first.id}`, cryptoConfig);
  check(plaintext.access_token === 'synthetic-access', 'persisted ciphertext decrypts with owner/request AAD');
  assert.throws(() => decryptPrivate(verified.credential_ciphertext, `tiktok:oauth:${other}:${first.id}`, cryptoConfig)); checks++;
  check(!JSON.stringify(await scalar('select jsonb_agg(to_jsonb(r)) v from app_tiktok_dm.oauth_requests r')).includes('synthetic-access'), 'no plaintext token persisted');
  check((await complete(first, credential)).code === 'STALE_LEASE', 'callback completion cannot be reused');
  const refresh = await service('oauth_token_claim', { payload: { kind: 'refresh' } });
  check(refresh.id === first.id && refresh.lease_kind === 'refresh', 'near expiry grant claimed independent of paid gate');
  check(await service('oauth_token_claim', { payload: { kind: 'refresh' } }) === null, 'no concurrent refresh claim');
  const rotated = credentials(refresh);
  delete rotated.status; delete rotated.authorized_username; delete rotated.evidence;
  const renewed = await service('oauth_token_complete', { id: first.id, token: refresh.lease_token, payload: { ...rotated, status: 'REFRESHED', provider_request_id: 'refresh-1' } });
  check(renewed.grant_status === 'ACTIVE' && !renewed.lease_token, 'rotated encrypted credential stored');
  const ambiguous = await service('oauth_token_claim', { payload: { kind: 'refresh' } });
  await expiredLease(ambiguous.id);
  check(await service('oauth_token_claim', { payload: { kind: 'refresh' } }) === null, 'expired refresh lease never blindly retries old refresh token');
  check((await service('oauth_status', { userId: user, id: first.id })).grant_status === 'RECONCILE', 'unknown rotation kept for protected recovery');
  const revokedRequest = await service('oauth_revoke', { userId: user, id: first.id });
  check(revokedRequest.grant_status === 'REVOKING', 'owner can queue revoke even when gate OFF');
  const revoke = await service('oauth_token_claim', { payload: { kind: 'revoke' } });
  const revoked = await service('oauth_token_complete', { id: first.id, token: revoke.lease_token, payload: { status: 'REVOKED', provider_request_id: 'revoke-1' } });
  check(revoked.status === 'REVOKED' && revoked.credential_ciphertext === null && revoked.access_expires_at === null, 'verified revocation clears token material');
  check((await service('oauth_revoke', { userId: user, id: first.id })).status === 'REVOKED', 'revoke idempotent');
  await db.exec('update app_tiktok_dm.settings set connection_enabled=true');
  await resetLimit();
  const mismatch = await claim(await start());
  const mismatchResult = await complete(mismatch, credentials(mismatch, { username: 'different_user', status: 'USERNAME_MISMATCH' }));
  check(mismatchResult.status === 'USERNAME_MISMATCH' && mismatchResult.grant_status === 'REVOKING', 'wrong username automatically queues encrypted grant revocation');
  const lost = await claim(await start());
  const lostCred = credentials(lost);
  await complete(lost, { ...lostCred, status: 'VERIFYING' });
  const failed = await service('oauth_fail', { id: lost.id, token: lost.lease_token, payload: { status: 'UNAVAILABLE', error_code: 'TIKTOK_OAUTH_UNAVAILABLE', grant_exchanged: true } });
  check(failed.credential_ciphertext && failed.grant_status === 'REVOKING', 'downstream failure retains encrypted token for revoke');
  const abandoned = await claim(await start());
  await expiredLease(abandoned.id);
  await service('oauth_token_claim', { payload: { kind: 'refresh' } });
  check((await service('oauth_claim', { payload: { state_hash: await scalar('select state_hash v from app_tiktok_dm.oauth_requests where id=$1', [abandoned.id]) } })).code === 'TIKTOK_AUTHORIZATION_REPLAY', 'abandoned callback never exchanges code again');
  const cancelled = await start();
  check((await service('oauth_revoke', { userId: user, id: cancelled.row.id })).status === 'REVOKED', 'pending cancellation needs no external token call');
  check((await claim(cancelled)).code === 'TIKTOK_AUTHORIZATION_REPLAY', 'cancelled nonce cannot authorize');
  // An expired request is inserted only into this disposable fixture to advance
  // its clock; production never changes immutable state expiry after issuance.
  const expiredKey = randomUUID(), expiredInput = startPayload(expiredKey);
  const expiredId = await scalar(`insert into app_tiktok_dm.oauth_requests(user_id,idempotency_key,requested_username,state_hash,state_ciphertext,app_id,redirect_uri,expires_at)
    values($1,$2,$3,$4,$5::jsonb,$6,$7,now()-interval '1 minute') returning id v`,
    [user, expiredKey, expiredInput.requested_username, expiredInput.state_hash, JSON.stringify(expiredInput.state_ciphertext), expiredInput.app_id, expiredInput.redirect_uri]);
  check((await service('oauth_claim', { payload: { state_hash: expiredInput.state_hash } })).code === 'TIKTOK_AUTHORIZATION_EXPIRED', 'expired nonce never exchanged');
  check((await service('oauth_status', { userId: user, id: expiredId })).status === 'EXPIRED', 'expiration durably visible to polling');
  check((await service('oauth_start', { userId: user, id: expiredKey, payload: expiredInput })).status === 'EXPIRED', 'idempotent retry never regenerates expired state');
  await resetLimit();
  const missingPermission = await claim(await start());
  const missingGrant = credentials(missingPermission);
  const incomplete = { ...missingGrant, status: 'VERIFYING', scope: ['user.info.basic'], evidence: { app_id: missingPermission.app_id, verified_at: new Date().toISOString(), request_ids: { exchange: 'exchange-scope' } } };
  check((await complete(missingPermission, incomplete)).ok, 'grant retained before scope read');
  const { evidence: unusedEvidence, ...missingFinal } = incomplete;
  check((await complete(missingPermission, { ...missingFinal, status: 'MISSING_PERMISSION', error_code: 'TIKTOK_OAUTH_SCOPE_MISSING' })).grant_status === 'REVOKING', 'missing scope with retained initial evidence queues revoke');
  const badError = await claim(await start());
  check((await service('oauth_fail', { id: badError.id, token: badError.lease_token, payload: { status: 'REJECTED', error_code: 'raw provider text with secret' } })).code === 'INVALID_INPUT', 'arbitrary errors cannot enter private audit');
  const rejected = await service('oauth_fail', { id: badError.id, token: badError.lease_token, payload: { status: 'REJECTED', error_code: 'TIKTOK_AUTHORIZATION_REJECTED' } });
  check(rejected.status === 'REJECTED' && rejected.grant_status === 'NONE', 'user authorization denial consumes session without inventing token');
  const scopeFixture = await claim(await start());
  await complete(scopeFixture, credentials(scopeFixture));
  const scopeRefresh = await service('oauth_token_claim', { payload: { kind: 'refresh' } });
  check(scopeRefresh.id === scopeFixture.id, 'authorized fixture selected for scope-loss rotation');
  const reduced = credentials(scopeRefresh); delete reduced.status; delete reduced.authorized_username; delete reduced.evidence;
  reduced.scope = ['user.info.basic'];
  const scopeLost = await service('oauth_token_complete', { id: scopeRefresh.id, token: scopeRefresh.lease_token, payload: { ...reduced, status: 'REFRESHED', provider_request_id: 'refresh-scope-lost' } });
  check(scopeLost.status === 'MISSING_PERMISSION' && scopeLost.grant_status === 'REVOKING' && scopeLost.error_code === 'TIKTOK_OAUTH_SCOPE_MISSING', 'removed refresh scopes queue revoke');
  assert.deepEqual(scopeLost.credential_ciphertext, reduced.credential_ciphertext); checks++;
  check(await service('oauth_token_claim', { payload: { kind: 'refresh' } }) === null, 'reduced-scope rotated grant never refreshes again');
  await assert.rejects(db.query('update app_tiktok_dm.oauth_requests set user_id=$2 where id=$1', [first.id, other]), { code: '42501' }); checks++;
  await assert.rejects(db.exec('delete from app_tiktok_dm.oauth_events'), { code: '42501' }); checks++;
  check(await scalar('select count(*)>10 v from app_tiktok_dm.oauth_events'), 'private immutable lifecycle audit recorded');
  check(await scalar('select count(*)=0 v from app_finance.outbox'), 'OAuth never dispatches paid provider creation');
  check((await service('seen', { userId: user })).ok, 'existing service action preserved through wrapper');
  console.log(`TikTok OAuth database: ${checks} assertions passed (isolated PostgreSQL; no runtime/provider calls).`);
} finally { await db.close(); }
