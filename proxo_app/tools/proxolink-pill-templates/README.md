# ProxoLink Pill template kit

Four reusable, responsive HTML templates for Proxo: `pill.html`, `pill-mint.html`, `pill-dark.html`, and `pill-white.html`. All four use the same typography, geometry, provider colors and configuration API. The HTML files include their font, SVG icons and unmodified store badges; opening them requires no font/CDN connection. A configured remote profile image still requires a network connection.

## Use the editor

Open `proxo-template-editor.html` in a browser. Choose a theme, enter profile details, select providers, enter real links, reorder buttons, then download configured HTML or JSON. Importing exported JSON restores a configuration. The live preview is deliberately inert. Exported HTML uses `preview: false` and enables valid links.

The unconfigured four HTML files are previews with all 11 requested providers. They contain no real customer phone numbers or Proxo app download URLs. Do not publish these previews as customer pages. `proxo-config.example.json` contains explicit placeholders that must be replaced before use.

## Which buttons belong on the page?

Delivery buttons open the merchant's actual listing/order link on talabat, Lezzoo, Toters or WADE. App Store and Google Play badges download the merchant's own app. They serve different goals and may coexist in separate sections. Store badges should not imply that a merchant owns a delivery platform's app. If downloading WADE itself is intended, label that section clearly in the surrounding product flow.

Contact, order and download are separate sections; empty sections disappear. Prefer the few providers the merchant actually uses. Korek and Asiacell here are phone-call buttons using the customer's phone number, not balance transfer or recharge actions. WADE is the service at `wadedelivery.com`.

## Shared dimensions

| Element | Default rendered size |
|---|---|
| Page content | Fluid width; maximum 430 CSS px |
| Outside gutter | 16–26 px, responsive |
| Card padding | 16–22 px, responsive |
| Profile circle | 88 × 88 px; image fills interior with `object-fit: cover` |
| Name / bio | 20 / 14 px at default text size |
| Provider button | Minimum 56 px high; full available width |
| Provider label / icon | 16 px / 22 × 22 px |
| Label alignment | True center with symmetric icon/spacer slots |
| Within-section button gap | 12 px |
| Between sections | 22 px on either side of a divider |
| Store click target | 64 px high |
| Visible App Store / Google Play badge | 40 px high each |
| Store clearspace | At least 10 px; official badges unchanged |
| Editor controls / reorder controls | Minimum 48 px high |

The layout handles safe-area insets, portrait/landscape, RTL/LTR, long labels, reduced motion and 200% text sizing. Buttons grow for wrapped text; their minimum height is not a fixed cap. Mobile browser measurements passed at 320–430 px and larger/tablet/landscape widths. Actual iOS/Android WebView, device text scaling and installed-app handoffs remain separate integration checks.

## Button palette and contrast

These are Proxo UI colors, with provenance per provider in `button-catalog.json`. A color observed in site CSS or sampled from a logo is not a certified brand palette. Contrasts below are measured from the rendered default button colors, using the WCAG relative-luminance formula. All normal provider labels exceed 4.5:1.

| Provider | Background | Text/icon | Contrast | Basis |
|---|---|---|---|---|
| WhatsApp | `#25D366` | `#10231A` | 8.29:1 | Proxo green in the brand color family |
| Telegram | `#0073B5` | `#FFFFFF` | 5.10:1 | Adapted accessible blue |
| Viber | `#6F5BED` | `#FFFFFF` | 4.78:1 | Adapted from published `#7360F2` |
| Korek | `#0060AB` | `#FFFFFF` | 6.44:1 | Official SVG color |
| Asiacell | `#C61932` | `#FFFFFF` | 5.86:1 | Adapted accessible red |
| talabat | `#FF5A00` | `#241509` | 5.66:1 | Proxo orange in the brand color family |
| Lezzoo | `#E63946` | `#111111` | 4.53:1 | Official site CSS color |
| Toters | `#10B899` | `#102A24` | 6.05:1 | Sampled from official logo |
| WADE | `#00C6E8` | `#10252C` | 7.74:1 | Adapted from app-icon cyan |
| App Store | Official black badge | Original artwork | — | Unmodified Apple asset |
| Google Play | Official black badge | Original artwork | — | Unmodified Google asset |

Viber's published purple with white text measures about 4.48:1, so the button background is slightly darker. The store badges retain their original proportions and artwork; Apple appears first. The Google PNG's transparent margins are preserved: its entire image is 59.52381 px high, with a 40 px visible badge. Do not stretch it or treat the transparent source height as the visible badge height.

## Configuration API

Each template has a JSON `<script id="proxo-config" type="application/json">` block. The editor safely replaces that block. In a host WebView or browser, update it after loading:

```js
window.ProxoLink.setConfig({
  template: 'pill-white',
  preview: false,
  name: 'Your business',
  bio: 'Contact and order',
  direction: 'rtl',
  lang: 'ku',
  avatarUrl: '',
  buttons: [
    { type: 'telegram', enabled: true, url: 'https://t.me/YOUR_USERNAME' }
  ]
});
```

Supported IDs: `whatsapp`, `telegram`, `viber`, `korek`, `asiacell`, `talabat`, `lezzoo`, `toters`, `wade`, `app_store`, `google_play`. Optional `instagram` is preserved in the runtime catalog for compatibility but is not one of the editor's 11 requested choices.

Use `ProxoLink.getConfig()` to read the current configuration and `ProxoLink.validateUrl(type, value)` to obtain the normalized valid URL or `null`. Enabled entries render in their configured order within each section; stores always place App Store before Google Play. Missing/invalid/disabled buttons are hidden when `preview` is false. Text is inserted using `textContent`, not customer-controlled HTML. HTTPS links have provider host allowlists, no embedded credentials and no nonstandard ports. App Store links require an app ID path; Google Play links require `/store/apps/details?id=...`. Phone buttons accept valid phone numbers or `tel:` values; Iraqi local `07...` numbers normalize to `+9647...`. Viber supports `viber://chat?number=%2B...`. Unknown provider schemes are rejected.

`fallbackUrl` is optional and validated against the same provider. It is passed to the host bridge for handling if an app cannot open. Delivery universal links and installed-app behavior depend on the platform and actual supplied merchant link; this kit does not guarantee an OS handoff.

WhatsApp entries can set `intents: true` and use a top-level `intents` array of `{emoji, label, message}` objects. The accessible dialog sends a URL-encoded message only after selection, supports Escape/Cancel and restores focus. Other providers open directly. Optional `videoUrl` can prefix WhatsApp messages with a validated TikTok URL. Optional `tiktokUrl` adds a separate video link.

## Proxo integration boundary

This directory is a development kit under `proxo_app/tools/`, not a Flutter asset or an enabled production renderer. It changes no app template registry, `pubspec.yaml`, renderer route, analytics pixel, database record or deployed customer page. Existing PR #7 and its native migration evidence remain separate.

For a future native integration, register the JavaScript channel `ProxoLinkNavigation` and have its `postMessage` receive a JSON object:

```json
{"type":"openExternal","provider":"telegram","url":"https://t.me/YOUR_USERNAME","fallbackUrl":null}
```

Revalidate URLs and schemes in the native handler before launching them. Intercept navigation at the WebView level as well, including footer links. Register the bridge before enabling live links; bridge registration/lifecycle varies by native WebView package. The `proxo:navigate` event is cancellable for host adapters and browser tests. `window.__PROXO_INTERCEPT_NAVIGATION__ = true` routes direct provider links through that event; without a bridge/cancelled event, browser navigation proceeds normally.

Keep the source-template delivery strategy consistent with the private renderer migration; do not add these HTML sources to publicly served assets or bundle them into Flutter simply to activate this kit. The repository's current web build copies root `index.html` and root `assets/` into `public/`, not this tools directory.

## Verification

`verification-summary.json` records 40 actual Chromium-rendered viewport/theme combinations and functional checks. It is browser evidence, not a claim of native Android/iOS testing.

To reproduce from this kit directory with Node and Playwright installed:

```sh
npx playwright install chromium
node tests/verify-templates.cjs
```

For an existing Chrome binary, set `CHROMIUM_EXECUTABLE_PATH` to its absolute executable path. `PROXO_KIT_ROOT` optionally sets the kit directory. Fresh screenshots and full measurement results are written to `verification/`.

## Sources and asset credits

Research checked 2026-10-06. Per-provider source links and color qualifications are also included in the catalog.

- [WCAG text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html) and [44 px enhanced targets](https://www.w3.org/WAI/WCAG22/Understanding/target-size-enhanced.html).
- [WhatsApp brand resources](https://www.meta.com/brand/resources/whatsapp/whatsapp-brand/), [Telegram logo resources](https://telegram.org/tour/screenshots), [Viber brand center](https://www.viber.com/en/brand-center/).
- [Korek](https://www.korektel.com/), [Asiacell](https://www.asiacell.com/personal), [talabat Iraq](https://iraq.talabat.com/), [Lezzoo](https://www.lezzoo.com/), [Toters](https://www.totersapp.com/), [WADE](https://wadedelivery.com/ckb).
- [Apple App Store badge guidelines](https://developer.apple.com/app-store/marketing/guidelines/), [Google Play brand hub](https://partnermarketinghub.withgoogle.com/brands/google-play/).
- Official badge files: [Apple SVG](https://developer.apple.com/assets/elements/badges/download-on-the-app-store.svg), [Google PNG](https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png).
- WhatsApp, Telegram and Viber glyphs: [Font Awesome Free 6.x](https://github.com/FortAwesome/Font-Awesome/tree/6.x/svgs/brands), icons under [CC BY 4.0](https://fontawesome.com/license/free). These are Font Awesome glyphs, not a claim that official brand asset artwork was validated. Other icons are simple inline UI symbols.
- Bahij regular is the font already used by the supplied templates, from the owner's [existing font source](https://github.com/Zana-Sponsor/Zana-Sponsor/blob/main/Bahij_TheSansArabic-Regular.ttf).
