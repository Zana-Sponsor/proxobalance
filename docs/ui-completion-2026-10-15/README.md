# Proxo UI completion and defect verification — 2026-10-15

دیزاینی Auth، زیادکردنی باڵانس، هۆم، پڕۆفایل و نیشانەی + یەکخراون. هۆم تەنها سێ کرداری سەرەکی هەیە؛ لۆگۆی ڕاستەقینەی دابینکەرەکان و کارتەکانی هەڵە بە شێوەی چینە سەر یەکترەکان بەکارهاتوون. ئەم ڕاپۆرتە وێنە، پێوانە و ئەنجامی تاقیکردنەوەکان تۆمار دەکات.

Application source: `e2571ea7507ac1e9103b818fc178e189802a5461`. Comparison baseline: `e24575c135ca599a6775bd66e385d3b8033b7e92`. The evidence commit contains documentation only. PR #7 remains Draft/Open/Unmerged.

[Original before/after gallery](gallery.md) · [Measured geometry](measurements.md) · [Verification record](verification.json) · [All changed files since the comparison baseline](changed-files.txt) · [Files changed during this completion pass](completion-pass-files.txt)

## Requested behavior

| Request | Implemented result |
|---|---|
| Clean, consistent Auth | Removes decorative heading/field/channel icons; retains functional Back and password visibility controls. Shared Rabar typography, quiet filled fields, consistent spacing and rounded surfaces across sign-in, registration, recovery and OTP. |
| Repair phone entry | Persistent `+964`, explicit phone direction, Kurdish/Persian/Arabic digit normalization, local/international paste, fixed mid-edit caret and length enforcement. Single-line hints scale down independently of the accessible editable text. |
| Exactly three Home actions | Create Ad, Add Balance and Create Page have enabled callbacks, icons and balanced labels. No duplicate quick-action heading/button; fallback banner has no synthetic CTA. |
| Admin-managed banner | Existing Firebase `appContent/banners` and `appContent/activeBanner`, then Supabase `pa_banners`, supply localized content. Supabase `title`, `subtitle`, `bg_color`, `btn_text` and `navigate_to`/`link` are honored. Foreground contrast adapts to light, middle and dark backgrounds. Realtime updates retain one subscription; deletion clears stale cached content. No live admin record was written. |
| Correct payment marks | Official FIB, FastPay, Qi, ZainCash, Asiacell and Korek assets; consistent 88×32dp contain area and native interactive cards. Two columns at normal size, one at narrow/large text. Missing recipient configuration is visibly disabled. The unidentified SuperApp placeholder is hidden. |
| Balanced Profile and navigation + | Compact identity card, grouped account/support rows, a soft blue balance card and readable amount. The central create control is a 56dp rounded square with a 32dp plus. Navigation targets and selected states are preserved; narrow large-text navigation scrolls to keep labels readable. |
| Matching rounded banner/action cards and wrapped text | Home banner/actions use 18dp corners. Shared label heights, centered multiline action labels, word-aware Auth headings/channel labels, single-line field hints and scrollable forms prevent orphaned letters and oversized hints. |
| Overlapping 3D errors | Three visible layers use progressively smaller back cards and vertical depth offsets. Only the front card receives input; hidden queued messages are not lost when clearing. Create Ad gives each front message its own five-second reading period. |

## Defects found and repaired during completion

- The former padded FastPay JPEG made the mark almost invisible at its slot size. The unchanged official transparent PNG now renders legibly; SVGs retain native vector geometry.
- Covered Create Ad messages used to expire before the user could read them. Only the front timer now runs. Existing timing tests were updated to verify the full sequential lifetime, while keeping strict early full-opacity/size checks.
- Error-stack cleanup could leave queued cards or its overlay behind. Clearing empties the queue and removing the final card disposes the overlay entry.
- Light or middle-tone administrator banner colors could produce unreadable white text. Foreground selection now compares actual contrast against white and the shared ink color; a blank admin CTA remains blank.
- At 280dp and 2× text, Sorani headings could split off a final letter and phone/email hints wrapped into multiple lines. The longest word is measured under the actual text scaler. Channel label letter spacing is explicit so measurement matches Material rendering. Editable values retain accessibility text scaling.
- Moving from a scrolled sign-in form to registration inherited the old scroll position and hid the new heading. Auth step transitions now reset the owned scroll controller to the top; normal same-step edits keep their position.
- Android testing exposed concurrent notification-permission requests when Home remounted while the first OS request was pending. A shared in-flight guard prevents a second request, unmounted/inactive screens do not prompt, denial does not attempt token registration, and optional permission/FCM failures cannot escape as unhandled exceptions. A regression test covers pending/remount, denial and platform failure.

## Verification method

Screenshots render actual production widgets with bundled fonts and fictional read-only backend data. Baseline and candidate use the same measurement harness. Fifteen screen groups are captured in Sorani, Arabic and Arabic-script Badini at 393×852dp/DPR3/text1× and 280×852dp/DPR2/text2×. Scrolled lower portions are retained separately. OTP evidence uses the actual component, without submitting live authentication.

Geometry comes from laid-out RenderObjects, including text family, size, line height, scale, container padding/radius/color, Material shape and bounds. [The complete register](all-measurements.json.gz) includes every capture and lifecycle record. [Selected raw values](selected-measurements.json) are directly readable. [Image hashes and original dimensions](image-manifest.json) allow byte-for-byte verification. Images are original PNGs, not retouched screens or generated mockups.

Native fixtures use Android API35 in three configurations, with 1×/2× text, actual phone input normalization, decoded logos, action callbacks, disabled actions, Profile/Sidebar/receipts, native keyboard and ADB Back checks. Notifications are pre-granted only on the disposable emulator installation so an OS prompt does not cover unrelated UI captures. Pending/denied/error permission behavior is tested separately against the actual Home widget.

Detailed terminal results and immutable run links are in [verification.json](verification.json). Counts from overlapping suites must not be added into a unique-test total. Flutter analysis permits the repository's existing info/warning policy; passing analysis is not a claim of zero analyzer diagnostics.

## Final results

All six final-source workflows completed successfully. The optional protected runtime/hosted jobs in the APK workflow were skipped and are not counted as verification.

| Gate | Result |
|---|---|
| [Auth/localization/polish](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38771491459) | 90 candidate capture tests and 29 behavior tests pass; 126 candidate PNGs including lower sections and notices |
| [UI/remediation/receipt regression](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38771491425) | 64 candidate capture tests and 298 behavior tests pass |
| [Profile/navigation/chrome](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38771491367) | 20 candidate captures and 3 behavior tests pass |
| [Android API35](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38771491412) | Phone, narrow and tablet pass; 111 original PNGs, 18 action callbacks, three actual ADB Back events, zero tap/overflow/unhandled-exception warning matches |
| [Full source/release gate](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38771491529) | All five jobs pass: Flutter regressions/release APK/privacy scan, backend, responsive, disposable database and edge functions |
| [Credential-free native APK](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38771491357) | Build/analysis pass; optional protected runtime and hosted jobs skipped |

The gallery retains **46 original PNGs**: 19 before/after pairs, three feedback examples and five native examples. The complete widget register contains **6,297 baseline and 5,889 candidate layout rows**, with zero recorded capture/lifecycle exceptions on either side. All five downloaded polish/native ZIPs passed independent SHA-256 and ZIP CRC checks. Other artifact digests are identified as GitHub metadata only in the verification record. All six bundled provider files match their recorded hashes.

| Native configuration | Measured logical viewport | DPR | Text scales |
|---|---|---|---|
| Phone | 393×640dp | 3 | 1× / 2× |
| Narrow | 280×640dp | 3 | 1× / 2× |
| Tablet | 768×852dp | 2 | 1× / 2× |

Phone emulator height was clamped to 1920 physical pixels by Android; the table reports the actual measured viewport, not the requested command-line size. [Native measurements](native-measurements.json) retain the raw device/Flutter values and successful phone normalization, disabled actions, decoded image, keyboard and back observations.

## Asset provenance

[Provider sources and exact SHA-256 hashes](../../proxo_app/assets/logos/providers/SOURCES.json) · [Provider trademark notice](../../proxo_app/assets/logos/providers/NOTICE.md). The official FastPay file is unchanged. Korek/ZainCash SVG CSS is inlined for Flutter compatibility; paths and colors are retained. No payment recipient, processing route or ledger behavior was invented by this visual update. Existing Solar icon attribution remains in the app.

## Remaining release work

This UI completion does not close the separate older ProxoLink WebView strict FIRST pixel-parity investigation: the last protected run had 232 exact pairs out of 240, eight failed pairs, ten changed pixels and maximum channel delta1; its cause remains unproven. No tolerance, masking, selector or security gate was loosened. The last completed isolated staging audit found eight required settings missing. Those hosted journeys were not replaced with production traffic.

Representative physical-device profile-mode latency, CPU/heap/frame measurements, manual TalkBack, real authentication/payment delivery and native push delivery remain release validation. Emulator debug screenshots are not performance measurements. The previously prepared ad-correction/notification-guard migration still must precede release of that client change; it was not applied to production here.
