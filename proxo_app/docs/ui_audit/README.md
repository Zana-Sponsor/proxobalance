# Proxo UI verification evidence

The PNGs are actual Flutter renderings of production screen/component trees,
using deterministic sample records. They are not design mockups. Each filename
states its screen, state, and logical viewport dimensions. PNGs are rendered at
2 pixels per logical pixel; component-only captures may be shorter or taller
than the viewport.

## Reproduce

Use Flutter 3.47.2 (Dart 3.13.2), matching CI. Resolve the locked dependencies
with `flutter pub get`, then run:

```sh
FLUTTER_BIN=/path/to/flutter/bin/flutter \
PROXO_EVIDENCE_DIR=/absolute/output/path \
./tools/capture_ui_evidence.sh
```

Then inventory the delivered files without changing their pixels:

```sh
python tools/build_ui_evidence_manifest.py /absolute/output/path \
  --output docs/ui_audit/manifest.json
```

The script runs the full Flutter test suite, generates the screenshots, and
captures actual receipt PDF output. Its supported SDK analytics-suppression
flags prevent telemetry during verification. Ordinary `flutter test` does not
write the new evidence PNGs unless `PROXO_CAPTURE_DIR` is supplied.

## What the fixtures demonstrate

- Authentication reference screens use the real `AuthScreen`, with an isolated
  transport that rejects network access.
- Home uses the production app bar, `HomeContent`, bottom navigation, and results
  widgets with sample result records. Home initialization and remote data loading
  are tested separately from the visual composition.
- Pages use a controlled repository to demonstrate loading, empty, retrieval
  error, validation, creation, list refresh, and reopening. The fixture's template
  preview intentionally fails, so captures show the real preview retry state.
- Profile and menu use a local mocked Supabase transport and synthetic account
  information. Screenshots include long Kurdish text, missing optional values,
  the edit form with a simulated keyboard inset, and a real drawer overlay.
- Payment destinations in screenshots are replaced with all-zero fixture values.
  No live transfer is initiated. FastPay captures cover its confirmation UI.
- Receipt data, references, customer names, and monetary values are test data.
  The PDF fixtures run the same export code as production.

## Verification limits

Widget tests verify layout and interactions in Flutter's test engine. They do
not prove live backend configuration, real account persistence, settlement of a
payment, OS notification delivery, device-keyboard behavior, or Android/iOS
sharing sheets. A reopened Pages fixture proves the UI reloads saved repository
data; live database persistence still requires a staging or real-account smoke
test. No real payment, OTP, or account deletion was performed.

See `manifest.json` for the capture inventory, viewport labels, byte dimensions,
and hashes. Delivery screenshots are packaged separately from app source.
