# ProxoLink native run 38265055827 — terminal evidence

**FAILED strict pixel acceptance. Notification fix VERIFIED on Android. Pixel root cause NOT PROVEN. Hosted verification BLOCKED by observed missing protected settings.**

## Pinned execution

- Native run: [38265055827](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38265055827), attempt 1
- Tested executable: `4b816fb4e62b55d09ea8951d82cd30536bd612cd`
- Runtime job: `114866813387`
- Source CI: [38265055650](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38265055650), all five jobs passed
- APK artifact: `11754162894`, upload SHA256 `72a536da97b2b4c8ddf8d2a8054d4457fda6d0179448a217a186d450086919da`
- Runtime evidence artifact: `11761854434`, independently verified SHA256 `96194a6c06e5d7f963eae87a9f581e2b684efa83d29aadddc08749eeeca2cdc0`
- Android 35 / WebView `124.0.6367.219`; KVM gate passed with API version 12; evidence upload succeeded.

The runtime artifact contains 2,502 files and 2,485 PNGs. Independent audit decoded every PNG and found no audit errors. It rechecked all 240 candidate/baseline FIRST pairs, 480 full-screen-to-crop correspondences, 960 acceptance repeat crops, 32 reproduction repeat crops, all 496 stability records, 240 diff PNG dimensions, 64 actual-screen captures and both 12-case chooser sets.

## Gate result

| Gate | Result |
|---|---|
| Behavior matrix | 240/240 passed |
| FIRST candidate/baseline captures | 240/240 each; none missing |
| Fixed capture stability | 480/480 acceptance roles stable; 16/16 reproduction roles stable |
| Strict pixels | 234/240 exact; 6 failed; 1,134 changed pixels; max channel delta 1 |
| Diagnostics | Passed; 26 deep roles and all required states present |
| Legacy chooser | 12/12 passed |
| Current Create chooser | 12/12 passed |
| Browser return | 3/3 passed |
| Refresh actual screens | 8/8 passed |
| Notice actual screens | 8/8 passed |

The independent gate rejected only `matrix` with `native_pixel_parity_failed`. Diagnostics, both choosers, browser, and actual-screen gates passed.

## Notification cause, change, and native verification

**Cause PROVEN:** insertion and five-second expiry started from the scheduled notice time, while the old `AnimationController` started entry only when the notice widget mounted. A delayed mount therefore consumed part of the lifecycle but restarted the 240 ms entry animation, producing incomplete opacity/size at the unchanged 400 ms assertion.

**Exact product change:** `AdValidationNotifications` now stores the scheduled entry timestamp and advances the existing controller from elapsed wall-clock time when mounted. The 90 ms stagger, 240 ms motion, five-second lifetime, decorations, visible-slot behavior, and shared Create Ad/ProxoLink UI remain unchanged. A queued notice receives a new scheduled timestamp when it enters a visible slot. The test deadline was not delayed.

**Verification:** source CI separately reproduced the old behavior from the prior source, passed the corrected behavior, and passed the complete 235-test Flutter suite. The protected Android run then passed all eight notice cases at widths 320/393/430/768 for both Create Ad and ProxoLink: two notices at full opacity/size at the unchanged 400 ms checkpoint, still present at 4,900 ms, and absent at 5,500 ms. Observed 400 ms samples were 400–433 ms.

## Strict pixel failures

| Case | Crop coordinate | Screen coordinate | Candidate → baseline | Classification |
|---|---:|---:|---|---|
| `pill-order-ku-portrait-768` | 380,222 | 596,440 | 220,227,240 → 220,226,240 | one green level; `.ubio` glyph/underlying background region |
| `pill-order-en-portrait-768` | 380,222 | 596,440 | 215,222,236 → 215,221,236 | one green level; `.ubio` glyph/underlying background region |
| `pill-mint-order-ku-portrait-430` | 282,184 | 667,402 | 237,247,244 → 237,247,243 | one blue level; overlapping background gradients |
| `pill-mint-order-ku-portrait-768` | 290,228 | 506,446 | 234,245,241 → 234,246,241 | one green level; overlapping background gradients |
| `pill-mint-order-en-portrait-430` | 282,184 | 667,402 | 237,247,244 → 237,247,243 | one blue level; overlapping background gradients |
| `pill-white-contact-ku-portrait-393` | region 41,379–352,396 | region 444,597–755,614 | 1,129 pixels, every channel delta ≤1 | WhatsApp button lower shadow band; bounds/style match |

The large white-template region is exactly below the WhatsApp button (`y=322.828125`, height 56) inside its declared `rgba(8,125,67,.36) 0 6px 14px -8px` shadow. Candidate/baseline button bounds, shadow text, CSS hash, font hash, normalized config-field hashes, DPR, WebView version, matrices, parent bounds and crop agree. The whole region is stable across all three FIRST samples.

## Controlled pixel result

The experiment added one predetermined same-document native redraw after FIRST and the existing SurfaceView observation, before any CDP operation. All 26/26 targeted candidate/baseline roles remained exactly equal to their own FIRST capture after that redraw. This rules out an extra native draw or elapsed-frame progression as the cause for the sampled roles.

Later bundled WebContents/CDP observation changed one pixel in 11/26 roles while DOM geometry/style snapshots remained stable. WebContents readbacks still differed from their own screen FIRST by 238,996–343,527 pixels. Fresh-view reproduction was stable within each role; five of eight fresh candidate/baseline comparisons retained a one-pixel difference, and one fresh candidate differed from its original by one pixel. These observations localize the mismatch to rendered output and prove that the diagnostic observation can itself perturb a later screen pixel, but they do **not** isolate the causal paint/raster variable.

The new 1,129-pixel white shadow failure was not one of the predetermined deep/reproduction targets. Its element and paint region are identified, but no post-FIRST single-operation intervention exists for that case. Therefore the exact box-shadow raster state, raster CTM/clip, color conversion/dither, or framebuffer variable remains unisolated. Pixel root cause and remedy are **NOT PROVEN**. No tolerance, mask, chosen later frame, template change, or speculative rendering fix is authorized by this evidence.

The next necessary controlled diagnostic is defined before execution: preserve the original 240 FIRST pairs unchanged, add this white case and the current five single-pixel cases to deep/fresh targets, then after acceptance capture one operation at a time. For the white case, disable only the WhatsApp `box-shadow`; the discriminating observation is exact candidate/baseline equality outside and inside the former band, followed by an exact restored-role capture. For `.ubio` cases, make only the glyph paint transparent; for mint cases, suppress only one background layer per capture. Also record in-page per-style/per-script hashes and a safe normalized DOM-structure hash so live source parity no longer depends on an empty CDP cached body. Source checks must pass before any new protected run.

## Hosted verification

[Hosted run 38264179020](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38264179020), commit `a7ace8348c05d3f7dcb84e4dbcb3a830ebb4b4b8`, job `114862024061`, executed the protected presence audit and failed closed. Native primary settings were present. The run directly observed these required isolated-staging settings absent:

- `PROXO_STAGING_PROJECT_REF`
- `PROXO_STAGING_SUPABASE_URL`
- `PROXO_STAGING_BASE_URL`
- `PROXO_STAGING_ANON_KEY`
- `PROXO_STAGING_TEST_EMAIL`
- `PROXO_STAGING_TEST_PASSWORD`
- `PROXO_STAGING_OTHER_EMAIL`
- `PROXO_STAGING_OTHER_PASSWORD`

Optional `PROXO_STAGING_VERCEL_BYPASS` was also absent. No credential values were retained. Account existence/authentication and isolated hosted execution were not attempted and are not inferred. Hosted artifact `11756526797` independently matches SHA256 `a07400dc4bd84687b53717cd3759fe0a67a7261cfb5fafe94408281ed19164bb`.

## Status

The notice implementation is verified and requires no further timing change. Full ProxoLink acceptance remains **NOT VERIFIED** because strict zero-pixel parity failed and hosted isolated credentials are not configured. PR 7 remains Draft/Open/Unmerged; production publishing, production writes, migrations, and customer data remain untouched.
