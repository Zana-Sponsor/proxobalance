# Proxo WhatsApp Auth and optional marketing consent

Prepared for Draft PR #7. **The scoped live OTP repair is authorized; see the follow-up status below for what has actually been verified and deployed.** PR #7 remains Draft/Open/Unmerged.

For the current Zana project, import [proxo-wevlix-configured.json](proxo-wevlix-configured.json): every Supabase URL is already configured and no n8n Variables are needed. Credentials are still stored separately in n8n. Regenerate with:

```sh
node integrations/wevlix/build-workflow.mjs https://cojchkwssmasiejcgvbk.supabase.co
```

The portable [proxo-wevlix.json](proxo-wevlix.json) continues to use `PROXO_SUPABASE_URL`; regenerate it with `node integrations/wevlix/build-workflow.mjs` without an argument.

## Live repair status — 2026-10-16, follow-up repair

The user explicitly authorized a complete scoped OTP repair. The prepared repair now also preserves behavior found only in the deployed login handler: canonical phone lookup through `pa_profile_by_phone` and rejection of ambiguous phone matches. Signup refuses existing canonical matches. Both handlers reject non-string codes before database access and pin supabase-js to 2.118.0.

Initial live evidence confirmed the old generator contract, anonymous generator/verifier execution permissions, missing new verifier/delivery/consent objects, a missing `phone-otp-session` deployment and `whatsapp-session-exchange` version 2. The resumed rollout has now applied the reviewed migration, closed the public OTP surface and deployed both handlers. The compatibility verifier is service-only and purpose-bound. No account or audit row was deleted.

Twenty isolated workflow/Edge tests pass after five new regression cases failed against the previous source. The SQL lifecycle/RLS/consent tests pass on disposable PGlite/PostgreSQL 18.6. [GitHub run 38833558625](https://github.com/Zana-Sponsor/proxobalance/actions/runs/38833558625), for source commit `8ee6215`, also passed the real PostgreSQL 17 migration, cross-connection concurrency and Deno type checks. A follow-up regression verifies that replaying the migration preserves new secure codes while the first transition invalidates old exposed proofs. These tests send no provider messages.

The n8n editor was reached using secure sign-in and showed the reviewed workflow as Published, with a corrected Reserve OTP URL and `Custom Auth account 2` bound to that node. The browser then reported that native credential state could not safely resume; the supported reset did not restore access. Consequently the current active export, complete bindings, graph and node options have **not** been fully verified or changed. A possible duplicated graph edge in the editor observation remains unconfirmed until the export is available. Do not interpret offline source checks as verification of that active version.

**Deployment status: database and Edge repair deployed; n8n and real delivery verification remain blocked.** The resumed preferred migration call succeeded, creating live migration `20261016012937`. The new objects and grants were read back. `whatsapp-session-exchange` version 3 and `phone-otp-session` version 1 are ACTIVE and their retrieved sources exactly match the reviewed handlers. Live OTP lifecycle checks passed inside a rolled-back transaction, and both HTTP endpoints returned the expected 405/400 responses to GET/malformed-input probes. A second migration, `20261016013607`, pins the canonical phone helpers' search paths; live matching and grants were rechecked. The browser still cannot safely resume n8n credential state. The user subsequently authorized one OTP test to a specific recipient: its single webhook request returned HTTP 403 and created no OTP reservation; it was not retried. Provider acceptance/delivery is unverified, and no active n8n edit was made. See the [current rollout report](../../docs/otp-repair-status-2026-10-16.md) for exact source/live versions, checks and remaining steps. Keep PR #7 Draft/Open/Unmerged; credential rotation and unrelated release blockers remain unresolved.

Once the coordinated rollout and bindings are complete, the public send request is `{ "phone": "+9647XXXXXXXXX", "purpose": "login" }`. Do not include an OTP, template ID or privileged key. Provider acceptance is distinct from delivery. A real send requires a specifically authorized test recipient. Do not repeatedly retry `otp_unavailable` or an uncertain provider timeout.

## Supplied templates

| Template | Wevlix UUID | Category / parameters | Intended use |
|---|---|---|---|
| `proxo_otp` | `fcb360b0-6bee-499c-990b-8fc181dccfbd` | AUTHENTICATION, en_US; body OTP and copy-code URL button | User-requested verification, maximum five minutes |
| `proxo_account` | `c81050e6-f9af-42ae-90bf-b43b41469b61` | UTILITY, ar; named `customer_name` | Requested confirmation of a real newly created account |
| Marketing | **Not supplied** | Requires an approved MARKETING template | No campaign sender is enabled by this change |

The two supplied IDs are not marketing permission and must not be reused for advertisements. The workflow pins the UUIDs through `/v1/messages/template`; `/v1/otp/send` selects its own template and may generate a different OTP if code is omitted.

## What changed

- Database errors, malformed reservations and cooldowns terminate before the paid provider. A cryptographically generated OTP is reserved before sending. Concurrent requests serialize per phone; every resend counts toward five/hour and a 60-second cooldown. Codes are purpose-bound and expire after five minutes; five wrong attempts lock the code. Anonymous clients cannot read/generate/consume stored OTP material.
- Both the body and copy-code button receive the same six-digit code, preserving leading zeroes. Server-generated idempotency IDs identify each reserved send. HTTP success is returned only after provider acceptance and message-ID storage; `queued` is not a delivery guarantee. Provider errors, codes and personal data are not reflected to clients.
- The app verifies and obtains a session in a single Edge Function call. The raw verifier and status routes require internal authentication. The account route verifies a fresh Auth user and a separately requested confirmation event; marketing consent does not authorize this event. The current app does not invoke this optional account route automatically.
- Signup stores both acceptance and refusal in `whatsapp_marketing_preferences`, with append-only `whatsapp_marketing_consent_events`. Server-controlled evidence includes the confirmed phone, displayed wording/version/locale, purpose, source and timestamp. Repeating the same choice is idempotent. Missing choice defaults to refusal. Consent is recorded before a new session is issued.
- Profile → WhatsApp notifications allows withdrawal or re-enrollment. Reads are owner-scoped; the write RPC derives the owner from Auth. The screen loads only when opened. Changing a confirmed phone invalidates the old number's marketing eligibility until a fresh opt-in.

## Consent shown to the user

**ڕەزامەندم، بە هاتنی ئاگاداری و نوێکارییەکان لە ڕێگەی واتسئاپ**

نامەکانی مارکێتینگی Proxo؛ ئارەزوومەندانەیە و لە پڕۆفایل دەتوانیت ناچالاکی بکەیت.

Unchecked by default. Signup and security OTPs do not depend on acceptance. Arabic and Badini equivalents are included; the locale displayed when signup was submitted is retained through OTP verification. Auth uses a 20dp title, 14dp controls, 12dp helper text, 16dp field spacing and minimum 48dp touch targets, with accessibility scaling and RTL wrapping.

## Meta requirements and campaign launch conditions

Based on the [WhatsApp Business Messaging Policy](https://business.whatsapp.com/policy), reviewed 2026-10-15 (policy updated 2026-09-23):

1. Obtain permission for the stated business and purpose after the person supplies their number. Do not assume that registration or receiving an OTP means marketing consent.
2. Honor stop/block/withdrawal requests made inside or outside WhatsApp. Exclude withdrawn people before sending; do not surprise or spam recipients.
3. Initiate messages using an approved template for its designated category. Outside the 24-hour customer service window, use approved templates.
4. Maintain accurate business/support details and a published privacy policy describing relevant collection, use and sharing. Follow applicable laws and content restrictions.
5. Meta can pause templates or restrict accounts. These controls reduce risk; they cannot guarantee protection from blocking.

Before enabling campaigns, supply an approved MARKETING template and a real published privacy-policy URL, and verify the inbound/support opt-out path. The supplied screenshots do not establish either. Check `pa_whatsapp_marketing_allowed(user_id)` immediately before **each** marketing send; never rely on signup metadata or an old exported audience. Use a clear stop instruction in campaign copy. The trusted sender/support processor must call `pa_withdraw_whatsapp_marketing(phone)` after authenticating an off-app withdrawal; a bare public POST is not evidence of the WhatsApp sender's identity. This repository does not claim an inbound provider webhook is configured. Keep campaigns disabled until this path has been exercised in staging. Conservative frequency limits and monitoring complaints are additional operational recommendations, not a guarantee or a stated fixed Meta limit.

## Review and staging setup

The attached original export and screenshot exposed a Wevlix key and Supabase service-role credential. **Rotate those exposed credentials before deployment.** No original secret is included here. Bind new secrets only in n8n Credentials / Supabase server secrets; never in Flutter, JSON exports or Git.

1. Use an isolated Supabase project. Review and apply `proxo_app/supabase/migrations/20261015215145_whatsapp_auth_consent.sql`, which targets the inspected existing `otp_whatsapp` schema. The migration revokes old public OTP function access; deploy the workflow and both updated Edge Functions together in a coordinated maintenance window after staging passes. Do not apply it independently to the current production flow.
2. Deploy `phone-otp-session` and `whatsapp-session-exchange` to that isolated project with the existing server-side Auth environment. Their external HTTP endpoints must allow unauthed requests, because they perform OTP proof themselves. Raw database OTP RPCs remain service-only. The app's signup/login paths must point to that same project.
3. Import the inactive portable workflow and set `PROXO_SUPABASE_URL` in n8n Variables to the isolated HTTPS project URL, without a trailing slash. If Variables are unavailable, generate a configured export using that isolated project's URL as the builder argument. The committed configured export points specifically to the live Zana project and must not be used as a staging destination.
4. Bind **Proxo Wevlix server** as HTTP Header Auth (`X-API-Key`, rotated development key). Bind **Proxo Supabase service role** as HTTP Custom Auth with two headers: `apikey: <server-key>` and `Authorization: Bearer <service-role-JWT>`. Bind **Proxo internal webhook** as a separate unpredictable header credential shared only with trusted server callers. Verify names resolve to actual credential IDs after import.
5. Keep execution-data saving disabled (the export disables success/error/manual/progress storage). Use TLS and access-controlled n8n administration. Confirm the reverse proxy protects the public send endpoint with per-source abuse controls in addition to database per-phone limits; never place an internal secret in the app. Disable the old workflow before enabling a replacement with matching paths.
6. In Wevlix development mode, exercise initial send, resend, cooldown, wrong/expired OTP, signup with both choices, consent withdrawal and re-enrollment, and login. Development messages simulate delivery. No live message has been sent by this implementation or its automated tests.

| Route | Caller | Contract |
|---|---|---|
| POST `/wevlix/otp/send` | App, behind deployment abuse controls | `{phone, purpose: signup/login/reset_password}`; returns accepted message ID/status/expiry, never code |
| GET `/wevlix/otp/status?messageId=...` | Authenticated internal service | Returns allowlisted status only |
| POST `/wevlix/otp/verify` | Authenticated internal service | `{phone, code, purpose}`; consumes OTP, so do not call before app session exchange |
| POST `/wevlix/account/created` | Authenticated internal service | `{event: "account_created", userId, confirmationRequested: true}`; verified fresh signup only, stable idempotency ID |

The current product's password reset uses its existing email flow; the prepared `reset_password` OTP reservation alone is not a password reset implementation. Delivery receipts are queried through Wevlix's message-status endpoint, not accepted from unauthenticated inbound events.

## Verification

- `node --test test/wevlix-workflow.test.js test/whatsapp-auth-edge.test.js` executes actual exported n8n Code/IF/HTTP request expressions and actual Edge handlers with intercepted transports; no billable sends.
- `.github/workflows/whatsapp-auth.yml` applies the migration twice to disposable PostgreSQL 17, tests permissions, RLS, expiry, reuse, attempts, purpose isolation, consent/audit/withdrawal, and concurrent reservations; checks Edge types with Deno.
- `proxo_app/test/whatsapp_marketing_test.dart` tests the real signup checkbox, outbound signup consent body, profile withdrawal/retry, three languages and 280dp/2× text layout. Actual widget screenshots are captured by the polish workflow. This does not replace a staged provider/Meta delivery test.

References: [Wevlix template send](https://docs.wevlix.com/reference/messagescontroller_sendtemplate_v1-1), [message status](https://docs.wevlix.com/reference/messagescontroller_getstatus_v1-1), [n8n HTTP credentials](https://docs.n8n.io/integrations/builtin/credentials/httprequest/), [Meta opt-in](https://developers.facebook.com/documentation/business-messaging/whatsapp/getting-opt-in).

