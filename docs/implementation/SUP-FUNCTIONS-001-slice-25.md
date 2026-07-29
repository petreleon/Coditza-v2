# SUP-FUNCTIONS-001 — module publication slice

Status: **in progress**. This is the twenty-fifth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added public.curriculum_publish_module, a server-only SECURITY DEFINER
  facade with an empty fixed search path and an execute grant only for
  service_role.
- The facade requires a server-generated request UUID, non-null actor and
  module identifiers, and a positive expected row version. It locks and
  rechecks the live active editor/admin profile before it reads module state,
  chapter readiness, lifecycle, or learner-progress data.
- It locks only the target module root. An archived target is denied; an
  already-published target returns only its current id and rowVersion before
  stale-version, readiness, audit, or progress work; only a current draft
  with the expected version can transition.
- The locked draft root is revalidated for slug, trimmed title, Markdown
  description, non-negative unique root position including archived roots,
  and a null publication timestamp. It then requires at least one already
  published direct chapter. It deliberately does not republish, repair, or
  revalidate that chapter's children.
- The sole authored-root write changes status, first published_at, and
  updated_by. Established lifecycle triggers advance row_version and
  updated_at exactly once.
- After the module becomes published, the facade derives distinct
  chapter/user pairs for every published direct chapter from current
  chapter-progress rows, theory completions, exercise attempts, and quiz
  attempts. It does not filter historical source rows by current leaf status.
  It acquires every pair's advisory progress lock in deterministic
  user/chapter order before recalculating any snapshot.
- A real transition appends exactly one module_published audit event with the
  closed status delta and no reason code. The facade creates no idempotency
  record and exposes no direct-client RPC.

## Deliberately not implemented

- Module/archive tree transitions, reorder, clone, hierarchy edits, generic
  lifecycle facades, or replay-key protocols.
- Fastify routes, browser behavior, Python/WASM grading, SMTP, MFA, hosted
  Supabase, Vercel, or secret values.
- A true two-session contention regression. The module root and progress-lock
  order are implemented and protected by deterministic state proof; separate
  contention evidence remains required before an HTTP mutation uses this
  authoring family.

## Files

- supabase/migrations/20260729012500_add_curriculum_published_module_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 38 forward migrations, all predecessor pgTAP suites, and the
62-assertion server-only-function suite. The function-suite test digest was:

    722b4438559f0155b8a8240c240b0b927609ff93048527705bb3f33841e670c4

The verified reset fingerprint was:

    3f2b9638305fab49ee2c83c0e655ce809a00f81ca3d65cce69b86b8655f10ec7

The proof covers exact ownership, fixed path, one overload, default-deny ACL,
direct authenticated denial, active-staff/argument/stale/archived denial,
deferred duplicate-root-position detection, and denial when no direct
published chapter exists. It proves real draft-to-published success and
state-based retry with no second lifecycle write, audit event, or replay
record.

The effective-module fixture covers every candidate arm: a snapshot-only
learner, source-only theory/exercise/quiz learners, a historical completion on
an archived theory section, and the same learner affecting two published
direct chapters. It proves only published direct chapters receive progress
work: direct draft and archived chapter sentinels remain untouched, including
an archived-chapter progress snapshot. Descendant roots and trees remain
unchanged, all source history remains unchanged, a draft-only child cannot
satisfy module readiness, and an exact full progress snapshot after success
proves retry performs no second recalculation or audit.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint, dependency boundaries, TypeScript checks, the
production build, and 184 unit tests. No hosted system or secret value was
used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is module-tree
archive. Its contract must preserve retained learner history, archive a locked
complete descendant tree atomically, recalculate affected effective learner
progress exactly once, emit closed audits, and remain a named
curriculum-only workflow without generic lifecycle, replay, Fastify,
direct-client, or external-configuration behavior.
