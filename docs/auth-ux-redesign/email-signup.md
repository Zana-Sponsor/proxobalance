# Email signup rollout

The revised form collects the name, email, password and password confirmation together. It sends one Supabase Auth signup request. After that succeeds, the separate OTP screen verifies the **signup** token for that email. Back restores the four field values. Email and phone login retain their existing services.

## Live inspection — 2026-10-18 UTC

The connected project `cojchkwssmasiejcgvbk` is active. A read-only request to its public Auth settings returned `disable_signup: false`, `external.email: true`, and **`mailer_autoconfirm: true`**. Email signup is enabled, but **Confirm email is disabled**. This is a release blocker for the code-based email signup flow: the app deliberately signs out an unexpectedly auto-confirmed session and reports the configuration problem.

The live `on_auth_user_created` trigger calls `public.handle_new_user`, which copies `raw_user_meta_data.full_name` and the email into `public.profiles`. This was inspected without creating or reading any user accounts.

The connected Supabase tools expose database and Edge Function operations, but no hosted Auth configuration or email-template update operation. SMTP, template contents and OTP length therefore remain unverified. No live signup request or email was sent. Separately, the notification function's icon/color update was deployed; it does not change Auth settings.

## Required server settings before release

1. In [Auth email provider settings](https://supabase.com/dashboard/project/cojchkwssmasiejcgvbk/auth/providers), keep email signup enabled and turn on **Confirm email**. Keep the email OTP length at **6 digits**, matching the existing Auth OTP input.
2. In Auth → Email templates → Confirm signup, apply [`confirm-signup.html`](../../proxo_app/supabase/templates/confirm-signup.html). Its `{{ .Token }}` placeholder displays the code; a template containing only a confirmation link would not satisfy this screen.
3. Verify the project's SMTP sender and delivery configuration. These account-level settings cannot be inferred from the repository and were not changed here.
4. On staging, register an address you control; check that the code arrives, a wrong/expired code cannot sign in, a correct code opens account setup, and resend supplies a new usable signup code. Confirm the inspected profile trigger's behavior with that test account.

Until these settings and delivery are confirmed, the email signup flow is **not verified against the live service**. An unexpectedly auto-confirmed session is signed out locally and the UI does not continue into the account.

## Implementation and offline checks

- `AuthService.beginEmailSignup` uses `auth.signUp(email, password, data)` with normalized email and full-name metadata.
- `verifyEmailSignup` uses `auth.verifyOTP` with the signup purpose, email and token. It must return a user **and** a session before navigation. No legacy `proxo_confirm_email` RPC is used by this flow.
- Resend uses `auth.resend(type: OtpType.signup)`, with the existing screen cooldown and error handling.
- The email form no longer asks for phone-only WhatsApp marketing consent. Existing phone login and backend phone functions remain available.
- Mock HTTP tests exercise request bodies, PKCE storage, invalid/valid OTP, resend rate limiting and the auto-confirm configuration guard. A widget test exercises the real unified form → OTP → Back transition and value retention. No real account was registered by the tests.

## Reference

- [Supabase Flutter signUp](https://supabase.com/docs/reference/dart/auth-signup)
- [Supabase Flutter verifyOTP](https://supabase.com/docs/reference/dart/auth-verifyotp)
- [Supabase email templates](https://supabase.com/docs/guides/auth/auth-email-templates)
