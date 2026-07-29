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
staff-authorization primitive cluster, root draft-module creation cluster,
draft-chapter creation cluster, draft-theory-section creation cluster, scalar
draft-exercise and complete draft-quiz creation clusters, scalar
draft-exercise and draft-quiz PATCH clusters, protected assessment authoring
reads, draft-module/chapter/theory-section PATCH clusters,
published-module/chapter/theory-section correction clusters, and
theory-section, exercise, and quiz publication, documented in
[slice 01](../docs/implementation/SUP-FUNCTIONS-001-slice-01.md),
[slice 02](../docs/implementation/SUP-FUNCTIONS-001-slice-02.md), and
[slice 03](../docs/implementation/SUP-FUNCTIONS-001-slice-03.md), and
[slice 04](../docs/implementation/SUP-FUNCTIONS-001-slice-04.md),
[slice 05](../docs/implementation/SUP-FUNCTIONS-001-slice-05.md),
[slice 06](../docs/implementation/SUP-FUNCTIONS-001-slice-06.md),
[slice 07](../docs/implementation/SUP-FUNCTIONS-001-slice-07.md), and
[slice 08](../docs/implementation/SUP-FUNCTIONS-001-slice-08.md),
[slice 09](../docs/implementation/SUP-FUNCTIONS-001-slice-09.md),
[slice 10](../docs/implementation/SUP-FUNCTIONS-001-slice-10.md), and
[slice 11](../docs/implementation/SUP-FUNCTIONS-001-slice-11.md), and
[slice 12](../docs/implementation/SUP-FUNCTIONS-001-slice-12.md), and
[slice 13](../docs/implementation/SUP-FUNCTIONS-001-slice-13.md), and
[slice 14](../docs/implementation/SUP-FUNCTIONS-001-slice-14.md), and
[slice 15](../docs/implementation/SUP-FUNCTIONS-001-slice-15.md), and
[slice 16](../docs/implementation/SUP-FUNCTIONS-001-slice-16.md), and
[slice 17](../docs/implementation/SUP-FUNCTIONS-001-slice-17.md), and
[slice 18](../docs/implementation/SUP-FUNCTIONS-001-slice-18.md), and
[slice 19](../docs/implementation/SUP-FUNCTIONS-001-slice-19.md), and
[slice 20](../docs/implementation/SUP-FUNCTIONS-001-slice-20.md), and
[slice 21](../docs/implementation/SUP-FUNCTIONS-001-slice-21.md), and
[slice 22](../docs/implementation/SUP-FUNCTIONS-001-slice-22.md), and
[slice 23](../docs/implementation/SUP-FUNCTIONS-001-slice-23.md). Continue
from those bounded baselines with the curriculum-owned
curriculum_publish_chapter facade. It must require a server-generated request
UUID, non-null actor and chapter identifiers, and a positive expected row
version. It must recheck the live active editor/admin actor before hierarchy,
chapter-root, descendant readiness, or progress-source access; discover the
current chapter-to-module path; lock module then chapter in canonical order;
and recheck the hierarchy edge. The module may be draft or published but must
not be archived.

The target is a closed lifecycle transition: an archived target is rejected;
an already published target returns only its current id and rowVersion before
expected-version comparison, with no UPDATE, audit, descendant scan, or
progress recalculation; and only a current draft with the expected version may
publish. Validate the locked root slug through private.is_valid_slug, title
(trimmed 1..160), summary Markdown (nonblank, at most 5,000 characters),
non-negative unique sibling position, estimated_minutes (1..1,440), and null
published_at. While the chapter remains locked, require at least one published
theory section, one published exercise, and one published quiz in that exact
chapter. The chapter lock is the outer serialization point for leaf lifecycle
and definition writers; do not invent a generic descendant-lock protocol or
revalidate published leaf definitions here.

The sole real write changes only status, first published_at, and updated_by;
the lifecycle triggers advance row_version/updated_at once. It then appends
exactly one chapter_published audit event with changed_fields ['status'], the
closed draft-to-published status delta, and no reason code. When the locked
module is published, it must recalculate every affected learner from the
distinct UUID-sorted union of chapter_progress, theory completions, exercise
attempts, and quiz attempts for that chapter, acquiring all progress locks last
before calling the existing recalculator. Under a draft module it must perform
no progress source/snapshot reads or writes. It must preserve every child
status, version, definition/tree, hierarchy, created field, and learner
completion/attempt/history. It must not add input/reason envelopes,
idempotency records, hierarchy/reorder/replacement, generic lifecycle,
Fastify/HTTP/direct-client/Python/SMTP/MFA/Vercel behavior, or WASM work.

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
