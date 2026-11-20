# Proxobalance OTP Registration Security Audit & Fix

- **Date:** 20 November 2026
- **Repository:** `Zana-Sponsor/proxobalance`
- **Scope:** customer registration, super-admin account creation, email/WhatsApp OTP verification, Supabase Auth creation paths, production Auth configuration, logging, and the supplied v59 ZIP changes.

## Executive outcome

The repository’s customer and administrator registration flows now require server-side OTP verification before their privileged Supabase Auth user-creation calls. The v59 changes were reconciled without restoring browser-side Auth signup or OTP verification. A second, separate Android registration Edge Function was also corrected: it previously called a login-only OTP wrapper and now verifies the `signup` purpose explicitly.

**Production is not fully closed to direct signup yet.** The live `Exchange` project’s public Auth settings endpoint reports `disable_signup=false` (new Auth users are allowed). A caller with the public anon key may therefore still attempt direct Supabase Auth signup outside the application flow. I did not send a signup probe because it could create a real account. No production Auth setting, migration, or Edge Function was changed or deployed in this task.

## Findings and fixes

1. **Customer registration bypass surface.** The customer UI now sends registration start/finish requests to `/api/auth`. The server validates the phone OTP with the `signup` purpose, or the email OTP with the required purpose, before calling the Supabase Admin user endpoint. The v59 customer bundle was checked and contains no `supabase.auth.signUp()` call, direct `/auth/v1/signup` call, or browser-side email OTP verifier RPC. The browser no longer decides whether an OTP is valid.

2. **Super-admin account creation.** The admin-create-user Edge Function now requests the existing email OTP through the n8n webhook and verifies that OTP server-side for the exact email and `signup` purpose before `auth.admin.createUser()`. OTP failure, omission, or service failure exits before account creation. The v59 admin modal’s misleading “OTP not required” message was removed and replaced with the OTP request/code controls required by the server function. The service-role key remains server-side.

3. **OTP hardening migration.** `supabase/migrations/20261118150000_harden_otp_registration.sql` hardens issuance and verification: it serializes issuance, binds a code to its phone/email and purpose, enforces expiry and single use, locks the OTP row during verification, limits issuance, counts failed attempts, and restricts the verifier RPCs to `service_role`. The phone issuance limits in the migration are three codes per phone in ten minutes and ten per IP per hour; email code issuance is capped at three per email/purpose in ten minutes with one live code at a time. Existing n8n email delivery request format is preserved.

4. **Separate Android registration path.** `proxo_app/supabase/functions/phone-otp-session/index.ts` previously invoked `verify_otp_whatsapp(p_phone, p_code)`. The live wrapper hard-codes purpose `login`, so it did not enforce registration-purpose binding. The function now calls `pa_verify_whatsapp_otp` with `p_purpose: "signup"` before Admin Auth creation. The live Zana database verifier was inspected read-only: it matches phone and purpose, requires an unused unexpired row, serializes verification with `FOR UPDATE`, increments failed attempts and blocks after five, and marks a successful code used in the same transaction. Its execute privilege is limited to `service_role` (not `anon` or `authenticated`). The existing login route remains separate.

5. **Logging.** Customer OTP failures and provider errors are logged without the submitted code, password, or full phone/email target. New admin function logs use coarse stage/status identifiers and do not include OTP values or secrets. Regression tests assert that rejected OTP events do not leak the phone or submitted code.

6. **v59 merge and cache invalidation.** The v59 source updates and added tests/migrations were incorporated. The three overlapping files were resolved in favor of v59 where appropriate, while preserving the OTP safeguards. The customer bundle URL is `app.js?v=109` and the admin bundle URL is `admin.js?v=41`; the smoke workflow and its test were updated to wait for those exact versions. The Vercel build script regenerates `public/` from the root sources, so generated public output is not intended to be committed wholesale.

## Production checks and remaining action

Read-only checks of the live `Exchange` project confirmed that `ex_auth_code_check` and `ex_verify_otp` are executable by `service_role` only, and their current definitions include row locking, purpose binding, expiry checks, and attempt tracking. The live `ex_otp_codes` table also has the one-live-code trigger. The new migration’s version is not present in Supabase migration history, so this task did not apply it; do not treat the repository migration file as deployed.

The live Auth setting `disable_signup=false` remains the material blocker. The application’s legitimate registration paths use server-side Admin APIs, so disabling **public** signup is compatible with those code paths and does not disable Admin API account creation. To close the direct Supabase bypass, disable “Allow new users to sign up” in the authenticated Supabase Dashboard for the `Exchange` project. The separate mobile `Zana` project’s Auth setting was not verified in this task; check and disable public signup there as well if that project remains in use. Do not claim the production bypass is closed until the setting is confirmed and the relevant Edge Functions/migration are deployed.

## Test results

- **Build:** `npm run build` passed; generated `public/index.html` and verified 63 referenced assets. The built output contains `app.js?v=109`, `admin.js?v=41`, and the OTP field in the admin account-creation modal.
- **Focused OTP + v59 regression suite:** 87/87 passed across the authentication, hardening, wallet/OTP, and v59-related test files.
- **OTP-focused subset:** 34/34 passed. Coverage includes valid, incorrect, expired, missing, and replayed registration OTPs; repeated failures; privacy-safe logging; and concurrent verification allowing at most one account creation. Static regression checks cover browser bypass absence, admin OTP ordering, mobile signup-purpose binding, and database grants/locking.
- **Full suite:** 317/403 passed; 86 failed in broader refund/admin/report/settlement/shortfall and related legacy areas. No OTP or Auth-registration test failed. These broader failures were already present before the v59 merge (the inherited run was 296/384 with 88 failures) and remain unresolved/out of scope here.
- **Syntax/lint:** `node --check` across source API handlers and browser JavaScript passed; `npm run lint` passed. Deno was unavailable in the sandbox, so the TypeScript Edge Function was not compiled locally.

## Deployment status

This report records repository work and read-only production inspection only. No Supabase migration was applied, no Edge Function was deployed, no production Auth setting was changed, and no direct signup probe was sent. The GitHub push and its commit SHA are reported separately after the final diff review.
