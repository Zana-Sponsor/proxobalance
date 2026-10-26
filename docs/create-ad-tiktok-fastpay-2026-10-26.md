# Create Ad, linked TikTok accounts and FastPay follow-up

## Previous design

The Create Ad screen and its shared form, TikTok tokens and price bar remain byte-for-byte identical to the previous design baseline `3e96d569`:

- `proxo_app/lib/screens/ad_create_screen.dart`
- `proxo_app/lib/widgets/ad_form_components.dart`
- `proxo_app/lib/theme/tiktok_ad_tokens.dart`
- `proxo_app/lib/widgets/tiktok_ad_price_card.dart`

The restored Kurdish Sorani RTL layout and full-width square price bar are unchanged by this follow-up. The [restoration captures](previous-design-restoration-2026-10-26/README.md) document the previous design.

## Integration fixes

TikTok account/status reads no longer require OAuth credentials for terminal requests. An unusable pending grant is reported as unavailable without hiding the owner's existing linked accounts. Pending grants check the current OAuth app and redirect binding before returning an authorization QR. The app handles actual pending, exchanging, rejected, revoked and verified-but-unlinked statuses; consumed QR codes are hidden and terminal requests stop polling. Switching owners clears pending account data and hides the previous owner's open QR sheet.

FastPay preparation now distinguishes an explicit rejection before durable attempt creation from an uncertain payment outcome. The server emits `attempt_created: false` only for allowlisted business rejections from the initial immutable-attempt RPC. The app accepts this proof only on an exact HTTP 409 prepare response with `ok: false` and `uncertain: false`. It can then clear the rejected pending submission. Missing proof, transport failures, conflicts and failures after preparation retain the same payment identity for recovery. Existing-attempt recovery precedes every allowlisted rejection in the SQL; no settlement or charge verification is relaxed.

The six TikTok worker exports and FastPay reconciliation export already use authenticated, fixed backend routes and remain inactive in the repository. No workflow route or payment provider contract was changed here.

## Verification

- Full Node API suite passes locally; the final test count is recorded in the PR checks.
- Focused regression tests cover missing/changed OAuth configuration, terminal status without secrets, account ownership changes, rejected QR state, definitive pre-payment rejection and ambiguous/post-prepare payment failures.
- Independent reviews checked owner scoping, QR exposure, SQL recovery ordering and the no-attempt proof boundary.
- The four design files above have no diff against `3e96d569`; `git diff --check` passes.
- Local Flutter execution was blocked by an interrupted SDK download. Flutter test, analysis and APK results must be taken from the new revision's GitHub Actions runs, not inferred from the preceding APK.

## Live readiness: not complete

Read-only inspection on 2026-10-26 found that the connected Proxo Vercel project has no `TIKTOK_OAUTH_*`, `TIKTOK_DM_WORKER_SECRET` or `FASTPAY_AD_*` settings. Secret values were not requested or printed. The intended Proxo Supabase project has no `app_tiktok_dm`, `app_finance` or `app_ad_payments` schemas, and the corresponding new integration migrations are not installed. This does not describe the separate existing legacy FastPay path.

The latest repository n8n inventory records seven unpublished drafts with the public backend origin set and nine HTTP credential bindings unassigned. That inventory was not a fresh live n8n inspection during this follow-up. Importing drafts or passing unit tests does not establish a successful live connection or payment.

Before live acceptance, the authorized environment needs the reviewed database migrations, protected OAuth/worker/merchant configuration, n8n credential bindings, real TikTok Accounts-to-Marketing/Business Center identity proof, and controlled FastPay sandbox verification. The account must remain unavailable for ad use until immutable identity and permissions are verified. Enter credentials through the protected platform stores, never in PR comments or chat.

This follow-up does not merge or deploy the PR, run production migrations, publish/activate n8n workflows, enable paid ads or payment creation, or change domains/routing. Production restoration and real provider acceptance are not claimed.
