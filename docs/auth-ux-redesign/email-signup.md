# Email API routes and signup verification

Email delivery uses the configured custom API **`https://email.proxopages.com/webhook/send_otp`**. Supabase stores identities, profiles and sessions and executes the existing verification RPCs. The previous draft incorrectly switched signup OTP delivery to Supabase-native email; that change and its email-template instructions have been removed. No Auth provider settings were changed.

## Route audit

| Operation | Request | Verification / completion |
|---|---|---|
| Email login | Custom API `POST {email}` after `pa_login_attempt` validates credentials | `pa_verify_login_otp(p_email,p_code)`, then password sign-in; returning users enter `AuthenticatedGate` |
| Email signup | Supabase `auth.signUp` creates the identity; its provisional session is signed out locally. Custom API receives `{action:"request_otp",purpose:"signup",email,name,user_id}` | `pa_verify_login_otp` must return `valid:true`; `proxo_confirm_email(p_user_id)` must succeed; password sign-in then opens `AccountSetupGate` |
| Signup resend | Same custom API and `request_otp` signup payload | Screen cooldown remains active; no Supabase-native `/resend` request |
| Password recovery | Existing custom `request_otp` request with `purpose:"reset_password"` | `pa_verify_reset_otp`, then `proxo_reset_password` with user-bound OTP proof |
| Email change in Profile | Custom API authenticated actions `request_email_change {new_email}` and `verify_email_change {request_id,code}` | Existing workflow confirms the new email; this route was inspected and retained |
| Phone login | Existing WhatsApp API | `whatsapp-session-exchange`; unchanged by the email correction |

The URLs are defined in [`main.dart`](../../proxo_app/lib/main.dart). Signup, login OTP and resend use [`AuthService`](../../proxo_app/lib/screens/auth/auth_service.dart); screen state and recovery remain in [`AuthShell`](../../proxo_app/lib/screens/auth/auth_shell.dart). Email-change requests are in [`ProfileScreen`](../../proxo_app/lib/screens/profile_screen.dart).

## Failure and retry handling

- The unified name/email/password/confirmation form opens a separate OTP screen only after the custom API accepts the send. Back retains the form values.
- Email is trimmed and lowercased. The custom send contains the created Auth user ID, required by the existing confirmation proof.
- HTTP errors, timeouts and explicit `success:false` / `ok:false` responses do not advance to OTP. The existing API's empty/plain successful responses remain compatible.
- A failed delivery can be retried with the same email/password without creating the identity again. Pending credentials exist only in memory and are cleared when the service closes or verification succeeds.
- Once the identity exists, changing its password is not a password update: the server's duplicate-account error is shown and the user can use the existing login/recovery screen. The original registration name remains the identity metadata; profile editing is available after entry.
- Invalid/expired OTP never calls confirmation or sign-in. Confirmation errors are not swallowed. Its server function requires fresh, consumed OTP proof bound to both user ID and email.
- Completed verification stages are retained for the same email/user/code/password while the screen is alive. A transient confirmation failure retries confirmation; a sign-in failure after successful confirmation retries sign-in. Resend invalidates the cached stage.
- If confirmation committed but its response was lost, the client cannot infer success: a fresh OTP is required. A local success flag never replaces a successful confirmation response.
- Signup OTP attempts use the existing in-memory rate limiter; it is a UI guard, not a replacement for server rate limits.

## What was verified

The repository contracts and the live definitions of `pa_verify_login_otp` and `proxo_confirm_email` were inspected. The latter consumes a used OTP bound to the target identity/email and created within 15 minutes. The live profile-creation trigger copies `full_name` and email. The current `mailer_autoconfirm:true` setting is compatible with the existing custom-mail arrangement; it is **not** a reason to switch mail providers or enable Supabase confirmation emails.

Mock HTTP regressions verify exact routes, bodies, ordering, delivery rejection/retry, provisional-session signout, invalid OTP, confirmation failure, retry stages, resend and final session. Fixtures reject unexpected Supabase-native `/verify` and `/resend` calls. The widget regression exercises form → OTP → Back with preserved values. See [`auth_email_signup_test.dart`](../../proxo_app/test/auth_email_signup_test.dart), [`auth_refresh_test.dart`](../../proxo_app/test/auth_refresh_test.dart), and [test log](email-api-tests.log).

**Live email delivery has not been exercised.** No account was created and no email was sent. The current n8n workflow is not checked into this repository, so its runtime handling of `purpose:"signup"` and `user_id` still needs an end-to-end check with an address controlled by the owner. The implementation follows the application's existing request/verification contracts; the account-creation ordering is a reconstruction for the new email signup form, not a recovered historical flow. Existing Supabase Auth policy remains unchanged; the app's OTP gate is not a claim that direct Auth API signup is server-enforced MFA.
