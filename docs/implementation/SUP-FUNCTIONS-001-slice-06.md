# SUP-FUNCTIONS-001 — curriculum draft-chapter creation slice

Status: **in progress**. This is the sixth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added `public.curriculum_create_draft_chapter`, a server-only
  `SECURITY DEFINER` facade granted only to `service_role`.
- Requires a live, unlocked editor/admin profile through
  `private.assert_active_staff_actor` before idempotency replay or parent/content
  access. A held or demoted staff actor cannot recover an earlier replay.
- Validates the exact draft input object
  `{ slug, title, summaryMarkdown, estimatedMinutes }`; server-owned parent,
  ID, position, status, version, actor, and timestamp fields cannot be supplied
  by a caller.
- Acquires the parent module row with `FOR UPDATE` after the idempotency step and
  rejects new children under an archived parent. That row is the documented
  sibling-scope mutex for future chapter reorders and module archival. New
  children may be created under draft or published modules.
- Serializes append placement across every chapter status, explicitly guards
  integer position exhaustion, and inserts only trusted parent/input/actor
  values. The lifecycle trigger supplies draft status, null publication time,
  and version one.
- Stores and replays only the safe envelope `201`,
  `/api/v1/admin/chapters/:id`, and `{ "id": "..." }`. A same-hash replay
  succeeds even if the parent was archived later; it occurs before the current
  parent-state check and never writes another audit event.
- Appends one sanitized `chapter_created` audit event with only the safe status
  transition `none -> draft`.

## Deliberately not implemented

- Theory, exercise, quiz, or other curriculum creation; authored updates,
  complete-list reorders, publication, archiving, cloning, replacement, or
  operations facades.
- Fastify routes, direct client grants, generated types, browser behavior, or
  a generic type-switched curriculum RPC.
- A two-session contention proof for the root-module advisory lock and the
  module-row chapter scope. It remains required before an HTTP mutation uses
  this family.
- SMTP, MFA, Python/WASM jobs, hosted Supabase, Chrome, Vercel, or secrets.

## Files

- `supabase/migrations/20260729010600_add_curriculum_draft_chapter_facade.sql`
- `supabase/tests/functions_test.sql`

## Verification

On 2026-07-29, the protected local function verifier passed after fresh reset
before and after every suite:

    npm run supabase:verify-functions:local

It reviewed 19 forward migrations, all predecessor pgTAP suites, and the
24-assertion server-only-function suite. The function-suite test digest was:

    fccabe8dc1c69fb8669df01acfcd4316e0f58dacb279a91492360f5982aff125

The regression proof covers owner and runtime ACLs, editor/admin creation under
draft and published parents, learner and held-staff denial, exact input
rejection, missing-parent rejection, same-hash replay, different-hash conflict,
replay after a later parent archive, no replay audit duplicate, lifecycle
defaults, actor attribution, and sequential positions that include an archived
sibling. No browser, HTTP route, hosted Supabase, SMTP, MFA, Vercel, or secret
value was used.

The Docker Compose foundation gate also passed: formatting, lint and dependency
boundaries, TypeScript checks, the production build, and 184 unit tests.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
`curriculum_create_draft_theory_section`: a server-only, staff-asserted child
creation facade with exact `{ title, bodyMarkdown, estimatedMinutes }` input.
It must preserve idempotency/safe replay/audit, lock the hierarchy in canonical
`module -> chapter` order, recheck that both ancestors remain non-archived, and
lock the chapter sibling scope before selecting a theory-section position. It
must not widen into a generic type-switched authoring RPC or add HTTP behavior.
