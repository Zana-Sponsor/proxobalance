# Proxo Auth Final V1 — release steps

This project now has three Auth presentation screens coordinated by one shared
state owner:

- `lib/screens/auth/login_screen.dart`
- `lib/screens/auth/signup_screen.dart`
- `lib/screens/auth/otp_screen.dart`
- `lib/screens/auth/auth_shell.dart` (state/navigation coordinator)
- `lib/screens/auth/auth_service.dart` (network and Supabase boundary)

## 1. Apply the database migration

From the linked Supabase project, run:

```bash
supabase db push
```

The migration `20260921120000_phone_only_signup_profiles.sql` makes
`profiles.email` nullable for phone-only users. Existing email profiles and
their sessions are not changed.

## 2. Deploy the phone registration function

```bash
supabase functions deploy phone-otp-session --no-verify-jwt
```

The function validates and consumes the WhatsApp OTP before creating the Auth
user/profile. It returns a one-time magic-link token hash; the Flutter client
redeems that hash to establish the session only after verification.

The existing `whatsapp-session-exchange` function remains the login path for
existing phone users and must stay deployed.

## 3. Verify the OTP workflow contract

The configured Wevlix endpoint must accept:

```json
{
  "phone": "+9647501234567",
  "purpose": "signup",
  "clientMessageId": "proxo-...",
  "locale": "ckb"
}
```

Supported `purpose` values are `login`, `signup`, and `reset_password`.
Server-side resend, expiry, attempt, and abuse limits remain the source of
truth; the 60-second Flutter countdown is presentation only.

## 4. Generate localization output and dependencies

```bash
flutter pub get
flutter gen-l10n
```

The selected Kurdish/Arabic locale is persisted with SharedPreferences and is
applied without recreating the Supabase client or clearing the current form.

## 5. Run quality gates

```bash
flutter analyze
flutter test
flutter build apk --release
```

The Auth tests cover phone normalization, duplicated country codes, masking,
visual-only Login CTA readiness, strong Sign Up validation, OTP paste and
backspace lifecycle, controller/focus disposal, and a 320dp-width overflow
case.

## 6. Manual device matrix

Verify on at least one 320–360dp Android device and one standard/tall device:

1. Login by existing email and password, then email OTP.
2. Login by existing phone, then resend and verify WhatsApp OTP.
3. Sign up with Name + Iraqi phone + strong password + confirmation.
4. Confirm that no Auth session exists before the Sign Up OTP succeeds.
5. Enter a wrong/expired code, resend, paste six digits, and use Back.
6. Open the keyboard on Login, Sign Up, and OTP; confirm no clipping/overflow.
7. Switch Kurdish/Arabic and relaunch; confirm the selection persists.
8. Reset an existing email user's password using the same strong policy.
9. Add/change a real email later through the existing verified Profile flow.

Do not release until the migration and Edge Function are deployed together;
the client expects phone-only profiles to permit a null public email.
