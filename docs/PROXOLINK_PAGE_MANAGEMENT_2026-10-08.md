# ProxoLink page management rebuild — 2026-10-08

Status: IMPLEMENTED, verification pending; not COMPLETE.

Branch: feat/proxolink-private-renderer-migration. PR #7 remains Draft/open/unmerged.

## Scope

Home exposes My Pages and Create Page. ToolsScreen is the canonical owner list; dedicated details and editor routes reuse the ad flow's typography, section cards and navigation only, not its business logic. Cards use owner-authorized small image capabilities and never create list WebViews. The existing four designs, formal Kurdish labels, twelve real PNG thumbnails and large live server-rendered preview are preserved.

Create chooses contact/order/download and returns a database-generated UUID with a stable typed URL. Multiple pages per owner and owner-scoped request UUID idempotency remain enforced. Save returns the complete safe owner card for immediate insertion in the list. Edit preserves UUID, owner, type and URL; optimistic updated_at leases reject stale writes. Loading/empty/error/retry, archive/deactivate confirmations, unsaved-change confirmation and recovery after a saved response are wired to the real repository. Latest-request-wins state deduplicates IDs and clears private cards on account changes; no broad Realtime subscription is used.

Authoring providers are exactly six contact, Talabat/Toters restaurant and Google Play/App Store download. Historical Lezzoo/WADE remain renderable and existing entries are retained unchanged; new or rewritten unsupported entries are rejected. Telegram is only a contact link.

## Database and authorization

Additive migration 20261008234009_proxolink_page_management_contract.sql adds an invoker trigger with explicit empty search_path. It generates new V6 page IDs in the database, maintains timestamps and validates state/legacy-provider retention. Existing identity/type/owner guards and restrictive owner RLS remain. Anonymous/PUBLIC table privileges and direct execution of the trigger function are revoked; no new SECURITY DEFINER RPC or authenticated privilege is introduced. Existing security-definer functions, scoped archive/ad dependency boundary and owner policies were reviewed, not replaced. Server owner detail reads filter authenticated UUID and hide archived/foreign records. Action and edit writes have concurrency leases.

Migration has not been applied to production or any live customer database. It performs no backfill, delete, column rename/drop or existing ID/URL/ad change. Disposable CI tests apply, reapply and transaction-roll back it. Rollback after deployment would require dropping only the new management trigger/function; prior guards remain. Do not automatically restore anon grants: restoring private-table access is not a safe rollback.

Existing isolated-write guard intentionally remains: hosted create/edit/archive requires approved isolated staging, not production activation. This report does not claim the hosted management journey ran.

## Verification

Local backend: 132 passed / 0 failed. Source privacy scan passed. Dart formatting parsed changed files; full Flutter analysis/widget tests, responsive browser checks, disposable PostgreSQL/RLS and release APK privacy are delegated to the existing source CI. Local Flutter setup encountered a security-sensitive incidental metadata request; that path was stopped, not bypassed. No local Flutter/DB success is claimed.

The separate protected Android diagnostic run 37844040950 attempt 2 is pinned to 6c7e6c634cfe0bceb2c43ceb485aba12cd78417c, before this rebuild. It failed strict pixel parity; it cannot certify the new management UI. Its terminal evidence is being independently audited. No new native run, workflow/protection change, acceptance weakening or speculative pixel fix was included here.

## Exact implementation paths

- .github/workflows/proxolink-verify.yml
- api/_lib/proxolink-pages.js
- api/_lib/proxolink.js
- api/_lib/proxolink-prepared.js
- api/_lib/proxolink-handlers/contact-cards.js
- api/_lib/proxolink-handlers/contact-card-action.js
- proxo_app/lib/controllers/proxolink_pages_controller.dart
- proxo_app/lib/models/proxolink_page_type.dart
- proxo_app/lib/services/proxolink_service.dart
- proxo_app/lib/screens/tools_screen.dart
- proxo_app/lib/screens/proxolink_page_editor.dart
- proxo_app/lib/screens/proxolink_page_editor_screen.dart
- proxo_app/lib/screens/proxolink_page_details_screen.dart
- proxo_app/lib/widgets/proxolink_page_card.dart
- proxo_app/lib/main.dart
- proxo_app/lib/screens/home_screen.dart
- proxo_app/lib/widgets/home_quick_actions.dart
- proxo_app/supabase/migrations/20261008234009_proxolink_page_management_contract.sql
- test/proxolink-page-management.sql
- test/proxolink-v6-api.test.js
- scripts/proxolink-v6-responsive.mjs
- proxo_app/test/proxolink_page_management_test.dart
- api/_lib/proxolink-handlers/independent-pages.js

This report is an additional documentation file. No template CSS/fonts/assets/thumbnails, production customers, migrations on production, publishing or merge were performed. Source-CI run/revision and final results must be recorded after actual execution; pending checks and new-UI Android coverage remain blockers.
