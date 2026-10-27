# Proxo TikTok Create Sponsored Ad — STRICT FINAL IMPLEMENTATION PROMPT v3

> **SOURCE-BASED / NON-NEGOTIABLE / POINT-BY-POINT / PIXEL-BY-PIXEL**
>
> This specification is based on the current PR #46 implementation in:
>
> - `proxo_app/lib/screens/ad_create_screen.dart`
> - `proxo_app/lib/widgets/ad_form_components.dart`
>
> Work from the current PR code. Do not replace working business logic with a new unrelated implementation.
> Do not make every button solid blue.
> Do not redesign unrelated screens.
> Preserve Kurdish Sorani RTL, existing backend safety, payment logic, provider logic, account isolation, and all working validation.

---

# 0. CURRENT PR BASELINE — READ BEFORE EDITING

Before making changes, inspect the current implementation and preserve all working behavior.

The current PR has these relevant behaviors/components:

- `AdCreateScreen` is the main Create Ad screen.
- `AdFormSection` currently wraps sections in a large white card with radius and shadow.
- `AdChoice` currently uses one shared selected style.
- Current TikTok objective heading is `ئامانجی ڕیکلام`.
- Current TikTok objectives are only:
  - `بینین`
  - `نامە`
- Current TikTok message destination choices are:
  - `نامەی ڕاستەوخۆ`
  - `پەیوەندی دەرەکی`
- Current `پەڕەی پەیوەندی` uses a dropdown.
- Current audience section still includes:
  - `جۆری پۆل`
  - `جۆری ئامێر`
- Current `AdChoice` selected visual is light blue + blue border + blue text.
- Current `AdFormSection` creates the oversized section-card appearance the owner wants removed.

The implementation must refine this existing code rather than layering a second duplicate UI on top of it.

If a shared component is used by Meta or another screen, do not globally change it in a way that breaks those flows. Add explicit style variants or scoped components when necessary.

---

# 1. PRIMARY GOAL

Act as a senior Flutter engineer, senior UI/UX implementer, state-management engineer, and QA engineer.

Refine and fix the existing TikTok Create Sponsored Ad flow so that it becomes:

- clean
- flat
- open
- visually balanced
- readable
- responsive
- smooth
- Kurdish Sorani RTL
- visually lighter than the current implementation
- free of oversized section-wrapper cards
- safe against duplicate submission
- correct after failed submission
- correct in Create Page navigation
- correctly filtered by ad type
- fully screenshot-reviewed before completion

The supplied visual reference is a direction for:

- spacing
- hierarchy
- button proportions
- selected states
- inactive states
- typography
- subtle shadows
- final-price treatment

Do not blindly copy unrelated UI from the reference.

---

# 2. EXACT SECTION ORDER AND NAMES

Use these customer-facing section names and hierarchy in the TikTok Create Sponsored Ad screen.

## Required main flow

1. **جۆری ڕیکلام**
2. **ناوی ڕیکلام**
3. **شوێنی پەیوەندیکردن** — only when required
4. **پەڕەی پەیوەندی** — expandable/collapsible breakdown
5. relevant media/content fields
6. **شوێن**
7. **تەمەن**
8. **ڕەگەز**
9. budget/duration
10. schedule
11. payment
12. **سپۆنسەرکردن**
13. sticky **کۆی گشتی** card above Bottom Navigation

Do not keep the old customer-facing heading `ئامانجی ڕیکلام`.
Change it to:

# **جۆری ڕیکلام**

---

# 3. EXACT `جۆری ڕیکلام` OPTIONS

The TikTok ad-type selector must show exactly these four customer-facing choices:

1. **نامە و پەیوەندی**
2. **بینینەکان**
3. **خواردنگە**
4. **دابەزاندنی ئەپ**

Rename:

- `نامە` → `نامە و پەیوەندی`
- `بینین` → `بینینەکان`

Do not show the old labels anywhere in this flow.

Do not silently collapse these back into only `messages` and `views` visually. If backend/provider mapping still uses internal values, map the new customer-facing types safely while keeping customer UI exactly as specified.

---

# 4. CRITICAL VISUAL RULE — TWO BUTTON SYSTEMS

There are two different visual classes of selectable controls.

They must NOT use the same active/inactive style.

This distinction is mandatory.

---

# 5. BUTTON SYSTEM A — PRIMARY / IMPORTANT CAMPAIGN SELECTIONS

This visual system is for important campaign decisions such as:

- `جۆری ڕیکلام`
- `تەمەن`
- `ڕەگەز`
- `شوێن` when presented as selection buttons
- other major segmented campaign-choice controls of the same importance

## A1. PRIMARY — INACTIVE

When not selected:

- background = **white**
- text = **gray**
- border = **gray**
- shadow = very soft
- moderate radius
- no layout movement

The gray text must be clearly readable, not disabled-looking to the point of low contrast.

## A2. PRIMARY — ACTIVE

When selected:

- background = **solid balanced medium blue**
- text = **white**
- **NO visible border**
- suitable icon becomes white or uses an appropriate high-contrast selected state
- subtle soft shadow

### Important

Do not draw a separate border around a button that is already fully filled blue.

The solid blue fill is the selected boundary.

The blue must be:

- balanced
- medium
- pleasant
- not too dark
- not neon
- not over-saturated

---

# 6. BUTTON SYSTEM B — SECONDARY DESTINATION / RESOURCE CONTROLS

This visual system is specifically for:

- **هەموو پلاتفۆڕمەکان**
- **نامەی تیک تۆک**
- **پەڕەی پەیوەندی**
- similar destination/resource disclosure controls

These controls are intentionally different from `جۆری ڕیکلام`.

## B1. SECONDARY — INACTIVE

When not active/selected:

- background = **white**
- text = **black / near-black**
- border = **gray**
- subtle soft shadow
- moderate radius

### Critical difference

Inactive text here is **black**, not gray.

Do not copy the inactive text color from `جۆری ڕیکلام`.

## B2. SECONDARY — ACTIVE

When active/selected:

- background = **very light watery blue / pale blue**
- text = **blue**
- border = **blue**
- subtle soft shadow
- icon/logo remains clearly visible

Do not fill these buttons with solid primary blue.

Do not make their active text white.

Their active identity is:

**pale blue background + blue text + blue border**

---

# 7. COLOR-STATE MATRIX — NON-NEGOTIABLE

| Control type | Inactive | Active |
|---|---|---|
| `جۆری ڕیکلام`, `تەمەن`, `ڕەگەز`, important campaign choices | White background + **gray text** + gray border | **Solid medium blue background + white text + no visible border** |
| `هەموو پلاتفۆڕمەکان`, `نامەی تیک تۆک`, `پەڕەی پەیوەندی` | White background + **black text** + gray border | **Pale watery blue background + blue text + blue border** |

Do not deviate from this matrix.

---

# 8. SOFT BUTTON SHADOWS

Buttons may use a subtle shadow.

Requirements:

- low opacity
- short depth
- soft blur
- consistent
- no dark shadow
- no dramatic Material elevation

The shadow should only give slight separation from the white page.

Do not make controls look like floating cards.

---

# 9. CORNER RADIUS

Use balanced rounded rectangles.

Do not make controls:

- pill-shaped
- overly rounded
- circular-looking

Use a consistent moderate radius across:

- ad-type choices
- age
- gender
- destination choices
- page disclosure
- Sponsor button

---

# 10. SOFT PRESS / STATE TRANSITIONS

All selectable controls must feel soft when tapped.

Apply to:

- `جۆری ڕیکلام`
- `تەمەن`
- `ڕەگەز`
- `شوێن`
- `هەموو پلاتفۆڕمەکان`
- `نامەی تیک تۆک`
- page disclosure/selection
- schedule buttons
- similar segmented/selectable controls

Recommended animation:

- 120–200 ms
- `easeOutCubic` or equivalent smooth curve

Animate:

- background color
- text color
- border color
- subtle shadow
- selected indicator

Do not:

- bounce
- scale aggressively
- change button height
- shift neighboring widgets
- cause layout jump

---

# 11. REMOVE OVERSIZED `AdFormSection` CARD APPEARANCE

The current `AdFormSection` adds:

- white card
- large radius
- card padding
- shadow

around every section.

This creates the oversized card-heavy design that must be removed.

Refactor this screen so normal sections become visually open.

Use:

- section heading
- spacing
- control group
- field
- divider only where truly useful

Do not wrap every normal section in a giant elevated card.

## Important shared-component safety

If `AdFormSection` is shared with Meta or other screens, do not globally break those screens.

Choose one safe method:

- add a flat/open visual variant, or
- create a TikTok Create Ad open-section component, or
- conditionally style only this target flow

The final TikTok Create Ad screen must not retain the current giant-card appearance.

---

# 12. TYPOGRAPHY

The current UI is too regular/thin in some important areas.

Improve readability.

## Section headings

Use:

- larger readable size than helper text
- Medium or SemiBold weight
- clean RTL alignment
- clear hierarchy

## Control labels

Use a readable medium weight.

## Button text

Must not look thin.

## Helper text

Can remain smaller/lighter.

Do not make all text bold.

The hierarchy should be obvious:

**section heading → control label → helper/status text**

---

# 13. ICON USAGE

Use icons only when semantically useful.

Do not add icons beside every section title.

Appropriate places include:

- ad-type options
- `هەموو پلاتفۆڕمەکان`
- `نامەی تیک تۆک`
- page/resource rows
- media controls
- expand/collapse indicators

Use proper local assets where available.

Do not use emoji.

Do not use blurry screenshots as logos.

---

# 14. `شوێنی پەیوەندیکردن`

When `جۆری ڕیکلام = نامە و پەیوەندی`, show:

# **شوێنی پەیوەندیکردن**

with exactly these two customer-facing options:

1. **هەموو پلاتفۆڕمەکان**
2. **نامەی تیک تۆک**

These are BUTTON SYSTEM B controls.

Therefore:

## Inactive

- white
- black text
- gray border

## Active

- pale watery blue
- blue text
- blue border

Do not use solid-blue + white-text style here.

---

# 15. `هەموو پلاتفۆڕمەکان` ICONS

Show suitable communication-platform logos/icons inside this control.

Use only actual supported/relevant platform identities.

Requirements:

- compact
- consistent icon size
- visually balanced
- proper spacing
- no oversized logos
- no crowding
- RTL-safe

If the available contact channels depend on the selected customer page, keep icons aligned with actual supported destinations and do not advertise unsupported providers.

---

# 16. `نامەی تیک تۆک` ICON

Use the appropriate TikTok logo/icon.

Requirements:

- balanced size
- same control height as `هەموو پلاتفۆڕمەکان`
- same internal spacing
- same secondary visual system
- same soft shadow

Do not use a random generic message icon as the main TikTok identity.

---

# 17. `پەڕەی پەیوەندی` — MUST BECOME A BREAKDOWN / ACCORDION

The current implementation uses `DropdownButtonFormField`.

Replace that interaction with an:

# **Expandable / Collapsible Contact Page Breakdown**

The customer-facing label is exactly:

# **پەڕەی پەیوەندی**

This component uses BUTTON SYSTEM B.

---

# 18. `پەڕەی پەیوەندی` — COLLAPSED STATE

Collapsed state should be compact.

Show:

- label `پەڕەی پەیوەندی`
- selected page summary if selected
- small disclosure/chevron icon

If selected page exists, summary may show:

- small page image
- page name
- concise status

Do not display every page until expanded.

### Collapsed inactive style

If no page is selected:

- white background
- black text
- gray border

### Collapsed selected style

If a page is selected / component is active:

- pale watery blue background
- blue text for the primary disclosure label
- blue border
- soft shadow

Keep actual page name/status readable and balanced.

---

# 19. `پەڕەی پەیوەندی` — EXPANDED STATE

When tapped:

- expand smoothly downward
- rotate/change the disclosure icon
- show valid pages/resources
- preserve selected state
- do not reset the form

Each page row must show:

1. **page image/avatar/thumbnail**
2. **page name**
3. **page status**
4. selected indicator when chosen

Do not make each page row an oversized card.

Use compact rows.

---

# 20. PAGE FILTERING BY `جۆری ڕیکلام`

This is mandatory.

The expanded `پەڕەی پەیوەندی` must not show unrelated page types.

## `نامە و پەیوەندی`

Show only pages valid for communication/contact advertising.

## `خواردنگە`

Show only restaurant pages.

## `دابەزاندنی ئەپ`

Show only app-download pages/assets relevant to that flow.

## `بینینەکان`

Show only resources valid for the views/video flow.

Do not mix every page type together.

Use actual stored type/category data.

Prefer filtering before pagination/query return when the data layer supports it.

Do not rely only on hiding unrelated rows after everything is loaded.

---

# 21. PAGE STATUS

Show authoritative page status.

Do not invent a status.

Do not expose raw backend/provider enums if the app already has customer-friendly status text.

Status text should be visually secondary but readable.

---

# 22. PAGE IMAGE FALLBACK

Use the real page image when available.

If missing:

- use the existing Proxo fallback behavior
- do not invent a random image
- do not use unrelated platform artwork

---

# 23. `خواردنگە`

When `جۆری ڕیکلام = خواردنگە`:

- show only restaurant-related assets/pages
- `پەڕەی پەیوەندی` breakdown must contain only restaurant pages
- hide unrelated app-download fields
- hide irrelevant contact-destination controls if not needed by the business flow

Do not mix restaurant and ordinary contact pages.

---

# 24. `دابەزاندنی ئەپ`

When selected:

- show only app-download-related fields/resources
- filter resource/page selection to valid app-download assets
- hide unrelated restaurant fields
- hide irrelevant communication controls

Preserve all required validation.

---

# 25. `بینینەکان`

When selected:

- show only TikTok view/video-related fields
- show only valid resources/content for this objective
- hide unrelated restaurant/app-download/contact fields

Preserve existing provider/business logic.

---

# 26. REMOVE THESE CURRENT FIELDS COMPLETELY

Remove from the TikTok Create Sponsored Ad screen:

- **جۆری پۆل**
- **جۆری ئامێر**

These currently exist in `_audience()`.

Remove them from the customer UI and validation path for this flow.

Do not leave empty vertical space after removing them.

Do not break unrelated screens that may use the same underlying data.

---

# 27. `ناوی ڕیکلام` — AUTO DEFAULT

For every new Create Ad session, prefill:

`New Ad + today’s date`

Example:

`New Ad 24-10-2026`

Rules:

- generated for a new ad session
- customer may edit it
- once customer edits it, never overwrite their edit
- do not add platform name
- do not add numbering
- do not silently regenerate when other fields change

---

# 28. `تەمەن`

TikTok age choices remain major campaign controls.

Use BUTTON SYSTEM A:

## Inactive

- white
- gray text
- gray border

## Active

- solid medium blue
- white text
- no visible border

Multiple active age ranges must each clearly show selected state.

Keep tap animation soft.

---

# 29. `ڕەگەز`

Use BUTTON SYSTEM A.

## Inactive

- white
- gray text
- gray border

## Active

- solid medium blue
- white text
- no visible border

Keep dimensions stable between states.

---

# 30. OTHER IMPORTANT CAMPAIGN CHOICES

If other controls are visually equivalent to age/gender/ad type, use BUTTON SYSTEM A.

Do not classify resource/destination/disclosure controls as primary.

The visual hierarchy must make it obvious which controls are:

- major campaign decisions
- secondary destination/resource choices

---

# 31. `سپۆنسەرکردن`

The Sponsor button is a primary CTA.

It may use:

- solid balanced medium blue
- white text
- no visible border needed
- moderate radius
- subtle soft shadow

But:

# DO NOT PUT `سپۆنسەرکردن` INSIDE THE FINAL PRICE CARD.

It must remain a separate form action in the normal form content.

---

# 32. FINAL PRICE — REQUIRED STRUCTURE

Redesign Final Price as:

# **Floating Sticky Expandable/Collapsible Final Price Card**

It must sit directly above the existing Bottom Navigation.

It must be separate from the Sponsor button.

---

# 33. FINAL PRICE — COLLAPSED

Default state:

Show only:

- **کۆی گشتی**
- current total
- small expand icon

Do not display:

`بینینی وردەکاری`

The owner explicitly does not want this text.

Use icon-only disclosure.

---

# 34. FINAL PRICE — EXPANDED

When the disclosure icon is tapped:

- smoothly expand upward
- keep the panel anchored above Bottom Navigation
- show price details
- keep Bottom Navigation stationary
- do not scroll-jump the form

Show existing authoritative price rows:

- `نرخی لاوەکی`
- `کرێی خزمەتگوزاری`
- `داشکاندن` only if present
- divider
- `کۆی گشتی`

Do not invent fees.

---

# 35. FINAL PRICE — COLLAPSE

When tapped again:

- smoothly collapse
- hide detail rows
- return to compact height
- keep `کۆی گشتی` visible
- remain above Bottom Navigation

Do not dismiss the card.

---

# 36. FINAL PRICE — SOFT 3D / LAYERING

This component should have slightly more depth than ordinary controls.

Use:

- white surface
- controlled radius
- soft shadow
- subtle elevation

When form content scrolls underneath, the card should visually remain on a higher layer.

Do not use:

- dark heavy shadow
- thick border
- dramatic 3D
- huge blur

---

# 37. FINAL PRICE — LOADING

When a price-affecting value changes:

1. show a compact loading state inside the Final Price card
2. wait for authoritative price recalculation
3. show the new final total

Do not immediately show a guessed value.

Do not block the full screen.

Do not move Bottom Navigation.

---

# 38. BOTTOM NAVIGATION

Do not redesign Bottom Navigation.

Only ensure:

- Final Price sits directly above it
- safe area is respected
- Bottom Nav remains tappable
- price panel never covers nav items
- keyboard behavior does not break positioning

---

# 39. FAILED AD SUBMISSION — FIX THE CURRENT STATE BUG

There is an existing problem where a failed ad submission can leave the Create Ad flow in a stale retry/pending state.

After the user leaves and returns, the screen may still behave like it must resend the previous request.

Fix this.

---

# 40. NEVER AUTO-RETRY A DEFINITIVELY FAILED AD

A failed ad must not automatically submit because:

- app reopened
- route reopened
- widget rebuilt
- connectivity returned
- local state restored
- customer returned later

A new provider/server submission requires a deliberate user action.

Prevent duplicate paid actions.

---

# 41. CLEAN NEW SESSION AFTER DEFINITIVE FAILURE

If the backend/provider confirms the previous attempt definitely failed before ad creation, and the user leaves Create Ad:

Next time they open Create Ad, initialize a clean new form.

Clear transient state:

- submitting
- stale error
- retry state
- old loader
- temporary submission state
- disabled CTA caused by old attempt

Do not reopen with an automatic Retry workflow.

---

# 42. DO NOT DUPLICATE A REAL SUCCESSFUL / UNCERTAIN AD

Distinguish:

1. definitely failed
2. processing
3. successful
4. uncertain/reconciliation required

If backend/provider may already have accepted the request, do not blindly create a second ad.

Use authoritative state and idempotency.

---

# 43. RAPID TAP PROTECTION

Rapidly tapping `سپۆنسەرکردن` must not create duplicate requests.

While processing:

- block duplicate submit
- show clear loading
- use existing idempotency protections

After definitive failure:

- do not create an automatic retry queue

---

# 44. PAGE CREATION / TOOLS ERROR — MUST BE FIXED

The existing Page Creation / related tools flow still has an unresolved error.

Do not mark the task complete until the actual underlying error is fixed.

Audit:

- page list loading
- empty state
- Create Page navigation
- form validation
- save
- Supabase/backend request
- error handling
- successful persistence
- list refresh
- return navigation
- loading state

Do not hide the problem with UI-only handling.

---

# 45. CREATED PAGE MUST PERSIST

After a page is successfully created:

- save it authoritatively
- refresh page data
- keep it after route changes
- keep it after app restart
- scope it to the correct customer
- make it immediately available to Create Ad

Never show a fake local success if backend save failed.

---

# 46. NO-PAGE FLOW FROM CREATE AD

If the selected ad type requires a page and the customer has no valid page:

- show the correct no-page state
- offer Create Page
- open the relevant Create Page flow directly

Do not route through an unrelated page-preview/cards screen.

---

# 47. BACK FROM CREATE PAGE — SOURCE-AWARE NAVIGATION

Scenario:

1. customer is inside Create Advertisement
2. no valid page exists
3. customer opens Create Page
4. customer presses Back

Expected:

# Return directly to Create Advertisement.

Do not send them to:

- page preview
- created-page cards
- general page list
- unrelated tab

Navigation must remember that Create Page was entered from Create Ad.

---

# 48. PRESERVE CREATE-AD CONTEXT DURING TEMPORARY CREATE PAGE

When customer leaves Create Ad only to create a required page:

Preserve compatible form state such as:

- `جۆری ڕیکلام`
- targeting
- schedule
- budget
- compatible selections

After successful page creation:

1. save page authoritatively
2. refresh filtered page list
3. return to Create Ad
4. restore compatible form state
5. show new page immediately in the `پەڕەی پەیوەندی` breakdown
6. clear no-page error
7. continue normally

Do not force page preview first.

---

# 49. TWO DIFFERENT RESET CASES

Do not confuse:

## Case A — temporary page creation

Create Ad → Create Page → Back/Success

Preserve compatible Create Ad state.

## Case B — definitive failed ad submission and user leaves

Later opening Create Ad:

Start a fresh clean new-ad session.

These are different behaviors.

---

# 50. ROUTE STACK SAFETY

Repeated:

Create Ad → Create Page → Back

must not stack duplicate Create Ad routes.

Successful:

Create Ad → Create Page → success → Create Ad

must return to the intended existing route.

Use correct pop/result/replacement behavior.

---

# 51. RTL

Verify Kurdish Sorani RTL for:

- section titles
- all four ad types
- age
- gender
- location
- platform icons
- TikTok logo
- page image/name/status
- disclosure arrows
- price values
- error messages
- Sponsor button
- sticky price card

Do not hardcode LTR layout positions.

---

# 52. RESPONSIVENESS

Test small Android screens.

Verify:

- four ad-type controls do not overflow
- Kurdish labels remain readable
- platform icon row fits
- page breakdown rows fit
- no horizontal overflow
- Sponsor button remains reachable
- sticky price card does not hide content
- expanded price details remain usable
- Bottom Navigation remains usable

---

# 53. PERFORMANCE

Avoid unnecessary rebuilds.

Especially optimize:

- scrolling with sticky Final Price
- page breakdown expand/collapse
- objective switching
- price updates

Use lightweight animations.

Do not add expensive blur/effects.

---

# 54. MANDATORY SCREENSHOTS

After implementation, capture real app screenshots for at least:

1. Main TikTok Create Ad screen
2. `جۆری ڕیکلام` section
3. `نامە و پەیوەندی` active
4. `بینینەکان` active
5. `خواردنگە` active
6. `دابەزاندنی ئەپ` active
7. inactive ad-type buttons showing gray text + gray border
8. `تەمەن` active solid-blue state
9. `ڕەگەز` active solid-blue state
10. `شوێنی پەیوەندیکردن`
11. `هەموو پلاتفۆڕمەکان` inactive: black text + gray border
12. `هەموو پلاتفۆڕمەکان` active: pale blue + blue text + blue border
13. `نامەی تیک تۆک` inactive: black text + gray border
14. `نامەی تیک تۆک` active: pale blue + blue text + blue border
15. `پەڕەی پەیوەندی` collapsed
16. `پەڕەی پەیوەندی` expanded
17. page list showing image + name + status
18. contact-page filtered list for `نامە و پەیوەندی`
19. restaurant-only filtered list for `خواردنگە`
20. app-download filtered resource list
21. views-related resource state
22. Final Price collapsed
23. Final Price expanded
24. Final Price loading
25. screen scrolled with Final Price floating above content
26. Sponsor button visibly separate from Final Price
27. no-page state
28. Create Page opened from Create Ad
29. Back returned directly to Create Ad
30. newly created page immediately visible
31. failed ad submission state
32. fresh clean Create Ad after leaving definitive failed submission
33. small-screen rendering
34. validation/error state

---

# 55. SCREENSHOT REVIEW — DO NOT SKIP

The developer must review the screenshots, not merely capture them.

Check:

- primary vs secondary button color hierarchy
- inactive primary gray text
- inactive secondary black text
- active primary solid blue / white text / no border
- active secondary pale blue / blue text / blue border
- button radius
- soft shadows
- heading position
- font size
- font weight
- RTL
- icon/logo size
- page image/name/status alignment
- page breakdown behavior
- spacing
- Final Price elevation
- Bottom Nav relationship
- Sponsor separation
- no clipping
- no overflow

If anything looks uneven, fix it before completion.

---

# 56. FUNCTIONAL TEST MATRIX

## `جۆری ڕیکلام`

Switch among all four types repeatedly.

Expected:

- active type = solid blue + white text + no visible border
- inactive types = white + gray text + gray border
- correct dependent sections only

## `تەمەن`

Select/deselect ranges.

Expected:

- selected = solid blue + white
- inactive = white + gray text + gray border
- smooth transition

## `ڕەگەز`

Switch options.

Expected:
same primary-selection rules.

## Secondary destination controls

Test:

- `هەموو پلاتفۆڕمەکان`
- `نامەی تیک تۆک`

Expected inactive:

- white
- black text
- gray border

Expected active:

- pale watery blue
- blue text
- blue border

## `پەڕەی پەیوەندی`

Expand/collapse repeatedly.

Expected:

- smooth
- selected state preserved
- image/name/status visible
- no form reset
- correct list for current ad type

## Price

Change a price-affecting value.

Expected:

loading → authoritative total.

Expand/collapse Final Price repeatedly.

Expected:

- smooth
- no Bottom Nav movement
- no layout jump
- no state corruption

## Failed submission

Simulate server/provider failure.

Expected:

- clear failure
- no fake success

Leave flow and reopen.

Expected:

- fresh form after definitive failure
- no stale retry
- no automatic submission

Restart app.

Expected:

- failed ad not automatically resent

Restore connectivity.

Expected:

- failed ad not automatically resent

## Duplicate submit

Rapidly tap Sponsor.

Expected:

- one valid request only

## Page creation

Create Ad → missing required page → Create Page.

Press Back.

Expected:

- direct return to Create Ad

Create successfully.

Expected:

- return to Create Ad
- page persists
- new page appears immediately in filtered breakdown

Fail page creation.

Expected:

- stay on Create Page
- preserve input
- show error

Restart after successful page creation.

Expected:

- page still exists

---

# 57. FINAL ACCEPTANCE CHECKLIST

Do not mark complete unless all are true:

- `ئامانجی ڕیکلام` changed to `جۆری ڕیکلام`
- four exact ad types implemented
- `نامە` changed to `نامە و پەیوەندی`
- `بینین` changed to `بینینەکان`
- large section cards removed
- `AdFormSection` heavy-card behavior removed/scoped safely for TikTok flow
- primary and secondary selection styles are separate
- inactive primary = gray text + gray border
- active primary = solid blue + white text + no border
- inactive secondary = black text + gray border
- active secondary = pale blue + blue text + blue border
- soft shadows implemented
- balanced non-pill radius
- `شوێنی پەیوەندیکردن` implemented
- `هەموو پلاتفۆڕمەکان` implemented with appropriate icons
- `نامەی تیک تۆک` implemented with TikTok identity
- `پەڕەی پەیوەندی` converted from dropdown to expandable breakdown
- expanded page row shows image + name + status
- page/resource list filters by ad type
- `جۆری پۆل` removed
- `جۆری ئامێر` removed
- Ad Name defaults to `New Ad + today’s date`
- Final Price is sticky above Bottom Nav
- Final Price has subtle 3D layering
- no `بینینی وردەکاری` text
- icon-only Final Price expand/collapse
- price loading works
- Sponsor button is separate
- failed submission does not auto-retry
- fresh session occurs after definitive failure
- duplicate submission protected
- Page Creation error fixed
- page persists after restart
- Back from Create Page opened by Create Ad returns to Create Ad
- no wrong preview/cards detour
- RTL correct
- small screens correct
- screenshots captured
- screenshots reviewed

---

# 58. FINAL REPORT REQUIRED

When finished, report:

1. Exact files changed
2. Shared components changed
3. How `AdFormSection` was flattened/scoped
4. How `AdChoice` was split into primary/secondary visual variants
5. Exact `جۆری ڕیکلام` labels
6. Conditional ad-type behavior
7. `شوێنی پەیوەندیکردن` implementation
8. platform/TikTok icon implementation
9. `پەڕەی پەیوەندی` accordion implementation
10. page image/name/status implementation
11. objective-based filtering
12. `جۆری پۆل` removal
13. `جۆری ئامێر` removal
14. automatic Ad Name implementation
15. typography/spacing changes
16. Final Price floating card
17. Final Price expand/collapse
18. price loading
19. Sponsor button separation
20. failed-submit reset fix
21. duplicate-submit protection
22. Page Creation error fix
23. page persistence fix
24. navigation fix
25. tests executed
26. screenshots captured
27. screenshot review result
28. remaining blockers, if any

Do not claim any item is complete unless it was actually implemented and tested.

---

# FINAL NON-NEGOTIABLE COMMAND

Do not simply “make the screen prettier.”

The work is complete only when:

1. the current PR implementation has been carefully refactored,
2. the exact color-state hierarchy above is implemented,
3. the page breakdown and page filtering work,
4. the current submission/page/navigation bugs are fixed,
5. the Final Price interaction is correct,
6. every required state is captured in real screenshots,
7. the screenshots are visually reviewed,
8. all relevant tests pass.

### Remember the most important color rule:

**PRIMARY IMPORTANT CONTROLS**
- inactive = white + gray text + gray border
- active = solid blue + white text + NO visible border

**SECONDARY DESTINATION / RESOURCE CONTROLS**
- inactive = white + black text + gray border
- active = pale watery blue + blue text + blue border

Do not mix these two systems.
Do not make every button solid blue.
Do not make inactive secondary text gray.
Do not put a border around fully solid-blue selected buttons.
