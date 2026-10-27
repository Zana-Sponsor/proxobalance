# Exchange customer and staff features

Wallet labels are configured manually in the admin wallet editor: none, popular, most popular, or new. New is recorded after a signed-in customer actually sees the wallet in the picker. It disappears on the next opening for that customer, across devices. Offscreen wallets are not marked seen. Changing the label away from New and back creates a new campaign.

Saved recipients are available beside the recipient number in Send. Customers can save, select, edit and delete up to 50 destinations. Entries belong to their owner, validate wallet-specific numbers, and respect active routes. Selecting an entry retains normal confirmation and identity checks.

Super admins configure employee permissions from Accounts. Existing full admins retain their access through a null permission list. An empty list disables panel access. Operational permissions include View automatically.

| Permission | Access |
| --- | --- |
| View | Orders, customer balances, statistics and permitted read views |
| Approve orders | Approve, reject, request corrections, manage payout steps, notes and payout receipts |
| Refunds | Explicit admin refund and permitted payout cancellation |
| Manage fees | Wallet and rate configuration |
| Manage rewards | Grant and revoke customer rewards |

The server checks fresh profile permissions on each request. Scoped staff cannot invoke unsupported legacy admin actions. Full-admin security and user-management paths remain restricted. Permission changes are audited and limited to super admins; self changes and changes to super-admin targets are rejected.

Reward notifications use the existing customer bell. Active usable rewards receive one reminder at their last remaining use and one within 24 hours of expiry. Unique reward/type keys prevent repeated alerts. Refresh on sign-in and the hourly exchange-reward-reminders cron cover customers who have not opened the site. Notifications do not change reward usage or financial balances.

## Applied database changes

- SUPABASE_EXCHANGE_CUSTOMER_STAFF_FEATURES.sql
- SUPABASE_EXCHANGE_STAFF_RPC_GUARDS.sql
- SUPABASE_EXCHANGE_REWARD_REMINDER_CRON.sql

Applied migrations: exchange_customer_staff_features_20261005 and exchange_reward_reminder_cron_20261005. User-management Edge functions were deployed with fresh permission guards: admin-create-user v4 and admin-set-password v5. Existing manual JWT validation and platform verify_jwt configuration were preserved.

## Verification

53 Node tests passed. Real Chromium flows passed at 390px and 1280px for wallet visibility, saved recipient CRUD, account isolation, and staff permissions. Database rollback tests verified owner RLS, permission escalation prevention, badge campaign versions, and reminder deduplication. Existing balance-source, admin-refund/reward-cap and scoped-reward SQL regressions passed. Production fixture changes were rolled back.

## Live synchronization and confirmed saves

SUPABASE_EXCHANGE_LIVE_SAVES.sql adds owner-only change signals for recipient insert, update and delete and badge reads. Realtime is enabled for rates, rewards, profiles, customer balances, payout requests and these signals; existing RLS remains in force. Private recipient DELETE payloads are not published. Clients coalesce change bursts, refresh on reconnect/resume and poll while disconnected. Subscriptions and pending jobs are cleared on account changes.

Wallet and route settings use the authenticated, RLS-enforced ex_staff_save_wallet RPC in one transaction. An invalid route or missing wallet rolls back the entire write. Recipient writes return the affected row, and staff permission writes return the confirmed target; empty results and network failures keep editors open with errors and restore save buttons. Successful recipient rows appear immediately from the committed result. Initial customer reads run concurrently.
