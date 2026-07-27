# Next task

The sole next implementation task is:

**OPS-VERCEL-001 — Verify the Vercel deployment topology before sandbox selection.**

Prerequisites verified: G1, ARC-DESIGN-001, and PRD-WASM-001 are complete. The
user has explicitly requested Vercel as the eventual public API destination.
This is a review-only task: it may research current official documentation and
write local decision evidence, but it must not create, configure, authenticate,
or deploy an external resource.

## Read first

1. README.md
2. TASKS.md
3. STATUS.md
4. 00-control/00-scope-and-non-goals.md
5. 00-control/01-fixed-decisions.md
6. 00-control/02-open-decisions.md, especially DEC-007 and DEC-032
7. 00-control/03-execution-protocol.md
8. 02-architecture/00-system-boundaries.md
9. 02-architecture/05-release-credentials.md
10. 02-architecture/07-python-wasm-verification.md
11. 07-operations/01-deployment-environments.md
12. 08-execution/00-roadmap.md
13. 08-execution/01-dependency-map.md
14. 08-execution/02-phase-gates.md
15. 08-execution/03-handoff-protocol.md
16. 09-templates/00-task-report-template.md
17. docs/adr/0001-modular-monolith-and-ports-adapters.md through
    docs/adr/0004-configuration-ownership-and-phase-one-api-parser.md
18. docs/implementation/PRD-WASM-001.md, ARC-DESIGN-001.md, QA-STRAT-001.md,
    and the current Docker reports

## Permitted scope

Use current official Vercel documentation only for read-only capability research.
Write a local topology ADR, capability matrix, implementation report, and
tracker updates after evidence passes. The ADR should use the next available
number and a descriptive filename such as 0005-vercel-public-api-and-private-
grader-topology.md.

Do not create a Vercel project, team, deployment, domain, environment variable,
token, CLI login, API call with credentials, billing commitment, Supabase
project, SMTP configuration, Docker sandbox, or private host. Do not select a
supplemental host. Do not change application code, runtime images, Compose,
secrets, or the Python launcher. Do not use Chrome for this task; Chrome is
reserved for later explicitly authorized Dashboard operations.

## Required research and decision record

1. Read current official Vercel documentation and record publication dates or
   access dates plus direct official URLs for:
   - the supported public Node/Fastify API deployment model;
   - request/body, duration, streaming, shutdown, concurrency, filesystem, and
     network limits relevant to this API;
   - deployment artifact, build, immutable promotion, rollback, logging,
     health/proxy, region, and egress behavior;
   - environment-variable scopes and secret masking;
   - documented isolation boundaries and whether any can prove Coditza's
     required disposable no-network, secret-free, non-root, read-only,
     resource-limited outer sandbox.
2. Build a capability matrix covering five planes separately:
   - public Fastify API;
   - private grader controller;
   - immutable Pyodide/Python assets;
   - one-off migration/release job;
   - disposable authoritative sandbox.
   For each plane record required capabilities, Vercel evidence, gaps,
   credential scope, network/egress exposure, cost/ownership effect, rollback
   implication, and the task that owns later implementation.
3. Preserve the fixed architecture:
   - Vercel remains the requested eventual public API boundary.
   - The grader controller is never a public function.
   - No Vercel function or runtime is presumed to be the hardened sandbox.
   - The API/controller never receives a general Docker socket.
   - Development and production scopes remain separate.
4. Make one of two evidence-based outcomes:
   - if Vercel can serve the public API but not the private grader/sandbox,
     document the minimum supplemental-host capabilities only and stop for
     explicit user approval before selecting a provider, region, tier, cost, or
     owner;
   - if current official documentation is insufficient to establish a safe
     topology, record the precise uncertainty and ask the smallest user
     question needed. Never fill a gap with a serverless, worker-thread,
     WASI-only, or Docker-socket fallback.
5. Create the topology ADR and report. They must separate observed documented
   facts from inferences, cite sources near each claim, state the current date,
   include a no-external-action confirmation, and name the exact handoff:
   ARC-WASM-001 selects/proves the launcher, OPS-HOST-001 later selects/creates
   approved external boundaries, and OPS-VERCEL-ENV-001 later binds approved
   development/preview variables.

## Required verification before completion

- Every factual capability claim is supported by a current official Vercel
  source; distinguish an inference from a quoted or documented fact.
- Confirm no browser login, CLI authentication, project creation, deployment,
  secret entry, billing action, or hosted-state mutation occurred.
- Verify the ADR/capability matrix rejects a public controller, a general Docker
  socket, an unproven sandbox, mixed development/production scopes, and a
  silent replacement of Vercel as public host.
- Run the relevant documentation-link and task-registry checks, inspect the
  diff for scope and secret safety, and run git diff --check.
- Create docs/implementation/OPS-VERCEL-001.md and synchronize the deployment
  checklist, DEC-007/DEC-032 state if evidence warrants it, TASKS.md,
  STATUS.md, roadmap, dependency map, scope guardrail, README, and this file
  only after acceptance evidence passes.

## Stop conditions

Stop and ask the user before selecting or creating any supplemental private
grader/sandbox provider, region, tier, paid service, account, Vercel project,
or credential binding. The user's earlier Vercel direction authorizes this
review, not a supplemental-host decision or any external resource.
