# Executable fixes and controlled experiments — October12

Not COMPLETE. Continues faf9a960 without redesign or production changes.

## Notifications

Source diagnosis: insertion/expiry timers begin before the notification widget mounts, but the old AnimationController begins entry on its first mounted frame. A busy mounting frame shifts entry independently of the existing five-second lifetime. The new regression mounts at180ms and observes at400ms; no deadline is delayed. CI runs this same scenario against actual cc52 source (asserting that entry is incomplete), restores the candidate fix, then requires full opacity and size at400ms, two notices at4900ms and removal at5500ms. The reproduction is not a replacement for the four physical-device cases.

Candidate product fix in lib/widgets/ad_validation_notifications.dart: store each notice's scheduled entry time using the clock package; a frame ticker advances the existing AnimationController from that elapsed time instead of restarting entry at mount. Keep90ms stagger,240ms entry/exit, five-second lifetime, decorations and shared Create Ad/ProxoLink component. A queued hidden notice receives a fresh timestamp when a visible slot opens. Use clock rather than the last scheduler timestamp so an idle app does not incorrectly skip entry. Existing clock1.1.3 transitive dependency promoted to explicit direct dependency; no version upgrade.

Tested executable: `4b816fb4e62b55d09ea8951d82cd30536bd612cd` on `feat/proxolink-private-renderer-migration`. Local backend/harness153/153 pass. Source CI38265055650 job114865008416 steps9–11 passed: changed-code analysis, controlled old-source/new-source reproduction, and the full Flutter suite. All five jobs have now passed, including the235-test Flutter suite, release APK, privacy scan and paired size measurement. The four native cases are NOT declared fixed until a new native artifact proves them.

## Native pixels

Root cause remains unproven. No template/renderer/GPU/threshold changes. The next run adds one fixed same-document native redraw using the existing awaitDraw barrier after the three original acceptance frames and SurfaceView observation, but before CDP readback. It retains the resulting image and compares it to FIRST without substituting it into acceptance. This separates redraw-history effects from the previously confounded CDP intervention. The original zero-pixel gate and all other assertions remain unchanged.

Deep diagnostic targets expand11→13 to include pill-mint-contact-en-portrait-768 at(290,228) and pill-mint-download-ku-portrait-320 at(257,88). Both Node and Dart target maps agree. Existing eight fresh-view controls and240matrix remain. Fixed host timeout and capture-ID-matched redraw acknowledgement fail closed if absent.

## Hosted

Requested through an empty-tree commit a7ace8348c05d3f7dcb84e4dbcb3a830ebb4b4b8 with the existing [proxolink-hosted-verification] marker. Run38264179020, hosted job114862024061, references proxolink-preview-verification and is waiting for its configured reviewer. It is NOT skipped. Current missing settings cannot be reported until the presence-only step executes; older missing-setting lists are historical. Native credentials are not claimed missing.

## Pending execution

Native run38265055827 targets executable4b816fb4; APK job114865010135 passed, runtime114866813387 is waiting at the configured environment review. Hosted run38264179020 targets a7ace834 (same renderer/backend as4b816, preceding the Flutter-only product fix). Both pending-deployments responses name environment23442858482, proxolink-preview-verification, reviewer Zana-Sponsor. These are newly triggered runs; the approval of completed run38070780315 remains acknowledged. No native experiment or hosted configuration check has executed in these new runtime jobs. Current report/checklist must retain Pending for notification native acceptance, pixel cause/remedy and isolated hosted result. PR7 Draft/Open/Unmerged; production unchanged. No audit publication is described as a fix, and no successful native rerun is claimed.

## Verified source results and artifacts

- [Source CI38265055650](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38265055650): backend, database and edge jobs passed; 235 Flutter tests, release build, privacy scan and paired size measurement all passed.
- Responsive job114865008699 passed all480 renderer/browser cases, five widths, RTL/LTR, text scale1.6 and exact prepared-design pixels. [Artifact11754232826](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38265055650/artifacts/11754232826); upload SHA256 `5ae383ccf312222cc5daa39fe90317f787aead2101a084a797c1c0bd74c9816e` (reported by upload, not yet independently downloaded).
- Database job114865008838 passed all three SQL suites and seven PostgreSQL-backed API lifecycles, including rollback/reapply, owner RLS, moderation grants, dependency-safe deletion and legacy preservation in a disposable database.
- [Native run38265055827](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38265055827): APK passed; runtime not executed, waiting review.
- [Hosted run38264179020](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38264179020): requested through the existing hosted marker, not skipped; waiting review before checking settings.

## Exact executable paths changed

`.github/workflows/proxolink-verify.yml`; `proxo_app/lib/widgets/ad_validation_notifications.dart`; `proxo_app/test/ad_notice_deadline_test.dart`; `proxo_app/pubspec.yaml`; `proxo_app/pubspec.lock`; `proxo_app/integration_test/proxolink_native_diagnostics.dart`; `proxo_app/integration_test/proxolink_native_probe.dart`; `scripts/proxolink-native-diagnostics.mjs`; `scripts/run-proxolink-native.mjs`; `test/proxolink-native-diagnostics.test.js`. The same commit also updates the AO report/checklist and adds this progress report.

## Independently checked current UI evidence

[UI artifact11754676443](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38265055650/artifacts/11754676443) downloaded and independently verified: SHA256 `8f6e62b4ec5faf09fa39eca09f85a586d961e51c5a16bb43c4b8b69ff1d22957`, all147 ZIP entries pass CRC,146 PNGs plus measurement JSON. Against138 retained same-name screenshots,130 are byte-identical, including all58 Tools/Create design screenshots. The only eight changes are the100ms notice-entry frames at320/393/430/768 for Create Ad and ProxoLink, consistent with the deliberate scheduled-entry fix. All400/4900/5100/5500ms matched prior screenshots exactly. These are widget tests of actual production classes with fictional transports, not native-device evidence.

[Current measurements](evidence/proxolink-fix-4b816/actual-screen-measurements.json) retain all16 actual-screen cases. All eight notice cases report opacity/size [1,1] at400ms and4900ms, and no notices at5500ms. All eight refresh cases retain one added read, the same scroll element and zero settled offset.

[Paired APK artifact11754502536](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38265055650/artifacts/11754502536): same-code4b816 before83,702,384bytes / after89,319,872bytes, +5,617,488bytes; release source-privacy scan passed. Artifact upload digest `11a28468a5a1211abfbd89cbe907ba97127374a86dbe4e7940028edae846d3dd` (not independently downloaded).
