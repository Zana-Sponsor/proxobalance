# Vercel deployment audit — 20 October 2026

Read-only deployment/HTTP recheck at 08:02 UTC after source publication. The connected Vercel plugin works for deployment metadata. The separate schema/environment-name inventory below was checked at 07:23 UTC. This audit did not promote a deployment, change configuration, decrypt an environment value or weaken protection.

| Target | Deployment | Source | State |
| --- | --- | --- | --- |
| `www.proxobalance.app` | `dpl_8Yj2cQBAYdifPzz4EUvuvuZQ3WsA` | `main` · `3c457e4ec1a326f33814d1cf5f19caa826e27fd0` | READY production |
| [PR 44 preview](https://proxobalance-l9uwi2dqe-proxoapp-1758.vercel.app) | `dpl_4Tm55uKBwNWUUT1R6ky8xRcBWypQ` | `codex/auth-ux-redesign` · `9fdd08d14f982e40221455cc4ab5dac0f3c368e3` | READY preview |

The new preview became ready on 20 October at 07:56:59.418 UTC. The live alias still resolves to the same production deployment and `3c457e4` source after this publication. A READY preview does not change the application's production API origin or certify authenticated application behavior. The earlier `5a6167e` preview and 07:23 observations are retained separately in the machine-readable history.

## Current boundary checks

- Production `/api/page-providers`: HTTP 404, JSON code `404` and message `The page could not be found` in this recheck. The earlier 07:23 response was plain-text `NOT_FOUND`; both observations show the required route is absent.
- Production `/api/proxolink?op=providers`: HTTP 404, JSON `not_found`.
- Production `/api/contact-templates`: HTTP 401, JSON `unauthorized`; authentication is required, but no authenticated production request was made.
- New preview `/api/page-providers`: HTTP 401, JSON code `401` and message `Protected deployment`. No redirect was followed and no protection bypass was attempted. This is a deployment-protection response, not proof of application authentication or provider availability. The previous preview's login-page HTTP 200 is also retained as blocked evidence, not an API pass.
- At 07:23, fourteen environment names were returned with decryption disabled. They are shared preview/production entries with no branch override in the returned list. `PROXO_V6_WRITE_MODE` was not among those returned names. Values were not examined or copied; this metadata was not re-read during the 08:02 deployment check.
- The 07:23 live Supabase schema inventory lacks the independent-page columns, and the post-consent branch inventory is empty. Neither was mutated as part of source publication or this deployment audit.

After the read-only audit, the coordinator requested an isolated Supabase branch named `proxo-ui-acceptance-20261020`. The provider-managed cost-consent flow returned `Invalid or expired requestState` (`INVALID_ARGUMENT`). A fresh branch listing after the error again returned `[]`. No approved cost, created branch, database change or isolated server is claimed; the expired flow was not retried.

## Contract comparison

| Contract | Deployed production | Current branch |
| --- | --- | --- |
| Prepared template version | 6 | 6 |
| Prepared styles | pill, pill-mint, pill-dark, pill-white | Same four |
| Page type field | `page_type` | `page_kind` |
| Page types | contact, food, download | contact, order, download |
| Provider input | `platforms` map | `settings.providers` list |
| Page identity | Request UUID reused as page UUID | Database UUID distinct from request UUID |
| Public path | Legacy `/contact/{id}` | Typed `/{page_kind}/{id}` |
| Management state | Legacy row fields | Additional archive/moderation contract |

The source at the exact deployed SHA was inspected locally. The production catalog already supports version 6 and the legacy create handler exists. No production create was attempted; it may work with a matching legacy client. The incompatibility is between that deployed contract and the current independent-page APK.

The provider documentation and returned metadata support using an isolated environment for the remaining hosted checks. Supabase branching uses a separate instance/credentials and does not include data or Storage objects by default; schema readiness depends on migration history/repository migrations. [Official branching documentation](https://supabase.com/docs/guides/deployment/branching). The 20 October changelog check found no relevant API change explaining this missing application route. [Official changelog](https://supabase.com/changelog).

[Machine-readable facts](vercel-readiness.json) · [Client recovery and remaining blocker](page-readiness.md) · [Isolated rollout plan](isolated-rollout-plan.md)
