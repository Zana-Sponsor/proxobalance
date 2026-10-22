// Real V6 renderer captures and footer geometry, with fictional local fixtures.
// No external navigation, customer data, database writes, or AI-generated UI.
// Run from the repository root after `npm ci` and Playwright Chromium install.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {execFileSync} from 'node:child_process';
import {createServer} from 'node:http';
import {mkdirSync, readFileSync, writeFileSync} from 'node:fs';
import path from 'node:path';
import {chromium} from 'playwright';
import {PAGE_TYPES, PREPARED_DESIGNS, AUTHORING_PROVIDERS, validatePage} from '../api/_lib/proxolink-pages.js';
import {preparedMetadata, preparedSource, renderPrepared} from '../api/_lib/proxolink-prepared.js';
import {pagePayload, OWNER} from '../test/fixtures/proxolink-v6-service.mjs';

const output = process.env.PROXO_FOOTER_OUTPUT || 'verification/proxolink-footers';
mkdirSync(path.join(output, 'screens'), {recursive: true});
const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
const sourcePaths = [
  'scripts/verify-proxolink-footers.mjs',
  'api/_lib/proxolink-pages.js',
  'api/_lib/proxolink-prepared.js',
  'test/fixtures/proxolink-v6-service.mjs',
  ...PREPARED_DESIGNS.map(key => `api/_lib/proxolink-templates/${key}.html`),
];
const source = {
  commit: execFileSync('git', ['rev-parse', 'HEAD'], {encoding: 'utf8'}).trim(),
  files: Object.fromEntries(sourcePaths.map(file => [file, sha256(readFileSync(file))])),
};
const descriptions = {
  contact: 'لەڕێگەی دووگمەکانەوە پەیوەندیمان پێوە بکەن.',
  order: 'داواکردنی خواردن',
  download: 'داگرتنی ئەپ',
};
const documents = new Map();
for (const style of PREPARED_DESIGNS) {
  const template = await preparedSource(await preparedMetadata(style));
  for (const type of PAGE_TYPES) for (const long of [false, true]) {
    const card = validatePage(pagePayload(type, AUTHORING_PROVIDERS[type], {
      name: long ? 'نمونەی پەڕە Proxo '.repeat(12).slice(0, 160) : 'Proxo',
      bio: long ? 'ئەمە زانیارییەکی درێژە بۆ پشکنینی پەڕە و فۆتەر. '.repeat(60).slice(0, 2000) : descriptions[type],
      template_key: style,
      card_language: 'ku',
    }), OWNER);
    documents.set(`/${type}/${style}/${long}`, renderPrepared(template, card, {preview: true}));
  }
}
const server = createServer((request, response) => {
  const html = documents.get(request.url);
  response.writeHead(html ? 200 : 404, {'Content-Type': 'text/html; charset=utf-8'});
  response.end(html || 'Not found');
});
await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
const base = `http://127.0.0.1:${server.address().port}`;
let browser;
const cases = [], screenshots = [];

function requireCase(condition, name, message) {
  assert.ok(condition, `${name}: ${message}`);
}

try {
  browser = await chromium.launch({
    ...(process.env.PROXO_CHROMIUM_PATH ? {executablePath: process.env.PROXO_CHROMIUM_PATH} : {}),
    args: ['--no-sandbox', '--disable-dev-shm-usage'],
  });
  for (const width of [320, 393]) for (const style of PREPARED_DESIGNS) {
    for (const type of PAGE_TYPES) for (const long of [false, true]) for (const scale of [1, 1.6]) {
      const name = `${type}/${style}/${width}/${long ? 'long' : 'normal'}/${scale}`;
      const page = await browser.newPage({viewport: {width, height: 852}, deviceScaleFactor: 2});
      const errors = [], outbound = [];
      page.on('pageerror', error => errors.push(error.message));
      await page.route('**/*', route => {
        if (route.request().url().startsWith(`${base}/`)) return route.continue();
        outbound.push(route.request().url());
        return route.abort();
      });
      await page.goto(`${base}/${type}/${style}/${long}`, {waitUntil: 'load'});
      await page.evaluate(() => document.fonts.ready);
      await page.waitForFunction(() => window.ProxoLink && [...document.images].every(image => image.complete && image.naturalWidth > 0));
      await page.evaluate(scale => {
        document.documentElement.style.fontSize = `${scale * 100}%`;
        for (const animation of document.getAnimations()) {
          if (Number.isFinite(animation.effect.getComputedTiming().endTime)) animation.finish();
          else { animation.pause(); animation.currentTime = 0; }
        }
        document.getElementById('toast').hidden = true;
        for (const hint of document.querySelectorAll('.wa-message-card')) {
          hint.hidden = true;
          new MutationObserver(() => { if (!hint.hidden) hint.hidden = true; })
            .observe(hint, {attributes: true, attributeFilter: ['hidden']});
        }
        window.scrollTo({top: document.documentElement.scrollHeight, behavior: 'instant'});
      }, scale);
      await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
      const measured = await page.evaluate(() => {
        const rect = element => {
          const r = element.getBoundingClientRect();
          return {x: r.x, y: r.y, width: r.width, height: r.height, right: r.right, bottom: r.bottom};
        };
        const footer = document.querySelector('footer.footer');
        const visible = element => {
          const style = getComputedStyle(element);
          return style.display !== 'none' && style.visibility === 'visible' && Number(style.opacity) > 0;
        };
        const parts = [...footer.querySelectorAll('small, .footer-brand, .footer-logo, .legal, .legal a')].map(element => ({
          tag: element.tagName,
          class: element.className,
          text: element.textContent.trim(),
          ...rect(element),
          visible: visible(element),
          contentFits: element.scrollWidth <= element.clientWidth + 1 && element.scrollHeight <= element.clientHeight + 1,
        }));
        const links = [...footer.querySelectorAll('a')].map(element => {
          const r = rect(element), hit = document.elementFromPoint(r.x + r.width / 2, r.y + r.height / 2);
          return {label: element.getAttribute('aria-label') || element.textContent.trim(), href: element.href,
            ...r, unobstructed: !!hit && (element === hit || element.contains(hit))};
        });
        const logo = footer.querySelector('.footer-logo');
        return {
          viewport: {width: innerWidth, height: innerHeight, dpr: devicePixelRatio},
          document: {width: document.documentElement.scrollWidth, height: document.documentElement.scrollHeight},
          scrollY,
          footer: rect(footer),
          credit: footer.querySelector('small').textContent.trim(),
          logo: {...rect(logo), loaded: logo.complete && logo.naturalWidth > 0, alt: logo.alt},
          parts,
          links,
          providerCount: document.querySelectorAll('[data-provider]').length,
          providerBottom: Math.max(...[...document.querySelectorAll('[data-provider]')].map(element => element.getBoundingClientRect().bottom)),
          preview: window.ProxoLink.getConfig().preview,
          safeAreaRulePresent: [...document.styleSheets].some(sheet => [...sheet.cssRules].some(rule =>
            rule.selectorText === '.wrap' && rule.style?.paddingBottom.includes('safe-area-inset-bottom'))),
        };
      });
      requireCase(errors.length === 0, name, `page errors: ${errors.join('; ')}`);
      requireCase(outbound.length === 0, name, 'unexpected external request');
      requireCase(measured.preview === true, name, 'fixture must be an inert preview');
      requireCase(measured.document.width <= width + 1, name, 'horizontal page overflow');
      requireCase(measured.providerCount === AUTHORING_PROVIDERS[type].length, name, 'missing provider');
      requireCase(measured.credit === 'سپۆنسەر کراوە لەئەپی', name, 'sponsor credit missing');
      requireCase(measured.logo.loaded && measured.logo.alt === 'Proxo', name, 'brand logo missing');
      requireCase(measured.logo.width === 84 && measured.logo.height === 24, name, 'logo aspect/size changed');
      requireCase(measured.safeAreaRulePresent, name, 'bottom safe-area rule missing');
      requireCase(measured.footer.y >= -1 && measured.footer.bottom <= measured.viewport.height + 1, name, 'footer cut off after scrolling to bottom');
      requireCase(measured.footer.bottom + measured.scrollY <= measured.document.height + 1, name, 'footer outside document');
      requireCase(measured.providerBottom <= measured.footer.y, name, 'provider/footer overlap');
      requireCase(measured.parts.every(part => part.visible && part.contentFits
        && part.x >= -1 && part.right <= width + 1
        && part.y >= measured.footer.y - 1 && part.bottom <= measured.footer.bottom + 1), name, 'footer part hidden, clipped, or outside footer');
      assert.deepEqual(measured.links.map(link => ({label: link.label, href: link.href})), [
        {label: 'Proxo', href: 'https://proxopages.com/'},
        {label: 'Privacy Policy', href: 'https://proxopages.com/policy'},
        {label: 'Terms & Conditions', href: 'https://proxopages.com/terms'},
      ], `${name}: footer links differ`);
      requireCase(measured.links.every(link => link.height >= 44 && link.width >= 44 && link.unobstructed), name, 'footer link target too small or obstructed');
      for (let i = 0; i < measured.links.length; i++) for (let j = i + 1; j < measured.links.length; j++) {
        const a = measured.links[i], b = measured.links[j];
        requireCase(Math.min(a.right, b.right) - Math.max(a.x, b.x) <= 1
          || Math.min(a.bottom, b.bottom) - Math.max(a.y, b.y) <= 1, name, 'footer links overlap');
      }
      if (width === 393 && !long && scale === 1) {
        for (const capture of ['footer', 'full']) {
          if (capture === 'full') await page.evaluate(() => window.scrollTo({top: 0, behavior: 'instant'}));
          const filename = `screens/${type}-${style}-${capture}.png`;
          const bytes = await page.screenshot({path: path.join(output, filename), fullPage: capture === 'full'});
          screenshots.push({file: filename, page_type: type, style, capture, sha256: sha256(bytes), bytes: bytes.length});
        }
      }
      cases.push({page_type: type, style, width, long_content: long, text_scale: scale, ...measured,
        page_errors: errors, outbound_requests: outbound.length, passed: true});
      await page.close();
    }
  }
  assert.equal(cases.length, 96);
  assert.equal(screenshots.length, 24);
  const result = {
    status: 'VERIFIED', generated_at: new Date().toISOString(), source,
    renderer: 'Unmodified production V6 preparedSource/renderPrepared HTML with validated fictional fixtures',
    images: 'Actual Chromium screenshots, not illustrations or AI-generated screens; fixture content is not a customer page',
    browser: browser.version(), page_types: PAGE_TYPES, styles: PREPARED_DESIGNS,
    case_count: cases.length, screenshot_count: screenshots.length,
    limits: [
      'Footer destination URLs are inspected, not fetched or clicked; their live availability is not asserted.',
      'The safe-area CSS rule is verified; this desktop Chromium run has no physical device inset.',
      'Text scaling changes the real document root font size to 160%; it does not emulate every operating-system accessibility mode.',
    ],
    cases, screenshots,
  };
  writeFileSync(path.join(output, 'results.json'), JSON.stringify(result, null, 2) + '\n');
  console.log(`VERIFIED: ${cases.length} actual renderer footer cases and ${screenshots.length} real screenshots; zero external requests.`);
} finally {
  if (browser) await browser.close();
  await new Promise(resolve => server.close(resolve));
}
