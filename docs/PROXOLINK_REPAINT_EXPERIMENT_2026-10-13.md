# Native fix verification — run38265055827

Not COMPLETE. Tested executable `4b816fb4e62b55d09ea8951d82cd30536bd612cd`, branch `feat/proxolink-private-renderer-migration`. PR7 Draft/Open/Unmerged; production unchanged.

[Native run](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38265055827) executed after approval and finished with `native_pixel_parity_failed`. Approval is resolved for this run. [Native artifact11761854434](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38265055827/artifacts/11761854434),182,021,684bytes,2502 entries, independently verified SHA256 `96194a6c06e5d7f963eae87a9f581e2b684efa83d29aadddc08749eeeca2cdc0`; all ZIP CRCs passed.

| Check | Actual result |
|---|---|
| Native behavior |240/240 pass|
| FIRST-frame strict pixels |234/240 pass;6failed pairs,1134changed pixels,max channel delta1|
| Fixed same-view repeats |960/960 independently recomputed exact comparisons|
| Legacy chooser |12/12 pass|
| Current Create chooser |12/12 pass|
| Browser return |3/3 pass|
| Actual Home/Tools refresh |8/8 pass|
| Actual Ad/ProxoLink notices |8/8 pass; all four prior failures fixed in this run|
| Hosted configuration |Executed; BLOCKED by eight absent required staging names|

## Notification fix verified

The old product animation began on widget mounting while insertion/expiry timers had already started. The controlled CI experiment reproduced incomplete entry at400ms using actual cc52 source.4b816 changes `proxo_app/lib/widgets/ad_validation_notifications.dart` to advance entry from each notice's scheduled timestamp, with a fresh timestamp for a queued notice when its slot opens. It retains90ms stagger,240ms animation, five-second lifetime, decorations and shared component. No native deadline or opacity assertion changed.

All eight native cases now record opacity/size[1,1] at the scheduled400ms and4900ms observations, then zero notices at5500ms. Former failures: `actual-ad-error-320`, `actual-proxolink-error-393`, `actual-proxolink-error-430`, `actual-proxolink-error-768`. Actual400ms observation times were433,406,405,400ms respectively (see raw observations for authoritative values). These use actual production screens and real validation with fictional backend transports; they do not certify hosted authenticated journeys.

[Raw actual-screen result](evidence/proxolink-native-38265055827/actual-screens-results.json). All64 phase screenshots remain in the digest-verified native artifact, named `actual-*`. Source CI38265055650 also passed235 Flutter tests,153 backend tests,480 browser cases, database/RLS/security, edge checks and release privacy. [Source results and exact fix paths](PROXOLINK_FIX_PROGRESS_2026-10-12.md).

## Exact failed screenshot pairs

Coordinates are WebView-crop pixels. Each pair is `<case>-webview.png` versus `<case>-baseline-webview.png` in the native artifact; `<case>-diff.png` is included. No first-frame substitution or tolerance.

| Case | Changed pixels | Max channel delta | Crop location/bounds |
|---|---:|---:|---|
|pill-order-ku-portrait-768|1|1|(380,222)|
|pill-order-en-portrait-768|1|1|(380,222)|
|pill-mint-order-ku-portrait-430|1|1|(282,184)|
|pill-mint-order-ku-portrait-768|1|1|(290,228)|
|pill-mint-order-en-portrait-430|1|1|(282,184)|
|pill-white-contact-ku-portrait-393|1129|1|x45–348,y383–392|

[Independent audit with every changed coordinate and RGB pair](evidence/proxolink-native-38265055827/independent-pixel-audit.json). All240 pairs and960 repeat comparisons were recomputed with Pillow/NumPy, independently of the Node verifier. This is a different failure set from38070780315. Three former failures now pass; one new white-style case fails. Its1129 pixels must not be described as another one-pixel mismatch.

## Controlled cause investigation and next executable experiment

Native redraw experiment: all26 instrumented role captures were pixel-identical before/after the extra same-document native draw. The subsequent CDP/WebContents readback coincided with changes in11/26 native surfaces. One of16 fresh same-role A/A comparisons changed a pixel. [Compact observations](evidence/proxolink-native-38265055827/controlled-comparisons.json). This excludes an extra native redraw as an effective remedy in these cases; it does not establish a complete causal explanation or justify modifying templates.

Next diagnostic code adds a fixed WebContents repaint after all three acceptance captures and the existing native redraw, before CDP. It temporarily hides/restores the document root, preserves the exact original inline attribute, requires completed animation callbacks/native draw and identical recorded geometry, and captures exactly one additional diagnostic frame. FIRST remains acceptance input. A real Chromium contract checks restoration of absent/empty/important styles, scroll and exact fixture pixels. Deep targets expand13→14 to instrument the new white393 failure. Existing240 matrix, zero-pixel threshold and passing flow assertions remain unchanged. This is an experiment, not a pixel fix; no speculative template/GPU change has been made.

## Actual hosted blocker

[Hosted38264179020](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38264179020) was triggered by `[proxolink-hosted-verification]` and executed in `proxolink-preview-verification`. Job114862024061 observed `staging_setting_required`, not a skipped marker or approval problem. [Artifact11756526797](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38264179020/artifacts/11756526797) independently verified SHA256 `a07400dc4bd84687b53717cd3759fe0a67a7261cfb5fafe94408281ed19164bb`, CRC passed. [Presence-only evidence](evidence/proxolink-native-38265055827/protected-configuration.json).

Required absent names: `PROXO_STAGING_PROJECT_REF`, `PROXO_STAGING_SUPABASE_URL`, `PROXO_STAGING_BASE_URL`, `PROXO_STAGING_ANON_KEY`, `PROXO_STAGING_TEST_EMAIL`, `PROXO_STAGING_TEST_PASSWORD`, `PROXO_STAGING_OTHER_EMAIL`, `PROXO_STAGING_OTHER_PASSWORD`. Configure isolated project/preview and two ordinary-account settings in that environment; first three accept variables or secrets, credentials are secrets. Optional `PROXO_STAGING_VERCEL_BYPASS` is absent too, but not in the eight required failures. All four existing native settings were present and native authentication executed. Account existence is not inferred from inaccessible staging settings. No credentials are retained.

## Remaining acceptance

Pending: native pixel cause, evidence-supported remedy, affected checks and full final native pass. Blocked: isolated hosted journeys until the observed eight settings are supplied. Notification lifecycle is now verified at4b816. Keep production, zero-pixel acceptance and PR state unchanged. This report supplements the40-item AO report; historical waiting statuses are superseded by these terminal results.
