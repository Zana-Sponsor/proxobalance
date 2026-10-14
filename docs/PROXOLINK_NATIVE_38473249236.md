# ProxoLink final-source native and hosted audit — run 38473249236

Status: **FAILED / NOT VERIFIED**. Pixel root cause: **NOT PROVEN**. Hosted blocker: **PROVEN missing isolated-staging configuration**. PR #7 remains Draft/Open/Unmerged; production publishing, customer writes and migrations remain unchanged.

## Pinned execution

| Item | Result |
|---|---|
| Protected run | [38473249236](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38473249236), attempt 1 |
| Executable revision | `8c1a353d527b4b9f45f7591515452ae3f0e025c4` |
| APK job | [115557446812](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38473249236/job/115557446812), SUCCESS |
| Native runtime job | [115559375465](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38473249236/job/115559375465), FAILURE after authorized execution |
| Hosted job | [115557447546](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38473249236/job/115557447546), FAILURE after authorized configuration check |
| Source CI | [38473249284](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38473249284), SUCCESS, all five jobs |
| Native artifact | [11859323347](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38473249236/artifacts/11859323347), 187,789,933 bytes, SHA-256 `1e67bc0f7bcc566ece62933c84d210cf21e6aa0ffb32521ca0d985762076fd67` |
| Hosted artifact | [11855625624](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38473249236/artifacts/11855625624), SHA-256 `adbf51e12affc686a1f6990dc56b505293a3211632f6aefb6a96e01d0e5dfc04` |
| Terminal time | 2026-10-13 23:57:36 UTC |

Both artifact digests and ZIP CRCs were independently verified. The native archive contains 2,560 files, including 2,543 PNGs.

## Acceptance results

| Gate | Result |
|---|---|
| Matrix behavior | 240 expected / 240 executed; 240 passed / 0 failed |
| FIRST captures | 240 candidate + 240 baseline; 0 missing cases/captures |
| Repeatability | 496 roles stable / 0 unstable, exactly 3 samples each: 480 acceptance + 16 reproduction |
| Strict FIRST parity | **232 exact / 8 failed; 10 changed pixels; maximum channel delta 1** |
| Diagnostic gate | PASS: 28 deep roles, 15 deep pairs, 16 fresh reproduction roles / 8 pairs |
| Legacy native live-preview chooser | 12/12 passed with actual thumbnail taps and large live WebView captures |
| Current Create selector | 12/12 passed with actual decoded-thumbnail selection |
| Tools external browser | 3/3 passed |
| Actual production screens | 16/16 passed, including all Home refresh cases |
| Security | 6/6 assertions true |
| Authentication | All 240 cases completed; no catalog HTTP 401 observed; exact renewal count not retained |

The unchanged strict validator failed only `native_pixel_parity_failed`. The independent audit recomputed all 240 FIRST pairs, 480 full-screen-to-crop correspondences, 960 acceptance repeats, 240 diff images and 32 reproduction repeats with zero audit errors.

## Exact FIRST failures

| Case | Crop → screen coordinate | Candidate RGB → baseline RGB | Classification |
|---|---|---|---|
| `pill-order-ku-portrait-768` | (380,222) → (596,440) | (220,227,240) → (220,226,240) | `.ubio` text over gradients |
| `pill-download-ku-portrait-768` | (583,90) → (799,308) | (236,241,254) → (235,241,254) | background gradient |
| `pill-download-ku-portrait-768` | (380,222) → (596,440) | (220,227,240) → (220,226,240) | `.ubio` text over gradients |
| `pill-mint-contact-ku-portrait-430` | (282,184) → (667,402) | (237,247,244) → (237,247,243) | `.uname` text over gradients |
| `pill-mint-order-ku-portrait-430` | (282,184) → (667,402) | (237,247,244) → (237,247,243) | `.uname` text over gradients |
| `pill-mint-order-ku-portrait-768` | (290,228) → (506,446) | (234,245,241) → (234,246,241) | `.ubio` text over gradients |
| `pill-mint-order-en-portrait-430` | (282,184) → (667,402) | (237,247,244) → (237,247,243) | `.uname` text over gradients |
| `pill-mint-order-en-portrait-768` | (290,228) → (506,446) | (234,245,241) → (234,246,241) | `.ubio` text over gradients |
| `pill-mint-download-ku-portrait-768` | (583,90) → (799,308) | (236,247,242) → (235,247,242) | background gradient |
| `pill-mint-download-ku-portrait-768` | (290,228) → (506,446) | (234,245,241) → (234,246,241) | `.ubio` text over gradients |

Every difference is one channel by one level. Historical 233/7 or 236/4 counts belong to older pinned runs and are not reused here.

## Controlled rendering diagnosis

Seven of the eight current failing cases were in the predefined deep set. Their Flutter SurfaceView candidate/baseline pairs reproduce all nine of those FIRST differences. After the separately instrumented repaint, the candidate/baseline pair is exact for all seven; post-observation native pairs and WebContents pairs are also exact. For each role, measured DOM/native geometry hashes remain unchanged across redraw, repaint and post-observation states.

Within those seven pairs:

- normalized input hashes match candidate to baseline;
- live CSS is byte-identical at 423,878 bytes, SHA-256 `20e445a66dcbe0edde7c4ab0cfada203ed1036896361143a8206536aaa88168c`;
- all three embedded-font identities and bodies match candidate to baseline;
- live HTML hashes differ and the safe normalized diff records one text/attribute difference per pair, two for `pill-mint-contact-ku-portrait-430`; every retained diff explicitly has `causal_effect_proven:false`;
- later WebContents readbacks differ from their own FIRST captures by roughly 309,508–343,528 pixels, so their exact candidate/baseline result does not substitute for FIRST acceptance;
- all eight fresh A/A candidate and baseline roles are stable, while fresh candidate/baseline reproduction retains the targeted one-pixel difference in five of eight cases.

The newly failing `pill-mint-download-ku-portrait-768` was not among the predefined deep pairs, so only its complete FIRST/repeat evidence exists. These observations localize the discrepancy to a state-sensitive paint/raster/composition path but do not isolate paint operation, raster CTM, clip, dither, color path, framebuffer, or a safe source-level causal variable. Therefore pixel root cause remains **NOT PROVEN**. No template/rendering patch, tolerance, masking, alternate-frame selection, retry-until-match, or blind rerun was applied.

## Hosted result

The hosted job executed its protected configuration check and failed closed with `staging_setting_required`. Native primary settings were present, credential values were not retained, and isolated staging was not configured. Exactly eight required settings were absent:

- `PROXO_STAGING_PROJECT_REF`
- `PROXO_STAGING_SUPABASE_URL`
- `PROXO_STAGING_BASE_URL`
- `PROXO_STAGING_ANON_KEY`
- `PROXO_STAGING_TEST_EMAIL`
- `PROXO_STAGING_TEST_PASSWORD`
- `PROXO_STAGING_OTHER_EMAIL`
- `PROXO_STAGING_OTHER_PASSWORD`

Second-account presence, account existence/authentication and the isolated hosted journeys were therefore not verified. No fallback to production occurred.

## Conclusion and next controlled step

This run materially closes the previous chooser, external-browser, actual-screen and Home-refresh gaps, but it does not meet final acceptance because eight FIRST pairs are non-exact and the hosted isolated-staging journey did not start.

A further protected Android execution is not justified with unchanged code. The next evidence-driven diagnostic must predefine one discriminating variable and capture the actual paint/raster CTM/clip/color path while separating individual observation operations from elapsed frames. It must preserve the first three acceptance frames, strict comparator and all 240 pairs. No product rendering fix should be proposed until that measurement establishes a causal chain. The hosted path requires the eight isolated-staging settings and two ordinary staging accounts; production must remain excluded.
