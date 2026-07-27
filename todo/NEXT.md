# Next task

The sole next implementation task is:

**ARC-WASM-001 — Approve and pin the Python/WASM execution boundary.**

Prerequisites verified: G1, ARC-DESIGN-001, PRD-WASM-001, FOUND-001, and the
reviewed public/private deployment topology in
[ADR 0005](../docs/adr/0005-vercel-public-api-and-private-grader-topology.md)
are complete. This is a **local** architecture/proof task. It owns DEC-032 and
must not create, select, configure, authenticate, deploy, or pay for Vercel or
any private host.

## Read first

1. README.md
2. TASKS.md and STATUS.md
3. 00-control/00-scope-and-non-goals.md
4. 00-control/01-fixed-decisions.md
5. 00-control/02-open-decisions.md, especially DEC-007 and DEC-032
6. 00-control/03-execution-protocol.md
7. 02-architecture/00-system-boundaries.md
8. 02-architecture/01-target-project-structure.md
9. 02-architecture/02-environments-and-secrets.md
10. 02-architecture/04-data-flow-and-security.md
11. 02-architecture/07-python-wasm-verification.md in full
12. 03-supabase/13-python-code-verification-data.md
13. 04-fastify/06-python-wasm-runner.md
14. 06-quality/06-python-wasm-verification.md
15. 07-operations/07-python-wasm-supply-chain.md
16. 07-operations/01-deployment-environments.md
17. 08-execution/00-roadmap.md, 01-dependency-map.md, 02-phase-gates.md, and
    03-handoff-protocol.md
18. docs/adr/0001-modular-monolith-and-ports-adapters.md through
    docs/adr/0005-vercel-public-api-and-private-grader-topology.md
19. docs/implementation/PRD-WASM-001.md, OPS-VERCEL-001.md, and
    OPS-VERCEL-001-capability-matrix.md

## Permitted scope

Select and prove an exact local authoritative Python/WASM execution boundary;
write the required ADR, runtime lock manifest, threat/ownership/composition/
deployment/data-flow inventory updates, protocol schemas, tests, and task
report. A local Docker or equivalent proof is permitted only if its exact local
resource scope is reviewed first and it never uses a Docker socket from the API
or controller. Keep work to ARC-WASM-001 and its named local proof.

Do not create or configure a Vercel project, Vercel Sandbox, private cloud host,
account, region, tier, billing commitment, deployment, Chrome Dashboard state,
Supabase project, SMTP setting, hosted environment variable, or credential.
Do not select a hosted private runner provider. Do not change public API
deployment topology. Do not turn a Node worker thread, Node WASI, in-process
Pyodide, Vercel Function/Sandbox, or a Docker socket into the claimed security
boundary.

## Required evidence

1. Write an ADR that selects the exact supported Pyodide/Python version and
   exact browser/server asset bundle, and selects/proves a **local** outer
   launcher. Record asset URLs/digests/licenses/provenance and why the choice
   is supported at the time of review.
2. Commit a runtime lock manifest with immutable hashes and prove an offline,
   clean load from the reviewed local asset set. No package/runtime download may
   occur during a learner run.
3. Add the private grader-controller execution plane to the ownership,
   composition, deployment, data-flow, and threat-model inventories without
   making a public service or generic job framework.
4. Prove the outer launcher—not merely WASM—enforces a fresh run with no
   network/DNS, no secrets/Auth/TOTP/database capability, no host mounts or
   Docker socket, enforced non-root/no privilege escalation, read-only assets,
   bounded temporary storage, CPU/memory/process/wall/output/IPC limits, and
   deterministic cleanup. Include adversarial negative tests for every claim.
5. Specify strict versioned request/result schemas with unknown-field
   rejection, canonical package/verdict reuse, lease/retry/overload/shutdown/
   deterministic-mismatch behavior, and no partial finalization.
6. Prove no Auth/TOTP or database capability crosses into runner input/output,
   logs, artifacts, or public feedback.

## Stop conditions

Stop and ask the user before selecting or creating any hosted provider, Vercel
Sandbox, project/account, region, tier, paid service, credential binding, or
deployment. If no local launcher can prove every required property, record a
sanitized blocker and leave DEC-032 unresolved; do not weaken the contract.

## Completion handoff

Run the active task's focused tests plus relevant lint/type/build and
documentation/registry checks. Inspect the diff and secret safety. Create
`docs/implementation/ARC-WASM-001.md`, update its owner checklist and the
single task registry/status/roadmap/dependencies/scope guardrail as evidence
warrants, and make exactly one eligible task `next`. Do not advance to a hosted
task merely because the local proof succeeds.
