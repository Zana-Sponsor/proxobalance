# ProxoLink V6 executed evidence

[Execution report](../../PROXOLINK_V6_EXECUTION_2026-10-07.md) · [Last executed Android summary](native-1dca41a/summary.json) · [Capture inventory](native-1dca41a/evidence-inventory.json) · [Validator replay](native-1dca41a/validator-replay.json) · [Exact correction files](native-capture-correction-files.json) · [Evidence paths](evidence-files.json).

| Evidence | Status | Scope |
|---|---|---|
| [Source CI](ci-results.json) | VERIFIED at 5bf533b | Run 37694585981: backend 121, Flutter 189, responsive 480, DB/RLS, 7 API lifecycles, edge functions and release APK privacy |
| [Last executed Android results](native-results.json) | FAILED | Run 37669328941, attempt 1: expected 240; candidate 240, baseline 240, missing 0; 240 behavior passed, 0 failed; 235 exact pixel pairs, 5 failed |
| [CURRENT native evidence](native-1dca41a/summary.json) | Inspected | Downloaded artifact digest verified; safe per-case JSON, all five failed crop/baseline/diff triples and exact RGB/coordinate diagnosis |
| Native capture correction | BLOCKED on approval | Run 37694585964, attempt 3, 5bf533b: successful APK reused; runtime job 113055174154 waiting in proxolink-preview-verification for Zana-Sponsor. Expected 240, executed 0, candidate/baseline 0/0, 240 per role pending, pixels NOT EXECUTED |
| Native chooser → large WebView | NOT VERIFIED | 0 native chooser cases; probe directly renders production ProxoLinkPreview |
| [Prepared design preservation](prepared-design-preservation.json) | VERIFIED | Four original CSS blocks remain identical; no product template or thumbnail change |
| [Isolated staging](staging-results.json) | Historical BLOCKED | Separate target still required; no new staging work in this native-only continuation |

Current artifact [11513497183](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37669328941/artifacts/11513497183) has 1,204 files, 79,889,382 bytes and verified SHA-256 `10b54dbe2e62104f9b12f8476e5962ce6ddcb7e6f8e3f80eacd92451ce7f6417`; expires 2026-10-14 at 21:44:57 UTC. Only allowlisted per-case JSON and the five failed comparison triples are retained in native-1dca41a; the original archive remains linked.

The 1,200 PNGs and all 240 metadata/pixel entries are complete. [Filename/hash/dimension manifest](native-1dca41a/capture-file-manifest.json) and [480 unique safe capture acknowledgements](native-1dca41a/capture-log-index.json) identify every required case; missing/invalid/skipped lists are empty. The unchanged original validator replay isolates five failed pixel predicates as the cause of the misleading native_evidence_incomplete error. The absent success-only results.json was a consequence, and the recovered early ADB-offline event left no missing capture.

The correction preserves strict zero differences, adds native draw acknowledgement and requires three predetermined exact captures per role without matching-frame searches, tolerances or averaging. Its Android pixel remedy is unverified until authorized runtime execution. The same run's attempt 1 NDK-download failure recovered with a failed-job retry; neither the workflow nor protected environment was replaced or bypassed.

The previous complete V6 run 37647222280 is separately FAILED (240 behavior passes; 233 exact / 7 failed pixel pairs). The earlier 169-case partial run, native-first-357aa00, native-partial-947dc34 and approval screenshots are historical only. V5 results are not current V6 evidence.

The thumbnail implementation stays complete: 12 real inert server-renderer PNGs, all four formal Kurdish labels and the large live WebView preview. Widget chooser checks and Chromium screenshots are separately scoped, not Android chooser certification.

No credentials, bearer capabilities, runtime configuration, customer fixtures, private storage metadata or raw runtime logs are retained. Original CSS/assets and zero changed-pixel acceptance are preserved. PR #7 stays Draft/open/unmerged.

Attempt 2 of the corrected run started after authorized approval but stopped at KVM setup before the emulator. It executed 0 native cases/captures/pixel pairs, and evidence upload failed because no runtime evidence directory existed. [Safe infrastructure diagnosis](native-5bf533b-attempt2-infrastructure.json) records the exact failure and uncertainty: the logs do not prove why KVM readiness failed. Only the failed job was retried in the same run; attempt 3 again awaits authorized approval. No source/workflow/acceptance/protection edit was made for this retry. Documentation-head source CI 37696341020 at 4b9e6fa passed all five jobs.
