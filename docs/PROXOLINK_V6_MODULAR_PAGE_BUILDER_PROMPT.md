# ProxoLink V6 — Modular Multi-Section Page Builder
## Self-contained implementation prompt for a fresh workspace

Read this complete document before changing code.

This is an implementation specification for the existing Proxo ecosystem. Work in:

- Repository: `Zana-Sponsor/proxobalance`
- Flutter app: `proxo_app/`
- Existing ProxoLink feature branch: `feat/proxolink-private-renderer-migration`
- Existing Draft PR: #7
- Existing Vercel project: `proxoapp-1758/proxobalance`

Do not restart the project from scratch. Inspect current code first, reuse verified V5 work, and implement only the new modular-page-builder requirements and any genuine defects.

PR #7 must remain Draft unless the owner separately authorizes merge.

Do not deploy the ProxoLink feature branch to production, activate V2 templates for existing customers, migrate production customer rows, delete legacy data, or make destructive production changes without separate explicit approval.

---

# 1. Product Goal

ProxoLink must become a flexible page builder that lets each customer create one personal public page automatically, then edit it later without changing its stable public URL.

The page is not limited to contact buttons.

A single customer page may contain multiple functional sections.

Confirmed sections in this specification are:

1. Contact
2. Restaurant / Food Ordering
3. App Download

The owner mentioned that more sections are planned. Only the three sections above are defined here. Do not invent a fourth business feature without explicit requirements.

The architecture must make future sections easy to add without redesigning the database or renderer.

---

# 2. Critical Concept — Template Style and Page Section Are Different

Do not confuse visual template styles with functional page sections.

## Template Style

The existing eight visual ProxoLink templates remain:

- dark
- light
- classic
- pill
- card
- neon
- zoom
- banner

These determine the visual identity of the public page.

## Page Section

Sections determine which type of actions/content the customer wants to expose:

- Contact
- Restaurant / Food Ordering
- App Download

A customer chooses one template style, then may enable one or more page sections inside that template.

Example:

```text
Template style: Neon

Enabled sections:
- Contact
- Restaurant
- App Download
```

The page must still look like the Neon template. The sections are functional modules inside that design.

Do not create separate duplicate template libraries such as `neon_restaurant`, `neon_download`, etc.

---

# 3. Public Page Behavior

The public page should show the customer's common profile information first:

- profile image
- profile/business name
- bio
- optional TikTok/profile identifier where already supported
- existing theme/language behavior

Below the profile area, show a section selector when more than one section is enabled.

Example section labels:

```text
پەیوەندی
داواکردنی خواردن
داگرتنی ئەپ
```

Use localized labels based on the selected page language.

When only one section is enabled, the section selector may be hidden and that section can be shown directly.

When the visitor selects a section, only that section's own action buttons should appear in the action area.

This is important.

Example:

If the visitor selects Restaurant:

```text
Talabat
Toters
other customer-enabled delivery services
```

should appear in the action area instead of WhatsApp/Viber contact actions.

If the visitor selects Contact:

```text
WhatsApp
Viber
Instagram
phone / existing supported non-Telegram contact methods
```

should appear.

If the visitor selects App Download:

```text
Google Play
App Store
```

should appear.

Use a smooth, light transition when switching sections. Do not reload the entire page.

---

# 4. Customer Builder UX

The customer must be able to create the page without coding.

The create/edit flow must include:

## A. Common page information

- profile/business name
- profile image
- bio
- language
- color/theme if supported
- visual template selector
- genuine live preview

## B. Section manager

Add a clear section-management UI.

The customer can:

- enable or disable supported sections
- configure each enabled section
- reorder sections
- edit section-specific links
- preview the result immediately

Do not force every customer to configure every section.

If a restaurant only needs food-ordering links, it can enable only Restaurant.

If a company only wants its app downloaded, it can enable only App Download.

If a business wants Contact + Restaurant + App Download on the same page, it can enable all three.

Preserve form state while switching between sections or templates.

---

# 5. Contact Section

The Contact section uses the existing ProxoLink contact functionality, excluding Telegram.

Telegram is not wanted in ProxoLink.

Do not add Telegram fields, buttons, demo links, bot notifications, Bot API calls, or replacement Telegram integrations.

Preserve existing supported non-Telegram contact methods where valid, including current WhatsApp, Viber, Instagram and phone-style actions.

Only enabled contact methods should render.

Do not show empty buttons.

---

# 6. Restaurant / Food Ordering Section

Add a dedicated Restaurant / Food Ordering section.

The customer should be able to select the delivery/order services their restaurant uses.

Confirmed providers:

- Talabat
- Toters

The design must support adding more delivery providers later without schema redesign.

Do not hardcode customer-specific restaurant links.

For every enabled provider, collect and store a validated destination belonging to that customer/business.

Use a provider registry or equivalent structured configuration with fields such as:

```text
provider_key
display_name
icon_asset
allowed URL/deep-link rules
enabled
sort_order
```

Do not accept executable HTML or JavaScript from users.

Do not invent undocumented URL schemes.

Prefer validated HTTPS provider/store URLs unless an officially supported deep link is already verified.

Use official/provider-approved brand assets supplied or verified for use. Do not draw fake logos or substitute unrelated icons.

A restaurant may enable only Talabat, only Toters, both, or future supported services.

The public page should render only the customer's enabled ordering services.

---

# 7. App Download Section

Add a dedicated App Download section for customers who own an application.

Confirmed download destinations:

- Google Play
- Apple App Store

The customer may enable one or both.

Collect validated store URLs.

For Google Play, validate the URL as an allowed Google Play application destination.

For Apple App Store, validate the URL as an allowed Apple App Store application destination.

Do not accept arbitrary JavaScript URLs, file URLs or unsafe schemes.

Use official store badges/assets where appropriate and allowed.

The customer should be able to configure:

```text
App name
optional short description
Google Play URL
App Store URL
```

Do not require both stores if the app exists on only one.

On the public page, show only configured store buttons.

---

# 8. Section Selector Design

The section selector is part of the public template.

It must fit each template's existing visual identity.

Do not make all eight templates look identical.

Examples of acceptable adaptation:

- pill template: compact pill-style section selector
- classic template: restrained classic tabs/buttons
- neon template: subtle neon-accented selector
- card template: card-style segmented selector

The selector must:

- be easy to understand
- remain compact
- work in RTL and LTR
- support long localized labels
- not overflow small screens
- have a clear selected state
- animate gently
- remain keyboard/accessibility friendly on web
- preserve reduced-motion preferences where supported

Do not make section controls oversized.

---

# 9. Existing Template Preservation

Preserve the distinctive identity of all eight templates.

Keep:

- backgrounds
- gradients
- card structure
- icon language
- avatar treatment
- established spacing identity
- typography identity
- existing approved animation language

The previously approved targeted refinements remain valid:

- profile name may be slightly more prominent
- bio wrapping should be balanced and readable
- spacing should be cleaner
- button press feedback should be soft
- regular text should remain natural, not oversized

Adding page sections does not authorize a broad redesign of the templates.

---

# 10. Live Template Preview

The builder must continue using genuine server-rendered live previews inside Flutter WebView.

Do not return to static `assets/styles/*` preview images.

Do not show raw HTML/CSS/JavaScript to users.

The preview should use the customer's current unsaved builder state where safely possible, including:

- chosen template
- language
- color/theme
- enabled sections
- section order
- configured provider buttons

If preview data is temporary, use a short-lived signed preview mechanism and do not write advertisement analytics.

Preview buttons must be inert or safely intercepted so testing a preview cannot call a real person, place an order, open an unrelated customer account, or create ad analytics.

---

# 11. Recommended Structured Data Model

Do not store raw customer HTML.

Keep structured customer data.

Implement an additive section configuration compatible with existing cards.

A suitable model may resemble:

```json
{
  "sections": [
    {
      "type": "contact",
      "enabled": true,
      "sort_order": 1,
      "items": [
        {"provider": "whatsapp", "value": "..."},
        {"provider": "viber", "value": "..."}
      ]
    },
    {
      "type": "restaurant",
      "enabled": true,
      "sort_order": 2,
      "items": [
        {"provider": "talabat", "url": "..."},
        {"provider": "toters", "url": "..."}
      ]
    },
    {
      "type": "app_download",
      "enabled": true,
      "sort_order": 3,
      "app_name": "...",
      "description": "...",
      "items": [
        {"provider": "google_play", "url": "..."},
        {"provider": "app_store", "url": "..."}
      ]
    }
  ]
}
```

This is an architectural example, not a requirement to use this exact JSON layout.

Choose the safest additive database representation after inspecting the existing schema.

Requirements:

- structured data only
- server-side validation
- ownership enforced
- deterministic rendering
- backward compatibility with current Contact-only cards
- no destructive migration
- easy future section/provider expansion

Do not silently rewrite production rows.

Prepare migrations safely and keep production cutover behind explicit approval.

---

# 12. Backward Compatibility

Existing ProxoLink cards must continue to work.

A current legacy/current structured Contact-only page should behave as:

```text
Enabled sections:
- Contact
```

without requiring the owner to recreate the card.

Existing stable public card UUIDs and URLs must remain unchanged.

Edit and Retry must retain the same card identity.

Do not invalidate existing advertisements that reference a card.

---

# 13. Create and Edit Flow

Create:

1. customer opens ProxoLink
2. enters common profile information
3. chooses visual template
4. enables desired sections
5. configures each section
6. sees live visual preview
7. submits
8. server validates structured data
9. one stable public page is created automatically
10. customer can immediately preview/share/use it when Ready

Edit:

1. open existing page
2. change common fields, template or sections
3. preserve unsaved state while navigating builder UI
4. validate before commit
5. keep same UUID and same public URL
6. publish atomically
7. if render/publish fails, preserve recoverable prior state and expose Retry

---

# 14. Section Validation Rules

Validate every section independently.

## Contact

Validate each platform using its known value rules.

## Restaurant

Validate each ordering destination.

Reject:

- empty enabled providers
- unsupported URL schemes
- malformed URLs
- javascript:
- file:
- data:
- arbitrary HTML
- unsupported provider spoofing

## App Download

Validate allowed Google Play and App Store destinations.

Do not trust button labels supplied by the client to determine provider identity.

Use server-recognized provider keys.

---

# 15. Provider Registry

Do not scatter provider definitions across Flutter and backend.

Create a maintainable provider registry or equivalent single-source contract.

The backend is authoritative.

Flutter receives safe metadata such as:

```text
provider_key
section_type
localized display label
icon identifier / safe asset reference
input type
validation hint
enabled state
sort order
```

Do not expose private renderer internals.

Future delivery services should be addable without redesigning the entire form.

---

# 16. UI Requirements in Flutter

The surrounding ProxoLink Flutter UI must continue matching Create Ad and Ad Details.

Use:

- existing Rabar typography
- normal weight for regular text
- blue headings
- black primary text
- gray secondary text
- white cards
- soft shadows
- existing radii
- balanced spacing
- responsive layout
- correct RTL Sorani/Arabic
- correct LTR URLs, handles, IDs and numbers

The section manager should feel native to the existing Proxo app.

Do not manually enlarge Kurdish text.

Do not make every button blue.

Use icons only where useful.

---

# 17. Section Configuration UX

Use a simple pattern.

Example:

```text
[ Contact ] [ Restaurant ] [ App Download ]

Contact
✓ WhatsApp
✓ Viber
□ Instagram

Restaurant
✓ Talabat
✓ Toters
+ Add supported service

App Download
✓ Google Play
✓ App Store
```

This is conceptual only.

The actual visual implementation should match the existing app design system.

When the customer taps a section in the builder, show that section's settings without losing data from other sections.

---

# 18. Public Button Behavior

Each section has its own action buttons.

Do not mix irrelevant actions into the active panel.

Restaurant active:
- ordering buttons

App Download active:
- store download buttons

Contact active:
- contact buttons

The visitor can switch sections using the section selector.

Switching sections must not create a new page navigation or reload the full document.

Use accessible state and predictable browser history behavior.

---

# 19. Analytics Separation

Do not break exact-ad attribution.

Existing tracked advertisement architecture must remain isolated per advertisement.

Section switching itself should not automatically count as an external contact conversion.

If section interaction analytics are added later, keep them distinct from:

- page views
- advertisement clicks
- outbound contact/order/download actions

Preview traffic must create zero advertisement analytics.

Organic traffic must not be falsely attributed to an ad.

Do not implement new production analytics without verifying privacy and retention requirements.

---

# 20. Security

Keep reusable HTML/CSS/JS template sources private on the server.

Flutter must not bundle reusable template source.

The user sees the rendered page, not source code.

Server-side rules must enforce:

- authenticated management operations
- card ownership
- provider allowlists
- safe URLs
- private template access
- structured content escaping
- no arbitrary HTML/JS injection
- no service-role keys in Flutter
- no secrets in source/logs/chat
- signed short-lived owner/template previews

Continue existing CSP, no-store, nosniff and referrer/privacy protections.

---

# 21. Telegram

Telegram is retired from ProxoLink.

Do not add it back.

Do not create:

- Telegram contact fields
- Telegram action buttons
- Telegram demo providers
- bot delivery
- Bot API calls
- Telegram notifications
- replacement Telegram credentials

Historical customer data may remain preserved for rollback/history, but it must not become an active ProxoLink control.

Do not modify the already verified retired production notification behavior unless separately authorized.

---

# 22. Restaurant Brand Assets

For Talabat, Toters and future providers:

- use verified official/provider-approved logos or assets
- keep assets optimized
- preserve correct aspect ratio
- never stretch
- include accessible labels
- do not fabricate brand marks
- do not download arbitrary third-party assets at runtime without review

If the repository already contains approved official assets, reuse them.

If no approved asset exists, report the missing asset requirement instead of inventing one.

---

# 23. Store Badges

For Google Play and Apple App Store:

- use recognized official badges/assets where permitted
- preserve their proportions
- do not recreate fake store logos
- keep labels readable
- localize surrounding UI without altering protected brand artwork

---

# 24. Responsive Requirements

Test at minimum:

- 320
- 375
- 393
- 430
- 768

Validate:

- section selector
- long business names
- long bios
- one / two / three enabled sections
- many restaurant providers
- one or both app stores
- RTL
- LTR
- mixed-script content
- text scaling
- portrait
- landscape
- keyboard overlap in edit forms

No horizontal overflow.

---

# 25. Native Android Verification

Use the existing protected Android verification workflow.

Do not create a parallel verification system unless absolutely necessary.

For template comparison, compare same-environment Android WebView baseline vs candidate when testing strict pixel parity.

Cross-renderer Chromium screenshots may remain reference evidence but must not be treated as deterministic zero-pixel native equality.

Execute real native cases.

Do not report prepared scripts as completed tests.

---

# 26. New Modular Section Test Matrix

Add tests for at least:

## Contact only

- page renders Contact directly
- correct buttons
- no Restaurant or Download controls

## Restaurant only

- Talabat only
- Toters only
- Talabat + Toters
- no Contact actions displayed
- provider links validated

## App Download only

- Google Play only
- App Store only
- both stores
- malformed store URL rejected

## Multi-section

- Contact + Restaurant
- Contact + App Download
- Restaurant + App Download
- all three

For multi-section cases verify:

- selector labels
- selected state
- panel switching
- no form-state loss
- no page reload
- no stale buttons from previous section
- correct RTL/LTR
- live preview matches public page

---

# 27. Existing Eight Templates

Run representative section tests across all eight templates.

At minimum verify every template with:

- one single-section page
- one multi-section page
- section switching
- long text
- actual WebView
- mobile width

Do not certify only one template and assume the rest.

---

# 28. Staging First

Do not use production customer records as disposable test fixtures.

Use isolated staging for write-path verification.

Verify:

- create
- edit
- stable URL
- activate
- deactivate
- retry
- section enable/disable
- section reorder
- restaurant provider validation
- store URL validation
- preview
- public render
- advertisement selection compatibility

If isolated staging does not exist, mark the write-path tests BLOCKED and provide exact setup requirements.

Do not silently test destructive flows in production.

---

# 29. Migration Safety

Any schema change must be additive first.

Before production cutover:

- back up affected rows
- verify exact existing row counts
- preserve existing card UUIDs
- preserve ad relationships
- preserve legacy columns
- validate rollback
- rehearse migration in a transaction/staging
- compare hashes/checkpoints

No destructive cleanup in this task.

---

# 30. Current Release Gates

The following remain separate owner approvals:

- activate new template versions for production customers
- production customer cutover
- merge PR #7
- production deployment of the ProxoLink feature
- destructive legacy cleanup

Do not combine these approvals.

---

# 31. Fresh Workspace Execution Order

A fresh workspace must follow this order:

1. Inspect repository, current branch and Draft PR #7.
2. Read current ProxoLink implementation and verification reports.
3. Identify already completed V5 work.
4. Do not rewrite working private-renderer/security infrastructure.
5. Design the additive modular-section model.
6. Implement section registry and server validation.
7. Update Flutter create/edit builder.
8. Update live preview payload/state.
9. Update server renderer for section selector and panels.
10. Preserve all eight template identities.
11. Add tests.
12. Run backend/Flutter/security CI.
13. Run Android native verification.
14. Run isolated staging write flows when an isolated target exists.
15. Update evidence matrix.
16. Stop before production release gates unless separately approved.

---

# 32. Definition of Done

This feature is complete only when a normal customer can:

1. open ProxoLink
2. create one personal page automatically
3. choose one of the eight visual templates
4. enable Contact, Restaurant and/or App Download sections
5. configure only the providers they use
6. see a genuine live preview
7. publish one stable public URL
8. edit it later without changing that URL
9. switch sections on the public page
10. see only the correct action buttons for the selected section
11. use Talabat/Toters links configured by a restaurant
12. use Google Play/App Store links configured by an app owner
13. use existing non-Telegram contact methods in Contact
14. keep all private template source and server secrets protected
15. preserve existing customer/ad relationships

And verification must show real executed evidence, not only prepared code.

---

# 33. Final Reporting

At completion report:

- exact files changed
- database migrations prepared/applied
- compatibility behavior for existing cards
- section/provider registry design
- Flutter builder screenshots/evidence
- live public-page evidence
- all eight template results
- Android native results
- isolated staging results
- tests passed/failed
- production state
- current PR state
- any BLOCKED items

Use:

```text
VERIFIED
FAILED
BLOCKED
```

Never report a blocked or unexecuted test as verified.

---

# Final Intent

The owner wants ProxoLink to evolve from a contact-link page into a modular business page builder.

One customer should be able to create one page and decide what that page contains.

For example, a restaurant can expose ordering options such as Talabat and Toters; an app owner can expose Google Play and App Store downloads; a normal business can expose contact methods; and a business that needs several of these can place them together on the same page as switchable sections.

Each section must show its own relevant buttons.

The eight ProxoLink template styles remain visual designs. They are not the same thing as the functional sections.

Do not add Telegram.

Do not expose source code.

Do not replace live previews with screenshots.

Do not break stable public URLs, ad relationships, existing customer data or security boundaries.
