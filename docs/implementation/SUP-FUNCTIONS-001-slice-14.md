# SUP-FUNCTIONS-001 — draft-quiz authoring-read slice

Status: **in progress**. This is the fourteenth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added public.assessment_get_draft_quiz_authoring, a server-only
  SECURITY DEFINER read facade granted only to service_role.
- It requires a server-generated request UUID and checks the live active staff
  profile before protected content access. It takes canonical shared module,
  chapter, and quiz locks, rechecks the hierarchy, and rejects
  missing/reparented paths, archived ancestors, and non-draft roots.
- The returned JSON is intentionally only the protected nested definition/key
  projection: stored question and option IDs, prompts, types, points, labels,
  stored scalar answerSpec, and feedback fields. Questions and options are
  ordered by stored position and ID. It does not return client references,
  root/list/detail fields, positions, lifecycle/version fields,
  actor/timestamp/key metadata, or audit metadata.
- An empty draft returns {"questions":[]}. A valid incomplete question returns
  an empty option array and JSON null answer spec/feedback fields because no
  private key row exists. The read does not reject retained learner attempts,
  set a tree marker, or mutate either root version.
- Each successful protected read appends exactly one empty-delta
  quiz_authoring_accessed audit event. The audit records access without
  authored content, answer material, or raw values.

## Deliberately not implemented

- Ordinary admin list/detail reads, a generic assessment-type facade, or a
  learner projection.
- Quiz definition mutation, Python/WASM definitions, grading jobs, or any
  placeholder Python response; those remain owned by SUP-WASM-001.
- Fastify routes, direct client grants, replay/idempotency behavior, content
  mutations, browser behavior, SMTP, MFA, hosted Supabase, Vercel, or secret
  values.
- A true two-session contention regression. The shared lock order is enforced
  here, while that independent proof remains required before an HTTP mutation
  uses the authoring family.

## Files

- supabase/migrations/20260729011400_add_assessment_draft_quiz_authoring_read_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 27 forward migrations, all predecessor pgTAP suites, and the
40-assertion server-only-function suite. The function-suite test digest was:

    24971e309ce0be55ee32adb70243bbab2c21757449b6a09686d525405d8018cb

The verified reset fingerprint was:

    55ae649ac8ff7aee48e042f0ab63d6ce61b6840e9d7fd0888da6d803e5d6383b

The protected pgTAP invocation passed all 40 assertions. The regression proof
covers facade ownership, fixed search path, one public overload, server-only
ACL, direct runtime denial, request/actor/root validation, learner/missing/held
denial, archive/non-draft rejection, exact ordered nested stored-ID/key output,
empty and incomplete draft output, retained-attempt access, no
version/tree/idempotency mutation, safe access audit, and audit absence for
denied reads.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint and dependency boundaries, TypeScript checks,
production build, and 184 unit tests. No browser, HTTP route, hosted
Supabase, SMTP, MFA, Vercel, or secret value was used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
curriculum_update_draft_module: a separate server-only draft-module PATCH
facade. It must lock one current draft module, recheck an active staff actor,
validate a nonempty partial scalar payload and expected row version, update
only that root atomically, return a safe version result, and append a
sanitized audit event. It must not absorb chapter/theory updates, published
corrections, reordering, lifecycle changes, replay/idempotency, or HTTP/direct
client behavior.
