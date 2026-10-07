# ProxoLink V6 executed verification — 2026-10-07

Implementation/test revision: `9ec6264940628c75fa0fc114edc88013a61cbab5`. The protected native retry remains pinned to `de501a9557cbd83520c5916e0c0085ec5c5a470e`; the intervening commit changes only test assertions, with no production API/UI/renderer/harness changes. This report continues the existing V5/V6 work; it does not certify completion of the remaining Android or hosted staging gates. PR #7 remains Draft, open and unmerged.

[Executed source CI](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37650583921) · [Latest protected native retry](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37647222280) · [Last executed native run](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37602803930).

**Requirement results**

VERIFIED means an executed check supports the stated scope. FAILED means an executed acceptance check failed. BLOCKED means the required execution has not completed or has no isolated target. Compilation, an APK build, a Chromium capture and source tests are not Android runtime certification.

| Requirement | Status | Executed evidence and limits |
|---|---|---|
| Backend/API | VERIFIED | 120 passed, 0 failed, 0 skipped at the implementation revision. |
| Database/RLS | VERIFIED | Disposable PostgreSQL 17.11: migration rollback and rerun, direct RLS assertions and 7 database-backed API lifecycles. No production DDL. |
| Database PAGE UUID differs from auth/owner/request UUID | VERIFIED | Actual database generation, multiple pages per owner, immutable IDs, cross-owner denial and edit/retry URL stability executed in the database/API tests. |
| Contact create/edit/preview/public rendering | VERIFIED | Backend and database execution, Flutter flows and browser renderer matrix. Hosted isolated staging is separately BLOCKED. |
| Restaurant create/edit/preview/public rendering | VERIFIED | Talabat-only, Toters-only and combined API lifecycles plus database/Flutter/browser checks. Hosted staging is BLOCKED. |
| App Download create/edit/preview/public rendering | VERIFIED | Google Play-only, App Store-only and combined API lifecycles plus database/Flutter/browser checks. Hosted staging is BLOCKED. |
| Wrong route/type rejection | VERIFIED | Typed public and avatar route guards, immutable page type and preview type/capability binding executed. |
| Malformed provider/store URLs | VERIFIED | Canonical provider allowlists and malformed/scheme/host/query injection cases executed. Viber regression also executed. |
| Flutter tests | VERIFIED | 189 passed at this revision; original six test files retained. |
| Flutter analysis | VERIFIED | Existing explicit 10-item analysis: 27 informational findings, 0 warnings/errors; integration_test analysis: 3 informational findings, 0 warnings/errors. This is not a claim of full-repository analysis. |
| RTL/LTR, long text, overflow and requested widths | VERIFIED | 480 actual renderer/Chromium cases covering widths 320, 375, 393, 430 and 768; all 3 types, 4 designs, Kurdish/English, both orientations, normal/long text and 1.6 text scale. |
| Same prepared top layout across all types | VERIFIED | Actual browser matrix and same CSS blocks retained in all four prepared designs. Type labels/actions vary; design identity is preserved. |
| Four original designs in all three page types | VERIFIED | The existing four keys only; same-environment Chromium baseline comparisons passed. Source CSS comparison was also executed at this revision. Android parity is separately FAILED. |
| Thumbnail selector and immediate full live preview updates | VERIFIED | 12 real rendered thumbnail assets decoded; 24 selector width/direction cases, all four card taps/semantics/equal heights, and 3 current-draft live-preview flows executed. Large preview still uses the server-rendered WebView. |
| Live native Flutter WebView execution completed before timeout | VERIFIED | 169 runtime cases at 5dbf391 passed. Contact 60, Restaurant 60, Download 49. This partial execution does not establish all 240 cases or all four designs. |
| Full Android 240-case runtime matrix | BLOCKED | Latest de501a9 runtime has not started; protected environment review is pending and the workspace/browser session is disconnected. Previous run timed out with 71 cases incomplete. |
| Exact Android baseline/candidate pixels | FAILED | Last executed run: 112 passed / 57 failed among 169 complete same-device pairs. Zero-difference acceptance remains unchanged. The corrected fresh-document rerun has not executed. |
| Live auth/RLS/private-template and response-header boundaries | VERIFIED | Actual read-only Android-run HTTP preflight passed; 4/4 rendered-preview header checks passed. All four values were masked in both executed setup blocks. Latest runtime preflight has not executed. |
| Client/release APK template-source privacy | VERIFIED | Source scan, release APK build and APK privacy scan executed at 9ec6264. Catalog contains safe metadata, not reusable HTML/storage paths/checksums. |
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

The existing version 6 prepared templates and `pill-templates-1.4.0` runtime are reused. The retained original baseline is commit `ba03534e73fa18fffbe42d8efbeb2e2661009ce0`. The four candidate CSS blocks were actually compared with their original baseline at de501a9 and were identical. The subsequent 9ec6264 change affects only lifecycle test assertions; product sources remain identical. No design set, colors, typography or production stylesheet was replaced.

The attached thumbnail prompt was read completely before its UI edits. Those UI changes are confined to `proxo_app`. Twelve thumbnails were generated from the actual existing authenticated server-preview renderer with fictional isolated fixtures: 393×1040 captures reduced to 240×635, 868,949 bytes total. The manifest records hashes, inert rendering and zero outbound requests.

The selector contains image cards, formal labels, selection borders/checks and semantic taps. It is constrained to 432 pixels, uses a responsive one/two-column layout and 12-pixel gaps. All four labels are measured with the actual font/text scale so cards have equal label heights without truncation. Each image decodes at cacheWidth 240; four decoded images use about 2.4 MiB. There are no WebViews inside these small cards.

Selecting another card immediately requests the existing full live preview with the current unsaved draft. Tapping the selected card does not duplicate the request. The existing edit debounce and full-preview button remain. Cached thumbnails serve only the chooser; they do not replace the actual full WebView preview.

The latest CI artifact contains actual Rabar-font chooser captures for Contact, Restaurant and Download; the earlier Ahem-font capture and late semantics cleanup failure were corrected. The final 189-test execution includes equal-height, tap and direction assertions. [UI evidence artifact](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37650583921/artifacts/11496552525) · [Browser responsive evidence](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37650583921/artifacts/11495494600). Artifact hashes and expiration times are in `ci-results.json`.

The last additional implementation change adds two assertions to all seven existing API lifecycle cases: an idempotent create must return the stored page type and exact stable typed URL. All seven passed in CI. The suspected missing-type defect did not reproduce because the existing shared database reader already appends typed fields; no production API fix or rewrite was made.

**Actual Android result and the pending correction**

The last approved runtime, [run 37602803930](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37602803930), finished with the actual `native_case_collection / native_verification_timeout` failure after the previous 45-minute collection budget. It was allowed to finish; it was not canceled for the thumbnail request.

It retained 169 complete native cases/pairs: 169 runtime assertions passed, 0 runtime assertions failed, 112 exact pixel pairs passed and 57 failed. The 170th candidate-only screenshot is not counted as a complete pair. Coverage was `pill` 60, `pill-mint` 60, `pill-dark` 49 and `pill-white` 0. Thus 71 required cases were not completed. All 60 Contact cases exercised canonical Viber actions on the older Android URL parser after the real Viber compatibility fix.

The downloaded 850-file artifact was inspected before disconnection. Differences were at most one channel level: mostly the WhatsApp shadow, with a few single header-edge pixels. For example, the classic Contact 393 capture had 1,129 changed shadow pixels; the dark Contact 393 capture had 280; Restaurant 768 had one header-edge pixel. The old candidate had repeated behavior/animation interactions while the baseline had only its initial render. This unequal history was observed; its role as the sole cause of pixel differences is an inference, not a proven exemption.

The already-pushed de501a9 correction reloads both current approved documents after behavior checks and requires fresh time origins, ready/font/image/icon/provider checks, visible actions, hidden transient hints/toasts and identical settling before capture. It also bounds the 48 independent capability reads to four concurrent requests, refreshes five-minute capabilities after three minutes, and gives collection 90 minutes within a 105-minute job budget. The required 240 cases, zero changed pixels, behavior checks, auth/RLS, allowlisted read-only endpoints, masking and original CSS/assets remain intact.

The corrected integration-test analysis and APK build passed. The new [protected run 37647222280](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37647222280) is waiting at environment `proxolink-preview-verification`, runtime job `112883427603`, required reviewer `Zana-Sponsor`. The connector confirmed the current user can review, but exposes no review mutation. The browser and local execution service returned HTTP 409 `environment_offline`, preventing the already-authorized exact-run review and subsequent device/artifact work. This is an execution connection blocker, not a request for new credentials or relaxed protection. No approval is bypassed and no new environment is created.

[Full last executed Android artifact](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37602803930/artifacts/11493772137): 64,739,807 bytes; SHA-256 `9fa3dae80698c19cc49dc50f539f8e2deb41afd7564eed91915a13b59c538cf7`; expires 2026-10-14T15:35:20Z. Safe completed-pair capture/log indexes and aggregate results are retained here. Existing earlier retry files and approval screenshots are also committed. Native screenshots remain Android evidence; Chromium captures are separately identified.

Actual OS-provider-app launch/fallback, physical-device coverage and the complete native management journey are not claimed as verified by this probe.

**Isolated staging and remaining blockers**

Fresh read-only inventory again listed production Zana `cojchkwssmasiejcgvbk` and the unrelated Exchange project `pycxuugoblkslvwebxuu`; Zana development branches were empty. The `proxolink-staging` deployment-project search was empty. The existing staging runner previously executed and rejected missing isolated configuration with exit 1 before writes. It did not fall back to production.

All eight settings remain required: `PROXO_STAGING_PROJECT_REF`, `PROXO_STAGING_SUPABASE_URL`, `PROXO_STAGING_BASE_URL`, `PROXO_STAGING_ANON_KEY`, `PROXO_STAGING_TEST_EMAIL`, `PROXO_STAGING_TEST_PASSWORD`, `PROXO_STAGING_OTHER_EMAIL`, `PROXO_STAGING_OTHER_PASSWORD`. Protection bypass is optional and staging-scoped. The server also needs isolated service/signing secrets, existing V5 prerequisites plus the additive V6 migration, and the unchanged isolated-write setting. Credentials are not included in this report.

Hosted create/edit/unsaved preview/upload/public rendering/URL stability/ownership/route integrity/retry/activation/deactivation for all three types and four designs are 0/12 BLOCKED. Disposable PostgreSQL lifecycles establish database behavior but are not substituted for hosted staging end-to-end.

**Security and data preservation**

Executed API/DB tests enforce authentication, ownership, restrictive RLS, immutable page identity/type, provider allowlists, canonical URLs, escaped text and safe HTML/JavaScript delivery. Tampered/expired previews, wrong-route/type/owner identifiers, malformed URLs and unsafe avatar paths reject. Rendered pages use restrictive CSP, no-store, nosniff and no-referrer headers. Anonymous/authenticated clients cannot directly read internal template/event/audit tables or private template objects. Secrets stay server-side or in approved CI runtime files; the release APK scan rejects reusable template/bot-source markers.

Typed outbound actions do not write click analytics or contact events. Existing advertisement relationships are preserved. Publishing lifecycle audit records are not outbound-button tracking. Private reusable template access is enforced over application/Storage/client delivery; this public GitHub repository is not claimed to hide its source from repository readers.

The read-only before/after checkpoints match 21 full customer-card rows and 27 advertisement relationships, with hashes recorded in `production-checkpoints.json` and zero invalid references. Historical concurrent advertisement-row changes were not attributed to this work; full advertisement-row immutability is not claimed.

**Exact files changed**

The net implementation delta from task starting commit `7d95421da4ebf2101b86793b3c4d6e92a8b9a06b` to 9ec6264 is exactly 68 files below. `source-files.json` records their Git blob SHAs. Earlier V5 changes already present before this task are excluded; PR #7's whole diff includes that earlier work.

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

**Final PR state**

PR #7 is Draft, open and unmerged. The implementation revision and pending protected runtime are preserved separately from this evidence-only commit. The pending native run is not canceled or replaced, and no redundant protected runtime is requested. Source CI may run for the documentation commit; its result is not substituted for the cited executed implementation tests.

Complete requested acceptance remains incomplete: native zero-difference failures require the actual corrected 240-case rerun; isolated hosted staging requires the separate missing target/configuration. Production release, V2 activation, customer migration and destructive cleanup still require the owner's separate approval.
