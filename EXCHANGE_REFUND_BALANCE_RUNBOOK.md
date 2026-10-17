# Proxo Balance: admin refunds, IQD balance and capped fee rewards

## Exact-thousand IQD payouts and automatic balance refunds

New approvals for an external **IQD recipient** pay only complete multiples of 1,000 IQD. The policy uses the final net entitlement **after fees and rewards**: `payout_iqd = floor(total / 1000) * 1000`; `payout_rounding_iqd = total - payout_iqd`. The original `ex_orders.total`, principal, fees and reward snapshots remain intact. The remainder is a customer balance liability, never extra fee income. Statistics and profit reports label principal and post-fee entitlement separately from external payout.

| Net entitlement | External payout | Automatic balance credit |
| --- | --- | --- |
| 10,500 IQD | 10,000 IQD | 500 IQD |
| 1,600 IQD | 1,000 IQD | 600 IQD |
| 1,500 IQD | 1,000 IQD | 500 IQD |
| 600 IQD | 0 IQD; no external transfer | 600 IQD |
| 20,000 IQD | 20,000 IQD | 0 IQD; no zero-value journal |
| 0 IQD | 0 IQD; no external transfer | 0 IQD; durable approval record only |

This applies to every configured external IQD destination, including a USDT source with an IQD recipient. An external USDT recipient and AccountBalance destination are excluded. Existing pending/corrected orders follow the new rule when explicitly approved; previously approved orders without a payout settlement retain their historical amounts and receive no automatic backfill. Stored IQD entitlement must be a whole amount from 0 through 1,000,000,000; malformed or fractional values require correction rather than silent truncation. Newly entered IQD principal is whole; USDT principal may remain fractional.

The customer sees external payout and planned balance credit before submitting. **Submission alone does not credit a balance.** In admin order details, review the frozen order/version, verify incoming funds, and confirm the exact displayed transfer after making it. A zero-payout order instead shows that no external transfer is required and must not claim a payment was made. Approving uses `approve_order` with a stable UUID, `expected_updated_at`, original `expected_total`, `confirmed_payout_iqd`, `confirmed_received = true`, and `confirmed_paid = (payout_iqd > 0)`. The backend supplies the authenticated actor to service-only `ex_admin_approve_order_settlement` and performs no separate balance mutation outside that transaction.

The database checks fresh approval permission, freezes the order under a row lock, validates receipt or AccountBalance debit proof, and commits status, immutable settlement, optional remainder case, double-entry ledger, balance update and audit together. The request lock and exact payload snapshots make repeat submissions return the original result, including when the remainder is zero. Changed reuses and stale versions fail; an old tab must reopen and review the order. Direct authenticated status updates cannot bypass the settlement requirement. Automated rounding requires approval permission; later discretionary shortfall credits retain their separate refunds permission.

`ex_order_payout_settlements` records every new IQD approval, including actor, customer, policy/unit, original net, exact external payout, remainder, confirmations, proof/version snapshots and refund/journal links. `ex_orders.payout_iqd`, `payout_rounding_iqd` and `payout_settlement_id` are protected cached references. A positive remainder also creates one immutable `ex_order_shortfall_refunds` case marked `refund_source = 'payout_rounding'`, using the existing `shortfall_refund` journal kind and contributing to `shortfall_refunded_iqd`. Manual cases retain `refund_source = 'manual_shortfall'`. A 500 IQD automatic credit followed by a separately confirmed 150 IQD manual correction totals 650 IQD; it never reapplies the rounding rule or creates a second refundable pool.

Payout proof is optional at approval. For a saved positive rounded payout with no proof, the admin may attach the **first** receipt later through audited service-only `ex_admin_attach_settlement_receipt`. That append is allowed only before any additional manual shortfall credit; replacing existing proof is blocked. A zero-payout settlement has no external receipt to attach. Historical non-rounded receipt behavior remains as before.

Apply `supabase/migrations/20261017212501_rounded_iqd_payout_settlement.sql` immediately before deploying the matching approval API and UI. It performs no existing customer credit. Preserve the explicit rollback boundary of `test/exchange-rounded-payout.sql`; the synthetic fixture covers authorization, stale or conflicting retries, zero transfers, USDT-to-IQD, later manual corrections, proof attachment, direct-write guards and atomic accounting failure. It may run as a rollback-only subtransaction after DDL in the same migration transaction, forcing deferred consistency checks before discarding all fixture rows. Run Node API/helper tests and the offline browser flows before publishing; inspect the new settlement reconciliation counters alongside the existing full/partial refund counters after migration.

## Approved-order shortfall credits

Use **گەڕاندنەوەی بڕی کەم نێردراو بۆ باڵانس** in an approved order's details, or find the exact order in the admin Balance board. Enter the actual unpaid IQD amount (including small amounts such as 150) and the reason, confirm the shortfall, then review the credit before submitting. No manual verification reference is needed. The board shows the expected recipient payout, previous shortfall credits, the remaining limit, and the customer's balance before and after the proposed credit. The final saved balances come from the database transaction.

This action is separate from rejecting and refunding an entire order. It keeps the approved status, original principal, net entitlement, fee, reward usage and original payment proof intact. `ex_orders.total` is the original net entitlement after fees/rewards, before balance refunds; `ex_orders.amount` is the original principal. For a historical 10,000 IQD principal with a 9,800 IQD entitlement, sending 9,650 IQD leaves a 150 IQD shortfall. Crediting that shortfall adds exactly 150 IQD to the customer's available account balance. New exact-thousand settlements follow the automatic policy above and include the remainder in the same cumulative refund limit.

The authenticated `balance_credit_shortfall` admin action calls service-only `ex_admin_credit_shortfall`. It derives the recipient from the locked order and independently checks the acting administrator's current refund permission. Only approved IQD orders with original receipt or recorded account-balance debit proof are eligible. USDT orders and fully refunded orders are excluded. Cumulative shortfall credits cannot exceed the original expected payout. Previously credited orders cannot be changed into a full rejection refund.

Each submission carries a UUID request key and the prior cumulative refund amount shown at lookup. The API generates `shortfall:<lowercase request UUID>` as the internal reference when a manual reference is omitted or null. Valid references from older tabs remain accepted so their original submissions can still be retried. This uses the existing database function and requires no additional schema migration.

An identical retry returns the saved credit without posting again. Reusing the key with changed data fails. A stale prior refund amount fails under the order lock, so two administrators cannot both apply a credit based on the same old snapshot. Before sending, the browser saves the frozen request in session storage scoped to the administrator and order. Returning to the order after a network error or same-tab reload restores the original amount, reason, key and snapshot; these values cannot be edited while the outcome is unresolved. A lookup recovers a committed request from its audit record, or the same request can be retried with fresh confirmation. Success or a definite stale response clears that pending record. A new credit after completion still requires reviewing the latest refund history and confirming again. Audit insertion, double-entry posting, wallet update and order refund aggregate either all commit or all roll back.

`ex_order_shortfall_refunds` preserves the order/account links, request key, credited amount, reason/internal reference, acting admin, timestamp, journal link, cumulative refund snapshots and actual before/after wallet balances. The admin board includes a dedicated history, and customer wallet history labels the credit as a shortfall refund. Generated references are not presented as payment evidence; older manually supplied references remain visible in their history. Records and journal entries are append-only; customers may read only their own records and cannot perform refunds. Amounts are validated as whole IQD before conversion to the ledger's integer representation.

Apply `SUPABASE_EXCHANGE_ORDER_SHORTFALL.sql` before the new server/UI because both histories read the new table. The migration creates no customer credit. Run `test/exchange-shortfall.sql` inside its explicit rollback transaction, the Node API/UI regressions, and the build before publishing. The SQL fixture includes temporary DDL for a targeted audit-failure trigger; use a trusted migration runner and preserve its rollback boundary. It can also run inside a rollback-only subtransaction as a migration verification gate. Verify 150 IQD, idempotent replay, mismatched/stale requests, over-refunds, authorization, full-refund conflicts and atomic rollback. Both `unlinked_shortfalls` and `shortfall_amount_mismatches` from reconciliation must remain zero.

`test/exchange-shortfall-auto-reference.sql` verifies generated-reference credits, exact retries, stale requests, legacy references and detailed accounting using synthetic data inside an explicit rollback transaction. It contains no schema changes. `npm test` includes the API and UI regressions. The optional `test/exchange-shortfall.browser.mjs` exercises the real admin/customer HTML, styles and modules with synthetic responses at 390px and 1280px, including pending-request recovery after reload; it blocks external network requests. Set `PROXO_PLAYWRIGHT_MODULE` to an installed Playwright module and, if required, `PROXO_BROWSER_EXECUTABLE` to its Chromium executable. `PROXO_SHORTFALL_SCREENSHOTS` selects a screenshot directory.

## Refund amounts and PDF reports

In the admin Refund and Balance board, choose optional **from/to dates** and **داگرتنی PDFـی گەڕاندنەوەکان**. One PDF includes both credited full refunds and partial shortfall credits, with customer/admin names, order and journal IDs, reasons, credit timestamps, amounts and available recorded balance snapshots. Dates select the **refund credit's `created_at` in Asia/Baghdad**, including the entire end date; PDF timestamps also use Baghdad time. Blank dates select all available history up to the report cutoff.

The board and PDF use these accounting meanings:

| Record | Expected payout | Sent | Unpaid | Credited to balance |
| --- | --- | --- | --- | --- |
| Manual shortfall | Stored `expected_iqd` | Calculated `expected_iqd - refunded_after_iqd` | Cumulative `refunded_after_iqd` at this record | This record's `amount_iqd` |
| Automatic payout remainder | Stored original net `expected_iqd` | Exact-thousand payout, `expected_iqd - amount_iqd`; zero means no external transfer | Original net modulo 1,000 | This record's `amount_iqd`, counted once |
| Full refund with `refund_kind = 'failed_payout'` and `confirmed_payout_failed = true` | Valid matching IQD order's `total`, when available | 0 when the linked payout is available; otherwise unknown | Expected payout, when available | Refunded original principal, `amount_iqd` |
| Admin rejection or other full refund without that confirmation | Valid matching IQD order's `total`, when available | Unknown / not recorded | Unknown / not recorded | Refunded original principal, `amount_iqd` |

Full refund cases do not store the shortfall table's payout or before/after balance snapshots. Their joined order details are contextual data, not frozen refund snapshots. Missing historical amounts stay unknown; an order rejection alone does not establish how much was sent. For repeated shortfall credits, each row describes its own historical state. The PDF total sums each case's **credited amount once**; it never sums cumulative unpaid or calculated sent amounts across records for the same order.

The browser explicitly limits one PDF to **2,000 records combined across both refund types**. More records stop the export with a request to narrow the date range; no truncated PDF is saved. This is separate from the board's recent 150-record lists. The export reads its own paginated history, not the dashboard's cached rows. Empty ranges create no PDF. Duplicate records, inconsistent pages, failed reads or rendering failures stop the download rather than save a partial report.

### Read-only report API

`POST /api/admin` accepts action `balance_refund_report` with payload `{date_from?, date_to?, page: 0, snapshot?}`. Date strings use `YYYY-MM-DD`; omitted, null or empty dates are unbounded. The response contains `{refunds, shortfalls, orders, profiles, page, next_page, has_more, snapshot}`. `orders` and `profiles` are maps keyed by ID. Full cases identify the acting admin through `verified_by`; shortfalls use `admin_id`.

Each page returns up to 100 records from each table, ordered by `created_at DESC, id DESC`, with one additional row fetched to detect continuation. Full cases explicitly require `status = 'credited'`; shortfall rows are immutable committed credits. Continue until `next_page` is null, preserving the original date filters and exact canonical UTC `snapshot` returned by the first page. Pages after zero require that snapshot. Related order/profile reads use batches of at most 100 IDs, and every source and relation batch must succeed.

The backend verifies the current authenticated admin and **refunds permission on every page**; dashboard viewing keeps its existing view permission. The browser also checks account identity and permission while collecting and rendering the report and before saving. Reporting performs no financial writes and requires no new database migration.

`snapshot` is a `created_at <= cutoff` filter, **not a strict MVCC database snapshot**. A transaction started before the cutoff can commit during export and shift offset pages. The browser rejects detected duplicate IDs or inconsistent pages and asks for a fresh export; retry after concurrent refund activity settles. Absence of a detected duplicate does not establish transaction-level snapshot isolation. Related names/order details are current reads rather than historical snapshots.

`npm test` includes the amount, report API and client regressions. They cover history beyond 150 records, Baghdad date boundaries, actor ownership, pagination, permissions and failed relation batches. `test/exchange-refund-report.browser.mjs` verifies the real Kurdish PDF download with synthetic full and partial refunds, repeated credits, a long reason, complete A4 cards and mobile/desktop controls. Set the Playwright variables described above and `PROXO_REPORT_LIB_DIR` to a directory containing the existing html2canvas 1.4.1 bundle as `html2canvas.js`, jsPDF 2.5.1 as `jspdf.js`, and the site's `Rabar_021.woff2` font. `PROXO_REFUND_REPORT_OUTPUT_DIR` selects the test output directory. This test blocks all external requests.

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
