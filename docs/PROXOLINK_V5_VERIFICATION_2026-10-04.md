# ProxoLink V5 implementation and verification — 4 October 2026

The independently actionable V5 changes are implemented on [Draft PR #7](https://github.com/Zana-Sponsor/proxobalance/pull/7). Tested executable revision: [`121be74e322e43dfb4e7d03d8ffb739c63d70422`](https://github.com/Zana-Sponsor/proxobalance/commit/121be74e322e43dfb4e7d03d8ffb739c63d70422). This report supersedes earlier reports' “current” test/deployment assertions. **Integrated product completion remains BLOCKED** by protected Vercel access, native runtime configuration, authorized staging writes and production approval gates.

The supplied V5 prompt, sections 0–144, was read in full. The owner's later instruction removing Telegram supersedes the older bot/button requirements: no new ProxoLink Telegram control, destination, notification or bot setup; historical customer fields stay preserved. Existing PR work was reused and concurrent branch updates reconciled before committing.

## Implemented changes

- The live selector and full-page demo now follow the selected theme and Kurdish/Arabic/English language. Those choices are signed into the short-lived capability; URL parameters cannot change them. Invalid selections fail before reading private metadata. The eight original styles retain their order, and the catalog selects the newest eligible revision of each style.
- Flutter retains entered form data while reloading one selected live preview. Restored pending create requests retain their pinned template revision instead of silently changing the idempotent payload when the catalog updates.
- All demo destinations, including original footer/legal links, are inert. Original visual confirmation modals remain functional. Real customer footer/contact destinations retain their separate behavior. Retired Telegram modal logic is removed from delivered pages.
- Eight immutable **private v2 copies were prepared locally** from checksum-verified v1 inputs. They apply only the approved name/bio/spacing/press changes and remove retired Telegram treatments. The generator refuses source/checksum mismatches and overwrites. The seed tool verifies uploaded bytes before registering metadata and defaults v2 to inactive/hidden.
- A repeatable local browser harness verifies the same renderer used by selector demos and public pages. Reusable template documents and private input/output manifests are **not committed to Git**, shipped in Flutter or exposed by this harness; it serves only final fictional pages on loopback.

**V2 is prepared, not deployed or registered.** Fresh SQL reports zero version-2 rows. No private v1 object was overwritten, no customer was repinned, and no catalog activation was performed. Existing deployed pages therefore do not yet receive these v2 refinements. All eight v1 input SHA-256 values matched the current private catalog; inputs were reconstructed from the repository's historical source rather than obtained through an authenticated Storage download. The actual protected remote renderer still needs verification.

## Current evidence and boundaries

| Evidence | Result and environment |
| --- | --- |
| C — backend/security | **55 passed**, 0 failed locally and in [push CI 37225977261](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37225977261); malformed input, owner/JWT checks, signed capabilities, same-UUID create/retry, failed/stale edit preservation, avatar bytes and exact-token attribution covered with controlled fixtures |
| F — Flutter | **96 passed** in the same CI run; selected ProxoLink, ad repository/creation/submission and text-direction suites. Analysis passed with 28 informational lints. Shared Ad UI/Rabar components retained. This is widget/model evidence, not native WebView certification |
| Android build/privacy | Release APK built successfully at **83.2 MB**; reusable-template/static-preview/credential-marker scan passed. No store-signed release or store publication |
| Native probe | [Build 37225977258](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37225977258) passed without runtime credentials. `native-runtime` was **SKIPPED**, not passed; no Android platform WebView cases certified |
| PR CI | [Run 37225981157](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37225981157) passed for executable revision `121be74` |
| L — local browser | **40/40**: eight styles × 320/375/393/430/768 px, Chromium 153, fictional data, cached original dependency bytes. Rabar/icon fonts, decoded images, advancing animations, modal cycle, inert demo links, long/mixed/unbroken bios, no horizontal overflow, reduced motion and no JS page errors checked. [Machine-readable results](evidence/proxolink-v5-browser/results.json) |
| Pixel comparison | Refined demo/public initial-state viewport pixels matched exactly in all 40 controlled local cases. Legacy/refined colors, gradients, button shapes and avatar dimensions stayed equal; approved typography/wrapping/spacing differences were reviewed separately. These results do not establish remote dependency availability, Latin webfont loading, every animation frame or Android/iOS parity |
| Build/routes/source | `npm run build`, source scan, seed dry run and diff checks passed; **10** top-level API functions, below the 12-function limit. Existing consolidated dispatcher/rewrites retained |
| D — live read-only database | 21 cards, 27 ads, 16 card references; zero orphan/cross-owner references; zero tracking links/events. Twelve template metadata rows: eight v1 catalog styles plus four hidden legacy variants. All 21 cards remain legacy/precutover (`active` + `creating`) |
| P — private access | `proxolink-templates.public=false`. Anonymous public-object requests for **all eight** styles returned HTTP 400/denied. Internal template/link/event/publish-attempt tables deny effective anon/authenticated SELECT/INSERT/UPDATE/DELETE. RLS enabled; atomic link RPC exists, is service-role executable and is not anon/authenticated executable |
| Index/retention metadata | Owner/readiness/request uniqueness, exact-token/current-ad, event/date/kind/retention and publication audit indexes present; one active ProxoLink retention job observed. Its execution/content was not retested |
| V — Vercel | Project lookup for `proxobalance` in `proxoapp-1758` returned **404 Project not found**. Current deployment status, secret target/presence and authenticated remote routes cannot be independently certified by this connection |

Flutter CI artifact `proxolink-ui-verification` is **11312315460**, digest `sha256:a19652657f1a404977a3ec214a28c58f38fd5a5a139cb6177d15a85c201ddb62`. Safe copies of [card list 320 dp](evidence/proxolink-v5-flutter/cards-320.png), [768 dp](evidence/proxolink-v5-flutter/cards-768.png), [form/retry 320 dp](evidence/proxolink-v5-flutter/form-320.png) and [768 dp](evidence/proxolink-v5-flutter/form-768.png) are retained here. The form screenshot intentionally shows a retry state from the test repository; it is not evidence of a rendered platform WebView.

The earlier/later card checkpoints matched during this pass; counts and reference validity remain unchanged at handoff. The whole-ad checkpoint changed while this read-only work was running, so complete ad-row immutability is **not claimed**. No database, Storage, Auth, Vercel environment or customer mutation was performed by this pass. A fresh frozen backup/manifest and relation check are still required immediately before any approved cutover. Historical verification of 19 avatars was not repeated and does not certify the new deployment.

Supabase's project-wide advisory scan is **not clean**: 26 mutable function search paths, one public extension, 14 anon/66 authenticated security-definer exposure warnings, and leaked-password protection disabled. RLS-without-policy informational findings include intentionally service-only tables/backups. No unrelated production security changes were made; these findings must be triaged separately rather than represented as resolved.

## Eight original designs and intentional differences

Each comparison below is a lossless 393 px capture: original v1 on the left, prepared v2 on the right, with the same fictional data and no Telegram button in either rendered page. These images are evidence only; the application uses live WebViews, not these files.

| Style | Approved differences | Evidence |
| --- | --- | --- |
| Dark | Name 18 px/500; normal 400 text; balanced 36ch bio; bio-to-grid gap 40→28 px; subtle press | [Before/after](evidence/proxolink-v5-browser/dark-before-after.webp) |
| Light | Same narrow typography/bio/grid improvements; light identity preserved | [Before/after](evidence/proxolink-v5-browser/light-before-after.webp) |
| Classic | Name 20 px/500 retains classic proportion; ordinary text 400; balanced bio/press | [Before/after](evidence/proxolink-v5-browser/classic-before-after.webp) |
| Pill | Name 18 px/500; regular labels; balanced bio; original pill gradient/shape retained | [Before/after](evidence/proxolink-v5-browser/pill-before-after.webp) |
| Card | Name 18 px/500; regular labels; balanced bio; original accent-card structure retained | [Before/after](evidence/proxolink-v5-browser/card-before-after.webp) |
| Neon | Name 18 px/500; regular labels; balanced bio; original outline/glow retained | [Before/after](evidence/proxolink-v5-browser/neon-before-after.webp) |
| Zoom | Name 18 px/500; regular labels; balanced bio; original zoom identity retained | [Before/after](evidence/proxolink-v5-browser/zoom-before-after.webp) |
| Banner | Name 18 px/500; bio max 36ch, shrink-safe header; ≤374 px header padding/gap reduced | [Before/after](evidence/proxolink-v5-browser/banner-before-after.webp) |

Shared changes: 130 ms press transition and scale `.985`, natural word wrapping without changed customer text, and reduced-motion suppression. Original background, gradient, footer, button order/icons and decorative JS remain, apart from retired Telegram code. Older engines retain natural wrapping when `text-wrap: balance` is unsupported; actual Android/iOS fallback rendering is still BLOCKED.

## Exact executable file list for this pass

```text
api/_lib/proxolink-handlers/contact-templates.js
api/_lib/proxolink-preview.js
api/_lib/proxolink.js
proxo_app/lib/screens/tools_screen.dart
proxo_app/lib/services/proxolink_service.dart
proxo_app/test/proxolink_flow_test.dart
scripts/proxolink-refinements.mjs
scripts/refine-proxolink-private.mjs
scripts/seed-proxolink-private.mjs
scripts/verify-proxolink-visual.mjs
test/proxolink-api.test.js
test/proxolink-private.test.js
test/proxolink-refinements.test.js
```

Report/evidence additions: this file, the current-note update in `PROXOLINK_IMPLEMENTATION_REPORT.md`, `evidence/proxolink-v5-browser/results.json`, eight `{style}-before-after.webp` files listed above, and the four Flutter PNGs listed above. The full existing PR diff includes earlier implementation work; this list identifies only this pass.

## Applied versus prepared

No new migration was applied in this pass. The live migration registry confirms these earlier applications:

| Live migration version | Name |
| --- | --- |
| `20261003202251` | `proxolink_private_staging` |
| `20261003212627` | `proxolink_production_integrity` |
| `20261004005907` | `proxolink_legacy_versions` |
| `20261004005953` | `proxolink_indexes` |
| `20261004010739` | `proxolink_migration_manifest` |
| `20261004013754` | `proxolink_hidden_analytics` |

Repository migration filenames are not the live registry timestamps. The standalone atomic-issuance SQL is also included in the previously applied production-integrity migration; current function presence/client denial were checked. `scripts/sql/proxolink_verified_cutover.sql` remains a separately gated cutover procedure. Final legacy-card privilege restriction, ready-state backfill, deferred relationship/sync activation, existing-ad token migration and legacy deletion are not applied by this work.

Prepared v2 copies have inactive/hidden manifest flags and are reproducible with `node scripts/refine-proxolink-private.mjs /private/v1-root /private/v2-root`. A seed **dry run** is `node scripts/seed-proxolink-private.mjs /private/v2-root` without `--apply`. Upload, registration and catalog activation must first occur in an authorized isolated staging project, using server-side configuration entered through secure provider settings. Do not change pinned v1 contents or bulk repin customers. Do not run an old inactive manifest against an already activated version without reviewing its catalog flags.

## Prepared v2 checksum manifest

These are hashes of the local immutable outputs tested above; no corresponding live v2 registrations exist.

| Style | Prepared v2 SHA-256 |
| --- | --- |
| dark | `f67cf6b8f4a002b7bd9cf5017e5b7255debbe964e6514136cf5d03f89371096c` |
| light | `aff227d7e7cae2d89bfefcd6e4693bd754117959b85e236dc017edbe26dfc20d` |
| classic | `e39a8730f8b56670aea0b2a426ed897c17a96a37589c64b47f39016e41e1535f` |
| pill | `eb906906df645a58f54b0add59d3ebc1e61308742b1d4081263bd4ae2e414730` |
| card | `d9ea423b772843ec97e00def424627aca9dbfd28143a56802f34eec09d8e4962` |
| neon | `82adf89404f52aaa52d2e7baf905d3158505c48038c671e6e9406e6b212f3b0e` |
| zoom | `17fcabb80930dc22d7e1f23de1f736d9a218a740f3f041d124bc98b194f217df` |
| banner | `bab9849457ce6dcd283b7f6cb1f64ceebb61c5e2d580ae2f4e135cd191e4ac97` |

## Exact remaining owner/provider gates

1. **Vercel access:** open [the project-owning team](https://vercel.com/proxoapp-1758), confirm `proxobalance` with its owner identity, and reconnect the Vercel plugin using that identity/team. The connected team listing alone is insufficient. Recheck project/current feature Preview and server-variable **presence/targets only**, using the `PROXO_*` names in `.env.example`; do not retrieve decrypted values or create duplicate credentials.
2. **Protected native testing:** create GitHub environment `proxolink-preview-verification`, restrict it to `feat/proxolink-private-renderer-migration`, require an appropriate reviewer and disable admin bypass. Add environment variable `PROXO_NATIVE_ANON_KEY` and environment secrets `PROXO_NATIVE_TEST_EMAIL`, `PROXO_NATIVE_TEST_PASSWORD`, `PROXO_NATIVE_VERCEL_BYPASS`. Use an existing ordinary account and secure provider entry, never chat. Follow [the exact setup](PROXOLINK_PREVIEW_VERIFICATION_SETUP.md), review the current workflow/SHA, then explicitly dispatch it. Verify all **32** Android 35 platform-WebView cases at 320/393/430/768 with safe screenshots; inspect the results rather than accepting the APK build alone.
3. **Scope of bypass:** Vercel's temporary automation capability is project-wide until revoked. Keep protection enabled, use the fixed Preview origin and restricted reviewed workflow, and revoke the dedicated capability immediately after testing. An isolated Preview project is required if provider-enforced preview-only scope is mandatory.
4. **Staging product proof:** authorize isolated staging configuration/fixtures, privately seed/activate the reviewed v2 catalog there, and test ordinary-user create, duplicate request, same-UUID edit, failed edit preservation, avatar, retry, owner-only inactive preview, public active/inactive/failed states, copy/share, AdCreate/AdScreen eligibility and exact two-ad token/event isolation. Preview/organic traffic must produce zero ad events. The current read-only native workflow cannot prove write flows.
5. **Devices and historical credentials:** test actual phone/message/social launch and fallback on Android; complete iOS and relevant older-WebView/landscape/keyboard coverage. Coordinate historical privileged-key revocation with consumers in a separately authorized maintenance window. Telegram is removed from ProxoLink; shared order-notification credentials must be evaluated separately.

Current Preview status is **unverified** through this connection; historical READY claims refer to older revisions. Main was observed at `e7c1d3060c2777cae7ff2bc293df7df5ebfd4cd6`; PR #7 remains open/Draft/unmerged. No production promotion was requested or performed. Customer cutover, credential rotation affecting production consumers, PR merge, production promotion and destructive cleanup remain **separate approval gates**, after the applicable tests succeed.

Rollback for this pass is a reviewed revert of executable commit `121be74` on the feature branch before merging. It needs no customer/database rollback because this pass made no live mutations. Keep all original private versions, backups and legacy fields. Future staging activation must be reversible through catalog flags while retaining every pinned version; any later production cutover requires a fresh protected backup/manifest and independently reviewed transactional rollback, not deletion of legacy fields.

## Requirement matrix — sections 0–144

VERIFIED means the stated evidence proves that requirement in its relevant tested environment. BLOCKED means a required deployment, native, staging, credential or production gate remains; code/unit progress is identified but does not promote an integrated requirement to verified. There are no known FAILED results in the completed checks. C/F/L/D/P refer to the concrete evidence above. N = native/device gate; V = protected Vercel access; S = authorized staging write-flow proof; O = separately approved production/credential operation.

| Section | Requirement | Status | Evidence / remaining gate |
| --- | --- | --- | --- |
| 0 | Historical Baseline — Re-Verify Live State Before Implementing | **BLOCKED** | V: current GitHub/DB/private metadata checked; actual Vercel project/deployment remains inaccessible. |
| 1 | Main Product Goal | **BLOCKED** | S/N/V: complete ordinary-customer journey requires integrated staging and device proof. |
| 2 | Important Technical Truth About Source Privacy | **VERIFIED** | C/APK: reusable source is server-only in the feature build; final browser markup remains inspectable. |
| 3 | Required Architecture | **BLOCKED** | V/S: architecture is implemented/tested in code; deployed integration remains unverified. |
| 4 | Private Template Storage | **VERIFIED** | D/P: private bucket flag and eight anonymous object denials; no private source added to client. |
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
| 24 | Public Template Source Protection Acceptance Test | **BLOCKED** | P eight public URLs denied; V/N: full authenticated/owner capability acceptance still pending. |
| 25 | Remove / Replace Flutter Template Generator | **VERIFIED** | Source/APK scan: template generator and reusable template assets absent from the feature build. |
| 26 | Remove Old Local HTML Preview | **VERIFIED** | Source scan/F: local HTML assembly replaced by signed URL WebView requests. |
| 27 | WebView Preview — Must Match Chrome | **BLOCKED** | N: real Android/iOS WebView-versus-Chrome comparison not executed. |
| 28 | Preview Tracking Safety | **BLOCKED** | C demo/owner analytics suppression passes; N/V: actual platform preview zero-event proof pending. |
| 29 | WebView Navigation Behavior | **BLOCKED** | C navigation restrictions present; N: platform denial and external launch/fallback untested. |
| 30 | Card List UI — Unify with Create Ad and Ad Details | **VERIFIED** | F: shared Ad UI components and responsive card list; current 320/768 dp captures reviewed. |
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
| 46 | Retired Telegram Behavior — historical text superseded by owner amendment | **VERIFIED** | C/F: owner override removes Telegram controls, rendering, navigation and tracked actions; historical fields retained. |
| 47 | Legacy Credential Remediation — one-time revocation, no replacement for ProxoLink | **BLOCKED** | O: compromised historical credentials require coordinated owner revocation/rotation; never chat values. |
| 48 | Flutter Model Update | **VERIFIED** | F/C: structured model, state gates, safe public path and archived-platform filtering tested. |
| 49 | Flutter List Query | **BLOCKED** | C safe owner list implemented; V/O: deployed list and legacy client privilege transition pending. |
| 50 | Template Selector in Flutter — Real Rendered Previews, Not Images | **BLOCKED** | F lazy signed URL widget and L eight styles pass; N/V: actual selector WebViews not certified. |
| 51 | Rabar 021 and Design Consistency | **VERIFIED** | F: inherited Rabar and actual shared Ad UI styles retained; responsive RTL tests pass. |
| 52 | Public Renderer Sanitization | **VERIFIED** | C/L: customer HTML/URLs escaped or rejected; template rendering remains intact. |
| 53 | Template Placeholder Contract | **VERIFIED** | C/L: all eight original placeholder documents render; source checksums and v2 generation validated. |
| 54 | Template Versioning | **VERIFIED** | C/dry run: separate immutable v2 paths, checksum enforcement, pinned v1 retained. |
| 55 | Future Automatic Template Management | **VERIFIED** | C: newest eligible catalog revision selected per style without changing restored pending requests. |
| 56 | GitHub Workflow | **VERIFIED** | GitHub: Draft feature PR retained; push and PR CI passed at 121be74. |
| 57 | Vercel Routing | **BLOCKED** | Consolidated rewrites retained; V: actual deployed Vercel routes not reached. |
| 58 | Vercel Environment Variables | **BLOCKED** | V: server variable target/presence cannot be read with current project access; values not retrieved. |
| 59 | Server Error Handling | **VERIFIED** | C/F: invalid inputs, stalled previews, late responses, stale edits and publish failures handled. |
| 60 | Recommended Error Codes | **VERIFIED** | C: validation/auth/conflict/readiness responses exercised with controlled API fixtures. |
| 61 | Public Link Readiness Check | **BLOCKED** | C render-before-ready passes; S/V: actual publish/public-link readiness pending. |
| 62 | Preview UX | **BLOCKED** | F timeout/retry/state retention passes; N: actual WebView loading/scroll/gesture experience pending. |
| 63 | Preview vs Chrome Acceptance | **BLOCKED** | N: desktop-local pixel equality does not establish Android/iOS preview parity. |
| 64 | Public Contact Button Behavior | **BLOCKED** | C safe destination/fallback construction passes; N: actual external applications untested. |
| 65 | Ads Integration Rules — Strong Per-Ad Isolation | **BLOCKED** | C exact-token isolation passes; S: live same-card/two-ad events and ad editing pending. |
| 66 | Realtime Is Not Required for Basic Card Creation | **VERIFIED** | C/F: create/save result is authoritative; realtime is not required for readiness. |
| 67 | Database Indexes | **VERIFIED** | D: live owner/readiness/request uniqueness and publication/tracking indexes enumerated. |
| 68 | Constraints | **BLOCKED** | D additive schema present; O: final legacy/cutover constraints and strict privilege transition deferred. |
| 69 | Migration Safety Procedure | **BLOCKED** | O: refreshed protected backup/manifest and separately approved migration procedure required. |
| 70 | Existing Production Data Must Survive | **BLOCKED** | D counts/references valid; O: fresh frozen preservation manifest required; unrelated live ad activity observed. |
| 71 | Safe Rollout Order | **BLOCKED** | O/N/S/V: current feature verification precedes cutover/merge/production/cleanup approval. |
| 72 | Testing Matrix | **BLOCKED** | C/F/L pass; N/S/V: full native/live product matrix remains incomplete. |
| 73 | UI Localization | **VERIFIED** | C/F: ku/ar/en labels and signed choices; mixed-direction text preserved in tests. |
| 74 | Design Rules for Status UI | **BLOCKED** | F shared styling present; N/S: all real status/keyboard/system-scale device combinations pending. |
| 75 | Card Row Layout | **VERIFIED** | F: long RTL card rows pass five widths at enlarged text scale; 320/768 dp captures retained. |
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
| 90 | card_number | **VERIFIED** | C/F: stable card identity and UUID paths retained; display numbering is not link authority. |
| 91 | Concurrency | **BLOCKED** | C stale lease/conflict tests pass; S: concurrent real DB create/edit/retry/ad-token operations pending. |
| 92 | Do Not Trust checked_btns as Security | **VERIFIED** | C: server derives allowed contacts; checked_btns is not trusted authorization. |
| 93 | Platform JSON Validation | **VERIFIED** | C: non-string/malformed/oversized platform JSON rejected before writes. |
| 94 | Privacy | **BLOCKED** | C visitor/IP minimization passes; O: legacy raw data/client privilege and migration cleanup deferred. |
| 95 | GitHub Secret Hygiene | **BLOCKED** | Source/APK scans pass; O: historical exposed-key rotation/history remediation is not complete. |
| 96 | Vercel Preview Testing | **BLOCKED** | V: new protected Preview API and ordinary-user access tests blocked by project connection. |
| 97 | Production Deployment | **BLOCKED** | O: production deployment/merge not authorized or performed. |
| 98 | Rollback Plan | **VERIFIED** | Handoff: reversible feature revert and separately gated future migration rollback documented. |
| 99 | Completion Report | **VERIFIED** | Handoff: current files, commit, CI, migration/deployment boundaries and owner steps recorded. |
| 100 | Final Acceptance Criteria | **BLOCKED** | N/S/V/O: final integrated acceptance and release gates remain incomplete. |
| 101 | Strong Per-Advertisement Tracking Architecture | **BLOCKED** | C exact-ad implementation passes; S/O: actual tracking/customer integration and migration pending. |
| 102 | New Mapping Table: pa_ad_contact_links | **BLOCKED** | D mapping table/RPC present; S/O: actual issued mappings and existing-ad backfill pending. |
| 103 | Why Use a Mapping Table | **BLOCKED** | C/D mapping design present; S: live mapping issuance/replacement/inactive behavior pending. |
| 104 | Tracked Ad URL | **BLOCKED** | C exact token paths pass; V/S: actual tracked ad public URLs pending. |
| 105 | Vercel Route for Tracked Ads | **BLOCKED** | Consolidated /a rewrites retained; V/S: deployed route/events not reached. |
| 106 | Do Not Redirect to a Shared Tracking Context | **BLOCKED** | C exact-ad render avoids shared-context redirects; V/S: actual deployed flow pending. |
| 107 | New Raw Event Table | **VERIFIED** | D: raw event table present, RLS enabled and effective client CRUD denied. |
| 108 | Optional Denormalized ad_id/card_id | **VERIFIED** | C: optional denormalized identity remains derived from validated server-side link context. |
| 109 | Controlled Event Types | **VERIFIED** | C: only controlled event/action kinds accepted; invalid token/action requests record nothing. |
| 110 | Page View Tracking | **BLOCKED** | C event recording passes; S/V: actual exact-ad page-view events not exercised. |
| 111 | Tracked Button URLs | **VERIFIED** | C: tracked buttons/TikTok preserve their exact validated ad token; arbitrary destinations rejected. |
| 112 | Contact Action Flow | **BLOCKED** | C validated action flow passes; S/N: actual recording then external contact action pending. |
| 113 | Example: Same Card, Two Different Ads | **BLOCKED** | C two-ad/shared-card isolation passes; S: live two-ad event fixture proof pending. |
| 114 | Never Use card_id Alone for Ad Analytics | **VERIFIED** | C: same-card, fake-session/IP tests resolve analytics using the exact ad link, never card_id alone. |
| 115 | Keep pa_ads.clicks Separate | **VERIFIED** | C: contact events remain separate from pa_ads platform-click counters. |
| 116 | Hidden Analytics Requirement | **VERIFIED** | F/C/D: no Flutter analytics dashboard or client internal-table access introduced. |
| 117 | RLS and Direct Access | **VERIFIED** | D/P: internal tables deny anon/authenticated CRUD; atomic issuance RPC is service-only. |
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
| 128 | Analytics Indexes | **VERIFIED** | D: token/current-ad and event link/date/kind/retention indexes present. |
| 129 | Analytics Security Tests | **BLOCKED** | C controlled isolation/security tests pass; S/V: live authenticated tracking acceptance pending. |
| 130 | Analytics Retention and Privacy | **BLOCKED** | D active retention job/private tables; V/S/O: actual retention execution and broader privacy audit pending. |
| 131 | Completion Report — Tracking | **VERIFIED** | Handoff: tracking architecture/tests and unexecuted live isolation gates explicitly reported. |
| 132 | Additional Final Acceptance Criteria — Zero Mixing Between Ads | **BLOCKED** | C exact-token regression tests pass; S: required real zero-mixing acceptance not certified. |
| 133 | MANDATORY FINAL OVERRIDE — Genuine Live Template Previews Inside Flutter | **BLOCKED** | F one live URL widget/L eight visual documents pass; N/V: genuine platform selector not certified. |
| 134 | MANDATORY — Unified ProxoLink Flutter UI/UX (Create Ad and Ad Details Reference) | **BLOCKED** | F shared Ad UI and responsive screenshots pass; N: full device/keyboard/landscape UI acceptance pending. |
| 135 | MANDATORY — Targeted Improvements Inside All Eight Original Contact-Page Templates | **BLOCKED** | L approved private v2 improvements pass; S/N: activation and actual customer/native rendering pending. |
| 136 | MANDATORY — Visual Preview Only; No Source-Code UI or Private Template Disclosure | **VERIFIED** | C/F/L/APK: final visual page only, no source-code UI, raw-template endpoint or bundled library. |
| 137 | MANDATORY — Finish the Existing PR; Resolve Real Blockers Without Inventing Success | **VERIFIED** | GitHub/handoff: existing PR continued, independent defects fixed, actual blockers disclosed. |
| 138 | MANDATORY — Final Acceptance, Evidence Matrix and Owner Handoff | **VERIFIED** | Handoff: every section has a status, evidence boundary and exact safe owner/provider steps. |
| 139 | V5 LIVE GITHUB INSPECTION — Authoritative Current Repository Structure | **VERIFIED** | GitHub/code: same-repo Flutter/API architecture, consolidated routes and 10-function count verified. |
| 140 | V5 PRODUCT CONTRACT — Fully Automatic Customer-Owned Contact Pages | **BLOCKED** | S/N/V: complete automatic ordinary-user management journey requires authorized write proof. |
| 141 | V5 VISUAL PREVIEW AND APPROVED UI REFINEMENTS — What Must Actually Be Visible | **BLOCKED** | L/F changes prepared and tested; S/N: refinements not deployed, real selector/device rendering pending. |
| 142 | V5 SECURE SERVER CONFIGURATION — Actual Variable Names and Access Boundaries | **BLOCKED** | V/N/O: server presence/targets, protected runtime settings and historical credential rotation pending. |
| 143 | V5 VERIFICATION AND DEPLOYMENT GATES — What Is Actually Known | **BLOCKED** | GitHub/DB evidence refreshed; V/N/S/O: current deployment/device/product/release gates incomplete. |
| 144 | V5 EXECUTION PRIORITY, OWNER HANDOFF AND DONE DEFINITION | **BLOCKED** | Independent code, CI and handoff complete; V/N/S/O: integrated product done definition not met. |

Section totals: 54 VERIFIED, 91 BLOCKED, 0 FAILED. BLOCKED does not mean absent code; it prevents an untested integrated requirement from being reported complete.
