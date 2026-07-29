# SUP-FUNCTIONS-001 — curriculum draft-theory-section creation slice

Status: **in progress**. This is the seventh bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added `public.curriculum_create_draft_theory_section`, a server-only
  `SECURITY DEFINER` facade granted only to `service_role`.
- Requires a live, unlocked editor/admin profile through
  `private.assert_active_staff_actor` before idempotency replay or hierarchy
  access. A held or demoted staff actor cannot recover an earlier replay.
- Validates the exact draft input object
  `{ title, bodyMarkdown, estimatedMinutes }`; server-owned parent, ID,
  position, status, version, actor, and timestamp fields cannot be supplied by
  a caller.
- Resolves the chapter's module, locks that module, then re-reads and locks the
  chapter in canonical `module -> chapter` order. A changed hierarchy retries;
  a missing or archived module/chapter rejects new work. Draft and published
  ancestors are both allowed.
- Uses the locked chapter row as the sibling-scope mutex, appends after every
  theory-section status, guards integer position exhaustion, and inserts only
  trusted parent/input/actor values. The lifecycle trigger supplies draft
  status, null publication time, and row version one.
- Stores and replays only the safe envelope `201`,
  `/api/v1/admin/theory-sections/:id`, and `{ "id": "..." }`. A same-hash
  replay succeeds even after later ancestor archival and never writes another
  audit event.
- Appends one sanitized `theory_section_created` audit event with only the safe
  status transition `none -> draft`.

## Deliberately not implemented

- Exercise, quiz, or other curriculum creation; authored updates, complete-list
  reorders, publication, archiving, cloning, replacement, or operations
  facades.
- Fastify routes, direct client grants, generated types, browser behavior, or
  a generic type-switched authoring RPC.
- A two-session contention proof for root, module, and chapter sibling scopes.
  It remains required before an HTTP mutation uses this family.
- SMTP, MFA, Python/WASM jobs, hosted Supabase, Chrome, Vercel, or secrets.

## Files

- `supabase/migrations/20260729010700_add_curriculum_draft_theory_section_facade.sql`
- `supabase/tests/functions_test.sql`

## Verification

On 2026-07-29, the protected local function verifier passed after fresh reset
before and after every suite:

    npm run supabase:verify-functions:local

It reviewed 20 forward migrations, all predecessor pgTAP suites, and the
26-assertion server-only-function suite. The function-suite test digest was:

    968820f45abedfe05941a4cacd1db30e4d77d85c522566ebf88dc0a3ae24e225

The regression proof covers owner and runtime ACLs, editor/admin creation under
draft and published ancestors, learner and held-staff denial, exact input
rejection, missing-parent rejection, same-hash replay, different-hash conflict,
replay after later chapter/module archival, no replay audit duplicate, lifecycle
defaults, actor attribution, and sequential positions that include an archived
sibling. No browser, HTTP route, hosted Supabase, SMTP, MFA, Vercel, or secret
value was used.

The Docker Compose foundation gate also passed: formatting, lint and dependency
boundaries, TypeScript checks, the production build, and 184 unit tests.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is the separate
assessment-owned `assessment_create_draft_exercise` facade for scalar exercises
only. It must use the same active-staff/idempotency/hierarchy-lock/safe-audit
discipline, create the public exercise and private scalar definition atomically,
and preserve initial row/definition version one. It must explicitly exclude
`python_code`, whose definition and execution ownership remains SUP-WASM-001;
it must not add HTTP behavior or a generic cross-context authoring RPC.
