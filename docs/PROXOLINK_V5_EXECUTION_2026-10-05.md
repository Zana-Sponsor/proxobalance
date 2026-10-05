# ProxoLink V5 execution and remaining gates — 5 October 2026

PR [#7](https://github.com/Zana-Sponsor/proxobalance/pull/7) remains Draft and unmerged. The authoritative attached V5 prompt, sections 0–144, was read completely. **Integrated acceptance is not complete: Android 0/40 and live staging 0/8.** Under the owner's new, narrowly scoped authorization, only the production `notify-tool-created` retirement replacement was deployed. No ProxoLink feature promotion, customer cutover, database/Storage/Auth write, V2 activation, credential replacement or destructive cleanup occurred.

## Latest authorized execution: Telegram delivery retired

Production `notify-tool-created` is now **v4 ACTIVE**, with JWT verification retained. Its deployed `index.ts` exactly matches the already reviewed HTTP 410 replacement: SHA-256 `acea4f591e33c241722f4ccd82b24719e6d560c9880ec05907861f5510fc5896`. Actual HTTP requests verified authenticated POST **410** with `proxolink_html_delivery_retired`, unauthenticated POST **401**, and OPTIONS **204**. The source reads no request payload, sends no Telegram requests and accesses no database or Storage. Other Edge Function versions and update timestamps were unchanged. [Executed retirement evidence](evidence/proxolink-v5-2026-10-05/retirement-execution.json).

The first deployment attempt failed before activation because v3 retained an obsolete absolute import-map path. Packaging the same replacement with an empty `deno.json` resolved that deployment error; no runtime integration or dependency was added. The new authorization applies only to this function retirement. All feature release, customer migration and legacy cleanup restrictions remain in force.

Fresh saved GitHub controls still show **Required reviewers disabled** and **administrator bypass enabled**, although all four required setting names are present. Automatic approval review rejected changing those controls because authorization covered verification/use of the environment rather than editing its access controls. No control was changed and no live native job was triggered. The exact pending change is to require reviewer `Zana-Sponsor`, disable administrator bypass and save within the existing environment, retaining its exact branch rule and settings. A cropped screenshot could not be captured because the browser screenshot API timed out; the safe DOM observations are recorded in [configuration evidence](evidence/proxolink-v5-2026-10-05/secure-configuration.json).

The native result is **0 executed, 0 passed, 0 failed, 40 BLOCKED**. Each of the eight styles and five widths is listed explicitly in [native results](evidence/proxolink-v5-2026-10-05/native-results.json). No native font, layout, animation, direction or navigation defect can be assessed from an unexecuted suite.

The retirement window kept **21 cards, 27 ads and 16 relationships**, with identical full card-row and relationship hashes, zero orphan/cross-owner references, and zero V2 templates, tracking links and events. The full advertisement-row hash changed during that window. This task made no customer-data writes, and the retirement source cannot access those records; the concurrent advertisement content change is unattributed, so full advertisement-row immutability is not claimed. [Before/after checkpoints](evidence/proxolink-v5-2026-10-05/production-checkpoints.json).

## Continuation: current main integrated and provider access corrected

The draft feature branch now incorporates main commit `db95ae062a38f95280715f5ae8e938196413242a`, preserving the independently released Exchange account-balance work. Git completed this feature-branch merge without textual conflicts. This does not merge PR #7 into main. The combined tree passes **103/103 backend tests**, the Vercel build, JavaScript syntax check and ProxoLink source-privacy scan. It contains **11 top-level API functions**, within the existing 12-function CI limit. Generated build outputs were restored and excluded from the commit. [Safe continuation evidence](evidence/proxolink-v5-2026-10-05/continuation.json).

The earlier [prepared, unsaved settings](evidence/proxolink-v5-2026-10-05/protection-review.jpg) screenshot is historical preparation evidence, not proof of persisted protection. Fresh saved-state observations and the current automatic-review rejection are recorded above. The owner has authorized approval/use of the exact ProxoLink verification job; changing the two environment access controls remains blocked by automatic approval review.

## Executed work and evidence

The existing native runner stopped on its first pixel mismatch, preventing collection of all 40 requested comparisons. `scripts/run-proxolink-native.mjs` now acknowledges and collects subsequent cases after recording a mismatch. The final `validateNativeResults` gate still fails if any pixel differs or required evidence is missing. Security/configuration failures still stop execution. No completed feature was redesigned and no new test harness was added.

| Check | Result and evidence boundary |
| --- | --- |
| Existing backend/security suite | **VERIFIED: 60/60**, freshly executed after the runner fix; [log](evidence/proxolink-v5-2026-10-05/backend-tests.log). Controlled provider fixtures do not certify live staging. |
| Backend build, source scan, function limit | **VERIFIED** on the combined tree: build, syntax and source scan pass; 11 top-level API functions. Earlier pre-merge [build](evidence/proxolink-v5-2026-10-05/build.log) and [source scan](evidence/proxolink-v5-2026-10-05/source-scan.log) remain labeled baseline evidence. Generated build outputs were restored. |
| Current inspected CI at `dfa7c9480c4b14efab18756a689274ee499613c7` | [PR CI](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37255198628) and [push CI](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37255195613) succeeded. Backend, Flutter and Edge jobs passed; Flutter analysis reports 28 informational issues and the 83.2 MB release APK/privacy scan succeeded. Combined-tree local backend verification is 103/103. [CI metadata](evidence/proxolink-v5-2026-10-05/ci-results.json) retains the earlier 60/60 and 96-test baseline separately. |
| Android native runtime | **BLOCKED**, not executed. [Latest native build](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37255195714) succeeded, but `native-runtime` job `111591563746` was **SKIPPED**; artifacts contain APK pieces, no runtime evidence. [All 40 blocked cases](evidence/proxolink-v5-2026-10-05/native-results.json). |
| Live isolated staging | **BLOCKED**, not executed. Only production Zana and unrelated Exchange projects are visible; Zana has no development branches. No isolated target or staging runtime settings are configured in this execution environment. [Explicit 0/8 status](evidence/proxolink-v5-2026-10-05/staging-results.json). |
| Eight prepared V2 refinements | **VERIFIED preparation only**: eight historical source hashes match fresh private metadata; eight generated V2 hashes match the reviewed outputs; seed dry run passes. [Reproduction evidence](evidence/proxolink-v5-2026-10-05/template-reproduction.json). No private source/manifests uploaded to Git or CI artifacts; no V2 registration/activation. |
| Private object access | **VERIFIED: 8/8 anonymous public-object requests returned HTTP 400**; [responses](evidence/proxolink-v5-2026-10-05/private-storage.json). The bucket remains private. |
| Telegram retirement | **VERIFIED for the scoped production function**: v4 deployed, exact replacement source verified, actual POST 410/unauthenticated 401/OPTIONS 204; JWT guard retained. [Execution](evidence/proxolink-v5-2026-10-05/retirement-execution.json) and [audit](evidence/proxolink-v5-2026-10-05/telegram-audit.json). |
| Production preservation | **VERIFIED scope**: this task made no customer-data writes. Both checkpoints contain 21 cards, 27 ads, 16 references, zero orphan/cross-owner references and zero V2 rows/links/events. Full card rows and relationships match. Full ad-row hashes differ during the window; cause is unverified. [Checkpoints and limitation](evidence/proxolink-v5-2026-10-05/production-checkpoints.json). |
| Internal privacy | Internal template/link/event/audit tables retain RLS and deny anon/authenticated CRUD; issuance/summary RPCs remain service-only. **Legacy owner access to `html_content` still exists** and is deferred to separately approved cutover. [Metadata and advisor findings](evidence/proxolink-v5-2026-10-05/provider-security.json). |

## Secure configuration: all four settings present; reviewer protection incomplete

The signed-in GitHub environment page now verifies the four exact names and locations. Only names, types, timestamps and protection controls were inspected; no value was revealed. [Safe configuration evidence](evidence/proxolink-v5-2026-10-05/secure-configuration.json).

| Exact setting | Required location | Current result |
| --- | --- | --- |
| `PROXO_NATIVE_ANON_KEY` | Environment variable in `proxolink-preview-verification` | **VERIFIED: present** |
| `PROXO_NATIVE_TEST_EMAIL` | Environment secret in that environment | **VERIFIED: present** |
| `PROXO_NATIVE_TEST_PASSWORD` | Environment secret in that environment | **VERIFIED: present** |
| `PROXO_NATIVE_VERCEL_BYPASS` | Environment secret in that environment | **VERIFIED: present** |

**FAILED protection check:** Selected branches and tags restrict the environment to `feat/proxolink-private-renderer-migration`, but Required reviewers is **unchecked**, no reviewer approval is required, and Allow administrators to bypass configured protection rules is **checked**. The authoritative V5 section 144 requires: "require appropriate reviewer approval and audit the exact job/ref before releasing credentials." The current procedure cannot safely release the test credentials until those controls are corrected. Presence does not establish account/key validity; the existing runtime configuration/security checks will establish validity after authorized release.

**VERIFIED connector and dashboard access from the preceding inspection:** lookup by stable project ID `prj_TCDpM3JNJAZNREZAVyxBLfiZGFxq` succeeds under team `team_8HiDsaKfcCegaE9FgXwmVrUJ`; the name-based 404 does not establish a broken connection. Non-decrypted metadata verifies all six server-variable names with Preview and Production targets. The service-role, preview-signing and analytics-hash secrets have type `sensitive`; the URL, public-base URL and TikTok ID have type `encrypted`. No credential value was decrypted or disclosed. Runtime validity remains untested. The inspected feature deployment `dpl_2hbtGYf7EesDnwDNXS9De44q87Kc` at `8a900ee` was READY. The earlier observed production deployment `dpl_9N9Vnr9YPS1U4uWaDf4mnnsBTWAc` contained main `db95ae0` for independent Exchange work; main has since advanced independently. This task made no Vercel production deployment. Timestamped scope is recorded in the safe configuration evidence. Protected app execution remains blocked; the protected-fetch capability returned 403 and was not retried.

Vercel Activity records removal of a Protection Automation Bypass secret and addition of a replacement labeled `proxolink-preview-verification`. The protected environment bypass entry was updated at `2026-10-04T22:44:23Z`. This is **verified retirement/replacement metadata**, without revealing either capability. Correspondence of the GitHub value to the active replacement and actual runtime validity remain untested. The anonymous Preview request returns **302**, before application authentication; [response](evidence/proxolink-v5-2026-10-05/preview-access.json). No protection bypass was used, and no native job was triggered while reviewer protection is incomplete. Bypass possession must not replace app authentication, card ownership, RLS or private-template permissions.

## Verified scoped Telegram retirement in the deployed system

Feature-branch ProxoLink has no Telegram inputs, buttons, selectors, demo destinations, notification calls or Telegram delivery package. Archived `tg`/`telegram` customer fields are intentionally retained and excluded from rendered/actionable contacts.

Before the owner's new production-retirement authorization, deployed `notify-tool-created` **v3 ACTIVE** retained Telegram document-delivery code. That old version was not invoked. The narrowly scoped authorized replacement is now **v4 ACTIVE**, and fetched provider source exactly matches the checked no-delivery replacement. Actual HTTP verification confirms the retirement response; no Telegram messages or documents were sent. [Audit](evidence/proxolink-v5-2026-10-05/telegram-audit.json).

The already committed replacement in `proxo_app/supabase/functions/notify-tool-created/index.ts` returns **HTTP 410**, never parses or forwards legacy payloads and needs no Telegram credential. Its Deno checks passed in CI, including the current combined feature tree. The owner explicitly authorized deploying only this replacement with JWT verification retained, and that action is complete. No bot, token, notification path or replacement integration was created. Historical customer/platform data and the unrelated non-ProxoLink order-notification workflow were preserved. Runtime template/selector and external-contact acceptance remain independently BLOCKED until the native/staging suites execute.

## Eight direct visual comparisons

These are **retained Chromium 393 px V1/V2 comparisons from `121be74`**, inspected here and tied to freshly reproduced V2 hashes. They are not Android comparisons, fresh remote renders or certification of native fonts/animations. Approved typography/wrapping/spacing/press differences remain distinct from unintended regressions.

| Template | Existing comparison | Actual Android cases executed | Native acceptance |
| --- | --- | --- | --- |
| Dark | [dark-before-after.webp](evidence/proxolink-v5-browser/dark-before-after.webp) | 0/5 | **BLOCKED** |
| Light | [light-before-after.webp](evidence/proxolink-v5-browser/light-before-after.webp) | 0/5 | **BLOCKED** |
| Classic | [classic-before-after.webp](evidence/proxolink-v5-browser/classic-before-after.webp) | 0/5 | **BLOCKED** |
| Pill | [pill-before-after.webp](evidence/proxolink-v5-browser/pill-before-after.webp) | 0/5 | **BLOCKED** |
| Card | [card-before-after.webp](evidence/proxolink-v5-browser/card-before-after.webp) | 0/5 | **BLOCKED** |
| Neon | [neon-before-after.webp](evidence/proxolink-v5-browser/neon-before-after.webp) | 0/5 | **BLOCKED** |
| Zoom | [zoom-before-after.webp](evidence/proxolink-v5-browser/zoom-before-after.webp) | 0/5 | **BLOCKED** |
| Banner | [banner-before-after.webp](evidence/proxolink-v5-browser/banner-before-after.webp) | 0/5 | **BLOCKED** |

Widths remain 320/375/393/430/768 CSS px. There is no executed native-comparison artifact to link. The status file above records that absence explicitly. The same applies to live staging; controlled provider tests are not substituted for real workflow results.

## Exact remaining actions

1. **GitHub reviewer protection:** in [the configured environment](https://github.com/Zana-Sponsor/proxobalance/settings/environments/23442858482/edit), enable Required reviewers, add the owner/trusted reviewer, disable Allow administrators to bypass configured protection rules and save. Keep the existing exact feature-branch rule and all four settings. No setting is missing. The authoritative V5 section 144 and [existing setup](PROXOLINK_PREVIEW_VERIFICATION_SETUP.md#2-create-the-protected-github-testing-environment) require reviewer authorization; this is the immediate native gate.
2. **Vercel access:** use the verified stable project ID and owning team. No plugin reconnection or server-variable replacement is required by the current evidence. Protected application execution still requires the authorized native job and an independently validated temporary bypass.
3. **Replacement bypass:** retirement and replacement metadata are observed. Keep the capability masked and deployment protection enabled. The owner should ensure the existing protected GitHub bypass entry contains that replacement directly in provider settings; no new credential should be sent here. Automation bypasses remain project-wide until revoked; fixed-origin requests and protected workflow/ref/reviewer gates constrain usage. Revoke the temporary capability after the authorized run.
4. **Run the existing native workflow:** once reviewer protection is verified, request the reviewed feature-branch workflow through its existing explicit live-verification trigger. Approve only its exact `native-runtime` job/ref/SHA. Collect all 40 comparisons; a pixel difference must remain FAILED, never tolerated or described as parity.
5. **Isolated staging:** configure a separate Supabase project and separate `proxolink-staging[-suffix]` Vercel project with synthetic accounts/data. Supply protected `PROXO_STAGING_PROJECT_REF`, `PROXO_STAGING_SUPABASE_URL`, `PROXO_STAGING_BASE_URL`, `PROXO_STAGING_ANON_KEY`, `PROXO_STAGING_TEST_EMAIL`, `PROXO_STAGING_TEST_PASSWORD` and an optional temporary `PROXO_STAGING_VERCEL_BYPASS`. Keep staging server credentials separate from production/Exchange. Privately seed and activate V2 only there, then run `node scripts/run-proxolink-staging.mjs`. [Exact setup](PROXOLINK_ISOLATED_STAGING_SETUP.md). The existing runner covers create/failure/idempotency/avatar/retry/public/same-UUID edits/deactivate/owner-preview/reactivate; it excludes OS Copy/Share, native rendering, external app launches and exact-ad live analytics, which still require actual staging/device checks.
6. **Historical credential remediation:** the scoped live Telegram retirement is complete. Historical compromised-token revocation remains an unverified owner security action, not a request for any replacement ProxoLink bot. Preserve historical customer/platform data.

The owner's production-deployment exception permitted only the now-completed retirement replacement. Customer migration, main merge, ProxoLink production promotion, V2 production activation and destructive cleanup remain separate later decisions. No feature release approval is requested while native/staging acceptance is incomplete.

## Scope, migrations and rollback

The earlier ProxoLink executable change was limited to `scripts/run-proxolink-native.mjs`. The continuation imported existing main changes into the draft feature branch. The latest follow-up changes only evidence/documentation in the repository and deploys the existing retirement source to its explicitly authorized Supabase function. Existing Flutter UI and eight template identities were not rewritten. Imported Exchange SQL files were not executed by this task.

The executable collector fix and initial evidence are committed in [`ff7e63a`](https://github.com/Zana-Sponsor/proxobalance/commit/ff7e63abd41071f3630f1098c566d03003f27a33). All three baseline CI runs passed; [CI metadata](evidence/proxolink-v5-2026-10-05/ci-results.json) preserves the 60 backend and 96 Flutter-test baseline and adds the successful combined-tree runs at `dfa7c94`. The combined tree passes 103 local backend tests; actual Android runtime remains skipped.

Fresh registry inspection confirms earlier ProxoLink migrations: `20261003202251` private staging, `20261003212627` production integrity, `20261004005907` legacy versions, `20261004005953` indexes, `20261004010739` migration manifest and `20261004013754` hidden analytics. **No migration was applied in this pass.** All 21 customer rows remain legacy/precutover, `active` + `creating`; final HTML/client-privilege cleanup, readiness backfill, existing-ad token issuance and V2 activation remain unapplied. Retention job metadata is active; its real execution is unverified. Project-wide advisor warnings remain unresolved; the [safe metadata file](evidence/proxolink-v5-2026-10-05/provider-security.json) includes their official remediation links.

Feature rollback remains a feature-branch revert of the native collection change. No customer/database rollback is needed because this task made no customer-data writes. Do not restore the retired Telegram delivery source without separate explicit owner authorization. Keep original pinned templates, legacy fields and secured backups.

## Requirement matrix — all sections 0–144

C = passed backend/security tests and source/build checks, limited to code/controlled provider fixtures, including 103 combined-tree local tests. F = successful Flutter/Edge CI at `dfa7c94`; application/retirement files unchanged from the verified baseline. D = fresh read-only Supabase metadata/checkpoints. T = authorized production retirement deployment, fetched-source verification and actual HTTP requests. P = eight anonymous private-object denials from the earlier pass. L = retained historical Chromium evidence, with V2 hashes reproduced; no new browser/native run. N = actual native/device gate. S = actual isolated staging gate. V = untested protected Vercel application runtime; dashboard metadata is accessible. O = separate production/credential gate. A VERIFIED row is limited to its stated evidence environment and does not certify the deployed product.

| Section | Requirement | Status | Evidence / remaining gate |
| --- | --- | --- | --- |
| 0 | Historical Baseline — Re-Verify Live State Before Implementing | **BLOCKED** | Fresh PR/CI, production baseline, Vercel dashboard and four protected setting presences inspected. Native/staging and protected application execution remain unverified; reviewer protection is incomplete. |
| 1 | Main Product Goal | **BLOCKED** | S/N/V: complete ordinary-customer journey requires integrated staging and device proof. |
| 2 | Important Technical Truth About Source Privacy | **VERIFIED** | C/APK: reusable source is server-only in the feature build; final browser markup remains inspectable. |
| 3 | Required Architecture | **BLOCKED** | V/S: architecture is implemented/tested in code; deployed integration remains unverified. |
| 4 | Private Template Storage | **VERIFIED** | D/P: private bucket flag; all eight fresh anonymous public-object requests returned HTTP 400. No source body or private download exposed. |
| 5 | Preserve the Eight Original Design Identities — Allow Only Approved Refinements | **BLOCKED** | L passed; N/S: prepared v2 not registered/activated or certified on native devices. |
| 6 | Template Dependencies | **BLOCKED** | L uses original cached dependencies; V/N: remote dependencies and all relevant webfonts/engines pending. |
| 7 | Template Metadata Table | **VERIFIED** | D/C: private versioned metadata exists; catalog exposes safe labels/choices and signed demos only. |
| 8 | Card Table Migration | **BLOCKED** | O: legacy customer cutover and final column/client privilege transition remain unapplied. |
| 9 | Status Model | **BLOCKED** | C/F gates pass; S/V: real Active/Inactive/Failed/Creating public transitions pending. |
| 10 | Important Clarification About "Link Creation Failure" | **VERIFIED** | C: render/readiness errors produce recoverable failure; no per-customer deployment required. |
| 11 | Do Not Store public_url as the Source of Truth | **VERIFIED** | C/F: stable UUID-derived public path; stored URL is not authoritative. |
| 12 | Creation Flow | **BLOCKED** | C idempotency passes; S: ordinary-user write/create/public readiness proof pending. |
| 13 | Structured Data Only | **VERIFIED** | C/APK: structured input validation and no client template upload/assembly. |
| 14 | Platform Normalization — historical Telegram examples superseded by owner amendment | **VERIFIED** | C: validated contact destinations, phone normalization and retired Telegram rejection. |
| 15 | Avatar / Profile Image Migration | **BLOCKED** | C avatar handling passes; S/O: current avatar migration/public delivery not independently repeated. |
| 16 | Existing html_content Migration | **BLOCKED** | O: protected backup, approved cutover and later HTML/Base64 cleanup remain separate. |
| 17 | Template Rendering API | **BLOCKED** | C renderer tests pass; V: real protected API and customer pages inaccessible. |
| 18 | Reuse Existing Vercel Security Infrastructure | **VERIFIED** | C: existing verified-bearer security and consolidated handler infrastructure retained. |
| 19 | Authenticated Card Management API | **BLOCKED** | C auth/owner tests pass; V/S: real ordinary-user management API flow pending. |
| 20 | Safe Create / Retry Idempotency | **BLOCKED** | C duplicate-create/retry tests pass; S: stable UUID across actual write/recovery flow pending. |
| 21 | Optional Publish Attempt Audit | **BLOCKED** | D audit table/C handling present; S: real publish-attempt lifecycle not exercised. |
| 22 | RLS | **BLOCKED** | D internal denial verified; O: legacy card owner CRUD/raw-column privilege restriction deferred. |
| 23 | Private Storage Policies | **BLOCKED** | P anonymous denial verified; V/N: current ordinary authenticated Storage request proof pending. |
| 24 | Public Template Source Protection Acceptance Test | **BLOCKED** | C/F/P feature build and private bucket checks pass. T: legacy HTML-delivery function now returns 410. O: owner-readable legacy html_content remains; full source-privacy acceptance is incomplete. |
| 25 | Remove / Replace Flutter Template Generator | **VERIFIED** | Source/APK scan: template generator and reusable template assets absent from the feature build. |
| 26 | Remove Old Local HTML Preview | **VERIFIED** | Source scan/F: local HTML assembly replaced by signed URL WebView requests. |
| 27 | WebView Preview — Must Match Chrome | **BLOCKED** | N: real Android/iOS WebView-versus-Chrome comparison not executed. |
| 28 | Preview Tracking Safety | **BLOCKED** | C demo/owner analytics suppression passes; N/V: actual platform preview zero-event proof pending. |
| 29 | WebView Navigation Behavior | **BLOCKED** | C navigation restrictions present; N: platform denial and external launch/fallback untested. |
| 30 | Card List UI — Unify with Create Ad and Ad Details | **VERIFIED** | F/source: shared Ad UI components and responsive card-list tests pass at ff7e63a; actual native UI acceptance remains separately blocked. |
| 31 | Active Card Actions | **BLOCKED** | F model/UI gating present; S/N: active Preview/Copy/Share/Edit/Use for Ad integrated flow pending. |
| 32 | Inactive Card Actions | **BLOCKED** | C/F inactive gates present; S/N: real inactive owner preview/activation/actions pending. |
| 33 | Failed Card Actions | **BLOCKED** | C/F failure/retry gates present; S: full real failed-card recovery/actions pending. |
| 34 | Creating State UI | **BLOCKED** | F states present; S/N: real slow/uncertain creation and complete creating-state UX pending. |
| 35 | Edit Flow | **BLOCKED** | C failed/stale edit tests pass; S: same-UUID actual customer edit flow pending. |
| 36 | Safe Atomic Edit | **BLOCKED** | C render-before-write/conflict tests pass; S: actual database edit atomicity/preservation pending. |
| 37 | Template Change During Edit | **BLOCKED** | C pinned-version recovery fixed; S: real template-switch edit/public result pending. |
| 38 | Activate / Deactivate | **BLOCKED** | C/F status gates pass; S/V: real activation/deactivation/readiness flow pending. |
| 39 | Public Page for Inactive / Failed Cards | **BLOCKED** | C inactive/failed behavior tested; V/S: actual public responses inaccessible. |
| 40 | Retry Flow | **BLOCKED** | C retry/race tests pass; S: actual failed-publication same-UUID recovery pending. |
| 41 | Copy Link | **BLOCKED** | F deterministic link gating present; N/S: actual clipboard/public-page interaction pending. |
| 42 | Share | **BLOCKED** | F share action present; N/S: actual platform sharing flow pending. |
| 43 | Use for Ad | **BLOCKED** | F eligibility gates present; S: actual ad-selection/write integration pending. |
| 44 | Add Database Integrity for pa_ads.asset_id | **BLOCKED** | O: deferred ad-card validation relationship transition waits for approved cutover. |
| 45 | Delete Behavior | **BLOCKED** | C dependency behavior present; S/O: actual dependency-safe delete and protected legacy transition pending. |
| 46 | Retired Telegram Behavior — historical text superseded by owner amendment | **VERIFIED** | Feature source/CI remove Telegram controls, destinations, calls and delivery dependency. T: notify-tool-created v4 source exactly matches the checked no-delivery replacement; actual POST 410, unauthenticated POST 401, OPTIONS 204; JWT verification retained. Historical fields preserved. Native/staging rendering acceptance is separate. |
| 47 | Legacy Credential Remediation — one-time revocation, no replacement for ProxoLink | **BLOCKED** | O: coordinated historical credential revocation remains unverified. No new Telegram bot, replacement token or ProxoLink credential is required. |
| 48 | Flutter Model Update | **VERIFIED** | F/C: structured model, state gates, safe public path and archived-platform filtering tested. |
| 49 | Flutter List Query | **BLOCKED** | C safe owner list implemented; V/O: deployed list and legacy client privilege transition pending. |
| 50 | Template Selector in Flutter — Real Rendered Previews, Not Images | **BLOCKED** | F lazy signed URL widget and L eight styles pass; N/V: actual selector WebViews not certified. |
| 51 | Rabar 021 and Design Consistency | **VERIFIED** | F: inherited Rabar and actual shared Ad UI styles retained; responsive RTL tests pass. |
| 52 | Public Renderer Sanitization | **VERIFIED** | C/L: customer HTML/URLs escaped or rejected; template rendering remains intact. |
| 53 | Template Placeholder Contract | **VERIFIED** | C and private reproduction: eight source checksums match fresh metadata; all eight V2 output hashes match reviewed outputs; seed dry run passes. |
| 54 | Template Versioning | **VERIFIED** | C/private dry run: separate immutable V2 outputs reproduced with inactive/hidden flags; D zero V2 registrations and unchanged pinned customer rows. |
| 55 | Future Automatic Template Management | **VERIFIED** | C: newest eligible catalog revision selected per style without changing restored pending requests. |
| 56 | GitHub Workflow | **VERIFIED** | GitHub: feature PR remains Draft/unmerged; push/PR CI at dfa7c94 passed. Existing runner retains branch/environment gates. |
| 57 | Vercel Routing | **BLOCKED** | Consolidated rewrites retained; V: actual deployed Vercel routes not reached. |
| 58 | Vercel Environment Variables | **BLOCKED** | Stable-ID connector metadata verifies six names, Preview/Production targets and sensitive/encrypted types without decryption. Runtime credential validity remains unverified. |
| 59 | Server Error Handling | **VERIFIED** | C/F: invalid inputs, stalled previews, late responses, stale edits and publish failures handled. |
| 60 | Recommended Error Codes | **VERIFIED** | C: validation/auth/conflict/readiness responses exercised with controlled API fixtures. |
| 61 | Public Link Readiness Check | **BLOCKED** | C render-before-ready passes; S/V: actual publish/public-link readiness pending. |
| 62 | Preview UX | **BLOCKED** | F timeout/retry/state retention passes; N: actual WebView loading/scroll/gesture experience pending. |
| 63 | Preview vs Chrome Acceptance | **BLOCKED** | N: desktop-local pixel equality does not establish Android/iOS preview parity. |
| 64 | Public Contact Button Behavior | **BLOCKED** | C safe destination/fallback construction passes; N: actual external applications untested. |
| 65 | Ads Integration Rules — Strong Per-Ad Isolation | **BLOCKED** | C exact-token isolation passes; S: live same-card/two-ad events and ad editing pending. |
| 66 | Realtime Is Not Required for Basic Card Creation | **VERIFIED** | C/F: create/save result is authoritative; realtime is not required for readiness. |
| 67 | Database Indexes | **VERIFIED** | D: fresh index metadata includes owner/readiness/idempotency, publication, token/current-ad and event link/date/kind indexes. |
| 68 | Constraints | **BLOCKED** | D additive schema present; O: final legacy/cutover constraints and strict privilege transition deferred. |
| 69 | Migration Safety Procedure | **BLOCKED** | O: refreshed protected backup/manifest and separately approved migration procedure required. |
| 70 | Existing Production Data Must Survive | **BLOCKED** | D/T: no customer-data writes by this task; 21 cards, 27 ads, 16 valid references and full card/relationship hashes match. Full ad-row hash changed concurrently; cause unverified. O/S: migration survival and post-cutover designs remain unverified. |
| 71 | Safe Rollout Order | **BLOCKED** | O/N/S/V: current feature verification precedes cutover/merge/production/cleanup approval. |
| 72 | Testing Matrix | **BLOCKED** | C combined-tree local 103/103 and F CI pass. T real retirement HTTP requests pass. Native 0/40 and live staging 0/8; controlled fixtures are not integrated acceptance. |
| 73 | UI Localization | **VERIFIED** | C/F: ku/ar/en labels and signed choices; mixed-direction text preserved in tests. |
| 74 | Design Rules for Status UI | **BLOCKED** | F shared styling present; N/S: all real status/keyboard/system-scale device combinations pending. |
| 75 | Card Row Layout | **VERIFIED** | F: responsive long-RTL row tests passed at ff7e63a; retained widget images are explicitly not native-WebView evidence. |
| 76 | Creation Success UX | **BLOCKED** | F/C success handling present; S: real create-to-ready success UX pending. |
| 77 | Creation Failure UX | **BLOCKED** | F/C retained inputs/retry behavior present; S/N: real create/publish/network-failure UX pending. |
| 78 | Public URL Security | **VERIFIED** | C: strict stable identifier/path validation; no client-supplied public origin trust. |
| 79 | Preview Token Security | **VERIFIED** | C: expiry, token purpose, selected options and tamper/query-override rejection tested. |
| 80 | No Raw Template API | **VERIFIED** | C/source scan: catalog returns no Storage paths/checksums/source body and no raw-template API. |
| 81 | No Client-Side Template Assembly | **VERIFIED** | F/APK scan: no reusable template assembly/source in Flutter feature build. |
| 82 | HTML Minification | **VERIFIED** | C: final document rendering does not treat optional minification/obfuscation as source security. |
| 83 | Content Security Policy | **BLOCKED** | C/L renderer CSP used locally; V: current deployed CSP/header behavior not verified. |
| 84 | Public Page Headers | **BLOCKED** | C/L header code exercised; V: protected/public remote headers not verified. |
| 85 | Flutter Code Cleanup | **VERIFIED** | Source/APK scan: active generator/local preview/static style assets removed; DB cleanup separately blocked. |
| 86 | AdCreateScreen Update | **BLOCKED** | F ad creation/return-state tests pass; S: actual card creation/selection/submission pending. |
| 87 | AdScreen Duplicate Update | **BLOCKED** | F source integration retained; S: actual AdScreen card selection/submission pending. |
| 88 | Deactivation and Existing Ads | **BLOCKED** | C availability validation present; S/O: actual existing-ad deactivation behavior pending. |
| 89 | Database Update Trigger | **BLOCKED** | D touch trigger is earlier schema work; S: runtime edit timestamp/concurrency proof pending. |
| 90 | card_number | **VERIFIED** | D: card_number default is nextval(proxolink_cards_card_number_seq); Flutter/backend leave numbering to the database. Stable UUID controls the permanent URL. |
| 91 | Concurrency | **BLOCKED** | C stale lease/conflict tests pass; S: concurrent real DB create/edit/retry/ad-token operations pending. |
| 92 | Do Not Trust checked_btns as Security | **VERIFIED** | C: server derives allowed contacts; checked_btns is not trusted authorization. |
| 93 | Platform JSON Validation | **VERIFIED** | C: non-string/malformed/oversized platform JSON rejected before writes. |
| 94 | Privacy | **BLOCKED** | C visitor/IP minimization passes; O: legacy raw data/client privilege and migration cleanup deferred. |
| 95 | GitHub Secret Hygiene | **BLOCKED** | Source/APK scans pass; O: historical exposed-key rotation/history remediation is not complete. |
| 96 | Vercel Preview Testing | **BLOCKED** | Dashboard opens the correct project and shows the feature Preview as Ready. Anonymous request returns 302. No bypass used or current deployed app test; required GitHub reviewer protection is incomplete. |
| 97 | Production Deployment | **BLOCKED** | T: only the explicitly authorized notify-tool-created retirement was deployed. O: ProxoLink feature promotion/merge/customer cutover remains unauthorized and unperformed. |
| 98 | Rollback Plan | **VERIFIED** | Handoff: reversible feature revert and separately gated future migration rollback documented. |
| 99 | Completion Report | **VERIFIED** | All 145 statuses, exact 0/40 native results, staging non-execution, successful scoped production retirement, preservation limitations and precise blocked action are recorded. |
| 100 | Final Acceptance Criteria | **BLOCKED** | N/S/V/O: final integrated acceptance and release gates remain incomplete. |
| 101 | Strong Per-Advertisement Tracking Architecture | **BLOCKED** | C exact-ad implementation passes; S/O: actual tracking/customer integration and migration pending. |
| 102 | New Mapping Table: pa_ad_contact_links | **BLOCKED** | D mapping table/RPC present; S/O: actual issued mappings and existing-ad backfill pending. |
| 103 | Why Use a Mapping Table | **BLOCKED** | C/D mapping design present; S: live mapping issuance/replacement/inactive behavior pending. |
| 104 | Tracked Ad URL | **BLOCKED** | C exact token paths pass; V/S: actual tracked ad public URLs pending. |
| 105 | Vercel Route for Tracked Ads | **BLOCKED** | Consolidated /a rewrites retained; V/S: deployed route/events not reached. |
| 106 | Do Not Redirect to a Shared Tracking Context | **BLOCKED** | C exact-ad render avoids shared-context redirects; V/S: actual deployed flow pending. |
| 107 | New Raw Event Table | **VERIFIED** | D: raw event table present, RLS enabled, anon/authenticated effective CRUD denied; zero event rows currently present. |
| 108 | Optional Denormalized ad_id/card_id | **VERIFIED** | C: optional denormalized identity remains derived from validated server-side link context. |
| 109 | Controlled Event Types | **VERIFIED** | C: only controlled event/action kinds accepted; invalid token/action requests record nothing. |
| 110 | Page View Tracking | **BLOCKED** | C event recording passes; S/V: actual exact-ad page-view events not exercised. |
| 111 | Tracked Button URLs | **VERIFIED** | C: tracked buttons/TikTok preserve their exact validated ad token; arbitrary destinations rejected. |
| 112 | Contact Action Flow | **BLOCKED** | C validated action flow passes; S/N: actual recording then external contact action pending. |
| 113 | Example: Same Card, Two Different Ads | **BLOCKED** | C two-ad/shared-card isolation passes; S: live two-ad event fixture proof pending. |
| 114 | Never Use card_id Alone for Ad Analytics | **VERIFIED** | C: same-card, fake-session/IP tests resolve analytics using the exact ad link, never card_id alone. |
| 115 | Keep pa_ads.clicks Separate | **VERIFIED** | C: contact events remain separate from pa_ads platform-click counters. |
| 116 | Hidden Analytics Requirement | **VERIFIED** | F/C/D: no Flutter analytics dashboard or client internal-table access introduced. |
| 117 | RLS and Direct Access | **VERIFIED** | D: all four internal tables deny anon/authenticated CRUD; issuance and summary RPCs are service-only. Legacy card privileges are separately blocked in section 22. |
| 118 | Server-Observed IP | **VERIFIED** | C: visitor IP uses socket/trusted Vercel-reserved source; forged client fields are ignored. |
| 119 | Session ID Is Secondary Only | **VERIFIED** | C: shared/fake session or IP cannot change exact-token attribution. |
| 120 | Preview Must Produce Zero Ad Analytics | **BLOCKED** | C preview routes write zero events; N/V: current deployed/native preview zero-event proof pending. |
| 121 | Organic Traffic Is Separate | **BLOCKED** | C organic visits write zero ad events; V: deployed organic traffic response not retested. |
| 122 | Raw Events Are the Source of Truth | **VERIFIED** | C/D: raw event storage remains authoritative; no client aggregate replaces it. |
| 123 | Optional Aggregate Stats Table | **VERIFIED** | Code review: aggregate table is optional and not introduced; no analytics UI exposed. |
| 124 | Editing an Ad or Changing Its Card | **BLOCKED** | C/D versioned mapping machinery present; S/O: actual ad/card replacement and old-token behavior pending. |
| 125 | Deactivate / Delete Behavior with Tracking | **BLOCKED** | C dependency validation present; S: actual tracked deactivate/delete flow pending. |
| 126 | Token Generation Timing | **BLOCKED** | C/D atomic server-only issuance present; S: real post-registration/ad-edit issuance pending. |
| 127 | Existing ProxoLink Ads Migration | **BLOCKED** | O: existing production advertisement token migration remains unapplied. |
| 128 | Analytics Indexes | **VERIFIED** | D: fresh token/current-ad and event link/date/kind/retention index metadata observed. |
| 129 | Analytics Security Tests | **BLOCKED** | C controlled isolation/security tests pass; S/V: live authenticated tracking acceptance pending. |
| 130 | Analytics Retention and Privacy | **BLOCKED** | D: active proxolink-visitor-retention job metadata, private tables and minimal IP handling present. Actual job execution and wider privacy acceptance remain unverified. |
| 131 | Completion Report — Tracking | **VERIFIED** | Current report separates controlled exact-token tests and hidden-table/RPC metadata from unexecuted live two-ad, cross-tab and historical-attribution checks. |
| 132 | Additional Final Acceptance Criteria — Zero Mixing Between Ads | **BLOCKED** | C exact-token regression tests pass; S: required real zero-mixing acceptance not certified. |
| 133 | MANDATORY FINAL OVERRIDE — Genuine Live Template Previews Inside Flutter | **BLOCKED** | F one live URL widget/L eight visual documents pass; N/V: genuine platform selector not certified. |
| 134 | MANDATORY — Unified ProxoLink Flutter UI/UX (Create Ad and Ad Details Reference) | **BLOCKED** | F shared Ad UI and responsive screenshots pass; N: full device/keyboard/landscape UI acceptance pending. |
| 135 | MANDATORY — Targeted Improvements Inside All Eight Original Contact-Page Templates | **BLOCKED** | Eight V2 outputs freshly reproduced; hashes match reviewed refinements and seed dry run passes. L comparisons inspected; V2 is not registered or certified in live staging/native. |
| 136 | MANDATORY — Visual Preview Only; No Source-Code UI or Private Template Disclosure | **VERIFIED** | C/F/L/APK: final visual page only, no source-code UI, raw-template endpoint or bundled library. |
| 137 | MANDATORY — Finish the Existing PR; Resolve Real Blockers Without Inventing Success | **BLOCKED** | Existing PR reused and prior collector fix retained; no new harness or feature rewrite. T retirement completed. Native/staging/provider gates still prevent full completion. |
| 138 | MANDATORY — Final Acceptance, Evidence Matrix and Owner Handoff | **VERIFIED** | 145 unique numbered rows, scoped retirement execution, saved protection failure, all 40 blocked cases and direct eight historical comparison links; no Chromium/build result represented as native verification. |
| 139 | V5 LIVE GITHUB INSPECTION — Authoritative Current Repository Structure | **VERIFIED** | GitHub/code: same-repo Flutter/API architecture and consolidated routes retained; combined main/feature tree has 11 functions within the 12-function limit. |
| 140 | V5 PRODUCT CONTRACT — Fully Automatic Customer-Owned Contact Pages | **BLOCKED** | S/N/V: complete automatic ordinary-user management journey requires authorized write proof. |
| 141 | V5 VISUAL PREVIEW AND APPROVED UI REFINEMENTS — What Must Actually Be Visible | **BLOCKED** | L/F changes prepared and tested; S/N: refinements not deployed, real selector/device rendering pending. |
| 142 | V5 SECURE SERVER CONFIGURATION — Actual Variable Names and Access Boundaries | **FAILED** | Four exact GitHub settings and six Vercel server names/targets present; bypass removal/replacement audit metadata observed. Required reviewers is disabled and administrator bypass enabled, violating the protected-release procedure. Values/runtime validity remain untested. No values requested in chat or exposed. |
| 143 | V5 VERIFICATION AND DEPLOYMENT GATES — What Is Actually Known | **BLOCKED** | Latest inspected CI passes at dfa7c94; native-runtime skipped. Authorized retirement source/HTTP verification completed. Real native/staging/application/feature-release gates remain incomplete. |
| 144 | V5 EXECUTION PRIORITY, OWNER HANDOFF AND DONE DEFINITION | **BLOCKED** | Independent authorized work executed, including live Telegram retirement, and evidence published. Complete product done definition remains blocked by N/S/V/O and saved reviewer protection. |

Section totals: 53 VERIFIED, 1 FAILED, 91 BLOCKED.
