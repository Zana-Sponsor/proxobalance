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

test('accepts an active admin-configured route that is not hard-coded', async (t) => {
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
      return response([{ id: 'order-1', ...payload }], 201);
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
