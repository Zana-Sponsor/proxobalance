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
      if (rpc === 'pa_verify_whatsapp_otp') return { data: { success: true, data: { verified: options.verified ?? true, otp_id: otpId } } };
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
        upsert: async value => { calls.push({ table, upsert: value }); return {}; },
        update: value => { operation = 'update'; calls.push({ table, update: value }); return chain; },
        then: resolve => resolve(operation === 'update' ? {} : { data: null }),
      };
      return chain;
    },
    auth: { admin: {
      createUser: async value => { calls.push({ create: value }); return { data: { user: { id: uid } } }; },
      deleteUser: async id => { calls.push({ delete: id }); return {}; },
      getUserById: async id => { calls.push({ get: id }); return { data: { user: { email: 'fixture@example.invalid' } } }; },
      generateLink: async value => { calls.push({ mint: value }); return { data: { properties: { hashed_token: 'fixture-hash' } } }; },
    } },
  };
  const anon = { auth: { verifyOtp: async () => ({ data: { session: { access_token: 'fixture-access', refresh_token: 'fixture-refresh' } } }) } };
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

