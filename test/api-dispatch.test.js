import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import dispatch, { selectApiHandler } from '../api/dispatch.js';

const routes = [
  'admin', 'balance', 'error-log', 'forms', 'notify-order', 'orders',
  'proxolink', 'public', 'security-admin', 'support-cases', 'track',
  'transaction-summary'
];

for (const route of routes) {
  test(`dispatcher selects the existing ${route} handler and restores its API URL`, () => {
    const req = {
      method: 'POST',
      url: `/api/dispatch?__pb_api_route=${encodeURIComponent(route)}&keep=one&keep=two`,
      query: { __pb_api_route: route, keep: ['one', 'two'] }
    };
    const handler = selectApiHandler(req);
    assert.equal(typeof handler, 'function');
    assert.equal(req.url, `/api/${route}?keep=one&keep=two`);
    assert.deepEqual(req.query, { keep: ['one', 'two'] });
  });
}

test('proxolink rewrites retain operation and path-derived query values', () => {
  const req = {
    method: 'GET',
    url: '/api/dispatch?__pb_api_route=proxolink&op=contact&id=abc123',
    query: { __pb_api_route: 'proxolink', op: 'contact', id: 'abc123' }
  };
  assert.equal(typeof selectApiHandler(req), 'function');
  assert.equal(req.url, '/api/proxolink?op=contact&id=abc123');
  assert.deepEqual(req.query, { op: 'contact', id: 'abc123' });
});

test('unknown dispatcher selectors do not resolve to any handler', () => {
  const req = {
    method: 'GET',
    url: '/api/dispatch?__pb_api_route=constructor',
    query: { __pb_api_route: 'constructor' }
  };
  assert.equal(selectApiHandler(req), null);
});

test('Vercel maps every legacy API URL to the one dispatcher function', () => {
  const config = JSON.parse(readFileSync(new URL('../vercel.json', import.meta.url), 'utf8'));
  assert.deepEqual(Object.keys(config.functions), ['api/dispatch.js']);
  assert.equal(config.functions['api/dispatch.js'].maxDuration, 30);

  const rewrites = new Map(config.rewrites.map(rule => [rule.source, rule.destination]));
  for (const route of routes) {
    assert.equal(
      rewrites.get(`/api/${route}`),
      `/api/dispatch?__pb_api_route=${route}`,
      `missing compatible rewrite for /api/${route}`
    );
  }
  for (const [source, op] of [
    ['/contact-preview', 'template-preview'],
    ['/api/contact-templates', 'templates'],
    ['/api/contact-ad-links', 'ad-links'],
    ['/api/contact-preview-token', 'preview-token'],
    ['/api/contact-card-action', 'card-action'],
    ['/api/contact-cards', 'cards'],
    ['/contact/:id/avatar', 'avatar'],
    ['/contact/:id', 'contact'],
    ['/a/:token/avatar', 'avatar'],
    ['/a/:token/action/:action', 'ad'],
    ['/a/:token', 'ad']
  ]) {
    assert.match(rewrites.get(source) || '', new RegExp(`/api/dispatch\\?__pb_api_route=proxolink&op=${op}`));
  }
});

test('dispatcher preserves method gates without invoking endpoint business logic', async () => {
  const cases = [
    ['admin', 'GET', 405],
    ['balance', 'PUT', 405],
    ['error-log', 'GET', 405],
    ['forms', 'PUT', 405],
    ['notify-order', 'GET', 405],
    ['orders', 'GET', 405],
    ['proxolink', 'GET', 404],
    ['public', 'POST', 405],
    ['security-admin', 'PUT', 405],
    ['support-cases', 'GET', 405],
    ['track', 'DELETE', 405],
    ['transaction-summary', 'GET', 405]
  ];
  for (const [route, method, expectedStatus] of cases) {
    const headers = {};
    const res = {
      statusCode: 0,
      status(code) { this.statusCode = code; return this; },
      setHeader(name, value) { headers[name.toLowerCase()] = value; },
      end(body = '') { this.body = body; return this; },
      send(body = '') { this.body = body; return this; }
    };
    const req = {
      method,
      url: `/api/dispatch?__pb_api_route=${encodeURIComponent(route)}`,
      headers: {},
      socket: { remoteAddress: '127.0.0.1' },
      query: { __pb_api_route: route }
    };
    await dispatch(req, res);
    assert.equal(res.statusCode, expectedStatus, `${route} ${method} status`);
    assert.equal(req.url, `/api/${route}`);
    if (expectedStatus === 405 && route !== 'balance') assert.ok(headers.allow, `${route} Allow header`);
  }
});
