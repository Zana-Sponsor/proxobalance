# ProxoLink Private Template Rendering & Automated Contact Card System
## V5 — Verified GitHub Architecture, Automated User Pages, Secure Visual Previews & Production Gates

> **AUTHORITATIVE V5 OWNER AMENDMENT — NO TELEGRAM IN PROXOLINK (4 OCTOBER 2026).** This decision supersedes every contrary Telegram-related instruction, example, checklist, preview fixture, UI element and release gate in Sections 0–144 and in older V2/V3/V4 plans. Historical mentions below are retained solely for traceability, NOT as active requirements. See [the no-Telegram acceptance criteria](PROXOLINK_V5_NO_TELEGRAM_ACCEPTANCE.md).
>
> **Required current behavior:** ProxoLink offers WhatsApp, Viber, Instagram, TikTok and existing phone contacts only. Remove Telegram from all contact forms, platform selectors, public and owner-rendered pages, eight genuine server-rendered demo previews, external-link navigation, tracked actions and native tests. ProxoLink sends no bot notifications, HTML files or messages and requires no Telegram bot, chat ID, token, server configuration or replacement credentials. Preserve the exact identity of all eight designs except the intentional loss/reflow of that contact button and the already approved typography, bio, spacing and press refinements.
>
> **Non-destructive compatibility:** Keep all existing customer IDs, original card rows, legacy HTML and historical platform JSON intact until separately authorized migration/cleanup; hide historical Telegram values from client responses and render output, reject Telegram in new requests, and preserve historical values when a card is edited. Previously exposed bot tokens should be revoked once by their owner using BotFather as a separate security task; do not issue a replacement for ProxoLink or make revocation a prerequisite for implementing or testing non-Telegram features. Unrelated order-notification services are outside this ProxoLink-only change and must not be silently broken.
>
> **Release gates unchanged:** Maintain Draft PR #7, private template versions, RLS, existing advertisement links, secure preview protection and the separate approval requirements for customer cutover, merge, production deployment or destructive cleanup. Native/pixel tests must now compare the approved no-Telegram output, not claim pixel identity against a historical page containing that button.



> **HISTORICAL V2/V3/V4 CONTEXT — follow the authoritative V5 live-code corrections and Sections 139–144 in case of conflict**
>
> Read this **entire document from beginning to end** before writing or changing code. Every section below is part of the implementation contract, including all analytics and security sections at the end. Implement the actual integrated Flutter + Vercel + Supabase system, not just a plan, summary, mockup, or partial prototype. Review the full requirements again after implementation and test the delivered result. Never claim a feature was tested or deployed unless it was actually verified.
>
> **LATEST OVERRIDE — LIVE VISUAL PREVIEWS, NOT STATIC IMAGES OR SOURCE-CODE DISPLAY:** The template selector must show the genuine, visually rendered versions of all eight existing templates inside Flutter, through securely rendered server URLs and an in-app WebView. Do **not** use `assets/styles/*_v1.webp`, screenshots, mockup images, generated thumbnails, or other static pictures as the template previews. Do not distribute the reusable private HTML/CSS/JS template source in Flutter. Use the same exact server renderer, private templates, fonts, CSS, JavaScript, visual styles and responsive behavior as real published cards, with safe demonstration data and no analytics or actual contact actions. Do not initialize eight heavy WebViews at once; use on-demand/lazy rendering with an immediately available real preview for the selected template. The detailed visual-preview requirements are in Section 133, as refined by the live-code corrections in Sections 139–144.
>
> **IN-PROGRESS CODE:** Inspect `Zana-Sponsor/proxobalance`, including the confirmed nested `proxo_app/` Flutter project, root `api/` web backend, the existing `feat/proxolink-private-renderer-migration` feature branch and draft PR #7 (if it remains open). The prior agent reported extensive implemented code and CI checks; **independently verify its current state** before deciding what remains, and do not assume its latest revision is production-ready. Audit and correct them before reuse. Reinspect the live Supabase database, template source, code and Vercel deployment. The historical row counts and other baseline statements below are inspection snapshots, not a guarantee of current live state. Keep existing customer data and ads intact. Never merge unverified changes directly to production.
>
> **SECURITY:** A legacy Telegram bot credential embedded in historical Flutter code is compromised even if removed from the current source. Rotation/revocation requires authorized access to Telegram BotFather; never claim it was rotated merely by deleting the literal. Keep all Supabase service-role keys and preview-signing secrets server-side only. The Proxo Supabase project and any separate Exchange Supabase project must not be confused or share an accidental fallback.


> **V5 — AUTHORITATIVE PRIORITY AND IMPLEMENTATION CONTRACT**
>
> Read this complete document, including Sections 0–144, before editing code. This V5 document supersedes V2/V3/V4 wherever they conflict. Do not treat historical baseline snapshots or completed-work reports as verified current facts; inspect the live repository, PR, database and deployments. Implement only the missing or defective work, reuse verified work and produce tangible code, migration and test results rather than another plan.
>
> **THE USER WANTS TO SEE THE VISUAL PAGE, NOT ITS CODE.** Flutter must display each of the eight genuine **visually rendered** ProxoLink templates inside its WebView, with the profile, bio, buttons, layout and animations visible like a normal contact page. Never show raw HTML, CSS, JavaScript, JSON, a source-code viewer, an editor, a file download or a syntax-highlighted code block as the preview. Never substitute `assets/styles/*_v1.webp` images, screenshots or generated thumbnails for the live page. Keep the eight reusable template source files, internal paths and renderer logic private on the server. A WebView must receive a final rendered HTML document to display a webpage; its delivered markup is technically inspectable. Protect the **reusable private source library** without falsely promising the final displayed document is uninspectable. See Sections 2, 24, 50, 133 and 136.
>
> **APP UI AND TEMPLATE DESIGNS ARE DIFFERENT SCOPES.** Refine the surrounding Flutter ProxoLink interface to match the existing Create Ad (دروستکردنی ڕیکلام) and Ad Details (وردەکاری ڕیکلام) screens in card proportions, padding, spacing, colors, shadows, button treatment and inherited Rabar typography. Inside the eight HTML contact-card templates, preserve the original distinctive identity, structure, platform functionality and colors; the user explicitly authorizes only targeted improvements to the profile-name hierarchy, balanced multi-line bio, regular text sizing, spacing and gentle button-press feedback. These authorized refinements take priority over earlier blanket instructions forbidding *any* visual difference. See Sections 5, 30, 51, 74, 133–135.
>
> **RELEASE AND ACCESS GATES.** Feature-branch code, CI passes and a Ready Vercel Preview are not the same as production completion. Complete the actual Android native WebView tests, resolve access/credential blockers using provider settings (never chat), and label each item VERIFIED, FAILED or BLOCKED. Do not merge PR #7, migrate live customers, promote to production or delete legacy data without the user's separate explicit approval. See Sections 69, 71, 96–100 and 137–138.


> **PRODUCT OUTCOME — IMPORTANT OWNER CLARIFICATION:** Each authenticated Proxo user must be able to choose an existing contact-page template, enter their own name, profile image, bio, TikTok/contact methods and supported colors, and tap **Create**. The backend must automatically create a customer-specific, publicly usable contact page and stable link **without anyone writing a customer-specific HTML file, making a GitHub commit, or deploying Vercel for that customer**. The same user must be able to preview, edit and change their template, edit their profile/contact buttons, share, activate/deactivate and reuse the same permanent page URL. Keep ownership checks and ad/card integrity. A feature is not finished merely because a template selector, API files or a database schema exists; prove the complete create → public page → edit same URL → share and advertisement-use flow in an authorized staging environment.

> **LIVE ACCESS NOTE (read-only review, 4 October 2026):** GitHub authenticated access was successful, including draft PR #7, its 72 changed files, current head `bb5772939fa74cd08e8177b99354a8695acd6290` and successful Verify ProxoLink workflow run `37215966426`. The Vercel connector could list team `proxoapp-1758` but could not list/access project `proxobalance` (empty project list, project/deployment 404, protected-preview 403). Statements about the Vercel Preview being READY are recorded in the repository report, **not directly verified by this Vercel connection**. Before repeating protected tests, reconnect/reauthorize the correct project-owning Vercel account; never bypass this blocker by disabling protection or asking for a credential in chat. Sections 139–144 capture the directly inspected code and safe completion order.
---

You are working on the Proxo ecosystem. Before changing any code, database object, GitHub file, Vercel route, or Flutter screen, inspect the current implementation and verify the live state again. Do not assume that the database, repository, or Flutter package is unchanged.

The goal is to rebuild the existing **ProxoLink / Contact Tool** flow so that it becomes fully automated, keeps all existing card designs visually intact, produces a public link automatically, opens the real public page in an in-app WebView for preview, supports Active / Inactive / Failed / Retry / Edit states, and — most importantly — removes the raw HTML template source from the Flutter application, user-accessible database rows, public GitHub files, and Telegram delivery.

---

# 0. Historical Baseline — Re-Verify Live State Before Implementing

The following facts were verified from the currently supplied Flutter project, the live Supabase project, the GitHub web repository, and the current Vercel deployment. Re-check all of them before implementation and treat the live systems as the final source of truth.

## Flutter project that was inspected

The supplied Flutter archive contains the current Proxo mobile implementation.

Important files include:

```text
proxo_app/lib/screens/tools_screen.dart
proxo_app/lib/screens/proxo_cards_list_screen.dart
proxo_app/lib/screens/card_webview_screen.dart
proxo_app/lib/widgets/html_preview_sheet.dart
proxo_app/lib/services/html_generator.dart
proxo_app/lib/templates/card_templates.dart
proxo_app/lib/services/telegram_delivery_service.dart
proxo_app/lib/controllers/proxo_card_controller.dart
proxo_app/lib/models/proxo_card.dart
proxo_app/lib/screens/ad_create_screen.dart
proxo_app/lib/screens/ad_screen.dart
```

The Flutter project already includes:

```text
webview_flutter: ^4.10.0
url_launcher: ^6.3.0
supabase_flutter: 2.5.0
flutter_svg
Rabar_021.ttf
```

The current Tools flow has eight visual styles:

```text
dark
light
classic
pill
card
neon
zoom
banner
```

The app also already contains local preview images such as:

```text
assets/styles/dark_v1.webp
assets/styles/light_v1.webp
assets/styles/classic_v1.webp
assets/styles/pill_v1.webp
assets/styles/card_v1.webp
assets/styles/neon_v1.webp
assets/styles/zoom_v1.webp
assets/styles/banner_v1.webp
```

These are **legacy screenshot assets only**. They must **not** be used in the template-selection UI after this migration. The new selector must use genuine server-rendered template previews; see Section 133. Existing screenshots may temporarily remain in source for migration comparison, but must not be displayed as previews or silently used as a fallback.

## Current unsafe / legacy behavior that must be replaced

At the moment:

```text
ToolsScreen
    ↓
buildCardHtml()
    ↓
card_templates.dart
    ↓
raw HTML/CSS/JS generated inside Flutter
    ↓
html_content saved in proxolink_cards
    ↓
HTML may also be delivered as a document
```

The current implementation therefore places template source in multiple places where it should not live.

`lib/templates/card_templates.dart` contains the actual HTML/CSS/JS of all eight templates.

`lib/services/html_generator.dart` generates the final HTML inside Flutter.

`tools_screen.dart` currently calls `buildCardHtml()`, writes HTML temporarily, stores it in `proxolink_cards.html_content`, and sends generated HTML through the delivery pipeline.

The existing preview also reads saved HTML and loads it using `loadHtmlString(...)`.

This architecture must be replaced.

## Critical secret finding

A legacy controller file contains a hard-coded Telegram bot credential.

Do **not** copy, print, document, commit, or reuse its value.

Treat that credential as compromised.

Before release:

```text
revoke/rotate the old Telegram bot credential
remove it from Flutter source
remove any direct Telegram Bot API calls from Flutter
ensure no secret is compiled into APK/IPA
```

If Telegram notifications are still desired, they must be sent server-side using environment secrets. Never send raw template HTML to Telegram.

## Live Supabase baseline

Supabase project:

```text
cojchkwssmasiejcgvbk
```

Current table:

```text
public.proxolink_cards
```

Verified columns currently include:

```text
id uuid primary key default gen_random_uuid()
user_id uuid not null references auth.users(id) on delete cascade
name text not null
description text
avatar_b64 text
style text default 'classic'
color_theme text default '#1c2333'
platforms jsonb default '{}'
status text default 'active'
card_number integer not null
created_at timestamptz default now()
bio text
html_content text
checked_btns jsonb
tiktok text
logo_b64 text
video_url text
tt text
```

RLS is enabled.

Current policies include owner access and admin access.

Existing owner rule is based on:

```text
auth.uid() = user_id
```

There is currently no dedicated ProxoLink template metadata table.

There is currently no private ProxoLink template bucket.

Existing storage buckets include public image buckets and at least one unrelated private identity-documents bucket.

At the time of inspection:

```text
20 proxolink_cards rows existed
20/20 contained html_content
18/20 contained avatar_b64
all 20 had status = active
```

Existing styles in those rows include multiple current templates. Existing customer cards must not be lost.

## Ads integration already exists

`pa_ads` contains:

```text
asset_id uuid
goal text
user_id uuid
status text
```

There is currently no verified foreign-key constraint from:

```text
pa_ads.asset_id
```

to:

```text
proxolink_cards.id
```

`AdCreateScreen` currently loads ProxoLink cards from `proxolink_cards`.

`AdScreen` also checks an ad's `asset_id` when duplicating an ad.

The new implementation must preserve this integration and make it safer.

## GitHub / Vercel baseline

Web/API repository:

```text
Zana-Sponsor/proxobalance
```

Important note:

The latest accessible `Zana-Sponsor/proxobalance` repository has a Vercel web/API project at its root **and** a `proxo_app/` Flutter directory that includes `lib/screens/tools_screen.dart` and `lib/templates/card_templates.dart`. Re-check the current branch and exact file versions before making changes.

Treat the root web/API project and the nested Flutter application as **separate build/deployment targets** even when they share a GitHub repository. Do not mix server credentials or web build artifacts into Flutter.

Current Vercel routing is based on `vercel.json`, with serverless functions under:

```text
api/*.js
```

The repository already contains:

```text
api/_lib/security.js
```

with existing authentication/security helpers.

Reuse existing security infrastructure where appropriate instead of creating a second inconsistent authentication system.

The latest inspected main deployment was successful.

---

# 1. Main Product Goal

Create a fully automated **ProxoLink Contact Card** system.

The user experience must be:

```text
ToolsScreen
    ↓
Create Contact Tool
    ↓
Choose one of the existing Proxo templates
    ↓
Enter name / bio / TikTok / WhatsApp / Telegram / Instagram / phone / etc.
    ↓
Choose profile image when required
    ↓
Tap Create
    ↓
Card record receives a UUID
    ↓
Server validates that the selected private template can render this card
    ↓
Card becomes Active
    ↓
Public link is immediately available
    ↓
https://PUBLIC_DOMAIN/contact/CARD_UUID
```

There must be:

```text
NO per-card HTML file creation
NO GitHub commit per customer
NO Vercel redeployment per customer
NO raw template HTML saved in the card row
NO raw HTML template bundled in Flutter
NO raw HTML sent to Telegram
```

Creating or editing a card must normally require only database/API operations.

---

# 2. Important Technical Truth About Source Privacy

The raw reusable template library must not be exposed.

The final HTML/CSS that a browser receives in order to display a public webpage can always be inspected by a technically skilled user through browser developer tools. No web architecture can make the final browser-delivered markup literally invisible.

Therefore the security objective is:

```text
Hide the reusable raw template source library
Hide every other template
Hide private template storage paths
Hide server rendering logic secrets
Hide database/service-role credentials
Hide generator source from Flutter
Do not expose raw template files directly
Return only the final rendered document for the selected card
```

The implementation must never falsely claim that browser-rendered HTML is impossible to inspect.

However, it must ensure that the user cannot fetch:

```text
template-dark.html
template-light.html
all template files
private storage objects
raw template source
template source maps
server secrets
```

from the public application.

---

# 3. Required Architecture

Use this architecture:

```text
Flutter app
    │
    │ only sends structured card data
    ▼
Authenticated API / secure RPC
    │
    ▼
Supabase proxolink_cards
    │
    │ stores DATA only
    ▼
CARD UUID
    │
    ▼
/contact/CARD_UUID
    │
    ▼
Vercel server function
    │
    ├── load card data
    ├── verify Active + Ready
    ├── find selected template metadata
    ├── privately load exact template version
    ├── validate/sanitize card values
    ├── inject the customer's values
    └── return the final rendered HTML
         │
         ▼
Browser / Flutter WebView
```

Raw template source must live only in protected server-side storage.

---

# 4. Private Template Storage

Create a new private Supabase Storage bucket, for example:

```text
proxolink-templates
```

Requirements:

```text
public = false
```

Store the existing templates with versioning:

```text
dark/v1/template.html
light/v1/template.html
classic/v1/template.html
pill/v1/template.html
card/v1/template.html
neon/v1/template.html
zoom/v1/template.html
banner/v1/template.html
```

Do not expose signed template URLs to Flutter or the public browser.

The Vercel backend should retrieve the template with server-side credentials and return only the rendered final page.

Do not put those template HTML files under:

```text
public/
assets/
Flutter assets/
GitHub public static files/
```

Do not make them directly downloadable.

---

# 5. Preserve the Eight Original Design Identities — Allow Only Approved Refinements

This is primarily a privacy/architecture migration, **not** a replacement of the eight contact-card designs. Preserve each original template's distinctive visual identity. The user has separately and explicitly approved the narrow typography, bio-wrapping, spacing and button-press refinements described in Section 135. Those refinements are required and override any older instruction that every pixel must remain unchanged.

Preserve:

```text
layout
spacing
font sizes
font weights
cards
button shapes
icons
gradients
profile image position
backgrounds
borders
shadows
animations
responsive behavior
platform button order
Kurdish / Arabic direction
footer
privacy / terms links
TikTok integration where intentionally required
```

Do not arbitrarily modernize, simplify, restructure, recolor or reinterpret the original templates. Apply **only** the approved improvements in Section 135. Preserve all other design details.

First establish a baseline that reproduces the original template design accurately. Then apply the approved, controlled refinements to the versioned private templates and test both the new live preview and the actual published page using the same refined version. Do not falsely report a pixel-identical result when an intentionally changed font size, line wrap, spacing or press animation produces an approved visual difference.

For each template:

```text
old Flutter generated output
vs.
new Vercel server-rendered output
```

must be compared visually. Record any differences and distinguish **approved Section 135 refinements** from unintended regressions.

Test at minimum:

```text
320 CSS px
375 CSS px
393 CSS px
430 CSS px
768 CSS px
```

Do not accept:

```text
layout shift
unapproved padding or spacing changes
different gradient
unapproved button size or shape changes
missing or broken animation
unapproved font changes
icon mismatch
RTL breakage
unbalanced or unintended line wrapping (apart from approved improvements)
```

---

# 6. Template Dependencies

Inspect every current template before migration.

The existing template source currently references external resources such as font/icon resources and analytics scripts.

Do not blindly copy dependencies without review.

Prefer:

```text
local controlled Proxo font asset
inline/local SVG icons where practical
stable Proxo-controlled image assets
```

The project already contains `Rabar_021.ttf` in Flutter.

For the web renderer, use an approved/licensed web-compatible Rabar 021 asset owned by the project.

Avoid depending on an unrelated public GitHub raw URL for the production font if a Proxo-controlled asset can be served instead.

If TikTok Pixel remains required:

```text
move configurable IDs to server-side configuration
do not hardcode sensitive configuration into Flutter
disable tracking during authenticated in-app preview
preserve production tracking behavior on the real public page
```

---

# 7. Template Metadata Table

Add a protected metadata table such as:

```sql
public.proxolink_templates
```

Recommended schema:

```sql
id uuid primary key default gen_random_uuid(),

template_key text not null,
version integer not null,

display_name_ckb text not null,
display_name_en text,

storage_path text not null,
checksum_sha256 text,

requires_avatar boolean not null default false,
is_active boolean not null default true,

created_at timestamptz not null default now(),
updated_at timestamptz not null default now(),

unique(template_key, version)
```

Example rows:

```text
dark / 1
light / 1
classic / 1
pill / 1
card / 1
neon / 1
zoom / 1
banner / 1
```

`storage_path` is internal.

Do not expose `storage_path` to ordinary authenticated users.

Do not expose the raw template object.

If Flutter needs a catalog, provide a safe RPC/view/API that returns only:

```text
template_key
version
display_name
requires_avatar
is_active
preview identifier / safe preview URL
```

The local `*_v1.webp` files must **not be used to display template previews**. Provide a safe server-rendered preview endpoint and metadata-only catalog; see Section 133.

---

# 8. Card Table Migration

Preserve the current `public.proxolink_cards` table and existing IDs.

Do not recreate all cards with new IDs.

The public URL must be based on the existing stable UUID:

```text
/contact/<proxolink_cards.id>
```

Add fields needed for the new architecture.

Recommended final additions:

```sql
template_key text
template_version integer not null default 1

avatar_path text

card_language text not null default 'ku'

publish_status text not null default 'creating'

last_publish_error_code text
last_publish_error_at timestamptz

published_at timestamptz
updated_at timestamptz not null default now()
```

Continue to use `status` for public availability.

Recommended `status` values:

```text
active
inactive
```

Recommended `publish_status` values:

```text
creating
ready
failed
```

This is intentionally separated into two columns.

Do not overload one column with both:

```text
whether the user disabled the card
```

and:

```text
whether server rendering succeeded
```

---

# 9. Status Model

Use the following state model.

## Creating

Database:

```text
publish_status = creating
```

UI label:

```text
لە دروستکردندایە...
```

Behavior:

```text
show spinner
disable duplicate Create action
disable Use for Ad
disable public Share
wait for server validation
```

## Active

Database:

```text
status = active
publish_status = ready
```

UI label:

```text
چالاکە
```

This means:

```text
public URL works
preview works
copy link works
share works
edit works
use for ad works
deactivate works
```

## Inactive

Database:

```text
status = inactive
publish_status = ready
```

UI label:

```text
ناچالاکە
```

This means:

```text
card data is valid
template renders correctly
owner intentionally disabled the public page
```

The normal public route must not expose an inactive card.

The owner may still use an authenticated preview.

## Failed

Database:

```text
publish_status = failed
```

UI label:

```text
دروستکردن سەرکەوتوو نەبوو
```

Show:

```text
دووبارە هەوڵبدەرەوە
```

The user must not be forced to fill the entire form again.

Keep the same card UUID.

Retry should re-run server validation/render readiness.

If successful:

```text
publish_status = ready
status = active
```

If it fails again:

```text
publish_status = failed
```

Never create duplicate cards from repeated Retry taps.

---

# 10. Important Clarification About "Link Creation Failure"

The public URL is deterministic:

```text
PUBLIC_BASE_URL + "/contact/" + CARD_UUID
```

Therefore there is no reason to generate and store a random HTML filename.

The "link" itself should not require a build or deployment.

What may fail is:

```text
template not found
template disabled
invalid customer data
image failure
backend failure
Supabase failure
render validation failure
```

Therefore a card should be shown as `Failed` because publishing/render readiness failed, not because a string URL could not be constructed.

The same UUID and same future public URL must be reused on Retry.

---

# 11. Do Not Store public_url as the Source of Truth

Do not make the database depend on a hard-coded domain.

The public URL should normally be derived from:

```text
PROXO_PUBLIC_BASE_URL
+
/contact/
+
card.id
```

The domain may change later.

The card UUID is the permanent identifier.

If a cached/display URL field is added, it must not be treated as authoritative.

---

# 12. Creation Flow

Replace the current `_submit()` HTML-generation workflow.

Current behavior that must disappear:

```text
buildCardHtml(...)
temporary .html file
html_content insert
sendHtmlDocument(...)
```

New flow:

```text
1. Validate Flutter inputs locally
2. Upload profile image if required
3. Send structured data to authenticated backend
4. Backend verifies authenticated user
5. Backend verifies template_key + version exist and are active
6. Insert card with publish_status=creating
7. Backend privately loads template
8. Backend renders/validates card using proposed data
9. If render passes:
       publish_status=ready
       status=active
       published_at=now()
10. If render fails:
       publish_status=failed
       store safe internal error code
11. Return card UUID + status + derived public path
12. Flutter refreshes the card list
```

The API response on success should look approximately like:

```json
{
  "ok": true,
  "card": {
    "id": "CARD_UUID",
    "status": "active",
    "publish_status": "ready",
    "public_path": "/contact/CARD_UUID"
  }
}
```

Do not return:

```text
template HTML
template storage path
service key
internal stack trace
raw SQL error
```

---

# 13. Structured Data Only

Flutter should send structured content such as:

```json
{
  "name": "Zana Store",
  "bio": "Mobile Accessories",
  "tt": "zana_store",
  "template_key": "dark",
  "template_version": 1,
  "color_theme": "purple",
  "card_language": "ku",
  "platforms": {
    "wa": "9647501234567",
    "ig": "zana.store",
    "tg": "zanastore"
  },
  "avatar_path": "USER_UUID/CARD_UUID/avatar.webp"
}
```

Flutter must never send:

```text
full HTML template
full CSS
template JavaScript
template storage path
service-role credentials
Telegram bot credentials
```

---

# 14. Platform Normalization — historical Telegram examples superseded by owner amendment

Preserve the existing supported contact options unless product requirements explicitly change.

The existing project includes:

```text
WhatsApp
Viber
Telegram
Instagram
Korek / phone
Asiacell / phone
TikTok identity
```

Normalize values in trusted server logic.

Examples:

```text
WhatsApp:
input 9647501234567
→ https://wa.me/9647501234567
or the exact current supported deep-link behavior

Instagram:
zana.store
→ https://instagram.com/zana.store

Telegram:
zanastore
→ https://t.me/zanastore

Phone:
964...
→ tel:964...
```

Do not use client-provided full arbitrary JavaScript handlers.

Build safe URLs server-side.

Allow only supported protocols:

```text
https:
tel:
mailto:
whatsapp:
viber:
```

as required by the template behavior.

Reject dangerous schemes such as:

```text
javascript:
data:
file:
```

except controlled internal rendering data where explicitly required and sanitized.

---

# 15. Avatar / Profile Image Migration

The current table stores large Base64 values.

This must be migrated away from:

```text
avatar_b64
logo_b64
```

Create an isolated image bucket, for example:

```text
proxolink-assets
```

This bucket may be public only for image delivery if the security model confirms that public profile images are intentional.

Allowed MIME types:

```text
image/jpeg
image/png
image/webp
```

Use paths such as:

```text
USER_UUID/CARD_UUID/avatar.webp
```

Authenticated users may write/delete only inside their own first-level folder.

Do not store Base64 image blobs in the final card table.

Migration requirements:

```text
existing 18 Base64 avatars must be migrated safely
verify uploaded object exists
verify image can render
only then update avatar_path
do not clear legacy Base64 until verification passes
```

Use a secure server-side migration script, not public Flutter code.

---

# 16. Existing html_content Migration

There are existing production rows containing `html_content`.

Do not delete them blindly.

Use a staged migration.

## Phase A

Add new columns and private templates.

Keep existing `html_content` temporarily for rollback.

## Phase B

For each existing card:

```text
map current style -> template_key
set template_version
migrate avatar
verify structured platforms
server-render the card from structured data
compare it to legacy visual output
mark publish_status=ready only after validation
```

## Phase C

Update Flutter so it no longer reads or writes `html_content`.

## Phase D

After all active rows pass validation:

```text
stop exposing html_content to users
set legacy values to null or move them out of user-readable storage
```

## Phase E

After a defined rollback window and successful production verification:

```text
drop html_content
drop avatar_b64
drop logo_b64
remove other obsolete legacy fields only if no remaining code depends on them
```

Before destructive cleanup, export a secure backup.

Do not keep raw template code indefinitely in a table that ordinary users can select.

---

# 17. Template Rendering API

Add a Vercel server endpoint for public rendering.

Recommended route:

```text
GET /contact/:id
```

Use a Vercel rewrite such as:

```json
{
  "source": "/contact/:id",
  "destination": "/api/contact?id=:id"
}
```

Create:

```text
api/contact.js
```

The function must:

```text
1. validate UUID
2. load card using service-side access
3. verify publish_status = ready
4. verify status = active
5. load exact template_key + template_version
6. verify template metadata is active
7. privately fetch template source
8. sanitize all user data
9. generate contact URLs safely
10. inject data
11. return the final rendered HTML
```

Response:

```text
Content-Type: text/html; charset=utf-8
X-Content-Type-Options: nosniff
```

Use conservative caching initially so edits appear immediately.

Prefer:

```text
Cache-Control: no-store
```

until a deliberate cache invalidation strategy is implemented.

Do not redirect the public user to a Supabase Storage template URL.

Do not expose the private bucket object path in page source.

---

# 18. Reuse Existing Vercel Security Infrastructure

The web repository already contains:

```text
api/_lib/security.js
```

with authentication and request handling helpers.

Reuse that architecture where appropriate.

Do not create a second unrelated auth parser.

For authenticated card management endpoints:

```text
withSecurity(..., { auth: 'required' })
```

or the equivalent verified existing helper should be used.

For the public renderer:

```text
auth = none
```

but the renderer must expose only the final public page for an Active + Ready card.

Never expose private metadata through the public endpoint.

---

# 19. Authenticated Card Management API

Implement authenticated operations for:

```text
create
edit
activate
deactivate
retry
delete
preview-token if needed
```

Possible API layout:

```text
POST   /api/contact-cards
PATCH  /api/contact-cards?id=CARD_UUID
POST   /api/contact-card-action
GET    /api/contact-preview-token?id=CARD_UUID
```

You may choose another clean structure compatible with the current Vercel project.

Every write must verify:

```text
authenticated user.id = card.user_id
```

Never trust a `user_id` sent by Flutter.

---

# 20. Safe Create / Retry Idempotency

Prevent duplicate cards when the user taps Create repeatedly or a network retry occurs.

Use an idempotency strategy.

For example:

```text
client_request_id UUID
```

with a unique constraint per user.

Create operation:

```text
same user + same client_request_id
→ return the existing result
```

Retry operation must operate on the same `card.id`.

Do not insert a second card just because a publish attempt failed.

---

# 21. Optional Publish Attempt Audit

Recommended table:

```sql
public.proxolink_publish_attempts
```

Suggested schema:

```sql
id uuid primary key default gen_random_uuid(),
card_id uuid not null references public.proxolink_cards(id) on delete cascade,
user_id uuid not null references auth.users(id) on delete cascade,

operation text not null,
result text not null,

error_code text,
created_at timestamptz not null default now()
```

Allowed operations may include:

```text
create
retry
activate
edit_publish
```

Allowed results:

```text
started
success
failed
```

Never store raw secrets or full HTML in this audit table.

Users may optionally read their own simplified history.

Server/admin may inspect full operational history.

---

# 22. RLS

Keep RLS enabled on:

```text
proxolink_cards
```

Add RLS to all new user-facing tables.

For card ownership:

```text
auth.uid() = user_id
```

For template metadata:

Raw template metadata and `storage_path` should not be directly readable by ordinary users.

Prefer server/service-role-only access to the internal template table.

If Flutter needs a template catalog, expose only a safe RPC or view.

For publish attempts:

```text
owner can select own attempts
client should not directly insert arbitrary audit rows
server performs inserts
```

---

# 23. Private Storage Policies

For:

```text
proxolink-templates
```

do not grant anonymous direct read access.

Do not grant ordinary authenticated users direct raw-template read access.

Only trusted server-side/service-role code should read template HTML.

For:

```text
proxolink-assets
```

allow owner uploads only under:

```text
auth.uid()/...
```

Never allow one user to overwrite another user's card image.

---

# 24. Public Template Source Protection Acceptance Test

After implementation, verify all of the following:

```text
Flutter release bundle does not contain the eight raw template HTML documents.
card_templates.dart no longer contains raw HTML.
html_generator.dart no longer contains the reusable template source.
proxolink_cards no longer exposes html_content to normal users.
Telegram no longer receives HTML files.
Public GitHub static files do not contain the raw template library.
Private template bucket cannot be fetched anonymously.
Flutter cannot request the private template object.
Browser Network does not reveal a private template signed URL.
No source maps expose template source.
Only the final rendered selected card document is returned to the browser.
```

Build a release APK and search it for unique strings from the old templates.

They must not exist except for ordinary user-facing copy that is intentionally part of Flutter.

---

# 25. Remove / Replace Flutter Template Generator

`lib/templates/card_templates.dart`

must no longer ship the raw templates.

Either:

```text
delete it
```

or replace it with safe enum/metadata only.

`lib/services/html_generator.dart`

must no longer generate HTML.

It may retain only safe shared models/helpers such as:

```text
PlStyle enum
display names
requiresAvatar
platform metadata
validation helpers
```

Prefer moving those non-secret definitions to a clearly named file such as:

```text
lib/models/proxolink_template_meta.dart
```

so `html_generator.dart` can be removed entirely.

---

# 26. Remove Old Local HTML Preview

The current preview loads:

```text
html_content
```

with:

```text
loadHtmlString(...)
```

This must be replaced.

Do not preview raw HTML stored in the app.

The preview must load the rendered URL from the server.

---

# 27. WebView Preview — Must Match Chrome

Preview must use the real server-rendered page.

For an Active card:

```text
https://PUBLIC_DOMAIN/contact/CARD_UUID
```

The Flutter WebView should use:

```text
WebViewController.loadRequest(...)
```

not:

```text
loadHtmlString(...)
```

Because both Chrome and the WebView are loading the same web page:

```text
same HTML
same CSS
same JS
same responsive layout
same assets
```

the visual result should be the same.

The only difference is that the in-app WebView has Proxo navigation chrome instead of the Chrome address bar.

---

# 28. Preview Tracking Safety

Do not let the owner's repeated Preview actions pollute advertising analytics.

Use the same renderer and same design, but support a server-verified preview mode.

For example:

```text
/contact/CARD_UUID?preview_token=SHORT_LIVED_SIGNED_TOKEN
```

For an active card the design must be visually identical.

Preview mode may suppress:

```text
TikTok Pixel page events
conversion events
other marketing analytics
```

without changing layout.

For an Inactive card, a valid authenticated/signed preview token may allow the owner to preview it even though normal public visitors cannot.

Never create a second "fake Flutter preview design".

Preview must use the same server renderer.

---

# 29. WebView Navigation Behavior

The project already has:

```text
webview_flutter
url_launcher
```

Use them.

WebView:

```text
JavaScriptMode.unrestricted
```

may be required because current templates contain JS/animations.

But navigation must be controlled.

Allow:

```text
initial same-origin Proxo contact page
same-origin assets
```

Intercept external contact actions:

```text
whatsapp://
viber://
tel:
mailto:
https://wa.me/
https://instagram.com/
https://t.me/
approved TikTok URLs
```

and open them externally with `url_launcher` where appropriate.

Block unexpected arbitrary navigation.

Show a Proxo error state when the page cannot load.

Include:

```text
دووبارە هەوڵبدەرەوە
```

for WebView network/render failure.

---

# 30. Card List UI — Unify with Create Ad and Ad Details

Refine all **ProxoLink-specific** Flutter surfaces (Tools/ProxoLink entry, template selector, preview containers, contact form, list and card actions) to follow the **existing Create Ad and Ad Details visual system**. This is an explicitly authorized ProxoLink redesign; do not redesign unrelated application screens or the eight HTML template identities.

Maintain/match:

```text
white / existing off-white app backgrounds
existing Proxo blue headings and active accents
black primary text and restrained gray secondary text
existing Create Ad / Ad Details card proportions and radii
existing padding, row rhythm, compact component sizing and soft shadows
existing rounded inputs, natural-sized chips and button patterns
real server-rendered visual template previews, not images or source code
correct RTL Sorani / Arabic and natural LTR Latin text and numbers
inherited default Rabar typography; normal regular text without manual size bumps
```

Improve each existing card row so its state and actions are clear.

Each row should show:

```text
avatar
name
created date
template/style chip
status chip
actions
```

---

# 31. Active Card Actions

When:

```text
status = active
publish_status = ready
```

show actions such as:

```text
پێشبینین        Preview
دەستکاریکردن    Edit
کۆپی لینک       Copy Link
هاوبەشکردن      Share
ناچالاککردن     Deactivate
ڕیکلام           Use for Ad
سڕینەوە          Delete
```

Do not overload the row with seven permanent icons.

Use one or two primary actions plus an overflow/bottom sheet for secondary actions if needed.

The UI must remain clean and mobile-friendly.

---

# 32. Inactive Card Actions

When:

```text
status = inactive
publish_status = ready
```

show:

```text
ناچالاکە

پێشبینین
دەستکاریکردن
چالاککردن
سڕینەوە
```

Do not allow normal public Share/Use for Ad until reactivated.

Copying the public link while inactive should either:

```text
be disabled
```

or clearly warn:

```text
this link is currently inactive
```

---

# 33. Failed Card Actions

When:

```text
publish_status = failed
```

show:

```text
دروستکردن سەرکەوتوو نەبوو
```

Primary action:

```text
دووبارە هەوڵبدەرەوە
```

Also allow:

```text
دەستکاریکردن
سڕینەوە
```

Do not show:

```text
Use for Ad
Share public link
Active status
```

until Retry succeeds.

Do not display raw server exception text to the user.

Use a friendly localized message.

Log the safe error code internally.

---

# 34. Creating State UI

While create/publish validation is running:

```text
لە دروستکردندایە...
```

Show:

```text
spinner
disabled Create button
stable layout
```

Do not let the user accidentally create two rows.

If the app is closed mid-request, the backend/idempotency behavior must allow safe recovery.

---

# 35. Edit Flow

Add a real Edit action.

When the user taps Edit:

```text
load current card data
open the existing form
pre-fill:
  template
  theme
  name
  bio
  TikTok
  enabled contact methods
  contact values
  language
  avatar
```

The UUID must remain unchanged.

The public link must remain unchanged.

Example:

```text
/contact/abc-123
```

before Edit and after Edit.

Do not create a new card for an ordinary edit.

---

# 36. Safe Atomic Edit

Do not break a currently Active public card if an edit contains invalid data.

Preferred edit behavior:

```text
1. receive proposed new data
2. validate template exists
3. validate values
4. server-render proposed version in memory
5. if render passes:
       update DB atomically
6. if render fails:
       do not replace the current published values
       return a friendly error
```

This prevents an Edit failure from taking a working public link offline.

For avatar replacement:

```text
upload new image
validate it
commit DB change
then delete old object
```

Do not delete the currently published avatar before the replacement is confirmed.

---

# 37. Template Change During Edit

Changing:

```text
dark → neon
```

must update:

```text
template_key
template_version
```

after validation.

The card UUID and public link remain the same.

Do not regenerate the public URL.

---

# 38. Activate / Deactivate

## Deactivate

Authenticated owner only.

Set:

```text
status = inactive
```

Do not delete the card.

Do not delete its UUID.

Do not delete structured data.

Normal public request should return a safe unavailable response / 404-style page.

## Activate

Before activation:

```text
revalidate selected template
revalidate required avatar
revalidate required platform values
server-render test
```

Then:

```text
status = active
publish_status = ready
```

If validation fails:

```text
publish_status = failed
```

and show Retry/Edit.

---

# 39. Public Page for Inactive / Failed Cards

Do not reveal internal status details publicly.

A visitor to an unavailable card should receive a neutral Proxo page such as:

```text
This page is currently unavailable.
```

or a safe 404-style response.

Do not reveal:

```text
owner ID
template key
storage path
failure reason
database error
```

---

# 40. Retry Flow

Retry must be idempotent.

Flow:

```text
Failed card
    ↓
Tap Retry
    ↓
publish_status = creating
    ↓
server loads same card UUID
    ↓
server validates current structured data
    ↓
server loads same selected template/version privately
    ↓
render test
    ↓
success → ready + active
failure → failed
```

Do not create another card.

Do not change UUID.

Do not change the link.

Do not re-upload avatar unless required.

---

# 41. Copy Link

Only expose the canonical public URL after the card is Active + Ready.

Example:

```text
https://PUBLIC_DOMAIN/contact/CARD_UUID
```

Use the system clipboard.

Show a small Proxo toast:

```text
بەستەرەکە کۆپی کرا
```

Do not copy a private template URL.

---

# 42. Share

Use platform share functionality to share only:

```text
public contact URL
optional card name
```

Never attach:

```text
HTML file
template source
database payload
private storage URL
```

---

# 43. Use for Ad

Preserve the current Tools → AdCreate flow.

However, only cards satisfying:

```text
user_id = auth.uid()
status = active
publish_status = ready
```

may be used for a new ad.

Change `AdCreateScreen._loadAssets()` so it does not list:

```text
inactive
creating
failed
other users' cards
```

The selected ad asset must continue to use the card UUID.

---

# 44. Add Database Integrity for pa_ads.asset_id

Before adding a foreign key, inspect existing data for orphaned asset IDs.

If safe, add:

```text
pa_ads.asset_id
    references public.proxolink_cards(id)
```

Choose deletion behavior carefully.

Recommended:

```text
ON DELETE SET NULL
```

or block deletion while active ads depend on the card.

Also add server/database validation so an ad cannot attach:

```text
another user's card
inactive card
failed card
creating card
```

The rule should be:

```text
ad.user_id = card.user_id
card.status = active
card.publish_status = ready
```

Do not depend only on Flutter UI filtering.

---

# 45. Delete Behavior

Before deletion, check whether the card is referenced by ads.

If an active/pending ad uses it:

```text
show a clear warning
```

Prefer preventing deletion until the user resolves the dependent ad, or require an explicit safe confirmation based on product requirements.

Never silently leave a paid/live ad pointing to a broken destination.

After deletion:

```text
public URL becomes unavailable
private avatar object may be deleted
publish logs cascade/delete as designed
```

Do not delete shared template files.

---

# 46. Retired Telegram Behavior — historical text superseded by owner amendment

The current architecture sends generated HTML through a delivery pipeline.

Stop doing that.

If Telegram notification is still needed, send only metadata such as:

```text
ProxoLink card created
card name
template name
card ID
public URL
user/account reference if appropriate for admins
```

Do not send:

```text
template HTML
CSS
JavaScript
private template storage path
service keys
```

Prefer Vercel server → Telegram directly using Vercel environment secrets.

Flutter should not contain:

```text
bot token
chat ID if sensitive
shared secret presented as a true secret
```

Remember: any value compiled into Flutter can be extracted from the APK/IPA.

---

# 47. Legacy Credential Remediation — one-time revocation, no replacement for ProxoLink

The old hardcoded Telegram token discovered in the supplied Flutter project must be treated as leaked.

Required release task:

```text
rotate/revoke it
remove the literal from source
remove direct Bot API code
ensure CI logs do not print the new credential
store new server-only credentials in Vercel/secure worker environment
```

Do not include the old token value in commits, tickets, documentation, or output.

If it ever existed in Git history, rotation is mandatory even if the code is later deleted.

---

# 48. Flutter Model Update

Update `ProxoCard`.

It should no longer require:

```text
htmlContent
avatarB64
```

Recommended model fields:

```text
id
userId
name
bio
templateKey
templateVersion
colorTheme
avatarUrl/avatarPath
platforms
status
publishStatus
cardNumber
createdAt
updatedAt
publicUrl/publicPath derived in app
```

Keep only compatibility fields temporarily during the migration window.

---

# 49. Flutter List Query

Current card fetch loads the entire row.

Change it to an explicit safe column list.

Do not use:

```text
select()
```

after private/legacy columns exist.

Use only required UI fields.

Example conceptually:

```text
id
name
bio
style/template_key
template_version
color_theme
avatar_path
platforms
status
publish_status
card_number
created_at
updated_at
```

This reduces accidental exposure.

---

# 50. Template Selector in Flutter — Real Rendered Previews, Not Images

Preserve the existing Proxo Tools UI and template-selection flow, but **replace every image-based template preview with the genuine, server-rendered design inside Flutter**. The actual reusable HTML/CSS/JavaScript template files are read privately on the server, and a safe final page is sent to the WebView for **visual display as a normal contact page**. The Flutter UI must never expose the source as text, a code viewer, an editor, JSON or a downloadable HTML file. The browser-delivered final page is necessarily HTML and can technically be inspected; this does not permit exposing the private reusable template files or other templates. No local screenshot, mockup, static thumbnail or cached PNG/WebP may be used as the selector preview.

Available designs remain:

```text
Dark
Light
Classic
Pill
Card
Neon
Zoom
Banner
```

Implement a safe on-demand preview endpoint using deterministic sample profile and contact data without creating customer card rows; disable TikTok Pixel, analytics, external contact actions and writes in selector preview mode. Load the preview of the currently selected template and lazily render any additional visible previews when necessary. Avoid eight simultaneously active heavy WebViews. Maintain the real template's original proportions, typography, CSS, effects, animations, RTL direction, and responsive layout. If live rendering fails, show a compact error/retry state **rather than substituting the old image preview**.

Selection stores only:

```text
template_key
template_version
```

See Section 133 for the complete requirements and acceptance tests.

---

# 51. Rabar 021 and Design Consistency

Use the existing Create Ad / Ad Details design tokens in the surrounding Flutter ProxoLink interface. Inherit the application's default Rabar typography; keep normal text at its regular weight and natural size, with no arbitrary hardcoded boosts or heavy weights. For the eight rendered contact-page templates, apply the approved, subtle profile-name hierarchy and regular bio/button typography from Section 135 while preserving each template's distinctive style.

The supplied Flutter project already contains:

```text
assets/fonts/Rabar_021.ttf
```

Do not replace the Tools UI with system fonts.

For the rendered contact cards, preserve the font behavior of the existing templates while moving the font hosting to a controlled production location if appropriate.

Do not otherwise alter the existing contact-card template appearance beyond the explicit, targeted Section 135 refinements.

---

# 52. Public Renderer Sanitization

All customer-controlled values must be escaped according to context.

Use different escaping for:

```text
HTML text
HTML attributes
URLs
JSON embedded inside scripts
JavaScript strings if unavoidable
```

Do not perform a naive placeholder replacement with unsanitized user data.

Never allow:

```text
<script> from user input
event-handler attributes from user input
javascript: links
raw arbitrary HTML bio
```

unless a future feature explicitly creates a sanitized rich-text system.

---

# 53. Template Placeholder Contract

Define a strict placeholder contract for private templates.

For example:

```text
{{NAME}}
{{BIO}}
{{AVATAR_URL}}
{{TIKTOK_HANDLE}}
{{PLATFORM_BUTTONS}}
{{CONTACT_CONFIG_JSON}}
{{THEME_FROM}}
{{THEME_TO}}
{{LANG}}
```

Do not allow arbitrary executable template expressions.

The renderer should know exactly which placeholders are legal.

At template upload/registration time:

```text
validate required placeholders
validate template version
calculate checksum
reject malformed template
```

---

# 54. Template Versioning

Pin each card to a template version.

Example:

```text
template_key = dark
template_version = 1
```

A future `dark/v2` must not silently alter every existing customer's card unless that migration is explicitly intended.

This protects current production designs.

An admin migration may later update cards to a new version after testing.

---

# 55. Future Automatic Template Management

The system should be designed so future templates can be added without embedding HTML into Flutter.

Future admin process may be:

```text
upload private template
register template metadata
register the template in the private renderer
activate template version
Flutter catalog shows its real server-rendered preview
```

Adding a template should not require shipping its raw HTML inside the mobile app.

Never make a static image a requirement or fallback for the template selector. New templates become previewable through the same secure server renderer using actual code and safe sample data; Flutter receives only safe metadata and final rendered preview documents.

---

# 56. GitHub Workflow

Do not commit directly to production main.

For the Vercel web/API repository:

```text
Zana-Sponsor/proxobalance
```

use:

```text
feature branch
↓
commits grouped by concern
↓
Vercel Preview
↓
test
↓
Pull Request
↓
merge to main
↓
production deployment
↓
production smoke test
```

Example commit groups:

```text
Add private ProxoLink renderer API
Add contact-card routes and status flow
Add private-template storage integration
Add ProxoLink database migration
Remove legacy HTML delivery
```

For Flutter, first identify the correct Flutter Git repository.

Do not assume the Vercel web repository is the Flutter repository.

The supplied ZIP is the current source reference for `ToolsScreen`.

---

# 57. Vercel Routing

Add the contact route before the generic SPA fallback.

For example:

```json
{
  "source": "/contact/:id",
  "destination": "/api/contact?id=:id"
}
```

Do not let:

```text
/contact/:id
```

fall through to `index.html`.

Do not break the existing:

```text
/form/:id
/api/*
exchange routes
SPA fallback
```

Verify route ordering.

---

# 58. Vercel Environment Variables

**Actual ProxoLink server code on PR #7 uses these distinct variables; use its live code as the final source of truth:**

```text
PROXO_SUPABASE_URL                (the Proxo Supabase project URL)
PROXO_SUPABASE_SERVICE_ROLE_KEY   (server-only sensitive credential)
PROXO_PUBLIC_BASE_URL             (canonical public contact-page origin)
PROXO_PREVIEW_SIGNING_SECRET      (server-only HMAC signing secret)
PROXO_ANALYTICS_HASH_SECRET       (if enabled by the current analytics implementation)
PROXO_TIKTOK_PIXEL_ID             (only if required for real public pages)
TELEGRAM_BOT_TOKEN                (only if server notification remains)
TELEGRAM_CHAT_ID                  (only if required)
```

The repository also contains `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` for a **separate Exchange service**. Never accidentally use Exchange credentials or an Exchange fallback for ProxoLink. Verify the names and environment targets against current code before configuration. Do not log, decrypt, paste into chat, duplicate, or overwrite secret values during a prompt-review or read-only audit.

Never expose those values in:

```text
public JS
Flutter
GitHub source
HTML response
API error
logs
```

Do not add a Vercel secret to `.env.example` as a real value.

Only document variable names.

---

# 59. Server Error Handling

Public response must never expose internal stack traces.

Use safe public errors.

Internally log:

```text
operation
card_id
safe error code
HTTP status
request id
timestamp
```

Do not log:

```text
full HTML
service key
private template source
phone numbers unnecessarily
Telegram token
authorization header
```

Reuse the existing error/security logging architecture where appropriate.

---

# 60. Recommended Error Codes

Use stable internal codes such as:

```text
card_not_found
card_inactive
card_not_ready
template_not_found
template_inactive
template_fetch_failed
template_invalid
invalid_platform_value
avatar_required
render_failed
database_error
network_error
```

Flutter maps them to Kurdish user messages.

Do not show raw PostgreSQL/Vercel errors.

---

# 61. Public Link Readiness Check

After card creation, the backend must confirm the card is actually renderable.

A simple successful database insert is not enough.

Validation should include:

```text
card exists
template metadata exists
private template can be read
required avatar rule passes
platform data validates
renderer completes
result contains expected HTML shell
```

Only then set:

```text
publish_status = ready
status = active
```

This is what the UI interprets as:

```text
بە سەرکەوتوویی دروستکرا
چالاکە
```

---

# 62. Preview UX

When the user taps:

```text
پێشبینین
```

open an in-app full-screen WebView.

Header:

```text
back/close
card name
optional refresh
```

Body:

```text
the real rendered web page
```

Loading:

```text
small Proxo spinner
```

Failure:

```text
پێشبینین نەکرایەوە
نەتوانرا کەرەستەکە پیشان بدرێت.
تکایە دووبارە هەوڵ بدەرەوە.

[ دووبارە هەوڵبدەرەوە ]
```

Do not expose an "Open With" chooser that could offer a code editor.

Do not save an HTML file to device storage for Preview.

---

# 63. Preview vs Chrome Acceptance

For the same Active card, compare:

```text
Chrome:
https://PUBLIC_DOMAIN/contact/CARD_UUID

Flutter WebView:
same renderer / same card
```

Verify:

```text
same chosen template version and visible design
same viewport
same font and approved name/bio hierarchy
same image
same buttons and gentle press effects
same animations
same balanced spacing
same responsive breakpoints
no displayed HTML/CSS/JS source text
```

The WebView must not crop the page or add unintended horizontal padding.

---

# 64. Public Contact Button Behavior

Test every platform from both:

```text
Chrome
Flutter WebView
```

Expected:

```text
WhatsApp opens WhatsApp/web fallback
Telegram opens Telegram/web fallback
Instagram opens intended profile
phone opens dialer
Viber opens Viber when available
```

If an external app is unavailable, use a safe fallback where possible.

Do not break the landing page when a deep link is unsupported.

---

# 65. Ads Integration Rules — Strong Per-Ad Isolation

For `goal = messages` or any flow using ProxoLink, the selected contact card must be validated when the ad is created.

Base relationship:

```text
pa_ads.id                 = exact advertisement
pa_ads.asset_id/card_id   = selected ProxoLink card
proxolink_cards.id        = exact contact card
```

Server/database validation:

```text
card.id = ad.asset_id/card_id
card.user_id = ad.user_id
card.status = active
card.publish_status = ready
```

Do not allow an inactive, creating, failed, or another user's card into a new advertisement.

## Do not use one shared tracked card URL for every ad

The permanent non-ad card URL remains:

```text
https://PUBLIC_DOMAIN/contact/CARD_UUID
```

This URL is for:

```text
normal card sharing
organic/direct traffic
owner preview
non-ad use
```

It must not be the authoritative tracked destination for every advertisement.

Every advertisement must receive its **own unique tracking-link record and its own unique public token**.

Recommended tracked advertising URL:

```text
https://PUBLIC_DOMAIN/a/AD_LINK_TOKEN
```

Example:

```text
Ad A:
https://PUBLIC_DOMAIN/a/K7vP2mR8qX...

Ad B:
https://PUBLIC_DOMAIN/a/N4zL9cT1wB...
```

Even if Ad A and Ad B use the exact same `CARD_UUID`, the two tracked URLs must be different.

The token must resolve server-side to exactly one advertisement-link record and therefore exactly one `pa_ads.id`.

## Strong isolation rule

The system must never identify the advertisement from:

```text
card_id alone
owner_user_id alone
phone number
WhatsApp number
template
session guess
latest ad using that card
```

The authoritative attribution chain is:

```text
AD_LINK_TOKEN
      ↓
pa_ad_contact_links.id
      ↓
exact pa_ads.id
      ↓
exact proxolink_cards.id
```

All advertisement-attributed events must be stored against that exact tracking-link context.

This guarantees that two advertisements using the same card never mix analytics.

## Do not rely on a browser session alone for ad identity

Do not use a design where:

```text
?ref=TOKEN
→ save ad identity only in cookie/session
→ redirect to shared /contact/CARD_UUID
```

as the sole source of attribution.

That can become ambiguous when the same visitor opens two different ads in different tabs or quickly moves between ads.

For production attribution, keep the exact ad-link token in the tracked route itself.

The tracked page should render directly from:

```text
/a/AD_LINK_TOKEN
```

and tracked button actions should preserve that same token:

```text
/a/AD_LINK_TOKEN/action/whatsapp
/a/AD_LINK_TOKEN/action/viber
/a/AD_LINK_TOKEN/action/telegram
```

The token is therefore explicit for every tracked request and cannot be overwritten by another tab's session.

A session ID may still be used for visitor/session analytics, but it must never replace the ad-link token as the authoritative advertisement identity.

## Keep ad-platform clicks separate

Do not mix ProxoLink contact-button analytics into:

```text
pa_ads.clicks
```

`pa_ads.clicks` remains the ad-platform metric.

ProxoLink landing-page views and contact-button clicks must use the dedicated analytics architecture defined later in this document.

If an existing ad references a card that later becomes unavailable:

```text
warn before deactivation
block deletion while a live ad depends on it
do not silently break a paid/live advertisement
```

---

# 66. Realtime Is Not Required for Basic Card Creation

The public link is dynamic and database-backed.

A card does not need a Vercel deployment event.

After a successful database/API creation:

```text
/contact/CARD_UUID
```

should work immediately.

Do not wait for:

```text
GitHub
CI
Vercel build
deployment propagation
```

for each card.

That would be the wrong architecture.

---

# 67. Database Indexes

Add only useful indexes after inspecting current usage.

Recommended:

```sql
create index ... on proxolink_cards(user_id, created_at desc);
create index ... on proxolink_cards(user_id, status, publish_status);
```

Template metadata:

```sql
unique(template_key, version)
```

Publish attempts:

```sql
(card_id, created_at desc)
```

Do not add duplicate/unnecessary indexes.

Run the Supabase performance advisor after migration.

---

# 68. Constraints

Add check constraints after verifying existing data.

Examples:

```text
status in ('active','inactive')

publish_status in ('creating','ready','failed')

template_key format is controlled

template_version > 0

platforms is JSON object

card_language in supported languages
```

Do not add a constraint that invalidates existing production rows without migrating them first.

---

# 69. Migration Safety Procedure

Before any DDL:

```text
inspect live schema
inspect row counts
inspect current policies
inspect current constraints
inspect current indexes
inspect pa_ads asset references
inspect storage policies
backup relevant rows
```

Test migration logic in a transaction when possible:

```sql
begin;
...
rollback;
```

For Storage migration, use a dry-run mode and a secure migration script.

Use `apply_migration` for real Supabase schema changes.

Do not use ad-hoc destructive SQL for production DDL.

After migration run:

```text
Supabase security advisor
Supabase performance advisor
```

---

# 70. Existing Production Data Must Survive

There are existing ProxoLink cards.

Acceptance criteria:

```text
same card UUID
same owner
same card name
same bio
same template/style
same theme
same platform data
same TikTok value
same public design
same existing ad relationship
```

The migration must not force users to recreate cards.

---

# 71. Safe Rollout Order

Use this order:

```text
1. Create private template storage and metadata
2. Upload all eight template v1 sources privately
3. Add new database columns/tables
4. Add server renderer
5. Test renderer against copied/test cards
6. Migrate avatars
7. Mark migrated cards ready
8. Add /contact/:id route
9. Test public links
10. Update Flutter to structured-data flow
11. Update WebView to URL preview
12. Update AdCreate filtering
13. Remove Telegram HTML delivery
14. Remove raw templates from Flutter
15. Confirm release APK has no template source
16. Stop reading/writing html_content
17. Clear/remove legacy html_content after verification
18. Remove old Base64 fields after migration
19. Merge/release
```

Do not reverse this order in a way that breaks existing users.

---

# 72. Testing Matrix

## Creation success

```text
choose each of 8 templates
create card
UUID returned
publish_status ready
status active
public URL opens
WebView opens
```

## Creation failure

Simulate template fetch/render failure.

Expected:

```text
card remains recoverable
publish_status failed
Retry appears
no duplicate row
no Use for Ad
```

## Retry

Fix failure and Retry.

Expected:

```text
same card.id
same public URL
status active
publish_status ready
```

## Inactive

Deactivate card.

Expected:

```text
public visitor cannot access live card
owner can authenticated-preview
AdCreate does not list it
```

## Reactivate

Expected:

```text
server validates first
same UUID
same public URL becomes live again
```

## Edit

Change:

```text
name
bio
contact number
template
theme
avatar
```

Expected:

```text
same UUID
same URL
new design/data appears immediately
no Vercel deployment
```

## Edit failure

Submit invalid proposed data.

Expected:

```text
old Active page remains valid
failed edit does not corrupt live page
```

## Preview

Compare Chrome and WebView.

Expected:

```text
pixel-consistent design
no HTML chooser
no code editor
no local HTML file
```

## Source privacy

Verify:

```text
template files cannot be downloaded publicly
release APK does not contain raw templates
proxolink_cards does not expose html_content
Telegram does not receive HTML
GitHub public directory does not contain template source
```

## Ads

Expected:

```text
only active+ready own cards are selectable
other user's card rejected
inactive card rejected
failed card rejected
```

---

# 73. UI Localization

Use Kurdish/Sorani RTL in the Flutter user interface.

Recommended state labels:

```text
Active:
چالاکە

Inactive:
ناچالاکە

Creating:
لە دروستکردندایە...

Failed:
دروستکردن سەرکەوتوو نەبوو

Retry:
دووبارە هەوڵبدەرەوە

Edit:
دەستکاریکردن

Preview:
پێشبینین

Copy Link:
کۆپی لینک

Share:
هاوبەشکردن

Activate:
چالاککردن

Deactivate:
ناچالاککردن

Delete:
سڕینەوە
```

Keep wording concise.

Do not use "Approved" for a normal successful ProxoLink card unless a future admin-approval workflow is explicitly introduced.

`Active` is the correct concept here.

---

# 74. Design Rules for Status UI

Status chips must not dominate the card.

Use:

```text
small rounded chip
same typography system
clear icon + text if useful
```

Do not use huge colored panels.

Recommended semantics:

```text
creating -> neutral/Proxo accent loading treatment
active -> calm success treatment consistent with app palette
inactive -> muted gray
failed -> danger/error treatment
```

Keep accessibility contrast.

Do not rely on color alone; always include text.

---

# 75. Card Row Layout

A clean card row can be:

```text
[avatar]  Name
          date / template

                    [status]

Preview      Use for Ad / primary contextual action

More (...) → Edit / Copy / Share / Activate-Deactivate / Delete
```

Do not crowd all actions into one horizontal row.

Preserve the existing compact Proxo visual style.

---

# 76. Creation Success UX

When creation succeeds:

```text
show a success toast / compact confirmation
return to card list
new card appears at top
status = active
```

Suggested Kurdish:

```text
کەرەستەکە بە سەرکەوتوویی دروستکرا
```

Then actions are immediately available.

The user should not need to refresh the entire app.

---

# 77. Creation Failure UX

If the row exists but publishing/render validation fails:

Return the user to a recoverable state.

Do not erase their input.

The list may show:

```text
دروستکردن سەرکەوتوو نەبوو
```

with:

```text
دووبارە هەوڵبدەرەوە
دەستکاریکردن
```

If the database insert itself never happened:

```text
do not show a phantom card
keep form values
show retry message
```

Distinguish:

```text
save failed completely
```

from:

```text
card saved but publish validation failed
```

---

# 78. Public URL Security

The UUID is a public identifier, not a secret.

Do not place private authorization logic in the UUID.

Do not expose user IDs in the path.

Do not allow arbitrary template selection by query parameter.

This must be invalid:

```text
/contact/CARD_UUID?template=other-template
```

The server reads the template key only from the trusted card row.

---

# 79. Preview Token Security

If a preview token is implemented:

```text
short expiration
card-specific
owner-specific where possible
signed server-side
not stored as a permanent secret in Flutter
```

Do not put service-role tokens in the URL.

A preview token should grant only:

```text
render this one card for preview
```

and nothing else.

---

# 80. No Raw Template API

Do not implement endpoints such as:

```text
/api/templates/dark
/api/template-source
/download-template
```

that return raw HTML.

The only public output is the fully rendered selected card page.

---

# 81. No Client-Side Template Assembly

Do not send a template plus JSON to the browser and combine them client-side.

This would expose the reusable template.

Rendering must happen server-side before the response reaches the browser.

---

# 82. HTML Minification

After correct rendering is proven, the final response may be minified to reduce readability and payload size.

You may:

```text
remove comments
collapse safe whitespace
minify CSS/JS carefully
omit source maps
```

Do not perform aggressive transformations that alter the visual design or break scripts.

Minification is an extra deterrent, not a security boundary.

---

# 83. Content Security Policy

Add a CSP that matches the real dependencies.

Do not blindly block required current template scripts.

Gradually move dependencies to controlled origins.

At minimum review:

```text
script-src
style-src
img-src
font-src
connect-src
frame-ancestors
```

If the public page must render inside the Proxo app WebView, make sure the policy does not accidentally block the intended WebView usage.

---

# 84. Public Page Headers

Recommended headers:

```text
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: limit unnecessary browser capabilities
Cache-Control: no-store initially
```

Add CSP after validating all eight templates.

Do not add a header that breaks required external/deep-link behavior without testing.

---

# 85. Flutter Code Cleanup

After migration remove obsolete code paths, including where no longer needed:

```text
buildCardHtml()
card_templates raw strings
temporary HTML file generation
LocalHtmlPreview code
loadHtmlString preview
sendHtmlDocument raw HTML delivery
legacy direct Telegram Bot API controller
htmlContent field in ProxoCard
```

Before deleting each file, search the entire Flutter codebase for references.

Do not leave dead duplicate preview implementations.

Prefer one canonical preview screen.

---

# 86. AdCreateScreen Update

Current code loads fields such as:

```text
id
name
style
color_theme
card_number
avatar_b64
```

Update it for the new schema.

Use:

```text
id
name
template_key/style compatibility
color_theme
card_number
avatar_path
status
publish_status
```

Filter:

```text
status = active
publish_status = ready
```

Only cards owned by the current user should be returned under RLS.

---

# 87. AdScreen Duplicate Update

When duplicating an ad with `asset_id`:

Do not only check that a row exists.

Validate:

```text
card exists
card belongs to the user
status active
publish_status ready
```

If not:

```text
asset_id = null
show existing friendly warning
ask user to select another card
```

---

# 88. Deactivation and Existing Ads

Before allowing deactivation:

Query ads that reference this card.

If there are active ads, present a clear warning.

Preferred product-safe behavior:

```text
prevent deactivation while a live ad uses the card
```

or require a deliberate resolution flow.

Do not let the user accidentally destroy a paid campaign's landing destination.

---

# 89. Database Update Trigger

Add an `updated_at` trigger where appropriate.

Do not rely on Flutter time for authoritative database timestamps.

Use database `now()`.

---

# 90. card_number

The current Flutter code manually queries the last `card_number` and increments it.

This is race-prone.

The table already uses a sequence for `card_number`.

Stop manually calculating the next number in Flutter.

Let PostgreSQL assign:

```text
card_number
```

through its existing sequence/default.

This prevents duplicates during concurrent creation.

---

# 91. Concurrency

Protect against:

```text
double Create tap
two devices editing same card
Retry clicked repeatedly
activation racing with deletion
```

At minimum use:

```text
idempotency key
server-side ownership check
atomic DB updates
button disabling
updated_at/version optimistic check for Edit if useful
```

---

# 92. Do Not Trust checked_btns as Security

`checked_btns` may remain temporarily for compatibility.

The authoritative active contact methods should be derived from validated:

```text
platforms
```

Do not use a boolean array as a security boundary.

Eventually normalize or remove redundant legacy fields.

---

# 93. Platform JSON Validation

Validate that:

```text
platforms is an object
keys are approved platform IDs
values are strings
lengths are limited
phone-like values are normalized
usernames are normalized
```

Reject unknown keys if the template does not support them.

---

# 94. Privacy

Do not expose all card-owner account data through the public page.

The public renderer needs only:

```text
card content
public contact actions
public avatar
public brand/template content
```

It should not expose:

```text
auth user ID
email unless intentionally placed as a contact
internal card status
error fields
publish logs
admin information
```

---

# 95. GitHub Secret Hygiene

Before final merge:

```text
scan changed files for tokens
scan for "bot" credentials
scan for SUPABASE_SERVICE_ROLE_KEY literals
scan for private template HTML accidentally committed
```

Do not place actual environment secrets in documentation.

---

# 96. Vercel Preview Testing

Before merge to main, first confirm that the connected Vercel account can access the **correct** project `proxoapp-1758/proxobalance`. A Ready preview is insufficient if the preview URL is protected by HTTP 403; configure a narrowly scoped, authorized preview-test bypass if required, without bypassing Proxo authentication, Supabase RLS or the private-template restrictions. Configure the server-only Proxo Supabase credentials through Vercel provider settings; never paste them in chat, GitHub code or logs.

Before merge to main:

Test Vercel Preview with:

```text
/contact/test-card-id
authenticated card management APIs
inactive behavior
failed behavior
preview token behavior
```

Verify no existing route broke.

Inspect build logs and runtime logs.

Do not merge if Vercel Preview is failing.

---

# 97. Production Deployment

After PR merge:

Confirm Vercel deployment is:

```text
Ready / Success
```

Then smoke-test:

```text
one existing migrated card
one newly created card
one inactive card
one failed/retried card
one WebView preview
one ad selection
```

Do not claim completion while deployment is pending.

---

# 98. Rollback Plan

Keep a reversible migration path.

Before cleanup:

```text
backup proxolink_cards
backup mapping of legacy HTML/card IDs
record template checksums
keep old columns until new renderer is verified
```

If public renderer fails after deployment:

```text
do not destroy customer card data
restore prior route/code
keep card UUIDs stable
```

---

# 99. Completion Report

At the end, provide a precise report. Distinguish a prepared migration or passed unit test from an actually applied migration, real-device check, merged PR or live production release. Label every requirement VERIFIED, FAILED or BLOCKED, include evidence and give exact owner action for each blocker.

Include:

```text
Flutter files changed
Flutter files removed
web/API files changed
GitHub branch
PR URL
merge commit
Vercel preview status
Vercel production status

Supabase migrations
new tables
altered columns
constraints
indexes
RLS policies
storage buckets
storage policies

template migration results for all 8 templates
existing card migration count
avatar migration count
legacy html_content cleanup status

security remediation
Telegram credential rotation confirmation
source privacy verification
APK template-string scan result

Chrome/WebView visual comparison
status-flow tests
Retry tests
Edit tests
Active/Inactive tests
AdCreate integration tests
```

Do not simply say:

```text
Done
```

State exactly what was implemented and exactly what was verified.

---

# 100. Final Acceptance Criteria

The feature is complete only when all of the following are true:

```text
1. User selects one of the eight templates in ToolsScreen and sees its genuine **visually rendered contact-page preview** inside the app—never a static image and never raw code displayed as text.
2. Flutter never receives or contains raw HTML template source.
3. User enters structured contact information.
4. Create produces one stable card UUID.
5. PostgreSQL assigns card_number safely.
6. Backend privately validates/renders the selected template.
7. Successful card becomes Active + Ready.
8. Public URL works immediately without GitHub/Vercel deployment.
9. Preview opens the server-rendered page in Flutter WebView.
10. WebView visually matches Chrome.
11. Raw templates are stored privately.
12. Public users cannot download private template files.
13. All eight original template identities are preserved; only the explicitly approved Section 135 typography, bio-wrapping, spacing and button-feedback refinements may differ from the legacy pixel baseline. The live selector preview and the corresponding published page match each other.
14. Failed publishing produces a recoverable Failed state.
15. Retry uses the same UUID and same link.
16. Edit uses the same UUID and same link.
17. Inactive cards are not publicly accessible.
18. Inactive/Failed cards cannot be used for new ads.
19. Active + Ready cards can be selected in AdCreate.
20. Existing ad asset relationships are preserved/migrated safely.
21. Raw HTML is no longer saved in proxolink_cards.
22. Base64 avatars are migrated to Storage.
23. Raw HTML is never sent to Telegram.
24. No Telegram/Supabase server secret exists in Flutter.
25. The previously exposed Telegram credential has been rotated/revoked.
26. No per-card HTML file is generated.
27. No per-card GitHub commit is generated.
28. No per-card Vercel deployment is generated.
29. Existing customer cards survive migration.
30. GitHub, Supabase, Flutter, and Vercel are tested together before completion.
```

Implement this as a production migration, not as a throwaway demo.
Do not redesign unrelated screens.
Do not change existing template visuals beyond the user-approved, narrowly scoped Section 135 refinements.
Do not guess when the live database/repository can be inspected.
---

# 101. Strong Per-Advertisement Tracking Architecture

The analytics system must guarantee that **data from one advertisement can never be counted as data from another advertisement**, even when multiple ads use the same ProxoLink card.

Use three distinct identities:

```text
CARD_UUID
= identifies the contact card

AD_UUID
= identifies the advertisement (`pa_ads.id`)

AD_LINK_TOKEN
= identifies one exact tracked ad→card link/version
```

Never collapse these three concepts into one field.

---

# 102. New Mapping Table: pa_ad_contact_links

Create a dedicated mapping table:

```sql
public.pa_ad_contact_links
```

Recommended schema:

```sql
id uuid primary key default gen_random_uuid(),

ad_id uuid not null
  references public.pa_ads(id)
  on delete cascade,

card_id uuid not null
  references public.proxolink_cards(id)
  on delete restrict,

owner_user_id uuid not null
  references auth.users(id)
  on delete cascade,

public_token text not null unique,

version integer not null default 1,

is_current boolean not null default true,

status text not null default 'active',

created_at timestamptz not null default now(),

deactivated_at timestamptz
```

Add a partial unique index so one ad has only one current tracking link:

```sql
create unique index ...
on public.pa_ad_contact_links(ad_id)
where is_current = true;
```

The `public_token` must be:

```text
unguessable
server-generated
unique
opaque
not sequential
not derived from card_number
not derived from public_ad_id alone
```

Flutter must never generate the authoritative tracking token.

---

# 103. Why Use a Mapping Table

Do not attach all analytics logic directly to `CARD_UUID`.

The same card may be used by:

```text
Ad A
Ad B
Ad C
```

If analytics are stored only by `card_id`, their data will mix.

The mapping table creates an exact boundary:

```text
Ad A → Link Row A → Card X
Ad B → Link Row B → Card X
Ad C → Link Row C → Card X
```

All three may use the same Card X, but they have three different link IDs and three different public tokens.

---

# 104. Tracked Ad URL

The canonical permanent card URL remains:

```text
https://PUBLIC_DOMAIN/contact/CARD_UUID
```

The tracked advertising URL must be different:

```text
https://PUBLIC_DOMAIN/a/AD_LINK_TOKEN
```

Example:

```text
Permanent card:
https://PUBLIC_DOMAIN/contact/8c7f...

Ad A:
https://PUBLIC_DOMAIN/a/pQ7xN4mK...

Ad B:
https://PUBLIC_DOMAIN/a/Y2rT8vLs...
```

Do not expose `AD_UUID` directly in the public URL.

Do not require:

```text
?ref=
?ad_id=
?card_id=
```

for the recommended production flow.

The `/a/:token` route is the authoritative tracked route.

---

# 105. Vercel Route for Tracked Ads

Add a route before the SPA fallback:

```text
GET /a/:token
```

It should resolve to a Vercel server function, for example:

```text
/api/contact-ad?token=:token
```

The server must:

```text
1. validate token format
2. load exactly one pa_ad_contact_links row
3. verify link.status = active
4. load exact pa_ads.id from that row
5. load exact card_id from that row
6. verify ad.user_id = card.user_id = owner_user_id
7. verify the ad still points to that card
8. verify card.status = active
9. verify card.publish_status = ready
10. privately load the correct template
11. render the exact same ProxoLink design
12. record the page_view under this exact tracking-link context
13. return the rendered page
```

Never guess a card or advertisement.

---

# 106. Do Not Redirect to a Shared Tracking Context

For tracked advertisement traffic, prefer rendering the page directly on:

```text
/a/AD_LINK_TOKEN
```

Do not immediately convert it into a shared URL whose only ad identity lives in a cookie.

Reason:

```text
Ad A opened in Tab 1
Ad B opened in Tab 2
```

must still preserve two independent attribution contexts.

Each tab's URL already contains the exact token, so there is no ambiguity.

A first-party session cookie may be used for session analytics, but it must not determine which advertisement owns an event.

---

# 107. New Raw Event Table

Create:

```sql
public.pa_contact_events
```

Recommended schema:

```sql
id uuid primary key default gen_random_uuid(),

ad_contact_link_id uuid not null
  references public.pa_ad_contact_links(id)
  on delete cascade,

event_type text not null,

button_type text,

session_id uuid,

visitor_hash text,

ip_address inet,

ip_hash text,

user_agent text,

device_type text,

browser text,

os text,

referrer text,

request_path text,

created_at timestamptz not null default now()
```

The authoritative advertisement and card are derived through:

```text
pa_contact_events.ad_contact_link_id
        ↓
pa_ad_contact_links.ad_id
pa_ad_contact_links.card_id
```

This normalized structure prevents event rows from containing mismatched:

```text
Ad A + Card B
```

because the event stores one authoritative `ad_contact_link_id`.

Do not accept `ad_id`, `card_id`, or `owner_user_id` from the public browser as authoritative event fields.

---

# 108. Optional Denormalized ad_id/card_id

For very large analytics workloads, `ad_id` and `card_id` may later be duplicated onto `pa_contact_events` for query performance.

If that is done:

```text
the values must be populated by trusted database/server logic
they must be derived from ad_contact_link_id
they must never be accepted from the browser
```

Prefer a database trigger or a strict composite integrity rule.

Do not allow:

```text
ad_contact_link_id = Link A
ad_id = Ad B
```

to exist.

The first implementation may remain fully normalized and query through the mapping table.

---

# 109. Controlled Event Types

Recommended:

```text
event_type:
  page_view
  button_click
```

For `button_click`, supported `button_type` values may include:

```text
whatsapp
viber
telegram
instagram
phone
email
website
tiktok
```

Use only the verified contact methods supported by the existing templates.

Do not accept arbitrary free-form event types or button names from the public client.

---

# 110. Page View Tracking

When:

```text
/a/AD_LINK_TOKEN
```

renders successfully:

```text
resolve token
↓
load exact link row
↓
validate exact ad + exact card
↓
render page
↓
insert page_view with exact ad_contact_link_id
```

Example:

```text
ad_contact_link_id = LINK_A_UUID
event_type         = page_view
button_type        = null
```

Ad A and Ad B can use the same card, but their events use different link IDs.

Therefore their page-view counts cannot mix.

---

# 111. Tracked Button URLs

The server-rendered tracked page must generate contact actions tied to the exact ad-link token.

Examples:

```text
/a/AD_LINK_TOKEN/action/whatsapp
/a/AD_LINK_TOKEN/action/viber
/a/AD_LINK_TOKEN/action/telegram
/a/AD_LINK_TOKEN/action/instagram
/a/AD_LINK_TOKEN/action/phone
/a/AD_LINK_TOKEN/action/email
/a/AD_LINK_TOKEN/action/website
/a/AD_LINK_TOKEN/action/tiktok
```

Do not use a generic action endpoint that depends on a browser cookie to determine the ad.

The token in the route identifies the exact ad-link context every time.

---

# 112. Contact Action Flow

For every tracked button:

```text
Visitor taps button
        ↓
/a/AD_LINK_TOKEN/action/BUTTON
        ↓
Vercel server resolves token
        ↓
server loads exact pa_ad_contact_links row
        ↓
server verifies exact ad + exact card
        ↓
server validates BUTTON
        ↓
server loads destination from trusted card data
        ↓
server inserts button_click using exact link id
        ↓
server redirects to WhatsApp/Viber/etc.
```

Do not accept an arbitrary destination URL from the browser.

The destination must be generated from trusted card data.

This prevents an open redirect.

---

# 113. Example: Same Card, Two Different Ads

Suppose:

```text
CARD_X
```

is used by two ads.

Mapping:

```text
LINK_A:
  ad_id   = AD_A
  card_id = CARD_X
  token   = TOKEN_A

LINK_B:
  ad_id   = AD_B
  card_id = CARD_X
  token   = TOKEN_B
```

URLs:

```text
Ad A:
https://PUBLIC_DOMAIN/a/TOKEN_A

Ad B:
https://PUBLIC_DOMAIN/a/TOKEN_B
```

Visitor from Ad A clicks WhatsApp:

```text
event.ad_contact_link_id = LINK_A
button_type = whatsapp
```

Visitor from Ad B clicks WhatsApp:

```text
event.ad_contact_link_id = LINK_B
button_type = whatsapp
```

Even though both use the same:

```text
CARD_X
WhatsApp number
template
owner
```

the event records are structurally separate.

---

# 114. Never Use card_id Alone for Ad Analytics

This query is wrong for one advertisement:

```sql
where card_id = :CARD_UUID
```

because it may combine multiple ads.

Correct ad analytics must use:

```text
pa_ads.id
```

through the mapping table.

Example:

```sql
select
  e.button_type,
  count(*) as clicks
from public.pa_contact_events e
join public.pa_ad_contact_links l
  on l.id = e.ad_contact_link_id
where l.ad_id = :AD_UUID
  and e.event_type = 'button_click'
group by e.button_type;
```

Page views:

```sql
select count(*) as page_views
from public.pa_contact_events e
join public.pa_ad_contact_links l
  on l.id = e.ad_contact_link_id
where l.ad_id = :AD_UUID
  and e.event_type = 'page_view';
```

---

# 115. Keep pa_ads.clicks Separate

The existing:

```text
pa_ads.clicks
```

must remain an advertising-platform metric.

Do not increment it for:

```text
WhatsApp
Viber
Telegram
Instagram
Phone
Email
Website
TikTok/Profile
```

ProxoLink contact interactions live in:

```text
pa_contact_events
```

only.

---

# 116. Hidden Analytics Requirement

For the current scope:

```text
record analytics in Supabase
do not display raw analytics to ordinary users
do not display IP addresses
do not display visitor lists
do not display tracking tokens
do not add a new analytics screen yet
```

The public ProxoLink page must not reveal the analytics data.

Flutter must not receive raw event rows.

If an advertiser-facing analytics screen is requested later, expose only safe aggregates through an authenticated server API.

---

# 117. RLS and Direct Access

`pa_contact_events` and internal tracking-link data must be private.

Default desired permissions:

```text
anon:
  NO SELECT raw events
  NO direct INSERT raw events
  NO UPDATE
  NO DELETE

ordinary authenticated user:
  NO direct SELECT raw events
  NO direct INSERT raw events
  NO UPDATE
  NO DELETE
```

Trusted server/service role:

```text
may resolve tracking links
may insert validated events
may run internal analytics
```

Do not let Flutter or public JavaScript insert events directly using the Supabase anon/publishable key.

All public tracking writes go through controlled Vercel endpoints.

---

# 118. Server-Observed IP

The authoritative IP must come from the trusted server request.

Do not trust:

```text
Flutter-provided IP
JavaScript-provided IP
query-parameter IP
body-field IP
```

Recommended event fields:

```text
ip_address
ip_hash
```

If raw IP is retained:

```text
restrict access
define a retention period
do not expose it to ordinary users
```

If an admin view is created later, mask the IP when full precision is unnecessary.

Do not use IP as the advertisement identity.

The ad identity always comes from `AD_LINK_TOKEN`.

---

# 119. Session ID Is Secondary Only

Use a random first-party:

```text
session_id
```

for analytics such as:

```text
repeat clicks
sessions
unique-ish visitors
```

But:

```text
session_id must never determine ad_id
```

This matters when one person opens:

```text
Ad A
Ad B
```

in different tabs.

Each page's `/a/TOKEN` route remains the authoritative attribution context.

---

# 120. Preview Must Produce Zero Ad Analytics

The owner's Preview flow must continue to use the card preview path/context, not a production ad tracking link.

Preview must not:

```text
insert page_view into pa_contact_events
insert button_click into pa_contact_events
increment any ad contact counter
fire production ad-conversion analytics
```

The owner can test the page without contaminating real campaign data.

---

# 121. Organic Traffic Is Separate

The permanent URL:

```text
/contact/CARD_UUID
```

is not automatically attributed to an ad.

If someone opens it directly:

```text
do not guess an advertisement
do not use the latest ad
do not use an active ad that happens to share the card
```

For the current scope:

```text
pa_contact_events contains only advertisement-attributed traffic
```

If organic analytics are needed later, create a separate explicit organic analytics model.

---

# 122. Raw Events Are the Source of Truth

Do not store only counters such as:

```text
whatsapp_clicks = 80
viber_clicks = 20
```

as the only record.

Keep individual event rows.

This makes it possible to calculate:

```text
raw clicks
sessions
unique-ish visitors
time trends
device/browser breakdown
per-button breakdown
fraud/repeat patterns
```

without losing historical detail.

---

# 123. Optional Aggregate Stats Table

If performance later requires it, add:

```sql
public.pa_ad_contact_stats
```

Possible columns:

```sql
ad_id uuid primary key
  references public.pa_ads(id)
  on delete cascade,

page_views bigint not null default 0,
total_button_clicks bigint not null default 0,

whatsapp_clicks bigint not null default 0,
viber_clicks bigint not null default 0,
telegram_clicks bigint not null default 0,
instagram_clicks bigint not null default 0,
phone_clicks bigint not null default 0,
email_clicks bigint not null default 0,
website_clicks bigint not null default 0,
tiktok_clicks bigint not null default 0,

updated_at timestamptz not null default now()
```

This table is optional.

If used:

```text
pa_contact_events = source of truth
pa_ad_contact_stats = derived/cache only
```

Never let aggregate counters become the only copy of the data.

---

# 124. Editing an Ad or Changing Its Card

Do not rewrite historical attribution.

If an advertisement's ProxoLink card changes after tracked traffic already exists:

```text
do not mutate the old tracking-link row in a way that changes history
```

Instead:

```text
1. mark old pa_ad_contact_links row as not current
2. preserve the old row for historical events
3. create a new versioned link row
4. generate a new public token
5. make the new row current
```

Historical events stay attached to the old link.

New traffic uses the new link.

Both still belong to the same `pa_ads.id` if it is truly the same advertisement record.

This preserves exact history.

---

# 125. Deactivate / Delete Behavior with Tracking

When a card or ad is deactivated:

```text
do not delete historical event rows
do not reassign historical events
do not reuse its old public token for another ad
```

A deactivated tracking link should stop accepting new tracked traffic.

Old analytics remain queryable internally.

Never recycle tracking tokens.

---

# 126. Token Generation Timing

The tracking-link row should be created only after:

```text
pa_ads.id exists
selected card has been validated
ad ownership has been validated
```

Recommended flow:

```text
Create ad
   ↓
pa_ads row exists
   ↓
validate card
   ↓
create pa_ad_contact_links row
   ↓
generate unique public_token
   ↓
return tracked URL
```

Do not generate the token before the exact `pa_ads.id` is known.

---

# 127. Existing ProxoLink Ads Migration

Before adding tracking links to existing ads:

```text
inspect all pa_ads rows that use ProxoLink
verify their current asset_id/card_id
verify ownership
verify card still exists
```

For every valid existing ad:

```text
create one current pa_ad_contact_links row
generate one unique token
preserve pa_ads.id
preserve card UUID
do not merge two ads into one tracking link
```

If two existing ads use the same card:

```text
they still receive two different link rows
they still receive two different tokens
```

---

# 128. Analytics Indexes

Recommended indexes after inspecting the live schema:

```sql
create index ...
on public.pa_ad_contact_links(ad_id, is_current);

create index ...
on public.pa_ad_contact_links(card_id, created_at desc);

create unique index ...
on public.pa_ad_contact_links(public_token);

create index ...
on public.pa_contact_events(ad_contact_link_id, created_at desc);

create index ...
on public.pa_contact_events(
  ad_contact_link_id,
  event_type,
  button_type,
  created_at desc
);
```

Do not create redundant indexes.

Run Supabase security and performance advisors after applying the migration.

---

# 129. Analytics Security Tests

The implementation must pass all of these tests:

```text
1. Ad A and Ad B use the same CARD_UUID.
2. Ad A and Ad B have different pa_ad_contact_links rows.
3. Ad A and Ad B have different public tokens.
4. Page view from Ad A creates an event only under Link A.
5. Page view from Ad B creates an event only under Link B.
6. WhatsApp click from Ad A creates an event only under Link A.
7. WhatsApp click from Ad B creates an event only under Link B.
8. Viber click from Ad A creates an event only under Link A.
9. Telegram click from Ad B creates an event only under Link B.
10. Opening Ad A and Ad B in separate browser tabs does not mix attribution.
11. Changing a cookie/session does not change the ad identity of an /a/TOKEN request.
12. Invalid token creates no attributed event.
13. A token never resolves to more than one ad.
14. A token for one card cannot be used to attribute another card.
15. Organic /contact/CARD_UUID does not get assigned to an ad.
16. Preview creates zero production ad events.
17. Anonymous users cannot SELECT pa_contact_events.
18. Ordinary authenticated users cannot directly INSERT fake events.
19. Client-provided fake IP is ignored.
20. Contact-action cannot redirect to an arbitrary URL.
21. pa_ads.clicks is not changed by ProxoLink button tracking.
22. Historical events remain attached to the original link after an ad/card edit.
23. Old tokens are never recycled.
24. Two ads sharing the same phone/WhatsApp destination never merge analytics.
```

---

# 130. Analytics Retention and Privacy

Before production launch, define retention for visitor-level data.

Recommended direction:

```text
keep aggregate statistics longer
keep raw visitor/IP detail only as long as operationally necessary
```

Do not silently keep raw IP data forever.

State the chosen retention behavior in the completion report.

---

# 131. Completion Report — Tracking

The final implementation report must additionally include:

```text
pa_ad_contact_links migration
pa_contact_events migration
token generation implementation
tracked /a/:token route
tracked action routes
RLS/policy changes
page-view tracking
button-click tracking
IP handling
session handling
Preview suppression
organic-traffic behavior
same-card multi-ad isolation test
cross-tab isolation test
invalid-token test
direct-Supabase-access test
open-redirect test
historical attribution test
retention decision
```

Do not claim tracking is complete unless the multi-ad isolation tests pass.

---

# 132. Additional Final Acceptance Criteria — Zero Mixing Between Ads

In addition to the original acceptance criteria, the feature is not complete until all of these are true:

```text
31. Every tracked advertisement has one exact internal pa_ads.id.
32. Every tracked ad has its own pa_ad_contact_links row.
33. Every current tracked ad has its own unique public token.
34. The permanent card URL remains /contact/CARD_UUID.
35. The tracked ad URL uses /a/AD_LINK_TOKEN.
36. Two ads using the same card always have different tracked URLs.
37. The tracked page resolves the token server-side before rendering.
38. The tracked page never guesses an ad from card_id.
39. Every page_view is stored with one exact ad_contact_link_id.
40. Every WhatsApp click is stored with one exact ad_contact_link_id.
41. Every Viber click is stored with one exact ad_contact_link_id.
42. Every Telegram click is stored with one exact ad_contact_link_id.
43. Every Instagram click is stored with one exact ad_contact_link_id.
44. Every Phone click is stored with one exact ad_contact_link_id.
45. Every Email click is stored with one exact ad_contact_link_id.
46. Every Website click is stored with one exact ad_contact_link_id.
47. Every TikTok/profile click is stored with one exact ad_contact_link_id.
48. Ad A and Ad B can use the same card without sharing event rows.
49. Ad identity does not depend on a shared browser session/cookie.
50. Cross-tab use of two different ad links does not mix attribution.
51. pa_ads.clicks remains separate from ProxoLink button analytics.
52. Raw analytics remain hidden from ordinary users.
53. Anonymous visitors cannot query raw events.
54. Ordinary authenticated users cannot insert raw events directly.
55. Authoritative IP is observed server-side.
56. Preview generates zero production ad analytics.
57. Organic card traffic is never assigned to an arbitrary ad.
58. Tracked button routes cannot act as open redirects.
59. Historical events are never rewritten when the card/ad is edited.
60. Old tracking tokens are never reused for another ad.
61. Existing ads that share one card are migrated into separate tracking-link rows.
62. Raw pa_contact_events rows remain the analytics source of truth.
63. Optional aggregate counters are derived/cache data only.
64. All analytics for one ad are resolved through its exact pa_ads.id / tracking-link mapping.
```

---

# 133. MANDATORY FINAL OVERRIDE — Genuine Live Template Previews Inside Flutter

This section takes priority over every earlier historical statement or instruction referring to local preview images, cached style screenshots, sample `*_v1.webp` assets, image-based catalog tiles or static preview fallbacks. **The user explicitly rejects image previews in the template selector.** They want the templates themselves, rendered from their actual code and displayed inside the application.

## 133.1. What the user must see

When a user opens ProxoLink's template-selection section in the Flutter Tools screen, the displayed preview for the chosen Dark, Light, Classic, Pill, Card, Neon, Zoom or Banner template must be the **actual visual appearance of the rendered HTML/CSS/JavaScript page, not code displayed as text**. Keep the current template names, order and existing Proxo visual language around the selector. The preview's text, avatar, contact buttons, typography, colors, gradients, responsive layout, shadows, animations and spacing must be those of the real template, not a reproduction drawn using Flutter widgets. Never show raw source, code blocks, an editor, a JSON document or an HTML download in the user-facing preview.

Never display `assets/styles/dark_v1.webp`, `light_v1.webp`, `classic_v1.webp`, `pill_v1.webp`, `card_v1.webp`, `neon_v1.webp`, `zoom_v1.webp`, `banner_v1.webp`, or another static screenshot as a template preview. Do not replace them with server-generated screenshot files: the preview must show the visually rendered live page in a WebView and must never show HTML/CSS/JS as code text.

## 133.2. Secure preview architecture

Use a dedicated, narrowly scoped **server-rendered sample-template preview route**, for example `GET /api/contact-template-preview?template_key=dark&version=1`, or another clean route compatible with the existing Vercel project. The route must use an exact allowlist/active template catalog, validate the requested template key/version, fetch only the selected version from the **private** Supabase `proxolink-templates` bucket and render it with controlled, deterministic sample content. Do not create a fake or real `proxolink_cards` database row merely to preview a template. Do not require a GitHub commit or Vercel redeployment per preview. Apply appropriate access control or rate limiting to protect the preview endpoint, without leaking private source, template bucket paths, credentials or the full reusable template library.

The template renderer should be shared with `/contact/:card_uuid` so selector previews, owner previews and real public pages have the same markup-generation rules and visual appearance. Return only the final rendered sample document and required publicly safe assets, so the WebView displays its **visual result**. Never offer the markup as a source-code preview, editable file or downloadable attachment. Do **not** provide the reusable raw template file, source URL, entire catalog source or private signed Storage URL. A browser/WebView necessarily receives inspectable final HTML/CSS for the selected rendered page; never promise that browser-delivered markup is impossible to inspect.

## 133.3. Safe demonstration data

Provide realistic, deterministic sample content for each template: a sample name and bio, safe illustrative profile image where appropriate, a supported TikTok handle and sample WhatsApp/Telegram/Instagram/Viber/phone labels and values where needed for visual fidelity. Use values that will never route a user to an actual unrelated customer's account or telephone number. Demo content must be **server-controlled**, not arbitrary user-provided executable HTML/JavaScript. Render the chosen color theme, language and platform configuration safely if supported.

In template-selection preview mode, contact buttons may visually react exactly as in the original design but must **not actually call, message, dial, redirect to third-party profiles or charge anything**. Disable TikTok Pixel, advertising events, conversion tracking and any write to `pa_contact_events` or other analytics. An owner opening the selector, tapping a sample button or repeatedly switching styles must generate **zero** advertisement-attributed events.

## 133.4. Flutter presentation and performance

Use `webview_flutter` or an equivalent established embedded WebView to load the **rendered sample URL** with `loadRequest(...)`, never `loadHtmlString(...)` with embedded local template source. Preserve proper portrait aspect ratio and cropping inside the existing template selector without stretching, page overflow or unwanted horizontal margins. Support small phones, large phones, tablets, landscape orientations, safe areas, RTL Kurdish/Arabic and relevant LTR text. The preview must use the exact approved web font and the actual template's assets.

Do not eagerly initialize eight full WebViews at once. Prefer one live WebView for the currently highlighted template with instant transition, or lazy/virtualized previews for visible entries, and use a lightweight Proxo loading state. Switching to another template must display its real rendered code, not an image. Maintain selection and form state while switching or navigating. If a preview request fails, show a friendly localized failure state with Retry while preserving the selected template; **do not silently fall back to the old WebP/PNG preview assets**.

The template selector must not need a customer UUID. A separate real customer-card Preview still uses `/contact/CARD_UUID` or a verified short-lived owner preview token and still matches the real Chrome page.

## 133.5. Strict visual preservation and testing

All eight preview renders must retain their original design identities, include the approved Section 135 refinements, and work with versioned private template sources. If refinement changes the v1 checksum, register an explicitly versioned private template revision and pin published cards appropriately; do not silently change existing card versions. Compare each genuine in-app visual preview with the real server-rendered page and historical baseline at, at least, 320, 375, 393, 430 and 768 CSS-pixel widths. Document approved changes separately from accidental layout regressions. Check fonts, avatars, button arrangement, gradients, icon shapes, page height, shadows, animations, RTL direction, contact platform order, theme selection and responsiveness. Verify JavaScript animations work in the WebView. Test repeated rapid style changes and low-memory devices to ensure WebViews are disposed/reused correctly.

Acceptance is not achieved by showing the right screenshot. **For each of the eight styles, inspect the live WebView and confirm that it displays the actual visually rendered page produced from the privately stored template source, not a code viewer and not an image.** Verify that no static asset is used for preview rendering, no raw private template is bundled in the release APK/IPA, no private template object can be fetched by an ordinary app user and no selector preview contributes any ad analytics.

## 133.6. Update the implementation report

Explicitly report which Flutter selector widgets were changed, the final live preview endpoint and security strategy, performance/lazy-loading behavior, the eight per-style visual test results, selector and public-page visual comparisons, preview tracking isolation, and the scan proving `assets/styles/*_v1.webp` are no longer referenced by the selector. Report any unverified test honestly.

**Final acceptance:** all eight template options are genuinely displayed as *visually rendered pages inside the Flutter app* through the same protected server-rendering pipeline as their corresponding actual ProxoLink pages. Static preview images are not an acceptable substitute.

---

# 134. MANDATORY — Unified ProxoLink Flutter UI/UX (Create Ad and Ad Details Reference)

This section takes priority over older instructions to preserve the previous ProxoLink Flutter interface unchanged. **The user authorizes refinement of the ProxoLink Flutter UI, not replacement of the eight HTML contact-page template identities.** Use the current running `AdCreateScreen` (دروستکردنی ڕیکلام) and `AdDetails` (وردەکاری ڕیکلام) as the visual reference; inspect their real component definitions, theme values and default typography before editing.

Apply the same established system to the ProxoLink entry in Tools, template catalog and selection, embedded live preview container, create/edit contact form, page list, status chips, action controls, loading/empty/error states and full-page owner preview. Match the actual reference component proportions rather than inventing unrelated fixed dimensions.

Required style:

```text
white or existing restrained off-white app surface
clean white rounded cards with existing soft-shadow treatment
same card radius, natural component height, padding and sectional rhythm
Proxo blue headings and selected controls
black primary text, appropriate subdued gray secondary labels
same rounded text fields, compact chips, dropdowns and buttons
consistent icon sizes and natural-sized visual hierarchy
existing inherited Rabar typography at normal w400 for ordinary text
no arbitrary Kurdish font-size multipliers, excessive bold or bloated controls
correct Sorani/Arabic RTL; natural English/numbers/identifiers LTR
balanced text/number/icon spacing, keyboard-safe and responsive layout
```

The template-selection component must show **the visually rendered live template inside WebView**, not the `assets/styles` images, an HTML editor or a code block. Use on-demand/lazy loading; preserve selection and form state when switching templates. Match the surrounding Flutter chrome to Create Ad/Ad Details, but do not force an HTML template's internal unique palette or composition to look like a Flutter ad card.

Validate long names and labels, text scaling, 320–768 dp layouts, common phone sizes, tablets, landscape, RTL/LTR content, safe areas, keyboard overlap and loading/error states. Do not introduce unrelated changes to other sections or break their navigation and Supabase integrations.

---

# 135. MANDATORY — Targeted Improvements Inside All Eight Original Contact-Page Templates

**Explicit design exception:** The user has approved the following narrow improvements within Dark, Light, Classic, Pill, Card, Neon, Zoom and Banner. They override older blanket instructions prohibiting *any* visible difference, but do not authorize a broad template redesign. They must be applied consistently to both selector previews and actual customer pages using the same appropriately versioned private template sources.

## 135.1. Profile name and regular typography

Make the **profile name only slightly more prominent** than the bio and other regular text. Keep it tasteful, naturally sized and legible, not oversized or excessively bold. Preserve each template's original type family and identity; use the approved Rabar font behavior for Kurdish/Arabic and the established web font for relevant Latin text. Keep ordinary bio, labels and contact-button text at normal weight and natural sizes; avoid manually enlarging Kurdish text or changing every heading to a heavy font. Maintain correct Sorani/Arabic RTL and natural Latin/numeric LTR, including mixed-language content.

## 135.2. Bio wrapping and visually balanced line lengths

Long bios must flow naturally, with balanced line lengths and an intentional text measure; avoid a disproportionately long line followed by a very short orphan line containing only two or three words **where feasible**. Prefer supported CSS such as `text-wrap: balance` together with an appropriate responsive `max-width`, natural `line-height`, sensible word breaking and a tested fallback on Android/iOS WebViews that lack the property. Do not arbitrarily insert hard-coded line breaks, change the customer's wording, stretch word spacing, clip, truncate or conceal the bio. Arbitrary bio lengths cannot guarantee perfectly equal lines; prioritize readable and naturally balanced wrapping over artificial formatting. Test short, medium, multi-line, very long and mixed-script bios at each supported viewport.

## 135.3. Spacing, alignment and proportions

Balance gaps among the avatar, profile name, bio, TikTok identifier, contact buttons and other template sections. Keep horizontal/vertical padding, line height, row rhythm, icon/text separation, alignment and button spacing consistent within each template. Avoid both oversized empty gaps and cramped multi-line content. Ensure no text, button, footer or decorative layer overlaps or overflows on small or large screens. Preserve all eight original backgrounds, gradients, icon families, layouts, footer semantics and contact-button order unless a targeted adjustment is required for these specific spacing fixes.

## 135.4. Soft, responsive button-press behavior

Make contact buttons feel soft and naturally responsive on touch-down and release. Where compatible with the original style, use a subtle active-state scale, shadow/highlight adjustment and brief smooth transition—never large movement, harsh effects, extra delay or an entirely different button design. Preserve each template's original button shape, palette, icon, label, focus accessibility and functional deep link. Honor reduced-motion preferences where supported. On selector previews, buttons may animate visually but **must never actually call, message, dial, leave the app, write analytics or open third-party accounts**. On real published pages, preserve the intended, tested contact actions and exact-ad event attribution.

## 135.5. Change control and visual comparison

Capture the original design baseline for each template. Make only the four types of approved changes above; if their CSS/markup changes, use proper template versioning and keep existing cards pinned safely until compatibility and cutover are verified. For every style, compare the final rendered page with the Flutter WebView visual preview, and separately compare both with the legacy design. Label the intentional name/bio/spacing/press deltas as approved; treat any other color, layout, font, icon, gradient, platform or behavior difference as a defect. Do **not** use an old strict pixel-diff pass as evidence that these new refinements were applied. Provide representative before/after evidence without exposing private reusable source files.

---

# 136. MANDATORY — Visual Preview Only; No Source-Code UI or Private Template Disclosure

The user's request is **not** to view source code. It is to view the original page itself, fully rendered and visible inside the mobile app. This distinction is mandatory in all UI copy, implementation descriptions, demonstrations and tests.

```text
WHAT THE USER SEES:
A working visual contact-page preview showing sample avatar, profile name,
properly wrapped bio, contact buttons, original colors, fonts and animations.

WHAT THE USER MUST NOT SEE:
HTML/CSS/JavaScript printed as text; raw template files; a code editor;
JSON or HTML response shown in the UI; syntax highlighting; source-download
buttons; a local HTML file chooser; screenshots substituted for live previews.
```

The server privately reads the one approved reusable template/version, applies strict validation and sanitization, and returns the **final rendered page document** to the Flutter WebView. Flutter navigates to that page and displays it visually. Flutter must never bundle the reusable template files, fetch private Storage objects, receive all eight raw source files or store generated HTML in `proxolink_cards`. Public visitors may inspect browser-delivered HTML/CSS for the **one final page they receive**; no system can make rendered browser markup literally uninspectable. The security boundary is the reusable source library, other templates, internal storage paths, server-side renderer and all credentials. Do not exaggerate the security guarantee or mistake standard WebView page loading for exposing a source-code interface.

A successful acceptance test must demonstrate a visible live page for all eight templates, an absent source-code UI, no static preview image substitution, private Storage access denied to unauthorized callers and a release APK/IPA without raw reusable templates or embedded server secrets.

---

# 137. MANDATORY — Finish the Existing PR; Resolve Real Blockers Without Inventing Success

The previous coding-agent reports described extensive work in draft PR #7: private rendering, eight live visual previews, Proxo UI integration, profile-image migration preparation, exact-ad tracking, tests and successful CI builds. **These are reported historical results, not current independent verification.** The most recent agent reported 21 existing customer cards, 27 advertisements, 16 ad-to-card references and 19 verified avatars; verify the live counts again and preserve all actual records and relationships. Inspect the exact current GitHub branch, changed files, CI jobs, report, Supabase database and Vercel deployment before doing further work. Reuse correct implementations; fix code defects and omissions rather than starting over or producing another plan.

Investigate the specific outstanding requirements previously reported:

```text
Vercel project access: proxoapp-1758/proxobalance
Proxo Supabase server-only service-role configuration in Vercel
403 responses from protected Vercel Preview, including authorized CI access
GitHub Actions variable: PROXO_NATIVE_ANON_KEY
GitHub Actions secrets: PROXO_NATIVE_TEST_EMAIL
GitHub Actions secrets: PROXO_NATIVE_TEST_PASSWORD
GitHub Actions secrets: PROXO_NATIVE_VERCEL_BYPASS
real Android native WebView verification for all eight live visual previews
external contact-app launches and supported fallbacks
iOS runtime/WebView verification where an eligible environment is available
historically compromised Telegram credential rotation via authorized BotFather access
staged customer cutover, retained legacy data and production deployment gates
```

Never ask for a Supabase service-role key, account password, Vercel bypass or Telegram token in chat or commit those values to GitHub, `.env.example`, APK, web assets, telemetry or logs. Ask the owner to enter each secret directly into **the correct provider's protected settings** or use an authorized dashboard workflow. A preview protection bypass may only authorize access to the Vercel Preview for the agreed CI/test workflow; it must not bypass application login, Supabase RLS, private template permissions or card ownership checks. Keep the Proxo Supabase project separate from any unrelated Exchange Supabase configuration.

Do not repeatedly retry denied tools, invent permissions or claim that device/WebView verification occurred because widget tests, screenshots, Chrome checks, a CI build or a Ready Vercel Preview passed. If access is missing, perform all other independent work, then identify the exact blocked item, responsible party, provider UI path and necessary confirmation. Clearly distinguish completed code, validated tests, an unapplied migration, staged data, a merged PR and a live production release.

Respect the owner's prior explicit release instructions. Until the owner separately approves each applicable gate, **do not** cut over live customers, delete legacy `html_content`/Base64 data, merge PR #7 to `main` or promote the changes to Production. Maintain secure backups and a rollback path.

---

# 138. MANDATORY — Final Acceptance, Evidence Matrix and Owner Handoff

Do not end the task with another proposal or a generic claim of completion. Review **every requirement in Sections 0–144** after implementation and publish a concise, auditable matrix with one of three statuses for each item:

```text
VERIFIED — actually implemented and proved in the specified environment
FAILED   — tested and demonstrably not working; fix and retest
BLOCKED  — cannot finish without a clearly identified permission,
           provider configuration, real device, credential rotation or
           separately approved production operation
```

At minimum, supply evidence for: the eight visually rendered (not code-text or image-based) selector previews; Flutter UI match to Create Ad/Ad Details; all approved name/bio/spacing/button refinements; native Android WebView behavior; correct external contact actions; owner-only Preview; public Active/Inactive/Failed flows; UUID-stable Create/Edit/Retry; private template access denial; safe avatar delivery and verified migration; `AdCreate`/`AdScreen` integration; zero analytics for preview/organic traffic; exact per-ad tracking isolation; secrets and APK privacy scans; CI/build results; current PR/preview/production status; complete customer/ad preservation; and pending iOS, Telegram and cleanup tasks.

For approved template refinements, document intentional visual differences from legacy baselines separately from regressions. Native-WebView acceptance requires a **running device or supported emulator with genuine platform WebView rendering**; Flutter widget screenshots, static image comparisons and Chrome-only rendering do not establish it. Do not call any item verified without concrete test evidence.

Provide the exact file list, relevant commits/PR URL, migrations **applied versus merely committed**, service configuration completed versus still needed, device coverage, Vercel Preview/Production status, verification artifacts and safe rollback instructions. If any owner action is needed, provide **short, exact and safe provider-setting steps**; never request actual secret values in chat. Customer cutover, merge, production promotion and destructive legacy cleanup remain explicitly separate approval decisions.

**FINAL SUCCESS CONDITION:** All eight original ProxoLink contact pages are visually previewable inside Flutter, without image substitutes or a source-code UI; ProxoLink's surrounding Flutter components match Create Ad/Ad Details; the approved typography/bio/spacing/button refinements work without altering each template's identity; backend and exact-ad tracking remain secure; existing customer data is preserved; and all required deployment and native-runtime gates are truly verified or honestly marked BLOCKED pending owner action.

---

# 139. V5 LIVE GITHUB INSPECTION — Authoritative Current Repository Structure

This section records an actual read-only GitHub connector inspection on **4 October 2026**, not a claim that Vercel or the production app has been independently retested. Reinspect if PR #7 or `main` changes after this snapshot.

```text
GitHub repository: Zana-Sponsor/proxobalance
Main/default branch: main
Flutter project inside same repository: proxo_app/
Vercel web root: repository root
Backend code: api/
Active feature branch: feat/proxolink-private-renderer-migration
Draft PR: https://github.com/Zana-Sponsor/proxobalance/pull/7
PR state at inspection: open, Draft, unmerged
PR inspected head SHA: bb5772939fa74cd08e8177b99354a8695acd6290
PR changes at inspection: 72 files, 39 commits
Successful GitHub Verify ProxoLink workflow at inspected head:
https://github.com/Zana-Sponsor/proxobalance/actions/runs/37215966426
```

**Correct the original V2 baseline:** there is no need to search for a second Flutter repository or assume the web GitHub repository lacks Flutter source. `proxo_app/` is already part of `Zana-Sponsor/proxobalance`. Treat `proxo_app/` and the root web/API code as different build/deployment targets in the **same** Git repository.

Inspect the actual changed files before editing. In particular:

```text
proxo_app/lib/screens/tools_screen.dart
proxo_app/lib/screens/proxo_cards_list_screen.dart
proxo_app/lib/screens/card_webview_screen.dart
proxo_app/lib/widgets/proxolink_preview.dart
proxo_app/lib/services/proxolink_service.dart
proxo_app/lib/models/proxo_card.dart
proxo_app/lib/models/proxolink_template_meta.dart
proxo_app/lib/screens/ad_screen.dart
proxo_app/lib/screens/ad_create_screen.dart
proxo_app/integration_test/proxolink_live_test.dart
proxo_app/integration_test/proxolink_native_probe.dart
api/proxolink.js
api/_lib/proxolink.js
api/_lib/proxolink-preview.js
api/_lib/proxolink-track.js
api/_lib/proxolink-handlers/
vercel.json
.github/workflows/proxolink-verify.yml
.github/workflows/proxolink-native-build.yml
scripts/run-proxolink-native.mjs
scripts/sql/proxolink_verified_cutover.sql
docs/PROXOLINK_IMPLEMENTATION_REPORT.md
docs/PROXOLINK_PREVIEW_VERIFICATION_SETUP.md
```

The latest inspected `api/proxolink.js` intentionally consolidates ProxoLink into **one top-level Vercel serverless function**, with internal handler modules, to remain within the project's Vercel Hobby function limit. **Do not create many separate top-level `api/*.js` functions simply because an older section suggests standalone endpoints.** Use the existing consolidated dispatcher and verified `vercel.json` rewrites unless a justified tested change is necessary.

The current Vercel rewrite contract observed on the feature branch includes:

```text
/contact-preview              -> /api/proxolink?op=template-preview
/api/contact-templates        -> /api/proxolink?op=templates
/api/contact-cards            -> /api/proxolink?op=cards
/api/contact-card-action      -> /api/proxolink?op=card-action
/api/contact-preview-token    -> /api/proxolink?op=preview-token
/api/contact-ad-links         -> /api/proxolink?op=ad-links
/contact/:id/avatar           -> /api/proxolink?op=avatar&id=:id
/contact/:id                  -> /api/proxolink?op=contact&id=:id
/a/:token/avatar              -> /api/proxolink?op=avatar&token=:token
/a/:token/action/:action      -> /api/proxolink?op=ad&token=:token&action=:action
/a/:token                     -> /api/proxolink?op=ad&token=:token
```

Do not replace these working route contracts with obsolete example file paths, generic catch-all routes or per-customer static files. Keep the existing Exchange, form and SPA routes working.

# 140. V5 PRODUCT CONTRACT — Fully Automatic Customer-Owned Contact Pages

**This is the primary owner-requested outcome.** Each ordinary authenticated user manages **their own** contact-page records in the app; no manual admin step, template-file creation or developer deployment is needed per customer.

Required end-to-end user journey:

```text
Open Proxo -> ProxoLink / Tools
    -> visually explore all eight server-rendered styles
    -> select one template + supported theme and language
    -> enter own profile name, image, bio, TikTok and chosen contact methods
    -> tap Create once
    -> validate and securely store structured information
    -> backend privately renders/checks the selected template
    -> issue one stable card UUID and deterministic public path
    -> mark Active + Ready only when the page is actually renderable
    -> immediately view /contact/<same-card-uuid> in a real browser/WebView
    -> Copy Link / Share / Use for Ad when permitted
    -> Edit profile, avatar, bio, buttons, theme or template when desired
    -> verify the SAME card UUID and public URL still work with updated data
    -> allow Active/Inactive, Failed/Retry and dependency-safe Delete
```

Every save/update must be owner-authorized, validated and idempotent where appropriate. The client sends structured data, never reusable template source or an HTML file. Keep the current published card available if a proposed edit fails. Support network errors, slow loads and recovery without duplicate cards, false success, lost entered values or broken older advertisements. Use the existing Flutter screens/services as the integration target, not a disconnected demo page.

The **publicly usable** `/contact/<CARD_UUID>` page is separate from a short-lived template-selection **demo** and an owner-only preview. The demo never creates a customer card or real contact actions. Owner previews may show an inactive card under a signed, purpose-bound capability. A real published card must respect Active + Ready status and render the actual customer's latest validated information.

**Acceptance requires an authorized end-to-end write-flow test** (prefer an isolated staging project or explicitly approved disposable fixture) proving create, same-UUID edit, public rendering, avatar display, sharing, activation, deactivation, failed publish/retry and ad-selection checks. Successful unit tests or API files alone do not satisfy the owner's goal. Preserve the existing 21 production cards, 27 ads and all true current relations; re-check counts before and after any authorized migration.

# 141. V5 VISUAL PREVIEW AND APPROVED UI REFINEMENTS — What Must Actually Be Visible

The inspected Flutter `ProxoLinkPreview` widget already uses `WebViewController.loadRequest`, JavaScript-enabled WebView rendering, allowed-origin checks, a 45-second watchdog and a visible Retry state. The inspected backend `contact-templates.js` returns a short-lived signed preview path and renders a selected private template with controlled sample data. Reuse this architecture and correct defects rather than replacing it with Flutter-drawn lookalikes, screenshot images, a code viewer or local `loadHtmlString` template assembly.

Only **the final visible contact page** should appear in the app. The reusable raw HTML/CSS/JS library, private Storage objects and renderer internals must not be shipped in Flutter or exposed as template-download endpoints. The final selected page's browser-delivered markup is technically inspectable; do not make an impossible claim that no markup is delivered to WebView.

The surrounding **Flutter ProxoLink UI** must reuse the existing Create Ad / Ad Details design and actual shared `AdUi`, `AdFormSection`, `AdChoice` and inherited Rabar styles. The eight **HTML page templates** retain their individual colors, layouts and identities. Only the user's expressly requested narrow refinements are permitted inside their rendered versions:

```text
- profile name only slightly more prominent than ordinary text
- normal, consistent ordinary typography without forced Kurdish size bumps
- bio wraps naturally and as evenly as practical, including long Sorani text
- balanced spaces between profile image, name, bio, contact controls and sections
- soft, responsive and subtle button press/release feedback
- no truncation, overflow, unintended word changes, heavy redesign or lost actions
```

**Inspect the current private template versions before claiming these refinements are present.** The repository implementation report states that the latest security/reliability re-audit did **not** modify the original HTML templates; historical pixel-identical comparisons alone do **not** prove that the later requested bio/name/spacing/button refinements were implemented. Where genuinely missing, implement the approved adjustments in a correctly versioned private template revision and test both selector previews and customer pages without silently modifying existing pinned versions. Never convert a cosmetic improvement into an unauthorized bulk customer cutover.

For the actual selector, use on-demand/lazy WebView loading (not eight full WebViews initialized simultaneously), retain selection/form state, disable demo contact launches and all analytics, and show a visible Retry error instead of falling back to `assets/styles/` images. Test all eight styles and the approved design changes in a **real** Android platform WebView, not only Flutter widget screenshots or desktop Chrome.

# 142. V5 SECURE SERVER CONFIGURATION — Actual Variable Names and Access Boundaries

The inspected ProxoLink backend uses **only** the Proxo-specific server namespace for privileged data access:

```text
PROXO_SUPABASE_URL
PROXO_SUPABASE_SERVICE_ROLE_KEY
PROXO_PUBLIC_BASE_URL
PROXO_PREVIEW_SIGNING_SECRET
PROXO_ANALYTICS_HASH_SECRET (if required by current runtime)
PROXO_TIKTOK_PIXEL_ID (only if enabled by requirements)
```

The existing `.env.example` also documents separate **Exchange** variables `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`; these are **not** safe aliases or fallbacks for ProxoLink. Verify the correct targets and presence through authorized Vercel provider settings; **do not retrieve, print or expose decrypted values**. The GitHub report states the Proxo service-role value is already configured as a server-only sensitive Vercel variable, but the current Vercel connection could **not independently verify that claim**. Do not blindly create a duplicate or overwrite a working credential to resolve a permission issue.

The reviewed native GitHub workflow now requires a dedicated protected **GitHub Actions Environment** named exactly:

```text
proxolink-preview-verification
```

Configure one environment **variable** `PROXO_NATIVE_ANON_KEY` and these three environment **secrets**:

```text
PROXO_NATIVE_TEST_EMAIL
PROXO_NATIVE_TEST_PASSWORD
PROXO_NATIVE_VERCEL_BYPASS
```

All four settings belong to this **protected environment, not to unrestricted repository-wide variables/secrets**. Restrict its branch to `feat/proxolink-private-renderer-migration`; require appropriate reviewer approval and audit the exact job/ref before releasing credentials. Use an existing ordinary, non-admin test account. Never store a Supabase service-role key in Android CI or compile any of these secrets into an APK. The build job is credential-free; the native runtime job only starts under the workflow's explicit user-request trigger and protected environment authorization. Follow `docs/PROXOLINK_PREVIEW_VERIFICATION_SETUP.md` for the current repository-specific procedure.

Vercel's **Protection Bypass for Automation** capability is project-wide until revoked; it is **not inherently preview-only or workflow-bound**. Create only a separately approved temporary capability if the protected CI verification needs it, send it solely to the fixed expected Preview origin, require app authentication separately, deny redirects carrying the capability, then revoke it immediately after testing. If provider-enforced preview-only scope is mandatory, use an isolated preview project instead. Never disable normal Vercel deployment protection to make tests pass.

Historically exposed Telegram and Supabase privileged keys must be treated as compromised and rotated by authorized owners in a coordinated, separately approved maintenance window; merely removing their literals from Flutter is not credential rotation. Never paste replacement values into conversation, GitHub, documentation or artifacts.

# 143. V5 VERIFICATION AND DEPLOYMENT GATES — What Is Actually Known

**GitHub read-only verification in this review:** PR #7 was open/Draft/unmerged at head `bb5772939fa74cd08e8177b99354a8695acd6290`. Its `Verify ProxoLink` workflow run `37215966426` completed successfully, with backend, Flutter and Edge Function jobs all reporting success; the Flutter job included a release APK build and template-source scan. The PR/report contains earlier 41/94 and later 45-backend-test assertions. Exact totals should be taken from the current relevant run logs, not mixed across revisions. A successful compile, Android APK, widget screenshot or earlier 40/40 pixel test **is not a completed native-WebView run**.

**Vercel read-only verification in this review:** the connected Vercel account could list team `proxoapp-1758` (`team_8HiDsaKfcCegaE9FgXwmVrUJ`) but returned no accessible projects, `404 Project not found` for `proxobalance`, `404 Deployment not found` for the reported deployment and `403` when accessing its protected Preview. Thus the protected Vercel deployment, its runtime secret targets and its actual `/contact-preview`/`/contact/:id` responses were **not independently verified by the current Vercel connection**. The GitHub implementation report describes a Ready Preview and historical protected API/browser tests; treat those as reported evidence with explicitly stated revision boundaries. Do not claim a fresh live deployment test until the project-owning Vercel connection is reauthorized and the target deployment is actually reached.

**Database state based on the GitHub report, not a fresh independent Supabase query:** additive migrations and a private bucket were applied; original eight styles and four hidden compatibility variants were prepared; 19 avatar binaries were checked; original 21 cards and 27 ads (16 card references) were retained; legacy customer cutover was rehearsed and rolled back; the customer rows are still in the legacy/precutover state; cleanup, merge and production promotion were not performed. Requery current production data and verify secure backup/manifest before any approved migration. Do not mark legacy rows Ready blindly or delete `html_content`/Base64 preemptively.

**Still required before declaring end-to-end completion:** (1) reauthorize the Vercel connection for the actual team/project; (2) verify current Preview origin and required server-side variable *presence*, never their values; (3) configure the protected GitHub environment and run the current feature-branch Android 35/KVM native WebView test; (4) complete all **32 expected cases** (eight templates × four widths: 320/393/430/768) with safe screenshot and per-style evidence, fonts/images/animations/modals/RTL/overflow and denied navigation, without exposing tokens; (5) test ordinary-user auth, private bucket/RLS and owner-only preview; (6) separately test real external contact-app launch/fallback and iOS when authorized test devices exist; (7) prove full create/edit/retry/public-avatar/exact-ad live flows in an **isolated staging environment** or with separately authorized named disposable fixtures; (8) coordinate historical credential rotation; (9) obtain separate explicit approval for customer cutover, PR merge, production promotion and later legacy cleanup.

The latest GitHub native workflow **builds** its standalone probe APK without privileged settings. The 32-case platform-WebView runtime job does not run just because a build passed and must be reported as **BLOCKED** until its exact required settings are available and a complete successful run is inspected. Never represent a skipped or failed configuration step as device verification.

# 144. V5 EXECUTION PRIORITY, OWNER HANDOFF AND DONE DEFINITION

Work in this order, without restarting completed work:

1. **Reconcile actual branch with this V5 spec.** Read the current PR diff, Flutter/backend routing, migrations, workflow, verification report and actual original private templates (through authorized server access). Record VERIFIED, FAILED or BLOCKED for each relevant feature. Resolve V2/V3/V4 contradictions in favor of this V5 contract.
2. **Fix independently actionable code/UX defects now.** Ensure automatic owner-specific Create and same-UUID Edit/Retry, true visually rendered lazy WebView demos, approved name/bio/spacing/button refinements, app-wide Ad UI consistency, analytics isolation, private source protection, responsiveness and robust error recovery. Reuse verified work; avoid unrelated rewrites or silent template changes.
3. **Run safe CI and code-level security checks.** Check actual current branch/ref and tested commit, unit/widget tests, Android release build, source scan, backend tests, route/function-count limits and schema/migration safety. Record exact evidence and revision; do not treat historical tests as current for changed code.
4. **Resolve provider/device blockers explicitly.** If the Vercel project cannot be read, give the owner short steps to reconnect the project-owning identity; do not claim secret values are missing merely because metadata is inaccessible. For protected native CI, give the exact `proxolink-preview-verification` setup and await secure owner entry/approval. Continue all independent tasks while blocked.
5. **Verify real, integrated behavior before requesting release approval.** Check eight native WebView page renders, all 32 responsive cases, application auth/RLS, actual safe demo non-actions, owner preview, public page, user Create/Edit/Retry/Share/Use for Ad, exact-ad tracking, external contact handling and device coverage. Use staging or expressly authorized test fixtures for writes, never ordinary production customer records.
6. **Prepare a short owner handoff with separate gates.** List code verified, verification still blocked, exact changes/tests/PR link/commit/deployment scope, safe rollback and any required owner actions. Request **separate explicit approval** for each of: customer cutover, credential rotation affecting production consumers, merge of PR #7, production promotion and destructive legacy cleanup. No step silently authorizes another.

**Definition of success for the user's intended product:** a real Proxo customer can independently create and manage a secure, beautiful personal contact page from one of eight genuine visually previewed designs, immediately obtain a stable public link, edit that same page at any time without a developer or per-user deploy, share it or attach it to an eligible advertisement, and have correct per-ad attribution. The deployed Flutter, Vercel and Supabase components must actually work together on tested devices, and current customer data and source privacy must remain protected. A PR, successful CI and a Ready preview are significant intermediate results—not synonyms for a completed production release.

