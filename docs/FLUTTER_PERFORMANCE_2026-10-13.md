# Flutter performance implementation and verification

Scope: existing Proxo app on feat/proxolink-private-renderer-migration. Preserve PR7 Draft/Open/Unmerged, production and ProxoLink zero-pixel acceptance. This performance task supplements ongoing native pixel investigation. No overall performance-completion claim.

## Evidence-supported change

MainShell already lazily creates visited tabs and retains them in IndexedStack. It does not need a second navigation/cache architecture. However, IndexedStack alone does not mute tickers. Profile balance shine calls AnimationController.repeat() (profile_screen.dart); Home banner skeleton/highlight also repeats (proxo_banner.dart). No TickerMode scope existed in lib. Those retained hidden widget trees can continue receiving per-frame callbacks even though IndexedStack does not paint them.

Targeted change: a ProxoTabStack wraps each existing IndexedStack child in TickerMode(enabled: selected). MainShell uses it in the same location with the same index, lazy placeholders, children and keys. Routes/back/deep links, data subscriptions, timers, API requests, layouts, durations and visible animation definitions are unchanged. No dependencies, prefetch, cache or rendering-engine changes.

Exact product files: proxo_app/lib/main.dart and proxo_app/lib/widgets/proxo_tab_stack.dart. Test: proxo_app/test/proxo_tab_stack_test.dart. CI adds that test and targeted analysis in .github/workflows/proxolink-verify.yml.

Regression executes both original IndexedStack and production ProxoTabStack with real repeating AnimationControllers. It requires hidden callbacks to continue in the original, stop with the new scope, and resume when selected. Active callbacks must continue; the same State instance and400px scroll position survive switching; disposal must not throw. Ten16ms pumps are a deterministic workload, not physical frame/performance measurements. CI result pending at publication; benefit is not yet called verified.

## Required classification

| Optimization | Initial Status | Action Taken | Verification |
|---|---|---|---|
| Screen state preservation | Already Optimized at source level | Retain lazy IndexedStack and keys | Existing architecture inspected; new state/scroll regression queued |
| Navigation latency | Not Verified | No routing or delay changes | Profile-device tap-to-frame/readiness measurements unavailable |
| Data caching | Not Verified for performance | Preserve existing best-metrics10min/week caches and owner-scoped page controller | Source inspected; no new cache or invalidation changes |
| Selective preloading | Not Applicable without usage evidence | Preserve lazy first-visit construction | No speculative startup prefetch |
| Widget rebuilds | Needs Improvement: hidden ticker callbacks | Scope inactive tab tickers | Original/new controlled widget experiment queued |
| Navigation animations | Not Verified for frame cost | Preserve ProxoPageRoute and durations | Release build/full functional tests queued |
| Image optimization | Already Optimized at source level for inspected images | Preserve thumbnail DPR decode cap1179, profile avatar and Ad image decode bounds | Existing image/layout tests retained; no quality change |
| Lazy loading | Already Optimized at source level for inspected lists | Preserve Tools ListView.builder/PageStorageKey and Ad/Profile ListView.separated | No list rewrite |
| Background processing | Not Verified | No isolates introduced | No measured CPU-heavy workload justifies them |
| API/database performance | Not Verified | Preserve concurrent Home/Profile requests and existing listeners | No database/schema/RLS/backend changes |
| Rendering performance | Not Verified | Preserve engine/blur/shadow/clip configuration | Native pixel investigation is separate; not a speed benchmark |
| Memory and resource management | Needs Improvement: retained hidden animation work | Mute tickers while retaining existing disposal | State/scroll/disposal regression queued; heap/battery measurements unavailable |

Already Optimized here certifies the inspected mechanism only; device performance remains unmeasured. No blanket claim that all code in those categories is optimal. Existing ProxoLink controller owner/revision checks and auth-clearing logic remain intact. No measured duplicate-request bottleneck was established, so no network/cache change was made.

## Before/after measurements

| Metric | Before | After | Change |
|---|---|---|---|
| First/repeated navigation latency | Not measured | Not measured | Unknown |
| Tap-to-interactive readiness | Not measured | Not measured | Unknown |
| P50/P95 navigation latency | Not measured | Not measured | Unknown |
| UI/raster frame times and missed frames | Not measured in profile mode | Not measured | Unknown |
| Memory/CPU/battery | Not measured | Not measured | Unknown |
| Startup | Not measured | Not measured | Unknown |
| Hidden animation callbacks, controlled widget workload | CI pending | CI pending | Not claimed yet |

No local Flutter SDK, adb or KVM is available. CI can compile/analyze/run Flutter widget tests and the existing Android emulator gate; this is not a representative lower-end physical device or a Profile Mode/DevTools benchmark. Device profiling, repeated navigation under real/cached/loading conditions, heap/subscription inspection and authenticated account-switch runtime coverage remain Not Verified. Do not infer zero regressions or faster navigation from a successful build.

## Verification and remaining risks

Product change awaits current CI. Existing235 Flutter tests,153 backend tests,480 browser cases and native4b816 notices/refresh/choosers/browser passing evidence predate this change. They are not presented as final-source results. Native strict pixels and hosted isolated configuration remain unresolved independently.

Expected benefit: hidden animations stop requesting their own frames; no quantified latency/CPU/memory benefit claimed. Ticker elapsed time resumes using Flutter's standard TickerMode behavior; finite animations may have elapsed while inactive. Timers and realtime listeners remain untouched so data stays current. This does not claim all hidden background work is eliminated. Broad caching/preloading/isolate/renderer changes were rejected for lack of measured benefit. Existing data correctness and lifecycle gates remain mandatory.

## Observed source verification update

At `7524487a3807c4467dd8227ee08054f1e0a20534`, source run38332774448 passed analysis, the old/new notice regression and all237 Flutter tests, including both original IndexedStack and ProxoTabStack callback/state/scroll tests. The controlled widget benefit is verified; physical CPU, memory, frame and latency metrics remain unmeasured. Release checks were not executed after the NDK download failed with an invalid ZIP. Responsive stopped in the repaint diagnostic restoration contract; no full final-source native pass is claimed. No Home cache change was retained because the name field is not rendered; authenticated cache runtime coverage remains Not Verified.

At final executable f7112a8, source CI38388402541 passed all five jobs, including237 Flutter tests,480 browser cases and release/privacy/paired APK checks. Both ticker regressions pass. Native APK also passed; protected runtime is waiting, and no physical profiling metrics are available. The NDK download failure belongs to the earlier run only.
