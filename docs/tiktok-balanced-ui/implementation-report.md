# TikTok Create Ad — balanced UI correction

> Price geometry in this revision is historical. The subsequently supplied image is implemented in the [full-width final-price follow-up](../tiktok-price-reference/implementation-report.md). Form typography, section spacing and the rest of the 69-point correction remain applicable.

This revision implements the newly supplied **69-point visual correction**, replacing the rejected strict-v3 appearance. The supplied prompt is preserved verbatim in [specification.md](specification.md) (SHA-256 `b00095a9ff00326fbe517946518f0cc191de2e86542fb487f8931c92f05e0e18`). Both new attachments contained identical text.

Source baseline: `57af051fcf85ab911d96c729be5cdbbeceaa0038`. This is a visual correction to TikTok creation. Provider, backend, quote calculation, payment submission, persistence, recovery, owner/type filtering and production flags retain their existing authority. Meta defaults and the receipt reference are regression checked.

## Requested final report

| # | Item | Result |
|---|---|---|
| 1 | Files changed | [Exact file manifest](changed-files.txt), relative to the baseline above. |
| 2 | Typography tokens | `TikTokAdTokens`, using existing `RabarAuthRegular` / Auth face. |
| 3 | Exact sizes / weights | AppBar 18/500; heading 16/500; field label 15/500; field value 15/400; choice/Sponsor 14/500; helper 13/400; status 12/400. All use 1.5 line height. Price row label 13/400, amount 14/500; total label 15/500, amount 16/600. |
| 4 | Section spacing | 20dp gutters; 16dp heading→control; 32dp section→next heading; 12dp grouped-control gap; 8dp field→helper. Actual rendered transition values are in [measurements.json](../evidence/tiktok-balanced-2026-10-25/measurements.json). |
| 5 | Input geometry | 56dp measured normal height; 16dp horizontal padding; 12dp corners; very light fill and subtle border. |
| 6 | Button geometry | 50dp normal height; 12dp corners; uniform widths per group; 21dp objective icons with 8dp text gap. Grids reduce columns at narrow widths/large text. |
| 7 | Primary states | Inactive white/gray; active solid medium blue `#2F70C7` with white text and transparent border; stable geometry and subtle shadow. |
| 8 | Secondary states | Inactive white/near-black; active pale `#EDF4FC` fill, blue text and border. |
| 9 | Contact Page | Open heading + compact accordion; typed eligible pages; 42dp avatar/fallback, name, status and selection. Existing creation/navigation behavior retained. |
| 10 | Price width | 353dp on 393dp; 280dp on 320dp; 240dp on 280dp. Exactly viewport minus two 20dp gutters. |
| 11 | Price radius | 10dp. |
| 12 | Collapsed price height | 72dp on all three normal-text phone widths. Accessibility text grows the component; see actual measurements. |
| 13 | Price→nav spacing | 2dp. Navigation is independent and fixed. |
| 14 | Expand / collapse | Same card, 200ms easeOutCubic, bottom anchored. Icon-only disclosure with 48dp target; header also responds to taps. |
| 15 | Loading | 20dp loader in reserved amount area. Expanded state/bounds preserved; hidden old amounts retain size only. Missing quotes cannot expose cached details. |
| 16 | Sponsor | Separate normal scrollable button, 32dp after payment; never a child of the price card. |
| 17 | Responsive | Normal and 200% at 393/320/280; existing extreme-width/300%/keyboard regressions also run. Large text gets extra space or stacked rows, not smaller global spacing. |
| 18 | Screenshots | [Fresh screenshot gallery](../evidence/tiktok-balanced-2026-10-25/README.md), with numbered captures, review sheets, exact dimensions and SHA-256 manifest. |
| 19 | Findings during review | Uneven age wrapping; inherited heavy coupon hint; narrow AppBar/payment labels breaking words; crowded large-text price labels; divider scrolled away; content leaking through the nav gap; stale-detail risk when the authoritative quote disappeared. |
| 20 | Fixes after review | Equal age columns; explicit helper face; word-aware title/payment layout; consistent stacked price rows with scroll indicator; pinned divider/total; white base under the 2dp gap; cache used for hidden loading geometry only. A 2px extreme-size header overflow was fixed by intrinsic sizing. |

## Point-by-point requirement map

| Prompt point | Requirement | Implementation / observed evidence |
|---|---|---|
| 1 | Complete hierarchy correction | One TikTok-only token system covers typography, spacing, controls, fields, helpers, page accordion and the bottom price surface. Fresh captures replace the rejected set. |
| 2 | Existing font family | RabarAuthRegular, the existing Auth face (Rabar_022.ttf); no fonts added or replaced. |
| 3 | AppBar | 18sp / 500 / 1.5 line height. At large text on narrow screens, the title receives more horizontal space and wraps at words. |
| 4 | Section headings | 16sp / 500 / 1.5; near-black, right aligned; no 700 weight. |
| 5 | Input labels | 15sp / 500 / 1.5; a measured 16dp gap before their own input. |
| 6 | Input values | 15sp / 400 / 1.5, including the editable default ad name. |
| 7 | Helpers | 13sp / 400; page status 12sp. Coupon hint explicitly uses the Auth helper face; tutorial/example links remain secondary. |
| 8 | Button text | 14sp / 500 / 1.5; Sponsor uses the same medium weight. |
| 9 | Spacing hierarchy | Measured heading-to-control 16dp; section-to-next-heading 32dp; grouped controls 12dp. |
| 10 | Visual rhythm | All top-to-bottom transitions use the same smaller internal / larger external gap. |
| 11 | No uniform cramped gaps | Recorded measurements establish 32dp > 16dp for every requested transition. |
| 12 | Horizontal margins | 20dp on both sides. Form, page accordion, Sponsor and price card share these bounds. |
| 13 | Input geometry | 56dp measured normal height; 16dp horizontal padding; 12dp radius; subtle #E2E8F0 border. |
| 14 | Open sections | No large section wrapper cards, including the Direct Message account/video sections. Small functional payment/page/forecast surfaces remain. |
| 15 | Four ad types | Exact heading جۆری ڕیکلام and exact contact, views, restaurant, app-download labels retained. |
| 16 | Primary inactive | White fill, #64748B text, #CBD5E1 border, soft shadow. |
| 17 | Primary active | Solid #2F70C7 fill, white text, transparent border preserving dimensions, soft shadow. |
| 18 | Balanced blue | #2F70C7 medium blue, scoped to TikTok creation controls and pricing; no global brand change. |
| 19 | Secondary controls | Destination and page disclosure use the secondary visual system. |
| 20 | Secondary inactive | White fill, #0F172A text, gray border, restrained shadow. |
| 21 | Secondary active | #EDF4FC pale blue fill, #2F70C7 text and border; no white text / solid blue fill. |
| 22 | Button radius | 12dp on scoped choices, fields and Sponsor. |
| 23 | Button height | 50dp measured normal choices. All options in a group share geometry; larger text reduces columns and grows rows when needed. |
| 24 | Soft interaction | 180ms easeOutCubic color/border/shadow/text transitions, with no bounce or selection-driven movement. Page text transition is explicit. |
| 25 | Icons | 21dp objective glyphs, 8dp icon/text gap; existing brand assets retained. |
| 26 | All-platform logos | Supported page channels appear as a compact 17dp logo row with 3dp gaps; no unsupported channel is invented. |
| 27 | TikTok identity | Existing TikTok logo, same destination-control geometry as All Platforms. |
| 28 | Page accordion | Expandable/collapsible disclosure remains; section heading now has its own 16dp control gap. |
| 29 | Page rows | Compact 42dp image/fallback, name, status and selected indicator; no giant row cards. |
| 30 | Typed filtering | Existing authenticated-owner/type/readiness filtering retained and regression tested for contact, restaurant and download resources. Views retain video inputs. |
| 31 | Editable ad name | New Ad DD-MM-YYYY initialization and customer-edited state preserved; same route/recovery semantics. |
| 32 | Removed fields | No wealth/category or device controls in the TikTok form and no placeholder gaps for them. |
| 33 | Help spacing | 8dp field-to-helper, 32dp helper-to-next heading or optional-note group. |
| 34 | Separate Sponsor | Scrollable normal primary button, 50dp normal height, medium text, 12dp corners; 32dp after the payment card. |
| 35 | Rebuilt Final Price | Dedicated bottom-anchored long rectangular surface; old rounded price renderer removed. |
| 36 | Long horizontal shape | 353dp wide at 393dp viewport, 280dp at 320dp, 240dp at 280dp; fills the usable phone width. |
| 37 | Sharper price corners | 10dp radius, independent of regular form-card/receipt geometry. |
| 38 | Above navigation | Card bottom is exactly 2dp above the existing fixed navigation. |
| 39 | Full usable width | 20dp screen gutters, no extra narrow phone-width constraint. |
| 40 | Compact collapsed height | 72dp at 393/320/280 with normal text. Large-text height grows rather than squeezing text. |
| 41 | Collapsed content | Only کۆی گشتی, authoritative total or compact loader, and disclosure icon; no بینینی وردەکاری text. |
| 42 | Collapsed RTL row | Label on the right, amount column, internal chevron on the left; large text can stack predictably. |
| 43 | Internal disclosure | 22dp chevron within a 48dp tap target. Header tapping also toggles; no extra bubble. |
| 44 | Total typography | 16sp / 600 / blue; number and currency stay together. No guessed or stale total is shown during recalculation. |
| 45 | Expand same card | The same component expands upward; no modal and no replacement surface. |
| 46 | Breakdown contents | Unit price, service fee, optional real discount, one divider, anchored total. |
| 47 | Amount alignment | One shared amount-column width at normal sizes. At accessibility sizes that would break Kurdish words, all rows consistently stack label/value with aligned amount edges. |
| 48 | Row typography | Label 13sp / 400; amount 14sp / 500; total label 15sp / 500; total amount 16sp / 600. |
| 49 | Compact row rhythm | 12dp between detail rows; 6dp within a stacked accessibility row. |
| 50 | Divider | One 1dp soft divider in a 24dp slot, fixed immediately above the total even when details scroll. |
| 51 | Soft elevation | White surface; #100F172A upward shadow, 12dp blur, offset (0,-3); no popup-style heavy elevation. |
| 52 | Fixed scrolling layers | Form scrolls behind price; bottom navigation and price bottom stay fixed. A 12dp white base prevents content leaking through the tiny nav gap. |
| 53 | Loading geometry | 20dp loader replaces the amount in its reserved area. Hidden cached measurements retain geometry only; cached prices are not presented. |
| 54 | Expanded loading | Expanded state and card bounds survive recalculation; detail amount placeholders preserve rows without exposing stale amounts. |
| 55 | Price animation | 200ms easeOutCubic AnimatedSize aligned to bottom; chevron rotation matches; reduced-motion respected. |
| 56 | Navigation independence | Expand/loading/scroll tests assert unchanged navigation rectangle and price bottom edge. |
| 57 | Content clearance | Scroll padding reserves enough room for the maximum expanded surface. Sponsor is proven fully reachable above price at all requested widths/scales, including keyboard coverage. |
| 58 | Single price summary | No duplicate in-form TikTok price-summary card. Budget controls still show their own budget data. |
| 59 | Intentional nav stacking | 2dp nav gap, matching gutters, rectangular footprint and a restrained upward shadow. |
| 60 | Measured section QA | 27 actual transitions/gaps recorded from rendered geometry in measurements.json, plus input/button/price/nav bounds. |
| 61 | Requested transitions | Ad type→name→code→helper→link, media→audience→budget→schedule and payment→Sponsor all measured and visually reviewed. |
| 62 | Responsive checks | 393, 320 and 280dp at normal/200% text; existing suite also exercises 240dp and 300% plus keyboard conditions. |
| 63 | New screenshots | Fresh named PNGs from the actual Flutter widgets, plus contact sheets and a hash manifest. No rejected PNG is reused as current acceptance evidence. |
| 64 | Actual measurements | Recorded font sizes/weights, gutters, gaps, input/control geometry, price widths/heights/radius and nav gap. |
| 65 | Spacing acceptance | Every measured section gap is 32dp and exceeds its 16dp heading-to-control gap. |
| 66 | Typography acceptance | Auth face retained with controlled 400/500/600 hierarchy; normal fields and helpers are not bold. |
| 67 | Price acceptance | Long, near-full width, 10dp corners, 2dp above nav, 72dp collapsed, upward expansion, aligned amounts, fixed divider/total, separate Sponsor. |
| 68 | Visual verification | New PNGs inspected alongside measurement/test evidence. Visual findings and fixes are documented below; test success alone is not treated as user approval. |
| 69 | Final report | The requested 20 report items, changed-file manifest, complete requirement mapping, screenshots and test evidence are included. |

## Verification and visual review

See [verification.json](verification.json) for exact command outcomes and log hashes. The complete local suite passed **1,331 tests**, with **1 intentional guarded-staging skip** and zero failures. After formatting and two const annotations, all **7** balanced-layout/capture tests passed again and all **37 PNGs** reproduced byte-for-byte. Analysis of the 11 edited source/test files reports no errors or warnings and one pre-existing informational style finding. Final visual evidence comprises 37 PNGs and 7 review sheets; overlapping test counts are not added. The first visual pass used all six contact sheets and full-size views of the initial screen, accordion, price card and large-text cases. Corrections were applied and a new final screenshot set was generated. Final review covers every image in the new manifest, including discount, loading, error/retry and narrow internally scrolling details.

Earlier regression failures included two obsolete expectations for natural-width choices / a 48dp Sponsor; these were updated to the newly required uniform grid and 50dp control. The discount label's green styling was restored rather than weakening its test. A transient unrelated deposit fixture failure passed the isolated rerun without changing deposit code.

Receipt typography, bitmaps and layout remain protected by the exact reference golden. `ReceiptAppBar` only gains an optional title style for this screen; its default remains unchanged. Existing Meta screenshot outputs remain byte-for-byte unchanged after rerendering. Historical rejected PNGs are retained as history, not overwritten or presented as the current result.

The screenshots render actual production Flutter widgets with deterministic fictional repositories and bundled fonts, at 2x image resolution. They are design evidence, not live TikTok/FastPay transactions or physical-device performance certification. No new external pixel-reference image accompanied this prompt; review is against the supplied typography, geometry, hierarchy and state requirements. These results do not substitute for the user's visual approval.

Production release remains separate: this visual revision does not apply the pending migration, enable production flags or activate the previously blocked n8n workflows.
