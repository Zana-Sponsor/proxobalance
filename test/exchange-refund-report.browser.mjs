// Offline integration: real admin markup, Kurdish font, PDF libraries and download.
// All report rows are synthetic; no account or database requests are permitted.
import assert from 'node:assert/strict';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require(process.env.PROXO_PLAYWRIGHT_MODULE || 'playwright');
const read = path => readFileSync(new URL('../' + path, import.meta.url), 'utf8');
const libs = process.env.PROXO_REPORT_LIB_DIR;
if (!libs) throw Error('Set PROXO_REPORT_LIB_DIR to html2canvas.js, jspdf.js and Rabar_021.woff2.');
const output = process.env.PROXO_REFUND_REPORT_OUTPUT_DIR || '/tmp/proxo-refund-report-check';
mkdirSync(output, { recursive: true });
const font = readFileSync(libs + '/Rabar_021.woff2').toString('base64');
const html = read('exchange-admin.html').replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '')
  .replace(/<link\b[^>]*>/gi, tag => {
    const match = tag.match(/href="\/?(assets\/css\/[^"?]+)/);
    return match ? '<style>' + read(match[1]).replaceAll(
      'https://raw.githubusercontent.com/Zana-Sponsor/Zana-Sponsor/main/Rabar_021.woff2',
      'data:font/woff2;base64,' + font) + '</style>' : '';
  });
const browser = await chromium.launch({ headless: true,
  ...(process.env.PROXO_BROWSER_EXECUTABLE ? { executablePath: process.env.PROXO_BROWSER_EXECUTABLE } : {}),
  args: ['--no-sandbox', '--disable-dev-shm-usage'] });
try {
  for (const width of [390, 1280]) {
    const page = await browser.newPage({ viewport: { width, height: 1000 }, acceptDownloads: true });
    page.setDefaultTimeout(15000);
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.route('**/*', route => route.request().url() === 'https://proxo.test/exchange-admin.html'
      ? route.fulfill({ status: 200, contentType: 'text/html', body: html }) : route.abort());
    await page.goto('https://proxo.test/exchange-admin.html', { waitUntil: 'domcontentloaded' });
    for (const lib of ['html2canvas', 'jspdf']) await page.addScriptTag({ path: libs + '/' + lib + '.js' });
    await page.evaluate(() => {
      document.getElementById('authWrap').style.display = 'none';
      document.getElementById('main').classList.add('show');
      document.querySelectorAll('.pg').forEach(el => el.classList.remove('on'));
      document.getElementById('pgBalance').classList.add('on');
      window.adminUser = { id: 'admin-fixture' };
      window.pageConfig = { balance: {} };
      window.esc = value => String(value ?? '').replace(/[&<>"']/g, c =>
        ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
      window.fixture = { allowed: true, calls: [], captures: [], toasts: [] };
      window.staffCan = permission => permission === 'refunds' && fixture.allowed;
      window.showToast = message => fixture.toasts.push(message);
      const id = number => '00000000-0000-4000-8000-' + String(number).padStart(12, '0');
      const profiles = { 'user-fixture': { full_name: 'کڕیاری تاقیکردنەوە' },
        'admin-fixture': { full_name: 'ئادمینی تاقیکردنەوە' } };
      const orders = {};
      for (const number of [1, 2, 3, 4, 5]) orders[id(number)] = { id: id(number),
        order_code: 'P' + String(number).padStart(11, '0'), user_id: 'user-fixture',
        from_method: 'FastPay', to_method: 'FIB', amount: 10000, total: 9800 };
      const partial = (number, patch = {}) => ({ id: id(100 + number), order_id: id(number),
        order_code: orders[id(number)].order_code, user_id: 'user-fixture', admin_id: 'admin-fixture',
        amount_iqd: 150, expected_iqd: 9800, refunded_before_iqd: 0, refunded_after_iqd: 150,
        balance_before_iqd: 1000, balance_after_iqd: 1150, journal_id: id(200 + number),
        request_key: id(300 + number), verification_reference: 'shortfall:' + id(300 + number),
        reason: 'بڕی ١٥٠ دینار کەمتر نێردراوە و بۆ باڵانسی کڕیار گەڕێندرایەوە.',
        created_at: '2026-10-17T08:00:00.000Z', ...patch });
      const full = (number, patch = {}) => ({ id: id(400 + number), order_id: id(number),
        user_id: 'user-fixture', verified_by: 'admin-fixture', amount_iqd: 10000,
        status: 'credited', refund_kind: 'admin_rejection', confirmed_payout_failed: false,
        journal_id: id(500 + number), failure_reason: 'مامەڵەکە ڕەت کرایەوە و پارەکە بۆ باڵانس گەڕێندرایەوە.',
        created_at: '2026-10-17T09:00:00.000Z', ...patch });
      const shortfalls = [partial(1), partial(1, { id: id(110), amount_iqd: 50, refunded_before_iqd: 150,
        refunded_after_iqd: 200, balance_before_iqd: 1150, balance_after_iqd: 1200,
        journal_id: id(210), request_key: id(310), verification_reference: 'shortfall:' + id(310),
        created_at: '2026-10-17T08:30:00.000Z' }), partial(2, {
        reason: ('وردەکاریی گەڕاندنەوەی پارە بۆ کڕیار.\n').repeat(100).slice(0, 1970) + ' کۆتایی هۆکاری درێژ.'
      }), partial(3, { reason: '<img src=x onerror="window.refundXss=true"> هۆکاری تاقیکردنەوەی دەقی پارێزراو.' })];
      const refunds = [full(4), full(5, { refund_kind: 'failed_payout', confirmed_payout_failed: true })];
      const report = { refunds, shortfalls, orders, profiles };
      fixture.report = report;
      window.adminApiRequest = async (action, payload) => {
        if (action === 'balance_dashboard') return { ...structuredClone(report), balances: [], payouts: [],
          alerts: [], config: {}, reconciliation: { ok: true } };
        if (action !== 'balance_refund_report') throw Error('Unexpected action: ' + action);
        fixture.calls.push(structuredClone(payload));
        await new Promise(resolve => setTimeout(resolve, 20));
        return { refunds: payload.page ? refunds.slice(1) : refunds.slice(0, 1),
          shortfalls: payload.page ? shortfalls.slice(2) : shortfalls.slice(0, 2),
          orders, profiles, page: payload.page, next_page: payload.page ? null : 1,
          has_more: !payload.page, snapshot: '2026-10-17T12:00:00.000Z' };
      };
      const render = window.html2canvas;
      window.html2canvas = async (source, options) => {
        const container = source.querySelector('.balance-refund-pdf-records');
        const bounds = container.getBoundingClientRect();
        if (source.scrollWidth > source.clientWidth || container.scrollHeight > container.clientHeight + 1)
          throw Error('PDF content overflow');
        for (const card of container.children) {
          const box = card.getBoundingClientRect();
          if (box.left < bounds.left - 1 || box.right > bounds.right + 1 || box.bottom > bounds.bottom + 1)
            throw Error('A refund card crosses its page bounds');
        }
        fixture.captures.push({ text: source.textContent,
          ids: [...container.children].map(card => card.dataset.refundCase),
          metrics: [...container.querySelectorAll('.balance-refund-pdf-metrics')].map(el => el.textContent) });
        return render(source, options);
      };
    });
    await page.addScriptTag({ content: read('assets/js/exchange-balance-admin.js') });
    await page.addScriptTag({ content: read('assets/js/exchange-refund-report.js') });
    await page.evaluate(() => { balanceRefundReportControls(); return loadBalanceAdmin(); });
    await page.evaluate(() => document.fonts.ready);
    assert.equal(await page.evaluate(() => document.fonts.check('13px R')), true);
    assert.match(await page.locator('#balanceShortfallList').textContent(), /9,650/);
    assert.match(await page.locator('#balanceShortfallList').textContent(), /9,600/);
    assert.match(await page.locator('#balanceRefundList').textContent(), /تۆمار نەکراوە/);
    assert.match(await page.locator('#balanceRefundList').textContent(), /ئادمینی تاقیکردنەوە/);
    assert.equal(await page.locator('#balanceShortfallReference').count(), 0);
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth + 1), true);
    await page.locator('.balance-refund-report').screenshot({ path: output + '/controls-' + width + '.png' });
    if (width === 390) {
      await page.locator('#balanceRefundReportFrom').fill('2026-10-17');
      await page.locator('#balanceRefundReportTo').fill('2026-10-17');
      const pending = page.waitForEvent('download', { timeout: 60000 });
      await page.locator('#balanceRefundReportBtn').click();
      const download = await pending;
      const path = output + '/refunds-ku.pdf';
      await download.saveAs(path);
      assert.equal(await download.failure(), null);
      assert.equal(readFileSync(path).subarray(0, 5).toString(), '%PDF-');
      await page.waitForFunction(() => document.getElementById('balanceRefundReportStatus').textContent.startsWith('PDF'));
      const result = await page.evaluate(() => structuredClone(fixture));
      assert.equal(result.calls.length, 2);
      assert.equal(result.calls[1].snapshot, '2026-10-17T12:00:00.000Z');
      assert.ok(result.calls.every(call => call.date_from === '2026-10-17' && call.date_to === '2026-10-17'));
      const ids = result.captures.flatMap(capture => capture.ids);
      assert.equal(ids.length, 6);
      assert.equal(new Set(ids).size, 6);
      assert.ok(result.captures.length >= 3, 'Fixture spans real A4 pages');
      assert.match(result.captures[0].text, /20,500/);
      const allText = result.captures.map(capture => capture.text).join('\n');
      assert.match(allText, /کۆتایی هۆکاری درێژ/);
      assert.ok(allText.includes('<img src=x onerror="window.refundXss=true">'));
      assert.ok(!allText.includes('shortfall:'));
      assert.equal(await page.evaluate(() => window.refundXss), undefined);
      assert.equal(await page.locator('.balance-refund-pdf').count(), 0);
      assert.equal(await page.locator('#balanceRefundReportError').textContent(), '');
      writeFileSync(output + '/captured-pages.json', JSON.stringify(result.captures, null, 2));
      console.log('PASS: Kurdish PDF download contains all 6 full/partial cases across ' + result.captures.length + ' complete A4 pages; total 20,500 IQD.');
    }
    await page.evaluate(() => { fixture.allowed = false; balanceRefundReportControls(); });
    assert.equal(await page.locator('#balanceRefundReportBtn').isDisabled(), true);
    assert.deepEqual(errors, []);
    await page.close();
    console.log('PASS: ' + width + 'px refund table amounts, report controls, permission state and no page overflow.');
  }
} finally { await browser.close(); }
