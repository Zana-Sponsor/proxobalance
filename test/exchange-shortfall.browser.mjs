// Offline regression with the deployed admin/customer HTML, styles and modules.
// No accounts, credits, messages or database records are created by this test.
// Run with PROXO_PLAYWRIGHT_MODULE and optional PROXO_BROWSER_EXECUTABLE.
import assert from 'node:assert/strict';
import { readFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PROXO_PLAYWRIGHT_MODULE || 'playwright');
const root = new URL('../', import.meta.url);
const read = path => readFileSync(new URL(path, root), 'utf8');
const screenshots = process.env.PROXO_SHORTFALL_SCREENSHOTS;
if (screenshots) mkdirSync(screenshots, { recursive: true });

function offlineHtml(path) {
  return read(path).replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<link\b[^>]*>/gi, tag => {
      const ref = tag.match(/href="\/?(assets\/css\/[^"?]+)(?:\?[^" ]*)?"/);
      return ref ? '<style>' + read(ref[1]) + '</style>' : '';
    });
}

async function pageFor(browser, path, width) {
  const page = await browser.newPage({ viewport: { width, height: 1000 } });
  page.setDefaultTimeout(10000);
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.route('**/*', route => route.request().url() === 'https://proxo.test/' + path
    ? route.fulfill({ status: 200, contentType: 'text/html', body: offlineHtml(path) })
    : route.abort());
  await page.goto('https://proxo.test/' + path, { waitUntil: 'domcontentloaded' });
  return { page, errors };
}

const browser = await chromium.launch({ headless: true,
  ...(process.env.PROXO_BROWSER_EXECUTABLE ? { executablePath: process.env.PROXO_BROWSER_EXECUTABLE } : {}),
  args: ['--no-sandbox', '--disable-dev-shm-usage'] });
async function installAdminFixture(page, restored = null) {
    await page.evaluate(restored => {
      document.getElementById('authWrap').style.display = 'none';
      document.getElementById('main').classList.add('show');
      document.querySelectorAll('.pg').forEach(el => el.classList.remove('on'));
      document.getElementById('pgBalance').classList.add('on');
      document.getElementById('pageTitle').textContent = 'ڕیفاوند و باڵانس';
      document.getElementById('pageSubtitle').textContent = 'گەڕاندنەوەی بڕی کەم نێردراو';
      window.esc = value => String(value ?? '').replace(/[&<>"']/g, c =>
        ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
      window.fixture = restored || { allowed: true, confirm: true, failAfterCommit: false, failBeforeCommit: false, calls: [], records: [],
        available: 1000, refunded: 0, confirmations: [], toasts: [],
        order: { id: '33333333-3333-4333-8333-333333333333', order_code: 'P123456789AB',
          user_id: '22222222-2222-4222-8222-222222222222', amount: 10000, total: 9800, fee: 200,
          status: 'پەسەندکرا', from_method: 'FastPay', to_method: 'FIB', receipt_url: 'https://proxo.test/proof.jpg' } };
      window.staffCan = () => fixture.allowed;
      window.showToast = message => fixture.toasts.push(message);
      window.confirm = message => { fixture.confirmations.push(message); return fixture.confirm; };
      const admin = '11111111-1111-4111-8111-111111111111';
      window.adminUser = { id: admin };
      const profiles = { [fixture.order.user_id]: { full_name: 'کڕیاری تاقیکردنەوە' },
        [admin]: { full_name: 'ئادمینی تاقیکردنەوە' } };
      window.adminApiRequest = async (action, payload) => {
        const f = fixture;
        if (action === 'balance_lookup_order') return structuredClone({ order: { ...f.order, shortfall_refunded_iqd: f.refunded },
          profile: profiles[f.order.user_id], profiles, refund: null, shortfalls: f.records,
          balance: { user_id: f.order.user_id, available_iqd: f.available, held_iqd: 0 },
          shortfall_summary: { eligible: f.refunded < f.order.total, code: null,
            expected_iqd: f.order.total, refunded_iqd: f.refunded, remaining_iqd: f.order.total - f.refunded } });
        if (action === 'balance_dashboard') return structuredClone({ balances: [{ user_id: f.order.user_id,
          available_iqd: f.available, held_iqd: 0 }], shortfalls: f.records, refunds: [], payouts: [], alerts: [],
          profiles, config: { payouts_enabled: false }, reconciliation: {} });
        if (action !== 'balance_credit_shortfall') throw new Error('Unexpected action ' + action);
        f.calls.push(structuredClone(payload));
        if (f.failBeforeCommit) { f.failBeforeCommit = false; throw new Error('Fixture network unavailable'); }
        const existing = f.records.find(row => row.request_key === payload.request_key);
        if (existing) return structuredClone(existing);
        if (payload.expected_refunded_iqd !== f.refunded)
          throw Object.assign(new Error('SHORTFALL_STATE_CHANGED'), { status: 409, code: 'shortfall_stale' });
        const row = { id: crypto.randomUUID(), order_id: f.order.id, order_code: f.order.order_code,
          user_id: f.order.user_id, admin_id: admin, amount_iqd: payload.amount_iqd,
          expected_iqd: f.order.total, refunded_before_iqd: f.refunded,
          refunded_after_iqd: f.refunded + payload.amount_iqd,
          balance_before_iqd: f.available, balance_after_iqd: f.available + payload.amount_iqd,
          journal_id: crypto.randomUUID(), request_key: payload.request_key, reason: payload.reason,
          verification_reference: 'shortfall:' + payload.request_key, created_at: '2026-10-17T17:00:00Z' };
        f.refunded = row.refunded_after_iqd; f.available = row.balance_after_iqd; f.records.push(row);
        if (f.failAfterCommit) { f.failAfterCommit = false; throw new Error('Fixture network response lost'); }
        return structuredClone(row);
      };
    }, restored);
    await page.addScriptTag({ content: read('assets/js/exchange-balance-admin.js') });
    await page.evaluate(() => loadBalanceAdmin());
}
try {
  for (const width of [390, 1280]) {
    const { page, errors } = await pageFor(browser, 'exchange-admin.html', width);
    await installAdminFixture(page);
    await page.locator('#balanceOrderSearch').fill('P123456789AB');
    await page.locator('#balanceOrderLookupBtn').click();
    await page.waitForFunction(() => !document.getElementById('balanceShortfallFields').disabled);
    assert.equal(await page.locator('#balanceShortfallReference').count(), 0, 'No manual shortfall reference field');
    assert.equal(await page.locator('#balanceBankReference').count(), 1, 'The full-refund proof field remains available');
    await page.locator('#balanceShortfallReason').fill('150 دینار کەمتر لە بڕی دیاریکراو نێردراوە.');
    await page.locator('#balanceShortfallAmount').fill('150.5');
    await page.locator('#balanceShortfallBtn').click();
    assert.equal(await page.evaluate(() => fixture.calls.length), 0, 'Fractional IQD must not reach the API');
    await page.locator('#balanceShortfallAmount').fill('١٥٠');
    await page.locator('#balanceShortfallBtn').click();
    assert.equal(await page.evaluate(() => fixture.calls.length), 0, 'The unpaid shortfall must be explicitly confirmed');
    await page.locator('#balanceShortfallConfirmed').check();
    await page.evaluate(() => { fixture.confirm = false; });
    await page.locator('#balanceShortfallBtn').click();
    assert.equal(await page.evaluate(() => fixture.calls.length), 0, 'Cancelling confirmation must not post');
    assert.match(await page.locator('#balanceShortfallPreview').textContent(), /1,150/);
    await page.evaluate(() => { fixture.confirm = true; fixture.failAfterCommit = true; });
    await page.locator('#balanceShortfallBtn').click();
    await page.waitForFunction(() => document.getElementById('balanceShortfallError').textContent.includes('Fixture network'));
    assert.equal(await page.evaluate(() => fixture.records.length), 1);
    await page.locator('#balanceShortfallBtn').click();
    await page.waitForFunction(() => document.getElementById('balanceShortfallSuccess').textContent.includes('150'));
    const credited = await page.evaluate(() => fixture);
    assert.equal(credited.calls.length, 2);
    assert.equal(credited.calls[0].amount_iqd, 150);
    assert.equal(Object.hasOwn(credited.calls[0], 'verification_reference'), false, 'The server generates the audit reference');
    assert.equal(credited.calls[0].expected_refunded_iqd, 0);
    assert.equal(credited.calls[0].request_key, credited.calls[1].request_key, 'Network retries must preserve their key');
    assert.equal(credited.records.length, 1, 'The browser retry must produce one fixture credit');
    assert.equal(credited.available, 1150);
    assert.equal(credited.order.status, 'پەسەندکرا');
    assert.equal(credited.order.total, 9800);
    assert.equal(await page.locator('#balanceShortfallAmount').inputValue(), '');
    assert.equal(await page.locator('#balanceShortfallConfirmed').isChecked(), false);
    assert.match(await page.locator('#balanceShortfallList').textContent(), /1,150/);
    assert.match(await page.locator('#balanceShortfallList').textContent(), /ئادمینی تاقیکردنەوە/);
    assert.equal(await page.locator('#balanceCreditBtn').isDisabled(), true);
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - innerWidth);
    assert.ok(overflow <= 1, 'The page must not overflow horizontally at ' + width + ': ' + overflow);
    if (screenshots) await page.locator('#balanceShortfallPanel').screenshot({ path: screenshots + '/admin-' + width + '.png' });

    // A request that never reaches the server must retain its exact UUID and
    // original balance snapshot across a real browser reload.
    await page.locator('#balanceShortfallAmount').fill('50');
    await page.locator('#balanceShortfallReason').fill('بڕێکی کەم نێردراوی دیکە بۆ کڕیار بگەڕێتەوە.');
    await page.locator('#balanceShortfallConfirmed').check();
    await page.evaluate(() => { fixture.failBeforeCommit = true; });
    await page.locator('#balanceShortfallBtn').click();
    await page.waitForFunction(() => document.getElementById('balanceShortfallError').textContent.includes('Fixture network'));
    const pending = await page.evaluate(() => structuredClone(fixture));
    assert.equal(pending.records.length, 1);
    const pendingPayload = pending.calls.at(-1);
    await page.reload({ waitUntil: 'domcontentloaded' });
    await installAdminFixture(page, pending);
    await page.locator('#balanceOrderSearch').fill('P123456789AB');
    await page.locator('#balanceOrderLookupBtn').click();
    await page.waitForFunction(() => document.getElementById('balanceShortfallAmount').value === '50');
    assert.equal(await page.locator('#balanceShortfallConfirmed').isChecked(), false, 'Reload must require fresh confirmation');
    await page.locator('#balanceShortfallConfirmed').check();
    await page.locator('#balanceShortfallBtn').click();
    await page.waitForFunction(() => document.getElementById('balanceShortfallSuccess').textContent.includes('50'));
    const recovered = await page.evaluate(() => structuredClone(fixture));
    assert.deepEqual(recovered.calls.at(-1), pendingPayload, 'Reload must retry the frozen request');
    assert.equal(recovered.records.length, 2);
    assert.equal(recovered.available, 1200);

    // Another admin acts after lookup. This form must stop and demand a fresh
    // lookup/confirmation rather than silently rebasing its pending credit.
    await page.locator('#balanceShortfallAmount').fill('50');
    await page.locator('#balanceShortfallReason').fill('بڕێکی دیکە لە ناردنەکە کەمە و پشتڕاستکراوەتەوە.');
    await page.locator('#balanceShortfallConfirmed').check();
    await page.evaluate(() => { fixture.refunded = 350; fixture.available = 1350; });
    await page.locator('#balanceShortfallBtn').click();
    await page.waitForFunction(() => document.getElementById('balanceShortfallBtn').disabled);
    assert.match(await page.locator('#balanceShortfallError').textContent(), /دۆزینەوە/);
    assert.equal(await page.locator('#balanceShortfallConfirmed').isChecked(), false);
    assert.equal(await page.evaluate(() => fixture.records.length), 2);
    await page.locator('#balanceOrderLookupBtn').click();
    await page.waitForFunction(() => !document.getElementById('balanceShortfallFields').disabled);
    assert.match(await page.locator('#balanceShortfallPreview').textContent(), /1,350/);
    await page.evaluate(() => { fixture.allowed = false; balanceSetControls(); });
    assert.equal(await page.locator('#balanceShortfallBtn').isDisabled(), true);
    assert.deepEqual(errors, [], 'No browser runtime errors');
    await page.close();

    const customer = await pageFor(browser, 'index.html', width);
    await customer.page.evaluate(() => {
      document.getElementById('authWrap').style.display = 'none';
      document.getElementById('mainApp').style.display = 'block';
      document.getElementById('pageHome').classList.add('active');
      document.documentElement.setAttribute('data-theme', 'light');
      window.curUser = { id: 'fixture-customer' }; window._route = 'home';
      window.getOrderSession = async () => ({ access_token: 'fixture-token' });
      window.escHtml = value => String(value ?? '').replace(/[&<>"']/g, c =>
        ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
      window.fetch = async () => ({ ok: true, status: 200, json: async () => ({ ok: true,
        balance: { available_iqd: 1150, held_iqd: 0 }, payouts: [], wallets: [], payouts_enabled: false,
        shortfalls: [{ journal_id: 'fixture-journal', order_code: 'P123456789AB',
          reason: '150 دینار کەمتر نێردراوە <img src=x onerror=alert(1)>' }],
        journal: [{ id: 'fixture-journal', order_id: 'fixture-order', kind: 'shortfall_refund',
          created_at: '2026-10-17T17:00:00Z', ex_balance_entries: [
            { account: 'customer_available', delta_iqd: 150, balance_after_iqd: 1150 }] }] }) });
    });
    await customer.page.addScriptTag({ content: read('assets/js/exchange-balance.js') });
    await customer.page.evaluate(async () => { await loadMyBalance(); toggleBalanceHistory(); });
    assert.match(await customer.page.locator('#balanceHistoryList').textContent(), /P123456789AB/);
    assert.match(await customer.page.locator('#balanceHistoryList').textContent(), /1,000/);
    assert.match(await customer.page.locator('#balanceHistoryList').textContent(), /1,150/);
    assert.match(await customer.page.locator('#balanceHistoryList .pb-history-credit').textContent(), /\+150/);
    assert.equal(await customer.page.locator('#balanceHistoryList img').count(), 0, 'Notes must remain escaped text');
    if (screenshots) await customer.page.locator('#balanceSendSection').screenshot({ path: screenshots + '/customer-' + width + '.png' });
    assert.deepEqual(customer.errors, []);
    await customer.page.close();
    console.log('PASS: shortfall admin/customer UI at ' + width + 'px');
  }
} finally {
  await browser.close();
}
