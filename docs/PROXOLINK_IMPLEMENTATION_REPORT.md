# ProxoLink implementation and verification report

Verified on 4 October 2026. The implementation is complete on the requested feature branch and is available as a protected Vercel Preview. The pull request remains draft and unmerged. Production promotion, customer cutover, legacy-column cleanup, and release publication remain approval-gated.

The supplied attachment was `PROXOLINK_PRIVATE_TEMPLATES_FULL_IMPLEMENTATION_PROMPT_UPDATED_V2(3).md`, containing 4,891 lines and sections 0–132. It was read from beginning to end before edits. The later user instructions requiring genuine server-rendered previews and the existing Ad UI design system supersede its older static-preview instructions. A separate V3 attachment was not available.

## Repository and deployment

| Item | Verified state |
| --- | --- |
| Repository | [Zana-Sponsor/proxobalance](https://github.com/Zana-Sponsor/proxobalance) |
| Branch | `feat/proxolink-private-renderer-migration` |
| Pull request | [Draft PR #7](https://github.com/Zana-Sponsor/proxobalance/pull/7) |
| Tested revision | `9e06751e41c0b9436de7ea51b690206ee74d9e70` |
| Main verification | [Run 37192633694](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37192633694): passed |
| Native APK build | [Run 37192631788](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37192631788): passed |
| Protected Preview | [proxobalance-pl7xiadni-proxoapp-1758.vercel.app](https://proxobalance-pl7xiadni-proxoapp-1758.vercel.app), deployment `dpl_9rCV68gGtaxo9ttwbHAMepHgUTVt`: READY |
| Preview protection | Vercel SSO enabled for all non-custom-domain deployments; temporary automation bypass revoked |
| Production | Existing production deployment unchanged; feature branch not promoted |
| Merge | None; PR remains draft |
| Android artifact | Debug verification APK, 93,758,173 bytes, SHA-256 `1185286da315f64bf3a17a7d4733cbaf1e9c96bae5b467220507eb06e75a8a54` |
| Store release | Not published; no private release keystore was supplied |

## Flutter application

- Rebuilt the ProxoLink template selector, live-preview container, contact form, card list, statuses, controls and actions with the existing `AdUi`, `AdFormSection`, `AdChoice` and inherited Rabar theme used by Create Ad and Ad Details.
- Kept white surfaces, Proxo blue headings, black primary text, grey secondary text, existing radii, padding, shadows and control proportions. ProxoLink adds no manual font-size overrides.
- Constrained forms to a responsive 600 dp content width and verified the relevant screens at 320, 375, 393, 430 and 768 dp, including 1.6 system text scale.
- Preserved RTL Kurdish/Arabic presentation and explicit LTR treatment for identifiers, URLs, numbers and handles.
- Replaced every static style preview with an authenticated, short-lived, server-rendered preview inside `webview_flutter`. The WebView uses the real original template CSS/JavaScript. An eager gesture recognizer lets bounded previews scroll correctly inside the surrounding Flutter form.
- Navigation accepts only the expected signed page URL. Template demos suppress contact launches; owner previews allow validated contact schemes through external application launch.
- Added authenticated catalog loading, structured create/edit, stable UUID idempotency, optimistic edit concurrency, binary avatar upload, failed-publication retry, activate/deactivate, dependency-aware delete, copy/share and Use for Ad flows.
- Both ad-selection paths require an owned Active + Ready card.
- Kept contact analytics hidden from Flutter.
- Removed the reusable template Dart source, local HTML generator/preview, Telegram HTML delivery, Android file-provider channel and bundled static preview use. Flutter contains no reusable template HTML/CSS/JavaScript.

A credential-free standalone Android probe is included at `proxo_app/integration_test/proxolink_native_probe.dart`. Runtime-only signed URLs and protection headers are provisioned onto a disposable emulator after APK build and never compiled into the APK or committed.

## Vercel backend and security

- Consolidated ProxoLink under `api/proxolink.js` and handler modules, keeping the project within the Vercel Hobby function limit.
- Implemented authenticated template catalog, card CRUD/action, owner-preview token and advertisement-link endpoints plus public card, tracked advertisement and tracked action routes.
- Renderer reads versioned templates from private Supabase Storage, verifies checksums, validates structured customer content, escapes untrusted fields and inserts only trusted contact destinations.
- Catalog responses expose display metadata and signed preview paths only. They do not expose storage paths, reusable source or renderer internals.
- Owner/template preview tokens are signed, short-lived and purpose-bound. Public cards require Active + Ready. Preview requests write no analytics and load no TikTok Pixel.
- Create is UUID-idempotent and payload-bound. Changed payload reuse conflicts rather than overwriting. Failed publication keeps the same retryable card.
- Edit renders the full proposed page before committing and uses `updated_at` optimistic concurrency.
- Avatars are owner/card scoped and immutable after publication. JPEG, PNG and WebP files are fully decoded and checked for MIME, truncation, size, pixel and dimension limits.
- HTML responses use no-store, nosniff, no-referrer, restricted Permissions Policy and a template-specific CSP.
- Public tracked pages resolve the exact link/ad/card/owner relation server-side. Same-card advertisements retain distinct paths and events. Organic and preview visits create no advertisement events.
- The minimal PostgREST write helper now accepts empty successful HTTP 201 and 204 responses. This fixed the live case where an event was recorded but the tracked page returned 404 while parsing an empty 201 response.
- Raw IP storage is blocked by application logic and a database trigger. A server-side HMAC can retain a non-reversible hash. Visitor identifiers and request metadata are cleared after 30 days while aggregate history remains.
- The Vercel service-role credential is configured as a sensitive server environment value. It is absent from Flutter, GitHub and the report.

## Supabase changes

Applied additive migrations:

| Migration | Result |
| --- | --- |
| `proxolink_production_integrity` | Private backup; structured constraints; timestamps; service-only template/link/event/audit access; RESTRICT card/ad relationships; publication protections; avatar policies; raw-IP suppression; atomic link issuance; retention |
| `proxolink_legacy_versions` | Four hidden historical renderer versions/options |
| `proxolink_indexes` | Relationship indexes and backup key; removed client audit policy |
| `proxolink_migration_manifest` | Guarded 21-card checkpoint with recovered fields and avatar hashes |
| `proxolink_hidden_analytics` | Service-only aggregate/tracked-path helper |

Storage and preservation:

- Eight original catalog designs (`dark`, `light`, `classic`, `pill`, `card`, `neon`, `zoom`, `banner`) are private, immutable and checksum-verified.
- Four hidden compatibility versions preserve historical customer output; five cards are pinned to those variants.
- Nineteen customer avatars were uploaded and verified as binary images. Two cards legitimately have no avatar.
- Full private database/storage rollback checkpoints retain the original 21 customer rows.
- The deployed `delete-user` function is version 4 and handles nested avatar paths plus the new RESTRICT relationships.
- A temporary verification cleanup function removed two disposable test avatars through the Storage API and was immediately replaced with a JWT-protected inert 404 implementation.

The guarded `scripts/sql/proxolink_verified_cutover.sql` was rehearsed in a transaction and rolled back. It intentionally retains legacy HTML/base64 columns. Destructive legacy-column removal is isolated in `scripts/sql/proxolink_legacy_cleanup.sql` and was not run.

## Data state after verification cleanup

| Item | Live state |
| --- | --- |
| Customer cards | 21 |
| Advertisements | 27 |
| Customer rows committed Ready by cutover | 0 |
| Test/advertisement contact links | 0 |
| Test contact events | 0 |
| Disposable verification users | 0 |
| Disposable avatar objects | 0 |
| Legacy HTML/base64 rows | All 21 retained |
| Customer cutover | Not applied |
| Legacy cleanup | Not applied |

The live verification created only isolated users/cards/ads/links/events with `example.invalid` addresses. Cleanup validated the expected fixture counts before deletion, removed two avatar objects through the Storage API, deleted only rows owned by those two fixture users, and required the final 21-card/27-ad/zero-link/zero-event state before commit.

## Verification results

| Verification | Result |
| --- | --- |
| Node backend/security tests | 34 passed, 0 failed |
| Flutter selected suites | 92 passed |
| Flutter analysis | No errors or warnings; informational lints only |
| Main CI | All backend, Flutter and Edge Function jobs passed |
| Android release build | Passed; 83.2 MB in main CI |
| Standalone native probe APK | Built and analyzed successfully |
| APK privacy scan | Passed: no template source markers, local generator, Telegram Bot API marker or bundled `assets/styles/` previews |
| Original template pixel comparison | 40/40 exact across eight styles at 320/375/393/430/768 |
| Prepared customer renders | 63 cases: 21 records at 320/393/768 |
| Combined browser checks | 103 cases; fonts/images loaded, no horizontal overflow, no JavaScript or CSP errors |
| Original confirmation dialogs | Open, cancel, reopen and confirm-close passed for all eight |
| Protected Preview API/security checks | 71 passed |
| Exact-ad live attribution | Same card/two ads produced distinct page and button events; WA/TikTok actions redirected correctly |
| Live access boundaries | Cross-owner operations, ordinary-client analytics/template/link access, source routes, invalid tokens/actions and published-avatar mutation denied |
| Data privacy | Raw IP null; referrer reduced to origin; hidden analytics RPC denied to clients |
| Cutover transaction rehearsal | Passed and rolled back |
| Supabase advisors | Reviewed after DDL; remaining server-only RLS and unused-precutover-index notices are expected |

### Native runtime boundary

The standalone APK installed and launched on the official API 35 x86_64 emulator. It reached the actual ProxoLink screen and started `dark (1/8)` through the production `ProxoLinkPreview` widget. The host has no KVM, so Android ran under TCG software emulation. Pixel Launcher and then System UI produced operating-system ANRs; QEMU saturated the shared host and disconnected the execution transport before the first WebView completed. Therefore eight completed native WebView renders and real external-app launches are **not claimed**.

The eight templates are otherwise verified as real server responses by the 71 protected Preview checks and 103 browser cases, while the exact production WebView widget compiles in both the release APK and standalone probe. A physical Android/iOS device or KVM-enabled runner is still required for final device certification.

## Approval gates and user actions

1. **Customer cutover:** requires separate approval before applying the guarded 21-card/16-link cutover.
2. **Legacy cleanup:** requires a later, separate approval after the observation window.
3. **Merge and production promotion:** require separate approval. PR #7 remains draft and Vercel production is unchanged.
4. **Telegram credential:** rotate the historically exposed bot credential with [@BotFather](https://t.me/BotFather). Client delivery code is removed, but rotation cannot be confirmed by repository changes.
5. **Supabase service-role credential:** rotate the Proxo project credential because it was pasted into the conversation. Coordinate consumers, replace the Vercel sensitive environment value, and redeploy at the approved time. Do not paste the replacement into chat.
6. **Native certification:** run the standalone probe on a physical device or KVM-enabled Android runner and complete iOS verification before store release.
7. **Attachment provenance:** provide the specifically named V3 file if it differs from the fully read 4,891-line V2(3) attachment.

## Rollback

No customer cutover, merge or production promotion occurred. The current customer rows and legacy columns remain available. Private original-row and storage backups, the migration manifest and the prior deployment reference are retained. The guarded cutover aborts if any customer checkpoint changed, preventing newer customer edits from being overwritten.
