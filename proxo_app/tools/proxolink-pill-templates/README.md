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
| Provider label / icon | 16 px / 24 × 24 px SVG slot; visible artwork approximately 21–22 px |
| Label alignment | True center with symmetric icon/spacer slots |
| Within-section button gap | 12 px |
| Between sections | 22 px on either side of a divider |
| Store click target | 64 px high |
| Visible App Store / Google Play badge | 40 px high each |
| Store clearspace | At least 10 px; official badges unchanged |
| Editor controls / reorder controls | Minimum 48 px high |

The WhatsApp button includes a small green message card reading `پەیوەندی بکە`, with a 12 px label and a speech-bubble tail. Space is reserved above that button so the card does not cover the section heading or other buttons. A soft entrance and two short floating movements finish within 3.9 seconds. The card remains visible and static when reduced motion is requested; tapping it uses the same WhatsApp action as its parent button.

The layout handles safe-area insets, portrait/landscape, RTL/LTR, long labels, reduced motion and 200% text sizing. Buttons grow for wrapped text; their minimum height is not a fixed cap. Mobile browser measurements passed at 320–430 px and larger/tablet/landscape widths. Actual iOS/Android WebView, device text scaling and installed-app handoffs remain separate integration checks.

## Button palette and contrast

All four themes use the same three-stop, 135-degree Proxo gradients in each provider's color family. These are UI colors rather than certified official brand gradients. Normal label contrast is measured across both gradient segments, including intermediate colors, and remains at least 4.5:1.

| Provider | Gradient stops | Text/icon | Minimum contrast |
|---|---|---|---|
| WhatsApp | `#46E98B` → `#25D366` → `#18B85E` | `#083B25` | 4.85:1 |
| Telegram | `#38BDF8` → `#18A5E3` → `#0797D2` | `#062538` | 4.79:1 |
| Viber | `#8351F0` → `#7547E4` → `#612ACF` | `#FFFFFF` | 4.77:1 |
| Korek | `#0E74CC` → `#075FB8` → `#0753A2` | `#FFFFFF` | 4.78:1 |
| Asiacell | `#E21B3F` → `#CA1539` → `#B01236` | `#FFFFFF` | 4.71:1 |
| talabat | `#FF9A24` → `#FF761A` → `#F85F08` | `#281508` | 5.52:1 |
| Lezzoo | `#FF617A` → `#F34B68` → `#E83C57` | `#210B16` | 4.64:1 |
| Toters | `#2AE0BC` → `#14C7A9` → `#08AE93` | `#063329` | 4.95:1 |
| WADE | `#40DDF7` → `#14C8E8` → `#06B3D6` | `#062B36` | 5.99:1 |
| App Store | `#2C3B54` → `#1E2A3D` → `#111827` | `#FFFFFF` | 11.29:1 |
| Google Play | `#2C3B54` → `#1E2A3D` → `#111827` | `#FFFFFF` | 11.29:1 |

Icons keep their original proportions inside a 24px slot. Their SVG view boxes remove inconsistent empty margins: outlined glyphs occupy approximately 22px, while Telegram's filled disc is optically adjusted to 21px. Phone and food-order glyphs no longer appear much smaller than messaging icons. Labels remain centered using equal spacer and icon slots.

App Store and Google Play use charcoal gradient click targets around their unmodified official badge artwork. The visible badges remain 40px high. Google PNG transparent margins and Apple clearspace are preserved.

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

## Proxo integration

The production renderer uses the four private documents in `api/_lib/proxolink-templates`, with version 3 catalog checksums. This toolkit contains standalone previews and an editor; it is not bundled as a public Flutter asset. The native form reads template versions from the authenticated server catalog. The host JavaScript channel `ProxoLinkNavigation` revalidates provider destinations before opening external apps.

For the staged gradient release, register `scripts/sql/proxo_gradients_v3_prepare.sql`, verify the exact preview and production renderer, then run `scripts/sql/proxo_gradients_v3_retire.sql`. Version 2 remains available while the previous production build is serving. Customer card IDs, profile/contact values, avatars and ad relationships stay unchanged. Old-version cards render with the current reviewed template and upgrade their stored version on their next successful edit.

## Verification

`verification-summary.json` records 40 actual Chromium-rendered viewport/theme combinations, rasterized icon measurements, gradient contrast and functional checks. It is browser evidence, not a claim of native Android/iOS testing.

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
