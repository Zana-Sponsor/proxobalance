# OTP repair status — 2026-10-16

## Result

The source repair is ready and its security workflow passed. Production has a verified, limited access-control mitigation. The coordinated migration, Edge deployment and n8n replacement are **not complete**.

- Tested source: [`44f1921`](https://github.com/Zana-Sponsor/proxobalance/commit/44f1921912e5d07286db838585a74822d34324d8).
- Passing verification: [GitHub run 38834723152](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38834723152).
- PR #7 remains Draft/Open/Unmerged. No unrelated production release was made.

## Verified live changes

For Supabase project `cojchkwssmasiejcgvbk`:

| Surface | anon / authenticated | service_role |
|---|---|---|
| `get_or_generate_otp_whatsapp(text,text)` | Execute denied | Execute retained |
| `verify_otp_whatsapp(text,text)` | Execute denied | Execute retained |
| `record_otp_whatsapp_send(...)` | Already denied; rechecked | Execute retained |
| `otp_whatsapp` | All direct privileges revoked; read denial rechecked | SELECT, INSERT, UPDATE retained |

OTP table RLS remains enabled. A scoped expiration of unused, unexpired legacy proofs affected **zero rows**; no account or audit row was deleted. These permission changes do not install the new OTP logic, repair an incorrect credential binding or revoke an exposed service credential.

## Source fixes and evidence

- Reserved OTPs use cryptographic randomness, five-minute expiry, a 60-second cooldown and five sends per hour across purposes. Per-phone database locking serializes first sends.
- Verification is single-use, purpose-bound and locks after five wrong codes. The old service-only login verifier delegates to the new verifier during rollout, including safe NULL handling.
- The first migration transition expires legacy proofs; replay preserves newly issued secure proofs.
- Malformed and expired reservations terminate before the provider request. Provider acceptance and recorded delivery IDs are checked; responses do not expose OTPs.
- Both Edge handlers preserve canonical `pa_profile_by_phone` lookup, reject ambiguous login matches and existing signup matches, normalize the observed phone variants and reject non-string codes.
- supabase-js is pinned to 2.118.0.
- The import candidate has 33 nodes, no saved credential bindings or secrets, `active=false`, empty pinned data and execution-data saving disabled. Its structure passed validation. This is not a runtime verification of the published workflow.

Verification on the tested source:

| Check | Result |
|---|---|
| Actual workflow expressions and Edge handlers with intercepted transports | 20/20 pass |
| PostgreSQL 17 migration applied twice | Pass |
| Replay preserves a newly issued proof | Pass |
| OTP expiry, attempts, reuse, purpose, privileges, RLS and consent audit | Pass |
| Two independent concurrent database requests | Pass |
| Deno type checks of both Edge handlers and pinned imports | Pass |

No real WhatsApp message was sent. The invalid-input HTTP probes received a non-JSON 403 through the execution environment; those responses are **not** evidence of the n8n webhook's behavior.

## Blockers and unchanged live components

1. The Supabase `apply_migration` operation returned `Invalid or expired requestState`. Read-after-error and the final catalog check confirmed `pa_verify_whatsapp_otp`, `pa_finish_whatsapp_otp_send` and the consent table are still absent. No DDL was sent through the raw query tool as a workaround.
2. n8n was reached through secure sign-in, and the reviewed workflow was Published. Reserve OTP showed the correct project URL and a credential named `Custom Auth account 2`. The browser subsequently refused observation because native credential state could not safely resume. The supported reset did not restore access. The active export, remaining bindings, full graph and node settings remain unverified; no n8n edit was made.
3. `phone-otp-session` was not deployed. `whatsapp-session-exchange` remains the observed version 2; neither handler was replaced.
4. Rotation of the previously exposed Wevlix and Supabase server credentials is unresolved. Replacement must be coordinated with every actual consumer; do not publish or paste secret values into chat, source or exports.

## Resume the rollout

Restore the supported Supabase migration connection and a fresh, authorized n8n browser runtime. Existing user authorization covers the scoped OTP repair; credentials should be entered only through secure sign-in or the service's secret/credential manager.

1. In a coordinated maintenance window, stop conflicting public workflow paths and preserve the current workflow export securely for rollback.
2. Rotate the exposed server credentials and update their actual consumers. Use a Wevlix development key for simulated delivery checks.
3. Apply [the reviewed migration](../proxo_app/supabase/migrations/20261015215145_whatsapp_auth_consent.sql) through the supported migration pathway. Verify the new RPCs, service-only execution and consent RLS before changing callers.
4. Deploy [phone-otp-session](../proxo_app/supabase/functions/phone-otp-session/index.ts) and [whatsapp-session-exchange](../proxo_app/supabase/functions/whatsapp-session-exchange/index.ts) to this same project. These public endpoints perform their own OTP authentication; raw OTP RPCs stay service-only.
5. Import the inactive, credential-free workflow candidate. Bind the following credentials in n8n:

| Nodes | Credential |
|---|---|
| Reserve OTP; Record delivery; Verify code; Read new account | HTTP Custom Auth: Supabase server `apikey` plus `Authorization: Bearer <service-role-JWT>` |
| Send OTP template; Read delivery; Send account template | HTTP Header Auth: Wevlix `X-API-Key` |
| Status webhook; Verify webhook; Account webhook | Separate unpredictable internal HTTP Header Auth |

6. Check the imported graph for duplicate edges; confirm execution logging stays disabled, URLs target this project and the public send path has per-source abuse controls at the reverse proxy. Importing a file does not configure those proxy controls.
7. Exercise the complete flow using simulated delivery: first send, cooldown, resend, invalid/expired/reused code, purpose isolation, signup and login. Confirm a real Supabase session is created only after the corresponding proof succeeds. Verify all three internal routes reject missing credentials.
8. Publish only the reviewed replacement with the old conflicting paths stopped. A real delivery test additionally needs a specifically authorized test recipient.
9. Record the applied migration version, deployed Edge versions and published n8n workflow version before marking the repair complete.

If rollout fails, stop the replacement ingress and restore compatible callers from the securely retained version. Keep the public OTP permission revocations. Do not reopen raw OTP access or restore the vulnerable verifier merely to make an old caller work.
