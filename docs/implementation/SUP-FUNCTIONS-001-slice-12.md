# SUP-FUNCTIONS-001 — draft-quiz definition replacement slice

Status: **in progress**. This is the twelfth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added `public.assessment_replace_draft_quiz_definition`, a server-only
  `SECURITY DEFINER` facade granted only to `service_role`, plus its
  owner-only `private.apply_draft_quiz_definition_replacement` collaborator.
- The public operation requires a server-generated request UUID for its audit
  record, but deliberately has no idempotency key, request hash, stored replay,
  or no-op branch. A valid replacement rematerializes its submitted tree and
  advances the root versions; a retry must use the returned row version.
- It validates a precise `{ "questions": [...] }` authoring envelope and
  locks the live active staff profile before content access, then locks module,
  chapter, and quiz in canonical order. It rejects missing or reparented
  hierarchy, archived ancestors, non-draft quizzes, stale expected versions,
  and any retained quiz attempt.
- “Complete replacement” means the complete submitted tree is replaced
  atomically; it does not require a publishable draft. An empty questions
  array remains valid, and a question with `answerSpec: null` and null or
  absent feedback persists no private answer key. Publication remains the
  separate point at which completeness is required.
- The private collaborator validates before setting the reviewed tree marker,
  deletes keys, options, then questions, materializes the new question/option
  tree, maps client references only in the safe response, remaps answer
  references to stored IDs, normalizes short text, and writes key actor
  metadata. The marker is cleared both on success and before rethrowing an
  error.
- The marker stays set only for the one allowed root update. The lifecycle
  trigger advances `row_version`, the helper advances
  `definition_version`, and the verified staff actor becomes `updated_by`.
  One safe `quiz_updated` audit event records only a coded draft-to-updated
  definition transition.

## Deliberately not implemented

- Draft assessment authoring projections, curriculum/assessment lifecycle,
  clone, reorder, operations, or generic cross-context RPCs.
- Python/WASM definitions or grading jobs; those remain owned by
  SUP-WASM-001.
- Fastify routes, direct client grants, generated types, browser behavior,
  SMTP, MFA, hosted Supabase, Vercel, or secret values.
- A true two-session contention regression. The canonical transaction locks
  are enforced here, while that separate proof remains required before an HTTP
  mutation uses the authoring family.

## Files

- supabase/migrations/20260729011200_add_assessment_draft_quiz_definition_replacement_facade.sql
- supabase/tests/functions_test.sql

## Verification

On 2026-07-29, the protected local function verifier passed after a fresh
reset:

    npm run supabase:verify-functions:local

It reviewed 25 forward migrations, all predecessor pgTAP suites, and the
36-assertion server-only-function suite. The function-suite test digest was:

    eeb11dbda00eb65fbe949ab5c296fe343a427fea7c3c4afb4fcd2246a72c2689

The verified reset fingerprint was:

    f0ae127a491f18b22a0e745a026d8eaa766a3f682a30806ef9166987c1c14998

The direct pgTAP invocation also passed 36/36 assertions. The regression proof
covers facade/private-helper ownership, fixed search paths, server-only ACL,
no replay overload, direct runtime denial, exact envelope validation,
cross-question reference denial, learner/null/missing/held denial,
ancestor/archive/draft/history/stale rejection, empty and incomplete draft
replacement, question/option mappings, normalized answer storage, private-key
actor metadata, old-tree replacement, exactly one root/definition version
advance per valid write, sanitized audit, absent idempotency record, and marker
cleanup.

The Docker Compose foundation gate also passed:

    docker compose --profile checks run --build --rm checks npm run check:foundation

It passed formatting, lint and dependency boundaries, TypeScript checks,
production build, and 184 unit tests. No browser, HTTP route, hosted Supabase,
SMTP, MFA, Vercel, or secret value was used.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is a separate
server-only draft exercise authoring projection. It must recheck live staff
authorization and canonical ancestors, expose only the protected draft
exercise definition/key projection needed by the server path, append the
plan-required safe access audit, and not add a generic
assessment-type RPC or any HTTP/direct-client behavior.
