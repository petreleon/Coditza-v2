# SUP-FUNCTIONS-001 — published-theory-section correction slice

Status: **in progress**. This is the twentieth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added public.curriculum_correct_published_theory_section, a server-only
  SECURITY DEFINER facade with an empty fixed search path and an execute grant
  only for service_role.
- The facade requires a server-generated request UUID, non-null actor and
  theory-section identifiers, a positive expected row version, and exactly the
  content_correction reason code. It locks and rechecks the current active
  editor/admin profile before it reads hierarchy or section state.
- It accepts only a nonempty partial JSON object with optional title,
  bodyMarkdown, and estimatedMinutes fields. SQL NULL, non-object input, JSON
  nulls, unknown/server-owned fields including chapterId and position, invalid
  scalar types, untrimmed titles, blank or overlong Markdown, and out-of-range
  or non-integral minutes are rejected.
- It discovers the current section-to-chapter-to-module path, locks module then
  chapter then theory section in canonical order, and rechecks both hierarchy
  edges. Draft or published non-archived ancestors are valid; an archived
  ancestor, missing/reparented hierarchy, draft/archived target, and stale
  version are rejected.
- A current-version semantic no-op returns only id and rowVersion without an
  UPDATE, timestamp, attribution, version, or audit change; a stale no-op is
  rejected. A real change updates only title, body_markdown,
  estimated_minutes, and updated_by, so the existing lifecycle trigger
  advances row_version exactly once.
- Each real correction appends exactly one theory_section_corrected event with
  the required content_correction reason and only the approved redacted content
  delta. The facade has no replay/idempotency behavior and never writes
  authored values to audit data.

## Deliberately not implemented

- Published module/chapter corrections beyond their separate bounded slices,
  draft updates, hierarchy/position changes, assessment changes, lifecycle
  operations, reorder, clone, publish/archive, or a generic curriculum
  facade.
- Fastify routes, direct client RPCs, browser behavior, Python/WASM grading,
  SMTP, MFA, hosted Supabase, Vercel, or secret values.
- A true two-session contention regression. The narrow module-to-chapter-to-
  theory locking protocol is implemented; independent concurrent proof remains
  required before an HTTP mutation depends on this authoring family.

## Files

- supabase/migrations/20260729012000_add_curriculum_published_theory_section_correction_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 33 forward migrations, all predecessor pgTAP suites, and the
52-assertion server-only-function suite. The function-suite test digest was:

    e8f2ae68bed7531dad3896ebad7f8d90292174433d5c51caeff4278210e8111e

The verified reset fingerprint was:

    79d2c3e4612fd78274dd7d641dc2f45e6d943cd238840d91abbca13c6afb35dd

The proof covers exact ownership, fixed path, one overload, default-deny ACL,
direct authenticated denial, full and partial editor/admin corrections,
draft-ancestor acceptance, learner/held/missing actor denial, exact
reason/input/version validation, draft/archived/missing target and
archived-parent denial, stale real and stale no-op denial, current-version
no-op timestamp/attribution preservation, safe response shape, one version
advance per real correction, root/parent-field preservation, redacted audit
shape/count/absence, no idempotency record, and cleared write markers.

The test also records a deterministic before/after fingerprint of the target
section's theory completions and parent chapter-progress snapshots, plus
section sibling and assessment-root state. It stores only digests of complete
rows, so authored content and learner metadata are covered without exposure;
the fingerprint is unchanged after the correction.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint, dependency boundaries, TypeScript checks, the
production build, and 184 unit tests. No hosted system or secret value was
used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
curriculum_publish_theory_section. It must lock module then chapter then theory
section in canonical order; publish only a valid current draft; make an already
published target idempotently return its current safe result before an
expected-version comparison; and append one redacted lifecycle audit only for
the real transition. It must preserve the authored theory relationship and
recalculate affected learner progress only when both ancestors are published.
It must not add hierarchy, generic lifecycle, replay-record, Fastify/direct-
client, or external configuration behavior.
