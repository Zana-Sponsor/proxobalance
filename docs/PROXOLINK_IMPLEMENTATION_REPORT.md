# ProxoLink implementation and verification report

Verified on 4 October 2026. **Production completion is blocked.** The application/backend changes are implemented on the requested branch and the tested code passes CI. Additive database changes and private storage preparation are live. Customer cutover, legacy-column cleanup, production promotion and native end-to-end verification remain pending.

The supplied attachment was `PROXOLINK_PRIVATE_TEMPLATES_FULL_IMPLEMENTATION_PROMPT_UPDATED_V2(3).md`, containing 4,891 lines and sections 0–132. It was read from beginning to end before edits. The user's later instructions requiring live template previews and the existing Ad UI design system supersede its older static-preview instructions. A separate V3 attachment was not available.

## Repository and deployment evidence

| Item | Actual status |
| --- | --- |
| Repository | [Zana-Sponsor/proxobalance](https://github.com/Zana-Sponsor/proxobalance) |
| Branch | `feat/proxolink-private-renderer-migration` |
| Pull request | [Draft PR #7](https://github.com/Zana-Sponsor/proxobalance/pull/7) |
| Tested application/backend revision | `c2536f5a09d2906c816ef501731960cbb192a8ea` |
| CI | [Run 37168650583](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37168650583): backend, Flutter and Edge Function jobs passed |
| Vercel preview | [proxobalance-nupewpz5b-proxoapp-1758.vercel.app](https://proxobalance-nupewpz5b-proxoapp-1758.vercel.app): READY |
| Vercel preview deployment | `dpl_5UbbGoeqXUmKCnKsiNUowj4YY95r` |
| Merge commit | None; PR remains draft and unmerged |
| Production deployment | Changes have not been promoted to production |
| Android | Release APK builds; 83.2 MB; privacy scan passes |
| Store distribution | Not published; CI uses the repository's signing fallback without a supplied private release keystore |
| iOS / physical-device test | Not performed |

Vercel READY confirms a successful build. It does not establish live endpoint correctness. Protected-preview access through the connected Vercel tools returns 403 before the application is fetched.

## Flutter implementation

- Rebuilt ToolsScreen template selection, preview container, contact form, card list, status presentation and actions using existing `AdUi`, `AdFormSection`, `AdChoice` and inherited Rabar typography. White surfaces, Proxo blue headings, soft shadows, corner radii, padding, input controls and buttons use the existing Create Ad components. No ProxoLink font-size overrides were added.
- Added authenticated template catalog and signed preview requests. The selected original template is rendered by Vercel and displayed in a native WebView inside Flutter, with a full-screen preview action. Loading, retry and failure states are implemented.
- WebView navigation accepts the expected HTTPS origin, path and query shape. Unexpected main-frame destinations are blocked. Owner card previews support approved contact schemes with external-launch fallbacks; template demonstrations disable contact actions. JavaScript remains enabled for the original templates' animations and confirmation dialogs.
- Card creation and editing send structured fields only. Owner identity is derived from the bearer session. Stable UUIDs, per-user pending-draft recovery, binary avatar uploads and recoverable failed publication support retry without creating another card.
- Implemented list, create, edit, preview, retry, activate, deactivate, dependency-aware delete, copy, share and Use for Ad actions. Public/ad actions require Active + Ready. Inactive cards remain privately previewable.
- Both advertisement-selection paths and repository validation require an owned Active + Ready card. Existing financial submission and receipt behavior are preserved.
- Kept contact analytics hidden. No new analytics panel remains in Flutter; Ad Details is unchanged from the starting branch. Flutter does not read raw events or internal link rows.
- Removed the reusable HTML templates, local HTML assembly/preview widgets, Telegram HTML delivery, native file-sharing channel and associated file-provider XML. Static `assets/styles/` previews are no longer used or bundled. Existing image files remain in repository history; they are not application previews.

Flutter files changed/added:

```text
lib/screens/tools_screen.dart
lib/screens/proxo_cards_list_screen.dart
lib/screens/card_webview_screen.dart
lib/screens/ad_screen.dart
lib/services/proxolink_service.dart
lib/services/ad_submission.dart
lib/models/proxo_card.dart
lib/models/proxolink_template_meta.dart
lib/controllers/proxo_card_controller.dart
lib/widgets/proxolink_preview.dart
test/proxolink_flow_test.dart
test/text_direction_test.dart
pubspec.yaml
android/app/build.gradle
android/app/src/main/AndroidManifest.xml
android/app/src/main/kotlin/com/proxo/proxoapp/MainActivity.kt
```

Removed Flutter files:

```text
lib/templates/card_templates.dart
lib/services/html_generator.dart
lib/services/local_html_preview.dart
lib/services/local_html_preview_io.dart
lib/services/local_html_preview_types.dart
lib/services/local_html_preview_web.dart
lib/services/telegram_delivery_service.dart
lib/widgets/html_live_preview.dart
lib/widgets/html_preview_sheet.dart
android/app/src/main/res/xml/proxo_file_paths.xml
```

The Android NDK is pinned to `28.2.13676358`, required by the native WebView dependency. Existing release-signing configuration remains in place.

## Backend and security

- Consolidated ProxoLink routes under `api/proxolink.js`, with handlers under `api/_lib/proxolink-handlers/`. The project now has ten top-level API functions and fits Vercel's Hobby limit; the starting branch's deployment exceeded that limit.
- Implemented authenticated catalog, card management, preview-token and advertisement-link endpoints; public `/contact/:id`, signed `/contact-preview`, `/a/:token` and `/a/:token/action/:platform` routes. Vercel rewrites and local server routes match.
- Reused `api/_lib/security.js` and verified Supabase bearer identities. Proxo's project credentials remain separate from the existing Exchange project's credentials.
- Renderer loads private, versioned, checksum-verified templates on the server. It validates structured content, escapes HTML/JavaScript, constructs trusted contact destinations and never returns raw template metadata through the catalog.
- Public pages require Active + Ready. Preview tokens are signed, short-lived and bound to their intended card/template. Preview rendering suppresses contact analytics and the TikTok Pixel bootstrap.
- Creation uses a stable client UUID and a normalized payload hash. Duplicate requests reuse the same result; changed payloads cannot overwrite an existing idempotency key. Failed publishing retains a retryable row.
- Editing validates the complete proposed page before committing, then uses `updated_at` for optimistic concurrency. Failed edits preserve the prior published data. Activation/retry use a publication lease.
- Avatars are restricted to immutable owner/card paths. Sharp fully decodes JPEG, PNG or WebP bytes, checks the MIME, rejects truncation and applies file-size/pixel/dimension limits before publishing.
- Public HTML receives no-store, nosniff, no-referrer and restricted permissions/CSP headers. CSP hashes authorize the original scripts and specific original confirmation handlers. Rabar is self-hosted; original template CSS and visual dependencies are preserved.
- Advertisement page views and button clicks resolve the exact link/ad/card/owner relationship server-side. Every tracked button, including TikTok, carries that advertisement's token. Sessions and IPs never determine ad identity. Organic and preview requests create zero advertisement events. `pa_ads.clicks` is not changed by contact-page tracking.
- Raw IP addresses are suppressed in application code and by a database trigger. The server can retain an HMAC hash using its secret. Visitor identifiers and user-agent/context fields are cleared after 30 days while counts/history remain.
- `server.js` serves the public output rather than the repository root. No reusable template HTML is added to GitHub or generated as a per-customer file, commit or deployment.

Main backend/build files: `api/proxolink.js`, the ProxoLink handler directory, `api/_lib/proxolink.js`, `proxolink-preview.js`, `proxolink-track.js`, `proxolink-audit.js`, `security.js`, `server.js`, `vercel.json`, `.env.example`, `package.json`, `package-lock.json`, the privacy scanner and the CI workflow. Public demo avatar/font assets contain no reusable template source.

## Supabase changes actually applied

Project: `cojchkwssmasiejcgvbk`.

| Migration | Applied result |
| --- | --- |
| `proxolink_production_integrity` | Private full-row backup; structured-field constraints; timestamp triggers; service-only template/link/event/audit access; ad/card RESTRICT foreign keys; live-card dependency protection; immutable binary avatar policies; raw-IP suppression; atomic ad-link issuance helper; visitor retention and cron |
| `proxolink_legacy_versions` | Private historical renderer variants/options, separate from the eight catalog versions |
| `proxolink_indexes` | Covering relationship indexes, backup primary key, removal of the client audit policy |
| `proxolink_migration_manifest` | Private 21-card checkpoint containing original-state guards and verified recovered fields/avatar hashes |
| `proxolink_hidden_analytics` | Aggregate/tracked-path helper executable only by service_role; anonymous/authenticated clients denied |

The staging schema from the partial branch is retained: `proxolink_templates`, `proxolink_cards`, `proxolink_publish_attempts`, `pa_ad_contact_links` and `pa_contact_events`. Existing card-number assignment is preserved. Link uniqueness/current-version constraints and event type/button constraints are retained.

New private checkpoint tables are `proxolink_private.cards_backup_20261003` and `proxolink_private.card_migration_manifest_20261004`. That schema is not client-exposed. New/strengthened fields include template renderer variants/options, catalog visibility, card creation-request hashes, supported language/version checks and structured platform JSON validation.

Storage:

- `proxolink-templates` is private. Eight immutable original v1 templates and four historical compatibility versions are stored there. Anonymous public/private object GETs for an original template both returned HTTP 400 without delivering source.
- `proxolink-assets` contains 19 verified binary avatars at immutable owner/card paths. HTTP availability, MIME, SHA-256 and image decoding were checked. Two existing cards have no avatar and use designs that permit this.
- A private full-card rollback object and private database backup retain the original legacy rows.

The account-deletion Edge Function was corrected for nested avatar paths and the new RESTRICT relationships, type-checked and deployed. No real customer account was deleted as a test. The temporary migration helper has been replaced by a JWT-protected inert 404 function; its migration capability is retired.

## Customer/template migration state

| Item | Verified state |
| --- | --- |
| Original catalog designs | dark, light, classic, pill, card, neon, zoom, banner: 8/8 private originals retained |
| Historical designs | Four hidden compatibility versions preserve older customer revisions; five cards are pinned to these variants |
| Customer cards | 21 existing cards retained |
| Advertisements | 27 existing advertisements retained |
| Structured recovery | 21 records prepared and guarded in a private migration manifest |
| Binary avatars | 19 uploaded and verified; two legitimately absent |
| Customer rows committed as Ready | 0; cutover has not been committed |
| Existing ad links committed | 0; backfill is prepared, not committed |
| Orphan/owner mismatch | No existing card/ad owner mismatch found |
| Legacy HTML/base64 cleanup | Pending; original columns remain live until verified cutover |

Recovery derives missing contact fields from each customer's existing rendered HTML and preserves valid current structured values. Historical CSS versions remain pinned rather than being replaced by the newest template. Some old rendered HTML contained stale contact values or broken embedded avatar content; current structured values and verified avatar bytes are used in the prepared recovery. Consequently, the 21 customer comparisons are not claimed to be all pixel-identical to stale/broken legacy pages.

`scripts/sql/proxolink_verified_cutover.sql` is prepared but not applied. It verifies that every customer row still matches its checkpoint, locks the related tables, checks exact template/avatar readiness, updates the 21 recovered records, installs advertisement validation/link synchronization, backfills distinct tokens for the 16 existing card-linked ads, restricts client card reads/writes and removes the legacy HTML/base64 columns. An explicit live-verification guard prevents automatic execution.

Completed/rejected ads receive inactive history links in the rehearsal. Historical relationships and advertisement IDs are preserved. The financial ad-submission RPC was not replaced.

## Test results and limits

| Verification | Result |
| --- | --- |
| Node backend regression/security tests | 33 passed, 0 failed |
| Flutter selected integration/widget/unit suites | 92 passed |
| Flutter analysis | No errors or warnings; 34 informational lint notices |
| Android release compilation | Passed, 83.2 MB APK |
| APK source/privacy scan | Passed: no raw template markers, local HTML generator, Telegram Bot API marker or bundled `assets/styles/` previews |
| Edge Function Deno check | Passed |
| Flutter responsive tests | Card list at widths 320/375/393/430/768 with system text scale 1.6; form/preview recovery at 320/393/768; no layout exceptions |
| Flutter visual artifacts | Actual Rabar and Material icons loaded; eight verified screenshots published as a CI artifact |
| Original template pixel comparison | 40/40 exact: eight styles at widths 320/375/393/430/768 with matched data/dependencies |
| Browser customer-card renders | 63 cases: 21 prepared records at widths 320/393/768 |
| Combined browser checks | 103 cases; loaded fonts/images, no horizontal overflow, no JavaScript or CSP errors |
| Original confirmation dialogs | Open, cancel, reopen and confirm-close passed for all eight templates |
| Actual external native-app launch | Not established by the browser harness; awaits native-device verification |
| Database cutover rehearsal | Passed inside a transaction, then rolled back: 21 Ready rows, 16 independent tokens, direct client card writes blocked |
| Same card / two ads SQL attribution | Passed: independent page/button totals and platforms; no cross-ad mixing |
| Cross-owner SQL access | Denied |
| Ordinary-client analytics/tokens/templates | Denied by actual role privileges |
| Raw-IP and 30-day retention SQL checks | Passed; test changes rolled back |
| Live Vercel endpoint verification | Blocked before application fetch by protected-deployment access denial |
| Flutter WebView versus live deployment on device | Pending; widget tests and browser tests are separate evidence |

Browser pixel tests freeze animations on both sides and use the same exact dependency bytes to make comparison deterministic. They do not send real tracking requests. The original template CSS and JavaScript remain in the server-rendered output. Pixel comparison is evidence for the controlled template cases, not a blanket claim covering every native WebView/device configuration.

`scripts/sql/proxolink_verify_transaction.sql` contains the reversible attribution/privacy checks. Post-test live counts are still 21 cards, 27 ads, zero Ready migrated cards, zero links and zero test events.

Supabase advisors were checked after the DDL changes. Missing related foreign-key indexes and backup primary-key findings were addressed. Server-only RLS tables intentionally have no client policies; see [the advisor explanation](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy). Existing card-table permissive policies remain until cutover, which replaces them with one safe read policy and revokes client writes; see [the policy finding](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies). New indexes currently have unused-index INFO notices because production cutover has not occurred. Unrelated pre-existing project warnings were left outside this change.

## Remaining production blockers and next actions

1. **Missing Proxo server credential:** Vercel has no `PROXO_SUPABASE_SERVICE_ROLE_KEY` for the Proxo Supabase project. The existing `SUPABASE_SERVICE_ROLE_KEY` belongs to the separate Exchange project and cannot be reused. The connected Supabase tools cannot retrieve/provision the required privileged credential. Configure it securely for preview and production; do not paste it into chat or commit it.
2. **Protected-preview access:** the Vercel connector cannot access the deployment's protection-bypass endpoint and returns 403. Its project/team authorization must be restored, or the user must approve browser-dashboard fallback. Deployment protection remains enabled.
3. **Live verification and cutover:** after credentials/access are restored, verify catalog previews, create/edit/retry/status flows, public links, private source denial and exact-ad events against the deployed backend, then verify the native WebView. Commit the guarded database cutover only after those checks pass. Re-check customer counts/IDs/card numbers and both ad-selection paths.
4. **Telegram credential remediation:** HTML delivery and client Bot API code are removed, but revocation/rotation of the historically exposed credential has not been confirmed. BotFather confirmation is still required. Git-history erasure and rotation are not claimed.
5. **Release:** complete native Android/iOS verification, supply the production release signing configuration, merge the PR and promote the verified Vercel deployment. No merge, production promotion or app-store publication has occurred.

Vercel preview and production already have the Proxo URL, public base URL, private preview-signing secret, analytics-hashing secret and preserved TikTok Pixel ID configured. The other application's environment variables are unchanged. No privileged server secret was printed, committed or placed in Flutter.

## Rollback readiness

No customer cutover has been committed, so the current customer rows and legacy columns remain available. The private original-row database/storage backups and original deployment reference are retained. The guarded cutover rejects any changed customer checkpoint rather than overwriting newer customer edits.

If post-cutover verification fails, restore the prior code/routes and original rows from the private backup while preserving UUIDs, card numbers and advertisement relationships. Pause tracking-link activation while restoring the backend. Do not delete the backup or private historical template versions during rollout.

This report records implemented code, applied additive changes and verified tests. It does not certify completed production migration or a native end-to-end release.
