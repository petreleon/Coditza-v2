# Next task

The sole next implementation task is:

**SUP-FUNCTIONS-001 — Implement workflow primitives (in progress).**

Prerequisites verified: all currently owned primitive, profile, curriculum,
assessment, learning-record, idempotency, and hardened audit tables are local,
protected, and covered by deterministic reset proof. ARC-SEC-003 completed the
closed audit contract. SUP-SMTP-LOCAL-001 and SUP-MFA-001 remain independently
ineligible; neither blocks this task.

This task builds named server-only transaction facades over those existing
tables. Twenty-five bounded slices are now complete, including the module
publication boundary documented in
[slice 25](../docs/implementation/SUP-FUNCTIONS-001-slice-25.md). Continue
from that baseline with the curriculum-owned
curriculum_archive_module facade only.

Its exact public signature is
public.curriculum_archive_module(actor_user_id uuid, module_id uuid,
expected_row_version integer, reason_code text, request_id uuid), returning
one response_status/response_body row. It must be SECURITY DEFINER, owned by
coditza_owner, use an empty fixed search path, revoke every default/runtime
grant, and grant execute only to service_role. It accepts no input envelope,
idempotency key, generic resource type, or client-supplied actor derivation.

Call private.assert_server_request_id first. Require a non-null actor and
module ID, a positive expected row version, and exactly the closed
content_archive reason code. Before any module, descendant, learner-history,
or progress read, call private.assert_active_staff_actor to lock and recheck
the current editor/admin profile. Then lock the target module root first.

An already archived target is a state-based retry: return only its current
safe id and rowVersion before stale-version comparison, descendant scan,
progress work, or audit. Any draft or published non-archived target must
match expected_row_version. A missing root, malformed request, invalid reason,
inactive/held/nonstaff actor, or stale non-archived root fails without a write.

The module archive is one all-or-nothing tree transaction. After locking the
module, discover and lock its direct chapters in UUID order, then lock theory
sections, exercises, and quizzes below those chapters in UUID order. Do not
touch question, option, answer-key, attempt, completion, or profile rows.
Every currently draft or published row in this module tree becomes archived;
already archived rows remain byte-for-byte unchanged. Each newly archived
content root changes only status and updated_by; existing lifecycle triggers
advance its row_version and updated_at once. Do not erase published_at,
created fields, hierarchy, positions, definitions, keys, attempts, or
completion history.

Only when the target module was published immediately before the transition,
derive the distinct affected (user_id, chapter_id) pairs from every direct
chapter that is currently published, using chapter_progress, theory
completions, exercise attempts, and quiz attempts. Historical source rows
remain candidates regardless of current leaf status. Draft and already
archived chapters are excluded. After all content locks are held, lock every
progress pair in deterministic user/chapter order, archive the tree, and only
then call private.recalculate_chapter_progress for every locked pair in the
same order. This makes denominators reflect the archived module while
preserving source history. When the target module was draft, perform no
progress-source or snapshot work. Do not batch, defer, or make network calls.

Append one closed audit event for every row that actually transitions:
module_archived, chapter_archived, theory_section_archived, exercise_archived,
or quiz_archived. Each event uses its actual entity type/ID, changed_fields
['status'], the exact prior-status-to-archived delta, the required
content_archive reason, the verified user actor, and the same request UUID.
No audit is written for already archived rows or a retry. The response may
return only safe IDs/counts and the root rowVersion; it must never return
authored content, answers, private keys, raw audit data, or learner history.

The pgTAP proof must cover exact ownership/path/ACL/one-overload/direct-user
denial; argument/actor/reason/missing/stale denial; both draft and published
tree archive; archived retry with a snapshot proving no repeat progress writes;
complete descendant status/version preservation; unchanged already archived
descendants; retained attempts/completions/definitions; all four affected-user
arms including snapshot-only and archived-leaf history; exclusion of draft and
archived chapters; exact per-row audit count/deltas; no idempotency record; and
a deferred failure/rollback proof. Preserve all preceding protected suites.
Do not implement chapter/leaf/assessment archive, reorder, clone,
replacement, generic lifecycle, Fastify/HTTP/direct-client/Python/SMTP/MFA/
Vercel behavior, WASM work, secrets, or hosted configuration in this slice.

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
