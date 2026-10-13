# A–AO implementation and acceptance checklist

Status: **Pending**, not COMPLETE. Continue the current V6 branch; do not restart it.
Historical native baseline: `e61bc1a93f4acdc7ad75e9f44e79e6d73f110f11`. This continuation started at `2f2b389a7acd187ea586839639e6010d02f7d226`; final executable source is `c830a683b6b70ee91f5aebc002b1b4b424d5ac4a`.
Specification: the attached `ProxoLink_FINAL_Tools_CreatePage_Supabase_HomeRefresh_Prompt_v4.md`, whose internal title says V3. The filename does not alter its requirements.

“Complete” below certifies only the identified source/fixture criterion. It does not certify a Pending/Blocked hosted/device criterion. Final executable c830 passed all five jobs in [source CI37983088739](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37983088739):230 Flutter,146 backend,480 renderer/browser,three disposable SQL suites and seven PostgreSQL API lifecycles. Release compilation/privacy and native debug APK analysis/build passed. Actual-screen widget evidence now includes80 PNGs from production Home/Tools/Create Ad/ProxoLink classes; it is not native or hosted evidence. Every retained58 product screenshot is byte-identical to the final CI artifact. Final-source [protected run38004288157](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38004288157), metadata and exact reviewer action: [native request](evidence/proxolink-tools-continuation-2026-10-09/native-runtime-request.json). Historical native evidence remains pinned to e61. [All forty AO items and exact blockers](PROXOLINK_TOOLS_CREATE_CONTINUATION_2026-10-09.md); [actual-screen audit](evidence/proxolink-tools-continuation-2026-10-09/actual-screen-artifact-audit.json); [independent native audit](evidence/proxolink-tools-continuation-2026-10-09/native-independent-audit.json).

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
| J: actual hosted moderation contract in isolated environment | Blocked | No separate isolated project; Supabase cost lookup unavailable and Vercel deployment scope403. Production lacks V6/moderation columns and remains unchanged. |
| K: owner SELECT/INSERT/UPDATE/DELETE, immutable identity/owner | Complete | Existing RLS plus guard migrations, three disposable SQL suites and seven API lifecycles. |
| K: no anonymous management reads, no client owner trust | Complete | Current grants/owner policies, request tests and native security preflight. |
| K: immediate logout/account-switch isolation, stale-result denial | Complete | Controller/form tests and upload owner checks pass current source CI; late old-owner results are rejected. Hosted two-account/device journey remains blocked separately. |
| L: confirmation, dependency-safe actual deletion, no hidden archive/detach | Complete | Safe API409/FK checks, existing RESTRICT FKs, owner DELETE tests. |
| L: duplicate dialog/submission prevention | Complete | Existing busy gate plus per-page confirmation re-entry guard; rapid callbacks prove one dialog; current Flutter CI passed. |
| M: actual typed HTTPS UUID route and externalApplication only | Complete | Production `launchUrl` call, URL contract tests, no WebView/custom-tab preview. |
| N: list/route/scroll preserved across three returns; no lifecycle GET | Complete | Existing injected launcher fixture with exact row position and one GET. |
| N: real Android external browser handoff/resume | Pending | Added production-launcher native journey, real ADB input, foreground-browser receipt, pause/resume/element/scroll checks; unexecuted. Fictional list/public-content limitations are explicit. |
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
| X: new native current-form type×style tap/decoded/selected/provider assertions | Pending | Twelve additive current-create cases and validator; legacy live-WebView gate retained independently. |
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
| AA.8: browser return does not trigger disruptive refresh | Complete | Tools has no resume observer; three-cycle widget fixture. Native pending above. |
| AA.9: shared programmatic controller, re-entry/scroll behavior | Complete | MainShell integration and rapid refresh/settled-geometry tests. |
| AA.10: one owner request/no N+1/images/WebViews/realtime/reset | Complete | Large lazy list and request-count tests; controller lifetime inspected. |
| AA.11: all fifteen refresh scenarios including empty/failure/account/list/scale | Complete | Existing controller/widget suites; same list element and exact settled geometry. |
| AA.11/AO37: actual HomeScreen vs Tools widget phase evidence | Complete | Production screen classes,80 new PNGs/four widths; exact100/300ms offsets,one read,same element,zero settle; fictional transports,not hosted/native. |
| AA.11/AO37: full native motion/pull-gesture evidence | Pending | Additive actual-screen native journey compiled but not executed; approved runner plus actual device pull/session coverage required. |
| AB: existing indexes inspected, measured query, no duplicates | Complete | Owner/date index, metadata-only EXPLAIN0.14..2.36; no new index. |
| AC: UI→controller→repository→auth API→DB/RLS layers, typed/safe errors | Complete | Existing architecture and boundary/error tests; new changes passed current CI. |
| AC: timeout/malformed/auth/idempotency/stale/delete/browser behavior | Complete | Service30s timeout and existing API/model/controller fixtures. |
| AD: private templates server-side; public data separate | Complete | Source privacy scan, compiled release scan and native boundary checks. |
| AE: exact footer across4×3, balanced smaller logo, legal relationship | Complete | Footer-only old/new hashes;84×24logo; twelve real renderer images. |
| AF: exactly12 full-page genuine high-DPI assets, no crop/stretch/upscale | Complete |1179×3120/DPR3 asset/hash manifest and image audit. |
| AF: physical-width decode quality and paired APK impact | Complete | Physical decode width;83,702,384→89,319,872bytes(+5,617,488),same-code final c830 CI measurement verified. |
| AG:9widths320/360/375/393/412/430/600/768/1024, Tools+3forms | Complete | Prior Flutter widths×scales1/1.6; renderer480cases. Current source CI also passed. |
| AH: semantics/minimum touch targets/status text/text scaling | Complete |48/52px actions, semantic labels, adaptive240×scale stack threshold, selector scaling tests. |
| AI: Tools exact labels/content/actions/no forbidden features | Complete | Existing widget suite and inspected source/images. |
| AI: state/loading/error/delete/owner/browser/multilingual/responsive | Complete | Existing source tests; actual browser/device gate pending separately. |
| AJ: Create AppBar/back/sections/labels/providers/4styles/noWebView | Complete | Existing Create suite and all width images. |
| AJ: validation5s/double-submit/idempotency/local success | Complete | Existing notice and submit tests; new route/dialog test passed current CI. |
| AK: generated distinct UUID/multiple pages/owner and immutable boundaries | Complete | Existing disposable PostgreSQL suites and API lifecycle evidence. |
| AK: stored moderation/trusted transitions/invalid values/provider/FK/grants | Complete | Tools moderation SQL suite, RLS suites and native read-only security preflight. |
| AK: isolated current Tools hosted runner implementation | Complete | Adds12 current type×style upload/create/read/real HTML+avatar/owner/session/delete lifecycles; trusted-transition/dependency observation requires separate authorized setup. Provider-fixture orchestration/security checks pass146Node suite. |
| AK: real hosted authenticated UI/API/DB journey | Blocked | Separate project+preview+two ordinary accounts absent; provisioning cost tool unavailable/deployment403. No hosted execution or UI account-switch claim; no production writes. |
| AL: actual Create Ad vs ProxoLink widget screen notices | Complete | Actual submit taps; decoded thumbnails; same appearance; fully visible400/4900ms,exit5100ms,removed5500ms atfour widths. |
| AL: native full-screen notice comparison | Pending | Additive native actual-screen journey compiled;64 whole-surface captures and validation await approved runtime. Callback input is explicitly not ADB. |
| AM: images320/393/430/768, Tools/multilingual/status/empty/error/Create/styles | Complete |58 original plus80 actual-screen fictional widget PNGs retained with dimensions/hashes; final CI matches. Browser renderer images and native artifacts are labeled separately. |
| AM: actual placement/padding/gaps/type/action stacking/rationale documented | Complete | Existing forty-item report, card/source measurements. |
| AN: no extra edit/archive/activate/menu/analytics/share/internal preview/types/templates/admin/table | Complete | Current reachable customer routes and negative tests; legacy compatibility editor appears only in debug verification, not Tools navigation. |
| Native: historical Android35/WebView matrix evidence | Complete | Pinned e61 run37960639713 executes240,captures240+240,480stable acceptance roles; independently recomputed. This does not verify final-source runtime. |
| Native: final executable matrix/first-frame/repeats | Pending | Original240/first-frame/three repeats/zero-pixel comparator retained; final protected workflow awaits review. |
| Native: zero changed pixels across240first-frame comparisons | Blocked |236exact/4failed,4changedpixels,maxdelta1. Same-input fresh-view variation observed; root cause NOT PROVEN. No tolerance/mask/frame selection/template remedy. |
| Native: legacy chooser independent12cases | Pending | Last run0/12 due wrong mounted route; debug probe now mounts existing legacy editor directly. Assertions unchanged. |
| KVM: original commands/gate/failure retained, safe interrupted-step evidence | Complete | Atomic checkpoints and8isolated checks pass locally/current CI, including simulated termination and observation failure. Baseline native KVM passed. Current protected runner execution remains pending below. |
| KVM: current helper executed on actual protected runner | Pending | Final-source request metadata gives the exact run/job/reviewer action; previous fb29 run37974532875 remains historical. No actual current runtime result exists. |
| AO: all40report items and exact changed paths/executableSHA/current results | Complete | Continuation report supplies all40 items, exact path/hash manifest, tested implementation SHA and current results. Final publication SHA is in PR metadata/final response. All unfinished acceptance criteria remain explicit. |
| AO/guardrails: PR7Draft/Open/Unmerged; production publishing/migrations/customer data untouched | Complete | Current PR metadata and read-only operations; no activation or production migration. |

Native source identity observation now hashes real live DOM/font bytes and rejects empty CDP cache parity claims. It is post-capture observational evidence, not a causal pixel remedy. All four original pixel failures remain unresolved.

Blocked criteria are not waived. Run only the existing protected workflow/environment. New user authorization covers the requested tests; the environment reviewer must still release its unchanged gate. Provisioning a separate hosted staging project/deployment with ordinary fictional accounts is required for the hosted journey. Production or the unrelated Exchange project must never substitute for staging.
