# SUP-FUNCTIONS-001 — draft-theory-section PATCH slice

Status: **in progress**. This is the seventeenth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added public.curriculum_update_draft_theory_section, a server-only SECURITY
  DEFINER facade with an empty fixed search path and an execute grant only for
  service_role.
- The facade requires a server-generated request UUID, non-null actor and
  theory-section identifiers, and a positive expected row version. It locks and
  rechecks the current active editor/admin profile before it reads authored
  state.
- It accepts only a nonempty partial JSON object with optional title,
  bodyMarkdown, and estimatedMinutes fields. SQL NULL, non-object input,
  unknown/server-owned fields, JSON nulls, invalid scalar types, untrimmed
  titles, blank or overlong Markdown, non-integer minutes, and minutes outside
  1 through 1,440 are rejected.
- It discovers the current chapter and module, locks module then chapter then
  theory section in canonical order, and constrains the locked chapter and
  theory rereads plus the final update to their expected parent IDs. This
  protects the write from concurrent reparenting while serializing with
  ancestor archival. Draft or published non-archived ancestors are valid;
  archived ancestors are not.
- Missing, non-draft, and stale theory sections are rejected. A no-op returns
  only id and rowVersion without UPDATE or audit. A real change updates only
  the three allowed theory-section scalars and updated_by, so the existing
  lifecycle trigger advances row_version exactly once.
- A real change appends exactly one theory_section_updated event using only the
  approved redacted content delta. The facade has no replay/idempotency
  behavior and never writes authored values to audit data.

## Deliberately not implemented

- Published corrections, hierarchy/position changes, assessment changes,
  lifecycle operations, reorder, clone, publish/archive, or a generic
  curriculum facade.
- Fastify routes, direct client RPCs, browser behavior, Python/WASM grading,
  SMTP, MFA, hosted Supabase, Vercel, or secret values.
- A true two-session reparent/archive contention regression. The canonical
  lock/recheck protocol is implemented; independent concurrent proof remains
  required before an HTTP mutation depends on this authoring family.

## Files

- supabase/migrations/20260729011700_add_curriculum_draft_theory_section_update_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 30 forward migrations, all predecessor pgTAP suites, and the
46-assertion server-only-function suite. The function-suite test digest was:

    5130040d4072b57a9abf898165c023f037801524b96f1fafeea17219a705e90e

The verified reset fingerprint was:

    16d82fdd9458aee9ad03696a9b96d8454f89754b0fd12d47fb82610a041dc462

The proof covers exact ownership, fixed path, one overload, default-deny ACL,
direct authenticated denial, editor/admin writes, learner/held/missing actor
denial, exact scalar input validation including fractional and JSON-null minute
rejection, stale real and stale no-op denial, published/archived target denial,
archived-ancestor denial, published-ancestor success, response shape, no-op
behavior, preserved module/chapter/theory sibling/exercise state, redacted audit
shape/count, audit absence for denied/no-op calls, no idempotency record, and
cleared write markers.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint, dependency boundaries, TypeScript checks, the
production build, and 184 unit tests. No hosted system or secret value was
used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
curriculum_correct_published_module. It must lock only the published module,
require a live editor/admin actor, a positive expected row version, a
server-generated request UUID, and the exact content_correction reason code.
Its nonempty JSON object may contain only title and descriptionMarkdown, using
the established scalar validators. A current-version semantic no-op must return
only id and rowVersion without a write or audit; a stale no-op remains denied.
A real change must preserve slug, position, lifecycle, identity/timestamp
fields, children, and learner progress; emit module_corrected with the
required content_correction reason and a redacted content fact; and remain
service-role only. It must not add a generic correction facade, replay,
hierarchy/lifecycle work, Fastify/direct-client behavior, or any external
configuration.
