# A–AO acceptance checklist — 2026-10-11

Overall: **Pending / Blocked — not COMPLETE**.
Specification: [complete A–AO specification](PROXOLINK_TOOLS_CREATE_SPEC_v4.md).
Current executable: `f7112a8f069e1b8edad036254f6dbaa6aec7d671`. [Updated forty-item AO report](PROXOLINK_AO_REPORT_2026-10-11.md) records exact current source results and independently verified artifacts. Source CI38388402541: all five jobs passed,237 Flutter tests,153 backend tests,480 browser cases, database/RLS, edge and release/privacy/size checks. The controlled repaint restoration fix passes without changing native FIRST captures or zero-pixel acceptance.

Last completed native executable4b816/run38265055827: notices8/8, refresh8/8, browser3/3 and both selectors12/12 pass; pixels234/240, six failed pairs/1134pixels/maxdelta1. New native38388402520 atf7112a8: APK passed, runtime115267707400 **not executed**, waiting at the configured environment review. Hosted38264179020 **executed**, observed eight absent staging settings; hosted journeys remain Blocked. These are distinct execution scopes. Complete rows below certify only their stated source/disposable-fixture or explicitly dated runtime criterion.

| Requirement | Status | Evidence / remaining work |
|---|---|---|
| A: inspect branch, current architecture and actual schema before changes | Complete | Current V6 clone, PR #7 metadata, read-only hosted metadata query; current audit JSON. |
| A: columns/types/defaults/CHECK/UNIQUE/FKs/indexes | Complete | Original and fresh read-only metadata audited; production remains V5 withoutpage_kind/settings/archived_at/moderation_status; existing owner/date index retained. |
| A: RLS/grants/triggers/functions/definers/storage/ad dependencies | Complete | Metadata/trigger bodies inspected read-only; hashes only retained. Assets bucketpublic with owner writes,templatesprivate; existing adRESTRICT FKs preserved. |
| A: existing admin mechanism and status semantics | Complete | Existing protected `profiles.is_admin`/`pa_is_admin`; operational/publishing status separate from moderation. |
| A/J: additive existing-table moderation migration, no duplicate table/role | Complete | Existing additive migration; isolated PostgreSQL rollback/reapply/security evidence. |
| B: new Tools/card/empty/loading/error/Create presentation | Complete | New `ToolsScreen`, value-only card/skeleton, `ProxoLinkCreatePageScreen`; prior source CI and images. |
| C: shared AppBar, exact titles, normal back/navigation | Complete | Both use `ReceiptAppBar`; widget back preservation checks. |
| D/Z: exact primary/create label | Complete | `پەڕە دروستبکە` on both screens; widgets. |
| E: only name/page UUID/date/time/type/moderation/Delete/Preview | Complete | Card source and images; no per-row image or extra actions. |
| E: no labels, avatars/logos/style/updated/analytics/admin metadata | Complete | Card source and negative widget checks. |
| F: deliberately chosen formal card composition, measured/justified | Complete | 20px padding,18px radius,16px gutters,600px content cap; detailed report. |
| F/G: long multilingual names and single-line authoritative PAGE_UUID | Complete | Three name lines with ellipsis, LTR single-line UUID; nine width/text-scale tests. |
| H: exact customer type values, no internal keys | Complete | `ProxoPageTypeInfo.label`; widgets. |
| I: exact compact textual moderation badges | Complete | pending/approved/rejected labels and restrained colors; all status images. |
| J: server-stored NOT NULL pending default/CHECK, no client decisions | Complete | Additive migration, request denial, direct-role tests; technical failure remains distinct. |
| J: trusted pending→approved/rejected mechanism | Complete | Existing service-role authority and invoker trigger; disposable tests. |
| J: actual hosted moderation contract in isolated environment | Blocked |Hosted38264179020 executed; presence-only artifact confirms eight absent PROXO_STAGING settings listed in terminal report. Native settings present. Isolated configuration needed; no production writes.|
| K: owner SELECT/INSERT/UPDATE/DELETE, immutable identity/owner | Complete | Existing RLS plus guard migrations, three disposable SQL suites and seven API lifecycles. |
| K: no anonymous management reads, no client owner trust | Complete | Current grants/owner policies, request tests and native security preflight. |
| K: immediate logout/account-switch isolation, stale-result denial | Complete | Controller/form tests and upload owner checks pass current source CI; late old-owner results are rejected. Hosted two-account/device journey remains blocked separately. |
| L: confirmation, dependency-safe actual deletion, no hidden archive/detach | Complete | Safe API409/FK checks, existing RESTRICT FKs, owner DELETE tests. |
| L: duplicate dialog/submission prevention | Complete | Existing busy gate plus per-page confirmation re-entry guard; rapid callbacks prove one dialog; current Flutter CI passed. |
| M: actual typed HTTPS UUID route and externalApplication only | Complete | Production `launchUrl` call, URL contract tests, no WebView/custom-tab preview. |
| N: list/route/scroll preserved across three returns; no lifecycle GET | Complete | Existing injected launcher fixture with exact row position and one GET. |
| N: real Android browser lifecycle and preserved state | Complete | Completed4b816 run38265055827:3/3 actual pause/resume and stable row/scroll/one read. Fictional public page; hosted-content coverage remains blocked separately. |
| N: supported browser families/iOS/device lifecycle | Blocked | Android runner evidence cannot certify Safari/iOS or unavailable browsers/devices. |
| N/P: browser failure keeps stable UI with exact shared notice | Complete | Existing shared component and five-second expiry test. |
| O: balanced dedicated empty state and primary create action | Complete | Exact title/support plus create action; four-width images. |
| P: actual Create Ad controller/notices/tokens/stack/animation reused | Complete | `AdValidationController`, `AdValidationNotifications`, `AdUi`; no duplicate implementation. |
| P: all validation/load/upload/create/delete/network/security errors safe | Complete | Safe Kurdish error mapping and shared notices; backend details omitted. |
| P/AL: same shared error component visual/lifetime regression | Complete | Shared-component screenshot, stagger/entry/5s/exit assertions; broader native full-screen comparison remains below. |
| Q: new single-scroll sections with native Proxo composition | Complete | Type/basic/providers/style;22px section gap/shared20px card padding. |
| R: exactly three types, safe type-specific fields | Complete | Model/provider filtering and Create form tests. |
| S: exact type image labels, existing secure storage paths/no upsert | Complete | Read-only storage-policy audit and validated JPEG/PNG/WebP upload. |
| S/K: account switch while upload is being prepared/completes | Complete | Owner captured before await; checked before storage/after completion and around request-key preparation. Current analyzer/tests pass. Actual hosted upload under two ordinary accounts is blocked separately. |
| T: exact name labels and automatic RTL/LTR | Complete | Directional input widget; multilingual tests. |
| U: clean multiline description and existing length/escaping limits | Complete | Form, server validators and SQL guards. |
| V: TikTok normalization/injection denial; no extra page type | Complete | Name-only normalization, strict server/SQL regex tests. |
| W: correct six contact/four restaurant/two store options | Complete | Provider model/options/API/renderer/SQL inspected and tested. |
| W: تەلەبات→talabat, وادێ→wade, تۆتەرز→toters, لەزوو→lezzoo | Complete | Exact labels/keys; all four available for new isolated authoring. |
| W: strict hosts/types/malicious URL denial | Complete | API/SQL validation tests; no relaxed host checks. |
| X: exactly four existing Kurdish designs and thumbnails | Complete | Existing selector and twelve high-DPI assets; selected-state widget coverage. |
| X: current native selector twelve type/style cases | Complete | Completed4b816 run38265055827:12/12, exact Kurdish labels independently asserted, decoded selection/native input/no WebView gate passed. |
| Y: no live/internal WebView in Create | Complete | Current form source, negative widget tests; native assertion added. |
| Z: DB-generated UUID, random request key, idempotent single submit | Complete | Backend/SQL identity and widget submit tests; local authoritative upsert. |
| Z: prevent duplicate create routes | Complete | Route re-entry guard and rapid callbacks prove one Create route; current Flutter CI passed. |
| AA.1: exact shared Home refresh component/motion, temporary reveal | Complete | `ProxoRefresh`/controller/scope/arrival;60px strip,22px/2px arc,springs,450ms floor. |
| AA.2/AA.5: loaded cards retained, skeleton only initial load | Complete | Widget and controller tests; stable list wrapper. |
| AA.3: PAGE_UUID reconciliation updates/new/sorted/deleted/status | Complete | Atomic latest result replacement and model reuse tests. |
| AA.3/AA.11: older response cannot overwrite newer result | Complete | Deferred-read latest-request tests and owner/dispose generations. |
| AA.4: subtle changed-row arrival, stable unchanged rows | Complete | Existing shared arrival and changed UUID set; no duplicate ListView/crossfade. |
| AA.6: failed refresh retains useful data, settles/retries/shared notice | Complete | Populated failure→successful replacement tests. |
| AA.7: create/delete authoritative local update without collection reload | Complete | Owner-scoped upsert/delete tests and one GET assertions. |
| AA.8: browser return does not trigger disruptive refresh | Complete | Tools has no resume observer; three-cycle widget fixture. Final-source native rerun pending above. |
| AA.9: shared programmatic controller, re-entry/scroll behavior | Complete | MainShell integration and rapid refresh/settled-geometry tests. |
| AA.10: one owner request/no N+1/images/WebViews/realtime/reset | Complete | Large lazy list and request-count tests; controller lifetime inspected. |
| AA.11: all fifteen refresh scenarios including empty/failure/account/list/scale | Complete | Existing controller/widget suites; same list element and exact settled geometry. |
| AA.11/AO37: actual HomeScreen vs Tools widget phase evidence | Complete | Production screen classes,80 new PNGs/four widths; exact100/300ms offsets,one read,same element,zero settle; fictional transports,not hosted/native. |
| AA.11/AO37: actual native refresh comparison | Pending | Completed4b816 run38265055827:8/8 Home/Tools refresh cases pass, one read/same list/zero settled offset. Final-source runtime and real authenticated pull/session coverage remain unverified. |
| AB: existing indexes inspected, measured query, no duplicates | Complete | Owner/date index, metadata-only EXPLAIN0.14..2.36; no new index. |
| AC: UI→controller→repository→auth API→DB/RLS layers, typed/safe errors | Complete | Existing architecture and boundary/error tests; new changes passed current CI. |
| AC: timeout/malformed/auth/idempotency/stale/delete/browser behavior | Complete | Service30s timeout and existing API/model/controller fixtures. |
| AD: private templates server-side; public data separate | Complete | Source privacy scan, compiled release scan and native boundary checks. |
| AE: exact footer across4×3, balanced smaller logo, legal relationship | Complete | Footer-only old/new hashes;84×24logo; twelve real renderer images. |
| AF: exactly12 full-page genuine high-DPI assets, no crop/stretch/upscale | Complete |1179×3120/DPR3 asset/hash manifest and image audit. |
| AF: physical-width decode quality and paired APK impact | Complete | Physical decode width;83,702,384→89,319,872bytes(+5,617,488),same-code current cc52 CI measurement verified. |
| AG:9widths320/360/375/393/412/430/600/768/1024, Tools+3forms | Complete | Prior Flutter widths×scales1/1.6; renderer480cases. Current source CI also passed. |
| AH: semantics/minimum touch targets/status text/text scaling | Complete |48/52px actions, semantic labels, adaptive240×scale stack threshold, selector scaling tests. |
| AI: Tools exact labels/content/actions/no forbidden features | Complete | Existing widget suite and inspected source/images. |
| AI: state/loading/error/delete/owner/browser/multilingual/responsive | Complete | Existing source tests; actual browser/device gate pending separately. |
| AJ: Create AppBar/back/sections/labels/providers/4styles/noWebView | Complete | Existing Create suite and all width images. |
| AJ: validation5s/double-submit/idempotency/local success | Complete | Existing notice and submit tests; new route/dialog test passed current CI. |
| AK: generated distinct UUID/multiple pages/owner and immutable boundaries | Complete | Existing disposable PostgreSQL suites and API lifecycle evidence. |
| AK: stored moderation/trusted transitions/invalid values/provider/FK/grants | Complete | Tools moderation SQL suite, RLS suites and native read-only security preflight. |
| AK: isolated current Tools hosted runner implementation | Complete | Adds12 current type×style upload/create/read/real HTML+avatar/owner/session/delete lifecycles; trusted-transition/dependency observation requires separate authorized setup. Provider-fixture orchestration/security checks pass146Node suite. |
| AK: real hosted authenticated UI/API/DB journey | Blocked |Hosted38264179020 executed; presence-only artifact confirms eight absent PROXO_STAGING settings listed in terminal report. Native settings present. Isolated configuration needed; no production writes.|
| AL: actual Create Ad vs ProxoLink widget screen notices | Complete | Actual submit taps; decoded thumbnails; same appearance; fully visible400/4900ms,exit5100ms,removed5500ms atfour widths. |
| AL: native full-screen notice comparison | Complete |4b816 native38265055827:8/8 pass including all four former failures. Fixed scheduled-entry timeline; unchanged400/4900/5500ms assertions. Raw evidence linked in terminal report. |
| AM: images320/393/430/768, Tools/multilingual/status/empty/error/Create/styles | Complete |58 original plus80 actual-screen fictional widget PNGs retained with dimensions/hashes; final CI matches. Browser renderer images and native artifacts are labeled separately. |
| AM: actual placement/padding/gaps/type/action stacking/rationale documented | Complete | Existing forty-item report, card/source measurements. |
| AN: no extra edit/archive/activate/menu/analytics/share/internal preview/types/templates/admin/table | Complete | Current reachable customer routes and negative tests; legacy compatibility editor appears only in debug verification, not Tools navigation. |
| KVM: original commands/gate/failure retained, safe interrupted-step evidence | Complete | Atomic checkpoints and8isolated checks pass locally/current CI, including simulated termination and observation failure. Baseline native KVM passed. Current protected runner execution remains pending below. |
| KVM: current protected runner execution | Complete | cc52 current run secure setup/KVM passed; native gate executed and failed pixels/notices, not readiness. |
| AO: all40 report items | Complete | AO report and October12 supplement identify4b816 executable, exact fix/diagnostic paths, actual source results and pending native/hosted gates; no completion claim. |
| AO/guardrails: PR7Draft/Open/Unmerged; production publishing/migrations/customer data untouched | Complete | Current PR metadata and read-only operations; no activation or production migration. |
| Native: strict FIRST-frame zero-pixel parity | Pending |4b816:234/240 exact;6failed pairs/1134pixels/maxdelta1. Native redraw26/26 unchanged; WebContents readback changed11. Root cause/remedy unresolved; next repaint diagnostic queued. |
| Workspace: local inspection and artifact extraction | Complete | Connection restored; repository/current artifact recovered; digest/CRC and independent PNG audit complete. Local Android adb/KVM unavailable; GitHub runner executed. |


Latest product fix: repeated refresh failures re-arm the shared error notice even when the service reuses the same error instance. Regression proves two notices after expiry, cards retained, settled refresh and three reads.

No production migration/publishing, security weakening, pixel tolerance changes or merge. Full task completion remains withheld.
