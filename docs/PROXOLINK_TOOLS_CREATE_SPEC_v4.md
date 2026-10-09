# ProxoLink — FINAL NEW Tools / Create Page UX + Supabase Contract Prompt (V3)

Continue from the CURRENT ProxoLink V6 branch and repository state.

This is a **NEW user-facing design implementation**, not a cosmetic redesign of the current Tools / page-card / editor UI.

Do NOT restart the entire ProxoLink architecture.
Do NOT rewrite working backend/security code blindly.
Do NOT merge PR #7.
Do NOT activate production publishing.
Do NOT apply destructive production migrations.
Do NOT weaken RLS, ownership checks, private renderer security, provider validation, or native verification.

The goal is:

- make Tools refresh use the SAME existing Proxo refresh interaction language/component as HomeScreen,
- replace the current ProxoLink Tools / created-page list / create-page presentation with a completely new, clean, fast, high-quality interface,
- keep it visually native to the Proxo app,
- reuse the app's shared AppBar, typography, design tokens, and Create Ad error style,
- preserve correct backend/security behavior,
- inspect the existing Supabase schema before changing anything,
- use the existing database structures where correct instead of inventing duplicate tables,
- make the Flutter and backend code production-grade, measured, responsive, and maintainable.

==================================================
A. FIRST: INSPECT BEFORE IMPLEMENTING
==================================================

Before changing UI, backend, migrations, or Supabase policies:

1. Inspect the current branch and current ProxoLink implementation.
2. Inspect the existing Supabase migrations and actual available schema.
3. Inspect the existing `public.proxolink_cards` table and all related:
   - columns
   - data types
   - defaults
   - CHECK constraints
   - UNIQUE constraints
   - foreign keys
   - triggers
   - indexes
   - RLS policies
   - grants
   - functions
   - SECURITY DEFINER functions
   - storage policies
   - advertisement dependencies
4. Inspect existing operational columns such as:
   - `id`
   - `user_id`
   - `page_kind`
   - `settings`
   - `created_at`
   - `updated_at`
   - `status`
   - `publish_status`
   - `archived_at`
   - `client_request_id`
   - template/design fields
5. Inspect the current admin/role mechanism already used by the app before adding any trusted status-transition logic.
6. Do NOT invent a second page table if the existing `proxolink_cards` table is the correct authoritative table.
7. Do NOT create duplicate admin-role systems.
8. Do NOT assume the meaning of old status fields.

Important existing semantics must be respected:

- the existing `status` field has operational meaning such as active/inactive,
- the existing `publish_status` field has technical publishing meaning such as creating/ready/failed,
- technical failure is NOT the same as a moderation rejection.

Therefore, do NOT incorrectly map `failed` to customer-facing "ڕەتکراوە" unless the existing backend contract explicitly proves that it is a true moderation rejection.

If a dedicated moderation field already exists, use it.

If it does NOT exist, add the smallest safe additive field to the existing authoritative table, for example:

`moderation_status`

with server-controlled values:

- `pending`
- `approved`
- `rejected`

and default:

`pending`

Optionally add:

`moderation_status_updated_at`

only if useful for integrity/audit.

Do not create a new table solely for this status unless existing architecture genuinely requires one.

All schema changes must be additive, migration-tested, and NOT applied to production as part of this task.

==================================================
B. NEW DESIGN — NOT AN INCREMENTAL REDESIGN
==================================================

The current ProxoLink management UI should NOT merely be recolored or rearranged.

Create a **new presentation layer from scratch** for:

- Tools main screen
- created-page cards
- empty state
- loading state
- error state
- Create Page form

You may reuse stable backend/services/models/security contracts where appropriate.

You may reuse shared Proxo visual primitives.

But do not preserve the current ProxoLink card layout just because it already exists.

The new result must feel:
- clean,
- modern,
- formal,
- quiet,
- balanced,
- fast,
- uncluttered,
- high-quality,
- native to Proxo.

Avoid visual density.

Avoid admin-panel appearance.

Avoid excessive chips, icons, menus, borders, labels, and metadata.

==================================================
C. SHARED APPBAR
==================================================

The Tools screen must use the SAME shared AppBar already used by the Proxo app.

Tools title:

**ئامرازەکان**

The Create Page screen must also use the SAME shared AppBar.

Create Page title:

**دروستکردنی پەڕە**

The Create Page AppBar MUST include the normal back button.

The back button must:
- return to Tools normally,
- never break the navigation stack,
- never reset the Tools screen unnecessarily,
- respect the shared app navigation behavior,
- work correctly after external-browser preview returns to the app.

Do not create a custom ProxoLink-only AppBar.

==================================================
D. TOOLS PRIMARY ACTION
==================================================

The primary action is exactly:

**پەڕە دروستبکە**

Do not use:
- پەڕەی نوێ
- Create Page

Use the same formal button language and interaction quality used by modern Proxo screens.

==================================================
E. CREATED-PAGE CARD — CONTENT
==================================================

Every page card contains ONLY:

- page name
- PAGE_UUID / page ID
- creation date
- creation time
- page type
- moderation status
- delete action
- preview action

Do NOT show:
- image
- avatar
- page logo
- restaurant logo
- app icon
- style name
- updated date
- analytics
- edit
- archive
- deactivate
- reactivate
- more menu
- share
- separate copy-link action
- separate open-link action

Do not show field-name labels such as:

- ناو:
- ئایدی:
- جۆر:
- دۆخ:
- بەروار:
- کات:

The UI must communicate meaning through visual hierarchy and placement.

==================================================
F. CARD LAYOUT — DESIGNER MUST DECIDE IT
==================================================

IMPORTANT:

Do NOT follow a pre-fixed card row layout from this prompt.

Do NOT mechanically place:
"name here, status there, ID here, date there"
just because a previous prompt suggested it.

The implementation agent must act as the product/UI designer:

1. inspect the shared Proxo design system,
2. inspect Create Ad and current modern Proxo screens,
3. measure available widths,
4. design a completely new page-card hierarchy,
5. choose the best placement for:
   - page name
   - status
   - page type
   - page ID
   - date
   - time
   - Preview
   - Delete
6. ensure the result does not feel crowded,
7. ensure the visual reading order is immediately understandable without field labels,
8. ensure the layout survives long Kurdish, Arabic and English names,
9. ensure it works from small phone widths through tablets.

The card should be a formal white card with:
- restrained soft shadow,
- balanced padding,
- shared Proxo radius/tokens,
- clear hierarchy,
- no decorative clutter.

The agent must document the final chosen card composition in the final report, including:
- exact visual order,
- alignment,
- spacing values/tokens,
- button placement,
- status placement,
- responsive behavior,
- why this composition was chosen.

The prompt intentionally does NOT prescribe the exact final location.

==================================================
G. PAGE ID
==================================================

Use the PAGE_UUID.

Never display the auth/user UUID as the page ID.

For display:
- the UUID may be visually shortened if necessary,
- it must never cause ugly multi-line overflow,
- the full PAGE_UUID remains authoritative.

If copy behavior is retained, it must be unobtrusive and must not become a separate visible card action unless explicitly requested.

==================================================
H. PAGE TYPE VALUES
==================================================

Show values only.

Use:

contact:
**پەیوەندی**

order:
**خواردنگە و ڕێستۆرانت**

download:
**داگرتنی ئەپ**

Never expose internal keys in customer UI.

==================================================
I. EXACT MODERATION STATUS
==================================================

The only customer-facing moderation labels are:

**چاوەڕوانی**
**پەسەندکراوە**
**ڕەتکراوە**

Internal safe values should be:

- pending
- approved
- rejected

unless the existing schema already has an equivalent authoritative field.

Recommended visual semantics:
- pending → restrained amber/yellow
- approved → restrained green
- rejected → restrained red

The badge must be compact and formal.

Do not make status visually dominate the card.

==================================================
J. STATUS MUST BE STORED IN SUPABASE
==================================================

Moderation status must be real Supabase/backend data.

Default for a newly created page:

`pending`

Customer-facing:

**چاوەڕوانی**

The ordinary user must NOT be able to directly change moderation status from Flutter.

Only the already-authorized trusted admin/server mechanism may change:

pending → approved
pending → rejected

Do NOT add an admin UI in this task unless explicitly requested.

Do NOT reuse a technical publish failure as a fake rejection.

Do NOT trust any client-supplied moderation value.

If a new `moderation_status` column is necessary:
- make it NOT NULL,
- use an explicit CHECK or equivalent safe constraint,
- default to pending,
- make ownership/status transition protections server-side,
- add any useful index only after measuring the query pattern.

==================================================
K. RLS / USER DATA ISOLATION
==================================================

This is mandatory.

A user must only see and manage their OWN private page-management records.

No user may read another user's management data.

Knowing another PAGE_UUID must never grant management access.

Enforce this in Supabase/Postgres, not only in Flutter.

Audit RLS for:
- SELECT
- INSERT
- UPDATE where applicable
- DELETE

Owner identity must come from authenticated server identity (`auth.uid()` or the existing trusted server contract).

Never trust a client-submitted `owner_id/user_id`.

The client must not be able to:
- create a page for another owner,
- list another owner's pages,
- delete another owner's page,
- overwrite another owner's metadata,
- modify immutable identity fields,
- modify moderation status,
- bypass page/provider validation.

Public page rendering is separate from private management reads.

Do not grant broad anonymous SELECT on private management rows.

==================================================
L. DELETE SECURITY
==================================================

Visible action:

**سڕینەوە**

Use the shared Proxo confirmation pattern.

Deletion must:
- verify authentication,
- verify ownership,
- prevent double submission,
- respect existing advertisement foreign keys/dependencies,
- never silently break an active advertisement.

The existing project already has advertisement references/foreign-key protection.

Inspect them before implementing delete.

If a page is in use:
- block deletion,
- return a safe clear error,
- do not archive as a hidden replacement,
- do not detach an advertisement silently.

No Archive UI.
No Deactivate UI.
No Reactivate UI.

==================================================
M. PREVIEW — EXTERNAL BROWSERS ONLY
==================================================

Visible action:

**پێشبینین**

When tapped, preview must open the actual public page in an **external browser application only**.

Do NOT use:
- an in-app WebView,
- Chrome Custom Tabs as an in-app preview substitute,
- internal browser screen,
- screenshot preview,
- static thumbnail preview.

Use the existing Flutter external-launch capability (`url_launcher` or the current app-standard equivalent) with external-application behavior.

The public routes remain:

contact:
`/contact/{PAGE_UUID}`

order:
`/order/{PAGE_UUID}`

download:
`/download/{PAGE_UUID}`

==================================================
N. EXTERNAL BROWSER MUST NOT BREAK APP STATE
==================================================

Launching Preview must NOT damage the Tools UI.

When Chrome/Safari/Firefox/etc. opens:

- the Proxo Tools page remains alive,
- card list state remains intact,
- current scroll position remains intact,
- no duplicate page rows appear,
- no white/blank reset occurs,
- no forced full reload occurs,
- no accidental create-form reset occurs.

When the user returns from the browser:
- return to the same Tools screen/state,
- do not automatically rebuild everything,
- do not re-fetch the entire screen solely because app lifecycle changed,
- refresh only when actually necessary.

Test:
- launch browser,
- return to app,
- repeat multiple times,
- background/foreground,
- different supported browser apps.

If no external browser can handle the URL:
show a proper Proxo-style error and keep the screen stable.

==================================================
O. EMPTY STATE
==================================================

When no pages exist, show a dedicated centered empty state.

Use a lightweight simple visual.

Suggested title:

**هێشتا هیچ پەڕەیەکت دروست نەکردووە**

Suggested supporting text:

**پەڕەیەک دروستبکە و بەستەرەکەت بەکاربهێنە.**

Primary action:

**پەڕە دروستبکە**

Keep it centered and balanced without excessive empty space.

==================================================
P. ERROR UX — EXACT CREATE AD VISUAL LANGUAGE
==================================================

This is mandatory.

Errors/validation notices in this new ProxoLink flow must use the SAME visual language as the existing Create Ad error system.

Inspect and reuse/refactor the existing shared implementation around:

- `AdValidationController`
- `AdValidationNotifications`
- `ad_validation_notifications.dart`
- `AdUi`

Current Create Ad validation behavior includes:
- white stacked notice cards,
- restrained red leading/start border,
- error-outline icon,
- soft shadow,
- slightly layered/angled depth,
- smooth entrance,
- smooth exit,
- maximum readable visible stack,
- staggered arrival,
- approximately five-second visible lifetime,
- automatic disappearance,
- balanced spacing.

Do not recreate a visually similar but separate component if the existing one can safely be generalized/reused.

Do not use random Snackbar errors in Tools/Create Page when the requested error-card pattern is appropriate.

The ProxoLink errors must feel exactly like the Create Ad error system in:
- card proportions,
- spacing,
- animation rhythm,
- typography,
- error color treatment,
- icon scale,
- shadow,
- stacking.

Support at least:
- required field errors,
- invalid provider URL,
- failed upload,
- failed create,
- failed page load,
- failed delete,
- external-browser launch failure,
- owner/security-safe backend errors,
- network failure.

Backend/internal details must not leak to the user.

Map technical failures to safe Kurdish customer-facing messages.

Do not show:
- SQL text,
- stack traces,
- service role details,
- raw exception dumps,
- RLS internals.

==================================================
Q. CREATE PAGE — COMPLETELY NEW FORM DESIGN
==================================================

Build a clean new create-page UI.

Do not merely modify the existing editor's appearance.

Use the shared Proxo visual system and Create Ad quality, but create a new ProxoLink-specific form composition.

The form should remain simple and fast.

Required logical sections:

**جۆری پەڕە**

**زانیاری سەرەکی**

**پەیوەندی و دووگمەکان**

**ستایلی پەڕە**

The designer may choose the exact internal spacing/layout of these sections after reviewing shared Proxo components.

Do not make the form crowded.

Do not use a complex stepper unless evidence shows it is materially better.

Preferred interaction is a single smooth scrollable form.

==================================================
R. PAGE TYPE
==================================================

Available types:

**پەیوەندی**
**خواردنگە و ڕێستۆرانت**
**داگرتنی ئەپ**

Internal keys stay:

contact
order
download

Changing type updates the relevant form safely.

==================================================
S. TYPE-SPECIFIC IMAGE FIELD
==================================================

contact:
**وێنەی پەڕە**

order:
**لۆگۆی ڕێستۆرانت**

download:
**ئایکۆنی ئەپ**

Use secure existing storage conventions.

Inspect the current `proxolink-assets` policies and path requirements before changing upload code.

Do not weaken storage ownership rules.

==================================================
T. TYPE-SPECIFIC NAME
==================================================

contact:
**ناوی پەڕە**

order:
**ناوی ڕێستۆرانت**

download:
**ناوی ئەپ**

Support correct automatic RTL/LTR direction.

==================================================
U. DESCRIPTION
==================================================

Use:

**کورتە باس**

Keep it clean, multiline and validated.

Preserve safe server-side length/escaping rules.

==================================================
V. TIKTOK USERNAME
==================================================

Include:

**ناوی تیک تۆک**

Normalize safely.

Do not permit injection.

Do not create a separate TikTok page type.

==================================================
W. PROVIDERS
==================================================

CONTACT:

- WhatsApp
- Viber
- Instagram
- Telegram
- Korek
- Asiacell

RESTAURANT:

All four must be available for NEW authoring:

- **تەلەبات** → internal `talabat`
- **وادێ** → internal `wade`
- **تۆتەرز** → internal `toters`
- **لەزوو** → preserve the repository's existing Lezzoo/Lezzo internal key, currently `lezzoo` where authoritative

APP DOWNLOAD:

- Google Play
- App Store

Restaurant provider customer-facing labels must be Kurdish.

Do not change internal keys unnecessarily.

IMPORTANT:
The current V6 validator already knows restaurant keys including:
- talabat
- toters
- lezzoo
- wade

But the newer management guard currently treats `lezzoo` and `wade` as historical-only.

Update the authoring contract safely so all four requested restaurant providers can be newly authored.

Do this consistently across:
- Flutter options,
- backend API allowlist,
- SQL validation/guard,
- renderer,
- tests.

Do not loosen URL-host validation.

==================================================
X. STYLE SELECTOR
==================================================

Exactly four designs:

- ستایلی کلاسیک
- ستایلی سروشتی
- ستایلی تاریک
- ستایلی ڕووناک

Internal keys remain:
- pill
- pill-mint
- pill-dark
- pill-white

The create form shows only the style thumbnails.

==================================================
Y. NO CREATE-SCREEN LIVE PREVIEW
==================================================

Do NOT show a live WebView preview in Create Page.

Do NOT show an internal full-screen preview.

Creation flow contains:
- form,
- providers,
- style thumbnails,
- create button.

Actual Preview happens after creation from the created-page card and opens the external browser.

==================================================
Z. CREATE BUTTON
==================================================

Exact label:

**پەڕە دروستبکە**

Prevent double submit.

Use existing idempotency/client-request contract.

PAGE_UUID must remain database/server generated.

A successful create should:
- update the local Tools list immediately,
- avoid a full-screen reload,
- return to Tools,
- show the new page card,
- keep status authoritative from Supabase.

==================================================
AA. REFRESH UX — EXACTLY THE SAME PROXO REFRESH LANGUAGE AS HOME SCREEN
==================================================

The Tools / created-pages refresh experience must use the SAME existing Proxo refresh system already used by `HomeScreen`.

Do NOT invent a new refresh visual.
Do NOT use a generic default `RefreshIndicator` as the primary Tools refresh experience if the shared Proxo refresh component can be used.
Do NOT add a different spinner, pull animation, refresh strip, or list-reload style.

First inspect and reuse the existing shared implementation:

- `proxo_app/lib/widgets/proxo_refresh.dart`
- `ProxoRefresh`
- `ProxoRefreshController`
- `ProxoRefreshScope`
- `ProxoArrival`

and inspect how `HomeScreen` integrates it.

The Tools refresh should feel visually and physically like HomeScreen refresh:
- same Proxo motion language,
- same lightweight spinner treatment,
- same drop/reveal behavior,
- same spring character,
- same timing philosophy,
- same smooth settle,
- same non-blocking feel.

Do not duplicate the source code into another private Tools-only refresh widget.
Reuse/generalize the shared component where technically appropriate.

--------------------------------------------------
AA.1 HOME-SCREEN REFRESH MOTION
--------------------------------------------------

Preserve the current HomeScreen refresh character.

The existing shared refresh currently uses a compact temporary top strip and translates the content as part of the refresh animation.

Important existing motion characteristics include approximately:
- 60 logical px refresh reveal/drop extent,
- 22 logical px custom spinner,
- 2 px spinner stroke,
- opening spring behavior,
- tighter closing spring behavior,
- minimum visible refresh duration around 450 ms,
- smooth scroll-to-top behavior for programmatic refresh when the shared ScrollController integration requires it.

These values are existing Proxo motion language, not arbitrary new Tools-screen constants.

If the shared component changes during this implementation, the change must remain compatible with HomeScreen and must not visually regress HomeScreen.

The refresh movement must be temporary only.

After refresh finishes:
- the Tools content returns cleanly to its normal position,
- no permanent spacer remains,
- no card remains shifted downward,
- no section height changes permanently,
- no blank top area remains.

--------------------------------------------------
AA.2 DATA DURING REFRESH
--------------------------------------------------

While refresh is running:

- keep the currently displayed cards visible,
- do not clear the page collection,
- do not replace an already loaded list with skeletons,
- do not show a blank screen,
- do not recreate the whole route,
- do not reset the Tools screen.

The currently visible data is only the temporary UI state while the new request is in progress.

Supabase/backend remains authoritative.

--------------------------------------------------
AA.3 NEW DATA MUST REPLACE STALE DATA
--------------------------------------------------

When the latest authorized Supabase response succeeds:

the in-memory authoritative page collection must be reconciled with that response.

Use PAGE_UUID as the stable identity.

The final local state after a successful refresh must match the latest authorized server result.

That means:

UNCHANGED PAGE:
- retain its stable identity,
- avoid an unnecessary visual rebuild where possible.

CHANGED PAGE:
- replace old values with fresh server values.

NEW PAGE:
- insert it into the correct sorted position.

PAGE REMOVED FROM SERVER:
- remove it from the local list.

STATUS CHANGED:
- immediately replace the stale moderation status with the fresh server status.

Do NOT keep stale cards after a successful authoritative refresh.

Do NOT merge old and new collections in a way that keeps server-deleted rows alive.

Do NOT allow an older slower request to overwrite a newer successful refresh.

Use latest-request-wins / request-generation protection.

Commit the validated authoritative result to controller state atomically.

--------------------------------------------------
AA.4 ARRIVAL / UPDATE MOTION
--------------------------------------------------

Follow the same Proxo philosophy used by HomeScreen:

fresh content should settle in smoothly as the refresh strip closes.

Where appropriate, reuse the shared refresh arrival mechanism rather than inventing a second animation system.

For list rows, `ProxoArrival` may be used if it fits the final Tools architecture.

The visual result should be subtle:
- small fade,
- small vertical settle,
- short controlled stagger for the first visible rows,
- no dramatic movement.

Do NOT use:
- full-list crossfade,
- two overlapping ListViews,
- giant slide animation,
- bounce-heavy cards,
- page flash,
- entire-screen fade-out,
- AnimatedSwitcher patterns that duplicate the whole scrollable and cause height/ScrollController problems.

Stable, unchanged rows should remain visually calm.

--------------------------------------------------
AA.5 INITIAL LOAD IS DIFFERENT
--------------------------------------------------

Initial load and refresh are different states.

INITIAL LOAD:
- there is no current page data yet,
- the new design may use lightweight page-card skeletons,
- skeletons must match the new card geometry.

NORMAL REFRESH:
- valid cards are already on screen,
- keep them visible,
- use the HomeScreen-style Proxo refresh motion,
- do NOT swap them for skeletons.

--------------------------------------------------
AA.6 REFRESH FAILURE
--------------------------------------------------

If refresh fails:

- keep the previously displayed valid cards,
- stop/settle the shared Proxo refresh animation correctly,
- do not leave the spinner open,
- do not clear useful data,
- show the failure using the SAME Create Ad error-card visual language required elsewhere in this prompt,
- allow a retry.

Old data may remain visible only because no newer authoritative result was successfully received.

As soon as a later refresh succeeds, stale values must be replaced by the new authoritative result.

--------------------------------------------------
AA.7 CREATE / DELETE WITHOUT FULL RELOAD
--------------------------------------------------

After successful Create:
- use the authoritative page returned by the backend,
- insert/upsert it locally,
- do not clear the screen,
- do not run a disruptive full-page reload,
- reconcile with Supabase when needed.

After successful Delete:
- remove that PAGE_UUID only after confirmed server success,
- do not clear/reload the entire Tools screen,
- keep all other cards stable.

A later HomeScreen-style refresh must still reconcile the entire authoritative collection.

--------------------------------------------------
AA.8 EXTERNAL BROWSER RETURN
--------------------------------------------------

Returning from the external browser Preview must NOT trigger a disruptive refresh animation automatically.

Preserve:
- Tools route,
- visible card list,
- current state,
- practical scroll context.

If freshness checking is necessary after app resume, use the same lightweight data-reconciliation principles and do not create a second refresh visual.

Do not make opening Preview feel like leaving and rebuilding the Tools screen.

--------------------------------------------------
AA.9 PROGRAMMATIC REFRESH / TAB BEHAVIOR
--------------------------------------------------

If Tools participates in the app's existing programmatic refresh-controller pattern, integrate it with the same `ProxoRefreshController` architecture used by HomeScreen rather than creating another controller system.

Prevent re-entry:
- repeated taps must not queue multiple refresh operations,
- one active refresh at a time,
- no duplicate Supabase fetch storm.

If the screen has an attached scroll controller and the shared refresh behavior intentionally scrolls to the top before a programmatic refresh, use the existing shared behavior rather than reimplementing it.

Do not break manual scrolling or pull physics.

--------------------------------------------------
AA.10 REFRESH PERFORMANCE
--------------------------------------------------

The refresh data request must be efficient:

- one owner-scoped page collection request where possible,
- no N+1 page-card requests,
- no image/avatar request because cards contain no images,
- no WebView creation,
- no per-row provider fetch,
- no broad unfiltered Realtime query.

Keep stable PAGE_UUID keys.

Do not recreate the entire controller on refresh.

Do not unnecessarily reconstruct the full navigation tree.

Clear private cached state immediately on logout/account switch.

--------------------------------------------------
AA.11 REFRESH TESTS
--------------------------------------------------

Add tests proving that Tools refresh matches the established HomeScreen refresh behavior and remains data-correct.

Test at minimum:

1. initial empty load
2. initial populated load
3. successful refresh with no changes
4. successful refresh with changed page values
5. successful refresh with status change
6. successful refresh with a new page
7. successful refresh with a removed page
8. refresh failure
9. two rapid refresh requests
10. stale slow request returning after a newer request
11. external-browser return
12. account switch during/after refresh
13. large page list
14. small-screen responsive behavior
15. refresh motion settles fully back to normal layout

Assert:
- no stale server-deleted card remains after successful refresh,
- latest server values win,
- no duplicate PAGE_UUID appears,
- no permanent layout shift remains,
- no spinner remains stuck,
- no account-crossing data appears,
- no entire-screen blanking occurs,
- no already-loaded list is replaced by skeletons during refresh.

Final visual evidence must compare:
- HomeScreen refresh
- Tools refresh

and demonstrate that both clearly belong to the same Proxo interaction system.

==================================================
AB. DATABASE QUERY PERFORMANCE
==================================================

Inspect existing indexes first.

The project already has owner/date related ProxoLink indexes.

Do not add duplicate indexes.

Only add a new index if EXPLAIN/query pattern shows it is needed.

Primary list query should be efficient for:
- authenticated owner
- non-deleted/current pages
- newest-first display

Avoid N+1 queries.

Avoid one extra Supabase request per card.

==================================================
AC. BACKEND QUALITY
==================================================

Use clear layers:

Flutter UI
→ controller/state
→ repository/service
→ authenticated API/Supabase contract
→ database/RLS

Do not place security logic only in widgets.

Do not place database parsing everywhere in the UI.

Use typed/validated models.

Handle:
- network timeout,
- malformed server response,
- auth expiration,
- duplicate submit,
- stale result,
- deletion dependency,
- browser-launch failure.

Fail closed for authorization.

==================================================
AD. PUBLIC RENDERER SECURITY
==================================================

Keep private reusable HTML/CSS server-side.

Do not ship private template source in Flutter.

Public page route returns only intended public data.

Management data remains private.

==================================================
AE. FOOTER
==================================================

Across all 4 templates × 3 page types:

Exact text:

**سپۆنسەر کراوە لەئەپی**

Then Proxo wordmark/logo below.

Keep the Proxo wordmark slightly smaller and balanced.

Preserve the existing Privacy Policy / Terms & Conditions relationship exactly unless a real tested responsive bug is proven.

==================================================
AF. THUMBNAILS
==================================================

Keep exactly 12 bundled style thumbnails.

Regenerate from the real renderer only after footer correction.

Do not upscale blurry files.

Use genuine high-resolution renderer output.

Preserve full page.

No crop.
No stretch.
No squash.
No footer loss.

Fix high-DPI decode quality.

Do not force a tiny fixed decode width such as 240 if physical display needs more.

Measure APK impact.

==================================================
AG. RESPONSIVE QUALITY
==================================================

Test at minimum:

320
360
375
393
412
430
600
768
1024

The new designer-created card layout must prove:
- no RenderFlex overflow,
- no clipped actions,
- no overlapping status,
- no broken long names,
- no ID overflow,
- no crowding,
- no excessive tablet width,
- no accidental label ambiguity.

The Create Page form must also pass all widths.

==================================================
AH. ACCESSIBILITY / INTERACTION
==================================================

Use proper semantic button labels.

Respect minimum touch targets.

Do not rely on status color alone; the text status remains visible.

Support text scaling without layout collapse.

Do not create tiny delete/preview controls.

==================================================
AI. TESTS — TOOLS
==================================================

Add/update tests proving:

- shared AppBar
- title `ئامرازەکان`
- `پەڕە دروستبکە`
- new card design is used
- no image/logo/avatar in page card
- only required values appear
- no field-name labels
- exact statuses:
  - چاوەڕوانی
  - پەسەندکراوە
  - ڕەتکراوە
- exact customer page-type values
- only visible card actions:
  - سڕینەوە
  - پێشبینین
- no Edit
- no Archive
- no Deactivate
- no Reactivate
- no More
- no Share
- no separate Open Link
- no in-app WebView preview
- external browser launch only
- browser return preserves Tools state
- browser launch failure shows Create-Ad-style error card
- empty state
- loading state
- refresh state
- delete confirmation
- dependency-safe deletion
- account switch clears old data
- long Kurdish/Arabic/English names
- text scaling
- responsive widths

==================================================
AJ. TESTS — CREATE PAGE
==================================================

Prove:

- shared AppBar
- back button works
- no navigation reset
- new Create Page presentation
- page type selection
- type-specific image label
- type-specific name label
- کورتە باس
- ناوی تیک تۆک
- correct provider sets
- restaurant providers:
  - تەلەبات
  - وادێ
  - تۆتەرز
  - لەزوو
- all four style thumbnails
- no live WebView preview
- `پەڕە دروستبکە`
- validation errors use exact Create-Ad error visual system
- five-second lifecycle behavior remains correct where applicable
- double-submit prevention
- idempotency
- successful local list update

==================================================
AK. DATABASE / RLS TESTS
==================================================

Use disposable/staging database tests.

Prove:

- DB/server-generated PAGE_UUID
- PAGE_UUID != auth UUID
- one owner can have multiple pages
- owner sees own pages
- owner cannot see another owner's private page-management row
- owner cannot delete another owner's page
- owner cannot set another owner_id
- owner cannot modify immutable identity
- owner cannot directly approve/reject their own page
- moderation status defaults to pending
- trusted admin/server transition can set approved/rejected
- invalid moderation value rejected
- all four restaurant providers accepted only with valid host URL
- cross-type provider rejected
- malicious URL rejected
- advertisement dependency prevents unsafe delete
- no anonymous private management read
- no unsafe grants
- no service-role secret in Flutter

==================================================
AL. ERROR STYLE REGRESSION
==================================================

Compare screenshots/Golden/widget evidence between Create Ad and ProxoLink error notices.

The ProxoLink error UI must match the existing Create Ad notification style rather than merely being "similar".

If generalization is needed:
- extract/refactor the common visual component,
- keep existing Create Ad behavior unchanged,
- reuse the shared component in ProxoLink.

Do not regress Create Ad.

==================================================
AM. FINAL DESIGN EVIDENCE
==================================================

Because the exact card placement is intentionally delegated to the designer/implementation agent, final evidence is mandatory.

Provide screenshots at:

320
393
430
768

for:
- Tools with several cards
- long page name
- each moderation status
- empty state
- error state
- Create Page
- style selector

Document the final card design with:
- width behavior,
- card padding,
- section gaps,
- typography hierarchy,
- exact placement of each value,
- status location,
- action location,
- responsive stacking rule,
- reason for each decision.

Do not say "designed responsively" without measurements.

==================================================
AN. DO NOT ADD UNREQUESTED FEATURES
==================================================

Do NOT add:

- Edit Page
- Archive
- Deactivate
- Reactivate
- More menu
- page analytics
- visible share action
- visible copy-link action
- separate Open Link button
- internal preview screen
- WebView preview
- extra page types
- extra template designs
- fake moderation
- new admin screen
- new duplicate page table

==================================================
AO. FINAL REPORT
==================================================

Before reporting COMPLETE, provide:

1. branch
2. final commit SHA
3. exact changed files
4. old user-facing screens/components replaced
5. new user-facing components created
6. exact shared AppBar component used
7. exact shared Create Ad error component/refactor used
8. final Tools card visual hierarchy and measurements
9. reason for the chosen card layout
10. empty-state design
11. exact external-browser launch implementation
12. proof returning from browser preserves screen/scroll state
13. Create Page final section design
14. exact restaurant provider labels/keys
15. Supabase schema inspection summary BEFORE changes
16. existing table reused
17. exact migration change, if any
18. exact moderation-status storage strategy
19. RLS policy results
20. grants audit
21. trigger/function audit
22. dependency-delete behavior
23. query/index analysis
24. cache/state strategy
25. account-switch isolation proof
26. responsive test results
27. error-style comparison evidence
28. Flutter test count
29. backend/API test count
30. DB/RLS test count
31. security/privacy scan
32. APK size before/after thumbnail changes
33. native verification status
34. remaining blockers
35. PR #7 state
36. proof Tools uses/reuses the HomeScreen Proxo refresh system
37. refresh motion comparison evidence: HomeScreen vs Tools
38. proof a successful refresh removes stale/deleted server rows
39. proof latest-request-wins prevents stale response overwrite
40. proof refresh settles with no permanent layout shift

Do NOT report COMPLETE if:

- the UI is merely the old ProxoLink design with small visual changes,
- the exact card hierarchy was not deliberately designed and documented,
- page cards still contain image/logo/avatar,
- field labels remain,
- unrequested actions remain,
- Preview uses an in-app WebView,
- browser return breaks/reset Tools state,
- errors use generic Snackbar instead of the required Create-Ad-style system,
- user moderation status is client-controlled,
- another user's management row can be read,
- duplicate page/admin tables were invented unnecessarily,
- current Supabase schema was not inspected first,
- restaurant Wade/Lezzoo remain historical-only,
- executable tests were skipped without a real blocker,
- Tools uses a different refresh visual/system than HomeScreen without a proven technical necessity,
- a successful refresh leaves stale server-deleted data visible,
- refresh causes a permanent card/section layout shift,
- an older request can overwrite a newer successful refresh.

PR #7 must remain:
- Draft
- Open
- Unmerged

Do not activate production publishing.
