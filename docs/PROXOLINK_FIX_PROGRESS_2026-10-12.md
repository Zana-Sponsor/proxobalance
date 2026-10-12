# Executable fixes and controlled experiments — October12

Not COMPLETE. Continues faf9a960 without redesign or production changes.

## Notifications

Source diagnosis: insertion/expiry timers begin before the notification widget mounts, but the old AnimationController begins entry on its first mounted frame. A busy mounting frame shifts entry independently of the existing five-second lifetime. The new regression mounts at180ms and observes at400ms; no deadline is delayed. CI runs this same scenario against actual cc52 source (asserting that entry is incomplete), restores the candidate fix, then requires full opacity and size at400ms, two notices at4900ms and removal at5500ms. The reproduction is not a replacement for the four physical-device cases.

Candidate product fix in lib/widgets/ad_validation_notifications.dart: store each notice's scheduled entry time using the clock package; a frame ticker advances the existing AnimationController from that elapsed time instead of restarting entry at mount. Keep90ms stagger,240ms entry/exit, five-second lifetime, decorations and shared Create Ad/ProxoLink component. A queued hidden notice receives a fresh timestamp when a visible slot opens. Use clock rather than the last scheduler timestamp so an idle app does not incorrectly skip entry. Existing clock1.1.3 transitive dependency promoted to explicit direct dependency; no version upgrade.

Verification at publication: local backend/harness153/153 pass. Flutter before/after reproduction and full suite are pending CI. The four native cases are NOT declared fixed until a new native artifact proves them.

## Native pixels

Root cause remains unproven. No template/renderer/GPU/threshold changes. The next run adds one fixed same-document native redraw using the existing awaitDraw barrier after the three original acceptance frames and SurfaceView observation, but before CDP readback. It retains the resulting image and compares it to FIRST without substituting it into acceptance. This separates redraw-history effects from the previously confounded CDP intervention. The original zero-pixel gate and all other assertions remain unchanged.

Deep diagnostic targets expand11→13 to include pill-mint-contact-en-portrait-768 at(290,228) and pill-mint-download-ku-portrait-320 at(257,88). Both Node and Dart target maps agree. Existing eight fresh-view controls and240matrix remain. Fixed host timeout and capture-ID-matched redraw acknowledgement fail closed if absent.

## Hosted

Requested through an empty-tree commit a7ace8348c05d3f7dcb84e4dbcb3a830ebb4b4b8 with the existing [proxolink-hosted-verification] marker. Run38264179020, hosted job114862024061, references proxolink-preview-verification and is waiting for its configured reviewer. It is NOT skipped. Current missing settings cannot be reported until the presence-only step executes; older missing-setting lists are historical. Native credentials are not claimed missing.

## Pending execution

New source/native verification will run against the executable commit containing this change. Current report/checklist must retain Pending for notification native acceptance, pixel cause/remedy and isolated hosted result. PR7 Draft/Open/Unmerged; production unchanged. No audit publication is described as a fix, and no successful native rerun is claimed.
