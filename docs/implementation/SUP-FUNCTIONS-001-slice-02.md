# SUP-FUNCTIONS-001 — learner-progress facade slice

Status: **in progress**. This is the second bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added server-only, service-role-only public facades for theory completion,
  paginated own-module summaries, and own-module progress detail.
- Preserved the owner-only theory-completion primitive: repeated completion
  returns the original timestamp, removal is idempotent, and a chapter that
  has ever completed cannot have a theory completion removed.
- Added safe audit events only for actual theory set/removal transitions; a
  non-null server request ID is required and a null completion flag is
  rejected.
- Built progress reads from current published modules and chapters, never from
  a learner snapshot alone. New learners therefore receive visible modules and
  zero completion values instead of an empty result.
- Added a set-based source fallback for a missing chapter snapshot. It derives
  the current percentages and completion state without inventing irreversible
  completion timestamps, which remain JSON null until explicit reconciliation.
- Emits the fixed, data-free PostgreSQL log signal
  `coditza_progress_snapshot_missing` once per affected read; it contains no
  user, content, answer, or Auth value.
- Uses a typed module keyset cursor `(position, moduleId)`, requires both
  cursor fields together, and enforces the API-wide 1–100 limit range.

## Deliberately not implemented

- Admin progress reconciliation. It requires the separately owned live
  database admin-role predicate and role-control workflow.
- Fastify routes, HMAC cursor encoding, metrics ingestion, direct-client RPC
  grants, generated types, or hosted configuration.
- Assessment attempt-history facades, curriculum/assessment authoring,
  lifecycle/reorder operations, scheduled maintenance, and true two-session
  concurrency proof.

## Files

- supabase/migrations/20260729010200_add_progress_learner_facades.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local verifier passed after fresh reset before
and after every suite:

    npm run supabase:verify-functions:local

It reviewed 15 forward migrations, all predecessor pgTAP suites, and the
12-assertion server-only-function suite. The function-suite test digest was:

    e28e5b791d779dfcd990ded25a3953af37dd9d0e30fee4a4e6e19009cd3ff1b4

The Docker Compose foundation gate also passed: formatting, lint and dependency
boundaries, TypeScript checks, the production build, and 184 unit tests.

The regression fixture proves the three distinct read states: a completed
learner with a persisted snapshot, a new learner with no history, and a learner
with completed sources but no snapshot. No browser, HTTP route, hosted
Supabase, SMTP, MFA, Vercel, or secret value was used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next learner slice should add safe own
assessment-history facades, including archived-definition history and terminal
quiz projections, before authoring/lifecycle work. It must preserve the same
service-role-only grant model and add real two-session concurrency evidence
before a mutation route consumes these functions.
