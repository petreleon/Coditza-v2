# SUP-PRIMITIVES-001 — Create database primitives

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-28
Agent/person: Codex
Authorization checked: The user granted implementation. This task stayed within
the approved local-only Supabase scope; no hosted, secret-dependent, or
production action was authorized or taken.
Prerequisites/gate checked: G1, SUP-LOCAL-001, and SUP-LOCAL-002 were complete.
Docker was available locally. G2 is not complete.
Decisions/defaults used: Supabase CLI remains pinned at 2.110.0. The reviewed
local project remains coditza-local, loopback-only, and invoked only through
the fixed private-workspace launcher. No product extension is required by the
current primitive contract; pgTAP is temporary test tooling only.

## Scope

- Intended: Add the foundational database-owner role, private/default-deny
  schema boundary, exact primitive enums, and table-independent helpers through
  one forward migration; prove them with task-owned pgTAP and clean resets.
- Explicitly excluded: Hosted Supabase, supabase link, remote targets,
  destructive linked resets, root Compose changes, profiles/Auth triggers,
  users, TOTP/MFA, Gmail SMTP, Vercel, content/assessment/progress tables, RLS
  policy matrix, curriculum data, generated TypeScript database types, and
  deployment work.

## Changed

- supabase/migrations/20260728010000_create_database_primitives.sql:
  creates/revalidates the non-login coditza_owner role, the unexposed private
  schema, global owner default-deny privileges, five public enums, and the
  private timestamp, short-text-normalization, and slug helpers. It
  intentionally does not create private.authored_resource_type, because no
  shared static helper needs it yet.
- supabase/tests/primitives_test.sql: adds 28 transaction-rolled-back pgTAP
  assertions for role topology, runtime denial, schema/type/function ownership,
  default privileges, helper fixed search paths, helper behavior, and the
  intentionally absent conditional type.
- scripts/supabase/local-stack.mjs and package.json: add the fixed
  supabase:verify-primitives:local action. It accepts only the reviewed test
  file, performs a reset/history/diff/lint pass for public and private, runs the
  local pgTAP container, performs another reset/history/diff/lint pass,
  compares deterministic fingerprints, and never prints raw test or credential
  output. It also rejects API schema/search-path settings that could expose
  private.
- todo tracking: records this completion and makes SUP-AUTH-001 the sole
  eligible next task.

## Verification

- node --check scripts/supabase/local-stack.mjs, npm run format:check, and git
  diff --check:
  - Result: PASS
  - Non-secret evidence: the fixed launcher parsed, tracked formatter inputs
    passed, and no whitespace error was reported.
- npm run supabase:verify-primitives:local:
  - Result: PASS
  - Non-secret evidence: the protected local workflow performed fresh reset,
    exact migration-history, public/private diff, and lint checks before and
    after the reviewed pgTAP suite. Two reviewed migrations were applied; the
    deterministic migration-and-seed manifest was
    2f3687774593592909dbc6771334be4f137b21076be51867b1e7f1d6c7a4d4e0,
    the primitive test digest was
    8b7399cc7bdab6f0c62752a16e04c13badbf4b09f56f0ea0344fdc8c63614220,
    and the verified reset fingerprint was
    4d87c50497dfbf23928beaf106781d57fcd2ee4db417bd4fc460dca438fd2730.
- Local post-reset database probe:
  - Result: PASS
  - Non-secret evidence: transient pgTAP and probe objects were absent after
    reset; only the documented non-inheriting owner membership topology
    remained; the explicit migration SET ROLE edge existed; and no runtime
    role could set coditza_owner.
- npm run supabase:status:local, npm run supabase:capture-env:local, and npm
  run supabase:stop:local:
  - Result: PASS
  - Non-secret evidence: API/Auth stayed at 127.0.0.1:54321, PostgreSQL at
    127.0.0.1:54322, Studio at 127.0.0.1:54323, Mailpit at 127.0.0.1:54324,
    and Analytics at 127.0.0.1:54327. Captured credentials remained unread,
    ignored, and mode 0600. Stop preserved only the named local volumes and the
    127.0.0.1 bridge network; no task-labeled container, shadow-port
    publication, or private CLI workspace remained.
- DOCKER_HOST=blocked node scripts/supabase/local-stack.mjs verify-primitives:
  - Result: PASS
  - Non-secret evidence: the launcher rejected Docker target overrides before
    any service action.
- Configuration and state inspection:
  - Result: PASS
  - Non-secret evidence: the reviewed Supabase configuration contains no active
    environment interpolation; .supabase remained mode 0700; ignored local
    capture/state/backup paths were confirmed without opening credentials.
- docker compose --profile checks run --build --rm checks npm run
  check:foundation:
  - Result: PASS
  - Non-secret evidence: formatting, lint, type checking, 177 unit tests,
    boundary verification, and the API build passed in the disposable Node 24
    check container.

## External actions

- Local Docker only: started, reset, tested, inspected, and stopped the
  CLI-owned loopback Supabase stack. Its named volumes and loopback network
  were preserved.
- No Chrome, Dashboard, hosted Supabase, Gmail, SMTP delivery, Vercel,
  deployment, billing, or external account action occurred.

## Deviations/ADRs

- No ADR changed. PostgreSQL 17 automatically gives a non-superuser
  CREATEROLE operator an admin-only creator membership for a role it creates.
  That bootstrap-superuser-granted edge is non-inheriting and cannot be changed
  by the migration operator. The migration permits only that documented edge
  plus one separate ADMIN FALSE, INHERIT FALSE, SET TRUE migration edge; all
  other owner memberships and every runtime SET ROLE path fail the
  migration/tests. postgres is a trusted migration-only operator and never a
  Fastify/Data API runtime credential.
- No application extension was added. The pinned local pgTAP runner creates
  transient test tooling only, and the final protected reset confirmed it is
  absent afterward.

## Risks/blockers

- Profiles/Auth trigger behavior, role control, TOTP/MFA configuration and
  flows, RLS policy matrix, all domain tables/workflows, generated types, and
  Fastify integration remain deferred to their named tasks. G2 remains open.
- SUP-SMTP-LOCAL-001 remains ineligible until the user supplies a Gmail App
  Password through the approved ignored local mechanism. It does not block
  SUP-AUTH-001.

## Secret-safety confirmation

- No credential, token, connection string, private data, protected answer,
  Auth body, QR/TOTP/otpauth/factor/challenge material, or unsafe screenshot
  or log was recorded. Root environment files and captured local credential
  contents were never read or printed.

## Next

- SUP-AUTH-001 is the single unblocked task. It owns only the local
  signup-profile table/trigger and task-owned proof; SMTP remains ineligible
  pending a user-provided Gmail App Password.
