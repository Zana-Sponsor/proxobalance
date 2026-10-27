# Strict v3 page persistence and eligibility

The page-creation failure was a backend release gate: `assertIsolatedWrites()` permitted only isolated Supabase projects and rejected the intended production project. The provider metadata consequently returned `writes_enabled: false`, and the Flutter creator correctly displayed an unavailable state. Rendering and persistence failures also needed distinct recovery from successful creation.

The gate now supports a deliberate production release only when all three values match:

```text
PROXO_SUPABASE_URL=https://cojchkwssmasiejcgvbk.supabase.co
PROXO_V6_WRITE_MODE=production
PROXO_V6_PRODUCTION_ENABLED=true
```

The default remains closed. Isolated mode still rejects that production host, including the trailing DNS-dot spelling. Production rejects other origins, non-default ports, credentials, paths, query strings and fragments. These environment values have **not** been changed in production as part of this patch.

The creator now accepts an initial locked page type for navigation directly from Create Ad. Back pops only that route. Only an active, ready stored page returns as success. A failed first render remains editable and an explicit corrected retry publishes the same stored page ID. Stored or late idempotent responses for another page type cannot close a locked form as success. Existing owner checks and pending-request keys remain in place.

`loadAssetsForType` issues a server query filtered by owner, active/ready state, absence of archive time, and stored `page_kind`. Contact alone includes the legacy null-kind adapter. Restaurant uses `order`; app download uses `download`; views requests no page. Returned avatar URLs use the established public avatar endpoint.

The unapplied additive migration `20261025120000_tiktok_typed_page_eligibility.sql` validates new explicit `tiktok_ad_type` requests inside the server submission transaction. It locks the eligible owned page before delegating to the unchanged financial implementation. Missing discriminators preserve legacy behavior; TikTok Direct Message retains its existing strict quote schema. Renamed internal functions are not callable by public, anonymous, authenticated or service roles. The public internal wrapper retains its prior service-only grant; clients continue through `pa_submit_ad`.

Local verification includes the backend API persistence suite and an isolated PostgreSQL test (`scripts/test-tiktok-typed-pages-database.mjs`) covering all four mappings, wrong owner/kind/status/archive rejection, legacy behavior, unchanged financial core, grants, idempotent retries, exact debit/outbox counts, and rollback when the final outbox write fails. This is synthetic local evidence, not a successful customer write against production. Deploying the code, applying the reviewed migration, configuring the explicit release flags, and authenticated production verification are separate outstanding release steps.
