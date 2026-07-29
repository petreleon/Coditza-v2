# Next task

The sole next implementation task is:

**SUP-FUNCTIONS-001 — Implement workflow primitives (in progress).**

Prerequisites verified: all currently owned primitive, profile, curriculum,
assessment, learning-record, idempotency, and hardened audit tables are local,
protected, and covered by deterministic reset proof. ARC-SEC-003 completed the
closed audit contract. SUP-SMTP-LOCAL-001 and SUP-MFA-001 remain independently
ineligible; neither blocks this task.

This task builds the named server-only transaction facades over those existing
tables. Its completed slices are the structured idempotency/assessment learner
mutation cluster, learner progress cluster, own assessment-history cluster,
staff-authorization primitive cluster, and root draft-module creation cluster
documented in [slice 01](../docs/implementation/SUP-FUNCTIONS-001-slice-01.md),
[slice 02](../docs/implementation/SUP-FUNCTIONS-001-slice-02.md), and
[slice 03](../docs/implementation/SUP-FUNCTIONS-001-slice-03.md), and
[slice 04](../docs/implementation/SUP-FUNCTIONS-001-slice-04.md), and
[slice 05](../docs/implementation/SUP-FUNCTIONS-001-slice-05.md). Continue
from those bounded baselines with `curriculum_create_draft_chapter`: it must
call the active-staff assertion before parent/content access, lock and recheck a
non-archived parent module before calculating the child sibling position,
validate an exact chapter input, and preserve idempotency/safe replay/audit. It
must not widen into a generic type-switched authoring RPC. This is not
permission to add HTTP routes, direct client policies, hosted configuration,
Python/WASM jobs, or identity/bootstrap workflows.

## Read first

1. README.md, TASKS.md, STATUS.md, and 00-control/00-scope-and-non-goals.md.
2. 00-control/01-fixed-decisions.md and 00-control/02-open-decisions.md.
3. 02-architecture/04-data-flow-and-security.md and
   02-architecture/06-modular-hexagonal-architecture.md.
4. 03-supabase/02-core-content-schema.md,
   03-supabase/03-assessment-schema.md,
   03-supabase/04-learning-progress-schema.md,
   03-supabase/05-functions-constraints-indexes.md,
   03-supabase/06-auth-profiles-and-roles.md, and
   03-supabase/07-rls-policy-matrix.md.
5. docs/implementation/SUP-DATA-001.md, SUP-DATA-002.md,
   SUP-DATA-003.md, and ARC-SEC-003.md.
6. 08-execution/00-roadmap.md, 08-execution/01-dependency-map.md, and
   08-execution/03-handoff-protocol.md.

## Permitted scope

1. Add only forward local migrations for the named server-only transactional
   facades and tightly scoped private collaborators specified by the functions
   plan. Preserve one context owner and one coordinator per workflow; reject a
   generic public type-switched lifecycle function.
2. Implement the listed curriculum, assessment, progress, operations, and safe
   learner workflow functions except the three Python grading job functions.
   Reserve, claim, and finalize Python grading remain exclusively owned by
   SUP-WASM-001.
3. Use exact server-verified actor arguments, reload and lock current
   profile/role/ownership inside PostgreSQL, fixed safe search paths, owner
   ownership, default-deny grants, and direct user denial. No function may
   claim to derive a user from the secret-key session.
4. Keep actor authorization, lock order, lifecycle validation, idempotency,
   audit append, source/progress update, and returned safe result in one
   transaction. Audit calls must use the closed reason-code and safe-delta
   contract; raw content/Auth/answer material never enters the audit row.
5. Add task-owned pgTAP, normalization golden vectors, deterministic race or
   rollback proof, and a fixed local verifier action. Preserve every preceding
   protected regression suite and schema diff/lint behavior.

## Required proof

1. Every public facade has one documented context owner, grants only the
   intended server role, and has no direct client/runtime bypass. Private
   helpers remain non-executable by runtime roles.
2. Each function validates exact input shapes, actor role/ownership, current
   lifecycle/publication state, cross-resource references, and its documented
   lock/idempotency order. Replays return only the stored safe result.
3. SQL and TypeScript normalization share golden vectors for accents, case,
   whitespace, empty-after-trim, and non-ASCII distinctions.
4. Representative concurrent, rollback, idempotency, audit, source/progress,
   attempt-finalization, and definition-history cases pass without orphaned
   state or duplicate effects.
5. Protected fresh resets, all regression suites, function tests, public/private
   diff, lint, loopback checks, launcher override refusal, and the foundation
   gate pass. The report contains only non-secret evidence and names exactly
   one next task.

## Explicitly forbidden

- Do not add Fastify routes, public client RPCs, direct user policies, generated
  database types, seed users/content, audit list endpoints, or a generic
  cross-context function.
- Do not implement Python grading definitions, job reservation/claim/finalize,
  controller selection, private test artifacts, or Python execution evidence.
- Do not implement admin bootstrap, role-control, identity security-hold,
  SMTP, TOTP/MFA, Chrome, hosted Supabase, Vercel, deployment, billing, CLI
  authentication, secrets, or remote URLs.
- Do not modify applied migrations, weaken RLS/default denial, or add a
  free-text audit reason or raw audit delta.

If a function requires a product/API decision, a user factor, a provider
capability, or an action owned by a later task, stop at that boundary and record
it rather than broadening SUP-FUNCTIONS-001.
