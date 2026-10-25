# PROXO TIKTOK CREATE AD
# STRICT BALANCED UI + TYPOGRAPHY + SPACING + LONG PRICE BREAKDOWN

> **NON-NEGOTIABLE VISUAL CORRECTION**
>
> Work **point by point and pixel by pixel**.
> The current TikTok Create Ad implementation is NOT visually approved.
> Do not make small random padding fixes.
> Rebalance the entire screen as one coherent UI system.
>
> Preserve all existing working business logic, provider logic, payment logic, validation, state management, page filtering, submission safety, and RTL.
>
> This task is primarily a complete visual hierarchy correction.

---

# 1. PRIMARY DESIGN GOAL

The TikTok Create Sponsored Ad screen must feel:

- clean
- open
- balanced
- readable
- calm
- professional
- lightweight
- properly spaced
- clearly structured
- Kurdish Sorani RTL
- consistent with Proxo’s polished design language

The current screen has these problems:

- headings are too visually heavy
- headings and controls are too close
- sections visually run into each other
- typography hierarchy is inconsistent
- some helper actions visually compete with headings
- Final Price does not match the required design
- the price card is too rounded/floating
- the price component does not feel integrated with Bottom Navigation

Fix all of these together.

---

# 2. DO NOT CHANGE THE FONT FAMILY

Keep the existing Proxo/Auth font family.

Do NOT introduce a random new font.

The problem is not the font family itself.

The problem is:

- weight
- size
- spacing
- line height
- positioning
- hierarchy

Refine those values.

---

# 3. GLOBAL TYPOGRAPHY HIERARCHY

Use one clear typography system throughout the Create Ad screen.

## AppBar title

`دروستکردنی ڕیکلام`

Use approximately:

- 18sp
- Medium
- FontWeight around 500
- balanced line height

Do not make it heavy bold.

---

# 4. SECTION HEADINGS

Examples:

- `جۆری ڕیکلام`
- `ناوی ڕیکلام`
- `شوێنی پەیوەندیکردن`
- `پەڕەی پەیوەندی`
- `شوێن`
- `تەمەن`
- `ڕەگەز`
- `بودجە و ماوەی ڕیکلام`
- `بەروار و کاتی دەستپێک`
- `شێوازەکانی پارەدان`

Use a balanced section-heading style.

Recommended visual target:

- 16–17sp
- FontWeight 500–600
- preferably Medium / controlled SemiBold
- not Bold
- black / near-black
- clear RTL alignment

Do not make headings visually oversized.

Do not use heavy `700`-style weight throughout the screen.

---

# 5. INPUT LABELS

Input labels such as:

- `ناوی ڕیکلام`
- `کۆدی ڤیدیۆ`
- `بەستەری ڤیدیۆ`

must visually match the section hierarchy.

Do not make them much heavier than the field text.

Use:

- approximately 15–16sp
- Medium
- black / near-black

The label should be readable but calm.

---

# 6. INPUT FIELD TEXT

Values inside fields such as:

`New Ad 25-10-2026`

must use:

- approximately 14–15sp
- Regular or Medium
- FontWeight 400–500
- black / near-black
- comfortable line height

Do not use bold text inside normal fields.

---

# 7. HELPER / SECONDARY TEXT

Helper actions and secondary descriptions must be visually weaker than headings.

Examples:

- tutorial/example actions
- helper text
- optional notes
- status descriptions

Use approximately:

- 12–14sp
- Regular / Medium
- lower visual emphasis

Blue helper links must not look like main actions.

---

# 8. BUTTON TEXT

Primary choice buttons and secondary destination controls should normally use:

- approximately 14–15sp
- Medium
- FontWeight around 500

Do not use Thin.

Do not use heavy Bold.

---

# 9. CORE SPACING RULE

The screen must use a consistent spacing hierarchy.

This is CRITICAL.

The user must immediately understand which heading belongs to which control.

Use this principle everywhere:

## Heading → own control

Smaller internal gap.

Target:

**14–18dp**

## End of a section → next section heading

Clearly larger external gap.

Target:

**28–36dp**

## Controls inside the same group

Target:

**10–12dp**

---

# 10. VISUAL RHYTHM

Every section must visually follow:

```text
SECTION HEADING

    small intentional gap

CONTROL / FIELD / BUTTON GROUP

    noticeably larger gap

NEXT SECTION HEADING
```

Do NOT use nearly equal spacing everywhere.

The customer must visually feel:

- this heading belongs to this control
- then this section ends
- then a new section starts

---

# 11. PROHIBITED SECTION RHYTHM

Do not produce:

```text
Heading
Control
Heading
Field
Heading
Control
```

with nearly identical gaps.

This creates the current problem where everything looks like it is inside everything else.

---

# 12. PAGE HORIZONTAL MARGINS

Use one consistent horizontal gutter throughout the form.

Target:

**20dp** on normal phone widths.

All main content should align to the same left/right visual line:

- headings
- fields
- button groups
- page breakdown
- Sponsor button
- price component

Do not let different sections have random widths.

---

# 13. INPUT FIELD GEOMETRY

Input fields must remain clean and balanced.

Recommended:

- minimum height around 52–56dp
- horizontal padding around 16dp
- moderate corner radius around 12–14dp
- subtle border
- white / very light surface

Do not make fields pill-shaped.

Do not make fields excessively tall.

---

# 14. REMOVE LARGE SECTION WRAPPER CARDS

Keep the requested flat/open structure.

Do NOT put each section inside a large elevated card.

Normal sections should use:

- heading
- spacing
- field/control
- next-section spacing

Small functional surfaces are allowed.

Large visual wrapper cards are not.

---

# 15. `جۆری ڕیکلام`

Use this exact heading:

# `جۆری ڕیکلام`

Options:

1. `نامە و پەیوەندی`
2. `بینینەکان`
3. `خواردنگە`
4. `دابەزاندنی ئەپ`

---

# 16. PRIMARY IMPORTANT BUTTONS — INACTIVE

This applies to:

- the four `جۆری ڕیکلام` options
- `تەمەن`
- `ڕەگەز`
- `شوێن`
- other equivalent major campaign choices

Inactive state:

- background: white
- text: gray
- border: gray
- soft subtle shadow
- moderate radius

Do not use black text for these inactive primary controls.

---

# 17. PRIMARY IMPORTANT BUTTONS — ACTIVE

When selected:

- full solid balanced blue background
- white text
- no visible border
- subtle soft shadow
- same geometry as inactive state

Do not draw an extra blue border around a fully blue button.

The selected fill itself defines the button.

---

# 18. PRIMARY BLUE

Use a balanced Proxo-style medium blue.

Do not use:

- dark navy
- neon blue
- extremely saturated electric blue

The selected state should look similar in intensity to the visual reference.

---

# 19. SECONDARY CONTROLS

These are visually different:

- `هەموو پلاتفۆڕمەکان`
- `نامەی تیک تۆک`
- `پەڕەی پەیوەندی`

Do not style them like the primary campaign choices.

---

# 20. SECONDARY CONTROLS — INACTIVE

Inactive:

- white background
- BLACK / near-black text
- gray border
- very soft shadow

This is intentionally different from inactive `جۆری ڕیکلام`.

---

# 21. SECONDARY CONTROLS — ACTIVE

Active:

- pale watery blue background
- BLUE text
- BLUE border
- subtle shadow

Do not use solid-blue fill.

Do not use white text.

---

# 22. BUTTON RADIUS

All controls must use balanced rounded rectangles.

Do not create excessive pill-style buttons.

Recommended visual target:

- 10–14dp radius depending on component size

Keep the geometry consistent.

---

# 23. BUTTON HEIGHT

Choice buttons must have a consistent height.

Normal phone target:

approximately **48–52dp**.

Do not allow one objective button to become taller than another merely because the label is longer unless accessibility/text scaling truly requires it.

---

# 24. SOFT PRESS INTERACTION

For:

- `جۆری ڕیکلام`
- `تەمەن`
- `ڕەگەز`
- `شوێن`
- `هەموو پلاتفۆڕمەکان`
- `نامەی تیک تۆک`
- page controls
- schedule controls

use a soft state transition.

Target:

**160–200ms**

Animate:

- background
- text color
- border
- shadow

Do not:

- bounce
- resize
- move neighboring controls
- create layout jump

---

# 25. ICONS

Use icons only where they help.

Do not add icons everywhere.

Objective icons must remain balanced in size.

Recommended:

approximately **20–22dp**.

Icon-to-text gap:

approximately **8dp**.

---

# 26. `هەموو پلاتفۆڕمەکان`

Show relevant platform logos/icons in a compact row.

Requirements:

- consistent icon size
- correct spacing
- no oversized logos
- no crowding
- text remains readable
- RTL remains correct

---

# 27. `نامەی تیک تۆک`

Use the TikTok identity/logo appropriately.

Do not replace it with a random generic message icon.

Use the same geometry as `هەموو پلاتفۆڕمەکان`.

---

# 28. `پەڕەی پەیوەندی`

This must remain an:

# Expandable / Collapsible breakdown

Do not return to the old dropdown-only interaction.

Collapsed state should be compact.

Expanded state should show matching pages/resources.

---

# 29. PAGE BREAKDOWN ROWS

Each page item should show:

- page image
- page name
- page status
- selected indicator

Keep rows compact.

Do not create giant cards for each page.

---

# 30. PAGE FILTERING

Filter based on `جۆری ڕیکلام`.

## `نامە و پەیوەندی`
Only relevant communication/contact pages.

## `خواردنگە`
Only restaurant pages.

## `دابەزاندنی ئەپ`
Only app-download pages/assets.

## `بینینەکان`
Only relevant video/view resources.

Do not mix unrelated page types.

---

# 31. AD NAME

New ad default remains:

`New Ad DD-MM-YYYY`

Example:

`New Ad 25-10-2026`

The customer can edit it.

Never overwrite a customer-edited name.

---

# 32. REMOVE

Remove from TikTok Create Ad:

- `جۆری پۆل`
- `جۆری ئامێر`

Do not leave blank spacing.

---

# 33. HELPER ACTION SPACING

The current screenshot shows helper actions too close to surrounding content.

Examples like:

- video tutorial
- view example

must have proper spacing.

After a helper row, leave clear breathing room before the next section heading.

Helper action → next heading should visually belong to different sections.

---

# 34. SPONSOR BUTTON

`سپۆنسەرکردن`

must remain a normal separate primary button inside scrollable form content.

It must NOT be inside the Final Price component.

Style:

- solid balanced blue
- white text
- medium font weight
- moderate radius
- normal app horizontal margins
- subtle shadow

---

# 35. FINAL PRICE — REBUILD VISUAL STRUCTURE

The Final Price must be redesigned again.

The current rounded floating bubble/card is not accepted.

Use a:

# **LONG HORIZONTAL EXPANDABLE PRICE CARD**

---

# 36. FINAL PRICE CARD SHAPE

The Price Breakdown must be:

- long horizontally
- nearly full usable screen width
- extending visually from left toward right with normal app margins
- not a small centered floating card

It should feel like one horizontal bottom surface.

---

# 37. PRICE CARD CORNERS

The card edges must be sharper / less rounded than the current design.

Do not make it pill-like.

Do not use the current large rounded bubble appearance.

Recommended visual target:

approximately **8–12dp corner radius**.

The long rectangular geometry is more important than roundness.

---

# 38. PRICE CARD POSITION

Place it immediately above Bottom Navigation.

It should visually sit on top of Bottom Nav.

There should not be a large floating gap between them.

Conceptually:

```text
FORM CONTENT
FORM CONTENT

┌────────────────────────────────────────┐
│             FINAL PRICE                │
└────────────────────────────────────────┘
┌────────────────────────────────────────┐
│            BOTTOM NAVIGATION           │
└────────────────────────────────────────┘
```

Two separate layers, but visually related.

---

# 39. PRICE CARD WIDTH

Use almost all available width.

Respect app margins.

For example:

- screen horizontal gutter around 16–20dp
- card fills the remaining width

Do not constrain this price card to an unnecessarily narrow centered width on phone.

---

# 40. COLLAPSED PRICE CARD HEIGHT

Keep collapsed state compact.

Target approximately:

**64–76dp**

depending on text scaling.

Do not make it excessively tall.

---

# 41. COLLAPSED PRICE CONTENT

Show only:

- `کۆی گشتی`
- total value
- expand/collapse icon

No extra explanatory label.

Do NOT display:

`بینینی وردەکاری`

---

# 42. COLLAPSED PRICE LAYOUT

Normal-width layout should preferably be a single balanced row.

RTL concept:

```text
┌────────────────────────────────────────┐
│  ˄       18,000 د.ع         کۆی گشتی │
└────────────────────────────────────────┘
```

Exact RTL ordering can follow the app’s correct directional rules, but it must visually remain balanced.

---

# 43. EXPAND ICON

The expand icon must remain INSIDE the long card.

It must not float outside the card.

Use:

- small chevron / disclosure icon
- proper tap target
- smooth rotation

Do not create a separate bubble around the icon unless absolutely necessary for accessibility.

---

# 44. PRICE AMOUNT

The total value should be:

- blue
- readable
- Medium/SemiBold
- visually important
- not oversized

Example:

`18,000 د.ع`

Keep number and currency together where possible.

Do not awkwardly split them.

---

# 45. EXPANDED PRICE CARD

When tapped:

the SAME long horizontal card expands upward.

Do not open a new modal.

Do not replace it with another card.

Do not move Bottom Navigation.

---

# 46. EXPANDED BREAKDOWN STRUCTURE

Expanded state should look conceptually like:

```text
┌────────────────────────────────────────┐
│ نرخی لاوەکی                 15,000 د.ع │
│ کرێی خزمەتگوزاری             3,000 د.ع │
│ داشکاندن                       -500 د.ع │
│ ────────────────────────────────────── │
│ کۆی گشتی                    17,500 د.ع │
│                                      ˅ │
└────────────────────────────────────────┘
```

`داشکاندن` appears only if it exists.

---

# 47. PRICE ROW ALIGNMENT

Every breakdown row must have predictable alignment.

Use a consistent two-column system:

- label side
- amount side

All amounts should line up visually.

Do not allow one amount to float randomly farther left/right.

---

# 48. PRICE ROW TYPOGRAPHY

Normal rows:

- label: 13–14sp Regular/Medium
- amount: 13–14sp Medium

Total row:

- label: 14–15sp Medium/SemiBold
- amount: 15–16sp SemiBold
- amount blue

Do not use heavy bold.

---

# 49. PRICE ROW HEIGHT

Keep rows compact.

Target vertical row rhythm around:

**10–12dp internal vertical spacing**

Do not create large form-style gaps inside Price Breakdown.

---

# 50. PRICE DIVIDER

Use one thin soft divider immediately above `کۆی گشتی`.

Do not use thick lines.

Do not overdecorate.

---

# 51. PRICE CARD 3D / ELEVATION

The long Price card must visually sit above scrolling content.

Use:

- subtle upward-facing shadow
- low opacity
- moderate blur
- white surface

It should create soft 3D layering.

Do not make it look like a floating popup.

---

# 52. SCROLL BEHAVIOR

While the user scrolls:

- form content scrolls behind the Price card
- Price card stays fixed
- Bottom Navigation stays fixed
- subtle shadow makes layering visible

No:

- jitter
- vertical jumping
- width changes
- random resizing

---

# 53. PRICE LOADING

When price is recalculated:

keep the long card in place.

Do not destroy its layout.

Show a compact loader inside the amount area.

Flow:

1. customer changes budget/duration/etc.
2. total area shows compact loader
3. authoritative quote arrives
4. new amount appears

The surrounding card geometry remains stable.

---

# 54. EXPANDED LOADING STATE

If Price Breakdown is already expanded when recalculation happens:

do not suddenly collapse it.

Preserve expanded state.

Show loading cleanly.

Update details when the quote arrives.

---

# 55. PRICE EXPAND/COLLAPSE ANIMATION

Use a smooth vertical animation.

Target:

**180–220ms**

Expanded card grows upward.

Collapsed card returns downward.

Bottom edge remains anchored above Bottom Navigation.

---

# 56. BOTTOM NAV MUST NOT MOVE

Expanding Price Breakdown must never move Bottom Navigation.

Bottom Nav is independent and fixed.

Price card grows upward only.

---

# 57. CONTENT CLEARANCE

The form scroll view must include enough bottom padding.

The last normal form content, especially:

`سپۆنسەرکردن`

must be scrollable completely above:

- Price card
- Bottom Navigation

Nothing should be permanently hidden behind them.

---

# 58. DO NOT DUPLICATE PRICE UI

For TikTok:

if the sticky long Price Breakdown is present, do not also show another full duplicate customer-facing `پوختەی نرخ` card in normal content.

One primary price summary experience is enough.

---

# 59. BOTTOM NAV RELATIONSHIP

The Price card and Bottom Nav should feel intentionally stacked.

Not:

- card floating randomly 20–30dp above nav
- card touching unrelated content
- giant space between card and nav

Keep visual spacing very small and controlled.

---

# 60. SCREEN SECTION QA

Review every section from top to bottom.

For each one measure:

1. previous section → heading
2. heading → control
3. control → helper text
4. helper text → next heading

The entire screen should feel rhythmically consistent.

---

# 61. REQUIRED VISUAL CHECK

Specifically inspect these transitions:

### `جۆری ڕیکلام`
→ `ناوی ڕیکلام`

### `ناوی ڕیکلام`
→ `کۆدی ڤیدیۆ`

### `کۆدی ڤیدیۆ`
→ helper/tutorial

### helper/tutorial
→ `بەستەری ڤیدیۆ`

### media
→ audience

### audience
→ budget

### budget
→ schedule

### payment
→ Sponsor

Make sure no headings appear visually attached to the wrong previous field.

---

# 62. SMALL SCREEN

Test at least:

- 393px normal phone
- 320px phone
- 280px narrow phone

Also test increased text scaling.

Do not reduce all spacing until the UI becomes cramped.

Instead allow appropriate wrapping/growth.

---

# 63. SCREENSHOT REQUIREMENT

Capture a new screenshot set after correction.

Do NOT reuse the previously rejected screenshots.

At minimum capture:

1. top of Create Ad
2. `جۆری ڕیکلام`
3. `ناوی ڕیکلام`
4. media section
5. Contact Destination
6. Contact Page collapsed
7. Contact Page expanded
8. Age
9. Gender
10. budget
11. schedule
12. payment
13. Sponsor button
14. Final Price collapsed
15. Final Price expanded
16. Final Price loading
17. scrolling beneath Price card
18. Final Price + Bottom Nav together
19. 320px layout
20. 280px layout
21. large-text layout

---

# 64. VISUAL MEASUREMENTS

Record actual measurements for:

- screen gutter
- section-heading font size
- section-heading font weight
- heading → control gap
- section → next section gap
- button height
- button radius
- input height
- Price card width
- Price card collapsed height
- Price card radius
- Price card → Bottom Nav gap

Do not simply write “balanced”.

Provide actual values.

---

# 65. ACCEPTANCE RULE FOR SPACING

A section is correctly spaced only when:

**gap between sections > gap between heading and its own control**

This must be visually obvious throughout the screen.

---

# 66. ACCEPTANCE RULE FOR FONT

Typography is accepted only if:

- heading is readable
- heading is not heavy-bold
- controls do not visually overpower headings
- field text is not oversized
- helper actions remain secondary
- all sections feel like one typography system

---

# 67. ACCEPTANCE RULE FOR PRICE

Final Price is accepted only when:

- it is a long horizontal rectangle
- nearly fills usable width
- corners are relatively sharp/moderate
- not a rounded floating bubble
- directly above Bottom Nav
- collapsed state is compact
- expand icon stays inside
- expands upward
- total stays anchored
- rows align
- divider is thin
- shadow is subtle
- Bottom Nav never moves
- Sponsor remains separate

---

# 68. DO NOT CLAIM SUCCESS FROM AUTOMATED TESTS ONLY

Automated tests passing does not mean the design is approved.

The previously rejected screenshot set proves this.

Final approval requires:

1. tests pass
2. new screenshots exist
3. screenshots visually match this specification
4. typography is reviewed
5. spacing is reviewed
6. Price Breakdown geometry is reviewed
7. narrow screens are reviewed

---

# 69. FINAL REPORT

Return:

1. files changed
2. typography tokens used
3. exact font sizes/weights
4. exact section spacing values
5. exact input geometry
6. exact button geometry
7. primary/inactive state implementation
8. secondary/inactive state implementation
9. Contact Page breakdown implementation
10. Final Price width
11. Final Price radius
12. Final Price collapsed height
13. Final Price/Bottom Nav spacing
14. expand/collapse implementation
15. loading implementation
16. Sponsor separation
17. responsive checks
18. screenshots captured
19. visual issues found during review
20. fixes applied after screenshot review

---

# FINAL NON-NEGOTIABLE SUMMARY

The final TikTok Create Ad screen must have:

- balanced Proxo/Auth font family
- lighter, cleaner font weights
- clear hierarchy
- correct heading positions
- larger spacing between sections
- smaller spacing inside a section
- no giant section cards
- clean open form
- solid blue primary selected controls
- gray inactive primary controls
- pale-blue selected secondary controls
- black inactive secondary controls
- soft shadows
- moderate corners

And most importantly:

# PRICE BREAKDOWN MUST BE A LONG HORIZONTAL RECTANGULAR CARD

- from near left edge to near right edge
- normal app margins only
- relatively sharp/moderate corners
- directly above Bottom Navigation
- compact when collapsed
- expands upward
- `کۆی گشتی` stays anchored
- subtle 3D shadow
- no floating rounded-bubble appearance
- no `بینینی وردەکاری` text
- icon-only disclosure
- Sponsor button completely separate

Do not make isolated visual patches.

Rebalance the complete TikTok Create Ad screen as one coherent design system and visually verify the final result from new screenshots.