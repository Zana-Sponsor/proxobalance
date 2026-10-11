# Completed native run 38070780315 — audited results

Overall acceptance: **Pending, not COMPLETE**. This report supersedes the approval, runtime, workspace and native-count entries in the earlier October11 report. Approval succeeded; the run is terminal. No approval problem is diagnosed for this completed run.

- Branch: `feat/proxolink-private-renderer-migration`.
- Tested executable: `cc52ca4c26a291677f935ff50cf13dd43cfcd5d5`.
- Publication parent: `bb1ae52ba1dc49c9e27cbb4a885fe373dffcb5b4`. This continuation changes evidence/docs only; final publication SHA is recorded in PR7.
- [Run, attempt2](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38070780315/attempts/2); native job114307708767; [artifact11707438523](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38070780315/artifacts/11707438523).
- Artifact:175,771,663bytes,2,454ZIP entries. SHA256 independently recomputed: `9c3d3fc79277834b02af99e6c5da992eef4f00734d0839b6365ef527ab9d769d`, exactly matches GitHub. Every ZIP CRC passed.
- PNGs independently decoded with Pillow/NumPy:all240 first-frame pairs and960 within-view repeats checked. Comparator threshold remains exactly zero. Twenty-four controlled fresh-view comparisons also independently recomputed.

| Result group | Status | Actual outcome |
|---|---|---|
| APK / secure setup / KVM | Complete | Passed; native run executed. |
| Read-only authentication/RLS/private-template boundary | Complete | Passed. Does not certify hosted V6 mutations. |
| Live preview response security | Complete |4/4 passed. |
| Native behavior matrix | Complete |240/240 passed. |
| Strict first-frame pixels | Pending — failed |232/240 exact;8 failed pairs;8 changed pixels; maximum channel delta1. |
| Within-view repeat stability | Complete |480 acceptance roles×2 repeat comparisons=960 exact comparisons. All496 roles including16 reproduction roles recorded stable. |
| Legacy live-WebView chooser | Complete |12/12 passed, independent gate passed. |
| Current Create Page chooser | Complete |12/12 passed; real native input, decoded thumbnail, changed/selected state, provider/type match, no WebView or preview request. cc52 exact Kurdish provider assertions executed. |
| External browser return | Complete for fixture lifecycle |3/3 passed with real pause/resume, same row element, scroll offset356, row(401,804),one total collection read. Public content explicitly NOT verified; repository fictional. |
| Actual production screen refresh | Complete for fixture motion |8/8 Home/Tools cases passed at320/393/430/768; one added read, same scroll element, spinner closed, settled offset0. |
| Actual production screen notices | Pending — failed |4/8 passed; four entry-phase failures below. All eight had two visible notices at4900ms and none at5500ms. |
| Actual-screen captures | Complete |64/64 whole-surface PNGs retained; all16 flows executed,12passed/4failed. Callback input for notices is explicitly not ADB input. |
| Isolated hosted verification | Blocked / not executed |Job-level marker condition false; zero steps executed. No current hosted configuration check or lifecycle result. |

Exact failed pairs (coordinates are zero-based x,y; viewport origin included in screen coordinate). Every listed pair differs by exactly one pixel and one channel level. Links retain original unmodified crops and diff images.

| Case ID | Changed pixels | Max channel delta | Crop x,y | Screen x,y | Candidate RGB → baseline RGB | Evidence |
|---|---:|---:|---|---|---|---|
|pill-order-ku-portrait-768|1|1|[380, 222]|[596, 440]|[220, 227, 240] → [220, 226, 240]|[Candidate](evidence/proxolink-native-38070780315/pill-order-ku-portrait-768-webview.png) / [baseline](evidence/proxolink-native-38070780315/pill-order-ku-portrait-768-baseline-webview.png) / [diff](evidence/proxolink-native-38070780315/pill-order-ku-portrait-768-diff.png)|
|pill-order-en-portrait-768|1|1|[380, 222]|[596, 440]|[215, 222, 236] → [215, 221, 236]|[Candidate](evidence/proxolink-native-38070780315/pill-order-en-portrait-768-webview.png) / [baseline](evidence/proxolink-native-38070780315/pill-order-en-portrait-768-baseline-webview.png) / [diff](evidence/proxolink-native-38070780315/pill-order-en-portrait-768-diff.png)|
|pill-mint-contact-en-portrait-768|1|1|[290, 228]|[506, 446]|[234, 246, 241] → [234, 245, 241]|[Candidate](evidence/proxolink-native-38070780315/pill-mint-contact-en-portrait-768-webview.png) / [baseline](evidence/proxolink-native-38070780315/pill-mint-contact-en-portrait-768-baseline-webview.png) / [diff](evidence/proxolink-native-38070780315/pill-mint-contact-en-portrait-768-diff.png)|
|pill-mint-order-ku-portrait-430|1|1|[282, 184]|[667, 402]|[237, 247, 244] → [237, 247, 243]|[Candidate](evidence/proxolink-native-38070780315/pill-mint-order-ku-portrait-430-webview.png) / [baseline](evidence/proxolink-native-38070780315/pill-mint-order-ku-portrait-430-baseline-webview.png) / [diff](evidence/proxolink-native-38070780315/pill-mint-order-ku-portrait-430-diff.png)|
|pill-mint-order-ku-portrait-768|1|1|[290, 228]|[506, 446]|[234, 245, 241] → [234, 246, 241]|[Candidate](evidence/proxolink-native-38070780315/pill-mint-order-ku-portrait-768-webview.png) / [baseline](evidence/proxolink-native-38070780315/pill-mint-order-ku-portrait-768-baseline-webview.png) / [diff](evidence/proxolink-native-38070780315/pill-mint-order-ku-portrait-768-diff.png)|
|pill-mint-order-en-portrait-430|1|1|[282, 184]|[667, 402]|[237, 247, 244] → [237, 247, 243]|[Candidate](evidence/proxolink-native-38070780315/pill-mint-order-en-portrait-430-webview.png) / [baseline](evidence/proxolink-native-38070780315/pill-mint-order-en-portrait-430-baseline-webview.png) / [diff](evidence/proxolink-native-38070780315/pill-mint-order-en-portrait-430-diff.png)|
|pill-mint-order-en-portrait-768|1|1|[290, 228]|[506, 446]|[234, 245, 241] → [234, 246, 241]|[Candidate](evidence/proxolink-native-38070780315/pill-mint-order-en-portrait-768-webview.png) / [baseline](evidence/proxolink-native-38070780315/pill-mint-order-en-portrait-768-baseline-webview.png) / [diff](evidence/proxolink-native-38070780315/pill-mint-order-en-portrait-768-diff.png)|
|pill-mint-download-ku-portrait-320|1|1|[257, 88]|[697, 306]|[239, 248, 245] → [239, 249, 245]|[Candidate](evidence/proxolink-native-38070780315/pill-mint-download-ku-portrait-320-webview.png) / [baseline](evidence/proxolink-native-38070780315/pill-mint-download-ku-portrait-320-baseline-webview.png) / [diff](evidence/proxolink-native-38070780315/pill-mint-download-ku-portrait-320-diff.png)|

This is not the historical set. Compared with run38060488156, `pill-contact-ku-portrait-768` and `pill-mint-contact-ku-portrait-768` now match; `pill-mint-contact-en-portrait-768` and `pill-mint-download-ku-portrait-320` are newly failing in this run.

Controlled reproduction findings:

The run already executed one fixed additional fresh candidate and baseline for eight predeclared cases, each with three captures. These diagnostic images never replace FIRST-frame acceptance images. The table was independently recomputed from those PNGs; A/A means the same role/source rendered in a fresh WebView.

| Case | Candidate A/A pixels | Baseline A/A pixels | Fresh candidate/baseline pixels |
|---|---:|---:|---:|
|pill-contact-en-portrait-768|1|0|1|
|pill-order-ku-portrait-768|0|2|1|
|pill-mint-contact-ku-portrait-768|0|1|1|
|pill-mint-order-ku-portrait-320|0|0|0|
|pill-mint-order-ku-portrait-430|0|0|1|
|pill-mint-order-ku-portrait-768|0|0|1|
|pill-mint-order-en-portrait-430|0|0|1|
|pill-mint-order-en-portrait-768|0|0|1|

Three of sixteen same-role fresh-view comparisons changed: candidate `pill-contact-en-portrait-768` at(380,222); baseline `pill-order-ku-portrait-768` at(583,90) and(380,222); baseline `pill-mint-contact-ku-portrait-768` at(290,228). All deltas1. This establishes fresh-view variation even without switching candidate/baseline roles; it does not identify the underlying rendering cause.

For six currently failing pairs with deeper instrumentation, WebContents screenshots compare exactly while Flutter SurfaceView PixelCopy still differs by one pixel. Runtime config hashes, CSS bytes and decoded embedded-font bytes match. The remaining live-markup difference is text in SCRIPT node72 (candidate79,976bytes vs baseline79,765), not proven causal. CDP screenshots differ from the accepted screen captures by hundreds of thousands of pixels, so their equality cannot replace native acceptance. Post-CDP observations changed some pixels without changing the first-frame results. No frame was selected to manufacture a pass.

**Cause: NOT PROVEN. Fix: not applied.** Evidence narrows the investigation toward raster/composition/history effects but does not prove a specific engine, rounding operation or product defect. No GPU mode, CSS, font, renderer, comparator, tolerance, crop or timing assertion was changed. Two new failed cases lack the deeper per-case pipeline observations because they were not in the predeclared historical diagnostic list.

Requirement3 remains unfinished. A valid next controlled device experiment must cover all eight current failures, preserve exact input hashes, capture the same source in both role positions/orderings, and isolate one native raster/composition variable at a time in diagnostics separate from acceptance. Any proposed remedy must then pass affected native checks and the full unchanged240-case gate. No new affected/full runtime execution or successful fix is claimed in this publication. The recovered local runtime has no adb or /dev/kvm; the configured protected GitHub Android runner remains the available native execution path. This is not an approval diagnosis for the completed run.

Actual notice failures (first fixed phase, not a chosen later frame):

| Case | Observed ms | Opacity / size factor | Status |
|---|---:|---|---|
|actual-ad-error-320|465|[1, 0.8333333333333334]|actual_screen_lifecycle|
|actual-proxolink-error-393|404|[1, 0.9722250000000001]|actual_screen_lifecycle|
|actual-proxolink-error-430|402|[1, 0.902775]|actual_screen_lifecycle|
|actual-proxolink-error-768|408|[1, 0.9722208333333334]|actual_screen_lifecycle|

All four retain matching opacity and size-factor arrays. Their4900ms phase is[1,1],5500ms phase is empty. Shared notice source uses90ms stagger and240ms animation; delayed native frame/timer delivery is a hypothesis, not proven by the existing snapshots. Product timing and full-visibility assertion are unchanged. The four failing first images and every other phase are retained below.

| Width | Home refresh | Tools refresh | Create Ad notice | ProxoLink notice |
|---|---|---|---|---|
|320|[initial](evidence/proxolink-native-38070780315/actual-home-refresh-320-initial.png) / [100ms](evidence/proxolink-native-38070780315/actual-home-refresh-320-100ms.png) / [300ms](evidence/proxolink-native-38070780315/actual-home-refresh-320-300ms.png) / [settled](evidence/proxolink-native-38070780315/actual-home-refresh-320-settled.png)|[initial](evidence/proxolink-native-38070780315/actual-tools-refresh-320-initial.png) / [100ms](evidence/proxolink-native-38070780315/actual-tools-refresh-320-100ms.png) / [300ms](evidence/proxolink-native-38070780315/actual-tools-refresh-320-300ms.png) / [settled](evidence/proxolink-native-38070780315/actual-tools-refresh-320-settled.png)|[initial](evidence/proxolink-native-38070780315/actual-ad-error-320-initial.png) / [400ms](evidence/proxolink-native-38070780315/actual-ad-error-320-400ms.png) / [4900ms](evidence/proxolink-native-38070780315/actual-ad-error-320-4900ms.png) / [5500ms](evidence/proxolink-native-38070780315/actual-ad-error-320-5500ms.png)|[initial](evidence/proxolink-native-38070780315/actual-proxolink-error-320-initial.png) / [400ms](evidence/proxolink-native-38070780315/actual-proxolink-error-320-400ms.png) / [4900ms](evidence/proxolink-native-38070780315/actual-proxolink-error-320-4900ms.png) / [5500ms](evidence/proxolink-native-38070780315/actual-proxolink-error-320-5500ms.png)|
|393|[initial](evidence/proxolink-native-38070780315/actual-home-refresh-393-initial.png) / [100ms](evidence/proxolink-native-38070780315/actual-home-refresh-393-100ms.png) / [300ms](evidence/proxolink-native-38070780315/actual-home-refresh-393-300ms.png) / [settled](evidence/proxolink-native-38070780315/actual-home-refresh-393-settled.png)|[initial](evidence/proxolink-native-38070780315/actual-tools-refresh-393-initial.png) / [100ms](evidence/proxolink-native-38070780315/actual-tools-refresh-393-100ms.png) / [300ms](evidence/proxolink-native-38070780315/actual-tools-refresh-393-300ms.png) / [settled](evidence/proxolink-native-38070780315/actual-tools-refresh-393-settled.png)|[initial](evidence/proxolink-native-38070780315/actual-ad-error-393-initial.png) / [400ms](evidence/proxolink-native-38070780315/actual-ad-error-393-400ms.png) / [4900ms](evidence/proxolink-native-38070780315/actual-ad-error-393-4900ms.png) / [5500ms](evidence/proxolink-native-38070780315/actual-ad-error-393-5500ms.png)|[initial](evidence/proxolink-native-38070780315/actual-proxolink-error-393-initial.png) / [400ms](evidence/proxolink-native-38070780315/actual-proxolink-error-393-400ms.png) / [4900ms](evidence/proxolink-native-38070780315/actual-proxolink-error-393-4900ms.png) / [5500ms](evidence/proxolink-native-38070780315/actual-proxolink-error-393-5500ms.png)|
|430|[initial](evidence/proxolink-native-38070780315/actual-home-refresh-430-initial.png) / [100ms](evidence/proxolink-native-38070780315/actual-home-refresh-430-100ms.png) / [300ms](evidence/proxolink-native-38070780315/actual-home-refresh-430-300ms.png) / [settled](evidence/proxolink-native-38070780315/actual-home-refresh-430-settled.png)|[initial](evidence/proxolink-native-38070780315/actual-tools-refresh-430-initial.png) / [100ms](evidence/proxolink-native-38070780315/actual-tools-refresh-430-100ms.png) / [300ms](evidence/proxolink-native-38070780315/actual-tools-refresh-430-300ms.png) / [settled](evidence/proxolink-native-38070780315/actual-tools-refresh-430-settled.png)|[initial](evidence/proxolink-native-38070780315/actual-ad-error-430-initial.png) / [400ms](evidence/proxolink-native-38070780315/actual-ad-error-430-400ms.png) / [4900ms](evidence/proxolink-native-38070780315/actual-ad-error-430-4900ms.png) / [5500ms](evidence/proxolink-native-38070780315/actual-ad-error-430-5500ms.png)|[initial](evidence/proxolink-native-38070780315/actual-proxolink-error-430-initial.png) / [400ms](evidence/proxolink-native-38070780315/actual-proxolink-error-430-400ms.png) / [4900ms](evidence/proxolink-native-38070780315/actual-proxolink-error-430-4900ms.png) / [5500ms](evidence/proxolink-native-38070780315/actual-proxolink-error-430-5500ms.png)|
|768|[initial](evidence/proxolink-native-38070780315/actual-home-refresh-768-initial.png) / [100ms](evidence/proxolink-native-38070780315/actual-home-refresh-768-100ms.png) / [300ms](evidence/proxolink-native-38070780315/actual-home-refresh-768-300ms.png) / [settled](evidence/proxolink-native-38070780315/actual-home-refresh-768-settled.png)|[initial](evidence/proxolink-native-38070780315/actual-tools-refresh-768-initial.png) / [100ms](evidence/proxolink-native-38070780315/actual-tools-refresh-768-100ms.png) / [300ms](evidence/proxolink-native-38070780315/actual-tools-refresh-768-300ms.png) / [settled](evidence/proxolink-native-38070780315/actual-tools-refresh-768-settled.png)|[initial](evidence/proxolink-native-38070780315/actual-ad-error-768-initial.png) / [400ms](evidence/proxolink-native-38070780315/actual-ad-error-768-400ms.png) / [4900ms](evidence/proxolink-native-38070780315/actual-ad-error-768-4900ms.png) / [5500ms](evidence/proxolink-native-38070780315/actual-ad-error-768-5500ms.png)|[initial](evidence/proxolink-native-38070780315/actual-proxolink-error-768-initial.png) / [400ms](evidence/proxolink-native-38070780315/actual-proxolink-error-768-400ms.png) / [4900ms](evidence/proxolink-native-38070780315/actual-proxolink-error-768-4900ms.png) / [5500ms](evidence/proxolink-native-38070780315/actual-proxolink-error-768-5500ms.png)|

Hosted skip and exact configuration:

At tested cc52, `.github/workflows/proxolink-native-build.yml` gives `isolated-hosted-verification` this condition: repository `Zana-Sponsor/proxobalance`, branch `refs/heads/feat/proxolink-private-renderer-migration`, and head commit message contains `[proxolink-hosted-verification]`. The first two match; the commit contains `[proxolink-live-verification]` only. Therefore this run skips hosted verification before allocating its `proxolink-preview-verification` environment or checking secrets. Rerunning failed native jobs does not change that head message.

Both native and hosted jobs reference the same named environment but different configuration namespaces. Native secrets resolved successfully in the actual run. The earlier hosted presence audit at2026-10-10T14:49:35Z, job114237583472/run38060488156, found these exact required settings absent:

- `PROXO_STAGING_PROJECT_REF`
- `PROXO_STAGING_SUPABASE_URL`
- `PROXO_STAGING_BASE_URL`
- `PROXO_STAGING_ANON_KEY`
- `PROXO_STAGING_TEST_EMAIL`
- `PROXO_STAGING_TEST_PASSWORD`
- `PROXO_STAGING_OTHER_EMAIL`
- `PROXO_STAGING_OTHER_PASSWORD`

The first three accept protected secrets or environment variables; the remaining five are protected secrets. `PROXO_STAGING_VERCEL_BYPASS` is optional when deployment protection requires it. Those missing names are historical evidence, not a fresh claim that accounts do not exist. This connector cannot read GitHub environment secret metadata: environment GET was rejected as an unsupported public endpoint. A new explicitly marked hosted run is needed to repeat the presence-only audit and, if ready, execute the existing ordinary-account runner. No secret values are printed or retained. Use the isolated staging setup document; never substitute production or the unrelated Exchange project.

The checklist and forty-item AO report link this audit. Original source CI remains tied to cc52:234Flutter,153backend,480browser cases,three SQL suites/seven PostgreSQL API lifecycles. No source test/build is counted as current native acceptance. Approval/workspace are resolved; remaining acceptance is strict pixel parity, four notice entry checks, unexecuted isolated hosted and real public-content/account-switch/device coverage. PR7 remains Draft/Open/Unmerged. Production unchanged.
