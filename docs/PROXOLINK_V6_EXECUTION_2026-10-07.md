# ProxoLink V6 executed verification — 2026-10-07

CURRENT corrected Android verification is **BLOCKED** on authorized environment approval: run `37694585964`, attempt 2, revision `5bf533b11b7f638acc65395b65da1512e3275f5f`, runtime job `113046619691`. The corrected APK built successfully; 0 corrected native cases have executed. The last executed Android revision, `1dca41a315b6988d98006f40ae4bee810be137f6`, remains **FAILED**: all 240 candidate captures, 240 baselines and 240 passing behavior cases are present, but 235/240 exact same-emulator pixel pairs passed and 5 failed. No required captures are missing. PR #7 remains Draft, open and unmerged.

[Passing corrected source CI](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37694585981) · [Corrected protected run awaiting approval](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37694585964) · [Completed failed protected run](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37669328941) · [Capture inventory](evidence/proxolink-v6-2026-10-06/native-1dca41a/evidence-inventory.json).

**Requirement results**

VERIFIED means an executed check supports the stated scope. FAILED means an executed acceptance check failed. BLOCKED means the required execution has not completed or has no isolated target. Compilation, an APK build, a Chromium capture and source tests are not Android runtime certification.

| Requirement | Status | Executed evidence and limits |
|---|---|---|
| Backend/API | VERIFIED | 121 passed, 0 failed in corrected source CI 37694585981 at 5bf533b. Previous executed Android source CI 37669328976 at 1dca41a passed 120. |
| Database/RLS | VERIFIED | Disposable PostgreSQL 17.11: migration rollback and rerun, direct RLS assertions and 7 database-backed API lifecycles. No production DDL. |
| Database PAGE UUID differs from auth/owner/request UUID | VERIFIED | Actual database generation, multiple pages per owner, immutable IDs, cross-owner denial and edit/retry URL stability executed in the database/API tests. |
| Contact create/edit/preview/public rendering | VERIFIED | Backend and database execution, Flutter flows and browser renderer matrix. Hosted isolated staging is separately BLOCKED. |
| Restaurant create/edit/preview/public rendering | VERIFIED | Talabat-only, Toters-only and combined API lifecycles plus database/Flutter/browser checks. Hosted staging is BLOCKED. |
| App Download create/edit/preview/public rendering | VERIFIED | Google Play-only, App Store-only and combined API lifecycles plus database/Flutter/browser checks. Hosted staging is BLOCKED. |
| Wrong route/type rejection | VERIFIED | Typed public and avatar route guards, immutable page type and preview type/capability binding executed. |
| Malformed provider/store URLs | VERIFIED | Canonical provider allowlists and malformed/scheme/host/query injection cases executed. Viber regression also executed. |
| Flutter tests | VERIFIED | 189 passed in corrected source CI 37694585981 at 5bf533b; corrected native debug APK compiled successfully in protected workflow attempt 2. Compilation is not Android runtime certification. |
| Flutter analysis | VERIFIED | Existing explicit 10-item analysis: 27 informational findings, 0 warnings/errors; corrected integration_test analysis: 4 informational findings, 0 warnings/errors. This is not a claim of full-repository analysis. |
| RTL/LTR, long text, overflow and requested widths | VERIFIED | 480 actual renderer/Chromium cases covering widths 320, 375, 393, 430 and 768; all 3 types, 4 designs, Kurdish/English, both orientations, normal/long text and 1.6 text scale. |
| Same prepared top layout across all types | VERIFIED | Actual browser matrix and same CSS blocks retained in all four prepared designs. Type labels/actions vary; design identity is preserved. |
| Four original designs in all three page types | VERIFIED | The existing four keys only; same-environment Chromium baseline comparisons passed. Source CSS comparison was also executed at this revision. Android parity is separately FAILED. |
| Flutter widget thumbnail selector and immediate full live preview updates | VERIFIED (widget scope) | 12 real rendered thumbnail assets decoded; 24 selector width/direction cases, all four card taps/semantics/equal heights, and 3 current-draft live-preview flows executed. Large preview still uses the server-rendered WebView. |
| Live native Flutter WebView behavior matrix | VERIFIED | 240 executed/passed, 0 failed at 1dca41a: 80 per type, 60 per design; RTL/LTR, providers, overflow and safe/inert navigation assertions passed. |
| Full Android acceptance | BLOCKED | Corrected run 37694585964, attempt 2, is waiting for authorized environment approval; 0 corrected native cases executed. Last completed run 37669328941 remains FAILED because five strict pixel comparisons failed. |
| Native thumbnail → large WebView selection | NOT VERIFIED | 0 native chooser cases: the pinned probe directly renders ProxoLinkPreview and does not tap ProxoLinkDesignSelector. Widget taps are not native chooser evidence. |
| Exact Android baseline/candidate pixels | FAILED | Current run: 235 exact / 5 failed among all 240 pairs, five changed pixels total, max channel error 1. Zero changed pixels remains mandatory. |
| Live auth/RLS/private-template and response-header boundaries | VERIFIED | Actual read-only Android-run HTTP preflight passed; 4/4 rendered-preview header checks passed. Current 1dca41a preflight passed and retained only safe boolean results; 4/4 current live response checks passed. |
| Client/release APK template-source privacy | VERIFIED | Source scan, release APK build and APK privacy scan passed in corrected source CI 37694585981 at 5bf533b. Catalog contains safe metadata, not reusable HTML/storage paths/checksums. |
| Telegram as a normal Contact action; no new outbound tracking | VERIFIED | Registry/rendering/API tests and source scan passed. Typed ad links use stable page URLs and produce zero outbound events in the database lifecycles. No bot/notification credentials or workflows were introduced. |
| Production customer cards and advertisement relationships preserved | VERIFIED | Executed read-only checkpoints retained 21 cards, 27 ads, matching full-card/relationship hashes and zero invalid relationships. Full advertisement-row immutability is not asserted. |
| Hosted isolated staging end-to-end | BLOCKED | 0/12; no separate Supabase project/branch or matching staging deployment/configuration. No production fallback or fixtures. |
| Actual native management create/edit/upload/activation journey against isolated staging | BLOCKED | Needs the isolated target; the read-only catalog/native probe is not this journey. |
| PR #7 Draft/open/unmerged | VERIFIED | Connector read confirmed the state before evidence publication; final state is checked again after the update. |

**Model, additive migration and routing**

The existing `public.proxolink_cards` table remains the database model. `id` is a database-generated page UUID; `user_id` is the authenticated owner UUID; `client_request_id` is a separate owner-scoped idempotency/upload UUID. Create omits `id`, rejects owner/request UUID substitution and checks the database result. The migration enforces the three identities differ and makes identity/type immutable. Public UUIDs identify pages; they do not authorize editing.

The only added migration is `proxo_app/supabase/migrations/20261006220119_proxolink_v6_independent_pages.sql`. It adds nullable `page_kind`, `settings` JSONB and `archived_at`; a NOT VALID check constrains new typed records without rewriting legacy data; invoker validators and triggers have fixed search paths; restrictive authenticated-owner RLS and an archive-instead-of-hard-delete policy constrain typed records; a filtered owner/type index supports listing. It was applied, rolled back and rerun on disposable PostgreSQL. It was not applied to production.

`settings.providers` contains canonical `provider_key`, `destination_url`, `enabled` and `sort_order` values with strict type/provider and URL validation. Existing common name/bio/avatar and publication fields are reused. NULL `page_kind` remains the explicit legacy Contact adapter. Existing legacy UUIDs and advertisements are not converted.

| Type | Stable public path | Shared top field meanings | Allowed actions |
|---|---|---|---|
| Contact | `/contact/{PAGE_UUID}` | Page Image, Page Name, Bio | WhatsApp, Viber, Instagram, Telegram, Korek, Asiacell |
| Restaurant | `/order/{PAGE_UUID}` | Restaurant Logo, Restaurant Name, Bio | Talabat, Toters; existing supported Lezzoo/WADE entries remain in the reviewed registry |
| App Download | `/download/{PAGE_UUID}` | App Icon, App Name, Bio | Google Play, Apple App Store |

No generic Phone provider exists in the V6 registry. Korek and Asiacell remain separate named providers even though both canonical destinations use `tel:`. Telegram remains a normal configurable Contact link.

The existing root API dispatcher and Express/Vercel mappings route each path to the shared private renderer with an enforced expected type. A page opened under the wrong path rejects; a query cannot convert a typed page or avatar route. Authenticated management checks ownership independently of the public ID. Editing uses the existing optimistic `updated_at` check. Edit, retry and activate/deactivate retain the same UUID and route; delete soft-archives typed pages. Unsaved live previews encrypt type-bound draft content in short-lived capabilities, render on the server and remain inert.

The feature write guard requires `PROXO_V6_WRITE_MODE=isolated` and rejects the production Supabase reference. This guard remains active. No production activation, deployment, migration or customer cleanup was performed.

**Prepared designs and the completed thumbnail change**

| Existing template key | Kurdish name |
|---|---|
| `pill` | ستایلی کلاسیک |
| `pill-mint` | ستایلی سروشتی |
| `pill-dark` | ستایلی تاریک |
| `pill-white` | ستایلی ڕووناک |

The existing version 6 prepared templates and `pill-templates-1.4.0` runtime are reused. The retained original baseline is commit `ba03534e73fa18fffbe42d8efbeb2e2661009ce0`. The four candidate CSS blocks were compared with their prepared baseline at 1dca41a and remain byte-for-byte identical. This continuation changes only native verification code, tests, debug-only Android support and evidence. No design set, colors, typography or production stylesheet was replaced.

The attached thumbnail prompt was read completely before its UI edits. Those UI changes are confined to `proxo_app`. Twelve thumbnails were generated from the actual existing authenticated server-preview renderer with fictional isolated fixtures: 393×1040 captures reduced to 240×635, 868,949 bytes total. The manifest records hashes, inert rendering and zero outbound requests.

The selector contains image cards, formal labels, selection borders/checks and semantic taps. It is constrained to 432 pixels, uses a responsive one/two-column layout and 12-pixel gaps. All four labels are measured with the actual font/text scale so cards have equal label heights without truncation. Each image decodes at cacheWidth 240; four decoded images use about 2.4 MiB. There are no WebViews inside these small cards.

Selecting another card immediately requests the existing full live preview with the current unsaved draft. Tapping the selected card does not duplicate the request. The existing edit debounce and full-preview button remain. Cached thumbnails serve only the chooser; they do not replace the actual full WebView preview.

The latest CI artifact contains actual Rabar-font chooser captures for Contact, Restaurant and Download; the earlier Ahem-font capture and late semantics cleanup failure were corrected. The final 189-test execution includes equal-height, tap and direction assertions. [UI evidence artifact](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37650583921/artifacts/11496552525) · [Browser responsive evidence](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37650583921/artifacts/11495494600). Artifact hashes and expiration times are in `ci-results.json`.

The last additional implementation change adds two assertions to all seven existing API lifecycle cases: an idempotent create must return the stored page type and exact stable typed URL. All seven passed in CI. The suspected missing-type defect did not reproduce because the existing shared database reader already appends typed fields; no production API fix or rewrite was made.

**CURRENT Android result and capture correction**

[Existing protected run 37669328941](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37669328941), attempt 1, revision `1dca41a315b6988d98006f40ae4bee810be137f6`, runtime job `112958862311`, completed with failure on 2026-10-07 at 21:45:03 UTC. The authorized environment review was cleared before execution. The Android APK build succeeded, and the actual production Android WebView runtime step executed; the build is not used as native certification.

The downloaded artifact SHA-256 was verified: `10b54dbe2e62104f9b12f8476e5962ce6ddcb7e6f8e3f80eacd92451ce7f6417`. [Artifact 11513497183](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37669328941/artifacts/11513497183) contains 1,204 files and 79,889,382 bytes, expires 2026-10-14 at 21:44:57 UTC, and includes complete safe per-case and pixel evidence. This commit retains its allowlisted JSON and all five failed candidate/baseline/diff crops, with exact coordinates and RGB values in [diagnosis.json](evidence/proxolink-v6-2026-10-06/native-1dca41a/diagnosis.json).

All 240 behavior cases passed, 0 failed: Contact/Restaurant/Download each 80; each of the four prepared designs 60; 120 RTL and 120 LTR; portrait/landscape at widths 320/375/393/430/768. Provider rendering, font/image/icon readiness, motion, inert preview clicks, intercepted canonical public actions, navigation boundaries and overflow assertions executed. Read-only app authentication, RLS/private-template boundaries and 4/4 rendered-response checks passed. The separate views capture the same emulator/WebView/DPR 1 environment.

The expected manifest is 4 designs × 3 page types × 2 languages × 2 orientations × 5 widths = 240 cases. The archive, metadata and sanitized capture acknowledgements match every expected ID:

| Required evidence | Expected | Present | Missing or invalid |
|---|---:|---:|---:|
| Candidate full captures | 240 | 240 | 0 |
| Baseline full captures | 240 | 240 | 0 |
| Candidate WebView crops | 240 | 240 | 0 |
| Baseline WebView crops | 240 | 240 | 0 |
| Pixel diff files | 240 | 240 | 0 |
| Case metadata/results entries | 240 | 240 | 0 |
| Pixel comparison entries | 240 | 240 | 0 |
| Unique candidate/baseline capture acknowledgements | 480 | 480 | 0 |

All 1,200 PNGs are valid. The artifact's four JSON files are case-results.json, pixels.json, security.json and failure.json; no failed or skipped behavior case IDs exist. The absent results.json is a success-only output written *after* validateNativeResults. Its absence follows the failed pixel gate; it did not cause collection failure. The early 20:47:51 UTC ADB-offline event recovered, and all 480 captures completed afterwards.

[Full capture filename/hash/dimension manifest](evidence/proxolink-v6-2026-10-06/native-1dca41a/capture-file-manifest.json) · [Safe capture acknowledgement index](evidence/proxolink-v6-2026-10-06/native-1dca41a/capture-log-index.json) · [Exact inventory](evidence/proxolink-v6-2026-10-06/native-1dca41a/evidence-inventory.json) · [Original validator replay](evidence/proxolink-v6-2026-10-06/native-1dca41a/validator-replay.json).

Strict parity FAILED: 235 exact pairs, 5 failed pairs, 5 changed pixels total. Every failure is one color-channel value at a single pixel in the shared header gradient/text edge:

| Native case | Crop coordinate | Candidate RGB | Baseline RGB |
|---|---|---|---|
| pill/contact/en/portrait/768 | (380, 222) | 215, 222, 236 | 215, 221, 236 |
| pill/order/ku/portrait/768 | (380, 222) | 220, 227, 240 | 220, 226, 240 |
| pill/order/en/portrait/768 | (380, 222) | 215, 222, 236 | 215, 221, 236 |
| pill-mint/order/en/portrait/430 | (282, 184) | 237, 247, 244 | 237, 247, 243 |
| pill-mint/order/en/portrait/768 | (290, 228) | 234, 245, 241 | 234, 246, 241 |

The exact terminal error `native_case_collection / native_evidence_incomplete` came from the pinned validator combining evidence completeness and zero-pixel parity in one conditional. Replaying that unchanged validator against the unchanged artifact data proves every metadata/completeness/geometry predicate passes and only the five nonzero pixel predicates fail. This is the established cause of the misleading final error. The diagnostic correction distinguishes `native_pixel_parity_failed` from incomplete evidence and unstable captures, while preserving rejection of even one changed channel at one pixel.

The pinned Dart probe only checked JS readiness and waited two seconds before publishing capture-ready; the runner then captured one surface per role. It never acknowledged native raster/draw completion. Android documents that DOM updates are asynchronous and provides [WebView.postVisualStateCallback](https://developer.android.com/reference/android/webkit/WebView#postVisualStateCallback(long,%20android.webkit.WebView.VisualStateCallback)) for this purpose. That missing acknowledgement is a proven harness gap. Its causal connection to all five one-level differences is an inference requiring the protected rerun; no product design defect is established by the current evidence.

The smallest scoped correction adds a debug-only Android probe activity/channel. Each role now waits for the existing native WebView's visual-state callback, a real onDraw and two compositor-frame callbacks. The production ProxoLinkPreview, rendering settings, CSS, assets, original baseline and thumbnails are untouched. The runner takes exactly three predetermined screenshots per role, independently checks that every crop equals its first crop, retains repeats, and compares the first candidate frame with the first baseline frame. No matching-frame search, averaging, masking, relaxed threshold or retry-until-pass exists. Final acceptance requires all 240 behavior cases, fresh native views, both native paint barriers, exact repeatability and zero changed pixels.

Validation after this correction: 121 local Node tests passed, 0 failed; source-privacy scan, JavaScript syntax and diff whitespace checks passed. Corrected source CI 37694585981 completed successfully at 5bf533b: backend 121, Flutter 189, renderer/browser responsive 480, database/RLS and 7 API lifecycles, edge functions and release APK privacy passed. Corrected native probe analysis and debug APK compilation also succeeded in protected workflow attempt 2. New regression coverage rejects a one-channel one-pixel drift and rejects missing barriers, unstable captures or fewer than three samples. The actual corrected Android runtime remains unexecuted.

The original failed run and workflow are preserved. The correction reuses `.github/workflows/proxolink-native-build.yml` with environment `proxolink-preview-verification` and required reviewer `Zana-Sponsor`; the workflow and protection are unchanged. The corrected run must receive authorized environment approval before native execution. No protected job is approved or bypassed by this continuation.

The corrected run is [37694585964](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37694585964), revision `5bf533b11b7f638acc65395b65da1512e3275f5f`. Attempt 1 stopped before compilation because its NDK download was not a ZIP archive; this transient download failure is separate from the original native result. Retrying failed jobs in the same run produced attempt 2: APK job `113044672963` SUCCESS; runtime job `113046619691` WAITING for the existing authorized reviewer. The current corrected counts are expected 240, executed/passed/failed 0/0/0, candidate 0, baseline 0, with 240 candidate and 240 baseline captures still pending. Pixel parity is NOT EXECUTED. This is BLOCKED, not VERIFIED or a failed evidence collection. No replacement workflow was created.

Native thumbnail-selection coverage remains unexecuted (0 cases). The production preview widget is tested directly, without tapping ProxoLinkDesignSelector. The 240-case matrix and widget tests do not certify thumbnail → selected large WebView navigation. Actual OS-provider-app launch/fallback, physical-device coverage and the isolated native management lifecycle also remain outside this probe's verified scope.

Historical V6 results remain separate: run 37647222280 at de501a9 passed 240 behavior cases, 0 failed, but only 233 exact pixel pairs / 7 failed; it is FAILED. Its artifact 11501290385 has SHA-256 `9018409f19abf2ec298b413d5f620892b47e52586c8c7522ee93cfcc471575fc`. Older run 37602803930 at 5dbf391 timed out after 169 behavior passes, with 112 exact pairs / 57 failed. Neither result is copied into the CURRENT counts.

**Isolated staging and remaining blockers**

Earlier read-only inventory listed production Zana `cojchkwssmasiejcgvbk` and the unrelated Exchange project `pycxuugoblkslvwebxuu`; Zana development branches were empty. The `proxolink-staging` deployment-project search was empty. The existing staging runner previously executed and rejected missing isolated configuration with exit 1 before writes. It did not fall back to production.

All eight settings remain required: `PROXO_STAGING_PROJECT_REF`, `PROXO_STAGING_SUPABASE_URL`, `PROXO_STAGING_BASE_URL`, `PROXO_STAGING_ANON_KEY`, `PROXO_STAGING_TEST_EMAIL`, `PROXO_STAGING_TEST_PASSWORD`, `PROXO_STAGING_OTHER_EMAIL`, `PROXO_STAGING_OTHER_PASSWORD`. Protection bypass is optional and staging-scoped. The server also needs isolated service/signing secrets, existing V5 prerequisites plus the additive V6 migration, and the unchanged isolated-write setting. Credentials are not included in this report.

Hosted create/edit/unsaved preview/upload/public rendering/URL stability/ownership/route integrity/retry/activation/deactivation for all three types and four designs are 0/12 BLOCKED. Disposable PostgreSQL lifecycles establish database behavior but are not substituted for hosted staging end-to-end.

**Security and data preservation**

Executed API/DB tests enforce authentication, ownership, restrictive RLS, immutable page identity/type, provider allowlists, canonical URLs, escaped text and safe HTML/JavaScript delivery. Tampered/expired previews, wrong-route/type/owner identifiers, malformed URLs and unsafe avatar paths reject. Rendered pages use restrictive CSP, no-store, nosniff and no-referrer headers. Anonymous/authenticated clients cannot directly read internal template/event/audit tables or private template objects. Secrets stay server-side or in approved CI runtime files; the release APK scan rejects reusable template/bot-source markers.

Typed outbound actions do not write click analytics or contact events. Existing advertisement relationships are preserved. Publishing lifecycle audit records are not outbound-button tracking. Private reusable template access is enforced over application/Storage/client delivery; this public GitHub repository is not claimed to hide its source from repository readers.

The read-only before/after checkpoints match 21 full customer-card rows and 27 advertisement relationships, with hashes recorded in `production-checkpoints.json` and zero invalid references. Historical concurrent advertisement-row changes were not attributed to this work; full advertisement-row immutability is not claimed.

**Exact files changed**

Historical implementation inventory: the net delta from task starting commit `7d95421da4ebf2101b86793b3c4d6e92a8b9a06b` to 9ec6264 is exactly 68 files below. `source-files.json` records their Git blob SHAs. Earlier V5 changes already present before this task are excluded; PR #7's whole diff includes that earlier work.

| Change | File |
|---|---|
| modified | `.github/workflows/proxolink-native-build.yml` |
| modified | `.github/workflows/proxolink-verify.yml` |
| modified | `api/_lib/proxolink-handlers/contact-ad-links.js` |
| modified | `api/_lib/proxolink-handlers/contact-ad.js` |
| modified | `api/_lib/proxolink-handlers/contact-avatar.js` |
| modified | `api/_lib/proxolink-handlers/contact-card-action.js` |
| modified | `api/_lib/proxolink-handlers/contact-cards.js` |
| modified | `api/_lib/proxolink-handlers/contact-preview-token.js` |
| modified | `api/_lib/proxolink-handlers/contact-templates.js` |
| modified | `api/_lib/proxolink-handlers/contact.js` |
| added | `api/_lib/proxolink-handlers/independent-pages.js` |
| added | `api/_lib/proxolink-handlers/page-preview.js` |
| added | `api/_lib/proxolink-native-baseline/manifest.json` |
| added | `api/_lib/proxolink-native-baseline/pill-dark.html` |
| added | `api/_lib/proxolink-native-baseline/pill-mint.html` |
| added | `api/_lib/proxolink-native-baseline/pill-white.html` |
| added | `api/_lib/proxolink-native-baseline/pill.html` |
| added | `api/_lib/proxolink-pages.js` |
| added | `api/_lib/proxolink-prepared.js` |
| modified | `api/_lib/proxolink-preview.js` |
| added | `api/_lib/proxolink-templates/pill-dark.html` |
| added | `api/_lib/proxolink-templates/pill-mint.html` |
| added | `api/_lib/proxolink-templates/pill-white.html` |
| added | `api/_lib/proxolink-templates/pill.html` |
| modified | `api/_lib/proxolink.js` |
| modified | `api/proxolink.js` |
| added | `proxo_app/assets/proxolink_thumbnails/contact-pill-dark.png` |
| added | `proxo_app/assets/proxolink_thumbnails/contact-pill-mint.png` |
| added | `proxo_app/assets/proxolink_thumbnails/contact-pill-white.png` |
| added | `proxo_app/assets/proxolink_thumbnails/contact-pill.png` |
| added | `proxo_app/assets/proxolink_thumbnails/download-pill-dark.png` |
| added | `proxo_app/assets/proxolink_thumbnails/download-pill-mint.png` |
| added | `proxo_app/assets/proxolink_thumbnails/download-pill-white.png` |
| added | `proxo_app/assets/proxolink_thumbnails/download-pill.png` |
| added | `proxo_app/assets/proxolink_thumbnails/order-pill-dark.png` |
| added | `proxo_app/assets/proxolink_thumbnails/order-pill-mint.png` |
| added | `proxo_app/assets/proxolink_thumbnails/order-pill-white.png` |
| added | `proxo_app/assets/proxolink_thumbnails/order-pill.png` |
| modified | `proxo_app/integration_test/proxolink_native_probe.dart` |
| modified | `proxo_app/lib/models/proxo_card.dart` |
| added | `proxo_app/lib/models/proxolink_design.dart` |
| added | `proxo_app/lib/models/proxolink_page_type.dart` |
| modified | `proxo_app/lib/screens/tools_screen.dart` |
| modified | `proxo_app/lib/services/proxolink_service.dart` |
| added | `proxo_app/lib/widgets/proxolink_design_selector.dart` |
| modified | `proxo_app/lib/widgets/proxolink_preview.dart` |
| modified | `proxo_app/pubspec.yaml` |
| added | `proxo_app/supabase/migrations/20261006220119_proxolink_v6_independent_pages.sql` |
| modified | `proxo_app/test/proxolink_flow_test.dart` |
| added | `proxo_app/test/proxolink_v6_flow_test.dart` |
| added | `proxo_app/tool/generate_proxolink_thumbnails.mjs` |
| added | `proxo_app/tool/proxolink-thumbnail-manifest.json` |
| modified | `scripts/proxolink-staging-verification.mjs` |
| added | `scripts/proxolink-v6-database.mjs` |
| added | `scripts/proxolink-v6-responsive.mjs` |
| modified | `scripts/proxolink-verification-security.mjs` |
| modified | `scripts/run-proxolink-native.mjs` |
| modified | `scripts/run-proxolink-staging.mjs` |
| modified | `scripts/scan-proxolink-source.mjs` |
| modified | `server.js` |
| added | `test/fixtures/proxolink-v5-database.sql` |
| added | `test/fixtures/proxolink-v6-service.mjs` |
| modified | `test/proxolink-api.test.js` |
| modified | `test/proxolink-staging-verification.test.js` |
| added | `test/proxolink-v6-api.test.js` |
| added | `test/proxolink-v6-database.sql` |
| modified | `test/proxolink-verification-security.test.js` |
| modified | `vercel.json` |

The evidence-only publication additionally adds this execution report, `docs/PROXOLINK_V6_ISOLATED_STAGING_SETUP.md`, `docs/evidence/proxolink-v6-2026-10-06/README.md` and the exact paths listed in `evidence-files.json`. No product source changes are made by that publication.

**Files changed after current native testing and final state**

The 10 verification files changed after examining run 37669328941 are recorded with SHA-256 hashes in [native-capture-correction-files.json](evidence/proxolink-v6-2026-10-06/native-capture-correction-files.json): the Dart native probe; debug manifest/activity; dev dependency declaration/lock classification for the already installed Android WebView plugin; Node runner, pixel comparison and security gate; two regression test files. Documentation and allowlisted evidence are listed in evidence-files.json. No production widget, selector, template, thumbnail, migration, workflow, publishing setting or customer record changed in this continuation.

Last fully executed code source CI: run 37694585981 at `5bf533b11b7f638acc65395b65da1512e3275f5f`, SUCCESS (backend 121, Flutter 189, browser 480, database/RLS, 7 API lifecycles, edge functions, release APK privacy). The corrected protected native run 37694585964, attempt 2, remains BLOCKED for authorized environment approval. This report update changes documentation/evidence only and does not claim a later documentation revision has run Android tests.

PR #7 remains Draft, open and unmerged. Remaining native blockers are execution of the corrected protected runtime with zero changed pixels and unexecuted native chooser-selection coverage. Separate isolated staging requirements are retained as historical limits and are outside this native-only continuation. No merge, production publishing/activation, production customer change, migration or destructive cleanup was performed.
