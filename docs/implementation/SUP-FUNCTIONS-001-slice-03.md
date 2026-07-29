# SUP-FUNCTIONS-001 — learner assessment-history facade slice

Status: **in progress**. This is the third bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added four service-role-only, server-only learner history facades:
  own exercise-attempt list/detail and own quiz-attempt list/detail.
- Kept history owner-scoped from the first lookup and reloads the active actor
  before every read. A held learner, foreign attempt ID, or browser runtime role
  cannot read another learner's data.
- Made exercise history return the learner's stored answer and only the feedback
  branch selected by immutable stored correctness. It never projects an answer
  specification, correct option, accepted answer, current lifecycle state, or
  authoring metadata.
- Made quiz lists definition-free and answer-free. Quiz detail returns retained
  public questions/options and saved answers while an attempt is in progress;
  it omits all grading fields until stored terminal status.
- Made terminal quiz detail begin from every retained question and left join the
  learner's answers. An omitted question therefore returns null submitted
  answer, false correctness, zero points, and only the selected incorrect
  feedback branch.
- Does not require current publication for history reads. Published and archived
  definition trees are immutable and retained by the existing assessment
  guards, so archived owner history remains available.
- Fails closed if a stored attempt version ever differs from its retained
  immutable definition, rather than labelling a changed definition as historic
  data.
- Added typed keyset boundaries and 1–100 limits for both lists. Exercise order
  is `(submitted_at DESC, id DESC)`; quiz order is
  `(coalesce(submitted_at, started_at) DESC, id DESC)`.
- Added history-specific indexes for unfiltered exercise history and quiz-filter
  history.
- Replaced `progress_list_own_modules` in a forward migration to repair its
  next-cursor calculation: the cursor is now derived inside the page CTE scope.
  A two-page regression test covers the repaired contract.

## Deliberately not implemented

- Fastify routes, signed HMAC cursor envelopes, generated database types, or
  direct-client RPC grants.
- Authoring/lifecycle operations, assessment replacement/clone, expiration
  worker, operations/admin facades, and true two-session race proof.
- Python/WASM grading jobs or any private execution-plane behavior.
- Hosted Supabase, SMTP, MFA, Chrome, Vercel, or secret configuration.

## Files

- `supabase/migrations/20260729010300_add_assessment_history_facades.sql`
- `supabase/tests/functions_test.sql`

## Verification

On 2026-07-29, the protected local function verifier passed after fresh reset
before and after every suite:

    npm run supabase:verify-functions:local

It reviewed 16 forward migrations, all predecessor pgTAP suites, and the
18-assertion server-only-function suite. The function-suite test digest was:

    5ebbe6d60f943c76815cba4d979a431fbe0c9667f8923e4d4d371b656723d503

The regression fixture proves archive-safe history, cross-user concealment,
held-actor denial, exact cursor tie-breaking, active quiz non-disclosure, and
terminal omitted-question behavior. No browser, HTTP route, hosted Supabase,
SMTP, MFA, Vercel, or secret value was used.

The Docker Compose foundation gate also passed: formatting, lint and dependency
boundaries, TypeScript checks, the production build, and 184 unit tests.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next database slice is curriculum and
assessment authoring/lifecycle work, preceded by an explicit review of the
missing in-database staff/admin predicates. It must not turn the current
server-only functions into public client RPCs.
