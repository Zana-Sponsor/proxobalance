# Proxo Balance: admin refunds, IQD balance and capped fee rewards

## Release and verification
1. Apply Exchange migrations in their original order, followed by `SUPABASE_EXCHANGE_SERVER_ONLY_ORDERS.sql` and `SUPABASE_EXCHANGE_ADMIN_REFUND_REWARD_CAP.sql`. These migrations create no refund credits or reward grants and leave existing financial records unchanged.
2. Deploy the server and UI together. The Vercel build copies root `index.html`, `exchange-admin.html` and `assets/` into `public/`, including `exchange-reward-pricing.js` before `app.js`.
3. Run the Node route/pricing tests, `test/exchange-order-permissions.sql` and `test/exchange-admin-refund-reward-cap.sql`. The last script uses synthetic users and financial entries inside an explicit transaction and rolls everything back. It verifies capped quotes, restored quotas, repeat refunds, duplicate evidence rollback and admin permissions.
4. Check that `/api/balance` rejects anonymous callers and admin actions reject ordinary customers. The production smoke workflow checks the live customer/admin pages and their bundled assets.
5. Leave `ex_balance_config.payouts_enabled` unchanged. External payouts are a separate manual flow: the admin verifies recipient ownership and makes the real transfer before recording its unique reference and actual receipt.
6. Reconcile banking statements with refund evidence references and run `ex_admin_balance_reconcile(admin_uuid)` through the connected service backend. Investigate journal, balance, held-funds or refund mismatches before further disbursement.

## Explicit admin rejection and refund
- The admin chooses **reject and refund to balance** from the order details or balance board. This is an explicit decision; an ordinary rejection or payout failure does not automatically credit money.
- The admin verifies that the original funds were actually received, enters a unique settlement/evidence reference and explains the decision. A failed outbound transfer is not a prerequisite or a required confirmation.
- The service-only `ex_admin_reject_and_refund` RPC checks the authenticated admin, locks the order, rejects it, credits its full original IQD `ex_orders.amount`, restores any used reward once and writes the refund case, journal, audit entry and notification in one transaction. It accepts no client-selected refund amount.
- New cases use `refund_kind = 'admin_rejection'` and `confirmed_payout_failed = false`. Legacy failed-payout records retain their original meaning. The older `ex_balance_credit_refund` RPC delegates to the new function for deployment compatibility; its former failed flag is no longer a precondition.
- A repeat request for the same order returns its existing case without another credit. Reused evidence references or receipt hashes are blocked. A failure rolls back status, balance and reward changes together.
- Only IQD-to-IQD orders with an original receipt and verified received funds are eligible. Approved orders or orders with payout proof are blocked; USDT needs separate reconciliation.
- A credited order retains its original proof and refund timestamps. Its amount, receipt, route and status are then protected against modification. Journals, entries and refund cases are append-only.

## Per-transaction reward amount cap
- Apply `SUPABASE_EXCHANGE_SCOPED_REWARDS.sql` after the capped-reward migration. Every reward is now separately assigned to `wallets`, `korek` or `asiacell`. Existing grants become wallet-only; no usage quota or historical financial value is rewritten. Carrier rewards have their own percentages, caps, expiry and use counts. A carrier leg uses that carrier scope; if both legs are carriers, the sending carrier determines eligibility. USDT remains excluded. Wallet rewards cannot consume quota or reduce fees for either carrier. Orders and usage records preserve the applied scope.
- The admin sets `max_amount_iqd` on each user's reward, alongside its use count, percentage and expiry. The form defaults to 50,000 IQD. A blank cap means unlimited amount coverage; existing rewards remain unlimited until replaced by an admin.
- The cap covers principal **per transaction**, not a cumulative spending allowance. With a 50,000 cap and a 60,000 transfer, the first 50,000 receives the reward and the excess 10,000 uses the normal route fee. At a 2% route fee, a free reward results in a 200 IQD fee and 59,800 IQD received.
- Percentage discounts reduce only the fee eligible under the covered principal. A 50% discount in the same example gives a 700 IQD final fee: 500 on the covered portion plus 200 on the excess.
- A fixed per-transfer fee still applies when any principal exceeds the cap. If a capped reward produces no saving, it does not consume a use. Fees use the route's existing payout-rounding rules.
- The user sees the reward cap, remaining uses, covered amount, excess amount and actual final fee before submitting. The database recalculates the authoritative amount and consumes a use under a row lock; caller-supplied reward values are discarded.
- `ex_orders` and `ex_reward_usages` store the applied cap, covered principal and discount snapshots so later reward changes cannot erase the historical calculation.

## Access and ledger controls
- Customer Send balances load independently of wallets/rates and remain visible when the exchange form is KYC-locked, including zero balances and load errors. KYC continues to hide the exchange form and disables the visible payout controls. Returning to Send, focusing/resuming the page or the visible-page refresh interval reloads current balances; sign-out clears financial UI and invalidates pending responses. Payout configuration is unchanged. Browser regression uses the real HTML/CSS and balance module with synthetic responses at 390px and 1280px; it reproduces the old KYC-hidden balance and verifies the fix without creating customers or financial entries.
- The admin Accounts section shows each user's available balance on desktop rows and mobile cards, including zero for an account with no balance record. Account details refresh available/held amounts and the balance timestamp through the authenticated `account_balances` admin action. Lookup requests are limited to 200 IDs and the account list reads all batches, independent of the recent-record limit on the balance board. Read errors are reported instead of displaying a false zero. The refresh button preserves the current user filter/search.
- New orders use authenticated `/api/orders`. Legacy table and column INSERT grants have been revoked so customers cannot bypass server route, receipt or price checks.
- Customers read only their own balances, ledger, refund cases, rewards and payout requests. They cannot directly create or alter these financial records or execute refund RPCs.
- The user sees account balance and payout requests inside the Send section. The database stores the full financial history, including actor, note, evidence, date and transaction links.
- Service-only functions use double-entry postings and row locks. Risk alerts record repeated payout attempts, overdraft attempts and suspicious duplicate refund requests.
- Cancelling a pending payout releases held funds; repeating a paid/cancelled operation cannot pay or release the same money twice.

## Read-only reconciliation
```sql
select journal_id, sum(delta_iqd)
from public.ex_balance_entries
group by journal_id
having sum(delta_iqd) <> 0;
```
This must return zero rows. Also inspect the full authorized `ex_admin_balance_reconcile` result. The application records manual settlement decisions; it does not autonomously transfer funds between external wallets.


## Account balance as an exchange source
Apply `SUPABASE_EXCHANGE_BALANCE_SOURCE.sql` before releasing the AccountBalance order API. This seeds only the new Send source and its outgoing routes at 2%; it changes no prior wallet or carrier fee. The admin wallet/pair and Rates editors manage these routes normally. Incoming deposits to AccountBalance and USDT balance routes are blocked.

AccountBalance is selected in the same Send picker/form. Its wallet icon and available amount are visible, sender identity comes from the authenticated profile, and no external payment receipt is required. POST `/api/orders` invokes a service-only atomic RPC: configured pricing/rewards, order creation, full principal debit, and double-entry journal either all commit or all roll back. Per-user request keys prevent repeated debits and reject changed retry payloads. Debit proof is shown in the admin order details; explicit admin refund verifies that proof and restores the full principal once. Ordinary rejection does not refund automatically.

This exchange path is controlled by the AccountBalance wallet lock and outgoing route switches; the older standalone payout configuration remains unchanged. The balance card directs customers into this exchange source. Reward quotas refresh when Send resumes, periodically, before confirmation, and after submission. The customer fee line now displays the actual fee, including the ordinary route fee after the quota is exhausted.
