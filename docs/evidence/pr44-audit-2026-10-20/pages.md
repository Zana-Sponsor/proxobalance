# Create Page: source repair and deployment limit

Scope: the current 15-point request, implemented on PR44 base `2a98e20`.

## Actual startup failure

The default app configuration calls `https://www.proxobalance.app/api/page-providers` before enabling the creation form. A fresh unauthenticated, read-only HTTPS GET on **2026-10-20 at 16:24:53 UTC** returned:

```text
HTTP 404
Content-Type: application/json
{"error":{"code":"404","message":"The page could not be found"}}
```

A second unauthenticated read-only check on **2026-10-22 at 18:25:57 UTC** still returned HTTP 404 (`text/plain; charset=utf-8`, `NOT_FOUND`). The Supabase inventory on October 22 still has no development branch for the app project; the other listed project is a separate application and was not used for testing.

This missing deployed route is sufficient to explain the screenshot's unavailable state. The request fails during catalog initialization, before form validation, avatar upload, or page submission. The client deliberately maps that 404 to the unavailable message. Retry really invokes initialization again; it cannot deploy a missing route.

The source also deliberately requires `PROXO_V6_WRITE_MODE=isolated` and rejects the production Supabase project in `assertIsolatedWrites()`. That restriction remains intact. The earlier rollout evidence records a legacy production schema; that database finding was **not independently rechecked during this source repair**.

## Source fixes

- Network/server failures no longer leave the creation form permanently read-only. Valid entered values remain available and all temporary submission state is released in `finally`.
- Corrected retries rebuild the payload while retaining the same owner-scoped request UUID. The API's existing idempotency check prevents another page from being inserted if the original request finished late.
- A changed-payload idempotency conflict now includes only the previously saved owner's safe card fields. The app can return that confirmed original page to the list without a second failing read. This preserves the original saved data; it does not silently overwrite it with the corrected retry.
- Confirmed server success remains successful if removing the local pending-request key fails. Local storage errors before submission still prevent a write without a durable recovery key.
- A failed pending-request list lookup no longer prevents loading an otherwise usable catalog. The original request UUID remains in use for safe reconciliation.
- Catalog checks require the four actual V6 designs and at least one provider for each supported page type. Malformed/incomplete catalog responses are evicted from the cache so Retry can retrieve repaired data.
- Create Page and Tools use the shared compact empty/error presentation. Decorative category chips were removed. Page notifications use the shared two-second, non-blocking surface; editor/details/preview feedback uses the shared toast API.

## Verification

- `node --test test/proxolink-v6-api.test.js test/proxolink-api.test.js`: **59 passed, 0 failed**. This uses isolated in-memory HTTP/database fixtures. Added assertions cover changed-payload recovery, one saved row per request, cross-owner isolation, and exclusion of internal hashes/template data from conflict responses.
- Flutter regression checks are coordinated with the main verification run. New cases cover editable network failure, corrected retry with the same key, list reopening, late committed conflict recovery, failed local cleanup, failed local key persistence, partial catalogs, and real service transport/cache behavior. Final run results belong in the main completion report.
- Screenshot captures in these tests are actual Flutter widget renders with fictional data, not a signed-in production device or a live database persistence check.

## Remaining concrete blocker

Live creation is **not verified or unblocked** by these source changes alone. Follow the existing [isolated rollout plan](../home-payment-remediation-2026-10-19/isolated-rollout-plan.md): obtain an authorized isolated project/branch without customer data, verify a complete schema-only baseline, apply the three existing V6/management/moderation migrations, and deploy this API on a separate staging host with complete matching app configuration. Then run the existing hosted acceptance runner and authenticated app create/refresh/reopen journey. The prior provisioning consent expired; no billable resources, database rows, production migrations, deployment changes, or guard removals were made here.

A production release remains a separately reviewed action after isolated acceptance passes.
