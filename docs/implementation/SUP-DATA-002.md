# SUP-DATA-002 — Assessment definitions and private answer keys

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-29
Agent/person: Codex

Authorization checked: The user authorized the task-scoped local implementation
and explicitly approved the protected Docker/Supabase retry used for final
verification. No hosted, secret-dependent, SMTP, MFA, Chrome, Vercel, or
production action was taken.

Prerequisites/gate checked: G1, SUP-LOCAL-001, SUP-LOCAL-002,
SUP-PRIMITIVES-001, SUP-AUTH-001, PRD-ROLE-001, and SUP-DATA-001 were
complete. G2 remains open.

## Scope

- Intended: Add owner-controlled exercise/quiz definition trees, isolated
  private answer keys, strict answer/key validators, atomic draft replacement,
  publication immutability, and fixed local proof covering catalog, ACL, RLS,
  lifecycle, definition version, cross-owner references, and no direct runtime
  key access.
- Explicitly excluded: learner attempts/progress, audit/idempotency records,
  Python verifier jobs/evidence, public/server authoring RPCs, direct user
  policies, generated database types, Fastify routes, MFA/SMTP, seeds, hosted
  Supabase, Chrome, Vercel, and deployment.

## Changed

- `supabase/migrations/20260728040000_create_assessment_public_definitions.sql`:
  creates public exercises, exercise options, quizzes, questions, and question
  options in parent-to-child order with bounded authored fields, scoped
  deferrable positions/slugs, lifecycle/version fields, audit/parent FKs,
  indexes, RLS, and default-deny privileges.
- `supabase/migrations/20260728040100_create_assessment_private_answer_keys.sql`:
  creates non-exposed exercise and quiz-question answer-key tables with private
  RLS/default denial, bounded feedback, actor FKs, and indexes.
- `supabase/migrations/20260728040200_create_assessment_definition_guards.sql`:
  adds owner-only `SECURITY INVOKER`, empty-search-path validation/replacement
  helpers; strict stored and authoring answer specs; draft-tree markers and
  triggers; publication validation; immutable published definitions; and final
  private/function/table revocations. It forward-replaces the shared lifecycle
  helper to prevent a never-published archived resource acquiring a false
  publication timestamp.
- `supabase/tests/assessment_definitions_test.sql`: 38 transaction-rolled-back
  pgTAP assertions covering catalog/ACL/RLS, generated-ID mapping, stored-key
  shape and ownership, draft direct-write denial, atomic rollback/CAS/version
  behavior, publication constraints, Python fail-closed behavior, immutability,
  reorder, parent restriction, and service-role private-read denial.
- `scripts/supabase/local-stack.mjs` and `package.json`: add the exact
  allowlisted `verify-assessments` local action and npm script. The action
  preserves primitive/profile/core regressions before and after protected
  reset/diff/lint checks.

The migration adds no new PostgreSQL enum or application type surface.
Generated application database types remain deferred to SUP-TYPES-001 after
the final migration set.

## Verification

- `npm run supabase:verify-assessments:local`
  - Result: PASS
  - Non-secret evidence: eight reviewed migrations applied in two deterministic
    protected resets. The migration/seed manifest was
    `3c41e706c4834112edecca140716496a735761259f5557bf361fcee9fba78115`.
    Primitive, profile, core-content, and assessment suite digests were
    respectively
    `8b7399cc7bdab6f0c62752a16e04c13badbf4b09f56f0ea0344fdc8c63614220`,
    `61f56dcf8a00e57af212f7842d530839d33a03c2b022287ca083deb3e44322e9`,
    `09ad934f6a477f459eea88fc03f92d30208e5c368fcbed59980f294dba204634`,
    and `b4273e77df5277584ad730633fd8079d51d74f7cb214aef85aad01386d9a0e1c`.
    The final reset fingerprint was
    `cbd59fe08ffe5687f63c4c871767dddcec5a5815e17d2ed9bbf97f2c418ab866`.
    All primitive/profile/core suites and 38 assessment assertions passed; the
    public/private schema diffs and lint were clean.
- `env DOCKER_HOST=blocked node scripts/supabase/local-stack.mjs verify-assessments`
  - Result: PASS (expected refusal)
  - Non-secret evidence: the fixed launcher rejected the injected Docker
    target before any stack operation.
- `docker compose --profile checks run --build --rm checks npm run check:foundation`
  - Result: PASS
  - Non-secret evidence: the disposable pinned Node 24 container passed
    formatting, linting, type checking, 177 unit tests, 63 negative and four
    positive boundary fixtures, and the API build.

## Security interpretation

- `anon`, `authenticated`, `service_role`, and `authenticator` have no direct
  assessment-table DML or private-key reads, schema usage, or private helper
  execution. The task adds no public RPC or policy surface.
- RLS is enabled and not forced on all new tables, with no permissive policy;
  the trusted owner-only migration/function path remains the sole definition
  mutation mechanism until SUP-FUNCTIONS-001 and SUP-RLS-001 own the later
  server/user surfaces.
- Private keys retain only generated UUID references, never authoring client
  references. Cross-exercise/question keys, malformed specs, unsorted multiple
  selections, and direct draft writes are rejected.
- `python_code` publication remains intentionally fail-closed until
  SUP-WASM-001 defines the approved digest-pinned private artifact.

## External actions

Local Docker only: the CLI-owned loopback Supabase stack was reset, tested,
diffed, linted, and inspected; a transient local Auth-health failure was
recovered by a scoped stop/start of `coditza-local` while preserving local
volumes, after which the final protected verifier passed. The disposable Node
24 checks container was built and removed. No hosted project, credential,
Gmail/SMTP delivery, Chrome, Dashboard, Vercel, billing, or account action
occurred.

## Deviations/ADRs

NONE. The final local lint fix removes only three redundant PL/pgSQL loop
variable declarations. The short-text pgTAP fixture now uses an actual ASCII
tab escape rather than the literal characters `\\t`; the pinned normalizer's
ASCII-whitespace-only contract was not changed.

## Risks/blockers

- SUP-SMTP-LOCAL-001 remains ineligible until the user supplies a Gmail App
  Password through the approved ignored local mechanism; it does not block the
  next independent task.
- SUP-MFA-001 remains separately gated by SMTP and DEC-030. This report does
  not claim TOTP/AAL2 or Fastify authorization is complete.

## Secret-safety confirmation

No credential, token, connection string, private answer, TOTP/QR/`otpauth`,
factor/challenge material, or unsafe screenshot/log was read or recorded.

## Next

SUP-DATA-003 is the sole next eligible task. It depends on these immutable
assessment definitions and owns attempts, completions, progress snapshots,
audit/idempotency tables, and its task-scoped local proof.
