# Manual visual review

Reviewed all 224 selected real-widget captures in the 31 side-by-side sheets indexed in [review-index.json](review-index.json). Inspected full-resolution Menu, Profile, narrow Auth, numeric Best Results, update UI, Create Page error and Ads large-text captures in addition to the sheets. Layout JSON and the strict Create Ad test measure geometry/palette; visual review is not represented as a screenshot-only golden test.

| Check | Result |
|---|---|
| Shared font, blue/gray and white surfaces | Shared roles/palette applied; official brands, status colors and customer page-template previews remain intentional exceptions. |
| Gutters and section rhythm | 20dp standard outer margin, 16dp own-control gap, 32dp external gap; responsive stacked layouts at narrow widths. Menu is a bounded drawer surface. |
| Primary/secondary selection hierarchy | Blue/white primary choices, watery blue/border secondary resources; no blended state system. |
| PNG semantic weight and placement | Single local icon family, alpha-bound normalization; Profile/Menu/Home reviewed with actual decoded images and RTL placement. |
| Price card | 20dp side margins, 10dp radius, 64dp collapsed normal row, upward expansion, conditional discount, loading/error/retry, zero navigation gap, separate Sponsor. |
| Create Page | Contact/Restaurant/App Download forms, all preview styles, submission/error/return fixtures and filled input reviewed. |
| Auth | Phone-only signup, retained values, legacy login, phone OTP, 280dp and 2× text; narrow input scrolls full values instead of shrinking them. |
| Home/Results | Blue CTA is usable; Home remains compact; dedicated result expansion and correct fallback reviewed. Large-text metric numbers remain intact. |
| Error/update states | Manual close remains available, form stays editable; optional and required update surfaces wrap and scroll at 2×. |
| Accessibility/scrolling | 393/320/280dp plus 2× capture matrix. Offscreen content has corresponding scrolled captures; no failed overflow assertions in final accepted runs. |

Corrections found during review and recaptured:

- Capture timing initially omitted decoded PNG artwork. Capture helpers now await asset decoding, including resized asset providers, and verify real image frames before screenshots.
- Best Results numeric values wrapped between digits. Measured widths choose a vertical layout and preserve whole amounts.
- The large-text phone hint shrank too far. It now keeps a readable role and uses ellipsis; entered text remains horizontally scrollable.
- The additional results fixture initially had not opened its detail control. It now taps the real control and asserts the expanded widget before capture.
- The Ads list clamped text scaling to 1.0. The clamp is removed; metric-height rounding accommodates the real font's final fractional line height.
- Price metadata still recorded a historic zero radius. It now reads the actual rendered surface radius, verified as 10dp.

Accepted responsive differences: large text increases content height; filter/navigation rows can scroll horizontally; long identifiers/titles use existing bounded ellipsis with full detail/copy routes. Images use their declared photo/thumbnail framing. Screenshot fixture IDs, amounts and simulated provider states are not live customer records or provider proof.

Physical Android, production OTP/provider/payment actions and authenticated production page persistence remain separate release gates. Native CI captures and performance results must be assessed on the final PR source, not substituted from a prior commit.
