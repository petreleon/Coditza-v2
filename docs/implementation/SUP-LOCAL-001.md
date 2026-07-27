# SUP-LOCAL-001 — Initialize the local Supabase CLI stack

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: The user granted implementation and approved the
local-only Supabase task. No hosted action was authorized or taken.
Prerequisites/gate checked: G1 was complete and Docker was available locally.
Decisions/defaults used: The CLI is pinned at version 2.110.0. The reviewed
local project ID is coditza-local; all published service bindings are loopback
only. The non-secret MFA policy caps enrolled factors at two, while
Authenticator enablement and headless-flow proof remain deferred to SUP-MFA-001.

## Scope

- Intended: Add a reproducible project-local Supabase CLI configuration, isolate
  its local state, start/status/capture/stop the local CLI-owned stack, and
  record non-secret proof.
- Explicitly excluded: Hosted Supabase, Chrome/Dashboard activity, root Compose
  changes, migrations or application schema, users/Auth/TOTP flows, Gmail SMTP,
  Vercel, and deployment work.

## Changed

- package.json and package-lock.json: pin Supabase CLI 2.110.0 and expose only
  fixed local lifecycle commands.
- supabase/config.toml, supabase/.gitignore, and supabase/seed.sql: hold the
  reviewed local configuration, protected generated-state rules, and intentional
  no-op seed path.
- scripts/supabase/local-stack.mjs: provide a fixed-action, fail-closed local
  launcher that rejects inherited Supabase and dangerous Docker target
  overrides, uses a fresh private workspace for every action, and never logs
  credentials.
- .gitignore and .dockerignore: exclude root local Supabase state, generated
  database artifacts, and captured local credentials.
- Dockerfile: make the existing checks stage copy its formatter inputs,
  including the local Supabase launcher, without changing runtime or Compose.
- todo tracking files: record completion and make SUP-LOCAL-002 the sole next
  task.

## Verification

- Node syntax check for scripts/supabase/local-stack.mjs:
  - Result: PASS
  - Non-secret evidence: the fixed launcher parsed successfully.
- Active configuration interpolation and local-state guard:
  - Result: PASS
  - Non-secret evidence: no active environment interpolation remained in the
    reviewed configuration; linked-project state was absent; local state,
    credential capture, temporary state, branches, and backups were ignored.
- npm run supabase:start:local; npm run supabase:status:local; npm run
  supabase:capture-env:local; npm run supabase:stop:local:
  - Result: PASS
  - Non-secret evidence: API and Auth issuer use 127.0.0.1:54321, PostgreSQL
    uses 127.0.0.1:54322, Studio uses 127.0.0.1:54323, Mailpit uses
    127.0.0.1:54324, and Analytics uses 127.0.0.1:54327. The captured local
    credential file was ignored and mode 0600; its contents were not read.
- Local Docker exposure and cleanup inspection:
  - Result: PASS
  - Non-secret evidence: all published ports bound to loopback only; the
    dedicated bridge network binds host ports to 127.0.0.1; stopping left no
    labeled containers running while preserving the final local network and
    named volumes.
- docker compose --profile checks run --build --rm checks npm run
  check:foundation:
  - Result: PASS
  - Non-secret evidence: Node 24 checks passed formatting, linting, type
    checking, 177 unit tests, boundary verification, and the API build.
- git diff --check:
  - Result: PASS
  - Non-secret evidence: no whitespace errors were reported.

## External actions

- Local Docker only: the CLI created and stopped the local coditza-local stack,
  its loopback-only bridge network, and named local volumes.
- During isolation hardening, three empty task-created local volumes were
  removed because their initial ephemeral state could not be safely reused.
  Clean replacement local volumes were then created and preserved. The removed
  volumes cannot be recovered.
- No Chrome, Dashboard, hosted Supabase, SMTP, Vercel, deployment, or external
  account action occurred.

## Deviations/ADRs

- No architecture decision changed. The launcher was hardened before final
  verification to use a fresh private workspace that is isolated from
  repository root environment files, stale dotenv variants, and linked-project
  state.

## Risks/blockers

- Authenticator TOTP is intentionally not enabled or flow-verified; SUP-MFA-001
  owns activation, enrollment, login, and AAL evidence.
- No application migrations, schema, database tests, or deterministic reset
  proof exist yet; SUP-LOCAL-002 owns those steps.

## Secret-safety confirmation

- No credential, token, connection string, private data, protected answer,
  Auth body, QR/TOTP/otpauth/factor/challenge material, or unsafe
  screenshot/log was recorded. Raw Supabase CLI output and the root .env file
  were never read or printed. Captured local credentials were neither opened nor
  logged.

## Next

- SUP-LOCAL-002 is the single unblocked task because the local CLI,
  isolated state, safe lifecycle, and loopback network have been objectively
  verified; it owns migration/reset/seed discipline.
