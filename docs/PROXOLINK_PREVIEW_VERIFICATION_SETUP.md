# ProxoLink preview verification setup

This procedure does not authorize customer cutover, database writes, merge, production deployment, legacy deletion or credential rotation affecting production consumers. PR #7 stays Draft. Never put credential values in chat, source, commits, screenshots, logs or reports. ProxoLink has NO Telegram integration or Telegram testing/credential requirement; historical credential revocation is a separate owner security action.

## 1. Reconnect Vercel using the project-owning identity

1. Open [the Vercel project](https://vercel.com/proxoapp-1758/proxobalance) in your own browser. Confirm the account can open `proxobalance` under team `proxoapp-1758`.
2. In ChatGPT, open Plugins, then Installed, then Vercel. Open its connected-account controls and choose Reconnect. If the interface only offers Disconnect/Connect, reconnect the existing Vercel account that way; do not uninstall the plugin or create a second custom MCP server.
3. Complete Vercel's OAuth prompt using the same project-owning account. If an account/team/project selector appears, select `proxoapp-1758` / `proxobalance` only. Review the requested provider permissions.
4. Vercel's documented MCP access follows the connected Vercel user's access. A project-only OAuth picker is not guaranteed. On this Hobby team, use the existing project-owning account. On plans with project RBAC, a team owner can grant the connected identity the needed project role through project Access. Do not grant unrelated identities broader access or change project ownership.
5. Return to this conversation with a non-secret confirmation. We will recheck project/deployment access. The current connection can list the team but still returns Project not found for `proxobalance`, so installation alone is not sufficient proof of project access.

If the owner account can open the project but the reconnected integration still cannot, stop and diagnose the connection; do not disable protection or paste an API token into chat as a workaround.

References: [ChatGPT plugins](https://learn.chatgpt.com/docs/plugins), [Vercel MCP access](https://vercel.com/docs/agent-resources/vercel-mcp), [Vercel project roles](https://vercel.com/docs/rbac/managing-team-members).

## 2. Create the protected GitHub testing environment

Use a GitHub account with repository administration permission.

1. Open [Zana-Sponsor/proxobalance](https://github.com/Zana-Sponsor/proxobalance), then Settings → Environments → New environment.
2. Name it exactly `proxolink-preview-verification`, then select Configure environment.
3. Under Required reviewers, add the owner or a trusted reviewer who will inspect the workflow identity and commit before releasing the secrets. Save protection rules. If only one owner is available, leave Prevent self-review off; if a second trusted reviewer is available, enable it.
4. Deselect Allow administrators to bypass configured protection rules and save.
5. Under Deployment branches and tags, select Selected branches and tags. Add a **Branch** rule with the exact pattern `feat/proxolink-private-renderer-migration`. Do not allow `main`, other branches, or tags.
6. In this environment's Environment variables, select Add variable and add `PROXO_NATIVE_ANON_KEY`.
7. In this environment's Environment secrets, use Add secret for the three names below. Do not create repository-wide copies of the password or bypass secret. If copies were already created under Settings → Secrets and variables → Actions, remove only those duplicate credential settings after the environment entries are in place; this does not involve customer/legacy data.

| Exact name | Type/location | Value entered privately |
| --- | --- | --- |
| `PROXO_NATIVE_ANON_KEY` | Environment variable | Project `cojchkwssmasiejcgvbk` publishable key (`sb_publishable_...`) or legacy `anon` key, from Supabase project Settings → API Keys |
| `PROXO_NATIVE_TEST_EMAIL` | Environment secret | An existing ordinary verification account's email |
| `PROXO_NATIVE_TEST_PASSWORD` | Environment secret | That account's password |
| `PROXO_NATIVE_VERCEL_BYPASS` | Environment secret | The dedicated temporary automation secret described next |

Use an ordinary account without an administrator role. The runner rejects cross-owner access and service-role/secret API keys. It signs in and makes read-only application/Storage/PostgREST requests; it does not create cards, advertisements, links or events. Creating a new account in the live Auth project is outside this no-production-mutation pass. If there is no existing ordinary verification account, identify that blocker without sending an email/password here so an isolated test-account/staging arrangement can be authorized.

GitHub environment secrets are released only after environment protection rules pass. Other jobs receive no testing credentials. The configured runtime job is restricted to the exact repository/branch and an explicit live-test request. The reviewer must approve **Build ProxoLink native verification / native-runtime** at the reviewed feature-branch SHA; decline requests from any other workflow or unexpected commit. GitHub environment secrets are environment-scoped, not cryptographically tied to one workflow file, so this identity review is part of the access restriction.

References: [GitHub environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments), [GitHub environment secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets), [Supabase API keys](https://supabase.com/docs/guides/getting-started/api-keys).

## 3. Create a dedicated temporary Vercel automation secret

1. In your own Vercel browser, open team `proxoapp-1758` → project `proxobalance` → Settings → Deployment Protection.
2. Keep existing Vercel Authentication/protection settings enabled.
3. In Protection Bypass for Automation, create a separate secret for this testing workflow, with a descriptive label such as `proxolink-preview-verification`. Do not regenerate an existing secret used by another integration, select a production redeploy, or alter the current system environment-variable selection.
4. Copy the new value directly into the GitHub **environment secret** `PROXO_NATIVE_VERCEL_BYPASS`, then close the credential view. Do not use a sharable URL/query parameter or include the value in a screenshot.
5. After the authorized run finishes, revoke this dedicated secret in Vercel and remove the temporary GitHub bypass/password secrets. Keep deployment protection enabled.

Important platform limit: Vercel automation secrets are **project-wide** and can bypass protection on all deployments in that project until revoked. They are not intrinsically preview-only, workflow-bound, or automatically time-limited. The restricted GitHub environment, required reviewer, explicit branch/workflow checks, pinned runtime actions, fixed preview origin and immediate revocation restrict how this workflow obtains and uses the secret. If a provider-enforced preview-only credential is required, do not create this project-wide secret; an isolated preview project is required instead.

The runner sends the bypass only as an HTTP header to the fixed feature Preview. It never sends it to Supabase or production and never follows redirects carrying credentials. Application catalog requests still require a valid ordinary Supabase bearer session; signed preview capabilities remain purpose-bound and expire after five minutes. The workflow explicitly checks that the bypass without app authentication gets HTTP 401 and that Supabase RLS/internal-table restrictions remain effective. No service-role credential is supplied to the verification workflow.

Reference: [Vercel Protection Bypass for Automation](https://vercel.com/docs/deployment-protection/methods-to-bypass-deployment-protection/protection-bypass-automation).

## 4. Trigger and review the new verification run

1. Once the configuration above is complete, reply only `Configuration complete` in this conversation, without values or credential screenshots.
2. We will recheck Vercel access and trigger the current feature-branch workflow with an explicit `[proxolink-live-verification]` request. Do not rerun the old `d9894d9` job: it predates the environment restrictions and expanded checks.
3. The workflow may not offer Run workflow while its definition exists only on this feature branch. No merge into `main` is needed: a tagged feature-branch commit can trigger the authorized push workflow. A no-code-change commit can request that run.
4. Open repository Actions → Build ProxoLink native verification → the new run. Approve the waiting `proxolink-preview-verification` environment job only after confirming its workflow file, feature branch and reviewed commit.
5. The credential-free APK build runs first. After approval, a KVM-backed Android 35 emulator runs all eight real server pages through the production `ProxoLinkPreview` widget at 320/393/430/768 dp: **32 cases**.
6. Results must include 32 successful cases and 32 screenshots, loaded/applied Rabar and icon fonts, decoded images, advancing CSS animations, modal open/cancel/reopen/confirm-close, working original WhatsApp/Viber/Instagram/phone confirmation UI and inert demonstration destinations, plus an inert TikTok badge and absence of Telegram controls, no horizontal overflow and blocked external/other-path/invalid-capability/file navigation. Demo contact launches are deliberately suppressed; no calls or messages are sent.
7. Read-only security results must confirm app-authentication independence, ordinary-user RLS, denied internal template/link/event/audit reads, denied private public-object URLs, invalid capabilities and response CSP/cache/referrer headers. Only allowlisted booleans/numbers/case identifiers and controlled demo screenshots are uploaded; runtime tokens, URLs, Auth session and credentials are excluded.
8. We will inspect artifacts and report each result honestly. A build-only, skipped, partial or configuration-failed job is not native certification. Missing settings now fail an explicitly requested runtime job.

## 5. Owner/device work still required

- **Historical credential (separate one-time security action, NOT a ProxoLink dependency):** the bot owner should revoke the historically exposed token through verified [@BotFather](https://t.me/BotFather) using `/revoke`. No new bot, replacement token or chat ID is needed for ProxoLink. Coordinate revocation only with owners of unrelated services still using that credential; do not paste any token into chat.
- **Supabase:** coordinate rotation of the historically exposed service-role credential and replacement in legitimate server consumers separately. Do not put the replacement in this workflow or chat; this no-production-change pass does not rotate it.
- **Android external applications:** demo tests validate destinations and prevent unwanted launches. Actual app handoff/fallback for WhatsApp, Viber, Instagram, TikTok and phone links requires an authorized device/test contact and a separate safe fixture or isolated staging setup.
- **iOS:** a Mac/Xcode runner plus an iOS simulator or device is required to verify WKWebView rendering, RTL, fonts, motion, responsive layouts and navigation. A physical device with the destination apps is needed for real external-app handoff/fallback. Signing/distribution, if needed, stays in the owner's secure provider settings.
- **Write-path/public-avatar/exact-ad live tests:** existing customer cards remain uncutover and no advertisement links exist. New create/edit/retry/activate/delete/attachment/analytics fixtures cannot be exercised on the live database under the no-production-mutation constraint. Use an isolated staging database/project, or obtain separate explicit authorization for named disposable fixtures. Existing automated regressions and earlier live results do not replace current end-to-end tests.
- **Legacy card access:** RLS remains enabled, but authenticated owner CRUD and legacy-field reads remain until the separately approved cutover restricts clients to safe structured columns and server-only mutations. The other internal template/link/event/audit tables already deny client access. No permission or data changes are made by this verification workflow.
- **Cutover/merge/production/legacy cleanup:** remain prohibited without later separate explicit approval. Preserve all 21 customer cards, 27 advertisements, 16 card relationships and all original template designs.
