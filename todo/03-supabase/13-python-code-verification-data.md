# Python verification data and transactional workflow

## Private definition data

Add one `private.python_exercise_definitions` row for each `python_code`
exercise. It contains the frozen entry-point contract, starter files, safe
public tests, private closed declarative case plan (never executable hidden
Python source), allowed package IDs, resource profile,
verifier/fixture versions, and the runtime-manifest/test-fixture SHA-256
digests. JSON shapes are closed and bounded by the product contract.

Choice options and scalar answer keys are forbidden for `python_code`. The
definition row is draft-replaceable only through the locked complete-definition
authoring function and becomes immutable with its exercise. Learner, `anon`,
and `authenticated` roles receive no access. Safe catalog RPCs project only
starter files, public descriptions/fixtures, limits, and non-secret runtime
metadata; hidden tests and their count/digest never enter learner projections.

## Durable grading queue

Add `private.python_grading_jobs` with:

- UUID job ID, actor user ID, exercise ID, frozen definition version;
- UUID idempotency key plus canonicalization version/request hash;
- canonical source package and submission digest;
- expected runtime-manifest, harness, and test-fixture digests;
- status `queued`, `leased`, `retryable`, `completed`, or `dead`;
- lease owner/token/expiry, retry count, next-eligible time, and safe last
  infrastructure-error code;
- nullable final exercise-attempt ID and timestamps.

Uniqueness covers `(user_id, operation, idempotency_key)`. Check constraints
enforce status/lease/result consistency. Queue reads use a bounded eligible
index and `FOR UPDATE SKIP LOCKED`. Learner source is encrypted by the selected
Supabase storage boundary, never copied to audit/idempotency/log rows, and
deleted according to the attempt/privacy retention rule after durable
finalization.

Extend immutable exercise-attempt evidence for `python_code` with the
allowlisted learner verdict and exact submission, definition, fixture, harness,
runtime-manifest, and canonical-result digests. Store safe bounded output
excerpts separately from private runner evidence. Do not store hidden test
source/expected values/tracebacks in an attempt or public schema.

## Server-only functions

Implement three `assessment`-owned server-only RPC facades:

1. `reserve_python_grading_job` performs idempotency step zero, validates the
   canonical source package, locks module -> chapter -> exercise, rechecks
   effective publication and frozen verifier metadata, and creates/replays one
   job. It returns no private test bundle to Fastify.
2. `claim_python_grading_jobs` is callable only by the dedicated grader
   controller. It selects a bounded eligible batch, assigns unguessable leases,
   and returns exactly the source/test/limit data required by the sandbox.
3. `finalize_python_grading_job` verifies job status, lease token, retry state,
   and all echoed digests. For a valid learner verdict it derives zero/full
   points, inserts one immutable attempt, recalculates progress, stores the
   idempotent safe result, scrubs transient private material, and marks complete
   in one transaction. Infrastructure outcomes reschedule/dead-letter without
   an attempt or progress change.

The finalizer rejects a client-shaped result, arbitrary points, an unknown
verdict, stale/wrong lease, extra digest, or any digest mismatch. Repeated
finalization returns the same stored result. A dead job is an operational
failure and may be requeued only by an audited operator runbook; it never
becomes an incorrect learner attempt.

## SUP-WASM-001 — Implement Python verification persistence

Prerequisites: SUP-DATA-002, SUP-DATA-003, SUP-FUNCTIONS-001, PRD-WASM-001, and
ARC-WASM-001.

- [ ] Add the private definition, job, attempt-evidence, constraints, grants,
      bounded indexes, and privacy/retention migrations.
- [ ] Extend authoring/publish validation so only a complete digest-pinned
      Python definition can publish.
- [ ] Implement the three server-only facades with canonical lock order,
      leases, idempotent finalization, progress atomicity, and safe projections.
- [ ] Prove `anon`, `authenticated`, ordinary server adapters, and learners
      cannot read hidden fixtures or claim/finalize jobs.
- [ ] Prove concurrent reserve/claim/finalize, controller crash, lease expiry,
      retry ceiling, archive race, replay, and account deletion outcomes.
- [ ] Prove infrastructure failure never awards zero points or changes
      progress, while every learner verdict finalizes once.
- [ ] Keep Supabase Auth/TOTP tables, functions, and flows unchanged.
