# ProxoLink Pill template kit

Four reusable, responsive HTML templates for Proxo: `pill.html`, `pill-mint.html`, `pill-dark.html`, and `pill-white.html`. All four use the same typography, geometry, provider colors and configuration API. The HTML files include their font, embedded official delivery marks, messaging icons and unmodified store badges; opening them requires no font/CDN connection. A configured remote profile image still requires a network connection.

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
| Provider label | 16 px, normal weight |
| WhatsApp / Viber / phone icon | 25 / 22 / 20 px em height, matching the supplied `zoom.html` |
| Delivery logo | 24 × 24 px box; approximately 22 px longest painted side, original proportions |
| Icon / spacer slot | 44 px each at every mobile width; glyph proportions preserved |
| Label alignment | True center with symmetric icon/spacer slots |
| Within-section button gap | 12 px |
| Between sections | 22 px on either side of a divider |
| Store click target | 64 px high |
| Visible App Store / Google Play badge | 40 px high each |
| Store clearspace | At least 10 px; official badges unchanged |
| Editor controls / reorder controls | Minimum 48 px high |

The WhatsApp button includes a small green message card reading `پەیوەندی بکە`, with a 12 px label and a speech-bubble tail. It is hidden for the first two seconds after the page renders, then appears above the physical right side of the WhatsApp button in RTL and LTR. Its white label, small message symbol, rounded speech-card corners and right-side tail share the green gradient of the button. Space is reserved from the start so its reveal does not shift the layout or cover another button. A soft entrance and two short floating movements finish 3.9 seconds after the reveal. Reduced motion preserves the same two-second delay and shows a static card; tapping it uses the same WhatsApp action as its parent button. Reconfiguring the page cancels the previous timer and starts a fresh two-second delay.

The layout handles safe-area insets, portrait/landscape, RTL/LTR, long labels, reduced motion and 200% text sizing. Buttons grow for wrapped text; their minimum height is not a fixed cap. Mobile browser measurements passed at 320–430 px and larger/tablet/landscape widths. Actual iOS/Android WebView, device text scaling and installed-app handoffs remain separate integration checks.

## Button palette and contrast

All four themes use the same three-stop, 135-degree Proxo gradients in each provider's color family. These are UI colors rather than certified official brand gradients. Normal label contrast is measured across both gradient segments, including intermediate colors, and remains at least 4.5:1.

| Provider | Gradient stops | Text/icon | Minimum contrast |
|---|---|---|---|
| WhatsApp | `#0F8548` → `#087D43` → `#066D37` | `#FFFFFF` | 4.70:1 |
| Telegram | `#117BC0` → `#0870B2` → `#065B9B` | `#FFFFFF` | 4.55:1 |
| Viber | `#8351F0` → `#7547E4` → `#612ACF` | `#FFFFFF` | 4.77:1 |
| Korek | `#0E74CC` → `#075FB8` → `#0753A2` | `#FFFFFF` | 4.78:1 |
| Asiacell | `#E21B3F` → `#CA1539` → `#B01236` | `#FFFFFF` | 4.71:1 |
| talabat | `#CF4A00` → `#BE3B00` → `#AB2F00` | `#FFFFFF` | 4.53:1 |
| Lezzoo | `#E02B4D` → `#CF1F49` → `#B9163E` | `#FFFFFF` | 4.54:1 |
| Toters | `#07836E` → `#007961` → `#006951` | `#FFFFFF` | 4.69:1 |
| WADE | `#067F9D` → `#006F8E` → `#005D7C` | `#FFFFFF` | 4.64:1 |
| App Store | `#2C3B54` → `#1E2A3D` → `#111827` | `#FFFFFF` | 11.29:1 |
| Google Play | `#2C3B54` → `#1E2A3D` → `#111827` | `#FFFFFF` | 11.29:1 |

The supplied `zoom.html` uses Font Awesome Free 6.5.0 with 25px WhatsApp, 22px Viber and 20px phone-alt icons in 44px slots. The exact font glyphs are embedded in small WOFF subsets, retaining their metrics and browser hinting. At the verified browser sizes, the WhatsApp font box is 22 × 25px, Viber 22 × 22px, and phone 20 × 20px. Font painting is measured against the reference at the actual display sizes. Telegram retains its 22px em box. Delivery buttons use the identifying marks taken from each official website in a 24px square box, with approximately 22px of visible artwork. Their original aspect ratios and internal clearspace are preserved. Equal 44px spacer and icon slots keep labels truly centered even at 320px. No external font or icon CDN is needed at runtime.

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

The production renderer uses the four private documents in `api/_lib/proxolink-templates`, with version 5 catalog checksums. This toolkit contains standalone previews and an editor; it is not bundled as a public Flutter asset. The native form reads template versions from the authenticated server catalog. The host JavaScript channel `ProxoLinkNavigation` revalidates provider destinations before opening external apps.

For the staged white-label/official-logo release, register `scripts/sql/proxo_brand_v5_prepare.sql`, verify the exact preview and production renderer, then run `scripts/sql/proxo_brand_v5_retire.sql`. Version 4 remains available while the previous production build is serving. Customer card IDs, profile/contact values, avatars and ad relationships stay unchanged. Old-version cards render with the current reviewed template and upgrade their stored version on their next successful edit.

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
- WhatsApp, Telegram, Viber and phone glyphs: Font Awesome Free 6.5.0, the same version referenced by `zoom.html`; icons under [CC BY 4.0](https://fontawesome.com/license/free). The four glyphs are embedded in tiny WOFF subsets rather than downloading Font Awesome at runtime. The delivery marks come from the official website artwork below; Instagram remains a simple inline UI symbol.
- Bahij regular is the font already used by the supplied templates, from the owner's [existing font source](https://github.com/Zana-Sponsor/Zana-Sponsor/blob/main/Bahij_TheSansArabic-Regular.ttf).

## Official delivery artwork

`official-logo-sources.json` records the exact source URLs, retrieval date and original byte checksums. The untouched source files are included in `assets/official`. Talabat uses the original t path from its white header logo; Lezzoo uses the mark in its official apple-touch icon; Toters uses the fruit symbol from its header logo, preserving the slice divisions; WADE uses its original two arrow paths. Display-only SVG clipping and monochrome filters apply the requested white treatment; the identifying geometry is not redrawn or stretched. These are brand-identifying link buttons, not a claim of endorsement.

All provider labels and messaging/delivery icon pixels are white. The store badges keep their original artwork, including the official multicolor Google Play symbol. No logo CDN requests are needed when a page opens.
