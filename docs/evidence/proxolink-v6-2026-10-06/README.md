# ProxoLink V6 executed evidence

[Execution report](../../PROXOLINK_V6_EXECUTION_2026-10-07.md) · [CURRENT Android summary](native-1dca41a/summary.json) · [Capture diagnosis](native-1dca41a/diagnosis.json) · [Exact correction files](native-capture-correction-files.json) · [Evidence paths](evidence-files.json).

| Evidence | Status | Scope |
|---|---|---|
| [Source CI](ci-results.json) | VERIFIED at 1dca41a | Run 37669328976: backend 120, Flutter 189, responsive 480, DB/RLS and release APK privacy; correction CI pending |
| [CURRENT Android results](native-results.json) | FAILED | Run 37669328941, attempt 1: 240 behavior executed/passed, 0 failed; 235/240 exact pixel pairs, 5 failed |
| [CURRENT native evidence](native-1dca41a/summary.json) | Inspected | Downloaded artifact digest verified; safe per-case JSON, all five failed crop/baseline/diff triples and exact RGB/coordinate diagnosis |
| Native capture correction | PENDING protected rerun | Debug-only native paint barrier and three independently exact captures per role; zero difference gate unchanged |
| Native chooser → large WebView | NOT VERIFIED | 0 native chooser cases; probe directly renders production ProxoLinkPreview |
| [Prepared design preservation](prepared-design-preservation.json) | VERIFIED | Four original CSS blocks remain identical; no product template or thumbnail change |
| [Isolated staging](staging-results.json) | Historical BLOCKED | Separate target still required; no new staging work in this native-only continuation |

Current artifact [11513497183](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37669328941/artifacts/11513497183) has 1,204 files, 79,889,382 bytes and verified SHA-256 `10b54dbe2e62104f9b12f8476e5962ce6ddcb7e6f8e3f80eacd92451ce7f6417`; expires 2026-10-14 at 21:44:57 UTC. Only allowlisted per-case JSON and the five failed comparison triples are retained in native-1dca41a; the original archive remains linked.

The previous complete V6 run 37647222280 is separately FAILED (240 behavior passes; 233 exact / 7 failed pixel pairs). The earlier 169-case partial run, native-first-357aa00, native-partial-947dc34 and approval screenshots are historical only. V5 results are not current V6 evidence.

The thumbnail implementation stays complete: 12 real inert server-renderer PNGs, all four formal Kurdish labels and the large live WebView preview. Widget chooser checks and Chromium screenshots are separately scoped, not Android chooser certification.

No credentials, bearer capabilities, runtime configuration, customer fixtures, private storage metadata or raw runtime logs are retained. Original CSS/assets and zero changed-pixel acceptance are preserved. PR #7 stays Draft/open/unmerged.
