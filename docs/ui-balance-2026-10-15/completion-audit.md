# Final UI and retained-state audit

The requested UI work is implemented. The final audit found one additional data-loading defect in Profile: opening the screen and immediately refreshing could duplicate both the profile and wallet requests. Concurrent reads now share one pending request for the same owner/Auth snapshot. A later refresh still fetches fresh data. Returning successfully from the actual Edit Profile route forces a new read; late responses cannot overwrite that result, a realtime update, or another account's screen. No persistent balance cache was introduced.

Baseline: `83086805d987938958c1a133545c4f3d63340efe`. Final application change: `82b4fe3c8311e5ee5343965df7e41753c4b01e9a`. Verification harness: `6248e6a24569cfd8ba259e8bc8ec66e20619b39a`, with identical production library/assets/Android files/dependencies.

## Request coverage

| Requested behavior | Implementation and verification |
|---|---|
| Proportionate Auth mark | 84 × 24dp, checked at normal and 2× text; original screenshots in the [gallery](gallery.md). |
| Smaller official bank/wallet marks | 64 × 24dp contain envelope; official assets, equal status-line slots, aligned provider rows. |
| Balanced logout and navigation + | Logout paints at 24dp inside a 40dp well; plus is 28dp inside a 56dp control. Tap targets remain full size. |
| Uncluttered Auth and repaired phone entry | Decorative field/heading icons removed; functional Back/password visibility retained. Persistent +964, Kurdish/Arabic/Persian digit and paste normalization, mid-edit caret and narrow large-text wrapping checked. |
| Exactly three Home actions | Create Ad, Add Balance and Create Page; no duplicate quick-action button. |
| Admin-controlled banner text/colors | Firebase and Supabase content/fallback paths, contrast, localized copy, removal/cache invalidation and single-subscription lifecycle checked. No live admin content was changed. |
| Consistent rounded cards and text | Home banner/actions use 18dp corners and balanced multiline labels; actual bundled-font captures cover Sorani, Arabic and Badini at standard/narrow widths and 1×/2× text. |
| Overlapping 3D errors | Layered cards, front-only interaction, queue cleanup and sequential reading periods are tested. |
| Fast return without recreating tabs | Lazy retained tab State and scroll; inactive tickers muted; successful ad creation retains Home/Ads; repeated create taps cannot duplicate routes. |
| Cache and request discipline | Bounded banner bytes, public metrics cache, owner-scoped Tools cache, coalesced Home/Ads reads; this final pass also coalesces Profile/wallet reads and rejects late results. |
| One refresh design | All ten refresh surfaces use ProxoRefresh with the same 22dp spinner, 60dp reveal and spring motion. Loaded content survives refresh. |
| Smooth interaction and recovery | Pull cancellation, in-flight guards, safe completion after disposal, real keyboard/Back checks, and narrow Ads error-to-empty recovery. |

## Final Profile verification

The production Profile widget is mounted against fictional HTTP/WebSocket transports. The original source and the changed source use the same request-count test. Five final tests cover overlapping reads plus subsequent freshness, the actual edit route's success result, realtime profile/wallet updates arriving before an older response, an authenticated-owner change during pending reads, and disposal during a pending read.

The saved-edit test supplies the route's success result without sending a mutation. It verifies return navigation and data freshness, not delivery of a real email change or an actual bank transaction. All test transports reject non-GET database requests and outside hosts.

The first diagnostic run, [38804737364](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38804737364), passed the 20 current-screen captures and three existing routing tests, then correctly stopped at a mistaken baseline count: the test expected three profile reads, but observed four. The pinned GoTrue 2.27.2 implementation emits `tokenRefreshed` on recovery and replays it to new subscribers, adding a fourth read on the old source. The exact-count test now includes that real event; wallet reads remain three. The final listener also rejects historical Auth snapshots before starting a read. No request assertion was replaced with a tolerance or a broad inequality. The original diagnostic remains linked.

The five Profile tests passed at application source [82b4fe3](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38805323137): the same scenario measured profile reads **4 → 1**, wallet reads **3 → 1**, and one additional fresh request for each resource on the next manual refresh. State retention and late-response assertions all passed.

The APK analyzer then flagged two uses of an internal realtime `topic` member in the fictional test backend, [run 38805323216](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38805323216). The final harness records subscribed topics directly from its own simulated `phx_join`/`phx_leave` protocol frames. No analyzer rule or gate was disabled, and production code is identical to the passing Profile source.

Final-harness [Profile/chrome verification](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38805771337) passes 20 captures, three existing routing tests, the baseline reproduction and all five new Profile tests. Original [baseline log](profile-logs/profile-before.log) and [candidate log](profile-logs/profile-after.log) retain the measured counts.

Final-harness [polish verification](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38805771272) passes 90 capture cases and 44 behavior tests. Independently comparing all 123 top-level original PNGs with the prior completed proportions build gives **117 exactly equal frames**. The remaining six are notification screens whose fixtures use the current clock: every changed pixel lies within the laid-out timestamp text rectangles. Profile, Auth, balance, Home and navigation frames are exactly equal. The [complete pixel record](completion-pixel-comparison.json) preserves all six differences and actual timestamp strings; no mask or tolerance was used to declare equality.

The downloaded final `chrome-after` and `polish-after` archives passed independent SHA-256 and ZIP CRC verification. The [full regression/release gate](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38805771230) passes all five jobs, the [UI/receipt suite](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38805771359) passes, and the [credential-free APK build](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38805771273) passes. The protected hosted/runtime jobs remain skipped, not verified.

On [Android API35](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38805771265), narrow and tablet completed with 37 original PNGs, two actual Android taps and one real Back each. Phone's first attempt passed all in-app assertions, then the driver lost its VM service while collecting results and ADB reported the device offline. The driver watchdog did not time out. The [original device record](profile-logs/phone-attempt1-device.json) and [driver-log excerpt](profile-logs/phone-attempt1-driver-excerpt.log) retain this failure; only that phone job was retried. The targeted phone retry completed successfully with its 37 original PNGs and input/keyboard/Back observations. The workflow is now successful for all three configurations, with **111 original Android PNGs**, two real taps and one Back per configuration. All three final native archives passed independent SHA-256 and ZIP CRC checks, and every PNG was decoded and verified. Original [phone](completion-native/phone.json), [narrow](completion-native/narrow.json) and [tablet](completion-native/tablet.json) observations and device/input metadata are retained.

All six final-harness workflows are successful. Counts from different suites overlap and are not summed into a unique-test total. These debug emulator results verify behavior and rendering, not physical-device performance.

[Machine-readable final verification](completion-verification.json) retains exact commits, workflow IDs, request counts, archive hashes, native observations and limitations.

## Release validation still open

These UI checks do not certify physical-device P50/P95, frame cost, CPU/heap, manual TalkBack, or live authentication/payment/push delivery. Those need the relevant devices and isolated service setup. The older strict FIRST WebView pixel-parity investigation and isolated staging configuration remain open in PR #7; no tolerance or protection was weakened. The prepared ad-correction/notification migration still precedes release of that client change.

PR #7 remains Draft/Open/Unmerged. No production deployment or live migration was performed.
