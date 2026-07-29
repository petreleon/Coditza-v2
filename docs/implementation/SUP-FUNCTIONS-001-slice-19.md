# SUP-FUNCTIONS-001 — published-chapter correction slice

Status: **in progress**. This is the nineteenth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added public.curriculum_correct_published_chapter, a server-only SECURITY
  DEFINER facade with an empty fixed search path and an execute grant only for
  service_role.
- The facade requires a server-generated request UUID, non-null actor and
  chapter identifiers, a positive expected row version, and exactly the
  content_correction reason code. It locks and rechecks the current active
  editor/admin profile before it reads hierarchy or chapter state.
- It accepts only a nonempty partial JSON object with optional title,
  summaryMarkdown, and estimatedMinutes fields. SQL NULL, non-object input,
  JSON nulls, unknown/server-owned fields including slug and moduleId, invalid
  scalar types, untrimmed titles, blank or overlong Markdown, and out-of-range
  or non-integral minutes are rejected.
- It discovers the current parent, locks module then chapter in canonical
  order, and rechecks the chapter-to-module relationship under those locks.
  A draft or published non-archived parent is valid; an archived parent,
  missing/reparented hierarchy, draft/archived target, and stale version are
  rejected.
- A current-version semantic no-op returns only id and rowVersion without an
  UPDATE, timestamp, attribution, version, or audit change; a stale no-op is
  rejected. A real change updates only title, summary_markdown,
  estimated_minutes, and updated_by, so the existing lifecycle trigger
  advances row_version exactly once.
- Each real correction appends exactly one chapter_corrected event with the
  required content_correction reason and only the approved redacted content
  delta. The facade has no replay/idempotency behavior and never writes
  authored values to audit data.

## Deliberately not implemented

- Published module/theory corrections beyond their separate bounded slices,
  draft updates, hierarchy/position changes, assessment changes, lifecycle
  operations, reorder, clone, publish/archive, or a generic curriculum
  facade.
- Fastify routes, direct client RPCs, browser behavior, Python/WASM grading,
  SMTP, MFA, hosted Supabase, Vercel, or secret values.
- A true two-session contention regression. The narrow module-to-chapter
  locking protocol is implemented; independent concurrent proof remains
  required before an HTTP mutation depends on this authoring family.

## Files

- supabase/migrations/20260729011900_add_curriculum_published_chapter_correction_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 32 forward migrations, all predecessor pgTAP suites, and the
50-assertion server-only-function suite. The function-suite test digest was:

    f3df1eb9651611271dc8c8c58a1bb4512c55d6bfe820e53e53ecebbe4a05c94f

The verified reset fingerprint was:

    20c19e1b089a4cf1ca7195bc61123e3207de52e72099368a452b82188d3c1035

The proof covers exact ownership, fixed path, one overload, default-deny ACL,
direct authenticated denial, full and partial editor/admin corrections,
draft-parent acceptance, learner/held/missing actor denial, exact
reason/input/version validation, draft/archived/missing target and
archived-parent denial, stale real and stale no-op denial, current-version
no-op timestamp/attribution preservation, safe response shape, one version
advance per real correction, root/parent-field preservation, redacted audit
shape/count/absence, no idempotency record, and cleared write markers.

The test also records a deterministic before/after fingerprint of every
descendant definition and learning record rooted at the corrected chapter:
theory sections, assessments and their option/key trees, theory completions,
exercise/quiz attempts and answer metadata, and chapter-progress snapshots.
It stores only digests of complete rows, so authored Markdown and answer
material are covered without being exposed; the fingerprint is unchanged after
the correction.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint, dependency boundaries, TypeScript checks, the
production build, and 184 unit tests. No hosted system or secret value was
used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
curriculum_correct_published_theory_section. It must preserve the same
content_correction/no-op/redacted-audit semantics while locking module then
chapter then theory section in canonical order, rechecking both hierarchy
edges, and allowing draft or published non-archived ancestors. It must not add
hierarchy, lifecycle, replay, Fastify/direct-client, or external configuration
behavior.
