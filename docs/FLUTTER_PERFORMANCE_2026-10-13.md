# Flutter performance — implementation and evidence

Status: targeted implementation in progress; physical runtime performance **Not Verified**. This report addresses the full18-section performance specification independently of ProxoLink pixel acceptance. Branch `feat/proxolink-private-renderer-migration`; PR7 stays Draft/Open/Unmerged and production stays unchanged.

## Scope inspected

Navigation/startup: `main.dart`, `theme/app_theme.dart`. Screens: Home, Ad, Tools, Profile. Data/state: `controllers/proxolink_pages_controller.dart`, `services/best_metrics_service.dart`, Ad loading/silent-sync/pagination, Profile profile/wallet loaders. Images/resources: `widgets/proxo_banner.dart`, Profile avatar, Ad thumbnails, `widgets/proxolink_design_selector.dart`, refresh/controller disposal. Existing source is retained unless a concrete defect is identified.

MainShell lazily instantiates visited tabs and retains their State/scroll with stable keys. Tab switching itself does not await requests. **Retention does not mean zero requests or zero rebuilds:** Home intentionally refreshes after260ms on activation; Ad starts a deduplicated silent sync on activation. Those freshness behaviors remain. Ad-create success intentionally changes Home/Ad keys. MainShell rebuilds child configurations when the selected index changes; no measured expensive subtree rebuild justifies caching widget instances or changing callbacks.

Startup awaits locale, Supabase, Firebase and notification initialization before runApp. No startup timing was collected, so ordering was not changed. AuthGate routing replaces routes on qualifying authentication events; optimizing it without authenticated lifecycle evidence would risk navigation/security behavior. Existing ProxoPageRoute push/pop durations, Cupertino behavior, back stack and deep-link handlers are retained.

## Optimization-status table

“Already Optimized” below applies to a specific verified mechanism, not a claim that device speed is optimal. Where only source inspection exists, effectiveness remains Not Verified.

| Optimization | Initial Status | Action Taken | Verification |
|---|---|---|---|
| Screen state preservation | Already Optimized for retained-tab mechanism | Keep lazy visited-tab stack, stable keys and refresh handles | Original/new ticker tests assert identical State and400px scroll after return; full app/auth navigation not physically profiled |
| Navigation latency | Not Verified | Preserve immediate tab dispatch and background freshness requests | No reliable tap-to-first-frame/readiness samples; no speed claim |
| Data caching | Not Verified for overall effectiveness; unused Home name fetch Needs Improvement | Remove fetch/cache of a name that has no consumers; preserve all used caches | Controlled original/new request-count test; public metrics TTL/week cache and owner/revision page guards inspected |
| Selective preloading | Not Applicable for additional broad preloading without evidence | Preserve lazy tab construction and existing banner prewarm | No usage data supports extra prefetch; banner memory cost still needs profiling |
| Widget rebuilds | Needs Improvement for hidden ticker work and unused Home setState | Mute inactive tab tickers; remove unused profile-name setState | Controlled callback counts and Home request regression; no claim all parent rebuilds eliminated |
| Navigation animations | Not Verified for device frame cost | Preserve durations, curves, visible animations, routes | Existing functional/visual gates retained; profile frame traces unavailable |
| Image optimization | Not Verified app-wide | Preserve DPR decode sizing for avatar/Ad/1179px-capped thumbnails; no quality changes | Source inspection and existing image tests; banner original-size decoding and static byte retention require heap evidence |
| Lazy loading | Already Optimized for inspected list mechanisms | Retain Tools builder, Ad pagination/loading guard and separated list, Profile separated list | Source mechanisms and existing list/state tests; rapid-scroll frame cost unmeasured |
| Background processing | Already Optimized for banner base64 decode mechanism; other workloads Not Verified | Retain existing compute-based decode; no new isolates | Source inspection; no CPU trace establishes another isolate candidate |
| API/database performance | Needs Improvement for banner subscription churn and unused Home query | Reuse one mounted banner subscription; remove unused query | Actual production widget with fictional HTTP/WebSocket transport reproduces lifecycle; backend/schema/RLS unchanged |
| Rendering performance | Not Verified | Preserve current explicit Impeller=true, hardware acceleration, blur, shadows and clipping | Native pixel work is separate; no runtime speed inference from pixels |
| Memory and resource management | Needs Improvement for hidden tickers and post-dispose subscription creation | Scope tickers; prevent channel creation after dispose | Lifecycle regression; heap/battery/total subscription usage remain unmeasured |

## Targeted changes and rationale

1. **Hidden tab tickers (implemented before this continuation).** Profile shine and Home animations use repeating controllers. Original IndexedStack retains active tickers in hidden tabs. `ProxoTabStack` wraps the same children in `TickerMode(enabled: selected)`. Tests compare the original stack and production wrapper for ten16ms fake-clock pumps, active callbacks, hidden callbacks, retained State/scroll, reactivation and disposal. No animation duration/curve or visible design was changed. Timers and realtime remain active by design; this is not a claim that all hidden work stops. Finite animations follow standard elapsed-time behavior when unmuted.
2. **Banner fallback channel lifecycle.** `_loadSupa` used to create a subscription after every response, including responses finishing after disposal. Realtime callback invokes that same loader. The minimal fix checks mounted before creating a channel and assigns with `??=` so data reloads retain the existing subscription. Disposal continues unsubscribing it. Real widget tests use a pending response released after unmount and an actual simulated Postgres-change frame; they compare the original source and the new source. No new cache/client/service or data policy.
3. **Unused Home profile request.** `_userName` and global `_sCachedUserName` had no readers outside their own loader. `_loadUser` queried profiles and rebuilt Home to store this unused value. Remove only those dead fields, loader and its initialization/refresh calls. Actual Home fixture checks original/new profile-request counts. Ads, featured metrics, notifications, popups and all displayed content remain unchanged. This removes unnecessary work and unused personal-data retention, not an authorization mechanism.

Exact cumulative performance paths:

- `proxo_app/lib/main.dart` — use retained-tab ticker scope (earlier change).
- `proxo_app/lib/widgets/proxo_tab_stack.dart` — scope inactive tickers (earlier change).
- `proxo_app/lib/widgets/proxo_banner.dart` — mounted guard and one owned subscription.
- `proxo_app/lib/screens/home_screen.dart` — remove unused name query/cache/setState.
- `proxo_app/test/proxo_tab_stack_test.dart` — original/new lifecycle and callback counts.
- `proxo_app/test/proxo_banner_lifecycle_test.dart` — original/new response-disposal and realtime-reload scenarios.
- `proxo_app/test/proxolink_actual_screens_test.dart` — original/new actual Home request regression.
- `proxo_app/integration_test/support/actual_screen_fixtures.dart` — bounded fictional banner transport/events/counters.
- `.github/workflows/proxolink-verify.yml` — original-source reproductions, restored new-source assertions and existing full suite.
- This report — evidence and limits; documentation is not an optimization.

## Caching, subscriptions and cleanup findings

Public featured metrics have separate five-row preview and100-row weekly caches, ten-minute TTL/week boundary and explicit invalidation. Their data source is public; no new private cache was added. ProxoLink pages retain owner-scoped data, reject late owner/revision responses, replace deleted rows authoritatively, and cancel polling/auth listeners on disposal. Ad silent sync reuses an in-flight Future and pagination guards duplicate loads. Those mechanisms are retained.

Home disposes its observer, intro/scroll controllers and both realtime channels. Ad removes its scroll listener, controllers and metrics channel. Profile disposes four ValueNotifiers, scroll controller, auth listener and two channels. Tools disposes its controller/listeners, scroll, notices and local refresh controller. This source inspection is not a heap-leak certification or proof of all account-switch races.

Banner Firebase subscription is intentionally process-wide. It captures methods on its original state; static image-byte maps have no evident eviction bound, and slider timers continue while hidden. These are source-level retention/background-work risks, **not quantified device bottlenecks**. No broad singleton/cache rewrite, timer schedule change or reduced image quality was made without evidence of acceptable behavior and resource cost. Profile loaders check mounted but full cross-account/device race coverage remains unverified; existing ProxoLink tests do not prove all app screens safe.

## Before/after evidence

| Metric | Before | After | Interpretation |
|---|---|---|---|
| Tap-to-first-visible-frame | Not measured | Not measured | No reliable device presentation timestamps |
| Tap-to-interactive readiness | Not measured | Not measured | No real input/response timing samples |
| Initial/repeated/cached/loading navigation mean/P50/P95 | Not measured | Not measured | No percentages or estimates claimed |
| UI/raster time, missed frames | Not measured in profile mode | Not measured | Build/widget/pixel gates are not frame benchmarks |
| CPU, heap, retained memory, battery | Not measured | Not measured | No quantified resource saving claimed |
| Startup time | Not measured | Not measured | Existing initialization order preserved |
| Hidden callback count over10 controlled16ms pumps | Awaiting recorded result | Awaiting recorded result | Automated operation count only; not160ms of physical workload |
| Banner joins after one realtime reload | Awaiting recorded result | Awaiting recorded result | Fictional transport operation count, not network latency |
| Banner subscription after disposing pending load | Awaiting recorded result | Awaiting recorded result | Resource-lifecycle assertion, not heap measurement |
| Actual Home unused profiles request on first mount | Awaiting recorded result | Awaiting recorded result | Eliminated request count, not measured screen speed |

## Profiling availability and readiness definitions

The current workspace has no Flutter/Dart SDK, adb, /dev/kvm or attached physical Android device. CI supplies Flutter widget/release tooling and an Android emulator for the separate native gate, but no app profile-mode before/after navigation trace or representative lower-end device is available. The native verification APK is not a performance benchmark. No post-frame callback, pumpAndSettle time, test duration or APK size is substituted for real tap-to-present/readiness latency.

For eventual same-device profile comparisons, readiness must be defined consistently:

| Destination | First frame | Interactive readiness |
|---|---|---|
| Home | First presented destination frame | Quick action/navigation accepts input; ads/background freshness need not finish |
| Ads | First presented list/loading/error shell | Available filter/navigation responds; data-dependent row interaction measured separately |
| Tools | First presented cards/loading/error shell | Create/back/navigation responds; Preview/Delete require the relevant loaded row |
| Profile | First presented profile/loading shell | Available settings/navigation responds; mutations keep existing data/auth requirements |

Measure tap input event to actual destination presentation, and separately to an observed response to the defined interaction. Collect initial, repeated, back-return, frequently switched, cached and controlled-loading scenarios on the same device/build/account/data/refresh rate. Compare original/new ordering across enough repetitions, retain raw samples, mean/P50/P95, UI/raster traces and memory/CPU observations. Until performed these are **unexecuted measurement requirements**, not results.

## Verification status and independent remaining work

Baseline f7112a8 source CI38388402541 passed237 Flutter tests,153 backend tests,480 browser cases, database/RLS, edge and release/privacy checks. It verifies the earlier ticker implementation functionally, not runtime speed. New banner/Home changes require their own final-source results below.

No performance improvement is runtime-profile verified. Expected benefits are fewer hidden tick callbacks, no unnecessary banner re-subscription/orphan channel, and no unused Home profile fetch/rebuild. Functional fixture evidence must be reported separately from device performance.

ProxoLink pixel cause/remedy and final native acceptance remain tracked in the A–AO checklist. Last completed native4b816 has234/240 exact pairs; notices/refresh/browser/selectors pass. New f7112a8 run38388402520 was requested separately; its status must not substitute for final performance-source runtime testing. Hosted configuration was observed missing eight staging settings in38264179020. Neither blocker prevents source inspection and functional performance regressions here. Production and PR state remain protected.
