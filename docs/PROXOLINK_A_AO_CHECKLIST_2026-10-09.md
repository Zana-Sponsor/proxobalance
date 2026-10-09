# A–AO implementation and acceptance checklist

Status: **Pending**, not COMPLETE. Continue the current V6 branch; do not restart it.
Baseline audited: `e61bc1a93f4acdc7ad75e9f44e79e6d73f110f11`.
Specification: the attached `ProxoLink_FINAL_Tools_CreatePage_Supabase_HomeRefresh_Prompt_v4.md`, whose internal title says V3. The filename does not alter its requirements.

“Complete” below means the identified source/fixture criterion has evidence. It does not certify a blocked hosted/device criterion. Newly changed source awaits its own CI; prior passing tests apply only to their pinned revision. Source evidence: [40-item implementation report](PROXOLINK_TOOLS_CREATE_2026-10-09.md), [58 screenshots and hashes](evidence/proxolink-tools-2026-10-09/ui-evidence.json), source CI [37960639711](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37960639711). Latest native audit: [safe independent audit](evidence/proxolink-tools-continuation-2026-10-09/native-independent-audit.json).

| Requirement | Status | Evidence / remaining work |
|---|---|---|
| A: inspect branch, current architecture and actual schema before changes | Complete | Current V6 clone, PR #7 metadata, read-only hosted metadata query; current audit JSON. |
| A: columns/types/defaults/CHECK/UNIQUE/FKs/indexes | Complete | Current schema metadata and existing migrations inspected; existing owner/date index retained. |
| A: RLS/grants/triggers/functions/definers/storage/ad dependencies | Complete | Metadata and trigger-function bodies inspected read-only; no private bodies/credentials retained. |
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
| J: actual hosted moderation contract in isolated environment | Blocked | No isolated Supabase project connected; production lacks V6/moderation columns and must remain unchanged. |
| K: owner SELECT/INSERT/UPDATE/DELETE, immutable identity/owner | Complete | Existing RLS plus guard migrations, three disposable SQL suites and seven API lifecycles. |
| K: no anonymous management reads, no client owner trust | Complete | Current grants/owner policies, request tests and native security preflight. |
| K: immediate logout/account-switch isolation, stale-result denial | Pending | Existing controller/form tests pass; added upload owner capture/checks require current CI and device run. |
| L: confirmation, dependency-safe actual deletion, no hidden archive/detach | Complete | Safe API409/FK checks, existing RESTRICT FKs, owner DELETE tests. |
| L: duplicate dialog/submission prevention | Pending | Existing request busy gate; new per-page confirmation re-entry gate and widget test require CI. |
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
| S/K: account switch while upload is being prepared/completes | Pending | Owner captured before await, checked before storage and after completion; current CI required. |
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
| Z: prevent duplicate create routes | Pending | New route re-entry gate and rapid-tap regression require CI. |
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
| AA.11/AO37: complete HomeScreen vs Tools native motion evidence | Blocked | Existing visual evidence is the shared Home integration-pattern fixture, not complete HomeScreen/device capture. Requires real controlled HomeScreen session/device evidence. |
| AB: existing indexes inspected, measured query, no duplicates | Complete | Owner/date index, metadata-only EXPLAIN0.14..2.36; no new index. |
| AC: UI→controller→repository→auth API→DB/RLS layers, typed/safe errors | Complete | Existing architecture and boundary/error tests; new changes need their current CI. |
| AC: timeout/malformed/auth/idempotency/stale/delete/browser behavior | Complete | Service30s timeout and existing API/model/controller fixtures. |
| AD: private templates server-side; public data separate | Complete | Source privacy scan, compiled release scan and native boundary checks. |
| AE: exact footer across4×3, balanced smaller logo, legal relationship | Complete | Footer-only old/new hashes;84×24logo; twelve real renderer images. |
| AF: exactly12 full-page genuine high-DPI assets, no crop/stretch/upscale | Complete |1179×3120/DPR3 asset/hash manifest and image audit. |
| AF: physical-width decode quality and paired APK impact | Complete | Physical decode width;83,702,384→89,319,872bytes(+5,617,488),same-code prior CI evidence. |
| AG:9widths320/360/375/393/412/430/600/768/1024, Tools+3forms | Complete | Prior Flutter widths×scales1/1.6; renderer480cases. New UI changes require current CI. |
| AH: semantics/minimum touch targets/status text/text scaling | Complete |48/52px actions, semantic labels, adaptive240×scale stack threshold, selector scaling tests. |
| AI: Tools exact labels/content/actions/no forbidden features | Complete | Existing widget suite and inspected source/images. |
| AI: state/loading/error/delete/owner/browser/multilingual/responsive | Complete | Existing source tests; actual browser/device gate pending separately. |
| AJ: Create AppBar/back/sections/labels/providers/4styles/noWebView | Complete | Existing Create suite and all width images. |
| AJ: validation5s/double-submit/idempotency/local success | Complete | Existing notice and submit tests; new route/dialog test pending CI. |
| AK: generated distinct UUID/multiple pages/owner and immutable boundaries | Complete | Existing disposable PostgreSQL suites and API lifecycle evidence. |
| AK: stored moderation/trusted transitions/invalid values/provider/FK/grants | Complete | Tools moderation SQL suite, RLS suites and native read-only security preflight. |
| AK: real hosted isolated authenticated create/delete/moderation journey | Blocked | Separate isolated project+deployment and two ordinary fictional accounts are absent; production writes forbidden. |
| AL: native full-screen Create Ad vs ProxoLink notice comparison | Blocked | Shared-component evidence exists; complete native screen comparison is not executed. |
| AM: images320/393/430/768, Tools/multilingual/status/empty/error/Create/styles | Complete |58safe fictional fixture PNGs committed with dimensions and hashes. |
| AM: actual placement/padding/gaps/type/action stacking/rationale documented | Complete | Existing forty-item report, card/source measurements. |
| AN: no extra edit/archive/activate/menu/analytics/share/internal preview/types/templates/admin/table | Complete | Current reachable customer routes and negative tests; legacy compatibility editor appears only in debug verification, not Tools navigation. |
| Native: real Android35WebView240cases and complete first/repeat evidence | Complete | Latest run37960639713 executes240, captures240+240,480stable roles; independently recomputed. |
| Native: zero changed pixels across240first-frame comparisons | Blocked |236exact/4failed,4changedpixels,maxdelta1. Same-input fresh-view variation observed; root cause NOT PROVEN. No tolerance/mask/frame selection/template remedy. |
| Native: legacy chooser independent12cases | Pending | Last run0/12 due wrong mounted route; debug probe now mounts existing legacy editor directly. Assertions unchanged. |
| KVM: original commands/gate/failure retained, safe interrupted-step evidence | Pending | Baseline run passed KVM; new atomic checkpoints+8isolated checks pass locally; next protected run required for new native execution. |
| AO: all40report items and exact changed paths/finalSHA/current results | Pending | Existing report retained; continuation report/current CI/run/manifest will be finalized after verification. |
| AO/guardrails: PR7Draft/Open/Unmerged; production publishing/migrations/customer data untouched | Complete | Current PR metadata and read-only operations; no activation or production migration. |

Blocked criteria are not waived. Run only the existing protected workflow/environment. New user authorization covers the requested tests; the environment reviewer must still release its unchanged gate. Provisioning a separate hosted staging project/deployment with ordinary fictional accounts is required for the hosted journey. Production or the unrelated Exchange project must never substitute for staging.
