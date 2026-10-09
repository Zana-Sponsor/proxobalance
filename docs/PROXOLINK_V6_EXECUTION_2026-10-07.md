# ProxoLink V6 — current terminal native result

**Android runtime status: FAILED.** Protected [run 37844040950](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37844040950), attempt **2**, pinned revision `6c7e6c634cfe0bceb2c43ceb485aba12cd78417c`, runtime job `113568639222`, executed after authorized review in unchanged `proxolink-preview-verification`. KVM succeeded; final error `native_case_collection / native_pixel_parity_failed`. This was diagnostic instrumentation, not a proven pixel fix.

| Terminal evidence, independently recomputed | Result |
|---|---|
| Expected / executed matrix | 240 / 240 |
| Behavior passed / failed | 240 / 0 |
| First candidate / same-device baseline | 240 / 240; missing cases/captures 0 / 0 |
| Exact / failed first-frame pixel pairs | **232 / 8**; 1,750 changed pixels, maximum channel delta 1 |
| Fixed three-frame repeatability | 480 stable / 0 unstable roles; all 960 saved repeats identical to first crops |
| Native chooser | 12 expected / 12 executed / 12 passed / 0 failed, actual Android builder thumbnail taps |
| Diagnostic completeness | 12 roles, PixelCopy success, WebView 124.0.6367.219, Android 35, DPR 1 |
| Authentication | All 240 complete, previous HTTP 401 did not recur; exact renewal count not retained |
| Artifact | 11586077978; 143,503,499 bytes; SHA-256 `4ae48def82e5a931ed79779ee75a272634d53202370376862734660e50b92ec8` |
| Independent checks | 240 PNG pairs + 240 original crop correspondence + 240 full diff images + 960 repeat crops + 12 targeted surface PNGs + 12 chooser records/tap/capture acknowledgements |

Exact failed IDs: `pill-contact-en-portrait-768` (1,743 pixels), `pill-order-ku-portrait-768`, `pill-mint-contact-ku-portrait-768`, `pill-mint-order-ku-portrait-320`, `pill-mint-order-ku-portrait-430`, `pill-mint-order-ku-portrait-768`, `pill-mint-order-en-portrait-430`, `pill-mint-order-en-portrait-768` (one pixel each).

**Root cause: NOT PROVEN.** Targeted roles have matching CSS/font hashes and viewport bounds. All 12 fixed post-acceptance PixelCopy surface crops exactly match their own first screenshot crops, and failed surface pairs retain the acceptance differences. This provides evidence that the differing colors also occur in the copied surface; it does not isolate GPU/raster, lifecycle or composition as the causal variable. Draw/frame-commit acknowledgements observe submission, not presentation. No speculative product change, tolerance, masking, alternate-frame selection, averaging or pixel retry was applied.

Safe audit files and failed crop/diff images are in `docs/evidence/proxolink-v6-2026-10-06/native-6c7e6c6-attempt2/`. All changed coordinates, RGB values, screen/crop origins and deltas are retained. Prepared templates/assets/CSS/fonts and native acceptance remain unchanged.

## Separate current page-management implementation

The subsequently requested rebuild was published at `dc15bbf84101044f5657d9320526f0c80152ac39`, after this pinned Android revision. Its dedicated list/details/editor flows are wired to the real owner API. [Exact implementation paths and migration safety](PROXOLINK_PAGE_MANAGEMENT_2026-10-08.md). The native 12 chooser passes above certify only the pinned pre-refactor builder binding, **not** the rebuilt management journey. Current source CI 37862457017: backend132, disposable DB/RLS + seven API lifecycles and edge checks passed; Flutter analysis/widget tests passed, final responsive/release APK checks pending at this checkpoint. PR #7 remains Draft/open/unmerged. No merge, production migration/customer writes or publishing.

Remaining blockers: strict native pixel failure with unproven cause, complete final source CI, and hosted isolated/native verification of the new management journey. Implementation is not reported COMPLETE.

---

## Historical dated checkpoint (superseded)

# ProxoLink V6 executed verification — current diagnostic continuation

**CURRENT Android status: BLOCKED — authorized environment approval pending.** Checked 2026-10-08 UTC. Existing protected [run 37844040950](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37844040950), **attempt 2**, revision `6c7e6c634cfe0bceb2c43ceb485aba12cd78417c`, runtime job `113568639222`, is waiting for `Zana-Sponsor` in unchanged `proxolink-preview-verification`. The successful APK is carried as job `113568637796`; it was not rebuilt. Approval has not been supplied or bypassed by the agent.

Attempt 1 runtime job `113542037262` received authorized review but failed at **Enable KVM for the disposable emulator** at **2026-10-08 21:11:17 UTC**. Its shell returned code 1; the logs do not identify which command failed or establish an underlying udev/device/permissions cause. The real Android/WebView step was **SKIPPED**. Always-run upload found no evidence directory. Artifact inventory contains only APK/parts, not a runtime evidence artifact. This provides no evidence about the six pixel mismatches or the newly added chooser.

| Attempt 1 actual execution | Result |
|---|---|
| Expected / executed behavior | 240 / 0 |
| Behavior passed / failed | 0 / 0 (not executed) |
| Candidate / baseline first captures | 0 / 0; all 480 absent because emulator never started |
| Stable / unstable measured roles | 0 / 0; 480 unmeasured |
| Pixel pairs evaluated / exact / failed | 0 / 0 / 0; all 240 unmeasured |
| Authentication / changed pixels / maximum channel error | Not measured |
| Expected / executed chooser | 12 / 0; no passes or failures measured |
| Runtime evidence artifact | None |

One bounded retry of **only the failed infrastructure job in the same native run** created attempt 2; no code, workflow, emulator setting, acceptance, protection or successful APK rebuild changed. Attempt 2 is unstarted at its approval gate: 240 matrix cases and 12 real builder chooser cases remain pending. Do not keep retrying blindly if KVM fails again; diagnose the runner readiness failure with safe observations before another execution.

The instrumentation is **diagnostic-only**. Pixel root cause: **NOT PROVEN**; no production/pixel fix applied. See [diagnostic scope and exact eight changed files](PROXOLINK_NATIVE_DIAGNOSTICS_2026-10-08.md). The original templates, CSS, fonts, 12 PNG thumbnails and production builder/live WebView remain unchanged. Strict first-frame comparison still requires all 240 pairs exact, zero missing/unstable captures, and all 12 actual Android builder thumbnail cases passing.

Source CI [37844040855](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37844040855), **attempt 2**, completed **SUCCESS** at **2026-10-08 21:15:17 UTC**, all five jobs, at native revision `6c7e6c6`. Backend 128, Flutter 189, responsive 480, database/RLS, edge checks and release APK privacy pass. Its attempt 1 NDK non-ZIP download failure was recovered by the bounded failed-source-job retry. Earlier identical-tree source CI 37843257117 also passed. These source/APK results do not certify native runtime.

The latest user authorization permits reasonably necessary evidence-driven diagnose/proven-fix/protected-rerun cycles, superseding old one-run limits. Every new environment review gate must remain intact and be reported with exact run/job/revision. PR #7 remains Draft/open/unmerged. No production publishing/customer mutation/migration/destructive cleanup.

Safe infrastructure record: [native-6c7e6c6-attempt1-infrastructure.json](evidence/proxolink-v6-2026-10-06/native-6c7e6c6-attempt1-infrastructure.json).

---

## Historical completed native checkpoint — 37759310377

The following audited result and its then-current authorization belong to the historical c06bd3d run, not the current diagnostic execution. Its 234/6 pixel result and zero chooser coverage must never be copied as new results.

HISTORICAL Android runtime status is **FAILED**, audited 2026-10-08. Protected [run 37759310377](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37759310377), **attempt 2**, revision `c06bd3dccf9b0ea124447a2fc2ff4a47a6e096f1`, runtime job `113255054733`, completed 2026-10-08 at **11:42:45 UTC**. Authorized `Zana-Sponsor` review cleared in the unchanged `proxolink-preview-verification` environment. KVM succeeded and the actual Android 35 production ProxoLinkPreview WebView ran. The final strict gate failed at `native_case_collection / native_pixel_parity_failed`; this is not incomplete evidence or an APK-only result.

The user explicitly authorized this one fresh execution after authentication fix `edcaa048289c9b5a4ee5e1e97f71035ca0731a91`. Trigger revision c06bd3d changes zero files and retains tree `0114f0870256e18069ec4a6325463da95166b54f`, identical to passing parent ce561f6. Attempt 1 failed before emulator startup at KVM; its underlying runner readiness cause is unknown. One same-run infrastructure retry reused the successful APK (original job `113251558088`, carried job `113255053774`) without rebuilding. No replacement workflow, further native run, cancellation, environment approval or protection bypass was performed.

| HISTORICAL native evidence | Expected | Actual result |
|---|---:|---|
| Behavior cases | 240 | 240 executed / 240 passed / 0 failed; 0 missing |
| FIRST candidate full captures | 240 | 240 present; 0 missing |
| FIRST same-emulator baseline full captures | 240 | 240 present; 0 missing |
| Candidate crops / baseline crops / diffs | 240 each | 240 each; no missing or invalid files |
| Metadata / pixel entries | 240 each | 240 each; all IDs match the expected manifest |
| Required PNG evidence | 2,160 | 2,160 valid; ZIP CRC and all file hashes checked |
| Role repeatability | 480 roles × 3 samples | 480 stable / 0 unstable; 1,440 predetermined screenshots, 960 saved repeats independently exact against each FIRST sample |
| Strict FIRST candidate / FIRST baseline pixels | 240 pairs | **234 exact / 6 failed**, six changed pixels total, max channel delta 1 |
| Full per-case acceptance including pixels | 240 | 234 passed / 6 failed / 0 unexecuted |
| Authentication outcome | Full matrix | All 240 complete; former catalog HTTP 401 did not recur; last JSON status 200. Exact renewal count/expiry diagnostics not retained |
| Native paint/provider/font/image/overflow/navigation checks | Full matrix | Passed all 240 under the pinned probe's checks |
| Native thumbnail → large WebView chooser | Separate native coverage | **NOT VERIFIED: 0 chooser cases**; direct production ProxoLinkPreview probe |
| PR #7 | Draft / open / unmerged | Preserved; no merge or publishing |

Coverage is all four designs (60 each), contact/order/download (80 each), Kurdish/RTL and English/LTR (120 each), portrait/landscape viewport shapes (120 each), widths 320/375/393/430/768 (48 each). The probe checks actual provider lists, font/image/icon readiness, live motion, no horizontal overflow under its existing assertion, inert preview actions, intercepted canonical public destinations and blocked unsafe navigation. It renders the production preview directly, so selector taps, external provider-app launches/fallback and physical-device behavior are outside this execution.

[Artifact 11548551620](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37759310377/artifacts/11548551620): 138,610,344 bytes, 2,165 files (2,160 PNGs + five allowlisted JSONs), SHA-256 **`97192f255e06ea104088f8f7220fd8f7690b983e6fdcf8cb35cb10bf32cf4b79`**, downloaded and verified. Expires 2026-10-15 at 11:42:37 UTC. Every FIRST RGB pair, complete diff image and saved repeat crop was independently recomputed. The byte-identical pinned validator replay also rejects exactly `native_pixel_parity_failed`. Absence of success-only results.json follows this rejection; it is not a missing required capture. [Complete inventory](evidence/proxolink-v6-2026-10-06/native-c06bd3d-attempt2/evidence-inventory.json) · [Independent audit](evidence/proxolink-v6-2026-10-06/native-c06bd3d-attempt2/independent-pixel-audit.json) · [Strict replay](evidence/proxolink-v6-2026-10-06/native-c06bd3d-attempt2/validator-replay.json).

**HISTORICAL exact pixel failures**

Coordinates are zero-based within the saved WebView crop. Every listed pair has one changed pixel and max channel delta 1. Channel deltas are candidate minus baseline.

| Case ID | Changed pixels | Crop (x,y) | Candidate RGB | Baseline RGB | Candidate − baseline RGB |
|---|---:|---|---|---|---|
| `pill-contact-en-portrait-768` | 1 | (380,222) | (215,221,236) | (215,222,236) | (0,-1,0) |
| `pill-order-ku-portrait-768` | 1 | (380,222) | (220,227,240) | (220,226,240) | (0,1,0) |
| `pill-order-en-portrait-768` | 1 | (380,222) | (215,222,236) | (215,221,236) | (0,1,0) |
| `pill-mint-contact-ku-portrait-430` | 1 | (282,184) | (237,247,244) | (237,247,243) | (0,0,1) |
| `pill-mint-order-ku-portrait-430` | 1 | (282,184) | (237,247,244) | (237,247,243) | (0,0,1) |
| `pill-mint-order-en-portrait-768` | 1 | (290,228) | (234,245,241) | (234,246,241) | (0,-1,0) |

The underlying cause of these six differences is **UNKNOWN**. All three samples within each role are identical, yet FIRST candidate and FIRST baseline differ. This establishes stable role captures, not parity or a proven CSS/font/template/compositor defect. The previous nine failures were measured anew; six current failures replace them as current counts. No speculative product/harness fix was made after native testing. Authentication renewal allowed observed full completion without the prior HTTP 401, but specific renewal events/expiry are not retained and it is not a pixel remedy.

Acceptance remains **ZERO missing cases, ZERO missing captures, ZERO unstable captures and ZERO changed pixels**, all 240 native pairs with FIRST frames. No tolerance, masking, averaging, frame search, adaptive pixel retry, missing-case allowance or Chromium/APK/widget replacement. Remaining blockers: the six strict pixel failures with unknown underlying cause and zero native chooser coverage. The one authorized run is terminal; any further protected native execution requires new authorization. PR #7 remains Draft/open/unmerged.

Exact native-revision [source CI 37759310220](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37759310220) is SUCCESS: backend 124, Flutter 189, renderer/browser responsive 480, database/RLS with seven API lifecycles, edge functions and release APK privacy; all five jobs passed. Latest completed pre-publication report CI [37762308917](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37762308917) at `0ab03eb11dd9915f0efe0bc538a60f6d4ea34b3e` is SUCCESS, completed 2026-10-08 10:21:08 UTC. CI triggered by this documentation publication is rechecked and recorded in Draft PR #7; source CI does not override the FAILED Android result.

This terminal continuation changes exactly **37 documentation/evidence files**: seven existing report/index files and 30 new allowlisted files in `native-c06bd3d-attempt2/` (12 JSONs and 18 failed candidate/baseline/diff crops). [Exact changed paths and hashes](evidence/proxolink-v6-2026-10-06/evidence-files.json). No product, authentication source, thumbnail, prepared template, production stylesheet, workflow, protection or acceptance file changed after this native run. Only safe JSON/inventories, sanitized capture IDs/timestamps and failed crop triples are retained; no credentials, capability URLs, private runtime configuration, raw logs or customer data. No merge, production publishing/activation, customer writes, migrations or destructive cleanup.

The retained historical sections below are dated evidence for earlier revisions. Their 218/209/9, 235/5 and 233/7 counts are not current results.

**Requirement results**

VERIFIED means an executed check supports the stated scope. FAILED means an executed acceptance check failed. BLOCKED means the required execution has not completed or has no isolated target. Compilation, an APK build, a Chromium capture and source tests are not Android runtime certification.

| Requirement | Status | Executed evidence and limits |
|---|---|---|
| Backend/API | VERIFIED | 124 passed, 0 failed in HISTORICAL native-revision source CI 37759310220 at c06bd3d. Pinned Android source 5bf533b had 121; earlier 1dca41a had 120. Source CI is not native certification. |
| Database/RLS | VERIFIED | Disposable PostgreSQL 17.11: migration rollback and rerun, direct RLS assertions and 7 database-backed API lifecycles. No production DDL. |
| Database PAGE UUID differs from auth/owner/request UUID | VERIFIED | Actual database generation, multiple pages per owner, immutable IDs, cross-owner denial and edit/retry URL stability executed in the database/API tests. |
| Contact create/edit/preview/public rendering | VERIFIED | Backend and database execution, Flutter flows and browser renderer matrix. Hosted isolated staging is separately BLOCKED. |
| Restaurant create/edit/preview/public rendering | VERIFIED | Talabat-only, Toters-only and combined API lifecycles plus database/Flutter/browser checks. Hosted staging is BLOCKED. |
| App Download create/edit/preview/public rendering | VERIFIED | Google Play-only, App Store-only and combined API lifecycles plus database/Flutter/browser checks. Hosted staging is BLOCKED. |
| Wrong route/type rejection | VERIFIED | Typed public and avatar route guards, immutable page type and preview type/capability binding executed. |
| Malformed provider/store URLs | VERIFIED | Canonical provider allowlists and malformed/scheme/host/query injection cases executed. Viber regression also executed. |
| Flutter tests | VERIFIED | 189 passed in HISTORICAL native-revision source CI 37759310220 at c06bd3d; release APK privacy passed. The pinned native APK compiled in attempt 1 and was carried into protected attempt 2. Compilation is not Android runtime certification. |
| Flutter analysis | VERIFIED | Existing explicit 10-item analysis: 27 informational findings, 0 warnings/errors; corrected integration_test analysis: 4 informational findings, 0 warnings/errors. This is not a claim of full-repository analysis. |
| RTL/LTR, long text, overflow and requested widths | VERIFIED | 480 actual renderer/Chromium cases covering widths 320, 375, 393, 430 and 768; all 3 types, 4 designs, Kurdish/English, both orientations, normal/long text and 1.6 text scale. |
| Same prepared top layout across all types | VERIFIED | Actual browser matrix and same CSS blocks retained in all four prepared designs. Type labels/actions vary; design identity is preserved. |
| Four original designs in all three page types | VERIFIED | The existing four keys only; same-environment Chromium baseline comparisons passed. Source CSS comparison was also executed at this revision. Android parity is separately FAILED. |
| Flutter widget thumbnail selector and immediate full live preview updates | VERIFIED (widget scope) | 12 real rendered thumbnail assets decoded; 24 selector width/direction cases, all four card taps/semantics/equal heights, and 3 current-draft live-preview flows executed. Large preview still uses the server-rendered WebView. |
| Live native Flutter WebView behavior matrix | VERIFIED (behavior scope) | HISTORICAL protected run 37759310377 attempt 2: all 240 executed/passed, 0 failed; 80 per type, 60 per design, RTL/LTR 120 each and all configured viewport shapes/widths. Provider/font/image/overflow/safe navigation assertions passed. Strict pixels are separately FAILED. |
| Full Android acceptance | FAILED | HISTORICAL protected run 37759310377 attempt 2 completed all 240 cases, complete evidence and stable role captures; six strict FIRST-frame pixel pairs fail. APK success is not native certification. |
| Native thumbnail → large WebView selection | NOT VERIFIED | 0 native chooser cases: the pinned probe directly renders ProxoLinkPreview and does not tap ProxoLinkDesignSelector. Widget taps are not native chooser evidence. |
| Exact Android baseline/candidate pixels | FAILED | HISTORICAL 234 exact / 6 failed among all 240 FIRST-frame pairs; six changed pixels total, max channel error 1. All 480 roles have three exact samples; zero changed pixels remains mandatory. |
| Live auth/RLS/private-template and response-header boundaries | VERIFIED (read-only probe scope) | HISTORICAL six security checks and 4/4 rendered-preview header checks passed; all 240 cases completed without the previous catalog HTTP 401. Last JSON response 200; exact renewal events are not retained. |
| Client/release APK template-source privacy | VERIFIED | Source scan, release APK build and APK privacy scan passed in HISTORICAL native-revision source CI 37759310220 at c06bd3d. Catalog contains safe metadata, not reusable HTML/storage paths/checksums. |
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

The existing version 6 prepared templates and `pill-templates-1.4.0` runtime are reused. The retained original baseline is commit `ba03534e73fa18fffbe42d8efbeb2e2661009ce0`. The four candidate CSS blocks were compared with their prepared baseline at 1dca41a and remain byte-for-byte identical. Earlier continuations changed native verification code, tests and debug-only Android support; this terminal continuation changes only documentation and safe evidence. No design set, colors, typography or production stylesheet was replaced.

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

After HISTORICAL run 37759310377 attempt 2, no product or harness source changed and no speculative pixel fix was made. Exactly seven existing documentation/index files changed: this report and evidence README.md, native-results.json, ci-results.json, execution-blockers.json, evidence-files.json and native-auth-correction-files.json. Thirty safe evidence files were added under native-c06bd3d-attempt2/: twelve JSON files (five artifact JSONs and seven derived audits) and eighteen failed crop/diff PNGs. [Exact 37 changed paths and hashes](evidence/proxolink-v6-2026-10-06/evidence-files.json). The prior authentication source correction and ten draw/capture changes remain historical manifests; this publication preserves their source bytes.

HISTORICAL native-revision source CI [37759310220](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37759310220) at c06bd3d is SUCCESS: backend 124, Flutter 189, responsive 480, database/RLS + seven API lifecycles, edge functions and release APK privacy; all five jobs. Completed pre-publication report CI [37762308917](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37762308917) at 0ab03eb also passed all five jobs. Source checks for the terminal documentation publication are rechecked separately in Draft PR #7; they do not alter the pinned native failure.

PR #7 remains Draft/open/unmerged. The HISTORICAL native result is FAILED: 240 behavior passes, complete evidence, 480 stable roles, 234 exact and six failed FIRST-frame pixel pairs. The prior catalog HTTP 401 did not recur; exact renewal events are not retained. Remaining native blockers are six nonzero pairs with an unknown underlying cause and zero native chooser cases. Further protected native execution requires new authorization under the one-run scope. Separate isolated staging requirements remain outside this read-only probe. No merge, production publishing/activation, customer changes, migrations or destructive cleanup.
