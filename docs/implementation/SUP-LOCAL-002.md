# SUP-LOCAL-002 — Establish migration discipline

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-28
Agent/person: Codex
Authorization checked: The user granted implementation. This task stayed within
the approved local-only Supabase scope; no hosted or secret-dependent action was
authorized or taken.
Prerequisites/gate checked: G1 and SUP-LOCAL-001 were complete. Docker was
available locally. G2 is not complete.
Decisions/defaults used: Supabase CLI remains pinned at 2.110.0. The protected
workflow accepts only the reviewed `coditza-local` loopback stack, fixed
`--local` CLI commands, a fresh private CLI workspace per command, one
no-application-effect baseline migration, and one deterministic non-persistent
seed notice.

## Scope

- Intended: Establish a fail-closed local migration/reset/seed workflow and
  prove two clean identical resets without domain schema.
- Explicitly excluded: Hosted Supabase, `supabase link`, remote targets,
  destructive linked resets, root Compose changes, user/Auth/TOTP flows, Gmail
  SMTP, Vercel, application tables/roles/RLS, real users or curriculum data,
  generated database types, and deployment work.

## Changed

- `package.json`: adds the fixed `supabase:verify-resets:local` command.
- `supabase/migrations/20260728000000_establish_local_migration_discipline.sql`:
  adds the named workflow-only baseline migration. It intentionally creates no
  application object.
- `supabase/seed.sql`: adds a deterministic, non-persistent seed execution
  marker; it creates no user, credential, fixture, or curriculum record.
- `scripts/supabase/local-stack.mjs`: validates the reviewed migration/seed
  configuration and inputs, runs two fresh local resets, checks exact applied
  migration history, requires an empty public-schema diff and lint result, and
  checks that the local shadow-diff port is released after each diff.
- `todo/` tracking: records this completion and makes SUP-PRIMITIVES-001 the
  sole eligible next task.

## Verification

- `node --check scripts/supabase/local-stack.mjs` and `git diff --check`:
  - Result: PASS
  - Non-secret evidence: the fixed launcher parsed and no whitespace errors
    were reported.
- `npm run supabase:start:local`, `npm run supabase:verify-resets:local`,
  `npm run supabase:status:local`, `npm run supabase:capture-env:local`, and
  `npm run supabase:stop:local`:
  - Result: PASS
  - Non-secret evidence: two fresh private-workspace resets applied exactly
    `20260728000000`; each reset saw the deterministic seed marker only in
    bounded private process output, matching local migration-history entries,
    an empty public-schema diff, an empty local lint result, and a released
    shadow-diff port. The reviewed migration-and-seed manifest was
    `68f8ffacee5b3d8be017138c3151172c8ef5ac5bc105eced1d3ce088c760d214` and
    both reset passes produced fingerprint
    `7590d7c734150463ba1c0e44af15929e68846ac8ca4148fcf3c5a0df13d38af6`.
    The safe status mapping remained API/Auth `127.0.0.1:54321`, PostgreSQL
    `127.0.0.1:54322`, Studio `127.0.0.1:54323`, Mailpit `127.0.0.1:54324`, and
    Analytics `127.0.0.1:54327`.
- `SUPABASE_FAKE_OVERRIDE=1 node scripts/supabase/local-stack.mjs verify-resets`:
  - Result: PASS
  - Non-secret evidence: the launcher refused inherited Supabase overrides
    before it could target any service.
- Post-stop local Docker and state inspection:
  - Result: PASS
  - Non-secret evidence: no task-labeled container or `54320` shadow-port
    publication remained; `coditza-supabase-local` remained a bridge bound to
    `127.0.0.1`; the three named local volumes were retained; `.supabase` was
    mode 0700; captured credentials remained unread, ignored, and mode 0600;
    no temporary private CLI workspace remained.
- `docker compose --profile checks run --build --rm checks npm run
  check:foundation`:
  - Result: PASS
  - Non-secret evidence: the pinned Node 24 check container passed formatting,
    linting, type checking, 177 unit tests, boundary verification, and the API
    build.

## External actions

- Local Docker only: started and stopped the CLI-owned loopback Supabase stack.
  Its named local volumes and loopback network were preserved.
- No Chrome, Dashboard, hosted Supabase, Gmail, SMTP delivery, Vercel,
  deployment, billing, or external account action occurred.

## Deviations/ADRs

- No ADR changed. The pinned CLI's experimental default schema-diff engine did
  not initialize reliably in the local runtime, so the fixed local verification
  command explicitly uses its supported `--use-migra` path. It remains
  loopback-only, uses the local shadow database, and fails closed if the shadow
  port cannot be acquired or released.

## Risks/blockers

- This is deliberately a workflow-only baseline. SUP-PRIMITIVES-001 owns the
  first real schema objects, role, privileges, enums, helpers, pgTAP checks,
  and clean-reset proof.
- Auth profiles, Authenticator TOTP, Gmail SMTP, RLS, generated database types,
  application integration, users, and Romanian curriculum data remain deferred
  to their named tasks. G2 remains open.

## Secret-safety confirmation

- No credential, token, connection string, private data, protected answer,
  Auth body, QR/TOTP/`otpauth`/factor/challenge material, or unsafe screenshot
  or log was recorded. Root environment files and captured local credential
  contents were never read or printed.

## Next

- SUP-PRIMITIVES-001 is the single unblocked task: the local migration/reset
  discipline now objectively exists, while SMTP remains ineligible until the
  user supplies a Gmail App Password through the approved ignored mechanism.
