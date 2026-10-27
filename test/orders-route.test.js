import assert from 'node:assert/strict';
import test from 'node:test';

process.env.SUPABASE_SERVICE_ROLE_KEY = 'test-service-key';
process.env.SECURITY_FINGERPRINT_SALT = 'test-fingerprint-salt';
process.env.TRUSTED_PROXY = 'direct';

const { default: ordersHandler } = await import('../api/orders.js');

function response(data, status = 200) {
  return new Response(data == null ? '' : JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

test('calculates a configured route, ignores forged rewards and returns the saved discount', async (t) => {
  const calls = [];
  const originalFetch = globalThis.fetch;

  globalThis.fetch = async (input, options = {}) => {
    const url = new URL(String(input));
    calls.push({ path: url.pathname, search: url.search, method: options.method || 'GET' });

    if (url.pathname === '/rest/v1/rpc/ex_ip_check') return response([{ banned: false }]);
    if (url.pathname === '/auth/v1/user') {
      return response({ id: 'user-1', email: 'user@example.com', user_metadata: { full_name: 'Test User' } });
    }
    if (url.pathname === '/rest/v1/rpc/ex_record_event') return response(null);
    if (url.pathname === '/rest/v1/ex_rates') {
      assert.equal(url.searchParams.get('from_method'), 'eq.NassWallet');
      assert.equal(url.searchParams.get('to_method'), 'eq.QiCard');
      return response([{ rate_type: 'fee_percent', rate_value: '1.5' }]);
    }
    if (url.pathname === '/rest/v1/ex_wallets') {
      return response([
        { key: 'NassWallet', is_locked: false, allow_from: true, allow_receive: true },
        { key: 'QiCard', is_locked: false, allow_from: true, allow_receive: true }
      ]);
    }
    if (url.pathname === '/rest/v1/ex_profiles') {
      return response([{ id: 'user-1', full_name: 'Test User', email: 'user@example.com', is_banned: false }]);
    }
    if (url.pathname === '/rest/v1/rpc/security_record_order_attempt') {
      return response({ banned: false, alert_created: false, frequency_count: 1, log_id: null });
    }
    if (url.pathname === '/rest/v1/ex_orders' && (options.method || 'GET') === 'GET') return response([]);
    if (url.pathname === '/rest/v1/ex_orders' && options.method === 'POST') {
      const payload = JSON.parse(options.body);
      assert.equal(payload.from_method, 'NassWallet');
      assert.equal(payload.to_method, 'QiCard');
      assert.equal(payload.total, 9850);
      assert.equal(payload.user_id, 'user-1');
      for (const field of ['fee', 'reward_id', 'reward_discount_iqd', 'reward_original_fee_iqd',
        'payout_iqd', 'payout_rounding_iqd', 'payout_settlement_id', 'payout_plan']) {
        assert.equal(Object.hasOwn(payload, field), false, 'Customer supplied ' + field);
      }
      // Simulate the database applying a legitimate fee reward after INSERT.
      // The API must return this persisted result instead of its base estimate.
      return response([{ id: 'order-1', ...payload, total: 10000, fee: 0,
        reward_id: 'saved-reward', reward_discount_iqd: 150 }], 201);
    }

    throw new Error(`Unexpected request: ${options.method || 'GET'} ${url.pathname}${url.search}`);
  };
  t.after(() => { globalThis.fetch = originalFetch; });

  const req = {
    method: 'POST',
    url: '/api/orders',
    headers: {
      authorization: 'Bearer test-user-token',
      'user-agent': 'Mozilla/5.0 Test Browser'
    },
    socket: { remoteAddress: '127.0.0.1' },
    body: {
      from_method: 'NassWallet',
      to_method: 'QiCard',
      amount: 10000,
      user_id: 'another-customer',
      total: 99999999,
      fee: -99999999,
      reward_id: 'forged-reward',
      reward_discount_iqd: 99999999,
      reward_original_fee_iqd: 99999999,
      phone: '07510070000',
      receipt_url: 'https://pycxuugoblkslvwebxuu.supabase.co/storage/v1/object/public/receipts/test.jpg',
      receipt_hash: 'a'.repeat(64)
    }
  };
  let body = '';
  const res = {
    statusCode: 0,
    setHeader() {},
    end(chunk = '') { body = String(chunk); }
  };

  await ordersHandler(req, res);

  assert.equal(res.statusCode, 201);
  assert.equal(JSON.parse(body).ok, true);
  assert.equal(JSON.parse(body).order.total, 10000);
  assert.equal(JSON.parse(body).order.fee, 0);
  assert.equal(JSON.parse(body).order.reward_id, 'saved-reward');
  assert.deepEqual(JSON.parse(body).order.payout_plan, {
    applies:true,valid:true,expected_iqd:10000,payout_iqd:10000,remainder_iqd:0,requires_payout:true
  });
  assert.ok(calls.some(call => call.path === '/rest/v1/ex_rates'));
});

test('lets the owner correct the recipient number on an admin-requested order', async (t) => {
  const orderId = '11111111-1111-4111-8111-111111111111';
  const originalFetch = globalThis.fetch;
  let patch = null;
  globalThis.fetch = async (input, options = {}) => {
    const url = new URL(String(input));
    if (url.pathname === '/rest/v1/rpc/ex_ip_check') return response([{ banned: false }]);
    if (url.pathname === '/auth/v1/user') return response({ id: 'user-1', email: 'user@example.com' });
    if (url.pathname === '/rest/v1/rpc/ex_record_event') return response(null);
    if (url.pathname === '/rest/v1/ex_orders' && (options.method || 'GET') === 'GET') {
      assert.equal(url.searchParams.get('id'), `eq.${orderId}`);
      assert.equal(url.searchParams.get('user_id'), 'eq.user-1');
      return response([{
        id: orderId,
        user_id: 'user-1',
        from_method: 'NassWallet',
        to_method: 'FIB',
        phone: '07510070000',
        sender_phone: null,
        receipt_url: 'https://pycxuugoblkslvwebxuu.supabase.co/storage/v1/object/public/receipts/original.jpg',
        receipt_hash: 'a'.repeat(64),
        status: 'پێویستی بە ڕاستکردنەوەیە'
      }]);
    }
    if (url.pathname === '/rest/v1/ex_orders' && options.method === 'PATCH') {
      assert.equal(url.searchParams.get('user_id'), 'eq.user-1');
      assert.equal(url.searchParams.get('status'), 'eq.پێویستی بە ڕاستکردنەوەیە');
      patch = JSON.parse(options.body);
      return response([{ id: orderId, user_id: 'user-1', ...patch }]);
    }
    throw new Error(`Unexpected request: ${options.method || 'GET'} ${url.pathname}${url.search}`);
  };
  t.after(() => { globalThis.fetch = originalFetch; });

  const req = {
    method: 'PATCH',
    url: '/api/orders',
    headers: { authorization: 'Bearer test-user-token', 'user-agent': 'Mozilla/5.0 Test Browser' },
    socket: { remoteAddress: '127.0.0.1' },
    body: {
      id: orderId,
      phone: '07511112222',
      customer_response: 'I corrected the FIB recipient number.'
    }
  };
  let body = '';
  const res = { statusCode: 0, setHeader() {}, end(chunk = '') { body = String(chunk); } };
  await ordersHandler(req, res);

  assert.equal(res.statusCode, 200);
  assert.equal(JSON.parse(body).ok, true);
  assert.equal(patch.phone, '07511112222');
  assert.equal(patch.status, 'ڕاستکراوەتەوە');
  assert.equal(patch.receipt_hash, 'a'.repeat(64));
  assert.equal(patch.correction_response, 'I corrected the FIB recipient number.');
});

test('does not let a customer edit an order that is not awaiting correction', async (t) => {
  const orderId = '22222222-2222-4222-8222-222222222222';
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input) => {
    const url = new URL(String(input));
    if (url.pathname === '/rest/v1/rpc/ex_ip_check') return response([{ banned: false }]);
    if (url.pathname === '/auth/v1/user') return response({ id: 'user-1', email: 'user@example.com' });
    if (url.pathname === '/rest/v1/rpc/ex_record_event') return response(null);
    if (url.pathname === '/rest/v1/ex_orders') {
      return response([{ id: orderId, user_id: 'user-1', status: 'پەسەندکرا' }]);
    }
    throw new Error(`Unexpected request: ${url.pathname}${url.search}`);
  };
  t.after(() => { globalThis.fetch = originalFetch; });

  const req = {
    method: 'PATCH',
    url: '/api/orders',
    headers: { authorization: 'Bearer test-user-token', 'user-agent': 'Mozilla/5.0 Test Browser' },
    socket: { remoteAddress: '127.0.0.1' },
    body: { id: orderId, phone: '07511112222', customer_response: 'Changed.' }
  };
  let body = '';
  const res = { statusCode: 0, setHeader() {}, end(chunk = '') { body = String(chunk); } };
  await ordersHandler(req, res);

  assert.equal(res.statusCode, 409);
  assert.equal(JSON.parse(body).error, 'This order is not waiting for a correction');
});

test('AccountBalance orders use authenticated atomic RPC, not receipt insertion or client totals',async(t)=>{
  const original=globalThis.fetch;let saved=null;
  globalThis.fetch=async(input,options={})=>{
    const url=new URL(String(input));
    if(url.pathname==='/rest/v1/rpc/ex_ip_check')return response([{banned:false}]);
    if(url.pathname==='/auth/v1/user')return response({id:'user-1',email:'fixture@example.invalid'});
    if(url.pathname==='/rest/v1/rpc/ex_record_event')return response(null);
    if(url.pathname==='/rest/v1/ex_rates')return response([{rate_type:'fee_percent',rate_value:2}]);
    if(url.pathname==='/rest/v1/ex_wallets')return response([
      {key:'AccountBalance',is_locked:false,allow_from:true,allow_receive:false},
      {key:'FastPay',is_locked:false,allow_from:true,allow_receive:true}]);
    if(url.pathname==='/rest/v1/ex_profiles')return response([{id:'user-1',full_name:'Fixture'}]);
    if(url.pathname==='/rest/v1/rpc/security_record_order_attempt')return response({banned:false});
    if(url.pathname==='/rest/v1/rpc/ex_balance_create_order'){
      saved=JSON.parse(options.body);
      return response({id:'fixture-order',from_method:'AccountBalance',to_method:'FastPay',total:39200,fee:800,balance_debit_journal_id:'fixture-journal'});
    }
    throw Error('Unexpected '+url.pathname);
  };
  t.after(()=>{globalThis.fetch=original;});
  const req={method:'POST',url:'/api/orders',headers:{authorization:'Bearer fixture-token'},socket:{remoteAddress:'127.0.0.1'},
    body:{from_method:'AccountBalance',to_method:'FastPay',amount:40000,phone:'07700000001',
      request_key:'33333333-3333-4333-8333-333333333333',user_id:'forged-owner',total:40000,reward_id:'forged'}};
  let body;const res={statusCode:0,setHeader(){},end(v){body=JSON.parse(v);}};
  await ordersHandler(req,res);
  assert.equal(res.statusCode,201);assert.equal(body.order.fee,800);
  assert.equal(body.order.payout_plan.payout_iqd,39000);
  assert.equal(body.order.payout_plan.remainder_iqd,200);
  assert.equal(saved.p_user_id,'user-1');assert.equal(saved.p_amount,40000);
  assert.equal(saved.p_to,'FastPay');assert.equal(saved.p_phone,'07700000001');
  assert.equal(Object.hasOwn(saved,'total'),false);assert.equal(Object.hasOwn(saved,'reward_id'),false);
});

test('AccountBalance requires idempotency and whole IQD before accessing its debit RPC',async(t)=>{
  const original=globalThis.fetch;
  globalThis.fetch=async(input)=>{
    const url=new URL(String(input));
    if(url.pathname==='/rest/v1/rpc/ex_ip_check')return response([{banned:false}]);
    if(url.pathname==='/auth/v1/user')return response({id:'user-1'});
    if(url.pathname==='/rest/v1/rpc/ex_record_event')return response(null);
    throw Error('Invalid request reached database mutation: '+url.pathname);
  };t.after(()=>{globalThis.fetch=original;});
  for(const change of [{request_key:null},{amount:10000.5},{to_method:'USDT'}]){
    const req={method:'POST',url:'/api/orders',headers:{authorization:'Bearer fixture-token'},socket:{remoteAddress:'127.0.0.1'},
      body:{from_method:'AccountBalance',to_method:'FastPay',amount:10000,phone:'07700000001',
        request_key:'44444444-4444-4444-8444-444444444444',...change}};
    const res={statusCode:0,setHeader(){},end(){}};await ordersHandler(req,res);assert.equal(res.statusCode,422);
  }
});

test('all IQD funding sources reject fractional principal before creating or debiting an order',async(t)=>{
  const original = globalThis.fetch;
  const businessCalls = [];
  globalThis.fetch = async input => {
    const url = new URL(String(input));
    if (url.pathname === '/rest/v1/rpc/ex_ip_check') return response([{banned:false}]);
    if (url.pathname === '/auth/v1/user') return response({id:'user-1'});
    if (url.pathname === '/rest/v1/rpc/ex_record_event') return response(null);
    businessCalls.push(url.pathname);
    throw Error('Fractional IQD reached business database: ' + url.pathname);
  };
  t.after(()=>{globalThis.fetch = original;});
  for (const [from_method,to_method] of [['FastPay','FIB'],['AccountBalance','FIB'],['FastPay','USDT']]) {
    const req = {method:'POST',url:'/api/orders',headers:{authorization:'Bearer fixture-token'},
      socket:{remoteAddress:'127.0.0.1'},body:{from_method,to_method,amount:10000.5,phone:'07700000001',
        request_key:'44444444-4444-4444-8444-444444444444'}};
    let body;
    const res = {statusCode:0,setHeader(){},end(value){body = JSON.parse(value);}};
    await ordersHandler(req,res);
    assert.equal(res.statusCode,422);
    assert.equal(body.error,'IQD amounts must be whole dinars');
  }
  assert.equal(businessCalls.length,0);
});

test('fractional USDT principal stays exact and an IQD creation preview never credits the account',async(t)=>{
  const original = globalThis.fetch;
  let inserted;
  const rpcCalls = [];
  globalThis.fetch = async (input,options={}) => {
    const url = new URL(String(input));
    if (url.pathname.startsWith('/rest/v1/rpc/')) rpcCalls.push(url.pathname);
    if (url.pathname === '/rest/v1/rpc/ex_ip_check') return response([{banned:false}]);
    if (url.pathname === '/auth/v1/user') return response({id:'user-1'});
    if (url.pathname === '/rest/v1/rpc/ex_record_event') return response(null);
    if (url.pathname === '/rest/v1/ex_rates') return response([{rate_type:'multiplier',rate_value:1}]);
    if (url.pathname === '/rest/v1/ex_wallets') return response([
      {key:'USDT',is_locked:false,allow_from:true},{key:'FIB',is_locked:false,allow_receive:true}]);
    if (url.pathname === '/rest/v1/ex_profiles') return response([{id:'user-1',is_banned:false}]);
    if (url.pathname === '/rest/v1/rpc/security_record_order_attempt') return response({banned:false});
    if (url.pathname === '/rest/v1/ex_orders' && options.method !== 'POST') return response([]);
    if (url.pathname === '/rest/v1/ex_orders' && options.method === 'POST') {
      inserted = JSON.parse(options.body);
      return response([{id:'fixture-order',status:'چاوەڕوانە',...inserted}]);
    }
    throw Error('Unexpected USDT order request: ' + url.pathname);
  };
  t.after(()=>{globalThis.fetch = original;});
  const req = {method:'POST',url:'/api/orders',headers:{authorization:'Bearer fixture-token'},
    socket:{remoteAddress:'127.0.0.1'},body:{from_method:'USDT',to_method:'FIB',amount:10000.5,phone:'07700000001',
      receipt_url:'https://pycxuugoblkslvwebxuu.supabase.co/storage/v1/object/public/receipts/fixture.jpg',
      receipt_hash:'c'.repeat(64),payout_iqd:1000,payout_rounding_iqd:9000,payout_settlement_id:'forged',
      payout_plan:{payout_iqd:1000,remainder_iqd:9000}}};
  let body;
  const res = {statusCode:0,setHeader(){},end(value){body = JSON.parse(value);}};
  await ordersHandler(req,res);
  assert.equal(res.statusCode,201);
  assert.equal(inserted.amount,10000.5);
  assert.equal(inserted.total,10000);
  assert.equal(body.order.payout_plan.expected_iqd,10000);
  assert.equal(body.order.payout_plan.payout_iqd,10000);
  assert.equal(body.order.status,'چاوەڕوانە');
  for (const field of ['payout_iqd','payout_rounding_iqd','payout_settlement_id','payout_plan']) {
    assert.equal(Object.hasOwn(inserted,field),false);
  }
  assert.equal(rpcCalls.some(path=>/settlement|shortfall|balance_post/.test(path)),false);
});
