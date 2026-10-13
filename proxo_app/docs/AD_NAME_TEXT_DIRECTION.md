# Advertisement name text direction

Updated and checked on 2026-10-03 with Flutter 3.47.2.

The Create Ad name input uses the shared receipt direction policy. The first
strong letter chooses the paragraph direction: Kurdish/Arabic RTL and English
LTR. Leading numbers or punctuation do not override later letters; a name made
only of numbers is LTR. Native Unicode bidirectional layout keeps Latin words,
codes and numbers readable inside mixed-language names.

## Implementation

- The name field requests the native name keyboard. It has no language filter
  or input formatter and accepts Kurdish, Arabic, English and mixed names.
- The shared direction observer rebuilds on direction changes rather than
  every controller notification. Moving the cursor or updating an IME composing
  range leaves the surrounding input widget intact.
- Create Ad no longer rebuilds its full form on every keystroke just to remove
  a nonexistent validation error. Existing errors still clear when edited.
- Direction detection never writes into the controller. Text, selection,
  composing range, callbacks and the native editable state are retained.
- Existing ad list, confirmation, feedback and receipt name displays continue
  to use the same shared direction detection. Display-only Latin/numeric
  isolation does not change stored, submitted or editable values.
- Input styling, spacing, inherited Rabar typography and normal weight are
  unchanged.

## Checks actually performed

- **11 new Flutter widget tests passed.** The actual Create Ad field receives
  platform text-input updates for Kurdish, Arabic, English, numeric-only and
  mixed names. Tests check focus, native editable state identity, exact cursor
  selection and composing ranges, and rendered Latin/numeric glyph order.
- Leading-letter insertion/removal and clearing the field update direction
  without altering input values. Same-direction typing and cursor changes do
  not rebuild the direction observer. Controller replacement, inherited
  direction changes and disposal are covered.
- Actual confirmation and receipt widgets render nine representative names
  with consistent paragraph direction and LTR Latin/numeric runs. Submission
  serialization and receipt data retain the raw name.
- Full Flutter suite: **273 tests passed**, including existing authentication,
  responsive Create Ad, countdown, transaction, receipt and PDF regressions.
- Analysis of the changed Dart source and test file: **No issues found**.
- Flutter application bundle for `linux-x64`: **built successfully**.

These are Flutter widget/runtime checks with repository fixtures and simulated
platform text input. Physical-device keyboard/IME testing and signed-in live
Supabase submissions were not performed for this change. Backend processing,
pricing, authentication and database schema are unchanged.

```sh
flutter test --no-pub test/ad_name_direction_test.dart
flutter test --no-pub
flutter analyze --no-pub lib/widgets/proxo_text.dart lib/screens/ad_create_screen.dart test/ad_name_direction_test.dart
flutter build bundle --no-pub --target-platform=linux-x64
```
