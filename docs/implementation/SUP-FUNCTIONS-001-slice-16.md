# SUP-FUNCTIONS-001 — draft-chapter PATCH slice

Status: **in progress**. This is the sixteenth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added public.curriculum_update_draft_chapter, a server-only SECURITY DEFINER
  facade with an empty fixed search path and an execute grant only for
  service_role.
- The facade requires a server-generated request UUID, non-null actor and
  chapter identifiers, and a positive expected row version. It locks and
  rechecks the current active editor/admin profile before content access.
- It accepts only a nonempty partial JSON object with optional slug, title,
  summaryMarkdown, and estimatedMinutes fields. SQL NULL, non-object input,
  unknown/server-owned fields, JSON nulls, invalid scalar types, untrimmed
  titles, invalid slugs, invalid Markdown, and out-of-range minutes are
  rejected.
- It discovers the current parent, locks module then chapter in canonical
  order, and constrains the locked chapter reread and final UPDATE to that
  module. This protects against concurrent reparenting while serializing with
  module archival. A draft or published parent is valid; an archived parent is
  not.
- Missing, non-draft, and stale chapters are rejected. A no-op returns only id
  and rowVersion without UPDATE or audit. A real change updates only the four
  allowed chapter scalars and updated_by, so the existing lifecycle trigger
  advances row_version exactly once.
- A real change appends exactly one chapter_updated event using only the
  approved redacted content delta. The facade has no replay/idempotency
  behavior and never writes raw authored values to audit data.

## Deliberately not implemented

- Theory-section or assessment updates, hierarchy/position changes, lifecycle
  operations, published corrections, reorder, clone, publish/archive, or a
  generic curriculum facade.
- Fastify routes, direct client RPCs, browser behavior, Python/WASM grading,
  SMTP, MFA, hosted Supabase, Vercel, or secret values.
- A true two-session reparent/archive contention regression. The canonical
  lock/recheck protocol is implemented; independent concurrent proof remains
  required before an HTTP mutation depends on this authoring family.

## Files

- supabase/migrations/20260729011600_add_curriculum_draft_chapter_update_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 29 forward migrations, all predecessor pgTAP suites, and the
44-assertion server-only-function suite. The function-suite test digest was:

    f20cdaf700b8cc3c72998e2575c8b8d658434c18cc87057991e5b79c45e3169f

The verified reset fingerprint was:

    5585a966c18a8f9a9964dac297857adce89a0512b036c546d44cc1e91cf66342

The proof covers exact ownership, fixed path, one overload, default-deny ACL,
direct authenticated denial, editor/admin writes, learner/held/missing actor
denial, exact scalar input validation, duplicate scoped-slug rollback, stale
real and stale no-op denial, published/archived chapter denial, archived-parent
denial, published-parent success, response shape, no-op behavior, preserved
module/hierarchy/sibling/theory/exercise state, redacted audit shape/count,
audit absence for denied/no-op calls, no idempotency record, and cleared write
markers.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint, dependency boundaries, TypeScript checks, the
production build, and 184 unit tests. No hosted system or secret value was
used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
curriculum_update_draft_theory_section. It must take canonical module then
chapter then theory-section locks, recheck both hierarchy edges, accept only
title, bodyMarkdown, and estimatedMinutes, preserve position/lifecycle and
assessment descendants, use expected-version/no-op semantics, and emit only a
redacted audit fact. It must not add replay, hierarchy moves, lifecycle work,
or HTTP/direct-client behavior.
