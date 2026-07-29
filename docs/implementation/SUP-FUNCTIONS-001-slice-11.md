# SUP-FUNCTIONS-001 — draft-quiz root PATCH slice

Status: **in progress**. This is the eleventh bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added public.assessment_update_draft_quiz, a server-only SECURITY DEFINER
  facade granted only to service_role.
- The function deliberately has no idempotency key, replay record, request hash,
  or replay path. The authoritative API contract reserves retry identity for
  named POST, clone, and grading operations; a draft PATCH instead uses its
  required expectedVersion conflict contract.
- Requires a live, unlocked editor/admin profile before content access, then
  locks module, chapter, and quiz in canonical order. It rejects missing or
  reparented hierarchy, archived ancestors, non-draft quizzes, and stale
  expected versions.
- Accepts only a nonempty partial object with slug, title,
  instructionsMarkdown, passingPercent, maxAttempts, timeLimitSeconds, and
  isRequired. Unknown, server-owned, answer, question-tree, and mapping fields
  reject. Nullable attempt/time policies accept only JSON null or their bounded
  integer form.
- A real root change writes the resolved seven fields once, advances
  row_version through the lifecycle trigger and definition_version explicitly
  once, and records the verified staff actor. A current-version exact no-op
  returns the safe version pair without a write or audit event.
- A real update is denied when any quiz attempt exists. Attempt history joins
  the frozen definition version to the current root, so advancing a retained
  draft's definition version would make its historical projection inconsistent.
- Leaves questions, options, private answer keys, and the tree marker untouched.
  Complete draft quiz-definition replacement remains a separate workflow.
- Appends one sanitized quiz_updated audit event only for a real change and
  returns only id, rowVersion, and definitionVersion.

## Deliberately not implemented

- Complete quiz question/option/key replacement, publication, archive, clone,
  reorder, replacement, or operations facades.
- Python/WASM definitions or grading jobs; Python work remains owned by
  SUP-WASM-001.
- Fastify routes, direct client grants, generated types, browser behavior,
  SMTP, MFA, hosted Supabase, Vercel, or secret values.
- A true two-session contention regression. The transaction lock order is
  enforced here, but that proof remains required before an HTTP mutation uses
  the authoring family.

## Files

- supabase/migrations/20260729011100_add_assessment_draft_quiz_update_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 24 forward migrations, all predecessor pgTAP suites, and the
34-assertion server-only-function suite. The function-suite test digest was:

    6932197f22cc31eab06e6b10748f237f627fa8e401cf4d2aab1018081f8f1263

The verified reset fingerprint was:

    17837dc2854e5f680f66521a7489fc767c24c357a6b1c54a29cc1267a36c62a8

The regression proof covers facade ownership, fixed search path, server-only
ACL, no replay overload, exact-input and question-tree denial, root scalar
validation, learner/null/missing/held denial, stale-version rejection, full
and partial root updates, nullable policy clearing, safe no-op behavior,
attempt-history denial, archived-parent and published-root denial, preservation
of question/key material, safe audit, and the absence of a PATCH idempotency
record.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint and dependency boundaries, TypeScript checks,
production build, and 184 unit tests. No browser, HTTP route, hosted Supabase,
SMTP, MFA, Vercel, or secret value was used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is the separate
complete draft quiz-definition replacement facade. It must own the expected
root-version contract, staff/ancestor/root locks, immutable-history denial,
complete question/option/key validation and materialization, one root-version
advance, safe authoring mappings, and sanitized audit behavior without
reintroducing a generic content RPC.
