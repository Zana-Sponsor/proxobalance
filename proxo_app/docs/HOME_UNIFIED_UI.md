# Home Quick Actions and Best Results

Implemented 3 October 2026. This change refines the two requested Home sections
using the existing Create Ad / receipt design tokens. Other Home sections and the
full Best Results screen keep their existing implementation.

## Shared visual system

| Element | Implementation |
| --- | --- |
| Main cards | White, `AdUi.radius` (18 dp), `AdUi.cardPadding` (20 dp), identical `AdUi.cardShadow` layers |
| Controls and icon wells | `AdUi.controlRadius` (14 dp), inherited icon sizing, subtle blue surfaces |
| Headings | Inherited `titleMedium`, existing Proxo blue, weight 400 |
| Primary / secondary text | Inherited `bodyMedium`, existing black / grey, weight 400 |
| Font | Existing app theme's Rabar; no custom font sizes or artificial scaling |
| Section spacing | Existing `AdUi.sectionGap` (22 dp) |
| Wide screens | Both sections centered within the existing Create Ad maximum content width of 600 dp |
| Text direction | Existing `ProxoText` first-strong direction and bidi isolation; Kurdish RTL, numerical metrics and currency LTR |

Quick Actions preserve the three original labels, helper texts, callbacks and
full-card tap targets. The application shell still opens Create Ad, contact tools
and FAQ through the existing navigation callbacks. Cards grow with text and switch
to a stacked arrangement when an icon-and-text row cannot fit naturally.

Best Results preserves the production `BestMetricsService.fetchHomePreview`
loader, weekly ranking, refresh/cache behavior, result values, View All route and
selected-result detail navigation. Its cards now share the same surfaces and
typography as Create Ad. The supplied thumbnail URL is still used with the existing
image cache; missing images use a subtle repeated Proxo wordmark fallback.

Metric rows become vertical when the inherited text cannot fit horizontally.
The carousel measures actual card height and recomputes it after resizing or
system text-size changes. Its horizontal viewport stays within the section,
including the preview of the next card. Home's spending metric retains its existing
USD value and precision: the result model supplies USD and no exchange-rate quote.
No conversion or financial calculation is introduced by this UI change.

## Verification

Flutter 3.47.2 / Dart 3.13.2 were used. Locked dependencies were restored without
changing the dependency manifest or lockfile.

- Full Flutter test suite: **309 passed**, including **36 new Home widget tests**.
- Responsive coverage: widths **240, 280, 320, 393, 430, 768, 852 and 1280 dp**,
  portrait and landscape sizes, with system text scales **1.0, 1.5 and 3.0**.
- Checked native Rabar glyph paint bounds, wrapping, normal weights and inherited
  font family; no layout exceptions in the tested size/scale matrix.
- Checked all three action callbacks and the existing Create Ad route, carousel
  swiping, ranked data, cached refresh, View All and selected-result navigation.
- Checked loading, empty, network-error/retry and late-completion-after-dispose
  states, plus rotation and text-size changes.
- Checked LTR numerical/currency token ordering and RTL labels.
- Checked card padding, corners and shadow values against a rendered existing
  `AdFormSection` reference.
- `flutter analyze --no-pub` on the new/reconstructed components and their tests:
  **no issues**. Whole-project analysis: **0 errors**, 91 warnings and 211
  informational findings remain in existing code.
- `flutter build bundle --no-pub --target-platform=linux-x64`: **passed**.
- `git diff --check`: **passed**.

Service implementations, Supabase queries, authentication, app-shell navigation,
theme tokens and the noncompact Best Results screen were preserved. No database,
RLS, Edge Function or storage changes are included.

## Runtime previews

These PNGs are rendered from the actual Flutter components with Rabar and
Material icons, rather than drawn mockups. They show only the two updated sections
using test fixtures. The portrait thumbnail shown is the missing-image fallback.
Fixtures are injected only by tests; production continues to load Supabase data.

- [Phone, 393 dp](home_sections_phone_preview.png)
- [Tablet, 768 dp](home_sections_tablet_preview.png)
- [Large accessibility text, 393 dp at 3.0 system scale](home_sections_large_text_preview.png)

Physical-device testing, a complete authenticated Home session and live Supabase
network queries were not performed. The executed runtime tests use Flutter's
headless widget engine; the bundle check is not an Android/iOS release build.

To reproduce from `proxo_app`, run `flutter pub get`, `flutter gen-l10n`,
`flutter test test/home_sections_test.dart`, and `flutter test`.
