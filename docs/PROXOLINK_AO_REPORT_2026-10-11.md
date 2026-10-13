# ProxoLink A–AO report — updated 2026-10-13

**Pending / Blocked — not COMPLETE.** [Requirement checklist](PROXOLINK_A_AO_CHECKLIST_2026-10-11.md). The complete [A–AO specification](PROXOLINK_TOOLS_CREATE_SPEC_v4.md) remains controlling.

Branch `feat/proxolink-private-renderer-migration`; latest executable `8c1a353d527b4b9f45f7591515452ae3f0e025c4`. [Performance implementation/status/evidence](FLUTTER_PERFORMANCE_2026-10-13.md) records the exact changes and12-category table. Source run38472486063 at604469d passed all five jobs and240 Flutter tests; final test-order rerun38473249284 at8c1a353 also passed all five jobs and240 Flutter tests. All146 final widget images independently match the immediately pre-performance artifact. No runtime speed improvement is claimed.

[Completed native38388402520](PROXOLINK_NATIVE_38388402520.md) atf7112a8 executed and failed:233/240 exact pairs,7failed pairs/8pixels/maxdelta1; notices8/8,refresh7/8,browser3/3,bothselectors12/12. Approval is not blocking that completed run. New native/hosted run38473249236 at8c1a353 was explicitly requested and is tracked separately; neither its acceptance nor device performance is certified. Production remains unchanged; PR7 stays Draft/Open/Unmerged.

| AO item | Evidence / limitation |
|---|---|
| 1. Branch | `feat/proxolink-private-renderer-migration` |
| 2. Final commit SHA | Latest executable `8c1a353d527b4b9f45f7591515452ae3f0e025c4`; last completed native executable `f7112a8f069e1b8edad036254f6dbaa6aec7d671`. No fully accepted executable yet. |
| 3. Exact changed files | Exact cumulative performance paths and rationale are listed in the performance report. This continuation fixes banner lifecycle, removes unused Home name work, adds controlled regressions and corrects fixture cleanup/order. Ticker scoping was implemented earlier. Native report/checklist/evidence updates are documentation, not pixel fixes. [Cumulative PR files](https://github.com/Zana-Sponsor/proxobalance/pull/7/files). |
| 4. Replaced screens | Existing customer Tools/card/Create presentation replaced by the new ToolsScreen and ProxoLinkCreatePageScreen flow. Legacy compatibility editor remains debug verification only. |
| 5. New components | New Tools value-only cards, skeleton/empty states and sectioned Create presentation; existing controller/repository layers retained. |
| 6. Shared AppBar | ReceiptAppBar on both customer screens. |
| 7. Shared error components | AdValidationController, AdValidationNotifications and AdUi reused. cc52 clears remembered error after controller error resets, so an identical later failure gets a fresh notice. |
| 8. Card hierarchy/measurements | Name → type/moderation wrap → single-line LTR PAGE_UUID → date/time → Delete/Preview. Card width min(viewport−32,600), padding20, radius18, inter-card16; gaps10/16/6/20. See measurement table. |
| 9. Layout reason | Name first supports scanning, textual type/status distinguishes meaning without color, UUID remains authoritative but subordinate, fixed large actions avoid ambiguous tap targets;600px cap prevents tablet stretching. |
| 10. Empty state | Dedicated centered article icon40, padding56 vertical/12 horizontal, gaps20/10/20; primary create action above; shared text styles. |
| 11. External launch | Production launchUrl(uri, mode: LaunchMode.externalApplication); validated typed HTTPS UUID route, no credentials/query/fragment. No internal WebView preview. |
| 12. Browser return proof | Last completed native run38388402520 passed3/3 actual external-browser pause/resume cycles, preserved row/scroll and one collection read. Fictional public page; hosted authenticated content remains unverified. Final executable native rerun requested. |
| 13. Create sections | Single scroll: type, basics, providers, prepared style. Four sections,22px section gap,20px padding,16px fields,24px submit gap; no live WebView. |
| 14. Restaurant labels/keys | تەلەبات→talabat; وادێ→wade; تۆتەرز→toters; لەزوو→lezzoo. Both native selectors12/12 passed at4b816, including exact customer labels. Current source assertions retained. |
| 15. Schema before changes | Historical read-only pre-change audit found V5 schema without page_kind/settings/archived_at/moderation_status. Existing RLS/grants/FKs/indexes/storage/functions were inspected; no production migration was applied. This continuation does not claim a fresh production audit. |
| 16. Reused table | Existing ProxoLink cards table and existing profiles.is_admin/pa_is_admin authority; no duplicate page/admin tables. |
| 17. Migrations | No migration change in this continuation. Existing three additive migrations listed below tested rollback/reapply/rerun on disposable PostgreSQL17 only. |
| 18. Moderation storage | Server-stored NOT NULL moderation_status default pending with allowed-value CHECK and trusted transition guard; operational/publishing status stays separate. |
| 19. RLS | Disposable suites prove owner CRUD, cross-owner denial, immutable identity/owner and denial of owner self-approval. Hosted V6 contract remains blocked. |
| 20. Grants | Live audit found no anonymous table grant; authenticated owner policies; privileged service role stays server-side. SQL suites check unsafe grants; no changes in this continuation. |
| 21. Triggers/functions | Existing private touch_updated_at invoker and protect_live_card SECURITY DEFINER inspected with empty search_path; ad dependency protection retained. No new role/privilege shortcut. |
| 22. Dependency deletion | Existing ad RESTRICT foreign keys and API409 prevent unsafe deletion. No archive, detach or silent success; row removed locally only after server success. |
| 23. Query/index | Existing owner_created(user_id,created_at DESC), owner_ready and owner_request_unique retained. One owner-scoped collection request; no per-card fetch or new duplicate index. |
| 24. Cache/state | Atomic authoritative replacement keyed by PAGE_UUID, stable unchanged models, latest-request generation; local authoritative create/delete updates, no automatic browser-resume reload. |
| 25. Account isolation | Source/controller/upload tests reject late old-owner completions and clear private state on switch/logout. Hosted two-account authenticated UI/device journey remains BLOCKED. |
| 26. Responsive | Atf7112a8, all480 browser cases and retained Flutter width/scale tests passed. Neither result substitutes for Android pixel acceptance. |
| 27. Error comparison | Notification cause proven: entry animation began at mount after the insertion clock. Product fix uses scheduled elapsed entry time. Old/new source reproduction passes; native4b816 actual Ad/ProxoLink notices8/8 pass at unchanged400/4900/5500ms checkpoints. No deadline delay. |
| 28. Flutter count | At604469d,240 Flutter tests, analyzer and original/fixed banner, Home and notice reproductions passed; release/privacy/paired size checks passed. Final8c1a353 also passed all five source jobs,240 Flutter tests and the same original/fixed checks. |
| 29. Backend/API count | 153/153 backend tests passed locally; f7112a8 backend CI passed including build/source scan. |
| 30. DB/RLS count | f7112a8 disposable database job passed: three SQL contract suites, seven PostgreSQL-backed API lifecycles and migration rollback/reapply/rerun checks. No invented aggregate SQL assertion count. |
| 31. Security/privacy | f7112a8 backend source scan, database/RLS/security and both Deno checks passed. Current release APK/privacy scan passed. Historical native security result cited here belongs to4b816. |
| 32. APK impact | Current f7112a8 paired measurement83,702,384→89,319,872bytes (+5,617,488); thumbnail compressed increase5,617,485bytes plus3bytes packaging. Artifact11807069634 independently digest/CRC verified. Assets remain genuine1179×3120 renderer PNGs. |
| 33. Native status | Completed38388402520 atf7112a8:240 behavior pass;233/240 exact pairs;7failed/8pixels/maxdelta1. Browser3/3,legacy12/12,current Create12/12,notices8/8 pass;refresh7/8. Artifact11813922930 digest/CRC and all240 pairs independently recomputed. New38473249236 at8c1a353 is requested, not passed. |
| 34. Blockers | Pending: native pixel cause/remedy and full final native pass. Blocked: hosted38264179020 observed eight missing required staging settings (listed below). Physical performance profiling and unsupported device/browser coverage remain unverified. GitHub pending_deployments confirms the newly requested run38388402520 requires reviewer Zana-Sponsor in proxolink-preview-verification (environment23442858482). No approval blocker is attributed to either completed historical run. |
| 35. PR state | PR7 confirmed Draft/Open/Unmerged. This continuation leaves production publishing, migrations and security gates unchanged. |
| 36. Shared Home refresh | Tools reuses ProxoRefresh/controller/scope/arrival;60px reveal,22px spinner/2px stroke, opening spring260/22, closing300/30, minimum450ms. |
| 37. Motion evidence | Native4b816 Home/Tools8/8 pass with same list,one read,zero settled offset. Actual-screen widget comparisons at100/300ms and settled are retained in current passing suite. Hosted authenticated pull journey remains unverified. |
| 38. Deleted-row reconciliation | Controller tests verify complete authoritative replacement removes server-deleted rows and updates values/status while preserving UUID identity; no stale merge. |
| 39. Latest-request-wins | Deferred old/new request tests plus owner/disposal generations reject older completion; source suite passes. |
| 40. No permanent shift | Widget exact settled geometry assertions pass; completed native4b816 all8 refresh cases report zero offset and stopped refresh. Final-source native result pending. |

Exact eight paths changed by cc52 relative to47d0c609c344a7e9c2ffae11bb4f4c29147dfd13:

- `proxo_app/lib/screens/tools_screen.dart`
- `proxo_app/test/proxolink_tools_create_test.dart`
- `proxo_app/integration_test/proxolink_native_chooser.dart`
- `proxo_app/integration_test/proxolink_native_create_chooser.dart`
- `proxo_app/integration_test/proxolink_native_tools_journey.dart`
- `scripts/proxolink-native-browser.mjs`
- `scripts/run-proxolink-native.mjs`
- `test/proxolink-native-browser.test.js`

The documentation publication adds `docs/PROXOLINK_AO_REPORT_2026-10-11.md` and `docs/PROXOLINK_A_AO_CHECKLIST_2026-10-11.md`. Existing reports remain historical. [Implementation diff](https://github.com/Zana-Sponsor/proxobalance/commit/cc52ca4c26a291677f935ff50cf13dd43cfcd5d5), [cumulative PR files](https://github.com/Zana-Sponsor/proxobalance/pull/7/files).

Existing disposable-tested migrations:

- `proxo_app/supabase/migrations/20261006220119_proxolink_v6_independent_pages.sql`
- `proxo_app/supabase/migrations/20261008234009_proxolink_page_management_contract.sql`
- `proxo_app/supabase/migrations/20261009131901_proxolink_tools_moderation.sql`

| Viewport | Card | Inner content |
|---|---|---|
|320|288|248|
|393|361|321|
|430|398|358|
|768|600|560|

Measurements are logical pixels. Screen insets16 horizontal/20top/32bottom. Name uses shared Rabar titleMedium regular, maximum3 lines; metadata/status bodyMedium, UUID bodySmall single-line ellipsis. Type/status wraps with12px horizontal/8px vertical spacing; status padding10×4/radius8. Date/time wrap gap14/run4. Filled action minimum52px, outline48px;12px horizontal gap; stack when inner width is below240×scaled-font-factor with10px vertical gap. Selector max432px,12px gap, one column below260 otherwise two, tile max210px. Full1179×3120 PNG uses contain, physical decode ceil((tileWidth−16)×DPR) capped1179.

Visual evidence below is **widget/fictional-transport evidence**, not native or hosted screenshots. Prior audit compared138 retained product/actual-screen images byte-identically to historical cc52 CI artifact. Current UI artifact11807339165 contains146PNGs plus measurements; all58 retained Tools/Create images match it byte-for-byte; eight compatibility images are not the new customer flow.

| Width | Cards/long name/all statuses | Empty | Error | Create | Styles |
|---|---|---|---|---|---|
|320|[Cards](evidence/proxolink-tools-2026-10-09/ui/tools-320.0-status-1.png) / [approved](evidence/proxolink-tools-2026-10-09/ui/tools-320.0-status-2.png) / [rejected](evidence/proxolink-tools-2026-10-09/ui/tools-320.0-status-3.png)|[Empty](evidence/proxolink-tools-2026-10-09/ui/tools-empty-320.0.png)|[Error](evidence/proxolink-tools-2026-10-09/ui/tools-error-320.0.png)|[Form](evidence/proxolink-tools-2026-10-09/ui/create-320.0.png)|[Selector](evidence/proxolink-tools-2026-10-09/ui/create-style-contact-320.0.png)|
|393|[Cards](evidence/proxolink-tools-2026-10-09/ui/tools-393.0-status-1.png) / [approved](evidence/proxolink-tools-2026-10-09/ui/tools-393.0-status-2.png) / [rejected](evidence/proxolink-tools-2026-10-09/ui/tools-393.0-status-3.png)|[Empty](evidence/proxolink-tools-2026-10-09/ui/tools-empty-393.0.png)|[Error](evidence/proxolink-tools-2026-10-09/ui/tools-error-393.0.png)|[Form](evidence/proxolink-tools-2026-10-09/ui/create-393.0.png)|[Selector](evidence/proxolink-tools-2026-10-09/ui/create-style-contact-393.0.png)|
|430|[Cards](evidence/proxolink-tools-2026-10-09/ui/tools-430.0-status-1.png) / [approved](evidence/proxolink-tools-2026-10-09/ui/tools-430.0-status-2.png) / [rejected](evidence/proxolink-tools-2026-10-09/ui/tools-430.0-status-3.png)|[Empty](evidence/proxolink-tools-2026-10-09/ui/tools-empty-430.0.png)|[Error](evidence/proxolink-tools-2026-10-09/ui/tools-error-430.0.png)|[Form](evidence/proxolink-tools-2026-10-09/ui/create-430.0.png)|[Selector](evidence/proxolink-tools-2026-10-09/ui/create-style-contact-430.0.png)|
|768|[Cards](evidence/proxolink-tools-2026-10-09/ui/tools-768.0-status-1.png) / [approved](evidence/proxolink-tools-2026-10-09/ui/tools-768.0-status-2.png) / [rejected](evidence/proxolink-tools-2026-10-09/ui/tools-768.0-status-3.png)|[Empty](evidence/proxolink-tools-2026-10-09/ui/tools-empty-768.0.png)|[Error](evidence/proxolink-tools-2026-10-09/ui/tools-error-768.0.png)|[Form](evidence/proxolink-tools-2026-10-09/ui/create-768.0.png)|[Selector](evidence/proxolink-tools-2026-10-09/ui/create-style-contact-768.0.png)|

Actual widget Home/Tools and Create Ad/ProxoLink phase screenshots and exact fake-clock values are retained in [earlier detailed visual evidence](PROXOLINK_TOOLS_CREATE_CONTINUATION_2026-10-09.md#visual-evidence-and-actual-measurements). That report's old runtime/status/count claims are superseded by this report.

Artifact provenance from preceding independent download/audit:

| Artifact | Run / ID | ZIP SHA256 |
|---|---|---|
|Historical UI|38070780277 /11676796495|`01e05a0f2772aef7c4dbe322686625ef37a4a275a6497b83478e8a30e0942a3c`|
|Historical paired APK size|38070780277 /11677176607|`d364a1ccbaba68092ac870c2ac2cba22c2f83c1a616bab3c6d16cb89afe798f2`|
|Historical native82|38060488156 /11675279231|`f38b5ee865c94a0c4c86803624b2437eba0e57e80640600b1f9fc10710ee8545`|

[Historical UI artifacts](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38070780277#artifacts). Historical [native artifact11761854434](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38265055827/artifacts/11761854434) independently verified SHA256 `96194a6c06e5d7f963eae87a9f581e2b684efa83d29aadddc08749eeeca2cdc0`; ZIP CRCs passed. It includes all64 actual-screen phase screenshots. [Exact failed pairs, raw results and coordinate audit](evidence/proxolink-native-38265055827). The six retained candidate/baseline pairs were independently recomputed again on October13: five single pixels plus1129 shadow-band pixels, maxdelta1.

Hosted [run38264179020](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38264179020) executed in `proxolink-preview-verification` and failed `staging_setting_required`. [Artifact11756526797](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38264179020/artifacts/11756526797) independently verified SHA256 `a07400dc4bd84687b53717cd3759fe0a67a7261cfb5fafe94408281ed19164bb`. Required absent names observed in that run:

- PROXO_STAGING_PROJECT_REF
- PROXO_STAGING_SUPABASE_URL
- PROXO_STAGING_BASE_URL
- PROXO_STAGING_ANON_KEY
- PROXO_STAGING_TEST_EMAIL
- PROXO_STAGING_TEST_PASSWORD
- PROXO_STAGING_OTHER_EMAIL
- PROXO_STAGING_OTHER_PASSWORD

The first three accept variables or secrets; the remaining values are secrets. An isolated project/preview and two ordinary accounts are needed. Account existence is not inferred. The current native-only marker intentionally skips the hosted job; it does not overturn the prior executed presence check or certify the settings as fixed.

Remaining: obtain current native diagnostic results, establish the pixel cause, implement an evidence-supported remedy and pass all240 zero-pixel comparisons plus every behavioral gate at the final executable. Configure the observed missing isolated settings and pass hosted journeys. No threshold, mask, later-frame substitution, template speculation, production migration or publishing change is allowed. PR7 remains Draft/Open/Unmerged.

## Current source artifact verification

All ZIP CRCs passed and independently computed SHA256 matched GitHub metadata:

| Artifact | ID / SHA256 |
|---|---|
| [Responsive](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38388402541/artifacts/11808085090) |11808085090 / `fae82e53f381c890aeeab9fc35835109435cfc8577d48026bfe4428113e2e05a`|
| [UI screenshots](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38388402541/artifacts/11807339165) |11807339165 / `774f989fe3366b3c4b7c047ac22324f116379d5f94309b71e089ba9d4d0a171a`|
| [Paired APK size](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38388402541/artifacts/11807069634) |11807069634 / `8e050e1712af0e2f7dcd0be19b1f4ddbf0089a1fb6ed700807bceadcfacf540a`|

These certify source/widget/browser verification atf7112a8. Its native artifact now exists and failed as documented in the current native report; subsequent performance-source verification is recorded separately.
