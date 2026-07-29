# SUP-FUNCTIONS-001 — published-module correction slice

Status: **in progress**. This is the eighteenth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added public.curriculum_correct_published_module, a server-only SECURITY
  DEFINER facade with an empty fixed search path and an execute grant only for
  service_role.
- The facade requires a server-generated request UUID, non-null actor and
  module identifiers, a positive expected row version, and exactly the approved
  content_correction reason code. It locks and rechecks the current active
  editor/admin profile before it reads module state.
- It accepts only a nonempty partial JSON object with optional title and
  descriptionMarkdown fields. SQL NULL, non-object input, JSON nulls,
  unknown/server-owned fields including slug, invalid scalar types, untrimmed
  titles, and blank or overlong Markdown are rejected.
- It locks exactly the target module row. Missing, draft, archived, and stale
  modules are rejected. It intentionally takes no sibling, descendant,
  assessment, or progress lock because it cannot change position, hierarchy,
  lifecycle, definitions, or learner state.
- A current-version semantic no-op returns only id and rowVersion without an
  UPDATE, timestamp, attribution, version, or audit change; a stale no-op is
  rejected. A real change updates only title, description_markdown, and
  updated_by, so the existing lifecycle trigger advances row_version exactly
  once.
- Each real correction appends exactly one module_corrected event with the
  required content_correction reason and only the approved redacted content
  delta. The facade has no replay/idempotency behavior and never writes
  authored values to audit data.

## Deliberately not implemented

- Published chapter/theory corrections, draft updates, hierarchy/position
  changes, assessment changes, lifecycle operations, reorder, clone,
  publish/archive, or a generic curriculum facade.
- Fastify routes, direct client RPCs, browser behavior, Python/WASM grading,
  SMTP, MFA, hosted Supabase, Vercel, or secret values.
- A true two-session contention regression. The narrow root-row locking
  protocol is implemented; independent concurrent proof remains required
  before an HTTP mutation depends on this authoring family.

## Files

- supabase/migrations/20260729011800_add_curriculum_published_module_correction_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 31 forward migrations, all predecessor pgTAP suites, and the
48-assertion server-only-function suite. The function-suite test digest was:

    32b2da68d7aac6138d377093bb1d8a518684862a2c02803eebe82518c9a7325a

The verified reset fingerprint was:

    b9215b37d03f20652fc5a717990dd4d093c6cec809f22776592b6e4840accba0

The proof covers exact ownership, fixed path, one overload, default-deny ACL,
direct authenticated denial, full and partial editor/admin corrections,
learner/held/missing actor denial, exact reason/input/version validation,
draft/archived/missing target denial, stale real and stale no-op denial,
current-version no-op timestamp/attribution preservation, safe response shape,
one version advance per real correction, lifecycle/root-field preservation,
redacted audit shape/count/absence, no idempotency record, and cleared write
markers.

The test also records a redacted, deterministic before/after fingerprint of
every descendant definition and learning record rooted at the corrected module:
chapters, theory sections, assessments and their option/key trees, theory
completions, exercise/quiz attempts and answer metadata, and chapter-progress
snapshots. The fingerprint excludes authored Markdown and answer material and
is unchanged after the correction.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint, dependency boundaries, TypeScript checks, the
production build, and 184 unit tests. No hosted system or secret value was
used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
curriculum_correct_published_chapter. It must preserve the same
content_correction/no-op/redacted-audit semantics while locking a module then
its chapter in canonical order, rechecking that edge, and allowing a draft or
published non-archived parent. It must not add hierarchy, lifecycle, replay,
Fastify/direct-client, or external configuration behavior.
