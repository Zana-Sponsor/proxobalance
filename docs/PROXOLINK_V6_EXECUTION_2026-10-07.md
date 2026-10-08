# ProxoLink V6 executed verification — 2026-10-07

CURRENT Android runtime status is **BLOCKED**, checked 2026-10-08. Fresh protected [run 37759310377](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37759310377), current attempt 2, revision `c06bd3dccf9b0ea124447a2fc2ff4a47a6e096f1`, runtime job `113255054733`, is waiting for authorized `Zana-Sponsor` approval in the existing `proxolink-preview-verification` environment. The user explicitly authorized this new execution after the authentication renewal fix, overriding the previous no-new-run restriction. The gate is unchanged and was not approved or bypassed by this continuation.

The trigger-only commit changes zero files and has the same Git tree `0114f0870256e18069ec4a6325463da95166b54f` as passing parent `ce561f6bbc688680e37c1bc03b92e202478d068b`. Authentication fix `edcaa048289c9b5a4ee5e1e97f71035ca0731a91` is included. [Exact-revision source CI 37759310220](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37759310220) succeeded: backend 124, Flutter 189, responsive/browser 480, database/RLS and seven API lifecycles, edge functions and release APK privacy; all five jobs passed.

| CURRENT execution | Exact checkpoint |
|---|---|
| Expected native cases | 240: four designs × three page types × ku/en × portrait/landscape × widths 320/375/393/430/768 |
| Native behavior | 0 executed / 0 passed / 0 failed; all 240 pending |
| Candidate / baseline first captures | 0 / 0; all 240 per role pending, 480 required first captures not yet captured |
| Strict same-emulator pixels | 0 pairs executed / 0 exact / 0 failed; all 240 pending; parity UNEXECUTED |
| Fixed capture repeatability | 0 roles executed; all 480 pending, three predetermined exact samples required for every role |
| Authentication result | UNEXECUTED; the earlier catalog HTTP 401 cannot yet be assessed in this corrected native run |
| Runtime artifact | None: attempt 1 stopped before emulator startup; attempt 2 awaits approval |
| APK artifact | 11542240080; credential-free APK success is not native verification |
| Native thumbnail → large WebView selection | NOT VERIFIED: 0 chooser cases; direct production ProxoLinkPreview probe |
| PR #7 | Draft / open / unmerged |

Attempt 1 received authorized approval from `Zana-Sponsor` and its APK job `113251558088` succeeded. Runtime job `113253360666` then failed at **Enable KVM for the disposable emulator**, 2026-10-08 09:55:23 UTC, exit 1. The Android/WebView action was SKIPPED: no emulator, native case, authentication request, capture or pixel comparison executed. The always-run evidence upload subsequently found no runtime directory. The underlying KVM-readiness cause is **not proven**; no udev race, permission cause or product defect is asserted. [Safe infrastructure diagnosis](evidence/proxolink-v6-2026-10-06/native-c06bd3d-attempt1-infrastructure.json).

Only that infrastructure-failed job was retried once in the SAME run, with no source/workflow/protection/acceptance edits. The successful APK is carried as job `113255053774` without rebuilding. Current attempt 2 job `113255054733` awaits a new authorized environment review. The existing follow-up remains enabled while approval is pending and will inspect actual terminal logs/evidence. No additional native run or further blind retry is created.

Acceptance remains all 240 Android cases, complete candidate/baseline evidence, native paint barriers, three exact repeat samples per role and **ZERO missing cases, ZERO missing captures, ZERO unstable captures and ZERO changed pixels**. FIRST candidate and FIRST baseline remain the comparison inputs. No masks, tolerances, averaging, frame matching, adaptive pixel retry, missing-case allowance or Chromium/APK/widget substitution. The previous nine pixel differences are not claimed fixed; a new complete run must report every actual difference with coordinates and channel values.

This continuation changes only the eight report/evidence files listed in the evidence manifest. The implementation, authentication source fix, thumbnails, four prepared designs, large live WebView, workflow and protected environment remain unchanged. No merge, production publishing, customer data changes, migrations or destructive cleanup.

**Historical audit before this explicitly authorized execution**

The following retained audit describes prior revisions/runs. Its 218/209/9 counts and source CI checkpoints are historical; they are not the current run's results.

HISTORICAL Android runtime status is **FAILED**, inspected 2026-10-08: protected run `37694585964`, attempt 3, revision `5bf533b11b7f638acc65395b65da1512e3275f5f`, runtime job `113055174154`, completed 2026-10-07 at 23:51:24 UTC after authorized approval. Expected 240; 218 behavior cases executed/passed, 0 failed, 22 not reached. Candidate 218, baseline 218, missing 44 first captures (22 per role). Strict same-emulator pixels: 209 exact / 9 failed among 218 pairs, 10 changed pixels total; 22 pairs unexecuted. All 436 captured roles have three exact samples. Final collection stopped at template_catalog / verification_endpoint_unavailable / HTTP 401. The runner authentication correction passed 124 local/backend tests and all five source CI jobs but has not run natively; pixel cause remains unknown. PR #7 remains Draft/open/unmerged.

[Passing authentication-fix source CI](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37709592066) · [Passing documentation-head CI](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37698544299) · [HISTORICAL failed protected run](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37694585964) · [HISTORICAL capture inventory](evidence/proxolink-v6-2026-10-06/native-5bf533b-attempt3/evidence-inventory.json) · [Exact authentication correction files](evidence/proxolink-v6-2026-10-06/native-auth-correction-files.json).

**Requirement results**

VERIFIED means an executed check supports the stated scope. FAILED means an executed acceptance check failed. BLOCKED means the required execution has not completed or has no isolated target. Compilation, an APK build, a Chromium capture and source tests are not Android runtime certification.

| Requirement | Status | Executed evidence and limits |
|---|---|---|
| Backend/API | VERIFIED | 124 passed, 0 failed in authentication-fix source CI 37709592066 at edcaa048. Pinned Android source 5bf533b had 121; earlier 1dca41a had 120. Source CI is not native certification. |
| Database/RLS | VERIFIED | Disposable PostgreSQL 17.11: migration rollback and rerun, direct RLS assertions and 7 database-backed API lifecycles. No production DDL. |
| Database PAGE UUID differs from auth/owner/request UUID | VERIFIED | Actual database generation, multiple pages per owner, immutable IDs, cross-owner denial and edit/retry URL stability executed in the database/API tests. |
| Contact create/edit/preview/public rendering | VERIFIED | Backend and database execution, Flutter flows and browser renderer matrix. Hosted isolated staging is separately BLOCKED. |
| Restaurant create/edit/preview/public rendering | VERIFIED | Talabat-only, Toters-only and combined API lifecycles plus database/Flutter/browser checks. Hosted staging is BLOCKED. |
| App Download create/edit/preview/public rendering | VERIFIED | Google Play-only, App Store-only and combined API lifecycles plus database/Flutter/browser checks. Hosted staging is BLOCKED. |
| Wrong route/type rejection | VERIFIED | Typed public and avatar route guards, immutable page type and preview type/capability binding executed. |
| Malformed provider/store URLs | VERIFIED | Canonical provider allowlists and malformed/scheme/host/query injection cases executed. Viber regression also executed. |
| Flutter tests | VERIFIED | 189 passed in authentication-fix source CI 37709592066 at edcaa048; release APK privacy passed. Pinned native APK also compiled in protected attempt 2. Compilation is not Android runtime certification. |
| Flutter analysis | VERIFIED | Existing explicit 10-item analysis: 27 informational findings, 0 warnings/errors; corrected integration_test analysis: 4 informational findings, 0 warnings/errors. This is not a claim of full-repository analysis. |
| RTL/LTR, long text, overflow and requested widths | VERIFIED | 480 actual renderer/Chromium cases covering widths 320, 375, 393, 430 and 768; all 3 types, 4 designs, Kurdish/English, both orientations, normal/long text and 1.6 text scale. |
| Same prepared top layout across all types | VERIFIED | Actual browser matrix and same CSS blocks retained in all four prepared designs. Type labels/actions vary; design identity is preserved. |
| Four original designs in all three page types | VERIFIED | The existing four keys only; same-environment Chromium baseline comparisons passed. Source CSS comparison was also executed at this revision. Android parity is separately FAILED. |
| Flutter widget thumbnail selector and immediate full live preview updates | VERIFIED (widget scope) | 12 real rendered thumbnail assets decoded; 24 selector width/direction cases, all four card taps/semantics/equal heights, and 3 current-draft live-preview flows executed. Large preview still uses the server-rendered WebView. |
| Live native Flutter WebView behavior matrix | PARTIAL | HISTORICAL 218 executed/passed, 0 behavior failures; contact 80, order 78, download 60; pill/pill-mint/pill-dark 60 each, pill-white 38. Remaining 22 required cases were not reached. RTL/LTR/provider/overflow/safe navigation checks passed only for executed cases. |
| Full Android acceptance | FAILED | Approved protected run 37694585964 attempt 3 actually executed. Catalog refresh HTTP 401 stopped at 218/240 cases; 44 required first captures missing and nine strict pair comparisons failed. APK success is not native certification. |
| Native thumbnail → large WebView selection | NOT VERIFIED | 0 native chooser cases: the pinned probe directly renders ProxoLinkPreview and does not tap ProxoLinkDesignSelector. Widget taps are not native chooser evidence. |
| Exact Android baseline/candidate pixels | FAILED | HISTORICAL 209 exact / 9 failed among 218 first-frame pairs; 10 changed pixels total, max channel error 1; 22 pairs unexecuted. All 436 role captures have three exact samples; zero changed pixels for all 240 pairs remains mandatory. |
| Live auth/RLS/private-template and response-header boundaries | PASSED preflight; FAILED later authenticated refresh | Six read-only security checks and 4/4 rendered-preview header checks passed before collection. A later authenticated catalog refresh returned HTTP 401 and stopped execution. |
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

**HISTORICAL Android result — run 37694585964 attempt 3**

The authorized environment review cleared for runtime job `113055174154`. KVM succeeded and the actual production ProxoLinkPreview Android WebView executed against the same Android 35 emulator / WebView / DPR 1 baseline and candidate. The successful verification APK was reused from attempt 2 (carried job `113055173167`). Workflow completion was FAILURE at 2026-10-07 23:51:24 UTC. No replacement run, cancellation, environment approval or protection change was performed in this continuation.

[Artifact 11518923127](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37694585964/artifacts/11518923127) was downloaded and its SHA-256 verified: `a487b5c46c245b24a64220bb5374bb35da135d143f8d46d06f9994fffdbcafbd`. It contains 1,967 files (1,962 PNGs + 5 allowlisted JSONs), 133,234,352 bytes; expires 2026-10-14 23:51:16 UTC. All PNGs and ZIP CRCs are valid. All 218 first-frame comparisons, diff masks and 872 saved repeat-crop comparisons were independently recomputed without tolerance. Only safe JSON/inventories, sanitized capture IDs/timestamps and the nine failed candidate/baseline/diff crop triples are retained.

| Required native evidence | Expected | Present/passed | Missing/failed |
|---|---:|---:|---:|
| Behavior cases | 240 | 218 passed | 0 failed; 22 unexecuted |
| Candidate full captures | 240 | 218 | 22 missing |
| Same-emulator baseline full captures | 240 | 218 | 22 missing |
| Candidate crops / baseline crops / diff files | 240 each | 218 each | 22 missing each |
| Case metadata / pixel entries | 240 each | 218 each | 22 missing each |
| Fixed capture roles, 3 exact samples each | 480 | 436 stable | 0 unstable; 44 unexecuted |
| Required PNG evidence files | 2,160 | 1,962 valid | 198 missing |
| First candidate / first baseline pixel pairs | 240 | 209 exact | 9 failed; 22 unexecuted |
| Native thumbnail chooser taps | Separate coverage | 0 executed | NOT VERIFIED |

Coverage reached contact 80/order 78/download 60; pill/pill-mint/pill-dark 60 each, pill-white 38; Kurdish/RTL 110 and English/LTR 108; portrait 110/landscape 108; widths 320/375/393 have 44 cases each, 430/768 have 43 each. All 218 executed behavior cases passed provider/font/image/icon readiness, overflow, inert/safe navigation and native_paint_barriers. These partial results do not verify the full matrix. Missing IDs are `pill-white-order-en-landscape-430`, `pill-white-order-en-landscape-768` and all 20 `pill-white-download` cases (ku/en × portrait/landscape × widths 320/375/393/430/768). [Exact expected/actual case and filename inventory](evidence/proxolink-v6-2026-10-06/native-5bf533b-attempt3/evidence-inventory.json) identifies every missing file; no half-captured case exists.

The actual terminal error is `template_catalog / verification_endpoint_unavailable`, HTTP 401 at 2026-10-07 23:51:09 UTC. It occurred during configuration refresh, before the final evidence validator. The absent success-only results.json is a consequence of that abort. The [strict validator replay](evidence/proxolink-v6-2026-10-06/native-5bf533b-attempt3/validator-replay.json) correctly rejects the 218-case partial set as incomplete; this replay is not falsely reported as the workflow's actual terminal stage.

The pinned runner signs in only when authorization is empty. It refreshes preview capabilities every three minutes but ignores the initial app access token's expires_in/expires_at. This is a demonstrated authentication-lifecycle bug. Its approximately one-hour failure timing is consistent with expiry; the retained artifact does not contain JWT expiry or backend auth diagnostics, so expiry is an inference, not direct proof of the underlying HTTP 401. The smallest correction renews the same ordinary app session at existing configure boundaries before the returned expiry, with five-minute headroom. It keeps only bearer/UUID in runner memory, rejects an account change or invalid/expired sign-in metadata, and fails closed. No permissions, token lifetime, account configuration, customer data, product widget, template or protection setting is changed. Three regression tests simulate a long run, earlier absolute expiry, changed user, invalid metadata and renewal failure. Local validation: 124 Node tests passed, 0 failed; source privacy, JavaScript syntax and whitespace checks passed. Authentication-fix source CI 37709592066 at edcaa048 succeeded: backend 124, Flutter 189, responsive 480, database/RLS and 7 API lifecycles, edge functions and release APK privacy. Its ordinary push APK workflow completed with native-runtime SKIPPED; no new protected runtime executed. [Exact three correction files/hashes](evidence/proxolink-v6-2026-10-06/native-auth-correction-files.json).

Strict parity independently remains FAILED: 209 exact / 9 failed first-frame pairs, 10 changed pixels total, maximum channel error 1. All 436 captured roles have exactly three identical samples, and pixels.capture_stable=true; none of the 872 repeat comparisons differs. The native draw correction established stable role captures but did not eliminate pair differences. [Diagnosis with all nine case IDs, coordinates and RGB values](evidence/proxolink-v6-2026-10-06/native-5bf533b-attempt3/diagnosis.json) preserves the evidence. The exact cause of those differences is unknown; the auth correction is not a pixel remedy, and no speculative product/style change is made. First frames, zero tolerance, all 240 pairs and complete required evidence remain mandatory.

No additional protected native run or same-run retry was created. The current instruction expressly prohibits a new native run, and rerunning the pinned 5bf533b revision cannot execute the authentication correction. A new authorized action to run the corrected revision through the existing protected workflow is required to establish complete native evidence; nine pixel differences and zero native chooser taps also remain unresolved. Android status stays FAILED.

**HISTORICAL complete Android run and draw correction — 1dca41a**

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

Validation after this correction: 121 local Node tests passed, 0 failed; source-privacy scan, JavaScript syntax and diff whitespace checks passed. Corrected source CI 37694585981 completed successfully at 5bf533b: backend 121, Flutter 189, renderer/browser responsive 480, database/RLS and 7 API lifecycles, edge functions and release APK privacy passed. Corrected native probe analysis and debug APK compilation also succeeded in protected workflow attempt 2. New regression coverage rejects a one-channel one-pixel drift and rejects missing barriers, unstable captures or fewer than three samples. That source-validation checkpoint preceded the corrected Android execution; HISTORICAL attempt 3 results are recorded above.

The original failed run and workflow are preserved. The correction reuses `.github/workflows/proxolink-native-build.yml` with environment `proxolink-preview-verification` and required reviewer `Zana-Sponsor`; the workflow and protection are unchanged. The corrected attempt 3 subsequently received authorized environment approval and executed; the requirement remains unchanged. No protected job is approved or bypassed by this continuation.

Historical infrastructure for the same corrected run: attempt 1 stopped before compilation because the NDK download was not a ZIP. The same-run failed-job retry recovered; attempt 2 APK job `113044672963` succeeded. Approved runtime job `113046619691` then failed at KVM on 2026-10-07 22:40:29 UTC, before emulator startup, with 0 native cases/captures/pixel pairs. Evidence upload found no runtime directory. [Safe infrastructure diagnosis](evidence/proxolink-v6-2026-10-06/native-5bf533b-attempt2-infrastructure.json) retains the exact failure and uncertainty; no udev/product cause is proven. Only the failed runtime job was retried at the unchanged source revision. Attempt 3 cleared authorized approval, succeeded at KVM and reached 218 native case pairs before the separate catalog HTTP 401 failure reported above. The attempt 2 zero counts and former approval wait are historical, not HISTORICAL counts. No workflow or protection was edited for that retry.

Native thumbnail-selection coverage remains unexecuted (0 cases). The production preview widget is tested directly, without tapping ProxoLinkDesignSelector. The 240-case matrix and widget tests do not certify thumbnail → selected large WebView navigation. Actual OS-provider-app launch/fallback, physical-device coverage and the isolated native management lifecycle also remain outside this probe's verified scope.

Historical V6 results remain separate: run 37647222280 at de501a9 passed 240 behavior cases, 0 failed, but only 233 exact pixel pairs / 7 failed; it is FAILED. Its artifact 11501290385 has SHA-256 `9018409f19abf2ec298b413d5f620892b47e52586c8c7522ee93cfcc471575fc`. Older run 37602803930 at 5dbf391 timed out after 169 behavior passes, with 112 exact pairs / 57 failed. Neither result is copied into the HISTORICAL counts.

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

After inspecting run 37694585964 attempt 3, the only verification source changes are `scripts/proxolink-verification-security.mjs`, `scripts/run-proxolink-native.mjs` and `test/proxolink-verification-security.test.js`. [native-auth-correction-files.json](evidence/proxolink-v6-2026-10-06/native-auth-correction-files.json) records exact hashes, scope and local validation. The HISTORICAL execution report, README, native-results.json, ci-results.json, execution-blockers.json, evidence-files.json and allowlisted native-5bf533b-attempt3 evidence are updated. Exact evidence paths/hashes are in [evidence-files.json](evidence/proxolink-v6-2026-10-06/evidence-files.json). The earlier ten draw/capture verification changes remain separately recorded in native-capture-correction-files.json. No production widget, selector, template, thumbnail, migration, workflow, publishing setting or customer record changed.

Last fully executed code source CI: [run 37709592066](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37709592066) at `edcaa048289c9b5a4ee5e1e97f71035ca0731a91`, SUCCESS (backend 124, Flutter 189, responsive 480, database/RLS, 7 API lifecycles, edge functions, release APK privacy; all five jobs). The same three verification source files/hashes are retained by this documentation update. Earlier code CI 37694585981 at 5bf533b and documentation-head CI 37698544299 at 634ad50 passed and remain historical. The ordinary push APK build workflow 37709592144 also succeeded, with native-runtime SKIPPED. The authentication correction has no protected native runtime certification. The exact tested Android revision stays 5bf533b; neither a later report commit nor source CI changes that native result. Source checks for the final documentation head are rechecked in Draft PR #7 separately.

PR #7 remains Draft/open/unmerged. Remaining native blockers are 22 unexecuted cases / 44 missing first captures, nine failed first-frame pairs despite exact role repeatability, authorized protected execution of the authentication correction under the current no-new-run constraint, and 0 native chooser-selection cases. Separate isolated staging requirements remain historical limits outside this continuation. No merge, production publishing/activation, production customer change, migration or destructive cleanup was performed.
