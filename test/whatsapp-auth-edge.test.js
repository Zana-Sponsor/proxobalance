import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

// Execute the actual Edge handlers. Every Supabase transport is intercepted;
// no live Auth user, provider message or production write is possible.
function handler(name, options = {}) {
  const calls = [];
  const uid = '11111111-1111-4111-8111-111111111111';
  const otpId = '22222222-2222-4222-8222-222222222222';
  const admin = {
    rpc: async (rpc, params) => {
      calls.push({ rpc, params });
      if (rpc === 'pa_verify_whatsapp_otp') return options.verifyFails
        ? { error: { message: 'fixture verification outage' } }
        : { data: { success: true, data: { verified: options.verified ?? true, otp_id: otpId } } };
      if (rpc === 'pa_profile_by_phone') return options.lookupFails
        ? { error: { message: 'fixture lookup failure' } }
        : { data: options.existing ? [{id:uid,is_banned:options.banned ?? false,match_count:options.matches ?? 1}] : [] };
      assert.equal(rpc, 'pa_record_signup_whatsapp_marketing');
      return options.consentFails ? { error: { message: 'fixture failure' } } : { data: { ok: true } };
    },
    from: table => {
      let operation;
      const chain = {
        select: fields => { operation = 'select'; calls.push({ table, fields }); return chain; },
        eq: (field, value) => { calls.push({ table, field, value }); return chain; },
        is: () => chain,
        maybeSingle: async () => ({ data: options.existing ? { id: uid, is_banned: options.banned ?? false } : null }),
        upsert: async value => { calls.push({ table, upsert: value }); return options.profileWriteFails ? { error: { message: 'fixture write failure' } } : {}; },
        update: value => { operation = 'update'; calls.push({ table, update: value }); return chain; },
        then: resolve => resolve(operation === 'update' ? (options.auditFails ? { error: { message: 'fixture audit failure' } } : {}) : { data: null }),
      };
      return chain;
    },
    auth: { admin: {
      createUser: async value => { calls.push({ create: value }); return options.createError ? { error: { message: options.createError } } : { data: { user: { id: uid } } }; },
      deleteUser: async id => { calls.push({ delete: id }); return {}; },
      getUserById: async id => { calls.push({ get: id }); return options.authLookupFails ? { error: { message: 'fixture auth outage' } } : { data: { user: { email: options.noEmail ? '' : 'fixture@example.invalid' } } }; },
      generateLink: async value => { calls.push({ mint: value }); return options.mintFails ? { error: { message: 'fixture mint failure' } } : { data: { properties: { hashed_token: options.noHash ? null : 'fixture-hash' } } }; },
    } },
  };
  const anon = { auth: { verifyOtp: async params => {
    calls.push({ redeem: params });
    return options.redeemFails ? { error: { message: 'fixture redemption outage' } }
      : { data: { session: options.noSession ? null : { access_token: 'fixture-access', refresh_token: options.noRefresh ? null : 'fixture-refresh' } } };
  } } };
  let serve;
  const source = readFileSync(new URL(`../proxo_app/supabase/functions/${name}/index.ts`, import.meta.url), 'utf8')
    .replace(/^import .*?;\s*$/m, '');
  const context = vm.createContext({ Response, console: { error() {} },
    createClient: (_url, key) => key === 'SUPABASE_ANON_KEY' ? anon : admin,
    Deno: { env: { get: key => key }, serve: fn => { serve = fn; } },
  });
  vm.runInContext(stripTypeScriptTypes(source), context);
  return { calls, request: async body => {
    const response = await serve(new Request('https://fixture.invalid', {
      method: 'POST', body: JSON.stringify(body), headers: { 'content-type': 'application/json' },
    }));
    return { status: response.status, body: await response.json() };
  } };
}
const signup = { phone: '+9647500000001', code: '012345', full_name: 'Fixture User', password: 'Example#9' };

test('signup saves optional acceptance/refusal and exact displayed locale before minting', async () => {
  for (const choice of [undefined, false, true]) {
    const h = handler('phone-otp-session');
    const result = await h.request({ ...signup, whatsapp_marketing_opt_in: choice, whatsapp_consent_locale: 'ar' });
    assert.equal(result.status, 200);
    const consent = h.calls.find(x => x.rpc === 'pa_record_signup_whatsapp_marketing');
    assert.equal(consent.params.p_opted_in, choice ?? false);
    assert.equal(consent.params.p_version, 'whatsapp-marketing-v1');
    assert.equal(consent.params.p_locale, 'ar');
    assert.equal(h.calls.find(x => x.rpc === 'pa_verify_whatsapp_otp').params.p_purpose, 'signup');
    assert.ok(h.calls.indexOf(consent) < h.calls.findIndex(x => x.mint));
    assert.ok(h.calls.some(x => x.table === 'otp_whatsapp' && x.field === 'id' && x.value === '22222222-2222-4222-8222-222222222222'));
    assert.equal(h.calls.find(x => x.create).create.phone_confirm, true);
  }
});
test('malformed consent rejected before consuming OTP', async () => {
  for (const extra of [{ whatsapp_marketing_opt_in: 'true' }, { whatsapp_consent_version: 'forged' }, { whatsapp_consent_locale: 'invalid' }]) {
    const h = handler('phone-otp-session');
    assert.equal((await h.request({ ...signup, ...extra })).status, 400);
    assert.equal(h.calls.length, 0);
  }
});
test('wrong code cannot create an account or record consent', async () => {
  const h = handler('phone-otp-session', { verified: false });
  assert.equal((await h.request(signup)).status, 401);
  assert.equal(h.calls.length, 1);
});
test('consent persistence failure rolls back new account and withholds session', async () => {
  const h = handler('phone-otp-session', { consentFails: true });
  assert.equal((await h.request({ ...signup, whatsapp_marketing_opt_in: true })).status, 500);
  assert.ok(h.calls.some(x => x.delete));
  assert.ok(!h.calls.some(x => x.mint));
});
test('signup cannot overwrite an existing account or its consent', async () => {
  const h = handler('phone-otp-session', { existing: true });
  assert.equal((await h.request(signup)).status, 409);
  assert.ok(!h.calls.some(x => x.create || x.rpc === 'pa_record_signup_whatsapp_marketing'));
});
test('login consumes only login OTPs and never changes marketing preference', async () => {
  const h = handler('whatsapp-session-exchange', { existing: true });
  assert.equal((await h.request(signup)).status, 200);
  assert.equal(h.calls.find(x => x.rpc).params.p_purpose, 'login');
  assert.ok(!h.calls.some(x => x.create || x.rpc === 'pa_record_signup_whatsapp_marketing'));
  const banned = handler('whatsapp-session-exchange', { existing: true, banned: true });
  assert.equal((await banned.request(signup)).status, 403);
  assert.ok(!banned.calls.some(x => x.mint));
});

test('canonical profile lookup is preserved and ambiguous numbers cannot mint sessions', async () => {
  const h=handler('whatsapp-session-exchange',{existing:true,matches:2});
  const result=await h.request(signup);
  assert.equal(result.status,409);
  assert.equal(result.body.error,'ambiguous_phone');
  assert.ok(h.calls.some(x=>x.rpc==='pa_profile_by_phone'));
  assert.ok(!h.calls.some(x=>x.mint||x.get));
});
test('legacy and Kurdish phone forms normalize identically before verification', async () => {
  for(const phone of ['07500000001','009647500000001','+96407500000001','٠٧٥٠٠٠٠٠٠٠١','۰۷۵۰۰۰۰۰۰۰۱']){
    const h=handler('whatsapp-session-exchange',{existing:true});
    assert.equal((await h.request({...signup,phone})).status,200,phone);
    assert.equal(h.calls.find(x=>x.rpc==='pa_verify_whatsapp_otp').params.p_phone,'+9647500000001');
    assert.equal(h.calls.find(x=>x.rpc==='pa_profile_by_phone').params.p_phone,'+9647500000001');
  }
});
test('canonical lookup errors stop signup and login without account or session writes', async () => {
  for(const name of ['phone-otp-session','whatsapp-session-exchange']){
    const h=handler(name,{lookupFails:true});
    assert.equal((await h.request(signup)).status,500);
    assert.ok(!h.calls.some(x=>x.create||x.mint));
  }
});
test('null, numeric and malformed OTP input is rejected before any database access', async () => {
  for(const name of ['phone-otp-session','whatsapp-session-exchange']){
    for(const code of [null,123456,{},'12345','1234567']){
      const h=handler(name);
      assert.equal((await h.request({...signup,code})).status,400);
      assert.equal(h.calls.length,0);
    }
  }
});

test('verification outages and false verification cannot reach account lookup or session minting', async () => {
  for (const name of ['phone-otp-session', 'whatsapp-session-exchange']) {
    for (const options of [{ verifyFails: true }, { verified: false }]) {
      const h = handler(name, options);
      const r = await h.request(signup);
      assert.equal(r.status, options.verifyFails ? 500 : 401);
      assert.equal(r.body.error, options.verifyFails ? 'verify_failed' : 'invalid_code');
      assert.equal(h.calls.length, 1);
    }
  }
});

test('missing, malformed and unavailable login accounts withhold sessions', async () => {
  for (const [options, status, error] of [
    [{}, 404, 'user_not_found'],
    [{ existing: true, matches: 0 }, 500, 'lookup_failed'],
    [{ existing: true, authLookupFails: true }, 500, 'lookup_failed'],
    [{ existing: true, noEmail: true }, 409, 'no_email_on_account'],
  ]) {
    const h = handler('whatsapp-session-exchange', options);
    const r = await h.request(signup);
    assert.equal(r.status, status);
    assert.equal(r.body.error, error);
    assert.ok(!h.calls.some(x => x.create || x.mint || x.redeem));
  }
});

test('session mint and redemption errors return no proof or session tokens', async () => {
  for (const name of ['phone-otp-session', 'whatsapp-session-exchange']) {
    const failures = [{ mintFails: true }, { noHash: true }];
    if (name === 'whatsapp-session-exchange') failures.push({ redeemFails: true }, { noSession: true }, { noRefresh: true });
    for (const options of failures) {
      const h = handler(name, { existing: name === 'whatsapp-session-exchange', ...options });
      const r = await h.request(signup);
      assert.equal(r.status, 500);
      assert.deepEqual(r.body, { ok: false, error: 'session_failed' });
      if (options.mintFails || options.noHash) assert.ok(!h.calls.some(x => x.redeem));
    }
  }
});

test('signup provisioning failures cannot mint sessions and profile failures roll back the new user', async () => {
  for (const [options, status, error] of [
    [{ createError: 'fixture database outage' }, 500, 'provision_failed'],
    [{ createError: 'user already registered' }, 409, 'already_registered'],
    [{ profileWriteFails: true }, 500, 'provision_failed'],
  ]) {
    const h = handler('phone-otp-session', options);
    const r = await h.request(signup);
    assert.equal(r.status, status);
    assert.equal(r.body.error, error);
    assert.ok(!h.calls.some(x => x.mint || x.rpc === 'pa_record_signup_whatsapp_marketing'));
    assert.equal(h.calls.some(x => x.delete), !!options.profileWriteFails);
  }
});

test('successful login redeems a magic link and returns both tokens even if audit backfill fails', async () => {
  const h = handler('whatsapp-session-exchange', { existing: true, auditFails: true });
  const r = await h.request(signup);
  assert.equal(r.status, 200);
  assert.equal(r.body.access_token, 'fixture-access');
  assert.equal(r.body.refresh_token, 'fixture-refresh');
  assert.equal(h.calls.find(x => x.redeem).redeem.type, 'magiclink');
  assert.equal(h.calls.find(x => x.redeem).redeem.token_hash, 'fixture-hash');
  assert.ok(h.calls.findIndex(x => x.mint) < h.calls.findIndex(x => x.redeem));
  assert.ok(!h.calls.some(x => x.create || x.delete));
});

test('weak signup passwords and short names do not consume a valid OTP', async () => {
  for (const patch of [{ password: 'short' }, { password: 'onlyletters' }, { full_name: 'AB' }]) {
    const h = handler('phone-otp-session');
    const r = await h.request({ ...signup, ...patch });
    assert.equal(r.status, 400);
    assert.equal(h.calls.length, 0);
  }
});

