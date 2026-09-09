import assert from 'node:assert/strict';
import test from 'node:test';

process.env.SUPABASE_SERVICE_ROLE_KEY = 'test-service-key';
process.env.SECURITY_FINGERPRINT_SALT = 'test-fingerprint-salt';
process.env.TRUSTED_PROXY = 'direct';

const { default: supportCasesHandler } = await import('../api/support-cases.js');

function response(data, status = 200) {
  return new Response(data == null ? '' : JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' }
  });
}

function request(body) {
  return {
    method: 'POST',
    url: '/api/support-cases',
    headers: {
      authorization: 'Bearer test-user-token',
      'user-agent': 'Mozilla/5.0 Test Browser'
    },
    socket: { remoteAddress: '127.0.0.1' },
    body
  };
}

function responseRecorder() {
  let body = '';
  return {
    res: {
      statusCode: 0,
      setHeader() {},
      end(chunk = '') { body = String(chunk); }
    },
    json() { return body ? JSON.parse(body) : {}; }
  };
}

function installBaseFetch(t, onRequest) {
  const originalFetch = globalThis.fetch;
  globalThis.fetch = async (input, options = {}) => {
    const url = new URL(String(input));
    if (url.pathname === '/rest/v1/rpc/ex_ip_check') return response([{ banned: false }]);
    if (url.pathname === '/auth/v1/user') {
      return response({ id: 'user-1', email: 'user@example.com' });
    }
    if (url.pathname === '/rest/v1/rpc/ex_record_event') return response(null);
    return onRequest(url, options);
  };
  t.after(() => { globalThis.fetch = originalFetch; });
}

test('creates a numbered support case for the authenticated customer', async (t) => {
  let inserted = null;
  installBaseFetch(t, async (url, options) => {
    if (url.pathname === '/rest/v1/ex_support_cases' && (options.method || 'GET') === 'GET') {
      return response([]);
    }
    if (url.pathname === '/rest/v1/ex_support_cases' && options.method === 'POST') {
      inserted = JSON.parse(options.body);
      assert.match(String(inserted.case_number), /^\d{6}$/);
      assert.ok(inserted.case_number >= 100000 && inserted.case_number <= 999999);
      return response([{
        id: 'case-1', status: 'open', created_at: '2026-09-09T18:00:00Z', ...inserted
      }], 201);
    }
    throw new Error(`Unexpected request: ${options.method || 'GET'} ${url.pathname}${url.search}`);
  });

  const recorder = responseRecorder();
  await supportCasesHandler(request({
    category: 'technical',
    description: 'The exchange form does not submit on my phone.',
    order_code: null,
    image_path: null
  }), recorder.res);

  assert.equal(recorder.res.statusCode, 201);
  assert.equal(inserted.user_id, 'user-1');
  assert.equal(inserted.category, 'technical');
  assert.equal(inserted.order_code, null);
  assert.equal(inserted.description, 'The exchange form does not submit on my phone.');
  assert.equal(inserted.image_path, null);
  assert.match(String(recorder.json().case.case_number), /^\d{6}$/);
});

test('verifies that an attached image exists in the customer private folder', async (t) => {
  const imagePath = 'user-1/problem-screen.webp';
  let storageChecked = false;
  installBaseFetch(t, async (url, options) => {
    if (url.pathname === '/rest/v1/ex_support_cases' && (options.method || 'GET') === 'GET') return response([]);
    if (url.pathname === '/storage/v1/object/list/support-case-images') {
      storageChecked = true;
      assert.deepEqual(JSON.parse(options.body), {
        prefix: 'user-1', search: 'problem-screen.webp', limit: 10, offset: 0
      });
      return response([{ name: 'problem-screen.webp' }]);
    }
    if (url.pathname === '/rest/v1/ex_support_cases' && options.method === 'POST') {
      const inserted = JSON.parse(options.body);
      assert.equal(inserted.image_path, imagePath);
      assert.match(String(inserted.case_number), /^\d{6}$/);
      return response([{ id: 'case-2', status: 'open', ...inserted }], 201);
    }
    throw new Error(`Unexpected request: ${options.method || 'GET'} ${url.pathname}${url.search}`);
  });

  const recorder = responseRecorder();
  await supportCasesHandler(request({
    category: 'order',
    description: 'My request shows the wrong state after sending.',
    order_code: 'P00000000001',
    image_path: imagePath
  }), recorder.res);

  assert.equal(recorder.res.statusCode, 201);
  assert.equal(storageChecked, true);
});

test('retries when a random six-digit case number collides', async (t) => {
  let insertAttempts = 0;
  installBaseFetch(t, async (url, options) => {
    if (url.pathname === '/rest/v1/ex_support_cases' && (options.method || 'GET') === 'GET') return response([]);
    if (url.pathname === '/rest/v1/ex_support_cases' && options.method === 'POST') {
      insertAttempts += 1;
      const inserted = JSON.parse(options.body);
      assert.match(String(inserted.case_number), /^\d{6}$/);
      if (insertAttempts === 1) {
        return response({ code: '23505', message: 'duplicate key value violates unique constraint' }, 409);
      }
      return response([{ id: 'case-after-retry', status: 'open', ...inserted }], 201);
    }
    throw new Error(`Unexpected request: ${options.method || 'GET'} ${url.pathname}${url.search}`);
  });

  const recorder = responseRecorder();
  await supportCasesHandler(request({
    category: 'general',
    description: 'This request verifies collision-safe case numbering.'
  }), recorder.res);

  assert.equal(recorder.res.statusCode, 201);
  assert.equal(insertAttempts, 2);
  assert.match(String(recorder.json().case.case_number), /^\d{6}$/);
});

test('rejects an image path that belongs to another customer', async (t) => {
  installBaseFetch(t, async (url, options) => {
    throw new Error(`Unexpected request: ${options.method || 'GET'} ${url.pathname}${url.search}`);
  });

  const recorder = responseRecorder();
  await supportCasesHandler(request({
    category: 'account',
    description: 'I cannot update the details in my account.',
    image_path: 'another-user/problem.jpg'
  }), recorder.res);

  assert.equal(recorder.res.statusCode, 422);
  assert.equal(recorder.json().error, 'Invalid support image path');
});
