# SUP-FUNCTIONS-001 — theory-section publication slice

Status: **in progress**. This is the twenty-first bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added public.curriculum_publish_theory_section, a server-only SECURITY
  DEFINER facade with an empty fixed search path and an execute grant only for
  service_role.
- The facade requires a server-generated request UUID, non-null actor and
  theory-section identifiers, and a positive expected row version. It locks
  and rechecks the active editor/admin profile before it reads hierarchy,
  lifecycle, authored content, or progress-source state.
- It discovers the current theory-section-to-chapter-to-module path, locks
  module then chapter then theory section in canonical order, and rechecks both
  hierarchy edges. Draft or published non-archived ancestors are valid;
  archived ancestors are rejected.
- A valid current draft with complete scalar content and a unique non-negative
  sibling position transitions to published. The one authored-row update
  changes only status, first published_at, and updated_by; the established
  triggers advance row_version and updated_at exactly once.
- An archived target is rejected. An already published target returns its
  current safe id/version result before expected-version comparison, so a retry
  carrying the original version is a state-based idempotent success with no
  second update, audit, or progress work.
- When both locked ancestors are published, the facade finds the distinct union
  of chapter-progress, theory-completion, exercise-attempt, and quiz-attempt
  users for that chapter. It locks all affected progress keys in UUID order,
  then uses the existing owner-only recalculator for each snapshot. Under a
  draft ancestor it intentionally skips every progress read/write.
- A real transition appends exactly one theory_section_published event with the
  closed status delta and no reason code. It does not create an idempotency
  record or expose authored content in audit data.

## Deliberately not implemented

- Module/chapter publication, assessment publication, archive/reorder/clone,
  hierarchy edits, a generic lifecycle facade, or any replay-key protocol.
- Fastify routes, direct client RPCs, browser behavior, Python/WASM grading,
  SMTP, MFA, hosted Supabase, Vercel, or secret values.
- A true two-session contention regression. The defined lock order is
  implemented and protected by deterministic state tests; independent
  contention proof remains required before an HTTP mutation depends on this
  authoring family.

## Files

- supabase/migrations/20260729012100_add_curriculum_published_theory_section_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 34 forward migrations, all predecessor pgTAP suites, and the
54-assertion server-only-function suite. The function-suite test digest was:

    061859c868bb591b3ebef5fdc78a5dceac159af41749bfa8e339f019db3c5c93

The verified reset fingerprint was:

    fcb87597a904d0607922042a40dd714d01de7a2fa232770c118f8d08e2b71c49

The proof covers exact ownership, fixed path, one overload, default-deny ACL,
direct authenticated denial, malformed-position readiness denial, active
staff/argument/stale/archived-target/archived-ancestor denial, current
draft-to-published success, published retry with the original version, exact
audit/no-audit behavior, no idempotency record, and all four valid ancestor
combinations.

For effective published parents, the proof covers all four affected-user
sources: an existing completed snapshot, archived-history-only attempts, live
completion/attempt source rows without a snapshot, and a snapshot-only row.
It verifies the new theory denominator, exact recalculated percentages,
preservation of first_completed_at, clearing of completed_at when the chapter
reopens, source/history immutability, and no repeated progress write on retry.
It also seeds sentinel snapshots under every ineffective parent combination
and proves they remain byte-for-byte unchanged.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint, dependency boundaries, TypeScript checks, the
production build, and 184 unit tests. No hosted system or secret value was
used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
assessment_publish_exercise. It must lock module then chapter then exercise,
validate the existing private exercise definition/key tree without recreating
that validator, publish only a complete current draft, and preserve published
retry semantics before version comparison. It must recalculate affected
progress only under effective published ancestors, fail closed for Python-code
exercises pending SUP-WASM-001, and must not add a generic lifecycle facade,
replay records, Fastify/direct-client behavior, or external configuration.
