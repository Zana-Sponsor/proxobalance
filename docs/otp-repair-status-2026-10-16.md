# OTP repair status — 2026-10-16, resumed rollout

## Result

The reviewed database repair and both Edge handlers are deployed and verified. The user has now supplied a specific recipient and authorized one OTP delivery test. That single request returned HTTP 403; no OTP reservation was recorded. The complete published n8n workflow and real WhatsApp delivery remain unverified because browser access is still blocked.

- Core tested source: [`44f1921`](https://github.com/Zana-Sponsor/proxobalance/commit/44f1921912e5d07286db838585a74822d34324d8).
- Passing source verification: [GitHub run 38834723152](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38834723152).
- PR #7 remains Draft/Open/Unmerged. These are scoped OTP production changes, not an unrelated ProxoLink release.

## Applied database changes

The earlier `Invalid or expired requestState` failure cleared on the resumed request. Both operations succeeded through the supported `apply_migration` pathway, and their migration-history entries were read back.

| Repository migration | Applied live version | Name |
|---|---|---|
| `20261015215145_whatsapp_auth_consent.sql` | `20261016012937` | `whatsapp_auth_consent` |
| `20261016013530_pin_whatsapp_phone_lookup_search_path.sql` | `20261016013607` | `pin_whatsapp_phone_lookup_search_path` |

The MCP migration pathway assigned the live versions. This mapping is retained for future migration-history reconciliation; no history entries were manually forged or edited.

The new verifier, delivery recorder and consent tables exist. Catalog checks confirm:

| Surface | anon / authenticated | service_role |
|---|---|---|
| OTP generator, new verifier, compatibility verifier and delivery recorder | Execute denied | Execute allowed |
| `otp_whatsapp` and consent audit events | Direct access denied | Required server access retained |
| Marketing preferences | Anonymous access denied; authenticated SELECT uses owner RLS | Server writer allowed |
| Canonical phone/profile lookup | Profile lookup remains service-only | Canonical matching retained |

RLS remains enabled. OTP functions use SECURITY INVOKER and an empty search path. The phone normalizer and canonical profile lookup now also pin their search paths, with unchanged function bodies and grants. The legacy login verifier delegates to the purpose-bound verifier and rejects NULL proofs.

The first transition invalidates outstanding legacy proofs. Migration replay preserves newly issued secure codes. The earlier permission-only mitigation's expiration statement affected zero eligible rows; that count should not be interpreted as a row count returned by the subsequent full migration.

## Deployed Edge handlers

| Function | Live version | State | Read-back source |
|---|---|---|---|
| `whatsapp-session-exchange` | 3 | ACTIVE | Exact match to reviewed source |
| `phone-otp-session` | 1 | ACTIVE | Exact match to reviewed source |

Both endpoints perform their own OTP authentication, so gateway JWT verification remains disabled intentionally. Raw OTP RPCs remain service-only. Both handlers pin supabase-js to 2.118.0, reject non-string codes, preserve canonical phone matching and reject ambiguous or conflicting account matches.

## Verification actually performed

| Check | Result |
|---|---|
| Actual workflow expressions and Edge handlers with intercepted transports | 20/20 pass |
| PostgreSQL 17 migration replay, privileges, RLS, OTP lifecycle and consent audit in GitHub | Pass |
| Two independent concurrent database requests in GitHub | Pass |
| Deno type checks with pinned SDK imports | Pass |
| Live reservation contract and persisted reservation before delivery | Pass |
| Live cooldown, resend accounting and five-send limit across purposes | Pass |
| Live wrong-purpose, NULL, expired and reused proof rejection | Pass |
| Live five-wrong-attempt lock and locked-code resend rejection | Pass |
| Live delivery-record success and stale-send rejection | Pass |
| Live compatibility login verifier | Pass |
| Live canonical phone normalization and service-only lookup after search-path hardening | Pass |
| GET to each deployed Edge HTTP endpoint | HTTP 405, `method_not_allowed` |
| Malformed-phone / NULL-code POST to each deployed Edge endpoint | HTTP 400, `bad_request` |

The live OTP lifecycle checks ran in a transaction as `service_role`. Existing-row collision guards ran first; the OTP table had no external triggers. The transaction was rolled back, and a final query confirmed no fixture rows remained. No proof was printed, no user was created and no provider message was sent.

The source CI run predates the two-line phone-helper search-path migration. That small hardening change has its own successful live catalog and canonical-behavior checks; the report does not represent the earlier CI as covering a later file.

Security advisors were rerun. The phone normalizer's mutable-search-path warning disappeared. Remaining OTP-related notices were reviewed:
- [RLS enabled without policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) is intentional for the service-only OTP and append-only audit tables; public grants are revoked.
- [Authenticated SECURITY DEFINER execution](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable) is intentional for the owner-derived consent writer. It checks `auth.uid()`, has an empty search path, accepts no caller-supplied owner ID and records through the private audit writer.

Other project-wide advisor warnings remain outside this scoped OTP change. This is not a claim that the entire project has no security findings.

## Remaining blockers

1. The n8n browser still reports: `Browser observation is unavailable because native credential state cannot be safely resumed. Start a new browser runtime to continue.` The earlier supported reset did not repair it. No browser session or credential was extracted through another channel.
2. The observed n8n workflow was Published and Reserve OTP had the correct project URL with `Custom Auth account 2` bound. The full active export, all bindings, graph and logging settings are still unverified; no n8n edit was made.
3. The earlier automatic-review rejection was resolved by the user's explicit recipient supplied in this conversation (ending 4008). One POST to `/webhook/wevlix/otp/send`, with `purpose=login`, ran at 2026-10-16 01:43:42–01:43:47 UTC and returned HTTP 403 with a JSON response. No automatic retry was made. Database checks found zero new OTP reservations for that recipient, and the scoped Supabase log query for 01:43:40–01:43:55 UTC returned no events. A separate read-only GET of the n8n home page also returned HTTP 403, with a Cloudflare server header. These observations do not identify the exact denying layer and do not prove provider acceptance or delivery. The full phone number and any OTP are deliberately absent from this report.
4. Rotation of the previously exposed Wevlix and Supabase server credentials remains unresolved. It requires access to the credential managers and coordinated updates to actual consumers. Do not place secret values in chat, source or workflow exports.

## Remaining rollout procedure

The database and Edge steps are complete; do not treat them as still waiting for installation.

1. Restore a fresh supported browser runtime for authorized n8n access, retain the active workflow export securely and inspect the active graph and credential bindings.
2. Rotate the exposed credentials and update every actual consumer. Use the provider's development key for simulated delivery checks.
3. Use the supplied credential-free inactive import candidate if the published workflow differs from the reviewed source. It has 33 nodes, `active=false`, empty pinned data and execution-data saving disabled. It passed structural validation, which is not a claim of a successful n8n import or runtime execution.
4. Bind credentials as follows:

| Nodes | Credential |
|---|---|
| Reserve OTP; Record delivery; Verify code; Read new account | HTTP Custom Auth: Supabase server `apikey` and `Authorization: Bearer <service-role-JWT>` |
| Send OTP template; Read delivery; Send account template | HTTP Header Auth: Wevlix `X-API-Key` |
| Status webhook; Verify webhook; Account webhook | Separate unpredictable internal HTTP Header Auth |

5. Confirm there are no duplicate edges or conflicting active paths, execution-data saving stays disabled, all URLs target the repaired project and the public send route has per-source abuse controls at the reverse proxy.
6. Verify first send, cooldown, resend, wrong/expired/reused code, purpose isolation and the app's complete session exchange using simulated delivery. Confirm all internal routes reject missing credentials.
7. The specific recipient and one-message authorization are already present in the private conversation. Resolve the HTTP 403 and inspect n8n/provider execution evidence before retrying; do not send repeatedly or expand the recipient scope. Record provider acceptance separately from confirmed delivery.
8. Record the verified published n8n workflow version and the delivery result before marking the entire repair complete.

If a caller fails, keep the public OTP permission revocations in place. Do not restore anonymous OTP access or the vulnerable verifier to accommodate an old caller.

