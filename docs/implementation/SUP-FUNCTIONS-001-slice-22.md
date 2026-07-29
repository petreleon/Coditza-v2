# SUP-FUNCTIONS-001 — exercise publication slice

Status: **in progress**. This is the twenty-second bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added public.assessment_publish_exercise, a server-only SECURITY DEFINER
  facade with an empty fixed search path and an execute grant only for
  service_role.
- The facade requires a server-generated request UUID, non-null actor and
  exercise identifiers, and a positive expected row version. It locks and
  rechecks the active editor/admin profile before it reads hierarchy, the
  exercise root, its definition, or progress-source state.
- It discovers the current exercise-to-chapter-to-module path, locks module
  then chapter then exercise in canonical order, and rechecks both hierarchy
  edges. Draft or published non-archived ancestors are valid; archived
  ancestors are rejected.
- A valid current draft with complete scalar content, a unique non-negative
  sibling position, and a valid existing definition/key tree transitions to
  published. The facade delegates option and answer-key completeness to
  private.validate_exercise_definition; Python-code exercises remain
  fail-closed until SUP-WASM-001 owns their verified private definition.
- The one authored-row update changes only status, first published_at, and
  updated_by; the established triggers advance row_version and updated_at
  exactly once.
- An archived target is rejected. An already published target returns its
  current safe id/version result before expected-version comparison, so a retry
  carrying the original version is a state-based idempotent success with no
  second update, audit, or progress work.
- When both locked ancestors are published, the facade finds the distinct union
  of chapter-progress, theory-completion, exercise-attempt, and quiz-attempt
  users for that chapter. It locks all affected progress keys in UUID order,
  then uses the existing owner-only recalculator for each snapshot. An optional
  exercise still causes recalculation while preserving its denominator
  semantics. Under a draft ancestor it intentionally skips every progress
  read/write.
- A real transition appends exactly one exercise_published event with the
  closed status delta and no reason code. It does not create an idempotency
  record or expose authored content in audit data.

## Deliberately not implemented

- Module/chapter/quiz publication, archive/reorder/clone, hierarchy edits, a
  generic lifecycle facade, or any replay-key protocol.
- Fastify routes, direct client RPCs, browser behavior, Python/WASM grading,
  SMTP, MFA, hosted Supabase, Vercel, or secret values.
- A true two-session contention regression. The defined lock order is
  implemented and protected by deterministic state tests; independent
  contention proof remains required before an HTTP mutation depends on this
  authoring family.

## Files

- supabase/migrations/20260729012200_add_assessment_published_exercise_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 35 forward migrations, all predecessor pgTAP suites, and the
56-assertion server-only-function suite. The function-suite test digest was:

    6870720831430f44a95325867726b3e615c50db487e48cc58067c2f6b25f42f1

The verified reset fingerprint was:

    1a5ca281053ec72e8534d6c15b0a698558bfba6a8251a9d801668b013ebf2041

The proof covers exact ownership, fixed path, one overload, default-deny ACL,
direct authenticated denial, malformed-root and definition readiness denial,
active staff/argument/stale/archived-target/archived-ancestor denial, current
draft-to-published success, published retry with the original version, exact
audit/no-audit behavior, no idempotency record, and all four valid ancestor
combinations.

For effective published parents, the proof covers all four affected-user
sources: an existing completed snapshot, archived-history-only attempts, live
completion/attempt source rows without a snapshot, and a snapshot-only row.
It verifies the new required-exercise denominator, exact recalculated
percentages, preservation of first_completed_at, clearing of completed_at when
the chapter reopens, source/history immutability, optional-exercise
recalculation without a denominator change, and no repeated progress write on
retry. It also seeds sentinel snapshots under every ineffective parent
combination and proves they remain byte-for-byte unchanged.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint, dependency boundaries, TypeScript checks, the
production build, and 184 unit tests. No hosted system or secret value was
used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
assessment_publish_quiz. It must lock module then chapter then quiz, validate
the existing private quiz definition/key tree without recreating that validator,
publish only a complete current draft, and preserve published retry semantics
before version comparison. It must recalculate affected progress only under
effective published ancestors, preserve optional-quiz denominator behavior, and
must not add a generic lifecycle facade, replay records, Fastify/direct-client
behavior, or external configuration.
