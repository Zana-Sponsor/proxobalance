# ProxoLink implementation and verification report

Updated on 4 October 2026. The corrected implementation is pushed to the requested feature branch and has a READY protected Vercel Preview. Production implementation and end-to-end certification are **not complete**: the new live Android WebView run is blocked by missing secure runtime configuration, authenticated checks of the new deployment are blocked by the Vercel connection, and customer cutover/merge/production promotion have not occurred. The pull request remains draft and unmerged under the user's earlier approval limits. No customer records or production settings were changed during this re-audit.

The supplied attachment was `PROXOLINK_PRIVATE_TEMPLATES_FULL_IMPLEMENTATION_PROMPT_UPDATED_V2(3).md`, containing 4,891 lines and sections 0–132. It was read from beginning to end before edits. The later user instructions requiring genuine server-rendered previews and the existing Ad UI design system supersede its older static-preview instructions. A separate V3 attachment was not available.

## Repository and deployment

| Item | Verified state |
| --- | --- |
| Repository | [Zana-Sponsor/proxobalance](https://github.com/Zana-Sponsor/proxobalance) |
| Branch | `feat/proxolink-private-renderer-migration` |
| Pull request | [Draft PR #7](https://github.com/Zana-Sponsor/proxobalance/pull/7) |
| Current tested code revision | `d9894d92db3ff6ed6494043657ccaecba9a743b1` |
| Current main verification | [Run 37212967155](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37212967155): backend, Flutter and Edge Function jobs passed; tested PR merge revision `4c9ac5d6112b79b7f771e78c40af9ac5a92b074a` |
| Current native APK build | [Run 37212964578](https://github.com/Zana-Sponsor/proxobalance/actions/runs/37212964578): build passed; live runtime steps skipped because configuration is missing |
| Current protected Preview | [proxobalance-m3i211mkp-proxoapp-1758.vercel.app](https://proxobalance-m3i211mkp-proxoapp-1758.vercel.app), deployment `dpl_JVLgM12PfZoEJhsizZ1oH8hQYXFM`: READY; 18-second deployment observed in the signed-in dashboard |
| Preview protection | Vercel SSO enabled for all non-custom-domain deployments; temporary automation bypass revoked |
| Production | Existing main revision `e7c1d3060c2777cae7ff2bc293df7df5ebfd4cd6`, deployment `dpl_H3aJZtYpfVhePK5n1ZL7pxwiLbvQ`, unchanged; feature branch not promoted |
| Merge | None; PR remains draft |
| Android artifacts | Current credential-free debug verification APK in run 37212964578; current release APK built at 83.2 MB and passed the privacy scan in run 37212967155. The prior debug artifact's hash is historical evidence, not the current APK hash. |
| Store release | Not published; no private release keystore was supplied |

## Corrections made during the current re-audit

The partial branch already contained the private renderer, live WebView integration, Ad UI components and additive migrations described below. The current code commit fixes concrete remaining defects without changing any original template layout, CSS, JavaScript or customer fields:

- **Public avatar identity:** rendered pages previously exposed Supabase Storage URLs containing the owner's Auth UUID. They now use card-scoped `/contact/:id/avatar` or exact-ad `/a/:token/avatar` routes. The server resolves the owner/card path privately, fully decodes the original JPEG/PNG/WebP, and returns unchanged bytes with no-store/nosniff headers. Inactive owner-preview images require the same short-lived preview capability. Image loads create no analytics events.
- **Publication races:** retry and activation now require the conditional database update to return the matching row. A newer edit taking the publication lease returns `409 edit_conflict`; an old failed render cannot overwrite the newer Ready state.
- **Analytics retention:** recorded request paths use the canonical validated advertisement/action path. Arbitrary visitor query strings are excluded from retained analytics history. Exact-ad resolution remains unchanged.
- **Stalled live previews:** Flutter now times out stalled signed-URL requests and page loads after 45 seconds, offers the existing Ad UI retry control, rejects late responses/old controller callbacks, and cancels timers on disposal. Typography and component styling remain inherited.
- **Repeatable native verification:** a KVM-backed GitHub Actions runtime job now installs the credential-free probe APK and provisions eight short-lived server preview capabilities through the app's private runtime file. Credentials, tokens and protection headers are not compiled into the APK or uploaded as artifacts. The runner captures safe screenshots and per-style results only when all required settings exist.

Changed code is covered by seven additional backend regression tests and two Flutter timeout/race regression tests. No reusable template files or template bytes were modified.

## Current verification evidence

These results apply to code revision `d9894d9`, unlike the historical browser/pixel results later in this report.

| Check | Current result |
| --- | --- |
| Backend/security regressions | 41 passed, 0 failed locally and in CI |
| Flutter selected suites | 94 tests passed in CI |
| Flutter analysis | Passed; informational lints only |
| Backend build and Vercel function limit | Passed; consolidated avatar operation adds no new top-level function |
| Release APK | Built successfully, 83.2 MB; source-privacy scan passed |
| Standalone native probe | Analyzed and built successfully without embedded runtime credentials |
| Edge Function type check | Passed |
| Source privacy scan | Passed: no reusable template source or static style-preview delivery in Flutter/public output |
| Responsive Flutter checks | Card list at 320/375/393/430/768 dp and form/retry layout at 320/393/768 dp passed; fresh 320 and 768 dp artifacts visually inspected |
| UI artifact boundary | The widget-test screenshots show the real-preview failure/retry state; they do **not** prove native WebView rendering |
| Customer checkpoint | All 21 cards exactly match the private migration manifest; 27 ads and 16 card-referencing ads preserved; no orphan/cross-owner references |
| Customer avatars | All 19 objects returned HTTP 200, matched manifest SHA-256, and fully decoded; two cards have no avatar |
| Private template bucket | Private flag retained; anonymous public-object requests for all eight catalog templates denied |
| Client access | RLS enabled; anon/authenticated direct access to internal templates, links, events and publication attempts remains denied |
| Retention | Existing 30-day visitor-detail cleanup job remains active; raw IP remains suppressed |
| Live database mutations in this re-audit | None |
| New deployment authenticated API/native checks | Not completed; access/runtime configuration blockers below |

The main CI UI artifact is `proxolink-ui-verification` (artifact 11307446475). Historical 40/40 pixel comparisons, 103 browser cases and 71 protected API checks were conducted on `9e06751`, not repeated against this new deployment. They remain useful preservation evidence but do not certify the new avatar route end to end.

### Current access and native blockers

The Vercel connector returned project/deployment access failures, including an explicit 403 while obtaining the protected-preview automation capability. The signed-in dashboard nevertheless confirms the new deployment is READY. A direct browser attempt to open its API returned `net::ERR_BLOCKED_BY_CLIENT`; no authenticated API success is claimed for the new deployment. Reauthorize the Vercel connection for team `proxoapp-1758` and project `proxobalance` before continuing protected API checks.

Run 37212964578 completed its APK build, then explicitly reported all four missing GitHub runtime settings:

| Setting | Location and intended value |
| --- | --- |
| `PROXO_NATIVE_ANON_KEY` | Repository variable; the project's publishable/anon key only |
| `PROXO_NATIVE_TEST_EMAIL` | Actions secret; dedicated ordinary verification account |
| `PROXO_NATIVE_TEST_PASSWORD` | Actions secret; that account's password |
| `PROXO_NATIVE_VERCEL_BYPASS` | Actions secret; a temporary protected-preview automation capability |

Configure these through the provider's secure settings, never chat or source. Then rerun the native workflow and verify eight completed WebView cases/screenshots. Revoke the temporary protection capability and remove temporary runtime secrets after verification. No new verification account or persistent credential was created in this re-audit. External-app contact launches and iOS device verification also remain outstanding.

Local Flutter execution was rejected by automatic approval review because the toolchain attempted to access a cloud instance metadata endpoint, creating a possible credential/metadata exposure risk. This was not retried or bypassed. GitHub CI provided the Flutter analysis, tests and builds instead. The local host also lacks KVM; the earlier software-emulated Android attempt is described below and is not native certification.

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

## Historical verification results at revision 9e06751

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
6. **Native certification and protected API access:** reauthorize Vercel for the stated team/project, configure the four secure runtime settings above, rerun the KVM-backed native workflow (or use a physical device), and complete external contact-launch and iOS verification before store release. The skipped runtime job is not a pass for this requirement.
7. **Attachment provenance:** provide the specifically named V3 file if it differs from the fully read 4,891-line V2(3) attachment.

## Rollback

No customer cutover, merge or production promotion occurred. The current customer rows and legacy columns remain available. Private original-row and storage backups, the migration manifest and the prior deployment reference are retained. The guarded cutover aborts if any customer checkpoint changed, preventing newer customer edits from being overwritten.
