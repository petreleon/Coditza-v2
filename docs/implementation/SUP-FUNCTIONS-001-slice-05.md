# SUP-FUNCTIONS-001 — curriculum draft-module creation slice

Status: **in progress**. This is the fifth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added `public.curriculum_create_draft_module`, a server-only
  `SECURITY DEFINER` facade granted only to `service_role`.
- Added `private.lock_module_root_scope()`, a fixed transaction advisory lock
  for the root module position set. The future root-module reorder facade must
  reuse this exact helper before it reads or changes that set.
- Requires a live, unlocked editor/admin profile through
  `private.assert_active_staff_actor` before idempotency replay or content
  access. A held or demoted staff actor cannot recover an earlier replay.
- Validates the exact draft input object
  `{ slug, title, descriptionMarkdown }`; server-owned ID, position, status,
  version, actor, and timestamp fields cannot be supplied by a caller.
- Serializes append placement across every root module status, explicitly guards
  integer position exhaustion, and inserts only the draft fields plus trusted
  actor attribution. The lifecycle trigger supplies draft status, null
  publication time, and version one.
- Stores and replays only the safe envelope `201`,
  `/api/v1/admin/modules/:id`, and `{ "id": "..." }`. No authored Markdown
  or other content becomes idempotency state.
- Appends one sanitized `module_created` audit event with only the safe status
  transition `none -> draft`.

## Deliberately not implemented

- Chapter or other curriculum creation; authored updates, complete-list
  reorders, publication, archiving, cloning, replacement, or operations
  facades.
- Fastify routes, direct client grants, generated types, browser behavior, or
  a generic type-switched curriculum RPC.
- A two-session contention proof for the new root lock. It remains required
  before an HTTP mutation uses this family.
- SMTP, MFA, Python/WASM jobs, hosted Supabase, Chrome, Vercel, or secrets.

## Files

- `supabase/migrations/20260729010500_add_curriculum_draft_module_facade.sql`
- `supabase/tests/functions_test.sql`

## Verification

On 2026-07-29, the protected local function verifier passed after fresh reset
before and after every suite:

    npm run supabase:verify-functions:local

It reviewed 18 forward migrations, all predecessor pgTAP suites, and the
22-assertion server-only-function suite. The function-suite test digest was:

    37752ae1458841ed6f41390026760c53ccc0567817680b6ae17164bd11d0995e

The regression proof covers owner and runtime ACLs, editor/admin creation,
learner and held-staff denial, exact input rejection, same-hash replay,
different-hash conflict, no replay audit duplicate, lifecycle defaults, actor
attribution, and serialized sequential root positions. No browser, HTTP route,
hosted Supabase, SMTP, MFA, Vercel, or secret value was used.

The Docker Compose foundation gate also passed: formatting, lint and dependency
boundaries, TypeScript checks, the production build, and 184 unit tests.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
`curriculum_create_draft_chapter`: a server-only, staff-asserted child creation
facade that locks and rechecks a non-archived parent module before determining
its sibling position, with exact input validation, idempotency/safe replay, and
sanitized audit evidence.
