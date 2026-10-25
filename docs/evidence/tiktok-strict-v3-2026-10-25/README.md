# Strict v3 — 34 required screenshot states

These are actual Flutter renders of production widgets, using deterministic test repositories. They are **controlled fixtures, not physical Android screenshots or live-provider acceptance**. Standard captures are 393 × 852 logical pixels rendered at 2×; states 33–34 are 280 × 700 with 200% text. The requested states overlap, so some full-screen captures are intentionally identical.

[28-point implementation report](../../tiktok-strict-v3/implementation-report.md) · [Exact supplied specification](../../tiktok-strict-v3/specification.md) · [SHA-256 and dimensions manifest](manifest.json)

The [capture test](../../../proxo_app/test/tiktok_strict_v3_form_test.dart) uses these scenario groups: **A** hierarchy/types/page filters/price (01–26), **B** real creator route with fixture persistence (27–30), **C** definitive failure/reopen (31–32), and **D** small screen/validation (33–34). The same file also verifies out-of-order quotes and 300% text with keyboard/Sponsor reachability. The [control tests](../../../proxo_app/test/tiktok_strict_v3_controls_test.dart) check exact color roles, 180 ms transitions, geometry, and scoped open sections.

State 17 exercises `Image.network` with an HTTPS URL intercepted by a deterministic HTTP fixture containing the bundled Proxo logo. States 16/18/19/20/30 exercise the bundled fallback. These do not prove a live page image or production save. Account/video data in states11/14 is synthetic.

All 34 originals were reviewed, using six contact sheets plus full-size inspection of the main, price, avatar, Sponsor, and narrow layouts. The review found and drove fixes for split money, extreme keyboard price overflow, and scaled fallback-logo clipping. Large-text bottom navigation retains its existing horizontal scroll behavior. Final review found no unresolved captured-state overflow or mixed primary/secondary styling.

The follow-up review corrected the confirmation ad-type label in state 31. The other 33 originals reproduced byte-for-byte; the updated image changes only the label/value text within its existing row. See the [follow-up measurements](../../tiktok-strict-v3/verification.json).

## State-to-evidence map

| # | Required state | Test | Preview (click for original) |
|---|---|---|---|
| 01 | Main TikTok Create Ad | A | [<img src="01-main.png" width="195" alt="Main TikTok Create Ad">](01-main.png) |
| 02 | Four exact ad types | A | [<img src="02-four-ad-types.png" width="195" alt="Four exact ad types">](02-four-ad-types.png) |
| 03 | Contact active | A | [<img src="03-contact-active.png" width="195" alt="Contact active">](03-contact-active.png) |
| 04 | Views active | A | [<img src="04-views-active.png" width="195" alt="Views active">](04-views-active.png) |
| 05 | Restaurant active | A | [<img src="05-restaurant-active.png" width="195" alt="Restaurant active">](05-restaurant-active.png) |
| 06 | App download active | A | [<img src="06-app-download-active.png" width="195" alt="App download active">](06-app-download-active.png) |
| 07 | Primary inactive state | A | [<img src="07-primary-inactive.png" width="195" alt="Primary inactive state">](07-primary-inactive.png) |
| 08 | Age active state | A | [<img src="08-age-active.png" width="195" alt="Age active state">](08-age-active.png) |
| 09 | Gender active state | A | [<img src="09-gender-active.png" width="195" alt="Gender active state">](09-gender-active.png) |
| 10 | Two contact destinations | A | [<img src="10-contact-destinations.png" width="195" alt="Two contact destinations">](10-contact-destinations.png) |
| 11 | All platforms inactive | A | [<img src="11-all-platforms-inactive.png" width="195" alt="All platforms inactive">](11-all-platforms-inactive.png) |
| 12 | All platforms active with supported icons | A | [<img src="12-all-platforms-active.png" width="195" alt="All platforms active with supported icons">](12-all-platforms-active.png) |
| 13 | TikTok messages inactive | A | [<img src="13-tiktok-message-inactive.png" width="195" alt="TikTok messages inactive">](13-tiktok-message-inactive.png) |
| 14 | TikTok messages active | A | [<img src="14-tiktok-message-active.png" width="195" alt="TikTok messages active">](14-tiktok-message-active.png) |
| 15 | Page disclosure collapsed | A | [<img src="15-page-collapsed.png" width="195" alt="Page disclosure collapsed">](15-page-collapsed.png) |
| 16 | Page disclosure expanded with fallback | A | [<img src="16-page-expanded.png" width="195" alt="Page disclosure expanded with fallback">](16-page-expanded.png) |
| 17 | Loaded image, stored name and status | A | [<img src="17-page-image-name-status.png" width="195" alt="Loaded image, stored name and status">](17-page-image-name-status.png) |
| 18 | Contact-only resources | A | [<img src="18-contact-only-pages.png" width="195" alt="Contact-only resources">](18-contact-only-pages.png) |
| 19 | Restaurant-only resources | A | [<img src="19-restaurant-only-pages.png" width="195" alt="Restaurant-only resources">](19-restaurant-only-pages.png) |
| 20 | App-download-only resources | A | [<img src="20-app-download-only-pages.png" width="195" alt="App-download-only resources">](20-app-download-only-pages.png) |
| 21 | Views content without page picker | A | [<img src="21-views-content.png" width="195" alt="Views content without page picker">](21-views-content.png) |
| 22 | Collapsed final price | A | [<img src="22-total-collapsed.png" width="195" alt="Collapsed final price">](22-total-collapsed.png) |
| 23 | Expanded final price | A | [<img src="23-total-expanded.png" width="195" alt="Expanded final price">](23-total-expanded.png) |
| 24 | Authoritative quote loading | A | [<img src="24-total-loading.png" width="195" alt="Authoritative quote loading">](24-total-loading.png) |
| 25 | Scrolled content beneath fixed total | A | [<img src="25-scrolled-sticky-total.png" width="195" alt="Scrolled content beneath fixed total">](25-scrolled-sticky-total.png) |
| 26 | Separate Sponsor button | A | [<img src="26-separate-sponsor.png" width="195" alt="Separate Sponsor button">](26-separate-sponsor.png) |
| 27 | No-page state | B | [<img src="27-no-page.png" width="195" alt="No-page state">](27-no-page.png) |
| 28 | Direct Create Page route | B | [<img src="28-direct-create-page.png" width="195" alt="Direct Create Page route">](28-direct-create-page.png) |
| 29 | Back returns with edited title | B | [<img src="29-back-to-preserved-ad.png" width="195" alt="Back returns with edited title">](29-back-to-preserved-ad.png) |
| 30 | New saved fixture page selected | B | [<img src="30-new-page-visible.png" width="195" alt="New saved fixture page selected">](30-new-page-visible.png) |
| 31 | Definitive submission failure | C | [<img src="31-definitive-failure.png" width="195" alt="Definitive submission failure">](31-definitive-failure.png) |
| 32 | Fresh form after leaving failure | C | [<img src="32-fresh-after-failure.png" width="195" alt="Fresh form after leaving failure">](32-fresh-after-failure.png) |
| 33 | 280px screen with 200% text | D | [<img src="33-small-screen-280-2x.png" width="195" alt="280px screen with 200% text">](33-small-screen-280-2x.png) |
| 34 | Validation error | D | [<img src="34-validation-error.png" width="195" alt="Validation error">](34-validation-error.png) |

## Review contact sheets

These are labeled composites for inspection; the lossless originals above are the screenshot evidence.

[Sheet01](review-sheet-01.jpg) · [Sheet02](review-sheet-02.jpg) · [Sheet03](review-sheet-03.jpg) · [Sheet04](review-sheet-04.jpg) · [Sheet05](review-sheet-05.jpg) · [Sheet06](review-sheet-06.jpg)
