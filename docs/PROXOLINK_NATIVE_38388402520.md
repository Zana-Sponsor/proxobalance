# Native run 38388402520 — observed result

Tested executable: `f7112a8f069e1b8edad036254f6dbaa6aec7d671`.
[Run](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38388402520) / [artifact 11813922930](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38388402520/artifacts/11813922930).
Approval is no longer blocking: native runtime executed and failed. This is not verification of subsequent performance commits.

Downloaded ZIP SHA-256 independently matches GitHub's digest: `80cf2466e601cf2bd29a5071331fd57898ec89f95cb611bbbdd2ec81337aac8f`. ZIP CRC passed. All 240 FIRST-frame screenshot pairs were independently decoded to RGB and compared using integer channel differences; stored changed-pixel/max-delta results match every pair. No threshold or replacement frame was used.

| Gate | Actual result |
|---|---|
| Behavioral matrix | Passed 240/240 |
| FIRST-frame exact pixels | Failed: 233/240 exact, seven failed pairs, eight changed pixels, maximum channel delta 1 |
| Browser returns | Passed 3/3, pause/resume, stable row/scroll, one collection read; fictional public content |
| Legacy chooser | Passed 12/12 |
| Current Create Page | Passed 12/12 |
| Actual-screen notices | Passed 8/8, including visibility and automatic exit |
| Actual-screen refresh | Failed: 7/8 passed; actual-home-refresh-320 failed |
| Diagnostic completeness | Passed |
| Hosted journey | Not executed in this native-only run; separate last presence check found missing staging configuration |

Coordinates below are relative to the compared viewport, zero-based. These are this run's failures, not a historical list.

| Case | Changed pixels | Maximum channel delta | Locations (x, y) |
|---|---:|---:|---|
| pill-contact-en-portrait-768 | 1 | 1 | (380, 222) |
| pill-order-ku-portrait-768 | 1 | 1 | (380, 222) |
| pill-mint-contact-ku-portrait-430 | 1 | 1 | (282, 184) |
| pill-mint-contact-en-portrait-430 | 1 | 1 | (282, 184) |
| pill-mint-order-ku-portrait-768 | 1 | 1 | (290, 228) |
| pill-mint-order-en-portrait-768 | 1 | 1 | (290, 228) |
| pill-mint-download-ku-portrait-768 | 2 | 1 | (583, 90), (290, 228) |

## Controlled observations and remaining work

All 44 initial/reproduction diagnostic roles retained identical pixels after ordinary native redraw. Forced repaint with exact inline-style restoration changed 14 roles by one pixel each; the post-WebContents capture retained those repaint changes. Identical-source fresh candidate comparisons changed one pixel in three of eight predetermined reproductions. This proves some variation can occur without a template-source change. It does not isolate a complete cause or prove that repaint is a correct acceptance normalization. Original FIRST frames remain authoritative; no retry, best-frame choice or tolerance is introduced. Two new failure cases lack the historical targeted repaint diagnostics. The remaining work is a controlled rasterization intervention covering the current failures, followed by the unchanged full gate. No speculative template change was made.

`actual-home-refresh-320` observed offset 0 at104ms while refreshing, then offset51.72136085594889 at302ms. All other refresh cases passed. The existing100/300ms assertions remain unchanged. The recorded values alone do not establish whether the first-frame scheduling delay is product or harness behavior; reproduce that phase with frame/spring-start observations before changing timing. Notification deadlines remain passing and unchanged.

Local profiling/native execution is unavailable (no Flutter/adb/KVM/device). CI native execution is available through its configured environment. Full native verification against the final performance executable remains Pending, not passed by the older result.

Raw per-gate results and independently recomputed coordinates are retained in `docs/evidence/proxolink-native-38388402520/`. Native artifact screenshots remain the primary full visual evidence.

## Hosted verification scope

The configured environment is `proxolink-preview-verification`. Ordinary pushes omit the `[proxolink-hosted-verification]` marker and skip that job by its explicit repository/branch/message condition. Commit `8c1a353d527b4b9f45f7591515452ae3f0e025c4` includes both existing verification markers and requests native plus hosted checks in run38473249236. No condition or environment protection was relaxed.

The last executed hosted configuration check (run38264179020) reported the following absent settings: `PROXO_STAGING_PROJECT_REF`, `PROXO_STAGING_SUPABASE_URL`, `PROXO_STAGING_BASE_URL`, `PROXO_STAGING_ANON_KEY`, `PROXO_STAGING_TEST_EMAIL`, `PROXO_STAGING_TEST_PASSWORD`, `PROXO_STAGING_OTHER_EMAIL`, `PROXO_STAGING_OTHER_PASSWORD`. The first three support environment variables or secrets; the remaining five are secrets. They must identify an isolated staging target and two ordinary test accounts. This is a dated observation, not a claim about the new run before it executes. No secret values are recorded.

New run38473249236 status observed2026-10-13T21:52UTC: native APK building; hosted job115557447546 waiting. GitHub pending_deployments explicitly lists environment23442858482 (`proxolink-preview-verification`), wait_timer0 and required reviewer `Zana-Sponsor`. This is a new run-specific review, not the obsolete diagnosis for the completed f711 run. No approval-write operation is exposed by the connected GitHub tools; protections remain unchanged. Hosted presence has not re-executed, so no new missing-setting claim is made.

Updated new-run status2026-10-13T21:55UTC: native APK job115557446812 passed; native-runtime115559375465 and hosted115557447546 are both waiting, not executed. The old f711 runtime failure remains the most recent completed native evidence. A successful APK does not certify either gate.
