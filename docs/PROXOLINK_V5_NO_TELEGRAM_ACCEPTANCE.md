# ProxoLink V5 — No-Telegram owner amendment and acceptance criteria

**Authority:** 4 October 2026 owner decision. This document overrides every older V5/V4/V3/V2 mention of a Telegram contact platform, bot, sample destination, notification, replacement credential, template action or release requirement. Historical requirement text remains available only as an audit trail. PR #7 must remain Draft.

**Current verified state, 5 October:** feature source and backend/Flutter/Edge checks remove active ProxoLink Telegram behavior. Under the owner's explicit exception for this function only, production `notify-tool-created` is now **v4 ACTIVE** with the checked HTTP 410 replacement and JWT verification retained. Fetched source matches exactly; actual authenticated POST returned **410**, unauthenticated POST **401**, and OPTIONS **204**. It reads no legacy payload, calls no Telegram API and accesses no database or Storage. Other function versions are unchanged. [Executed evidence](evidence/proxolink-v5-2026-10-05/retirement-execution.json). Native execution is still 0/40 and live staging 0/8; those rendering/workflow requirements remain BLOCKED. See the [current execution report and complete 145-section matrix](PROXOLINK_V5_EXECUTION_2026-10-05.md).

## Product and source-of-truth behavior

ProxoLink must be fully operational with **WhatsApp, Viber, Instagram, TikTok, Korek/phone and Asiacell/phone**. All eight original server-private template styles (dark, light, classic, pill, card, neon, zoom, banner) preserve their backgrounds, gradients, font identity, RTL/LTR behavior, button shape and animation. Telegram removal necessarily changes the number/order/wrapping of contact buttons; that is an explicitly authorized visual difference, as are earlier approved subtle name/bio/spacing/press changes.

No Telegram option may appear in the Flutter creation/edit forms, platform selection, contact list, published page, owner preview or signed template demonstration. No rendered DOM may include an actionable Telegram button, URL, event handler or tracked `/a/:token/action/tg` link. The ProxoLink backend must reject new client Telegram fields and retired tracked actions without redirects or contact events. Demo contact and TikTok links are inert and must not open an external app; published non-Telegram destinations remain validated server-side.

ProxoLink sends **no bot notifications, HTML files or messages**, does not call the Telegram Bot API, and must not require a bot token, chat ID, thread ID or replacement Telegram credential. Deleted legacy Flutter HTML delivery remains deleted. The unrelated root `/api/notify-order` endpoint presently consumes shared Telegram environment settings for **order notifications**, not ProxoLink; do not silently delete or break that separate workflow during this scoped change.

## Preserve all historical information

All existing card UUIDs, advertisement IDs, ownership, ad-card relationships, legacy HTML, archived avatar/base64 data, and historical `platforms.tg` / `platforms.telegram` values remain in the database. Historical Telegram values may be read internally for backward-compatible edits, but must not be returned to the new Flutter UI or influence page rendering, validation of supported destinations or analytics. Edit, Retry and template changes retain the old fields without creating new Telegram behavior. No schema drop, JSON deletion or customer cutover is authorized.

The read-only baseline before this amendment was **21 customer cards, 27 advertisements, 16 card relationships and 2 customer rows with archived Telegram fields**. Reinspect these counts before any later approval-gated migration; they are snapshots, not a permanent guarantee.

## Required verification before release

- [ ] Node tests pass for all eight styles and for public/owner/demo rendering with historical Telegram values hidden; ordinary supported destinations and exact-ad attribution still work
- [ ] Authenticated create rejects fresh Telegram fields, edit preserves historical fields without exposing them, and a tracked Telegram action returns a safe failure with no event or redirect
- [ ] Flutter tests confirm the five supported contact-selector entries, no Telegram widget/navigation allowlist, safe historical-model filtering and existing UI behavior at 320/375/393/430/768 dp
- [ ] Source and release APK scans find no ProxoLink Telegram controls, Bot API calls, reusable private templates or static screenshot previews
- [ ] Compare all eight original templates against approved no-Telegram server-rendered output at 320/375/393/430/768 CSS px. Log intentional Telegram-button/reflow differences separately from unintended font, layout, color, icon, animation or RTL regressions. Do **not** claim old pixel identity where an intentional button was removed
- [ ] Run the protected native Android WebView probe at eight styles × five widths = 40 cases, retain WebView/browser/diff images and exact pixel metrics for every case, verify modal open/cancel/reopen/confirm-close, applied Rabar/icon fonts, decoded images, live animations, no overflow, inert demo links and no Telegram controls
- [ ] Independently validate authenticated protected Vercel Preview routes, RLS, denied private template access, signed capabilities, analytics suppression in previews, owner checks and no user-specific HTML delivery
- [ ] Verify real WhatsApp/Viber/Instagram/TikTok/phone external application handoffs with authorized device/test fixtures; verify iOS WKWebView separately

**Immediate native blocker:** all four settings are verified present in `proxolink-preview-verification`. Fresh saved controls still have Required reviewers disabled and administrator bypass enabled. Automatic approval review rejected changing these access controls without explicit authorization for that change; no control or credential value was altered. Vercel dashboard and stable-ID connector project access were verified in the preceding inspection. Do not paste values into chat, commit them or disable deployment protection. Temporary bypass must be revoked after tests. These are **not** Telegram credentials.

**Separate historical security action:** The owner should revoke the previously exposed bot credential once through [verified BotFather](https://t.me/BotFather). No replacement Telegram bot or token is required for ProxoLink and this separate action must not block unrelated implementation. Coordinate any impact to non-ProxoLink order notifications.

**Release gate:** The owner authorized only the now-completed production HTTP 410 retirement of `notify-tool-created`. This does not authorize merging PR #7, promoting the ProxoLink feature, activating V2 for customers, migrating/cutting over customers, changing their cards/advertisements or deleting legacy data. Mark incomplete device and pixel checks BLOCKED, not VERIFIED.
