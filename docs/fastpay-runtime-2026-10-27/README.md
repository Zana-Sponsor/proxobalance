# FastPay n8n runtime audit — 27 October 2026

The repaired FastPay sandbox workflow is imported into n8n without the unavailable paid Variables dependency. Its updated manual runtime harness visibly passed **56 synthetic checks in n8n** and includes a separate default blank-configuration guard. **Real payment acceptance remains outstanding.** The published `FastPay Checkout + Supabase v12` workflow was not replaced or republished, and no production database migration or routing change was performed.

## Imported sandbox draft

The [inactive sandbox workflow](https://email.proxopages.com/workflow/pA8Zn5xnDitCmDiP), `Proxo legacy FastPay durable sandbox — INACTIVE`, was imported from the reviewed [152-node export](../../integrations/legacy-fastpay/proxo_fastpay_durable_sandbox.json).

After saving, an export confirmed:

- **152 nodes**, `active:false`, and **zero bound credentials**.
- All Code snippets and connections match the reviewed source graph.
- No `$vars` or `$env` dependency remains. All 30 nonsecret configuration literals are present; the default isolated URL and merchant reference remain empty.
- Import differences are n8n default normalization: omitted `onError:stopWorkflow`, omitted `neverError:false`, omitted default GET method and added empty IF `leftValue`. These did not replace any gate, request body or Code snippet.
- The dedicated staging paths, sandbox-only origin guard and main-project rejection remain in place. Refund and notification paths remain disabled.

The draft was not published or executed. Its selected credentials remain unconfigured.

![Imported inactive FastPay sandbox draft](fastpay-draft-imported-20261027.jpg)

## Actual n8n runtime result

The [manual-only runtime workflow](https://email.proxopages.com/workflow/8fLksW8MXDWJQ810), `Proxo FastPay runtime contract checks — MANUAL ONLY`, contains a Manual Trigger and one Code node. It ran manually and produced **`PASS` with `passedChecks:56`**. It remains inactive.

The [reproducible harness](../../integrations/legacy-fastpay/runtime-harness.mjs) derives a synthetic fixture from the actual sandbox export by changing only its compile-time nonsecret configuration. It embeds **16 Code snippets**, **four expressions** and the original contract factories without changing validation logic. It also executes the default blank configuration and asserts that it fails closed. There are no HTTP, webhook, schedule, credential or notification nodes, and no database or provider action is available to the harness. Template and configured-fixture provenance are recorded separately.

The screenshot directly confirms `PASS` and `passedChecks:56`. The executed harness emits the following summary fields, also verified in local rehearsal; fields below the screenshot fold were not separately read from the n8n UI:

```json
{
  "result": "PASS",
  "passedChecks": 56,
  "defaultConfigurationRejected": true,
  "syntheticOnly": true,
  "providerRequests": 0,
  "ledgerWrites": 0,
  "livePaymentAccepted": false
}
```

The successful updated run records these SHA-256 digests, calculated over `JSON.stringify` of each source:

| Artifact | SHA-256 |
|---|---|
| Default sandbox template | `6803c4d48f12792000d2dd74e7db1c1b709e792d6bc7a954e2e762eb964f6718` |
| Configured synthetic fixture | `78286852e156dfb33a49e8f87180b66893ebf407f8273d8ca47ba64f9adae59b` |

Checks cover sandbox target rejection, immutable-order isolation, original owner/order/amount binding, one authorization crossing the dispatch gate, retry recovery without dispatch, expiry, QR origin enforcement, malformed and non-200 evidence, independent callback validation, exact transaction/amount/currency matching, approved ledger confirmation, duplicate credit responses, nonterminal declines and historical-order recovery restrictions. They verify the supplied authority checks in n8n; they do not simulate a real financial settlement.

![n8n runtime output showing PASS and 56 checks](fastpay-runtime-pass-20261027.jpg)

## Remove the unavailable Variables dependency

The normal Variables UI allowed opening the create form, but saving `PROXO_LEGACY_FASTPAY_PUBLIC_ORIGIN` failed with `Error while saving variable` and `Plan lacks license for this feature`. No value was saved and no billing or upgrade change was made.

The updated sandbox generator uses ordinary Code/expression constants instead. Its optional public configuration JSON accepts only `supabaseUrl`, `publicOrigin` and `merchantReference`, validates the isolated target, and stamps all 30 copies consistently. It does not read `$vars`, `$env`, webhook fields or runtime input for configuration. Credentials remain unbound and must still be selected through n8n's protected credential UI. The default empty URL/merchant values fail closed before a request can be made; the main database remains prohibited.

The constant-based export was reimported, saved and compared with its source. The updated manual harness then ran successfully in n8n as recorded above. Local verification also passed 26 focused tests and a configured-CLI smoke check using synthetic public values.

## Remaining payment acceptance

The runtime result verifies Code/expression compatibility for these synthetic cases. It does **not** verify HTTP-node behavior, protected credential injection, database compatibility, provider responses or callbacks.

The sandbox still needs an isolated Supabase/backend target, migration preflight and the reviewed financial dependency chain, protected sandbox merchant and database credential bindings, a matching merchant reference, and registered sandbox callback. Then perform controlled QR/status/validation, interrupted checkout, duplicate callback, expiry and late-payment acceptance against that isolated target, confirming exactly one financial credit.

See the [setup instructions](../../integrations/legacy-fastpay/README.md) for the required public configuration and protected credentials. Production activation, the existing v12 workflow, production routing and domain assignments remain unchanged.
