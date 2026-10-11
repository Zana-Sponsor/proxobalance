# ProxoLink A–AO report — 2026-10-11

**Pending / Blocked. Not COMPLETE.** [Requirement checklist](PROXOLINK_A_AO_CHECKLIST_2026-10-11.md). The complete [A–AO specification](PROXOLINK_TOOLS_CREATE_SPEC_v4.md) remains controlling.

[Source CI38070780277](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38070780277) passes all five jobs at cc52. [Current native run38070780315](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38070780315) attempt2 has a successful APK, but Android execution awaits protected review. Attempt1 failed during NDK download before APK; one controlled failed-job retry recovered the build. No additional blind retry or relaxed gate.

This continuation fixed repeated identical refresh-error notices, synchronized native browser return to a real matching pause receipt, and corrected native restaurant-label fixtures/assertions. Product renderer, thresholds and production infrastructure were not changed. Current workspace exec-server connection failed; no shell/filesystem capability is exposed in this turn. Remote GitHub reads and documentation publication continue, but new local native artifact extraction/debugging cannot run.

| AO item | Evidence / limitation |
|---|---|
| 1. Branch | `feat/proxolink-private-renderer-migration` |
| 2. Final commit SHA | Tested executable `cc52ca4c26a291677f935ff50cf13dd43cfcd5d5`. This report/checklist publication is documentation-only; its commit SHA is recorded in PR7 and the delivery response. There is no fully accepted final executable yet. |
| 3. Exact changed files | Eight implementation/test paths listed below; this publication adds only this report and the new checklist. Full cumulative PR diff remains available in PR7; prior implementation manifests remain historical. |
| 4. Replaced screens | Existing customer Tools/card/Create presentation replaced by the new ToolsScreen and ProxoLinkCreatePageScreen flow. Legacy compatibility editor remains debug verification only. |
| 5. New components | New Tools value-only cards, skeleton/empty states and sectioned Create presentation; existing controller/repository layers retained. |
| 6. Shared AppBar | ReceiptAppBar on both customer screens. |
| 7. Shared error components | AdValidationController, AdValidationNotifications and AdUi reused. cc52 clears remembered error after controller error resets, so an identical later failure gets a fresh notice. |
| 8. Card hierarchy/measurements | Name → type/moderation wrap → single-line LTR PAGE_UUID → date/time → Delete/Preview. Card width min(viewport−32,600), padding20, radius18, inter-card16; gaps10/16/6/20. See measurement table. |
| 9. Layout reason | Name first supports scanning, textual type/status distinguishes meaning without color, UUID remains authoritative but subordinate, fixed large actions avoid ambiguous tap targets;600px cap prevents tablet stretching. |
| 10. Empty state | Dedicated centered article icon40, padding56 vertical/12 horizontal, gaps20/10/20; primary create action above; shared text styles. |
| 11. External launch | Production launchUrl(uri, mode: LaunchMode.externalApplication); validated typed HTTPS UUID route, no credentials/query/fragment. No internal WebView preview. |
| 12. Browser return proof | Widget three-cycle state/scroll/one-read checks pass. Historical real Android three cycles failed missing pause despite resume/same element/scroll. cc52 host requires matching observed pause before return. Current native execution BLOCKED on review; hosted content remains unverified. |
| 13. Create sections | Single scroll: type, basics, providers, prepared style. Four sections,22px section gap,20px padding,16px fields,24px submit gap; no live WebView. |
| 14. Restaurant labels/keys | تەلەبات→talabat; وادێ→wade; تۆتەرز→toters; لەزوو→lezzoo. Native fixture fixed and exact customer labels independently asserted; current native pass pending. |
| 15. Schema before changes | Read-only audit before cc52: live V5 schema lacks page_kind/settings/archived_at/moderation_status. RLS/grants/FKs/indexes/storage and trigger definitions inspected; production unchanged. Earlier detailed audit retained in prior evidence. |
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
| 26. Responsive | Flutter nine widths320/360/375/393/412/430/600/768/1024 at scales1/1.6 pass;480 renderer/browser cases pass separately. Neither substitutes for native. |
| 27. Error comparison | Shared widget and actual-screen fixture comparisons pass. Historical native400ms entry failed Create Ad320 and ProxoLink430; all eight visible4900ms, removed5500ms. Native entry cause unresolved. |
| 28. Flutter count | 234 tests passed, changed-code analysis passed in source CI38070780277 job114267559355. |
| 29. Backend/API count | 153 tests passed locally in preceding work and source CI job114267559253; build/source scan pass. |
| 30. DB/RLS count | Three SQL contract suites plus seven real PostgreSQL-backed API lifecycles; rollback/reapply/rerun three migrations. No invented aggregate SQL assertion count. |
| 31. Security/privacy | Source and release APK private-template scans pass; two edge functions Deno-check pass. Historical native secure-config/KVM gates pass; current runtime not executed. |
| 32. APK impact | Same-code paired measurement83,702,384→89,319,872 bytes; +5,617,488. Twelve thumbnail entries compressed868,949→6,486,434 (+5,617,485), remaining3bytes packaging. Genuine1179×3120 renderer PNGs, no crop/stretch. |
| 33. Native status | Current run38070780315 attempt2 APK SUCCESS; runtime job114307708767 WAITING for protected review. Historical run38060488156 failed strict acceptance:240 behavior passes,232/240 exact pixel pairs,8 failed pairs/8 pixels/max channel delta1;14/16 actual-screen flows;12/12 legacy and12/12 previous current chooser checks. |
| 34. Blockers | Required environment reviewer; unresolved native pixel and notice-entry failures; isolated hosted settings/two accounts/public content; unavailable workspace connection. Exact actions below. |
| 35. PR state | PR7 freshly confirmed Draft/Open/Unmerged. Production publishing and migrations unchanged. |
| 36. Shared Home refresh | Tools reuses ProxoRefresh/controller/scope/arrival;60px reveal,22px spinner/2px stroke, opening spring260/22, closing300/30, minimum450ms. |
| 37. Motion evidence | Historical actual native8/8 Home/Tools refresh flows pass with same list,one read,zero settled offset; current widget comparisons at100/300ms and settled pass. Current runtime and authenticated pull journey unverified. |
| 38. Deleted-row reconciliation | Controller tests verify complete authoritative replacement removes server-deleted rows and updates values/status while preserving UUID identity; no stale merge. |
| 39. Latest-request-wins | Deferred old/new request tests plus owner/disposal generations reject older completion; source suite passes. |
| 40. No permanent shift | Widget exact settled geometry and historical native all8 refresh cases report zero offset and stopped refresh. New current native result pending. |

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

Visual evidence below is **widget/fictional-transport evidence**, not native or hosted screenshots. Prior audit compared138 retained product/actual-screen images byte-identically to current cc52 CI artifact. Full current artifact includes146PNGs plus measurements; eight compatibility images are not the new customer flow.

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
|Current UI|38070780277 /11676796495|`01e05a0f2772aef7c4dbe322686625ef37a4a275a6497b83478e8a30e0942a3c`|
|Current paired APK size|38070780277 /11677176607|`d364a1ccbaba68092ac870c2ac2cba22c2f83c1a616bab3c6d16cb89afe798f2`|
|Historical native82|38060488156 /11675279231|`f38b5ee865c94a0c4c86803624b2437eba0e57e80640600b1f9fc10710ee8545`|

[Current artifacts](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38070780277#artifacts), [historical native artifacts](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38060488156#artifacts). Historical native ZIP retains64 whole-surface actual-screen PNGs and raw pixel/lifecycle/chooser results. They were audited in preceding work; new local extraction/copy is blocked by unavailable workspace and is not claimed published here.

Exact remaining actions:

1. **Native review:** configured reviewer `Zana-Sponsor` opens [run38070780315](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38070780315), chooses **Review deployments → proxolink-preview-verification → Approve and deploy**. GitHub pending-deployments confirms environment23442858482 and named reviewer. This is the existing required review, not a new agent permission policy. Runtime job114307708767 has not started; keep protections intact.
2. **Native failures:** once the protected run executes, inspect FIRST-frame strict pixels and two notice-entry cases. Historical8-pixel mismatch cause is NOT PROVEN. Do not introduce tolerance, masks, delayed chosen frames or speculative renderer changes. Browser pause and exact-label fixes require current native evidence, not just tests/build.
3. **Hosted acceptance:** isolated Supabase project/preview and two ordinary accounts are needed. Last protected presence audit found eight settings absent: `PROXO_STAGING_PROJECT_REF`, `PROXO_STAGING_SUPABASE_URL`, `PROXO_STAGING_BASE_URL`, `PROXO_STAGING_ANON_KEY`, `PROXO_STAGING_TEST_EMAIL`, `PROXO_STAGING_TEST_PASSWORD`, `PROXO_STAGING_OTHER_EMAIL`, `PROXO_STAGING_OTHER_PASSWORD`. Existing native credentials are a separate scope and are not claimed missing. Configure secrets through the protected environment, never chat or report. Follow [isolated staging setup](PROXOLINK_V6_ISOLATED_STAGING_SETUP.md), with existing renderer prerequisites, three migrations in staging only and isolated write mode. Run hosted runner, authorized isolated moderation/dependency fixtures, transition phase, authenticated UI/account switching and real published-page browser verification. Current hosted job is skipped, not passed.
4. **Workspace/debugging:** restore the failed workspace connection to inspect raw native artifacts, reproduce causes and make/test any necessary further fixes. No execution tool is currently callable. Browser-family/iOS or real authenticated device coverage cannot be inferred from desktop Chromium/widget fixtures.

No full acceptance or pixel-perfect completion is claimed. PR7 remains Draft/Open/Unmerged; production publishing and migrations stay untouched.
