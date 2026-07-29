# SUP-FUNCTIONS-001 — complete draft-quiz creation slice

Status: **in progress**. This is the ninth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added `public.assessment_create_draft_quiz`, a server-only
  `SECURITY DEFINER` facade granted only to `service_role`.
- Requires a live, unlocked editor/admin profile through
  `private.assert_active_staff_actor` before idempotency replay, body
  validation, or hierarchy access. A held or demoted staff actor cannot recover
  an earlier replay.
- Accepts only the exact flat create body
  `{ slug, title, instructionsMarkdown, passingPercent, maxAttempts,
  timeLimitSeconds, isRequired, questions }`. The nullable attempt/deadline
  fields must still be supplied explicitly. Server-owned fields, a wrapper
  definition, incomplete question trees, and unknown fields are rejected.
- Requires a complete independently publishable tree before root DML: one to
  one hundred scalar questions, non-null answer specs, two to twenty options
  for choice questions, and no options for short-text questions. The existing
  private replacement helper remains intentionally more permissive for a later
  draft-update workflow.
- Resolves the chapter's module, locks that module, then re-reads and locks the
  chapter in canonical `module -> chapter` order. A changed hierarchy retries;
  a missing or archived module/chapter rejects new work. Draft and published
  ancestors are both allowed.
- Uses the locked chapter as the quiz sibling-scope mutex, appends after every
  quiz status, guards integer position exhaustion, and leaves the new public
  root at draft, null publication time, `row_version = 1`, and
  `definition_version = 1`.
- Creates every question, option, and private answer key atomically under the
  existing transaction-local assessment-tree marker. It preserves array
  positions, remaps client references to stored IDs, sorts multiple-choice IDs
  canonically, normalizes short-text answers, and assigns the verified staff
  actor to each private key. It deliberately does not call
  `private.replace_draft_quiz_definition`, because that helper advances root
  versions.
- Stores and replays only the safe envelope `201`,
  `/api/v1/admin/quizzes/:id`, and `{ "id": "..." }`. A same-hash
  replay succeeds after later chapter/module archival and never creates another
  audit event.
- Appends one sanitized `quiz_created` audit event with only the safe status
  transition `none -> draft`.

## Deliberately not implemented

- Draft assessment updates, complete-list reorders, publication, archiving,
  cloning, replacement, or operations facades.
- Python/WASM definitions or grading jobs; quizzes contain only the three
  scalar question types and all Python execution work remains owned by
  SUP-WASM-001.
- Fastify routes, direct client grants, generated types, browser behavior,
  SMTP, MFA, hosted Supabase, Vercel, Chrome, or secrets.
- A real two-session contention regression. The shared canonical lock contract
  is documented, but this proof remains required before an HTTP mutation uses
  the authoring family.

## Files

- `supabase/migrations/20260729010900_add_assessment_draft_quiz_facade.sql`
- `supabase/tests/functions_test.sql`

## Verification

On 2026-07-29, the protected local function verifier passed after fresh reset
before and after every suite:

    npm run supabase:verify-functions:local

It reviewed 22 forward migrations, all predecessor pgTAP suites, and the
30-assertion server-only-function suite. The function-suite test digest was:

    8d8a8187e5b817bd449debf91e802ad72b2ebe7dae0121c865dcfcafdc23c948

The regression proof covers owner/runtime ACLs, editor/admin complete trees
with single-choice, multiple-choice, and short-text questions; private stored
key material; initial versions; archived-sibling placement; exact-input,
learner, held-staff, empty/incomplete tree, one-option, cross-question, and
missing-parent denial; same-hash replay/different-hash conflict; replay after
later parent archives; no replay audit duplicate; and no failed partial state.

The Docker Compose foundation gate also passed formatting, lint and dependency
boundaries, TypeScript checks, production build, and 184 unit tests. No browser,
HTTP route, hosted Supabase, SMTP, MFA, Vercel, or secret value was used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
`assessment_update_draft_exercise`: a separate staff-only facade with an
expected root-row-version, exact scalar root/definition input, canonical
ancestor/root locking, and one marker-gated complete-tree replacement. It must
advance root and definition versions once when it changes the definition,
preserve safe return/audit behavior, and remain separate from generic content
RPCs, Python/WASM work, and HTTP behavior.
