# Supabase login, logout and phone model logging — 2026-10-16

## Current result

The authorized Supabase Auth audit is deployed. New Auth sessions record login events and last-login time; actual session revocation records logout and closes matching detailed history. The Flutter changes collect phone model/OS and repair Profile logout navigation. **Those client changes require a new app build installed on the device.** This work does not claim that the user's existing installed app has updated itself.

PR #7 remains Draft/Open/Unmerged. Only the explicitly requested Auth database repair was deployed; no unrelated ProxoLink or production mobile release was made. No additional OTP or billable provider message was sent.

## Where to see the records

In the Supabase Table Editor for project `cojchkwssmasiejcgvbk`, select schema `public`:

| Table | Relevant fields | Meaning |
|---|---|---|
| `pa_activity_log` | `user_id`, `session_id`, `action`, `created_at` | One `login` or `logout` event per Auth session/event. |
| `pa_login_history` | `user_id`, `session_id`, `login_time`, `logout_time`, `session_duration` | Detailed session start/end and duration in seconds. |
| `pa_login_history` | `device_name`, `device_model`, `os`, `os_version`, `platform` | Device-reported Android/iOS model and OS, supplied by the updated app. |
| `profiles` | `last_login_at`, `last_logout_at` | Latest server-observed login and session termination for each account. |

Sort event/history tables by `created_at` descending and filter by the user's UUID. Timestamps are `timestamptz` and should be displayed with the intended timezone. Android records brand/model; iOS records its hardware model identifier, rather than an owner's personal device name.

Existing `auth.users.last_sign_in_at` populated last-login time for **193 profiles**. The original 81 history rows had no model, session ID or logout time. Missing historical phone models and logout times were not invented.

## Repairs and boundaries

- Auth session INSERT/DELETE triggers own event times. Token refresh and reopening an existing session do not fabricate another login. Failed Auth transactions roll back their audit records too.
- The persistent app listener outlives the original AuthGate route. Phone, email, signup and restored-session paths share one device recorder. Overlapping requests and repeated Auth events are deduplicated; transient collection/request failures remain retryable.
- Metadata RPC checks `auth.uid()`, the signed JWT's session ID, session ownership and active expiry. It locks against concurrent revocation and accepts only bounded descriptive device fields. Server Auth supplies the session start, IP and user-agent. Client-submitted user IDs, IPs and event timestamps are ignored.
- RLS remains enabled. Anonymous metadata execution and client timestamp forgery are denied. The privileged helper has a pinned search path behind an invoker wrapper in the public API; tokens, passwords, OTPs and unique hardware identifiers are not stored in these records.
- Profile logout clears protected navigation even if the original AuthGate was removed, including when the SDK clears local credentials before a remote logout error. Sidebar uses the same service. No unauthenticated client audit INSERT runs after signout.
- The legacy manual-close RPC remains available for old history rows with no Auth session ID. It cannot pre-close the new server-linked history while its Auth session remains active.
- `logout` means an actual server session termination, including explicit signout, revocation or expiry cleanup. Closing/backgrounding the app is not logout. A network-failed local signout cannot truthfully claim remote revocation; its server event arrives only if/when the server session ends. Expiry cleanup may occur after the expiry time; a known `not_after` bounds the recorded end time.
- Account deletion retains the existing cascade erasure behavior. This is an account-activity log, not an immutable compliance archive.

## Verification

The focused Flutter suite passed **22/22** at source `99ed1e55829a0547a780fadbd9fe434525307788`: [run 38932761153](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38932761153). It covers metadata deduplication/retry, account switching during a pending lookup, before-signout sequencing, invalid sessions, actual Profile logout with and without remote failure, phone-flow logic and OTP widget lifecycle. Flutter analysis completed without errors; existing nonfatal warnings/information elsewhere in the app remain.

The database fixture uses isolated PostgreSQL 17 roles and owner RLS. It applies the audit migrations twice and checks authoritative timestamps, allowlisted device fields/server IP, duplicate prevention, owner/session isolation, revoked-session denial, profile/history forgery denial, real revocation, global owner-scoped revocation and account-deletion erasure. The additional legacy-close regression also checks old unlinked-row compatibility.

The [live rollback-only diagnostic](../test/auth-session-activity-live-rollback.sql) passed against the deployed database: two temporary fixture accounts/sessions, real login/logout triggers, device RPC, duplicate handling, cross-session denial and timestamp protection. The transaction was rolled back. Independent readback found **zero fixture users and zero fixture history rows**, and confirmed RLS remained enabled. No real user's session was revoked or used as a fixture.

Earlier test failures are retained in CI history: missing `Response.request` in an HTTP mock caused an SDK null assertion; an unlaid-out scroll target and widget fake-clock storage wait blocked the UI test. The fixture now follows the actual SDK contract and waits for observable logout navigation, keeping all security/navigation assertions. These failures were resolved rather than ignored.

Security advisor comparison after the main migration found **no newly introduced findings** (129 existing findings before and after). Existing project-wide warnings are not represented as resolved by this scoped change.

The final focused database/Flutter run including the legacy guard is [38933067775](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38933067775), **both jobs passed** at source `139fc33a5de7c45ba50c884c4770c07ffc81f6ad`. [Broader source CI 38933067329](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38933067329) also passed all five jobs: Flutter, database, backend, responsive and Edge Functions. [Credential-free native APK build 38933067466](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38933067466) passed; its protected native-runtime and isolated-hosted jobs were skipped, not claimed as live verification.

Auth, Sidebar/Profile and general UI capture workflows also passed. One additional Android phone fixture build initially failed because Google's CMake 3.22.1 download returned HTTP 502; the tablet and narrow configurations passed. Only that failed phone job was retried, without changing application behavior or relaxing an assertion. At 16:54 UTC the [phone retry in run 38932761060](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38932761060) is in progress; it is not counted as passed yet.

The live rollback diagnostic was rerun after the legacy guard and passed, including proof that the legacy RPC cannot close an active Auth-linked history row. Final independent cleanup again found zero fixture users/history, 193 populated profile login timestamps, anonymous metadata execution denied and authenticated execution allowed. Two initial management calls returned `Invalid or expired requestState`; cleanup was checked before bounded retry, and only successful SQL responses are counted as verification.

## Deployment ledger

| Supabase migration version | Repository file |
|---|---|
| `20261016161022` | [`20261016161022_auth_session_activity_logging.sql`](../proxo_app/supabase/migrations/20261016161022_auth_session_activity_logging.sql) |
| `20261016163705` | [`20261016163705_auth_session_activity_legacy_close_guard.sql`](../proxo_app/supabase/migrations/20261016163705_auth_session_activity_legacy_close_guard.sql) |

Each migration was initially created with `supabase migration new`. After the management API assigned the live ledger version, its repository filename was aligned to that recorded version, without changing SQL content. Git blobs remain `bfb272bc1cd83eb8af7da4b0151d2137b12cc14b` and `493f3f6afd5edfb3a3a2e0eae708e7d4ec919c4d`, respectively—the same SQL tested in CI. The workflow selects these migrations by suffix, so the filename alignment preserves application order and prevents a duplicate/out-of-sync migration history.

## Remaining device verification

The database path and app code tests are verified separately. A physical Android/iOS login/logout with the updated production app has not been performed. Install the reviewed updated app through the normal release process, then a normal login can populate the real model and a logout can close that same session. Old clients cannot supply model fields they never collected.

The earlier WhatsApp test reached the recipient, but that code expired before confirmation; it was not used to prove an app session. Exact provider delivery time/charge, the old ambiguous 502 attempt and administrative n8n readback limits remain in the [OTP repair report](otp-repair-cloudflare-2026-10-16.md).
