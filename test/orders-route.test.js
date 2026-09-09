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
