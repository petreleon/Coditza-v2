# OPS-VERCEL-001 — Verify the Vercel deployment topology before sandbox selection

Outcome: COMPLETE

Environment: NONE (read-only public documentation research)

Date: 2026-07-27

Agent/person: Codex

Authorization checked: The user directed Coditza's future public API to Vercel
and authorized implementation generally. This task's owner restricted work to
official-documentation review and local decision evidence. It did not authorize
Vercel login, project/team creation, deployment, environment-variable entry,
CLI authentication, API call with credentials, billing action, Chrome use,
private-host selection, or Python-launcher implementation.

Prerequisites/gate checked: G1, ARC-DESIGN-001, and PRD-WASM-001 are complete.
OPS-VERCEL-001 was the sole `next` task when work began.

## Decision

ADR 0005 accepts the bounded topology: Vercel is the future public Fastify API
boundary, while the private grader controller and authoritative sandbox remain
separate private planes. The exact private provider/launcher is intentionally
unselected. This narrows DEC-007 without resolving DEC-032.

The review found that a Vercel Fastify application is documented as one Vercel
Function using Fluid compute, so it fits the public API plane subject to a
future serverless-aware adapter and lifecycle proof. It does **not** fit the
authoritative execution boundary by default. Vercel Sandbox has useful
Firecracker/deny-egress capabilities but documents `sudo`/full root and a
writable filesystem; it cannot be claimed as Coditza's non-root/no-privilege-
escalation/read-only outer sandbox on documentation alone.

## Scope

- Intended: current official Vercel capability review, five-plane map,
  topology ADR, capability matrix, and tracker synchronization.
- Explicitly excluded: application code, Fastify adapter, Compose, Docker,
  Python assets/launcher, Vercel or private-host resource creation, any
  credential/variable handling, billing, provider selection, and Chrome.

## Changed

- `docs/adr/0005-vercel-public-api-and-private-grader-topology.md`: accepted
  public/private topology, documented facts versus inferences, rejected
  fallbacks, private-execution envelope, and handoff.
- `docs/implementation/OPS-VERCEL-001-capability-matrix.md`: five-plane
  capability, isolation, credential, egress, artifact/rollback, cost, and
  ownership matrix.
- The operations checklist and control/status/roadmap/dependency handoff files:
  record completion and make ARC-WASM-001 the sole next task without granting
  any external action.

## Evidence and findings

- [Fastify on Vercel](https://vercel.com/docs/frameworks/backend/fastify)
  (updated 2025-10-28): recognized Fastify entrypoint, one Function, Fluid
  compute by default, and Function limitations apply.
- [Vercel Functions Limits](https://vercel.com/docs/functions/limitations)
  (updated 2025-12-18): bundle/body/duration/memory/concurrency/file-descriptor
  constraints and usage dimensions.
- [Vercel Function runtimes](https://vercel.com/docs/functions/runtimes):
  microVM, read-only filesystem, and bounded `/tmp` facts.
- [Functions API reference](https://vercel.com/docs/functions/functions-api-reference)
  (updated 2026-02-09): shutdown/cancellation constraints, including the
  500 ms `SIGTERM` cleanup window.
- [Environment Variables](https://vercel.com/docs/environment-variables)
  (updated 2025-09-24) and
  [Sensitive Environment Variables](https://vercel.com/docs/environment-variables/sensitive-environment-variables)
  (updated 2025-10-07): scopes, deployment timing, and masking limitations.
- [Deploying Projects from the Vercel CLI](https://vercel.com/docs/cli/deploying-from-cli)
  (updated 2026-01-13) and
  [Promoting Deployments](https://vercel.com/docs/deployments/promoting-a-deployment)
  (updated 2025-09-24): Build Output, staged Production promotion, preview
  rebuild, and rollback implications.
- [Vercel Sandbox](https://vercel.com/docs/sandbox) (updated 2026-01-30) and
  [Sandbox egress firewall](https://vercel.com/changelog/advanced-egress-firewall-filtering-for-vercel-sandbox)
  (2026-02-11): Firecracker, default open egress, deny-egress capability, and
  documented sudo/full-root conflict with the Coditza sandbox contract.

Every factual claim above is a public official Vercel source accessed on
2026-07-27. The ADR labels Coditza-specific conclusions as inferences.

## Required handoff

- **ARC-WASM-001** is now sole next task. It owns DEC-032 and must select and
  prove exact immutable Pyodide/Python assets plus a local outer launcher. It
  must retain every required no-network/secret-free/non-root/read-only/resource
  control; no worker-thread, WASI-only, in-process, Vercel Function, Vercel
  Sandbox, or Docker-socket fallback is accepted without that proof.
- **OPS-HOST-001** occurs only after G6, OPS-SOURCE-001, and a fresh explicit
  approval. It must select/create the exact Vercel public boundary and then,
  if ARC-WASM-001 requires it, a private runner provider only after naming
  provider/service/region/tier/cost/owner.
- **OPS-VERCEL-ENV-001** later owns Development/Preview API variable bindings;
  **ARC-ENV-PROD-001** later owns Production bindings. Neither is authorized
  now.

## Verification

- Official-source and topology review
  - Result: PASS.
  - Non-secret evidence: each matrix plane has a direct official source or an
    explicit documented gap; facts and Coditza inferences are separated.
- Required topology rejections
  - Result: PASS.
  - Non-secret evidence: ADR 0005 rejects public grader controller, general
    Docker socket, worker-thread/WASI/in-process fallback, unproven sandbox,
    mixed environment scopes, and non-Vercel replacement of the public API.
- External-action audit
  - Result: PASS.
  - Non-secret evidence: no browser login, Chrome action, CLI authentication,
    Vercel/private-host API action, project/deployment/domain/variable/token,
    secret entry, billing action, or hosted-state mutation occurred.
- Local documentation and registry checks
  - Result: PASS.
  - Non-secret evidence: all 134 repository Markdown files resolve their local
    relative targets; the task registry has exactly one `next` task
    (ARC-WASM-001), no `in progress` task, and the OPS-VERCEL-001 owner
    checklist has no remaining unchecked item.
- `git diff --check`
  - Result: PASS.
  - Non-secret evidence: the reviewed documentation/tracker diff has no
    whitespace errors.

## Risks and blockers

There is no blocker for this review task. Hosted Python grading remains blocked
until ARC-WASM-001 proves a compliant outer launcher and the user later
approves any private provider selection/creation. Exact Vercel team/project,
region, tier, cost, owner, release job, and environment values remain deferred.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer,
TOTP/QR/`otpauth`/factor/challenge material, or unsafe log was recorded.

## Next

ARC-WASM-001 is the sole next local task. It must not create or select hosted
resources while it resolves DEC-032.
