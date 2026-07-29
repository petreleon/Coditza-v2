# SUP-FUNCTIONS-001 — chapter publication slice

Status: **in progress**. This is the twenty-fourth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added public.curriculum_publish_chapter, a server-only SECURITY DEFINER
  facade with an empty fixed search path and an execute grant only for
  service_role.
- The facade requires a server-generated request UUID, non-null actor and
  chapter identifiers, and a positive expected row version. It locks and
  rechecks the active editor/admin profile before it reads hierarchy, chapter
  state, child readiness, or learner-progress sources.
- It discovers the chapter's module, locks module then chapter in canonical
  order, and rechecks the hierarchy edge. Draft and published modules are
  permitted; an archived module or archived chapter is rejected.
- A locked current draft must have valid scalar chapter state and at least one
  already-published direct theory section, exercise, and quiz. The chapter row
  is the outer serialization point for leaf lifecycle/definition writers, so
  this facade neither invents child locks nor revalidates immutable leaf trees.
- The sole authored-row transition changes only status, first published_at,
  and updated_by; established lifecycle triggers advance row_version and
  updated_at once. A published retry returns only the current {id,rowVersion}
  before stale-version, child, audit, or progress work.
- Under a published module, the facade reconciles the UUID-sorted union of
  chapter snapshots, theory completions, exercise attempts, and quiz attempts,
  acquiring all progress locks before recalculation. Historical archived and
  optional-child sources remain candidates while the established calculator
  preserves denominator semantics. Under a draft module it intentionally
  performs no progress-source or snapshot work.
- A real transition appends exactly one chapter_published event with the
  closed status delta and no reason code. It creates no idempotency record and
  exposes no direct-client RPC.

## Deliberately not implemented

- Module publication, archive/reorder/clone, hierarchy edits, a generic
  lifecycle facade, or a replay-key protocol.
- Fastify routes, browser behavior, Python/WASM grading, SMTP, MFA, hosted
  Supabase, Vercel, or secret values.
- A true two-session contention regression. The documented lock order is
  implemented and deterministic tests cover its state contract; independent
  contention proof remains required before an HTTP mutation depends on this
  authoring family.

## Files

- supabase/migrations/20260729012400_add_curriculum_published_chapter_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 37 forward migrations, all predecessor pgTAP suites, and the
60-assertion server-only-function suite. The function-suite test digest was:

    8fb4c8b0d0d515270a6c17844e3a38b94ef4351d597be04922a92ba6e9cf7656

The verified reset fingerprint was:

    924f1cbae8369091fb87eecdccc7d91cea817a40166ff27f6c1bb5941f293827

The proof covers exact ownership, fixed path, one overload, default-deny ACL,
direct authenticated denial, active-staff/argument/stale/archived denial,
deferred duplicate-position detection, and independent absence of each
published child category. It proves archive denial precedes published retry,
valid effective and draft-module transitions, retries without a second write,
and exact closed audit/no-idempotency behavior. It also proves that archived
siblings still block a duplicate chapter position and that published optional
exercise and quiz children satisfy chapter readiness.

For an effective module, the proof uses nine affected learners: a
snapshot-only learner, current theory/exercise/quiz sources, optional
assessment sources, and archived historical theory/exercise/quiz sources. It
proves all four source arms are included, source/history and descendant trees
remain unchanged, optional and archived content stays out of current
denominators, and retry does not rewrite progress. It separately proves that a
chapter published under a draft module leaves all progress state byte-for-byte
unchanged.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint, dependency boundaries, TypeScript checks, the
production build, and 184 unit tests. No hosted system or secret value was
used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
curriculum_publish_module. It must make learner visibility explicit at the
module boundary, validate the locked module and all required published chapter
readiness, preserve state-based retry, reconcile affected published-chapter
learners under the established lock order, and remain a named curriculum-only
facade without generic lifecycle, replay, Fastify, direct-client, or external
configuration work.
