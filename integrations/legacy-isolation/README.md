# Reviewed legacy workflow isolation

These are **offline patches for review**, not imported workflows and not evidence of runtime execution. They preserve the existing legacy nodes, credential references, webhook paths, provider amounts, metrics, and activation settings. No patch enables a workflow or changes a gateway configuration.

The inspected snapshots are `FastPay Checkout + Supabase v12` and `TikTok Budget Limit Auto-Stop v23 (completed analytics + metric provenance)`. Both inspected snapshots were active. Their full exports and live credential IDs are deliberately excluded from this repository.

Run the preparer against fresh authorized exports:

```bash
node integrations/legacy-isolation/prepare-patches.mjs \
  /absolute/path/fastpay-export.json \
  /absolute/path/tiktok-budget-export.json \
  /absolute/path/reviewed-isolation-patches.json
node --test test/legacy-workflow-isolation.test.js
```

The output contains source digests and minimal RFC6902 operations. It is **not** a complete n8n workflow and cannot be imported directly. The script does not contact n8n, does not save a modified workflow, refuses unexpected reviewed links/filters, and never exports original credentials or metadata. Its in-memory verifier checks node references and unchanged activation. Re-export and review if a source digest changes; do not force a patch onto a changed live workflow.

## TikTok budget patch

| Existing node | Minimal change |
| --- | --- |
| Get Active Ads | Preserve `or=(status.eq.active,status.eq.completed)` and append `&fulfillment_kind=neq.tiktok_conversation_auto`. |
| Update Spend | Add an AND condition `fulfillment_kind neq tiktok_conversation_auto`. |
| Update Spend Only | Add the same AND condition. |
| Mark Completed | Add the same AND condition. |

The original match/report/stop nodes remain untouched. Automatic Conversation ads cannot enter this legacy selector; write predicates also protect against stale selected rows. The existing `fulfillment_kind` column is `NOT NULL DEFAULT 'manual'`, so legacy rows remain selected. Apply the schema before this workflow patch. Stop and drain existing executions before replacing the workflow: an execution that already captured an older workflow graph is not rewritten by a saved patch. Do not resume a pinned or historical execution with automatic ads in its saved input.

## FastPay patch

The service-only RPC `pa_legacy_fastpay_guard(p_order_id text,p_transaction_id uuid default null)` is implemented by migration `20261023202139_immutable_ad_fastpay_attempts.sql`. The immutable adapter reserves case-insensitive `AP` followed by 28 hexadecimal characters **before a transaction exists**, and also checks durable attempt/transaction binding. Legacy `AD` orders and `PX` deposits keep their original behavior. Blank, malformed, mismatched and uncertain identities must fail closed.

A permitted result is exactly `{ok:true,legacy_allowed:true,immutable_ad_payment:false,code:'LEGACY_ALLOWED'}`. A blocked immutable order returns `{ok:true,legacy_allowed:false,immutable_ad_payment:true,code:'AD_PAYMENT_IMMUTABLE'}`. Non-2xx HTTP responses, missing fields, contradictory booleans and unknown codes stop execution. The workflow does not convert failed guard reads into approval.

| Route | Guard inserted before | Immutable-order outcome |
| --- | --- | --- |
| Authenticated checkout | `Ad Checkout?`, so before quote/repricing and Generate QR | HTTP 409; no quote or gateway POST |
| IPN | FastPay Config2 / Validate Payment | HTTP 200 with `ignored:true`; no payment or fulfillment claim |
| Polling, each Loop Orders item | FastPay Config3 / Get Status | Skip this item and continue the loop |
| Authenticated app status | Get App Payment / live FastPay status | HTTP 409; the new adapter owns status |
| Refund | Get Refund Target / eligibility / gateway refund | HTTP 409; no gateway refund or wallet mutation |

The allowed polling branch restores the exact current Loop Orders item after the HTTP guard, because FastPay Config3 reads `$json.fastpay_order_id`. No amount is copied from the guard response. The IPN acknowledgement means only that the **legacy** worker ignored the order; it does not mean the new adapter verified or funded it. The immutable adapter's own callback/reconciliation path must be deployed and tested first.

New lookup nodes reference a credential by the placeholder name **Proxo Supabase service role**, with no credential ID or secret. Map each node to the target instance's existing correct Supabase service credential using its protected credential UI. Set `PROXO_SUPABASE_URL` to that credential's project URL and verify that the runtime permits the `$env` expression; if it does not, configure the nonsecret URL through the instance's approved variables before review. Never paste a service key into node parameters. Node versions follow the inspected workflow: HTTP Request 4.2, Code 2, IF 2.2, Respond to Webhook 1.1. Their compatibility with the actual runtime still requires import/editor validation.

The same migration excludes immutable attempts from legacy `fastpay_orders_to_poll` and `fastpay_expire_stale_orders`, and rejects old create/paid/refund RPC handling of immutable orders. These database checks do not replace the workflow guards: the existing gateway QR/refund POST occurs **before** some database RPCs.

## Rollout dependencies and acceptance

1. Apply and verify the additive schema/service guard on the intended staging database. Confirm anonymous/authenticated clients cannot execute the guard; the n8n service credential can. Confirm `AP…` is blocked even without a row, both by workflow and legacy RPCs.
2. Deploy the immutable payment adapter and verify its callback/polling recovery, exact quote/order/transaction binding, duplicate handling and unchanged ledger authority. Keep its paid feature gate off until its own acceptance succeeds.
3. Pause/drain the relevant legacy executions for controlled replacement; obtain fresh exports, regenerate this patch, review the exact diff, map credentials, and inspect node versions/expressions in the actual instance. Do not modify unrelated webhook paths or existing credentials.
4. Run staging cases for all five FastPay routes: valid legacy order, reserved `AP…` without a row, bound immutable order, missing/mismatched identity, missing guard RPC, 401/403/500, timeout, malformed JSON, duplicate IPN and multi-item polling. Assert **zero** legacy quote/gateway/refund/ledger/fulfillment calls for immutable or uncertain cases. Verify ordinary deposit/manual checkout behavior stays unchanged.
5. Verify legacy TikTok selection returns manual active/completed ads and excludes automatic active/completed ads. Verify all three update filters, then inspect real execution data for absence of automatic provider stop/spend updates. New automatic status/spend workers remain solely responsible for those ads.

Static local tests validate patch structure, expression behavior, preservation, failure routing and drift rejection. They do not establish n8n import, runtime credential mapping, provider API success, physical-device acceptance, or production rollout. The preparer performs none of those actions.

Primary node references: [HTTP Request error behavior](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/common-issues/), [Supabase node implementation](https://github.com/n8n-io/n8n/blob/master/packages/nodes-base/nodes/Supabase/Supabase.node.ts), [Supabase non-equality and null behavior](https://supabase.com/docs/reference/javascript/using-filters-neq).
