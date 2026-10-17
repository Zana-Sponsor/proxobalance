// Offline browser integration: actual Kurdish markup, styles and financial UI functions.
// The fixture permits no account/database calls or external transfers.
import assert from 'node:assert/strict';
import { readFileSync, mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PROXO_PLAYWRIGHT_MODULE || 'playwright');
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const output = process.env.PROXO_ROUNDING_OUTPUT_DIR || '/tmp/proxo-rounded-payout-check';
mkdirSync(output, { recursive: true });
const font = process.env.PROXO_REPORT_LIB_DIR
  ? readFileSync(process.env.PROXO_REPORT_LIB_DIR + '/Rabar_021.woff2').toString('base64') : null;
function markup(path) {
  return read(path).replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '').replace(/<link\b[^>]*>/gi, tag => {
    const match = tag.match(/href="\/?(assets\/css\/[^"?]+)/);
    if (!match) return '';
    let css = read(match[1]);
    if (font) css = css.replaceAll('https://raw.githubusercontent.com/Zana-Sponsor/Zana-Sponsor/main/Rabar_021.woff2',
      'data:font/woff2;base64,' + font);
    return '<style>' + css + '</style>';
  });
}
const adminSource = read('assets/js/admin.js');
const approval = adminSource.slice(adminSource.indexOf('let _apFile=null'), adminSource.indexOf('async function uploadPayoutReceiptDirect'));
const appSource = read('assets/js/app.js');
const quote = appSource.slice(appSource.indexOf('function calc(){'), appSource.indexOf('function closeOrderConfirm(){'));
const cards = appSource.slice(appSource.indexOf('const TX_STATE = {'), appSource.indexOf('let _txSheetId=null'));
assert.ok(approval.length > 5000 && quote.length > 5000 && cards.length > 2000);
const browser = await chromium.launch({ headless: true,
  ...(process.env.PROXO_BROWSER_EXECUTABLE ? { executablePath: process.env.PROXO_BROWSER_EXECUTABLE } : {}),
  args: ['--no-sandbox', '--disable-dev-shm-usage'] });
async function pageFor(path, width) {
  const page = await browser.newPage({ viewport: { width, height: 1000 } });
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  page.setDefaultTimeout(10000);
  const url = 'https://proxo.test/' + path, html = markup(path);
  await page.route('**/*', route => route.request().url() === url
    ? route.fulfill({ status: 200, contentType: 'text/html', body: html }) : route.abort());
  await page.goto(url, { waitUntil: 'domcontentloaded' });
  return { page, errors };
}
async function adminFixture(page, restored = null) {
  await page.evaluate(restored => {
    document.getElementById('authWrap').style.display = 'none';
    document.getElementById('main').classList.add('show');
    window.adminUser = { id: '11111111-1111-4111-8111-111111111111' };
    window.STATUS_APPROVED = 'پەسەندکرا';
    window.REVIEWABLE_ORDER_STATUSES = new Set(['چاوەڕوانە', 'ڕاستکراوەتەوە']);
    window.esc = value => String(value ?? '').replace(/[&<>"']/g, c =>
      ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
    window.formatNum = value => Number(value).toLocaleString('en-US');
    window.fmtCode = value => value;
    window.orderCodeOf = value => value.order_code;
    window.methodPill = value => '<bdi>' + esc(value) + '</bdi>';
    window.openMo = id => document.getElementById(id)?.classList.add('on');
    window.closeMo = id => document.getElementById(id)?.classList.remove('on');
    window.showToast = message => fixture.toasts.push(message);
    window.refreshOrdersEverywhere = () => { fixture.refreshes++; };
    window.fixture = restored || { calls: [], settlements: [], uploads: [], toasts: [], refreshes: 0,
      loseAfterCommit: false, failBeforeCommit: false, available: 1000,
      order: { id: '33333333-3333-4333-8333-333333333333',
        user_id: '22222222-2222-4222-8222-222222222222', order_code: 'P123456789AB',
        profile: { full_name: 'کڕیاری تاقیکردنەوە' }, status: 'چاوەڕوانە',
        from_method: 'FastPay', to_method: 'FIB', phone: '07701234567',
        amount: 15000, total: 10500, fee: 4500, shortfall_refunded_iqd: 0,
        updated_at: '2026-10-17T12:00:00.000Z', created_at: '2026-10-17T11:00:00.000Z',
        receipt_url: 'https://proxo.test/incoming.jpg', payout_receipt_url: null, admin_note: null } };
    window.allOrders = [structuredClone(fixture.order)];
    window.sb = { storage: { from(bucket) {
      if (bucket !== 'receipts') throw Error('Unexpected storage bucket');
      return { async upload(path) { fixture.uploads.push(path); return { error: null }; },
        getPublicUrl(path) { return { data: { publicUrl:
          'https://pycxuugoblkslvwebxuu.supabase.co/storage/v1/object/public/receipts/' + path } }; } };
    } } };
    window.adminApiRequest = async (action, payload) => {
      if (action !== 'approve_order') throw Error('Unexpected action: ' + action);
      fixture.calls.push(structuredClone(payload));
      await new Promise(resolve => setTimeout(resolve, 40));
      if (fixture.failBeforeCommit) { fixture.failBeforeCommit = false; throw Error('Fixture response unavailable'); }
      const existing = fixture.settlements.find(value => value.request_key === payload.request_key);
      if (existing) {
        if (JSON.stringify(existing.payload) !== JSON.stringify(payload)) throw Error('Fixture idempotency conflict');
        return structuredClone(existing.order);
      }
      if (payload.expected_updated_at !== fixture.order.updated_at || payload.expected_total !== fixture.order.total)
        throw Object.assign(Error('ORDER_SETTLEMENT_STALE'), { status: 409, code: 'approval_stale' });
      const payout = Math.floor(fixture.order.total / 1000) * 1000, remainder = fixture.order.total - payout;
      if (payload.confirmed_payout_iqd !== payout || payload.confirmed_received !== true || payload.confirmed_paid !== (payout > 0))
        throw Error('Fixture confirmation mismatch');
      const saved = { ...fixture.order, status: 'پەسەندکرا', payout_iqd: payout,
        payout_rounding_iqd: remainder, payout_settlement_id: crypto.randomUUID(),
        shortfall_refunded_iqd: remainder, payout_receipt_url: payload.payout_receipt_url,
        updated_at: '2026-10-17T12:01:00.000Z' };
      fixture.available += remainder;
      fixture.settlements.push({ request_key: payload.request_key, payload: structuredClone(payload), order: saved });
      fixture.order = saved;
      if (fixture.loseAfterCommit) { fixture.loseAfterCommit = false; throw Error('Fixture response lost after commit'); }
      return structuredClone(saved);
    };
  }, restored);
  await page.addScriptTag({ content: read('assets/js/exchange-payout-rounding.js') });
  await page.addScriptTag({ content: approval });
}
try {
  for (const width of [390, 1280]) {
    const { page, errors } = await pageFor('exchange-admin.html', width);
    await adminFixture(page);
    await page.evaluate(() => approveOrder(fixture.order.id));
    assert.match(await page.locator('#apReview').textContent(), /10,500/);
    assert.match(await page.locator('#apReview').textContent(), /10,000/);
    assert.match(await page.locator('#apReview').textContent(), /500/);
    assert.match(await page.locator('#apConfirmBtn').textContent(), /10,000/);
    await page.locator('#apReceiptFile').setInputFiles({ name: 'payout.png', mimeType: 'image/png',
      buffer: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=', 'base64') });
    await page.evaluate(() => { fixture.loseAfterCommit = true; });
    await page.locator('#apConfirmBtn').click();
    await page.waitForFunction(() => document.getElementById('apError').textContent.includes('Fixture response lost'));
    assert.equal(await page.evaluate(() => fixture.settlements.length), 1);
    assert.equal(await page.evaluate(() => fixture.available), 1500);
    assert.equal(await page.locator('#apReceiptFile').isDisabled(), true);
    const beforeReload = await page.evaluate(() => structuredClone(fixture));
    const firstPayload = beforeReload.calls[0];
    await page.reload({ waitUntil: 'domcontentloaded' });
    await adminFixture(page, beforeReload);
    await page.evaluate(() => approveOrder(fixture.order.id));
    assert.match(await page.locator('#apActionNote').textContent(), /دووبارە مەنیەرە/);
    await page.locator('#apConfirmBtn').click();
    await page.waitForFunction(() => !document.getElementById('moApproveOrder').classList.contains('on'));
    const recovered = await page.evaluate(() => structuredClone(fixture));
    assert.deepEqual(recovered.calls[1], firstPayload);
    assert.equal(recovered.uploads.length, 1);
    assert.equal(recovered.settlements.length, 1);
    assert.equal(recovered.available, 1500);
    assert.equal(await page.evaluate(() => Object.keys(sessionStorage).filter(key => key.startsWith('proxo:approval:')).length), 0);

    // A realtime refresh changes the recipient and price while the modal is open.
    // The displayed confirmation stays frozen and the stale API response stops it.
    await page.evaluate(() => {
      fixture.order = { ...fixture.order, id: crypto.randomUUID(), status: 'چاوەڕوانە',
        payout_settlement_id: null, payout_iqd: null, payout_rounding_iqd: null,
        shortfall_refunded_iqd: 0, payout_receipt_url: null, updated_at: '2026-10-17T13:00:00.000Z' };
      allOrders = [structuredClone(fixture.order)]; approveOrder(fixture.order.id);
      fixture.order.phone = '07707654321'; fixture.order.total = 11600;
      fixture.order.updated_at = '2026-10-17T13:01:00.000Z'; allOrders = [structuredClone(fixture.order)];
    });
    assert.match(await page.locator('#apReview').textContent(), /07701234567/);
    assert.doesNotMatch(await page.locator('#apReview').textContent(), /07707654321|11,600/);
    await page.locator('#apConfirmBtn').click();
    await page.waitForFunction(() => document.getElementById('apError').textContent.includes('مامەڵەکە گۆڕاوە'));
    assert.equal(await page.locator('#apConfirmBtn').isDisabled(), true);
    assert.match(await page.locator('#apError').textContent(), /مامەڵەکە گۆڕاوە/);
    assert.equal(await page.evaluate(() => fixture.calls.at(-1).confirmed_payout_iqd), 10000);
    assert.equal(await page.evaluate(() => fixture.available), 1500);
    await page.evaluate(() => { closeMo('moApproveOrder'); approveOrder(fixture.order.id); });
    assert.match(await page.locator('#apReview').textContent(), /07707654321/);
    assert.match(await page.locator('#apConfirmBtn').textContent(), /11,000/);
    await page.locator('#moApproveOrder .modal').screenshot({ path: output + '/approval-' + width + '.png' });
    await page.evaluate(() => closeMo('moApproveOrder'));

    for (const net of [1600, 600, 0, 20000]) {
      await page.evaluate(net => {
        fixture.order = { ...fixture.order, id: crypto.randomUUID(), status: 'چاوەڕوانە', total: net,
          payout_settlement_id: null, payout_iqd: null, payout_rounding_iqd: null,
          shortfall_refunded_iqd: 0, payout_receipt_url: null };
        allOrders = [structuredClone(fixture.order)]; approveOrder(fixture.order.id);
      }, net);
      assert.equal(await page.locator('#apReceiptWrap').isVisible(), net >= 1000);
      const balanceBefore = await page.evaluate(() => fixture.available);
      await page.locator('#apConfirmBtn').click();
      await page.waitForFunction(() => !document.getElementById('moApproveOrder').classList.contains('on'));
      assert.equal(await page.evaluate(() => fixture.calls.at(-1).confirmed_paid), net >= 1000);
      assert.equal(await page.evaluate(() => fixture.available), balanceBefore + net % 1000);
    }
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), true);
    assert.deepEqual(errors, []);
    await page.close();

    const customer = await pageFor('index.html', width);
    await customer.page.evaluate(() => {
      document.documentElement.setAttribute('data-theme', 'light');
      document.getElementById('authWrap').style.display = 'none';
      document.getElementById('mainApp').style.display = 'block';
      document.querySelectorAll('.page').forEach(node => node.classList.remove('active'));
      document.getElementById('pageHome').classList.add('active');
      window.escHtml = value => String(value ?? '').replace(/[&<>"']/g, c =>
        ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
      window.formatNum = value => Number(value).toLocaleString('en-US');
      window.fmtPct = value => String(value);
      window.getAmtRaw = () => document.getElementById('amt').value;
      window.refreshFormHints = window.updateSubmitState = window.updateHeaderRate = () => {};
      window.routeAllowed = () => true; window.getWalletInfo = () => ({ locked: false });
      window.availableFeeReward = () => null; window.MIN_AMOUNT = 10000;
      window.RATES = { 'FastPay>FIB': { type: 'fee_fixed', value: 4500 } };
      window.METHOD_META = { FastPay: { label: 'FastPay' }, FIB: { label: 'FIB' } };
      document.getElementById('from').innerHTML = '<option value="FastPay">FastPay</option>';
      document.getElementById('receiveVia').innerHTML = '<option value="FIB">FIB</option>';
      window.curProfile = { full_name: 'کڕیاری تاقیکردنەوە' };
      document.getElementById('userSenderName').value = curProfile.full_name;
      document.getElementById('userPhone').value = '07701234567';
      window.needsSenderPhone = window.kycExchangeBlocked = () => false;
      window.normalizePersonName = value => value.trim();
      window.loadMyRewards = async () => {}; window.clearAllOrderFieldErrors = () => {};
      window.fixture = { errors: [], toasts: [] };
      window.setFieldError = (id, message) => fixture.errors.push({ id, message });
      window.showToast = message => fixture.toasts.push(message);
      window.methodIconHTML = () => '';
      window.onFileSelected = () => {};
      window.openSheet = node => node.classList.add('open');
      window.orderCodeOf = order => order.order_code;
      window.methodLabel = value => value;
      window.kycFmtDate = () => '17/10/2026';
      window.ICON = { arrowLeftLong: '←' };
    });
    await customer.page.addScriptTag({ content: read('assets/js/exchange-reward-pricing.js') });
    await customer.page.addScriptTag({ content: read('assets/js/exchange-payout-rounding.js') });
    await customer.page.addScriptTag({ content: quote + '\n' + cards });
    await customer.page.locator('#fileInput').setInputFiles({ name: 'incoming.png', mimeType: 'image/png', buffer: Buffer.from([1, 2, 3]) });
    for (const [principal, fee, expected, payout, remainder] of [[15000, 4500, 10500, 10000, 500],
      [10000, 8400, 1600, 1000, 600], [10000, 9400, 600, 0, 600], [20000, 0, 20000, 20000, 0]]) {
      const result = await customer.page.evaluate(({ principal, fee }) => {
        document.getElementById('amt').value = String(principal); RATES['FastPay>FIB'].value = fee;
        return calc();
      }, { principal, fee });
      assert.equal(result.expected_iqd, expected); assert.equal(result.payout_iqd, payout); assert.equal(result.remainder_iqd, remainder);
      assert.equal(await customer.page.locator('#payoutDisplay').textContent(), payout.toLocaleString('en-US') + ' IQD');
      assert.equal(await customer.page.locator('#bdRoundingRow').isVisible(), remainder > 0);
      await customer.page.evaluate(() => openOrderConfirm());
      assert.match(await customer.page.locator('#confirmSummary').textContent(), /بڕی ناردن بۆ وەرگر/);
      assert.match(await customer.page.locator('#confirmSummary').textContent(), /گەڕاندنەوەی خۆکار/);
      if (payout === 0) assert.match(await customer.page.locator('#confirmSummary').textContent(), /هیچ ناردنێکی دەرەکی/);
      await customer.page.evaluate(() => document.getElementById('confirmSheet').classList.remove('open'));
    }
    await customer.page.evaluate(() => {
      document.getElementById('amt').value = '15000'; RATES['FastPay>FIB'].value = 4500; calc();
    });
    await customer.page.locator('#bdExpectedRow').locator('..').screenshot({ path: output + '/quote-' + width + '.png' });
    const history = await customer.page.evaluate(() => {
      const common = { id: 'fixture-order', order_code: 'P123456789AB', amount: 15000, total: 10500,
        status: 'پەسەندکرا', from_method: 'FastPay', to_method: 'FIB', created_at: '2026-10-17T12:00:00Z' };
      return { legacy: orderCardHTML(common), settled: orderCardHTML({ ...common,
        payout_settlement_id: crypto.randomUUID(), payout_iqd: 10000, payout_rounding_iqd: 500 }) };
    });
    assert.match(history.legacy, /10,500 IQD/); assert.doesNotMatch(history.legacy, /گەڕاوەتەوە بۆ باڵانست/);
    assert.match(history.settled, /10,000 IQD/); assert.match(history.settled, /500 IQD/);
    assert.deepEqual(await customer.page.evaluate(() => fixture.errors), []);
    assert.deepEqual(customer.errors, []);
    await customer.page.close();
    console.log('PASS: ' + width + 'px exact payout quotes, confirmation, legacy history, frozen admin approval, saved receipt/reload retry and zero external transfers.');
  }
} finally { await browser.close(); }
