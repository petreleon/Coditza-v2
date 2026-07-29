# SUP-FUNCTIONS-001 — scalar draft-exercise creation slice

Status: **in progress**. This is the eighth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added `public.assessment_create_draft_exercise`, a server-only
  `SECURITY DEFINER` facade granted only to `service_role`.
- Requires a live, unlocked editor/admin profile through
  `private.assert_active_staff_actor` before idempotency replay, body
  validation, or hierarchy access. A held or demoted staff actor cannot recover
  an earlier replay.
- Accepts only the exact flat create body
  `{ title, promptMarkdown, exerciseType, points, isRequired, options,
  answerSpec, feedbackCorrectMarkdown?, feedbackIncorrectMarkdown? }`.
  It rejects server-owned fields, wrapper definitions, incomplete scalar
  definitions, and every non-scalar exercise type. In particular,
  `python_code` is rejected before any exercise, option, key, audit, or
  idempotency state is written.
- Resolves the chapter's module, locks that module, then re-reads and locks the
  chapter in canonical `module -> chapter` order. A changed hierarchy retries;
  a missing or archived module/chapter rejects new work. Draft and published
  ancestors are both allowed.
- Uses the locked chapter as the exercise sibling-scope mutex, appends after
  every exercise status, guards integer position exhaustion, and leaves the new
  public root at draft, null publication time, `row_version = 1`, and
  `definition_version = 1`.
- Creates the complete scalar definition atomically under the existing
  transaction-local assessment-tree marker. It creates choices in client order,
  remaps client references to stored option UUIDs, sorts multiple-choice IDs
  canonically, normalizes short-text answers, and stores feedback only in the
  private answer key. It deliberately does not call the draft-replacement helper
  because that helper advances root versions.
- Stores and replays only the safe envelope `201`,
  `/api/v1/admin/exercises/:id`, and `{ "id": "..." }`. A same-hash
  replay succeeds after later chapter/module archival and never creates another
  audit event.
- Appends one sanitized `exercise_created` audit event with only the safe
  status transition `none -> draft`.

## Deliberately not implemented

- Draft-quiz creation, authored updates, complete-list reorders, publication,
  archiving, cloning, replacement, or operations facades.
- Python exercise definitions, grading jobs, test artifacts, or execution:
  those remain exclusively owned by SUP-WASM-001.
- Fastify routes, direct client grants, generated types, browser behavior,
  SMTP, MFA, hosted Supabase, Vercel, Chrome, or secrets.
- A real two-session contention regression. The shared canonical lock contract
  is documented, but this proof remains required before an HTTP mutation uses
  the authoring family.

## Files

- `supabase/migrations/20260729010800_add_assessment_draft_exercise_facade.sql`
- `supabase/tests/functions_test.sql`

## Verification

On 2026-07-29, the protected local function verifier passed after fresh reset
before and after every suite:

    npm run supabase:verify-functions:local

It reviewed 21 forward migrations, all predecessor pgTAP suites, and the
28-assertion server-only-function suite. The function-suite test digest was:

    c424e5b5c57cabbfa82f6d7e6243c54ddfdb6ecf1921967f2fd426da152b19f9

The regression proof covers owner/runtime ACLs, editor/admin creation for
single-choice, multiple-choice, and short-text exercises; private stored key
material; initial versions; archived-sibling placement; exact-input, learner,
held-staff, incomplete-definition, missing-parent, Python, and foreign-option
denial; same-hash replay/different-hash conflict; replay after later parent
archives; no replay audit duplicate; and no failed partial state.

The Docker Compose foundation gate also passed formatting, lint and dependency
boundaries, TypeScript checks, production build, and 184 unit tests. No browser,
HTTP route, hosted Supabase, SMTP, MFA, Vercel, or secret value was used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is the separate
assessment-owned `assessment_create_draft_quiz` facade. It must establish its
exact server-owned input and complete question/option/key-tree contract before
DML, preserve active-staff-before-replay, safe replay/audit, and canonical
`module -> chapter` locking, and remain separate from generic content RPCs,
Python/WASM work, and HTTP behavior.
