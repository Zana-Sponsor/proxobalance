# Local implementation verification — 23 October 2026

**Historical baseline record.** The 25-section continuation added real OAuth, immutable FastPay attempts, private activation and nonfinal report evidence. Current status/counts are in the [completion ledger](../tiktok-dm-completion-status-2026-10-23.md); the baseline results below do not certify the new runtime paths.

These results apply to the combined Meta v8 / TikTok Direct Message v15 implementation on `codex/meta-tiktok-shared-create`, stacked on PR #44's `058f2f6ca7040481d82f5eaaec6edee28b1d3615` receipt baseline. All account, payment and provider fixtures are synthetic. No production migration, target n8n import, external provider mutation, payment or refund was executed.

## Flutter

The final combined run passed **163 tests across 19 files**:

```sh
flutter test --no-pub \
  test/ad_submission_test.dart test/ad_repository_test.dart \
  test/meta_ad_draft_test.dart test/meta_ad_repository_test.dart \
  test/tiktok_dm_draft_test.dart test/tiktok_dm_repository_test.dart \
  test/receipt_platform_refund_test.dart test/receipt_reference_match_test.dart \
  test/ad_receipt_data_test.dart test/ad_detail_loading_test.dart \
  test/receipt_pdf_test.dart test/ad_platform_test.dart \
  test/ad_platform_screen_test.dart test/tiktok_dm_accounts_test.dart \
  test/tiktok_dm_form_test.dart test/meta_ad_form_test.dart \
  test/ad_creation_flow_test.dart test/tx_history_refund_test.dart \
  test/navigation_chrome_layout_test.dart
```

A separate `flutter test --no-pub test/chrome_behavior_test.dart` run passed **3 additional tests**. These are separate from the 163 above. Flutter ran with `CI=true`, version checks disabled and the locally installed SDK; dependency extraction retained local ownership.

Coverage includes Direct versus manual branch visibility and payloads; owner/account/video isolation; offline and stale-response invalidation; pending-request recovery without a second charge; trusted-time requirements; shared wallet-default payment staging/confirmation/dismissal; platform pagination/realtime races; original-debit and refund financial routing; receipt data, golden and PDF preservation; and actual 280/393/768dp widget layouts through 200% text.

`receipt_reference_match_test.dart` passes against the unchanged approved golden. `receipt_platform_refund_test.dart` compares raw RGBA output from the same renderer: TikTok, automated TikTok and Meta Facebook-only/Instagram-only/both fixtures with the same bound values match exactly. The receipt renderer and reference image are unchanged. This does not claim pixel equality for newly added controls against an unavailable external reference.

Actual fixture screenshots are in [`proxo_app/docs/meta_ads_evidence`](../../proxo_app/docs/meta_ads_evidence) and [`proxo_app/docs/tiktok_dm_evidence`](../../proxo_app/docs/tiktok_dm_evidence). The QR screenshot tests presentation with a synthetic connection; the real connector returns its documented unavailable state until secure correlation is established.

Scoped Dart analysis of every changed/new application Dart file found **0 errors and 0 warnings**, with **24 informational style/deprecation notices**. This is not a clean whole-repository analyzer claim.

## PostgreSQL

Both disposable PGlite runs passed against the combined migration stack:

| Command | Assertions |
| --- | ---: |
| `node scripts/test-meta-database.mjs` | 77 |
| `node scripts/test-tiktok-dm-database.mjs` | 130 |

The scripts use `PGLITE_MODULE` pointing to the locally installed `@electric-sql/pglite/dist/index.js`. They apply the real additive migrations to disposable PostgreSQL fixtures. They do not connect to the owner's Supabase project.

Coverage includes private gates/grants; owner isolation; immutable quotes and bindings; existing checkout/wallet/outbox reuse; atomic rollback; idempotent recovery; manual-versus-automatic claim separation; stage order and unknown outcomes; expired leases/gate-off recovery; terminal and delayed status protection; actual metric availability; 95% stop evidence; final-refund claim priority; mandatory two-hour wait; stable settlement evidence; discounted budgets, overspend, original-debit linkage and one-time credit.

## Backend and workflows

The final `npm test` run passed **257 tests**. This includes 33 Meta contract tests, 13 Meta provider/API tests, 20 TikTok provider/API tests, five Meta workflow tests and six TikTok workflow tests alongside the existing regressions. The tests use local mocked transport or disposable loopback HTTP servers. Workflow tests execute the actual exported expressions/Code nodes locally; they do not run an n8n instance.

`npm run lint`, `npm run build` and `git diff --check` passed. The build verified 17 root assets; unrelated generated public copies were excluded from the change.

## Limits that remain

All rollout/FastPay/activation flags remain OFF, all workflow exports are inactive, and creation requests use PAUSED/DISABLE. The continuation implements private activation, OAuth and immutable FastPay quote binding; see the current ledger. The immutable Accounts-to-Marketing join, actual account/targeting eligibility, authoritative finality, deployed staging execution and physical-device acceptance remain unresolved. See [release blockers](README.md#release-blockers) and [configuration evidence](backend-config.md).
