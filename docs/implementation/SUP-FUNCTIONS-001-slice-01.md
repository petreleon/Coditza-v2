# SUP-FUNCTIONS-001 — assessment learner-facade slice

Status: **in progress**. This is a bounded, committed first slice of
SUP-FUNCTIONS-001, not completion of the full task.

## Scope completed in this slice

- Added a forward-only structured idempotency acquisition helper that returns
  replay status, original HTTP status, Location, and safe response body.
- Replaced the body-only private helper internally while retaining its existing
  signature for predecessor workflows.
- Replaced generic replay-body keyword filtering with exact safe schemas for
  scalar exercise submission and quiz start.
- Stored the complete original safe exercise and quiz-start response so a
  replay never reconstructs output from changed current content.
- Added named SECURITY DEFINER public facades for scalar exercise submission,
  quiz start, quiz answer save/removal, and quiz submission.
- Granted execution only to service_role; anon, authenticated, authenticator,
  PUBLIC, and postgres have no explicit execution grant. No runtime role
  receives direct table or private-helper access.
- Required a verified actor argument and non-null server request ID on each
  facade. A profile in security hold is rejected before an idempotency replay.
- Records an expired stale quiz attempt as an auditable terminal transition
  before reporting an attempt limit or starting a replacement attempt.
- Records quiz-answer audit events only when the stored answer actually
  changes; an unchanged transport retry is not a second protected transition.
- Added selected-feedback and terminal-quiz safe projections. They never expose
  answer specs, accepted answers, correct option IDs, or unused feedback.
- Added the "nfkc_ascii_ws_ascii_lower_v1" pure assessment TypeScript
  normalizer and matching SQL/TypeScript golden vectors.

## Deliberately not implemented

- Fastify routes, direct client RPC grants, generated types, or scheduled
  invokers.
- Identity/profile/role/bootstrap/security-hold facades.
- Python exercise definitions, queue jobs, reservation, claim, finalization,
  controller, or execution.
- Curriculum and assessment authoring/lifecycle/reorder/clone/replace
  facades; progress reads/reconciliation; audit projection; maintenance
  facades; and the task-owned true two-session race harness.

Those remain the continuation of SUP-FUNCTIONS-001 or their separately owned
tasks. The public entrypoints added here are intentionally limited to the
assessment learner mutation cluster.

## Files

- supabase/migrations/20260729010000_add_idempotency_replay_envelopes.sql
- supabase/migrations/20260729010100_add_assessment_learner_facades.sql
- supabase/tests/functions_test.sql
- scripts/supabase/local-stack.mjs
- apps/api/src/modules/assessment/domain/normalize-short-text.ts
- apps/api/src/modules/assessment/domain/normalization-golden-vectors.ts

## Verification

On 2026-07-29, the protected local verifier passed after fresh reset before and
after all suites:

    npm run supabase:verify-functions:local

It reviewed 14 forward migrations, all six predecessor pgTAP suites, the new
9-assertion function suite, public/private schema diff and lint, local
loopback bindings, and Auth health. The final function-suite digest was:

    7b9164d71d7259d121eb796de29f41b8149b50540c69d9848b5366e98ba2efa0

The Node unit/type/lint checks passed with 184 unit tests, including the shared
normalization vectors. The rebuilt local Docker checks profile also passed
formatting, lint, types, all 184 unit tests, dependency-boundary checks, and
the API build. No browser, hosted Supabase, SMTP, MFA, Vercel, or secret value
was used.

## Continuation

Keep SUP-FUNCTIONS-001 active. Its next slice must add the remaining named
facades in ownership order, preserve the same service-role-only grant model,
and add real two-session concurrency proof before any HTTP mutation task uses
these functions.
