# Email signup rollout

The revised form collects the name, email, password and password confirmation together. It sends one Supabase Auth signup request. After that succeeds, the separate OTP screen verifies the **signup** token for that email. Back restores the four field values. Email and phone login retain their existing services.

## Server settings before release

This change is prepared in GitHub; it does **not** modify the live Supabase project or send live emails.

1. In the project's Auth email provider settings, enable email signup and **Confirm email**. Keep the email OTP length at **6 digits**, matching the existing Auth OTP input.
2. In Auth → Email templates → Confirm signup, apply [`confirm-signup.html`](../../proxo_app/supabase/templates/confirm-signup.html). Its `{{ .Token }}` placeholder displays the code; a template containing only a confirmation link would not satisfy this screen.
3. Verify the project's SMTP sender and delivery configuration. These account-level settings cannot be inferred from the repository and were not changed here.
4. On staging, register an address you control; check that the code arrives, a wrong/expired code cannot sign in, a correct code opens account setup, and resend supplies a new usable signup code. Check that the existing profile trigger persists the `full_name` metadata for email accounts.

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
