# SUP-FUNCTIONS-001 — scalar draft-exercise PATCH slice

Status: **in progress**. This is the tenth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added public.assessment_update_draft_exercise, a server-only SECURITY DEFINER
  facade granted only to service_role.
- The function deliberately has no idempotency key, replay record, request hash,
  or replay path. The authoritative API contract reserves retry identity for
  named POST, clone, and grading operations; a draft PATCH instead uses its
  required expectedVersion conflict contract.
- Requires a live, unlocked editor/admin profile before any content access, then
  locks module, chapter, and exercise in canonical order. It rejects missing or
  archived ancestors, non-draft exercises, stale expected versions, and
  python_code.
- Accepts only a nonempty partial PATCH body with title, promptMarkdown,
  exerciseType, points, isRequired, options, answerSpec,
  feedbackCorrectMarkdown, and feedbackIncorrectMarkdown. Unknown or
  server-owned fields reject.
- Root fields are independently partial. A tree edit requires both options and
  answerSpec; a type change requires that complete tree. Scalar draft trees may
  remain incomplete when answerSpec is null and both feedback fields are null,
  matching the existing private draft-definition validation contract.
- Reuses one private, actor-aware combined helper for a root-only change or an
  atomic scalar tree replacement. A real change takes one root update and
  advances row_version and definition_version exactly once. A no-op returns the
  current safe version pair without a write or audit event.
- A tree replacement rejects an exercise with learner attempt history, applies
  the existing transaction-local tree marker, deletes old key/options, remaps
  client option references to stored IDs, canonicalizes choice answers,
  normalizes short text, and assigns the verified staff actor to the new
  private key. Client mappings remain private.
- Appends one sanitized exercise_updated audit event for a real change and
  returns only id, rowVersion, and definitionVersion.

## Deliberately not implemented

- Draft quiz PATCH, quiz-question-tree replacement, publication, archive,
  clone, reorder, replacement, or operations facades.
- Python/WASM definitions or grading jobs; Python work remains owned by
  SUP-WASM-001.
- Fastify routes, direct client grants, generated types, browser behavior,
  SMTP, MFA, hosted Supabase, Vercel, or secret values.
- A true two-session contention regression. The transaction lock order is
  enforced here, but that proof remains required before an HTTP mutation uses
  the authoring family.

## Files

- supabase/migrations/20260729011000_add_assessment_draft_exercise_update_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 23 forward migrations, all predecessor pgTAP suites, and the
32-assertion server-only-function suite. The function-suite test digest was:

    02874e651a61d26dd3ac33184b098600703d2287dd387e17367bd294ab5569e9

The verified reset fingerprint was:

    e539d8b7c0d2ac93196a66f23ec9f89ce6f6e134e9ac100038338c0c2f9acf3f

The regression proof covers facade/private ACLs, editor/admin scalar
type-change and root-only patches, safe version increments, no-op behavior,
exact-input denial, learner/held-staff/missing actor denial, stale-version and
archived-parent denial, learner-history tree-replacement denial, published
exercise denial, private key material, sanitized audit, marker cleanup, and
the absence of a PATCH replay mechanism.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint and dependency boundaries, TypeScript checks,
production build, and 184 unit tests. No browser, HTTP route, hosted Supabase,
SMTP, MFA, Vercel, or secret value was used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
assessment_update_draft_quiz: a staff-only root-field PATCH with expected
root-row-version, exact partial input, canonical ancestor/root locking, no
invented retry scheme, one version advance per real change, and safe audit and
return behavior. Complete quiz-question-tree replacement remains a separate
later facade.
