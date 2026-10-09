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

Source CI **37862457017 SUCCESS** at implementation revision **dc15bbf84101044f5657d9320526f0c80152ac39**, all five jobs, completed 2026-10-09 00:05:30 UTC: backend **132 passed/0 failed**, Flutter **210 passed/0 failed**, renderer/browser responsive **480 cases passed**, disposable PostgreSQL/RLS migration transaction rollback/reapply and **seven actual database-backed API lifecycles** passed, edge functions and release APK privacy passed. Source scan passed locally and in CI. Flutter analysis passed with informational lints; no fatal errors/warnings. These are source/widget/browser/database checks, not native runtime certification. Local Flutter setup encountered a security-sensitive incidental metadata request; that path was stopped, not bypassed. No local Flutter/DB success is claimed.

The separate protected Android diagnostic run **37844040950 attempt 2** is pinned to **6c7e6c634cfe0bceb2c43ceb485aba12cd78417c**, before this rebuild. Independently audited result: **FAILED**, behavior 240/240 passed, candidate/baseline 240/240, zero missing, 480 stable roles, **232 exact/8 failed** pixel pairs (1,750 changed pixels, max channel delta 1), chooser 12/12 passed on that pinned builder. It cannot certify the rebuilt management UI. Root cause remains NOT PROVEN; exact evidence is in native-6c7e6c6-attempt2. No new protected native run, protection/acceptance change or speculative pixel fix was included here.

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

This report is an additional documentation file. Terminal native publication adds 36 safe evidence files and updates the current execution report; those are separate from the 23 implementation paths above. No template CSS/fonts/assets/thumbnails, production customers, migrations on production, publishing or merge were performed. All implementation source checks passed; latest documentation-head CI is recorded in Draft PR #7 separately. Hosted isolated create/list/open/edit journeys and Android coverage of the rebuilt management screens remain unexecuted, and strict native pixel failures remain unresolved. This is not COMPLETE.
