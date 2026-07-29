# SUP-FUNCTIONS-001 — draft-exercise authoring-read slice

Status: **in progress**. This is the thirteenth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added `public.assessment_get_draft_exercise_authoring`, a server-only
  `SECURITY DEFINER` read facade granted only to `service_role`.
- It requires a server-generated request UUID and locks the live staff profile
  before content access. It then takes canonical shared module, chapter, and
  exercise locks, rechecks the hierarchy, and rejects missing/reparented
  paths, archived ancestors, non-draft roots, and `python_code` exercises.
- The returned JSON is intentionally only the protected scalar
  definition/key projection: ordered stored option IDs and labels, stored
  scalar `answerSpec`, and the two feedback fields. It does not return
  client references, root/list/detail fields, positions, lifecycle/version
  fields, actor/timestamp/key metadata, or audit metadata.
- A valid incomplete draft returns an empty option array and JSON null answer
  spec/feedback fields because no private key row exists. The read does not
  apply publish validation, reject retained learner attempts, set a tree
  marker, or mutate either exercise version.
- Each successful protected read appends exactly one empty-delta
  `exercise_authoring_accessed` audit event. The audit records access without
  authored content, answer material, or raw values.

## Deliberately not implemented

- The separate nested draft-quiz authoring projection, ordinary admin
  list/detail reads, or a generic assessment-type facade.
- Python private-definition projection, Python/WASM definitions, grading jobs,
  or any placeholder Python response; those remain owned by SUP-WASM-001.
- Fastify routes, direct client grants, replay/idempotency behavior, content
  mutations, browser behavior, SMTP, MFA, hosted Supabase, Vercel, or secret
  values.
- A true two-session contention regression. The shared lock order is enforced
  here, while that independent proof remains required before an HTTP mutation
  uses the authoring family.

## Files

- supabase/migrations/20260729011300_add_assessment_draft_exercise_authoring_read_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 26 forward migrations, all predecessor pgTAP suites, and the
38-assertion server-only-function suite. The function-suite test digest was:

    9091b5c82417ab74144d182a98b01cdde9a2a405a0b5bbe97b7f3ce532e4bc2a

The verified reset fingerprint was:

    54ae8668e910c23f4915a1adaae418c28849dbcb76a54537d3639ddd234e6064

The direct pgTAP invocation also passed 38/38 assertions. The regression
proof covers facade ownership, fixed search path, one public overload,
server-only ACL, direct runtime denial, request/actor/root validation,
learner/missing/held denial, archive/non-draft/Python rejection, complete
stored-ID option/key output in deterministic order, incomplete draft null
key output, retained-attempt access, no version/tree/idempotency mutation,
safe access audit, and audit absence for denied reads.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint and dependency boundaries, TypeScript checks,
production build, and 184 unit tests. No browser, HTTP route, hosted
Supabase, SMTP, MFA, Vercel, or secret value was used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is the
separate server-only draft-quiz authoring projection. It must use the same
staff/ancestor/ACL/audit rules, return only ordered stored question/option/key
data for a draft quiz, preserve incomplete draft questions as null-key
entries, and not create a generic assessment read facade or add HTTP/direct
client behavior.
