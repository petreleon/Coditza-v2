# SUP-FUNCTIONS-001 — draft-module PATCH slice

Status: **in progress**. This is the fifteenth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added public.curriculum_update_draft_module, a server-only SECURITY DEFINER
  facade with an empty fixed search path and an execute grant only for
  service_role.
- The facade first requires a server-generated request UUID, non-null actor and
  module identifiers, and a positive expected row version. It then reloads and
  locks the current active editor/admin profile before it can disclose module
  state.
- It accepts only a nonempty partial JSON object whose optional fields are
  slug, title, and descriptionMarkdown. SQL NULL, non-object input, unknown
  fields, JSON null fields, untrimmed titles, invalid slugs, and invalid
  Markdown are rejected. Supplied values use the same scalar limits as
  draft-module creation.
- It locks exactly the target module. Missing, published, archived, and stale
  roots are rejected. Because this PATCH cannot change hierarchy or position,
  it intentionally does not acquire a root sibling-scope advisory lock.
- A no-op returns only id and rowVersion without an UPDATE or audit event.
  A real change updates only the module scalar fields and updated_by; the
  existing lifecycle trigger advances row_version exactly once.
- A real change appends exactly one module_updated audit event using only the
  approved redacted content delta. It has no replay/idempotency behavior and
  never places authored values in audit data.

## Deliberately not implemented

- Chapter, theory-section, assessment, tree, position, reparenting, lifecycle,
  publish/archive, published-correction, reorder, or clone operations.
- Fastify routes, direct client RPCs, browser behavior, Python/WASM grading,
  SMTP, MFA, hosted Supabase, Vercel, or secret values.
- A true two-session contention regression. The narrow root-row lock and final
  expected-version predicate are present; the independent concurrency proof
  remains required before an HTTP mutation depends on this family.

## Files

- supabase/migrations/20260729011500_add_curriculum_draft_module_update_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 28 forward migrations, all predecessor pgTAP suites, and the
42-assertion server-only-function suite. The function-suite test digest was:

    d4b7d3d32a2841ccd7179559506f9a7beef972a9efd355be3cd6bb63cdcfcb59

The verified reset fingerprint was:

    07c0c4032a59e32dfc6a0e1312582e195c8b83fa5b231dce67be96ea82bb3ef1

The proof covers exact ownership, fixed path, one overload, default-deny ACL,
direct authenticated denial, active editor/admin success, learner/missing/held
actor denial, exact input validation, duplicate-slug rollback, stale real and
stale no-op denial, published/archived denial at their current versions,
response shape, one version increment per real write, child preservation,
redacted audit shape and count, audit absence for denied/no-op calls, no
idempotency record, and cleared write markers.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint, dependency boundaries, TypeScript checks, the
production build, and 184 unit tests. No hosted system or secret value was
used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
curriculum_update_draft_chapter. It must use the same server-only PATCH
envelope but lock module then chapter in canonical order, recheck their live
relationship, reject archived parents and non-draft/stale chapters, and validate
only slug, title, summaryMarkdown, and estimatedMinutes. It must not absorb
theory updates, parent/position moves, lifecycle work, replay/idempotency, or
HTTP/direct-client behavior.
