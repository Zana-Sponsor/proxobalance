# Proxo Balance: controlled refund and IQD balance runbook

## Release order
1. The additive **Exchange** Supabase migrations have been applied. Existing order amounts, receipts, customers and production balances were not changed. Keep the new GitHub PR Draft until preview and finance review complete.
2. Deploy the new server and UI together after review. The updated Vercel build copies `exchange-admin.html` from the repository root and `assets/` into `public/`.
3. Confirm `/api/balance` rejects anonymous users and that the admin balance actions reject non-admins. Test two concurrent payout requests and a rejected duplicate refund on staging.
4. Reconcile banking statements with every refund's `bank_verification_reference`. Only credit a verified receipt whose outbound transfer failed. The credited amount is always the original IQD `ex_orders.amount`, never a client-supplied number.
5. Leave `ex_balance_config.payouts_enabled = false` until regulatory, safeguarding, settlement and operational approvals are complete. **Do not turn on the flag merely to make the button clickable.** A payout is always manual: verify recipient ownership and make the real transfer first, then record the unique transfer reference and actual receipt.
6. Run `ex_admin_balance_reconcile(admin_uuid)` with the connected service-role backend. The admin board shows journal, balance, held-funds and refund inconsistencies. Any mismatch requires a finance review before further disbursement.
7. Keep original proof images and ledger records under the retention policy. The ledger, refund cases and their entries are append-only; correction requires a new audited operation.

## Controls
- New orders must use the authenticated `/api/orders` endpoint. `SUPABASE_EXCHANGE_SERVER_ONLY_ORDERS.sql` removes legacy table and column INSERT grants that would otherwise let customers submit their own total and bypass wallet/rate/receipt checks. It preserves customer history reads, existing admin note/receipt updates and trusted server writes. Verify with `test/exchange-order-permissions.sql`.
- Service-only Postgres RPCs implement double-entry postings inside transactions; row locks protect against concurrent overspending.
- Authenticated customers can read only their own balances, ledger, refund cases and payout requests. They cannot directly INSERT/UPDATE/DELETE those tables.
- The user sees the balance and requests manual payout only inside the Send section.
- No external wallet is paid automatically, no real refund is issued by a migration or test, and none of the tests enable payouts permanently.
- `ex_balance_risk_alerts` records repeated payout attempts, overdraft attempts and suspicious duplicate refund requests.
- The admin can cancel a pending payout to release held money. Paid or cancelled payouts cannot be reversed by repeating that action.
- A credited order is marked with its refund case and time; its amount, receipt, route and status are thereafter protected against modification.
- Redeemed fee-discount/free-transaction rewards are restored once when their order is refunded.

## Sample read-only reconciliation
```sql
select sum(delta_iqd) from public.ex_balance_entries group by journal_id
having sum(delta_iqd) <> 0;
```
This must return **zero rows**. Also inspect the full result of `ex_admin_balance_reconcile` from an authorized service backend.

## Release limitations
- Only IQD-to-IQD orders can be credited to the internal IQD balance. USDT and already approved/payout-completed orders require separate human reconciliation and do not use the auto-credit workflow.
- A submitted sender receipt is not proof the business actually received funds. An admin must independently verify the actual incoming settlement and failed outbound transfer.
- Wallet payouts remain disabled by default. When enabled after approval, a customer can request a configured receive wallet, but an admin manually checks wallet ownership, transfer proof and reference.
- The current payout list shows recent records; the database stores all financial entries permanently. The connected application does not autonomously move money between external wallets.
- Remaining live browser/UI verification and any outstanding security advisor findings outside this feature must be reviewed before merging and rollout.
