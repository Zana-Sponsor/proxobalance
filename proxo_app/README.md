# Proxo Flutter

Supabase owns authentication, data, RLS, pricing, and atomic ad creation.
FastPay still uses the bundled n8n gateway workflow because the merchant
credentials and server-to-server payment verification must never live in the
mobile app. See `docs/FASTPAY_AD_CHECKOUT_SETUP.md` before enabling checkout.

## Historical OTP migration notes

The section below documents the earlier removal of n8n from the email OTP and
account-deletion paths. It does not apply to the FastPay gateway workflow.

---

## What changed and why

| Old (n8n) | New (Supabase) | File |
|---|---|---|
| `n8nWebhookUrl` constant | Removed entirely | `main.dart` |
| `n8nOtpLoginWebhook` constant | Removed entirely | `main.dart` |
| `n8nDeleteAccountWebhook` constant | Removed entirely | `main.dart` |
| HTTP POST to n8n OTP webhook | `supabase.functions.invoke('send-otp')` | `auth_screen.dart` |
| `_notifyN8n()` analytics call | Removed (non-critical) | `auth_screen.dart` |
| HTTP POST to n8n delete webhook | `supabase.functions.invoke('delete-user')` | `proxo_sidebar.dart` |

The `otp_codes` table verification logic (`_verifyLoginOtp`, `_verifyCustomOtp`, `_doForgotVerifyOtp`) was already querying Supabase directly — **no changes needed there**.

---

## Files in this package

```
proxo_n8n_removal/
├── main.dart                               ← COMPLETE replacement (drop in)
├── patches/
│   ├── auth_screen_patches.dart           ← 6 targeted patches for auth_screen.dart
│   └── proxo_sidebar_patches.dart         ← 2 targeted patches for proxo_sidebar.dart
└── supabase/
    └── functions/
        ├── send-otp/index.ts              ← NEW: replaces n8n OTP webhook
        └── delete-user/index.ts           ← UPDATED: no n8n, handles full cleanup
```

---

## Step 1 — Add the Resend API key secret

The `send-otp` function sends emails via [Resend](https://resend.com) (free tier: 3,000 emails/month).

1. Sign up at https://resend.com — it's free.
2. Verify your sending domain (`proxopages.com`) in the Resend dashboard.
3. Create an API key.
4. Add it to Supabase:

```bash
supabase secrets set RESEND_API_KEY=re_xxxxxxxxxxxxxxxxxxxx
supabase secrets set RESEND_FROM_EMAIL=noreply@proxopages.com
```

Or in the Supabase Dashboard: **Settings → Edge Functions → Secrets**.

---

## Step 2 — Deploy both Edge Functions

```bash
supabase functions deploy send-otp    --no-verify-jwt
supabase functions deploy delete-user --no-verify-jwt
```

---

## Step 3 — Apply the SQL migration (if not already done)

From the previous delivery, run in **Dashboard → SQL Editor**:

```sql
-- Add ON DELETE CASCADE to FK constraints
-- Add SQL trigger handle_user_deletion() for belt-and-suspenders cleanup
-- (see supabase/migrations/20240601000000_add_cascade_deletes.sql)
```

Also make sure the `otp_codes` table has a `user_id` column (nullable):
```sql
-- If otp_codes doesn't yet have user_id, add it:
ALTER TABLE public.otp_codes ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL;
```

---

## Step 4 — Replace main.dart

Drop `main.dart` from this package directly into `lib/main.dart`.  
The 3 n8n URL constants are removed. No other changes.

---

## Step 5 — Apply auth_screen.dart patches

Open `patches/auth_screen_patches.dart` and apply each numbered patch:

| Patch | What | Where in your file |
|---|---|---|
| **1** | Change import line | ~line 12 |
| **2** | Replace `_requestOtp()` body | ~lines 308–340 |
| **3** | Replace `_sendLoginOtp()` body | ~lines 342–358 |
| **4** | Delete `_notifyN8n()` function | ~lines 392–397 |
| **5** | Replace `_n8nErrLabel()` with `_errLabel()` | ~lines 409–435 |
| **6** | Find & replace call sites | Multiple locations |

Patch 6 details:
- **6A**: Delete the line `_notifyN8n('email_verified', {...})` (~line 636)
- **6B**: Replace all `${_n8nErrLabel()}` → `${_errLabel()}` (5 places: `_doLogin`, `_doRegister`, `_resendOtp`, `_doForgotSendOtp`, `_resendFpOtp`)
- **6C**: The `http` package import can stay or be removed — `_verifyLoginOtp` and `_verifyCustomOtp` don't use it, but check the rest of your file first.

---

## Step 6 — Apply proxo_sidebar.dart patches

Open `patches/proxo_sidebar_patches.dart` and apply each numbered patch:

| Patch | What | Where in your file |
|---|---|---|
| **1** | Change import line | ~line 16 |
| **2** | Replace entire `_doDelete()` method | ~lines 600–706 |
| **3** | Optionally remove `http` import if unused | ~line 8 |

---

## How the new `send-otp` function works

```
Flutter app
    │ supabase.functions.invoke('send-otp', body: {email, purpose, name, user_id})
    ▼
send-otp Edge Function
    ├── Invalidates any old unused codes for same email+purpose
    ├── Generates fresh 6-digit code
    ├── Inserts into otp_codes table (expires in 10 min)
    └── Sends styled HTML email via Resend API
         └── User receives code in inbox
              └── Flutter verifies against otp_codes table (unchanged)
```

---

## Verification checklist

- [ ] `supabase functions list` shows `send-otp` and `delete-user` as deployed
- [ ] `supabase secrets list` shows `RESEND_API_KEY` and `RESEND_FROM_EMAIL`
- [ ] Registration sends OTP email via Resend (check Resend dashboard logs)
- [ ] Login OTP works (code arrives in email, verification succeeds)
- [ ] Forgot password OTP works
- [ ] Account deletion immediately frees the email for re-registration
- [ ] No n8n references remain in the codebase (`grep -r "n8n" lib/`)
