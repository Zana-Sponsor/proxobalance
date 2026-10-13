# FastPay ad checkout setup

The Flutter app contains two authenticated checkout purposes behind one
endpoint:

- `ad_checkout`: n8n ignores any phone-supplied price and calls
  `pa_quote_ad_checkout` with the authenticated user and ad draft.
- `wallet_deposit`: the customer chooses the top-up amount, but the user ID
  still comes only from the verified Supabase access token.

## 1. Apply the database migration

Apply `supabase/migrations/20260913210000_fastpay_ad_checkout.sql` through your
normal Supabase migration pipeline. The migration adds payment/device/note
fields to `pa_ads`, creates immutable `pa_transaction_events`, and replaces
`pa_create_ad` with the atomic balance/FastPay-aware implementation.

Do not expose the service-role key in Flutter. The public/publishable key may be
used by the app only with RLS enabled; the n8n workflow is the only component
that should hold the service-role credential.

## 2. Replace the n8n workflow

Import `n8n/workflows/FastPay Checkout (Supabase) v12.json` as the replacement
for the old FastPay workflow. Re-select all placeholder credentials:

- `RESELECT_FASTPAY_STORE_CREDENTIALS`
- `RESELECT_FASTPAY_REFUND_WEBHOOK_AUTH`
- `RESELECT_SUPABASE_SERVICE_ROLE`
- `RESELECT_SUPABASE_PUBLISHABLE_KEY`
- `RESELECT_TELEGRAM_SECURITY_ALERTS`, if alerts are wanted

Then activate the workflow and confirm these production webhooks:

- `POST /webhook/fastpay/order-create`
- `POST /webhook/fastpay/order-status`
- `POST /webhook/fastpay/ipn`

The first two require `Authorization: Bearer <Supabase access token>`. The IPN
route must be configured in the FastPay merchant panel and is verified against
FastPay server-to-server before a transaction becomes `PAID`.

Rotate any FastPay store or refund secret that was previously pasted into an
exported JSON file. The bundled workflow contains credential placeholders only.

## 3. Configure the app callback

The callback scheme is `appfpclientProxo` with host `fast-pay.cash`. Android is
configured in `android/app/src/main/AndroidManifest.xml`; iOS is configured in
`ios/Runner/Info.plist`. The FastPay launch URI uses `appFpp` and sends
`clientUri=appfpclientProxo`.

When the app resumes, Flutter immediately checks `order-status`. It also keeps
polling while the payment sheet is open. A return to the app is never treated
as proof of payment by itself.

## 4. Acceptance checks

1. Choose no payment method: submission must show a validation error.
2. Pick a past date or an earlier time today: submission must be rejected in
   Flutter and again by `pa_create_ad`.
3. Start FastPay: the QR, logo, progress state, and open-app button appear.
4. Return without paying: no row is created in `pa_ads`.
5. Pay an incorrect amount: the transaction must not become usable for an ad.
6. Pay the server-quoted amount: `pa_transactions` becomes `PAID`, an event is
   written to `pa_transaction_events`, and only then can `pa_create_ad` insert
   the ad and link the payment.
7. Reuse the same transaction for another ad: `FASTPAY_ALREADY_USED` is
   returned.
