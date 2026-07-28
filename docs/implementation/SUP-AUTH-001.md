# SUP-AUTH-001 — Signup profile

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-28
Agent/person: Codex

Authorization checked: The user granted implementation. This task stayed within
the approved local-only Supabase scope; no hosted, secret-dependent, SMTP, MFA,
or production action was authorized or taken.

Prerequisites/gate checked: G1, SUP-LOCAL-001, SUP-LOCAL-002, and
SUP-PRIMITIVES-001 were complete. Docker was available locally. G2 remains
open.

## Scope

- Intended: Add the minimal `public.profiles` projection and Auth-insert
  trigger, then prove default learner, fallback, duplicate, rollback, cascade,
  direct-access, and no-factor-copy behavior through fixed local pgTAP/reset
  checks.
- Explicitly excluded: Hosted Supabase, `supabase link`, remote targets, root
  Compose changes, Gmail SMTP, TOTP/MFA configuration or flows, Auth UI/client
  flows, Fastify routes/token verification, role-control/bootstrap/recovery
  functions, content tables, seeds, generated types, curriculum data, Vercel,
  and deployment.

## Changed

- `supabase/migrations/20260728020000_create_auth_profiles.sql`:
  - creates `public.profiles` with the approved six non-secret columns, an
    `auth.users(id)` delete-cascade FK, trimmed 1–80-character name constraint,
    learner default, nullable hold, timestamps, and the existing timestamp
    trigger;
  - enables RLS without force or user policy and explicitly removes direct
    table access from `PUBLIC`, `anon`, `authenticated`, `service_role`,
    `authenticator`, and the trusted migration operator;
  - creates owner-controlled `private.create_profile_for_auth_user()` as a
    fixed-empty-search-path `SECURITY DEFINER` trigger function;
  - accepts exactly the client metadata key `displayName` when it is an
    already-trimmed JSON string of 1–80 characters; all other values use the
    literal `Learner`; it never reads email, app metadata, passwords, sessions,
    factors, or MFA material;
  - writes explicit `learner` and `NULL` hold values and uses `ON CONFLICT (id)
    DO NOTHING` for replay safety.
- The Auth schema remains managed by Supabase. The trusted local migration
  operator creates the FK-bearing table and attaches the trigger; its temporary
  type/schema/function ACLs are revoked in the same transaction before commit.
  `coditza_owner` receives no enduring `auth.*` privilege.
- `supabase/tests/auth_profiles_test.sql` adds 25 transaction-rolled-back
  pgTAP checks for ownership, exact projection/type/FK shape, RLS and ACLs,
  temporary-ACL removal, trigger security/shape, valid/fallback metadata,
  ignored role/hold metadata, timestamp and name constraints, duplicate
  execution, profile-failure rollback, cascade deletion, and direct-data-only
  AAL1 denial evidence.
- `scripts/supabase/local-stack.mjs` and `package.json` add the fixed
  `supabase:verify-auth-profiles:local` action. The reviewed test set is an
  exact allowlist of `primitives_test.sql` and `auth_profiles_test.sql`; each
  action passes only its fixed file path(s), never arbitrary caller input.
  The new action runs the primitive regression plus the profile suite between
  protected public/private reset, history, diff, and lint passes.
- The fixed history parser accepts only the pinned CLI's documented local-only
  representation (`remote` empty) or a mirrored local/remote version. Reset
  success plus clean schema diff still prove the applied local migration state.

## Verification

- `node --check scripts/supabase/local-stack.mjs` and `git diff --check`:
  - Result: PASS
  - Non-secret evidence: the fixed launcher parsed and no whitespace error was
    reported.
- `npm run supabase:verify-auth-profiles:local`:
  - Result: PASS
  - Non-secret evidence: three reviewed migrations applied during protected
    fresh resets. The migration/seed manifest was
    `14f4222c9ac88821936320f7dd559d4d7cf0f347a9e30aeb72d569ffa6172b18`,
    the primitive-suite digest was
    `8b7399cc7bdab6f0c62752a16e04c13badbf4b09f56f0ea0344fdc8c63614220`,
    the profile-suite digest was
    `61f56dcf8a00e57af212f7842d530839d33a03c2b022287ca083deb3e44322e9`,
    and the final reset fingerprint was
    `2952bff2eb87548624de13f0128b1f2c5a402807a52f8ca5e8b935cc46f9f051`.
    Both suites passed 53 assertions total; public/private diffs and lint were
    clean before and after testing.
- `npm run supabase:verify-primitives:local`:
  - Result: PASS
  - Non-secret evidence: the preserved one-file primitive verifier still
    passed under the three-migration baseline; its post-reset fingerprint was
    `ba52f8f60f739e765972d3937c9011fd632b78e25c43cfaea641d42943d2127e`.
- `DOCKER_HOST=blocked node scripts/supabase/local-stack.mjs
  verify-auth-profiles`:
  - Result: PASS (expected refusal)
  - Non-secret evidence: the launcher rejected the injected Docker target
    before any stack operation.
- `npm run supabase:status:local`:
  - Result: PASS
  - Non-secret evidence: the local stack remained loopback-only at API/Auth
    `127.0.0.1:54321`, PostgreSQL `127.0.0.1:54322`, Studio
    `127.0.0.1:54323`, Mailpit `127.0.0.1:54324`, and Analytics
    `127.0.0.1:54327`.
- `docker compose --profile checks run --build --rm checks npm run
  check:foundation`:
  - Result: PASS
  - Non-secret evidence: the pinned Node 24 check container passed formatting,
    linting, type checking, 177 unit tests, boundary verification, and build.

## Security interpretation

- The profile's presence is not proof that registration or mandatory MFA is
  complete. The tests prove only database/direct-data denial: no direct
  profile privilege/policy is granted to `anon` or `authenticated`, and no
  factor/enrollment field is projected. Genuine AAL1/AAL2 Auth flows and
  Fastify's verified-token domain boundary remain owned by SUP-MFA-001 and the
  later Fastify tasks.
- The profile trigger does not mask insertion failure: a test-only profile
  constraint aborts the originating synthetic Auth insert and leaves neither
  parent nor profile row. The test transaction is rolled back.

## External actions

- Local Docker only: started, reset, tested, and inspected the CLI-owned
  loopback Supabase stack. Its named local volumes and loopback network were
  preserved.
- No Chrome, Dashboard, hosted Supabase, Gmail, SMTP delivery, Vercel,
  deployment, billing, or external account action occurred.

## Risks/blockers

- G2 remains open. TOTP/MFA, real Auth AAL transitions, complete direct Data
  API policy matrix, Fastify authorization, role-control/bootstrap/recovery,
  all domain content/workflows, generated types, and deployment remain owned by
  later tasks.
- SUP-SMTP-LOCAL-001 remains ineligible until the user supplies a Gmail App
  Password through the approved ignored local mechanism. It does not block the
  next PRD-ROLE-001 verification task.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer, Auth
body, QR/TOTP/`otpauth`/factor/challenge material, or unsafe screenshot/log was
recorded. Root environment files and captured local credential contents were
never read or printed.

## Next

PRD-ROLE-001 is the sole next eligible task. It verifies and records the
already-proven product requirement for default learner creation; it must not
modify this migration or begin MFA/SMTP/hosted work.
