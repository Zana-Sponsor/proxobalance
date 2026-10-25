# PROXO — APP-WIDE STRICT DESIGN, PNG ICON SYSTEM, FUNCTIONAL QA & RELEASE UPDATE

> **NON-NEGOTIABLE / POINT-BY-POINT / PIXEL-BY-PIXEL**
>
> The refined TikTok Create Advertisement screen is the primary visual baseline for the rest of the Proxo application.
>
> Do NOT redesign every screen independently.
>
> Build one coherent Proxo design system and carefully apply it throughout the application while preserving working functionality, backend safety, RTL, account isolation, and existing financial/provider logic.

---

# 1. PRIMARY GOAL

Bring these major areas into one coherent visual and functional system:

- Home
- Create Advertisement
- Create Page
- Profile
- Menu / Sidebar
- Authentication
- Best Results
- Ads
- TikTok Account Connection
- Empty states
- Error states
- Update flow
- relevant secondary screens

The application must feel like **one product**, not multiple unrelated designs.

A customer must not feel that:

- Home belongs to one app
- Create Ad belongs to another
- Create Page belongs to another
- Profile belongs to another
- Auth belongs to another

---

# 2. VISUAL BASELINE

Use the refined **Create Advertisement** visual system as the main baseline.

Carry forward:

- clean white surfaces
- open section layout
- balanced blue
- consistent gray
- moderate corner radius
- soft shadows
- readable typography
- clear heading hierarchy
- generous section separation
- consistent RTL
- balanced field geometry
- smooth state transitions

Do not blindly copy widgets from Create Ad.

Reuse the **design language**, dimensions, typography hierarchy, spacing rhythm, and color hierarchy.

---

# 3. PIXEL-BY-PIXEL REQUIREMENT

Work:

**point by point and pixel by pixel.**

Do not stop when a screen only compiles.

Inspect:

- x/y alignment
- horizontal margins
- vertical spacing
- font size
- font weight
- line height
- icon size
- icon baseline
- field height
- button height
- card height
- border thickness
- corner radius
- shadow strength
- RTL positioning
- text clipping
- image clipping
- small-screen rendering

---

# 4. SHARED TYPOGRAPHY SYSTEM

Create one typography system for the entire app.

Do not allow each screen to define random font sizes and weights.

Define shared roles for:

- AppBar title
- screen title
- section heading
- field label
- field value
- button text
- helper text
- status text
- amount/price
- empty-state title
- empty-state description

---

# 5. TYPOGRAPHY VISUAL TARGET

Use the same Proxo/Auth font family unless there is a genuine technical reason not to.

Do not introduce a random new font.

Balance primarily through:

- size
- weight
- line height
- spacing

## AppBar title

Approximately:

- 18sp
- Medium
- readable
- not heavy Bold

## Section headings

Approximately:

- 16–17sp
- Medium / controlled SemiBold
- clear black / near-black
- never excessively heavy

## Field labels

Approximately:

- 14–16sp
- Medium

## Field values

Approximately:

- 14–15sp
- Regular / Medium

## Button labels

Approximately:

- 14–15sp
- Medium

## Helper/status text

Approximately:

- 12–14sp
- Regular / Medium

---

# 6. SHARED SPACING SYSTEM

Create shared spacing tokens.

The relationship between sections is critical.

## Heading → own controls

Use a smaller internal gap.

Target:

**14–18dp**

## End of section → next heading

Use a clearly larger external gap.

Target:

**28–36dp**

## Controls inside one group

Target:

**10–12dp**

## Standard horizontal screen gutter

Target approximately:

**20dp**

Adjust responsively where necessary.

---

# 7. VISUAL RHYTHM RULE

Every screen should visually read as:

```text
SECTION HEADING

small internal gap

CONTROL / CONTENT

larger external gap

NEXT SECTION HEADING
```

Do not allow:

```text
heading
control
heading
control
heading
control
```

with almost identical spacing.

That makes the screen visually crowded and unclear.

---

# 8. SHARED CONTROL GEOMETRY

Normalize:

- button height
- field height
- radius
- horizontal padding
- icon-to-label spacing

Suggested targets:

- field height: around 52–56dp
- important button height: around 48–52dp
- normal control radius: around 10–14dp
- input horizontal padding: around 16dp

Do not create pill-shaped controls unless explicitly required.

---

# 9. SHARED COLOR SYSTEM

Use the same core family everywhere:

- white
- near-black
- gray
- balanced Proxo blue
- pale watery blue
- soft gray border

Do not invent a separate blue for each screen.

---

# 10. IMPORTANT PRIMARY SELECTION CONTROLS

Examples:

- `جۆری ڕیکلام`
- `تەمەن`
- `ڕەگەز`
- equivalent major campaign selections

## Inactive

- white background
- gray text
- gray border
- subtle shadow

## Active

- solid balanced medium blue
- white text
- no visible border
- subtle shadow

---

# 11. SECONDARY RESOURCE / DESTINATION CONTROLS

Examples:

- `هەموو پلاتفۆڕمەکان`
- `نامەی تیک تۆک`
- `پەڕەی پەیوەندی`
- equivalent secondary selectors

## Inactive

- white
- black / near-black text
- gray border

## Active

- pale watery blue background
- blue text
- blue border
- subtle shadow

Do not mix these states with the primary selection system.

---

# 12. PNG ICON SYSTEM — CRITICAL

Profile, Menu/Sidebar, Home shortcuts, and other suitable app sections must use **high-quality real PNG icons** where appropriate.

The visual goal is similar to polished icon libraries such as:

- Flaticon
- other professional licensed PNG icon libraries
- high-quality icon resources discoverable through Google Images

However:

**Google Images is for discovery only.**

Do not copy an arbitrary image from Google search results without checking its original source and usage rights.

Use the original source and ensure the icon has a license compatible with use in the Proxo application.

---

# 13. PNG ICON SOURCE REQUIREMENT

When choosing a PNG icon:

1. search for a semantically correct icon
2. prefer professional libraries such as Flaticon or another reputable source
3. open the original source
4. verify license/attribution requirements
5. download a high-quality PNG
6. store it locally in the app
7. document the source/license if required

Do not hotlink icons.

Do not rely on remote URLs at runtime.

---

# 14. LOCAL PNG ASSETS ONLY FOR THESE UI ICONS

After selecting the icon:

- store it inside the project assets
- add it correctly to Flutter assets
- render it from local application assets

Do not load Menu/Profile icons from remote URLs.

Do not use browser-cached images.

Do not use screenshots of icons.

---

# 15. DO NOT USE RANDOM GENERIC MATERIAL ICONS

If a high-quality relevant PNG icon is intentionally required for a section, do not substitute an unrelated Material icon simply because it is easier.

Examples:

For:

- Profile
- Security
- Wallet
- Transactions
- Notifications
- Support
- Settings
- Language
- Logout

choose PNG artwork that clearly communicates the actual section.

The icons must look intentionally chosen.

---

# 16. PNG ICON VISUAL NORMALIZATION

Do not simply set every PNG to the same raw width.

Different source PNGs may contain different transparent padding.

Normalize based on **visual weight**.

Check:

- visible icon bounds
- internal transparent padding
- icon stroke/fill weight
- visual center
- baseline
- shape density

The icons must look equal even if their source files differ.

---

# 17. PNG ICON SIZE SYSTEM

Define one shared icon box system.

For example:

- normal section icon box: approximately 24–28dp
- larger Home feature icon: approximately 28–32dp where appropriate

Keep consistent.

Do not allow:

- one icon at 18dp
- another visually at 35dp
- random alignment

---

# 18. ICON + TEXT ALIGNMENT

For every row:

- icon
- spacing
- label

must align properly.

Suggested icon-to-label gap:

approximately **10–12dp**.

In RTL, maintain correct placement.

---

# 19. ICON BACKGROUND

Do not put every PNG inside a heavy colored square.

Use:

- transparent icon
- subtle soft surface only if needed
- balanced spacing

The icon itself should remain the visual element.

---

# 20. ICON LICENSING / ATTRIBUTION

If an icon source requires attribution:

- preserve the required attribution
- document it in the project
- include appropriate license documentation

Do not ignore licensing requirements.

Do not ship copyrighted graphics with unclear rights.

---

# 21. CREATE PAGE — MATCH CREATE AD

The full **Create Page** experience must visually match Create Ad.

Update:

- AppBar
- section headings
- labels
- fields
- page type choices
- help actions
- button geometry
- validation
- spacing
- loading
- errors

Do not wrap every Create Page section in a giant card.

Use the same open layout.

---

# 22. CREATE PAGE MUST FULLY WORK

Test:

- page list
- no-page state
- Create Page
- page types
- input validation
- submission
- backend save
- Supabase response
- persistence
- route return
- app restart
- correct user ownership

No fake local success.

---

# 23. CREATE PAGE FROM CREATE AD

When entered from Create Ad:

Back must return directly to Create Ad.

Do not send the user to:

- page preview
- page card list
- unrelated screen

---

# 24. CREATE PAGE SUCCESS RETURN

After successful Page Creation:

1. authoritative backend save completes
2. page list refreshes
3. return to existing Create Ad route
4. preserve compatible ad form state
5. newly created page appears immediately
6. customer continues normally

---

# 25. HOME SCREEN — MATCH CREATE AD

Home must use the same:

- typography
- blue
- spacing
- horizontal margin
- button geometry
- card geometry
- shadows
- PNG icon style

Do not let Home look unrelated.

---

# 26. HOME GRADIENT BANNER

Create a polished blue gradient banner.

Use:

- Proxo blue
- lighter complementary blue
- restrained gradient
- clean typography
- subtle depth
- balanced radius

Do not use:

- neon gradient
- too many colors
- overly dark gradient
- flashy visual noise

---

# 27. HOME BANNER CONTENT

The banner should communicate useful existing information.

Possible valid roles:

- Create Advertisement shortcut
- important service update
- current meaningful Proxo announcement

Do not invent fake user statistics.

Keep the banner visually concise.

---

# 28. HOME BANNER ICON

If the banner uses an icon:

use a high-quality local PNG icon from the approved PNG asset system.

Do not use random emoji.

---

# 29. HOME BEST RESULTS

Keep Home Best Results compact.

Do not show full details on Home.

Detailed information belongs on the dedicated Best Results screen.

---

# 30. HOME BEST RESULTS THUMBNAIL BUG

Fix the existing thumbnail instability where the Best Results advertisement image sometimes breaks or changes incorrectly.

Audit:

- ad ID
- image URL
- widget key
- caching
- failed loading state
- stale thumbnail reuse
- race condition
- rebuild
- card recycling

The displayed thumbnail must always correspond to the correct advertisement.

---

# 31. THUMBNAIL FALLBACK

If there is truly no valid image:

show the approved Proxo fallback.

Do not show:

- broken-image icon
- previous advertisement image
- stale image
- malformed blank container

---

# 32. BEST RESULTS SCREEN

Redesign/rebalance dedicated Best Results.

Use same design system.

Normalize:

- cards
- thumbnail size
- title
- status
- objective
- budget
- metrics
- spacing
- expansion

Cards should appear balanced and consistent.

---

# 33. PROFILE — MATCH CREATE AD

Redesign/rebalance Profile using:

- same AppBar
- same typography hierarchy
- same horizontal gutter
- same spacing
- same blue
- same gray
- same soft shadows

Use clean grouped sections.

Avoid giant wrapper cards.

---

# 34. PROFILE PNG ICONS

Profile section icons must use **appropriate professional local PNG icons**.

Preferred workflow:

- discover using reputable icon resources such as Flaticon or similar
- Google search can help find sources
- fetch from original licensed source
- save locally
- normalize visual size

Do not use generic icons that do not match the section meaning.

---

# 35. MENU / SIDEBAR PNG ICONS

Menu must use the same PNG visual language as Profile.

Ensure:

- same icon box
- same visual weight
- same spacing
- same typography
- correct RTL
- clean selected state

Do not mix:

- Solar SVG
- random Material icons
- random PNG styles

without a deliberate visual reason.

The Menu icon family must look coherent.

---

# 36. AUTH — SAME TYPOGRAPHY

Auth typography must visually align with the rest of the updated app.

Normalize:

- title
- label
- input
- helper
- button
- validation message

Do not make Auth text much larger/smaller than the main app.

---

# 37. AUTH COLORS

Use the same:

- blue
- black
- gray
- white
- border gray

as the primary application system.

---

# 38. SIGN-UP BY MOBILE NUMBER ONLY

Self-registration should be centered on mobile number.

Do not require email as the main sign-up identity.

Use:

- Iraq mobile number
- proper normalization
- OTP verification
- current approved password/account setup only where required

---

# 39. PHONE NORMALIZATION

Avoid duplicate identities due to:

- `0750...`
- `750...`
- `+964750...`
- Arabic/Kurdish digits

Normalize consistently through the existing secure Auth path.

---

# 40. ERROR MESSAGES — MANUAL CLOSE

Temporary errors must have a manual dismissal control.

Use:

- clear close icon
- adequate tap target
- RTL-correct position

The customer should not have to wait.

---

# 41. ERROR AUTO-DISMISS

For temporary recoverable error notices:

target approximately **2–3 seconds**, adjusted if the text needs longer to read.

Critical/action-required errors should remain as needed.

---

# 42. ERROR STATE RECOVERY

Recoverable errors must not leave:

- disabled form
- frozen navigation
- stale loading
- permanent Retry state

Restore interaction appropriately.

---

# 43. TIKTOK CONNECTION QA

Verify:

- connect account
- authorization flow
- QR/official flow when required
- account verification
- selected account
- videos
- disconnect
- reconnect
- account switching
- persisted state
- strict customer isolation

Do not ship a decorative Connect button with a broken backend flow.

---

# 44. CREATE ADVERTISEMENT FUNCTIONAL QA

Test:

- four ad types
- conditional fields
- page/resource filtering
- Contact Destination
- TikTok account flow
- video
- location
- age
- gender
- budget
- duration
- schedule
- payment
- pricing
- Sponsor
- failed submission
- duplicate-submit protection
- successful submission

---

# 45. PRICE BREAKDOWN — APPROVED DESIGN

Keep the newly requested design:

# LONG HORIZONTAL EXPANDABLE PRICE CARD

It must:

- span nearly full usable width
- have only normal app horizontal margins
- use moderate/sharper corners
- sit directly above Bottom Navigation
- have subtle 3D elevation
- remain compact when collapsed
- expand upward
- use icon-only disclosure
- keep total anchored
- keep Sponsor separate

---

# 46. PRICE CARD COLLAPSED

Show only:

- `کۆی گشتی`
- total value
- small disclosure icon

No `بینینی وردەکاری` text.

---

# 47. PRICE CARD EXPANDED

Show:

- `نرخی لاوەکی`
- `کرێی خزمەتگوزاری`
- `داشکاندن` only if applicable
- thin divider
- `کۆی گشتی`

Keep amounts aligned.

Do not make this a giant form card.

---

# 48. PRICE CARD GEOMETRY

Visual target:

- long horizontal rectangle
- nearly full width
- around 8–12dp radius
- compact row spacing
- subtle upward shadow

Do not use the rejected rounded floating-bubble design.

---

# 49. PRICE LOADING

When price recalculates:

- keep card geometry stable
- show compact loader inside amount area
- wait for authoritative result
- show updated amount

Do not flash stale totals as final.

---

# 50. SPONSOR BUTTON

`سپۆنسەرکردن` must remain separate from Price Breakdown.

It stays inside scrollable form content.

Do not merge Sponsor with the fixed price surface.

---

# 51. APP-WIDE EMPTY STATES

Redesign consistently:

- no ads
- no pages
- no contact pages/resources
- no Best Results

Use:

- suitable icon/illustration
- clear heading
- short explanation
- clear CTA

Keep same design system.

---

# 52. APPBAR CONSISTENCY

Audit AppBars across:

- Home
- Ads
- Profile
- Create Ad
- Create Page
- Best Results
- secondary pages

They should feel related.

Do not leave Ads AppBar visibly different without functional justification.

---

# 53. UPDATE DELIVERY FOR EXISTING USERS

Implement/verify an app-version check so customers using old versions can receive a new-update notice when the approved new release is available.

Support:

- latest version
- minimum supported version
- update destination
- message
- optional/required update

---

# 54. OPTIONAL UPDATE

If old but supported:

show:

- Update
- Later

Use Proxo design.

Do not spam every navigation action.

---

# 55. REQUIRED UPDATE

If app version is below the minimum supported version:

show a required-update state.

But only activate this after the new build is genuinely available and verified.

Do not lock customers out prematurely.

---

# 56. UPDATE UI DESIGN

Update banner/dialog must use:

- same typography
- same PNG icon system where appropriate
- same blue
- same radius
- same spacing

---

# 57. BACKWARD COMPATIBILITY

Verify old versions during rollout.

Check:

- Auth
- ads
- pages
- TikTok connection
- balance
- payments
- notifications
- API fields
- migrations

Prefer additive compatibility.

---

# 58. PRODUCTION MIGRATION ORDER

Before publishing the client:

- required migrations must be applied
- RLS must be correct
- existing user data preserved
- migrations verified

Do not publish a client depending on unapplied schema.

---

# 59. RELEASE ORDER

Use this release sequence:

1. finish visual implementation
2. finish functional fixes
3. verify PNG assets/licenses
4. run tests
5. capture screenshots
6. manually review screenshots
7. verify preview/staging
8. verify backend compatibility
9. apply approved production migrations
10. build production app
11. production smoke test
12. release update
13. enable optional update message
14. only later enforce minimum supported version if needed

---

# 60. FULL BUTTON QA

Test all major actions:

- Home buttons
- Create Ad
- Sponsor
- Create Page
- Save Page
- Back
- Profile rows
- Menu rows
- Auth
- OTP
- Logout
- TikTok connect/disconnect
- Ads
- Best Results
- Retry
- manual error close
- app update

No dead controls.

---

# 61. NAVIGATION QA

Verify:

- Home → Create Ad
- Home → Create Page
- Create Ad → Create Page → Back
- Create Ad → Create Page → Success
- Home → Profile
- Menu routes
- Ads → Details
- Best Results → Details
- Auth → Home
- Logout → Auth
- Update flow

No duplicate routes.

---

# 62. DATA ISOLATION

Verify strict user separation for:

- ads
- pages
- TikTok accounts
- page resources
- media
- thumbnails
- Best Results
- balance
- receipts
- drafts

Do not mix users.

---

# 63. PERFORMANCE

Check:

- Home load
- image load
- Profile
- Menu
- Create Ad
- Create Page
- TikTok connection
- scrolling
- Price Breakdown
- Best Results

Do not add expensive visual effects.

---

# 64. SCREENSHOT REQUIREMENT

Capture NEW real screenshots after implementation.

Do not reuse old rejected screenshots.

At minimum:

## Home
- main
- gradient banner
- Best Results summary
- empty state

## Create Ad
- four ad types
- contact destination
- page selector
- TikTok connection
- age
- gender
- budget
- payment
- price collapsed
- price expanded
- Sponsor

## Create Page
- form
- all page types
- error
- success

## Profile
- main
- PNG icons
- grouped settings

## Menu
- full Menu with PNG icons

## Auth
- phone sign-up
- login
- OTP

## Best Results
- list
- detail/expanded
- thumbnail fallback

## Ads
- list
- empty
- details

## Update
- optional update
- required update

---

# 65. SCREENSHOT SIDE-BY-SIDE REVIEW

Compare major screens side by side.

Check:

- gutter
- heading weight
- heading size
- section gap
- button height
- field height
- radius
- shadows
- PNG icon visual size
- icon style consistency
- blue tone
- gray tone
- RTL

Fix inconsistencies before approval.

---

# 66. DEVICE MATRIX

Verify at least:

- 393px phone
- 320px phone
- 280px narrow phone
- large text

Also perform actual Android device acceptance before production release where available.

---

# 67. DO NOT RELY ONLY ON AUTOMATED TESTS

Automated tests passing does not prove visual acceptance.

Final acceptance requires:

- tests
- screenshots
- screenshot review
- visual consistency review
- navigation review
- provider/backend readiness
- update readiness

---

# 68. FINAL ACCEPTANCE CHECKLIST

Do not mark complete until:

- Home matches Create Ad design language
- Create Page matches
- Profile matches
- Menu matches
- Auth typography matches
- same blue is used
- shared spacing system is used
- PNG icon system is consistent
- Profile PNG icons are professional and semantically correct
- Menu PNG icons are professional and semantically correct
- PNG sources/licenses are documented
- Home has balanced blue gradient banner
- Best Results cards are balanced
- thumbnail bug is fixed
- temporary errors can be manually closed
- temporary error duration is shorter
- mobile-first sign-up works
- Create Ad works
- Create Page works
- TikTok connection works within approved provider capabilities
- Price Breakdown matches approved long rectangular design
- Sponsor remains separate
- old-client update flow works
- migrations/backend compatibility verified
- all screenshots captured
- all screenshots reviewed

---

# 69. FINAL REPORT REQUIRED

Return:

1. files changed
2. typography tokens
3. spacing tokens
4. color tokens
5. PNG icons added
6. source/license for each externally sourced PNG icon
7. Profile changes
8. Menu changes
9. Home changes
10. gradient banner
11. Create Page changes
12. Create Page fixes
13. Auth changes
14. mobile registration changes
15. Best Results changes
16. thumbnail bug root cause
17. error-message changes
18. TikTok connection status
19. Create Ad verification
20. Price Breakdown measurements
21. navigation fixes
22. update architecture
23. backward compatibility
24. migrations
25. tests
26. Android testing
27. screenshots
28. remaining production blockers

Do not claim something is complete unless actually verified.

---

# FINAL NON-NEGOTIABLE COMMAND

Treat this as an **app-wide release-quality design and functionality pass**.

Create Advertisement is the primary visual baseline.

Bring:

- Home
- Create Page
- Profile
- Menu
- Auth
- Best Results
- Ads
- error/empty states
- update UI

into one coherent design system.

Use **high-quality licensed local PNG icons** for Profile, Menu, and other appropriate sections.

Flaticon and similar professional libraries are valid sources when their license requirements are satisfied.

Google Images may be used to discover candidate icons, but always obtain the final asset from the original source and verify its usage rights.

Do not use random web images, emoji, blurry screenshots, or hotlinked assets.

Normalize every PNG visually, not just numerically.

Then complete full functional QA and visual screenshot review before production release.