# Proxo WhatsApp Auth and optional marketing consent

Prepared for Draft PR #7. **Not activated on n8n; not applied to production Supabase.**

Importable workflow: [proxo-wevlix.json](proxo-wevlix.json). Regenerate with `node integrations/wevlix/build-workflow.mjs`.

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
3. Import the inactive workflow and set `PROXO_SUPABASE_URL` in n8n Variables to the isolated HTTPS project URL, without a trailing slash. If Variables are unavailable on the installed n8n plan/version, replace only the `$vars.PROXO_SUPABASE_URL` references with the non-secret project URL.
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
