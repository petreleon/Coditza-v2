# ADR 0005: Vercel public API and private grader topology

Status: accepted (bounded topology; private execution provider and launcher remain unselected)

Date: 2026-07-27

Decision owners: Coditza architecture and operations

Related tasks: OPS-VERCEL-001, DEC-007, DEC-032, ARC-WASM-001, OPS-HOST-001,
OPS-VERCEL-ENV-001, ARC-ENV-PROD-001, OPS-WASM-001.

## Context and authorization

The user requires Vercel as Coditza's eventual public API destination. Coditza
also requires authoritative Python-on-WebAssembly grading to execute inside a
fresh, disposable outer boundary with no network or DNS, no secrets, no host
mounts or container-engine socket, non-root/no privilege escalation, read-only
assets, hard resource limits, bounded temporary storage, and reliable teardown.
The private grader controller must never become a public HTTP function.

OPS-VERCEL-001 was a read-only public-documentation review. It did not create
or inspect a Vercel account, team, project, deployment, domain, environment
variable, token, billing object, or private host. It did not authenticate a
CLI, use Chrome, enter a secret, or change application, Compose, runtime, or
launcher code.

## Decision

1. **Vercel remains the required future public API boundary.** The public
   Fastify API may be deployed as Vercel's documented Fastify integration: one
   Vercel Function using Fluid compute. The documented entrypoint and lifecycle
   model must be explicitly adapted and tested later; this ADR does not claim
   that the current long-lived Docker listener deploys unchanged.
2. **The private grader controller and authoritative sandbox are separate
   private planes.** They are not mapped to a public Vercel Function, a public
   route, a cron endpoint, an API process, a Node worker thread, Node WASI, or
   a Docker socket.
3. **No private provider, Vercel Sandbox configuration, region, tier, cost,
   team, account, or launcher is selected here.** Vercel Sandbox is an
   investigated candidate, not an approved outer sandbox: its public
   documentation describes a `vercel-sandbox` user with `sudo` access and
   Python/Node runtimes with full root access. That is not evidence for
   Coditza's non-root/no-privilege-escalation boundary.
4. **A separately approved private execution capability is required before any
   hosted grader deployment.** Its minimum envelope is recorded below. The
   user must approve the exact provider, region, tier, owner, and cost before
   OPS-HOST-001 selects or creates it.
5. **Vercel environment scopes remain distinct.** Later work may bind approved
   API values only through OPS-VERCEL-ENV-001 (Development/Preview) and
   ARC-ENV-PROD-001 (Production). No variable value or scope was configured by
   this task.

This partially resolves DEC-007: the public/private split is decided, while
the exact private plane remains deliberately unresolved. DEC-032 remains fully
owned by ARC-WASM-001.

## Observed Vercel facts

The following are documented facts, accessed on 2026-07-27. Later work must
recheck plan-dependent values before it relies on them.

### Public Fastify Function

- Vercel documents zero-configuration Fastify deployment when a supported
  `app`, `index`, or `server` entrypoint is present. It says the Fastify app
  becomes a **single Vercel Function** and uses Fluid compute by default.
  [Fastify on Vercel, updated 2025-10-28](https://vercel.com/docs/frameworks/backend/fastify)
- Node Functions have a 250 MB function-bundle limit, a 4.5 MB maximum
  non-streaming request or response body, a shared 1,024 file-descriptor limit,
  and plan-dependent duration/memory/concurrency limits. With Fluid compute,
  documented Node maximum duration is 300 seconds on Hobby and up to 800
  seconds on Pro/Enterprise. A timeout produces a 504.
  [Vercel Functions Limits, updated 2025-12-18](https://vercel.com/docs/functions/limitations)
- Functions have a read-only filesystem with at most 500 MB writable `/tmp`;
  they are region-first and use a microVM isolation boundary. That scratch
  space is not durable application storage.
  [Vercel Function runtimes](https://vercel.com/docs/functions/runtimes)
- Node Functions receive `SIGTERM` on shutdown/scale-down and have up to
  500 ms for cleanup. Request cancellation and background work have distinct
  lifecycle rules.
  [Functions API reference, updated 2026-02-09](https://vercel.com/docs/functions/functions-api-reference)
- Function regions are configurable later; the default region and multi-region
  or failover availability are plan/configuration dependent.
  [Configuring Function regions, updated 2026-01-05](https://vercel.com/docs/functions/configuring-functions/region)

**Inference for Coditza:** Fastify's public HTTP API is a supported Vercel
plane, but the deployment adapter must be a serverless-aware entrypoint. It
must preserve the one composition root, use Supabase for durable state, avoid
module-global mutable request state, respect the smaller function shutdown
window, and keep grading asynchronous rather than holding one public request
open for a grader run. The current Docker listener, its ten-second shutdown
allowance, and any image-based deployment flow are not automatically the Vercel
Function contract.

### Artifacts, promotion, rollback, and scopes

- `vercel build` produces a `.vercel/output` Build Output API artifact that can
  be inspected and later deployed with `vercel deploy --prebuilt`.
  [Deploying Projects from the Vercel CLI, updated 2026-01-13](https://vercel.com/docs/cli/deploying-from-cli)
- A staged **Production** deployment can be promoted without a rebuild. A
  Preview-to-Production promotion rebuilds with Production environment
  variables; an instant rollback remaps production domains to an existing
  deployment rather than rebuilding it.
  [Promoting Deployments, updated 2025-09-24](https://vercel.com/docs/deployments/promoting-a-deployment)
- Variables can be scoped to Development, Preview, Production, and custom
  environments; a changed value applies to newly created deployments, not
  already-created ones. Standard variable values are visible to project users.
  [Environment Variables, updated 2025-09-24](https://vercel.com/docs/environment-variables)
- Vercel documents Sensitive Environment Variables as non-readable after
  creation and limited to Preview/Production. That reduces dashboard readback,
  not the need for application-level redaction or separated runtime scopes.
  [Sensitive Environment Variables, updated 2025-10-07](https://vercel.com/docs/environment-variables/sensitive-environment-variables)

**Inference for Coditza:** a future public release may use an inspected,
staged-production Build Output artifact and promote that same Production build
without rebuilding it. A Preview artifact must not be called the identical
Production artifact when their variable scopes differ. The release evidence
must retain the deployment identity, source revision, exact Build Output or
OCI digest as applicable, variable-scope proof without values, and rollback
candidate. This does not yet prove a compatible path for the existing OCI
image; OPS-SOURCE-001/OPS-ARTIFACT-001/OPS-HOST-001 must establish that path.

### Vercel isolation products

- Ordinary Vercel Functions provide a microVM, read-only filesystem, and
  writable `/tmp`, but the public documentation reviewed here does not provide
  a per-function no-egress policy, an enforced non-root identity, or a proof of
  a secret-free process environment.
- Vercel Sandbox is an ephemeral Firecracker microVM with its own filesystem
  and network. Its documentation expressly describes the `vercel-sandbox` user
  with `sudo` access and built-in Python/Node runtimes with full root access.
  [Vercel Sandbox, updated 2026-01-30](https://vercel.com/docs/sandbox)
- Sandbox egress is unrestricted by default. Vercel documents a `deny-all`
  egress policy and allowlist controls, which can reduce network access only
  when configured and verified.
  [Sandbox egress firewall, 2026-02-11](https://vercel.com/changelog/advanced-egress-firewall-filtering-for-vercel-sandbox)

**Conclusion:** Vercel Functions are not a proven Coditza outer sandbox. Vercel
Sandbox has useful isolation and deny-egress capabilities, but its documented
root/sudo and writable-filesystem model fails to prove the required
non-root/no-privilege-escalation/read-only boundary. Neither is selected as the
authoritative launcher on documentation alone.

## Rejected options

| Option | Decision | Reason |
| --- | --- | --- |
| Put all five planes in a public Vercel Function | Rejected | A Function cannot prove the required no-network, secret-free, non-root, read-only disposable sandbox; it would also make the controller a public process. |
| Treat Vercel Sandbox as already compliant | Rejected | Default egress is open and the public product documentation advertises `sudo`/full root and writable filesystem behavior. A future proof cannot omit these facts. |
| Give the API or controller a general Docker socket | Rejected | It breaks the host-isolation boundary and fixed Coditza decisions. |
| Use Node worker threads, Node WASI alone, or in-process Pyodide as the boundary | Rejected | Those are runtime mechanisms, not the required outer isolation boundary. |
| Replace Vercel with another public API host | Rejected | It conflicts with the user's Vercel direction; a new user decision and ADR would be required. |
| Mix Development, Preview, or Production credentials | Rejected | It removes the required deployment/environment isolation and makes an immutable release claim unreliable. |

## Required private-execution envelope

Before a provider or launcher may be selected, it must demonstrate all of the
following for a fresh authoritative run:

- a controller with no public listener, reachable only through a narrow,
  authenticated internal create/run/terminate protocol;
- no public HTTP trigger, no API process execution, no general shell, no host
  mount, no Docker/container-engine socket, and no broad cloud credential;
- fresh disposable isolation per run; no network or DNS; no package download;
  no inherited secret, Auth/TOTP material, answer key, controller credential,
  or writable snapshot;
- enforced non-root identity and no privilege escalation, immutable runtime and
  asset mounts, a bounded writable temporary area, and teardown verification;
- hard CPU, memory, process, wall-clock, output, IPC, file, and queue limits;
- immutable runtime/asset digest verification, deterministic protocol evidence,
  bounded concurrency and leases, and a rollback path that preserves evidence;
- distinct controller-only credential scope, distinct development/production
  bindings, egress/cost accounting, operator ownership, and alert/log
  redaction.

This is a capability envelope, not a provider comparison or authorization to
spend money. No provider, region, tier, account, owner, or price is named.

## Five-plane topology

```text
Public Internet
      |
      v
Vercel Fastify Function (public API only) ----> Supabase / approved public-plane services
      |
      | authenticated, narrow internal job intent; never arbitrary code
      v
Private grader controller (separately approved private plane; no public route)
      |
      | narrow launch/collect/terminate protocol; no Docker socket
      v
Fresh authoritative sandbox (separately approved + ARC-WASM-001 proven)

Immutable Pyodide/Python assets: verified build/runtime input only; never downloaded by a run
One-off migration/release job: separate serialized credential scope; never API startup
```

The accompanying [capability matrix](../implementation/OPS-VERCEL-001-capability-matrix.md)
maps each plane to evidence, gaps, credentials, costs, and later ownership.

## Consequences and handoff

- **ARC-WASM-001** owns DEC-032. It must select and adversarially prove the
  exact local launcher, Pyodide/Python manifest, protocol, limits, teardown,
  and a truthful hosted-capability requirement. It may not present Vercel
  Sandbox, Function isolation, a worker thread, WASI, or a Docker socket as a
  compliant result without proving every required property.
- **OPS-HOST-001** begins only after G6, OPS-SOURCE-001, and explicit
  external-creation approval. It must select/create the exact Vercel public
  boundary and, only after user approval, the private execution provider.
  It must name service/account/region/tier/cost/owner, validate health/proxy,
  release locking, egress, logs, and an immutable rollback path.
- **OPS-VERCEL-ENV-001** later binds approved Development/Preview API
  variables. **ARC-ENV-PROD-001** later binds Production values. Neither task
  may mix the scopes or disclose values in evidence.
- **OPS-WASM-001** later owns Python/WASM supply-chain evidence. Vercel CDN,
  function filesystem, or a sandbox snapshot is not by itself the required
  runtime provenance proof.

## Validation and stop conditions

This ADR is valid only as a documentation-based topology decision. It has no
deployment, provider-selection, or sandbox-compliance result. Stop and obtain
explicit user approval before selecting or creating a private host, Vercel
project, Sandbox configuration, region, tier, cost commitment, account/team,
credential binding, or deployment. If the future provider cannot prove every
private-execution property, Python exercise publication and deployment remain
blocked rather than using a weaker fallback.
