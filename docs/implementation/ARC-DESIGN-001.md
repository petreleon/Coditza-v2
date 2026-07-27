# ARC-DESIGN-001 — Freeze module ownership and dependency graph

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: Implementation is authorized. This task changes only
architecture documentation in the local repository.
Prerequisites/gate checked: G0, PLAN-004, ARC-TREE-002, and ARC-TREE-001 are
complete; ARC-DESIGN-001 was the sole next task before this work began.
Decisions/defaults used:

- Coditza remains one deployable Fastify modular monolith backed by one
  Supabase/PostgreSQL database.
- The fixed business contexts are identity, curriculum, assessment, progress,
  and operations. Health and the database kernel are non-business platform
  concerns.
- The private grader-controller and disposable hardened Python/WASM sandbox are
  the sole justified process exception. They do not become public services or
  business-data owners.
- Cross-context application imports default to none. The only allowed read
  contracts are curriculum to assessment/progress and assessment to progress,
  all through the target public.ts contract.
- Cross-context writes use one named coordinator and one module-specific
  server-only RPC facade with private SQL collaborators, not foreign adapters.
- Generic public lifecycle RPCs and Fastify/request-bound raw clients are
  prohibited.
- The otherwise unnamed Python attempt-evidence relation is reserved as
  private.python_exercise_attempt_evidence; its columns, grants, retention,
  and migration remain exclusively owned by SUP-WASM-001.

## Scope

- Intended: freeze the ADR, exact ownership inventory, dependency/import
  matrix, composition-root graph, module-specific RPC map, isolated executable
  contract, and future negative-fixture strategy.
- Explicitly excluded: application source, package dependencies, schema or
  migrations, Docker, Supabase state, credentials, Chrome, Vercel, SMTP,
  sandbox launcher selection, and every external action.

## Changed

- docs/adr/0001-modular-monolith-and-ports-adapters.md: accepted architecture
  decision and rejected alternatives.
- docs/implementation/architecture-ownership-inventory.md: exact single-owner
  inventory for planned tables, protected data, server-only facades, routes,
  jobs, operators, and cross-context coordinators.
- docs/implementation/architecture-boundary-contract.md: public-contract
  allowlist, layer import matrix, narrow shared-kernel rules, composition
  graphs, one-off entrypoint isolation, generic-RPC conversion, and negative
  fixtures.
- docs/implementation/ARC-DESIGN-001.md: this task report.
- todo/02-architecture/06-modular-hexagonal-architecture.md,
  todo/TASKS.md, todo/STATUS.md, todo/NEXT.md, todo/README.md,
  todo/00-control/00-scope-and-non-goals.md, and
  todo/08-execution/00-roadmap.md: completion and next-task state.

## Verification

- Documentation architecture-inventory assertion script
  - Result: PASS
  - Non-secret evidence: every required planned primary/private artifact and
    module-prefixed facade is present; the contract includes all negative-rule
    IDs BND-001 through BND-010, three allowed application read edges across
    two named contract types, the raw-client prohibition, and the
    one-process/one-database statement.
- Manual ownership review against product, Supabase, API, and architecture
  plans
  - Result: PASS
  - Non-secret evidence: each planned table, RPC facade, route family, job, and
    one-off executable has exactly one listed owner; Supabase Auth remains
    provider-owned and no generic public lifecycle facade survives.
- Documentation-location check
  - Result: PASS
  - Non-secret evidence: the first ADR is a real document under docs/adr and
    the supporting architecture documents are real files under
    docs/implementation; no application or infrastructure directory was added.
- git diff --check
  - Result: PASS
  - Non-secret evidence: no whitespace error in the task change.

## External actions

NONE. No hosted state, browser configuration, credential, deployment, or
provider account was accessed or changed.

## Deviations/ADRs

- ADR 0001 accepts the modular-monolith/ports-and-adapters decision.
- The inventory makes the previously unnamed Python attempt-evidence relation
  explicit so a future database task cannot introduce an unowned physical
  relation. It does not define its data schema or authorize a migration.

## Risks/blockers

- ARC-BOUND-001 must select an enforcement tool only after FOUND-001 chooses
  the toolchain, then make every listed negative fixture demonstrably fail.
- ARC-WASM-001 and OPS-VERCEL-001 still exclusively own the hardened
  outer-sandbox launcher and public-Vercel/private-grader deployment topology.
- This task does not select a frontend or implement the direct Supabase Auth
  client contract; PRD-AUTH-001 owns that provider-neutral contract next.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer,
TOTP/QR/otpauth/factor/challenge material, or unsafe screenshot/log was
recorded.

## Next

PRD-AUTH-001 is the only unblocked next task. It may record the provider-neutral
mandatory-TOTP client contract after reviewing current official Supabase Auth
documentation, but may not implement a client, choose an SDK version, or make
an external change.
