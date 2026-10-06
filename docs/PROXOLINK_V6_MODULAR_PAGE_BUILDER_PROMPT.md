# ProxoLink V6 — Independent Page Types with Per-Page UUID
## Self-contained implementation prompt for a fresh workspace

Read this complete document before changing code.

Repository:
- `Zana-Sponsor/proxobalance`
- Flutter app: `proxo_app/`
- Existing feature branch: `feat/proxolink-private-renderer-migration`
- Existing Draft PR: #7
- Existing Vercel project: `proxoapp-1758/proxobalance`

Do not restart the project from scratch. Inspect the current ProxoLink code and reuse completed V5 work.

Keep PR #7 Draft. Do not merge, activate new template versions for production customers, migrate customer data, perform destructive cleanup, or deploy the ProxoLink feature branch to production without separate explicit approval.

---

# 1. Product Goal

ProxoLink must support several independent business page types.

Confirmed page types:

1. Contact Page
2. Restaurant / Food Ordering Page
3. App Download Page

More page types may be added later, so the architecture must be extensible.

Each created page is an independent database record with its own UUID.

A user account UUID is NOT the public page UUID.

Do not put the user's account/auth UUID in the public URL.

The public URL must use only the UUID of the page record that was created and stored in the database.

Examples:

```text
www.domain.com/contact/{CONTACT_PAGE_UUID}
www.domain.com/order/{ORDER_PAGE_UUID}
www.domain.com/download/{DOWNLOAD_PAGE_UUID}
```

Example for one customer who creates three separate pages:

```text
/contact/6f8c0c1a-....
/order/a31d2047-....
/download/b92e9130-....
```

Those three UUIDs are different because they identify three different page records.

Internally, the database may associate all three pages with the same authenticated owner through `owner_id` / `user_id`, but that account ID must not be used as the public page identity.

---

# 2. Critical Architecture Rule

Do not model Contact, Order and Download as tabs inside one public page.

They are separate pages.

Each page has:

- its own page UUID
- its own public URL
- its own page type
- its own selected visual template/style
- its own title/profile/business data where applicable
- its own type-specific settings
- its own status
- its own created/updated timestamps
- the same authenticated owner if created by the same customer

A customer may create multiple pages of the same type if the product allows it.

Example:

```text
Restaurant A -> /order/{uuid-1}
Restaurant B -> /order/{uuid-2}
Main contact page -> /contact/{uuid-3}
Mobile app -> /download/{uuid-4}
```

Do not derive page identity from the owner account UUID.

---

# 3. Visual Styles and Page Types Are Different

Do not confuse visual template/style with page type.

A page type defines what the page does:

- Contact
- Order
- Download

A visual template/style defines how that page looks.

Preserve the existing ProxoLink visual-template architecture and current verified private renderer.

If the repository currently contains eight established ProxoLink templates, preserve their identities and make the new page types compatible with the template system instead of cloning the template source per page type.

Do not create unsafe user-editable HTML/CSS/JavaScript.

Do not expose reusable private template source in Flutter.

---

# 4. Common Page Record

Use an additive structured model.

A suitable unified model is conceptually:

```text
id                UUID PRIMARY KEY        <-- generated page UUID
owner_id          UUID                    <-- authenticated account owner, internal only
page_type         contact | order | download
template_key
title
bio
avatar_url
language
status
settings          structured JSON or normalized child rows
created_at
updated_at
```

This is an architectural example, not a requirement to use these exact column names.

The important rule is:

```text
page.id = public page UUID
owner_id = internal ownership/account relationship
```

Never use `owner_id` as the public route identifier.

All ownership-sensitive operations must still verify the authenticated user's internal owner ID server-side.

---

# 5. User-Facing Names for the Three Page Types

Use three clear user-facing page-type names.

For Kurdish/Sorani UI, use:

1. `پەیوەندی` — Contact
2. `خواردنگە و ڕێستۆرانت` — Restaurant / Food Ordering
3. `داگرتنی ئەپ` — App Download

These are three separate page types, not sections inside one public page.

All three page types MUST use the same profile-header LAYOUT and visual structure, but the field labels/content meaning must adapt naturally to the page type.

Keep the same size, position, spacing, card treatment, typography and overall header composition across Contact, Restaurant and App Download pages.

Use these type-specific field labels:

## Contact / پەیوەندی
- Page Image / وێنەی پەڕە
- Page Name / ناوی پەڕە
- Bio / بایۆ

## Restaurant / خواردنگە و ڕێستۆرانت
- Restaurant Logo / لۆگۆی ڕێستۆرانت
- Restaurant Name / ناوی ڕێستۆرانت
- Bio / بایۆ

## App Download / داگرتنی ئەپ
- App Icon / ئایکۆنی ئەپ
- App Name / ناوی ئەپ
- Bio / بایۆ

These are semantic labels only. Do not redesign the header separately for each page type.

Only the type-specific action area below the shared header changes.

When the user taps one type in the Flutter create flow, show that page type's correctly labeled image/name/bio fields first, then show only the additional fields/actions relevant to that page type.

## Contact / پەیوەندی

Show configurable buttons for:

- WhatsApp
- Viber
- Instagram
- Telegram
- Korek
- Asiacell

Do not show a generic `Phone` provider.

Korek and Asiacell are explicit contact providers in the UI. Each should accept the customer's relevant phone number, validate it safely, and render its own clearly named button using the appropriate approved brand asset/icon.

Only configured providers should appear on the public Contact page.

## Restaurant / خواردنگە و ڕێستۆرانت

Show ordering/delivery providers such as:

- Talabat
- Toters

and future supported ordering providers from the backend-authoritative registry.

Do not show Contact or App Download providers in the Order form.

## App Download / داگرتنی ئەپ

Show app-store destinations:

- Google Play
- Apple App Store

Do not show Contact or Order providers in the Download form.

---

# 6. Public Routing

Use clear page-type routes.

Required route model:

```text
/contact/{page_uuid}
/order/{page_uuid}
/download/{page_uuid}
```

The route and database page type must agree.

Examples:

- a Contact page UUID must render through `/contact/{uuid}`
- an Order page UUID must render through `/order/{uuid}`
- a Download page UUID must render through `/download/{uuid}`

A mismatched route must not silently render another page type.

For example, if an Order UUID is requested at `/contact/{uuid}`, return a safe not-found/invalid-page response rather than rendering the wrong page.

Keep URLs stable after creation.

Editing the page must not change its UUID or public URL.

---

# 7. Contact Page

The Contact page is for direct contact methods.

Use the existing supported contact functionality where valid, for example:

- WhatsApp
- Viber
- Instagram
- Telegram
- Korek
- Asiacell
- other currently approved contact methods

Only configured methods should render.

Do not show empty buttons.

Telegram must be available as a normal Contact-page method.

Allow the customer to configure Telegram using a validated Telegram username and/or supported `https://t.me/...` destination.

Render a Telegram button only when the Contact page has a valid configured Telegram destination.

Telegram in this specification is a contact button only. Do not create or require a Telegram bot, Telegram notification workflow, Bot API token, document-delivery flow, or new Telegram credential unless separately requested by the owner.

If historical Telegram contact data already exists and is valid, preserve compatibility where safe.

Public route:

```text
/contact/{CONTACT_PAGE_UUID}
```

---

# 8. Restaurant / Food Ordering Page

Add a dedicated Order page type.

Public route:

```text
/order/{ORDER_PAGE_UUID}
```

The customer should be able to configure the food-ordering/delivery services used by that restaurant.

Confirmed providers:

- Talabat
- Toters

The architecture must allow more supported providers later.

For each provider, store structured data such as:

```text
provider_key
destination_url
enabled
sort_order
```

Use a provider registry or equivalent backend-authoritative configuration.

Do not hardcode a specific customer's order links.

Do not accept arbitrary HTML or JavaScript.

Do not invent undocumented deep-link schemes.

Use validated HTTPS destinations or officially verified provider link formats.

Render only the providers enabled for that Order page.

Use official/provider-approved logo assets where available. Do not fabricate fake brand logos.

---

# 9. App Download Page

Add a dedicated Download page type.

Public route:

```text
/download/{DOWNLOAD_PAGE_UUID}
```

Confirmed store destinations:

- Google Play
- Apple App Store

The customer may configure one or both.

Suggested structured fields:

```text
app_name
short_description
google_play_url
app_store_url
```

Validate store destinations server-side.

Do not accept unsafe schemes such as:

- javascript:
- file:
- arbitrary data:
- injected HTML

Do not require both stores if the application is available on only one.

Use recognized official store badges/assets where appropriate and permitted.

---

# 10. No Click-Tracking Requirement

Do NOT add click collection or click analytics for the new page types.

This prompt does not require collecting:

- WhatsApp button clicks
- Telegram button clicks
- Viber button clicks
- Instagram button clicks
- phone clicks
- Talabat clicks
- Toters clicks
- Google Play clicks
- App Store clicks
- outbound button-click events
- per-provider click counters
- conversion events for these page buttons

Do not add a new event table, tracking pixel, click RPC, outbound-click API, or analytics dependency for these actions.

Do not block implementation waiting for click analytics.

If old ProxoLink/ad infrastructure already contains unrelated historical tracking, preserve it unless a separately authorized task changes it, but do not expand it as part of this feature.

The new page-type implementation should focus on:

- creating pages
- storing structured page data
- rendering pages
- editing pages
- validation
- stable URLs
- ownership/security
- visual preview

not click collection.

---

# 11. Account UUID vs Page UUID

This rule is mandatory.

When an authenticated customer creates a page:

1. authenticate the customer
2. server determines the internal owner/account ID
3. create a new page database row
4. generate/use the page row's UUID
5. store the internal owner relationship separately
6. build the public URL from the PAGE UUID only

Correct:

```text
page.id = 6f8c...
page.owner_id = 91ab...

public URL = /contact/6f8c...
```

Incorrect:

```text
public URL = /contact/91ab...
```

where `91ab...` is the user's account/auth UUID.

Never expose ownership decisions by trusting a page UUID supplied by the client alone. Management APIs must authenticate the user and check page ownership.

---

# 12. Flutter Page Builder

The Flutter ProxoLink management UI should let the customer choose what type of page to create.

Example create-page choices:

```text
Contact Page
Restaurant / Order Page
App Download Page
```

Selecting a page type opens that type's own form.

## Contact form

Show Page Image + Page Name + Bio, then Contact methods.

## Restaurant form

Show Restaurant Logo + Restaurant Name + Bio, then restaurant/order provider configuration.

## Download form

Show App Icon + App Name + Bio, then Google Play/App Store configuration.

The three forms must keep the same visual header layout and dimensions even though their labels differ.

Do not show irrelevant fields from other page types.

For example:

- an Order page should not require WhatsApp/Viber
- a Download page should not require Talabat/Toters
- a Contact page should not require app-store links

---

# 13. Page List / Management

The user should be able to see all pages they own.

Each management card should clearly show:

- page name/title
- page type
- selected visual style
- status
- public page URL or copy/share action
- Edit
- Preview
- Activate/Deactivate where supported
- Retry when publication/rendering state genuinely requires it

Do not use the authenticated account UUID as a display/public URL identifier.

Use the page UUID/public URL when a technical identifier is needed.

---

# 14. Create Flow

Create flow:

1. user opens ProxoLink
2. taps Create Page
3. chooses page type
4. enters common information
5. configures type-specific fields
6. chooses a visual style/template
7. sees a genuine live preview
8. submits
9. backend validates ownership and structured data
10. database creates a new page row with a new page UUID
11. the page receives its stable public type-specific URL
12. user can preview/share it

Examples:

```text
Contact -> /contact/{new_page_uuid}
Order -> /order/{new_page_uuid}
Download -> /download/{new_page_uuid}
```

---

# 15. Edit Flow

Edit flow:

1. authenticate user
2. load page by page UUID
3. verify page.owner_id matches authenticated user
4. edit allowed fields
5. validate page-type-specific settings
6. update the same page row
7. preserve the same page UUID
8. preserve the same public URL

Do not generate a new UUID merely because the page was edited.

Do not change `page_type` in-place if doing so would make an existing public route semantically incorrect. Prefer creating a new page of another type if the user wants a fundamentally different page type.

---

# 16. Delete / Deactivate Safety

If delete functionality exists, do not hard-delete by default without reviewing existing data relationships.

Prefer existing safe status/deactivation behavior where appropriate.

Do not perform destructive production cleanup under this implementation prompt.

Any production deletion/cutover remains a separate approval.

---

# 17. Live Preview

Continue using genuine server-rendered visual preview inside Flutter WebView.

Do not replace live preview with static screenshots.

Do not expose raw reusable HTML/CSS/JavaScript.

The preview should represent:

- selected page type
- selected visual style
- title/profile data
- configured providers/buttons
- RTL/LTR language
- current unsaved form state where safely supported

Preview actions should be inert or intercepted so previewing does not contact real people, place actual orders, or launch unsafe destinations.

No click analytics are required in preview or public pages under this prompt.

---

# 18. Provider Registry

Use a maintainable provider registry or equivalent contract for supported external actions.

Example categories:

```text
contact:
  whatsapp
  viber
  instagram
  telegram
  korek
  asiacell

order:
  talabat
  toters

download:
  google_play
  app_store
```

The backend must remain authoritative for:

- provider key
- allowed page type
- validation rules
- safe URL/value format
- enabled/disabled support
- icon/asset identity

Flutter may receive safe metadata required to build forms.

Do not expose server secrets or reusable private template source.

---

# 19. Data Validation

Validate all customer input server-side.

For all page types:

- reject invalid UUID references
- reject unauthorized page updates
- escape rendered text
- reject arbitrary HTML/JS injection
- validate URLs
- reject unsafe schemes
- enforce type/provider compatibility

Examples:

- Talabat belongs to Order
- Toters belongs to Order
- Google Play belongs to Download
- App Store belongs to Download
- WhatsApp belongs to Contact
- Telegram belongs to Contact
- Korek belongs to Contact
- Asiacell belongs to Contact

Do not trust only the Flutter client for validation.

---

# 20. Backward Compatibility

Preserve existing customer cards/pages and current relationships.

Do not silently convert production records.

If current ProxoLink uses a different table/model, implement additive compatibility or a safe adapter.

Existing stable public URLs must continue working unless a separately approved migration explicitly replaces them.

Do not reuse an existing account UUID as the UUID of newly created pages merely for compatibility.

---

# 21. Database Migration Safety

Any new schema must be additive first.

Before production cutover:

- inspect existing schema
- preserve current rows
- preserve existing page/card UUIDs
- preserve advertisement relationships
- preserve legacy columns needed for rollback
- test migration in isolated staging/transaction
- verify rollback path
- compare row counts/checkpoints

No destructive cleanup in this task.

A unified `pages` table or compatible normalized structure is preferred if it cleanly supports independent page rows, but inspect the existing schema first rather than introducing a redundant parallel system.

---

# 21. Existing Four Prepared Designs

The owner already has four prepared ProxoLink visual designs.

Do not create a new visual design system and do not replace those four designs.

Inspect the repository and identify the exact existing four prepared design/template keys and reuse them as the authoritative visual choices for Contact, Order and Download pages.

Do not invent template names if the repository already defines them.

The same prepared design system should be reusable across the three page types while preserving each design's own visual identity.

If the current repository contains older or extra template experiments beyond the four prepared designs, do not activate or expose them merely because they exist; preserve them safely and follow the owner's four prepared designs as the active V6 design set.

# 22. Visual Design

The surrounding Flutter UI must match the existing Proxo design system used by Create Ad and Ad Details.

Use:

- Rabar
- normal font weight for normal text
- blue headings
- black primary text
- gray secondary text
- white cards
- soft shadows
- balanced spacing
- consistent radii
- correct Sorani/Arabic RTL
- correct URLs/IDs/numbers LTR

Do not manually inflate Kurdish font sizes.

Do not make every button blue.

Use icons where they improve clarity.

---

# 23. Existing Template Identity

Preserve existing template identities.

Do not make every page/style look the same.

Keep established:

- backgrounds
- gradients
- card structures
- avatar/profile treatment
- spacing language
- animations
- button language
- visual character

Type-specific buttons should adapt to the selected template without destroying its identity.

Adding Order/Download is not authorization for a broad template redesign.

---

# 24. Responsive Requirements

Test at minimum:

- 320
- 375
- 393
- 430
- 768

Verify:

- long names
- long bios/descriptions
- one and multiple providers
- RTL
- LTR
- mixed-script text
- text scaling
- portrait
- landscape
- no horizontal overflow
- safe provider-logo sizing
- correct official store-badge proportions

---

# 25. Brand Assets

For Talabat, Toters, Google Play and App Store:

- use official or approved assets when available
- preserve aspect ratio
- do not stretch
- do not fabricate fake logos
- include accessible labels
- optimize assets
- do not fetch arbitrary unreviewed third-party artwork at runtime

If an approved asset is unavailable, report it as a missing asset requirement rather than inventing one.

---

# 26. Security

Keep private reusable templates server-side.

Flutter must not bundle private template HTML/CSS/JS.

Keep:

- authenticated management APIs
- ownership checks
- RLS where applicable
- service-role secrets server-only
- safe URL validation
- private template storage
- signed short-lived previews
- CSP/no-store/nosniff/referrer protections where already implemented

Possessing a public page UUID must not grant edit access.

Public UUIDs are routing identifiers, not authorization credentials.

---

# 27. Telegram Contact Button

Telegram is supported in V6 as a normal Contact-page destination.

Requirements:

- allow a validated Telegram username and/or `https://t.me/...` URL
- render an official Telegram contact button when configured
- keep Telegram optional
- do not show an empty Telegram button
- validate and normalize the destination server-side
- keep the Telegram button visually consistent with the selected ProxoLink template
- use an approved Telegram icon/brand asset

This does not authorize reintroducing the old Telegram notification/delivery backend.

Do not create or require:

- a Telegram bot
- Bot API credentials
- document-delivery notifications
- background Telegram messaging
- a replacement notification integration

unless the owner separately requests those features.

---

# 28. Native Android Verification

Use the existing protected Android verification workflow.

Do not build a parallel system unless necessary.

Test actual WebView rendering for all supported page types and representative visual templates.

When strict pixel comparison is required, compare deterministic same-environment Android WebView baseline vs candidate.

Keep Chromium screenshots only as cross-renderer reference evidence when appropriate.

Do not treat prepared scripts as executed verification.

---

# 29. Required Functional Tests

At minimum test:

## Contact

- create Contact page
- receives Contact page UUID
- URL is `/contact/{page_uuid}`
- configured Contact buttons render, including Telegram when configured
- edit preserves UUID and URL
- unauthorized owner cannot edit

## Order

- create Order page
- receives different independent UUID
- URL is `/order/{page_uuid}`
- Talabat only
- Toters only
- Talabat + Toters
- invalid provider destination rejected
- edit preserves UUID and URL

## Download

- create Download page
- receives independent UUID
- URL is `/download/{page_uuid}`
- Google Play only
- App Store only
- both stores
- malformed store URLs rejected
- edit preserves UUID and URL

## Route/type integrity

- Contact UUID at Contact route works
- Order UUID at Order route works
- Download UUID at Download route works
- wrong page-type route does not render another type
- owner account UUID cannot be used as a substitute page UUID

No click-count verification is required.

---

# 30. Isolated Staging

Use isolated staging for write-path verification.

Do not create disposable production customer data.

Verify in staging:

- create each page type
- independent UUID generation
- correct route generation
- edit
- stable URL
- activate/deactivate if supported
- retry if supported
- validation
- ownership
- preview
- public render

If isolated staging is unavailable, mark write-path tests BLOCKED and provide exact setup requirements.

Do not silently use production as staging.

---

# 31. Existing Advertisement Relationships

Preserve existing advertisement/customer relationships.

Do not break an existing advertisement that references an existing ProxoLink record.

New page-type support must not automatically rewrite advertisement rows.

This prompt does not require new outbound-click tracking or per-button conversion analytics.

Any future change to advertisement tracking is a separate feature unless explicitly requested.

---

# 32. Fresh Workspace Execution Order

A fresh workspace must:

1. inspect repo, current branch and Draft PR #7
2. read current ProxoLink implementation/evidence
3. identify completed V5 work
4. preserve verified renderer/security infrastructure
5. inspect current page/card schema
6. design additive independent-page model
7. ensure page UUID and owner UUID are separate
8. implement type-specific routing
9. implement Contact page
10. implement Order page
11. implement Download page
12. update Flutter management/create/edit UI
13. update live previews
14. add provider validation/registry
15. preserve visual templates
16. run backend/Flutter/security tests
17. run Android native verification
18. run isolated staging write-path tests when available
19. update evidence
20. stop before production release gates

Do not spend time implementing click analytics because it is not part of this scope.

---

# 33. Definition of Done

The work is complete only when an authenticated customer can independently create:

```text
/contact/{contact_page_uuid}
/order/{order_page_uuid}
/download/{download_page_uuid}
```

with different UUIDs representing different database page records.

The customer account UUID is used internally for ownership only and is not the public page identifier.

Each created page must:

- use the same shared header layout with type-correct labels: Page Image/Page Name, Restaurant Logo/Restaurant Name, or App Icon/App Name, plus Bio
- be stored in the database
- own its page UUID
- have a stable public URL
- render the correct page type
- use the selected visual style
- support safe edit/preview
- preserve its UUID after editing
- validate its own provider fields
- enforce ownership for management actions

And:

- Contact shows contact actions
- Order shows configured food-ordering services such as Talabat/Toters
- Download shows configured Google Play/App Store destinations
- Telegram is available as an optional Contact-page button
- no Telegram bot/notification system is required
- no new button-click collection is required
- existing production data is preserved
- private template source remains protected

---

# 34. Final Reporting

At completion report:

- exact files changed
- schema/migrations prepared
- page table/model used
- how `page.id` differs from `owner_id`
- URL routing implementation
- Contact results
- Order results
- Download results
- live preview results
- Flutter tests
- backend/security tests
- Android results
- staging results
- production state
- Draft PR state
- any blocked items

Use only:

```text
VERIFIED
FAILED
BLOCKED
```

Never report unexecuted work as verified.

---

# Final Intent

ProxoLink should support multiple independent page types.

A customer's account may own many pages, but every created page has its own independent UUID stored in the database.

The public URL uses the created PAGE UUID, never the account/auth UUID.

Examples:

```text
/contact/{contact_page_uuid}
/order/{order_page_uuid}
/download/{download_page_uuid}
```

There is no requirement in this prompt to collect WhatsApp/Telegram/Talabat/store-button clicks or similar outbound-click analytics.

Focus on reliable page creation, structured data, per-page UUIDs, stable URLs, safe ownership, live previews, private rendering, responsive design and correct page-type behavior.

---

# 35. Mandatory Final Test Gate — Execute, Do Not Only Prepare

Testing is mandatory before this work may be reported as complete.

The agent must actually execute the available test suites and retain evidence. Merely writing tests, preparing scripts, building an APK, or describing expected behavior is not sufficient.

Before final completion, execute and report all applicable checks below:

## Backend / API

- create/read/update behavior for Contact, Order and Download pages
- page UUID generation
- owner UUID kept separate from page UUID
- route/page-type matching
- malformed UUID rejection
- unauthorized owner update rejection
- provider allowlist enforcement
- unsafe URL/scheme rejection
- HTML/JavaScript injection rejection
- backward-compatibility checks for existing ProxoLink records

## Database / RLS / migration safety

- additive migration validation
- ownership/RLS behavior
- existing production-data preservation checks
- existing advertisement/card relationship checks
- stable page UUID after edit
- rollback/dry-run validation where applicable

## Flutter

- analyze/lint
- unit/widget tests
- Create Page type selector
- Contact form
- Order form
- Download form
- edit flow
- page list/management cards
- state preservation
- RTL/LTR
- long text and mixed-script behavior
- no overflow

## Live WebView preview

For every supported page type, verify real server-rendered preview in Flutter WebView.

Do not substitute a static image for live preview verification.

Verify that preview actions are safely intercepted/inert and that private reusable template source is not bundled into Flutter.

## Public rendering

Execute representative public-page tests for:

- Contact
- Order
- Download
- every existing visual template/style that is supported by the implementation
- 320 / 375 / 393 / 430 / 768 widths
- RTL and LTR
- long names and descriptions
- one and multiple configured provider buttons
- no horizontal overflow

## Android native

Run the existing protected Android verification workflow and execute actual WebView cases.

Where pixel parity is required, use same-environment Android WebView baseline vs candidate for strict deterministic comparison.

Do not claim native parity from Chromium screenshots alone.

## Isolated staging end-to-end

When isolated staging is available, execute real write-path tests for all three page types:

1. create page
2. confirm a new database PAGE UUID is generated
3. confirm account/auth UUID is not used in the public URL
4. confirm correct route is generated
5. open public URL
6. edit page
7. confirm UUID and URL remain unchanged
8. preview again
9. activate/deactivate where supported
10. retry where supported
11. verify unauthorized account cannot modify the page
12. verify wrong page-type route is rejected

If isolated staging is unavailable, these tests must be explicitly reported as BLOCKED rather than VERIFIED.

## Security / privacy

Execute existing ProxoLink security checks, including:

- application authentication boundary
- ownership/RLS
- private-template access
- signed preview validation
- secret masking in CI
- no service-role secret in Flutter
- no raw private template source in APK/source bundles
- Telegram Contact button works only as a validated outbound contact destination
- no Telegram bot/notification backend is introduced
- no new click-tracking/event collection for the page buttons described by this prompt

## Final acceptance rule

The final report must list each major requirement as exactly one of:

```text
VERIFIED
FAILED
BLOCKED
```

A requirement may be marked VERIFIED only when supported by executed evidence.

Do not mark a requirement VERIFIED because code exists, a test was prepared, or a build succeeded.

If any required test fails, fix the genuine defect and rerun the relevant suite. Do not weaken security checks or silently relax visual acceptance merely to obtain a pass.

Keep PR #7 Draft and keep production release/cutover gates unchanged unless separately approved by the owner.