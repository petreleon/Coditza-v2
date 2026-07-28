# SUP-DATA-001 — Core content hierarchy

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-28
Agent/person: Codex

Authorization checked: The user granted implementation. This task stayed within
the approved local-only Supabase scope; no hosted, secret-dependent, SMTP, MFA,
Chrome, Vercel, or production action was authorized or taken.

Prerequisites/gate checked: G1, SUP-LOCAL-001, SUP-LOCAL-002,
SUP-PRIMITIVES-001, SUP-AUTH-001, and PRD-ROLE-001 were complete. Docker was
available locally. G2 remains open.

## Scope

- Intended: Add the owner-controlled module → chapter → theory-section schema
  and its update/lifecycle helper, then prove hierarchy shape, constraints,
  default denial, RLS state, versions, lifecycle, transactional reordering,
  delete behavior, and effective visibility through fixed local pgTAP/reset
  checks.
- Explicitly excluded: assessments, private answer keys, attempts, progress,
  audit/idempotency, workflow RPCs, direct user policies, generated types,
  Fastify routes, MFA/SMTP, seeds, hosted Supabase, Chrome, Vercel, and
  deployment.

## Changed

- `supabase/migrations/20260728030000_create_core_content_helpers.sql`:
  private `SECURITY INVOKER`, empty-search-path INSERT/UPDATE trigger helper
  that requires new authored rows to begin as draft/version 1 with no
  publication timestamp, advances optimistic row versions, and prevents
  lifecycle/publication-history reversals.
- `supabase/migrations/20260728030100_create_core_content_hierarchy.sql`:
  owner-created `public.modules`, `public.chapters`, and
  `public.theory_sections` in parent-to-child order, with bounded validation,
  UUID defaults, deferrable sibling positions, audit/parent FKs, indexes, RLS,
  default denial, and update/timestamp triggers.
- `supabase/tests/core_content_test.sql`: 34 transaction-rolled-back pgTAP
  assertions for catalog shape, ACL/RLS, constraints, lifecycle, CAS version
  behavior, deletion, reorder, and ancestor-aware visibility.
- `scripts/supabase/local-stack.mjs` and `package.json`: exact allowlisted
  `verify-core-content` local action and npm script, which run primitive,
  profile, and core regressions before/after protected reset/diff/lint checks.

No new PostgreSQL enum/type was required. Generated application database types
remain deliberately deferred to SUP-TYPES-001 after the final migration set.

## Verification

- `npm run supabase:verify-core-content:local`
  - Result: PASS
  - Non-secret evidence: five reviewed migrations applied in protected fresh
    resets. The migration/seed manifest was
    `856ef6641fbfc2fc1c1d2506c669e188e0882e62fed873026e2f9259f58bd10b`;
    the primitive, profile, and core suite digests were respectively
    `8b7399cc7bdab6f0c62752a16e04c13badbf4b09f56f0ea0344fdc8c63614220`,
    `61f56dcf8a00e57af212f7842d530839d33a03c2b022287ca083deb3e44322e9`,
    and `09ad934f6a477f459eea88fc03f92d30208e5c368fcbed59980f294dba204634`.
    The resulting fingerprint was
    `26b0f02e58bb7d41c3615cd25a0871786c4068306def498d06f714d49dc0492a`.
    Primitive, profile, and 34 core assertions passed; public/private schema
    diffs and lint were clean before and after testing.
- `DOCKER_HOST=blocked node scripts/supabase/local-stack.mjs verify-core-content`
  - Result: PASS (expected refusal)
  - Non-secret evidence: the launcher rejected the injected Docker target
    before any stack operation.
- `docker compose --profile checks run --build --rm checks npm run check:foundation`
  - Result: PASS
  - Non-secret evidence: the disposable pinned Node 24 container passed
    formatting, linting, type checking, 177 unit tests, 63 negative and four
    positive boundary fixtures, and the API build.

## Security interpretation

- `anon`, `authenticated`, `service_role`, and `authenticator` have no direct
  core-table or private-helper access. The trusted `postgres` migration
  operator retains only the pre-existing non-inheriting owner-role SET path;
  tests prove there are no explicit table/schema/function grants to it or to a
  runtime role.
- RLS is enabled but not forced on each core table, with no permissive policy.
  This task intentionally creates neither an effective-publication helper nor
  a workflow RPC. The visibility predicate is proven structurally only; later
  function/RLS/API tasks own executable read/mutation authorization.
- A published child below a draft or archived ancestor is representable but is
  excluded by the tested effective-visibility predicate. This preserves
  authoring states without exposing them as learner-visible content.

## External actions

Local Docker only: the CLI-owned loopback Supabase stack was reset, tested,
diffed, linted, and inspected; the disposable Node 24 checks container was
built and removed. No hosted project, credential, Gmail/SMTP delivery, Chrome,
Dashboard, Vercel, billing, or account action occurred.

## Deviations/ADRs

NONE. The existing primitive types/helpers were sufficient; the optional
`authored_resource_type`, production publication helper, and workflow surface
remain out of scope.

## Risks/blockers

- SUP-SMTP-LOCAL-001 remains ineligible until the user provides a Gmail App
  Password through the approved ignored local mechanism. It does not block the
  next independent assessment-schema task.
- SUP-MFA-001 remains separately gated by SMTP and DEC-030. This report does
  not claim TOTP/AAL2 or Fastify authorization is complete.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer,
TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
recorded.

## Next

SUP-DATA-002 is the sole next eligible task. It directly depends on this core
hierarchy and owns exercise/quiz definitions, private answer keys, and their
task-scoped database validation/proof; it does not require the separately
blocked SMTP/MFA path.
