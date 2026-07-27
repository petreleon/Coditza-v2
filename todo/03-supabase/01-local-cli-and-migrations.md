# Local Supabase CLI and migration workflow

## SUP-LOCAL-001 — Initialize the local stack

Prerequisites: FOUND-001 workspace baseline; Docker runtime available.

- [ ] Add a pinned, reviewed Supabase CLI dependency or an equally reproducible
      project-local invocation.
- [ ] Initialize `supabase/config.toml`.
- [ ] Commit `config.toml`, migrations, seed configuration, and database tests.
- [ ] Keep non-secret TOTP configuration explicit in `config.toml`; exact
      settings and proof belong to SUP-MFA-001 rather than a SQL migration.
- [ ] Ignore `.temp/`, branch state, local backups, and environment secrets.
- [ ] Start the local Supabase stack through the CLI.
- [ ] Record its non-secret URL/port mapping; obtain keys only into ignored local
      environment storage.
- [ ] Confirm local Studio opens in Chrome only when visual inspection is useful.
- [ ] Confirm no local service is publicly exposed.

## SUP-LOCAL-002 — Establish migration discipline

- [ ] Create one named migration per coherent schema step.
- [ ] Put schemas, tables, types, functions, triggers, indexes, grants, and RLS
      in migrations.
- [ ] Never edit a migration already applied to a shared environment.
- [ ] Add a forward migration for each subsequent change.
- [ ] Review generated diffs; do not commit unrelated extension/system changes.
- [ ] Use explicit `--local`/`--linked` target flags where supported.
- [ ] Never use a destructive linked reset.
- [ ] Use an expand/migrate/contract sequence for breaking changes.

## SUP-PRIMITIVES-001 — Create database primitives

Prerequisites: SUP-LOCAL-001/002.

- [ ] Create required extensions only after checking local/hosted availability.
- [ ] Create the exact `coditza_owner` role with
      `NOLOGIN NOINHERIT NOBYPASSRLS NOCREATEDB NOCREATEROLE NOREPLICATION`;
      grant no role membership to `service_role`, `anon`, or `authenticated`.
      Because roles are cluster-level and may survive a local schema reset, use
      an existence-guarded migration that revalidates/sets every attribute and
      fails on unexpected ownership/membership; never drop/recreate it casually.
- [ ] Create the unexposed `private` schema and revoke/default-deny privileges.
- [ ] Create `app_role`, `content_status`, `exercise_type`, `question_type`, and
      `quiz_attempt_status` before any table references them.
- [ ] Create a private/internal `authored_resource_type` with exactly `module`,
      `chapter`, `theory_section`, `exercise`, and `quiz` only if shared static
      workflow helpers need it; never expose it as a generic public RPC input.
- [ ] Create shared timestamp/slug/text helpers that do not depend on profiles or
      content tables.
- [ ] Add pgTAP checks for enum values, schema exposure, function search paths,
      owner-role attributes/membership, object ownership, and default privileges.
- [ ] Complete a clean reset before SUP-AUTH-001.

## Required local feedback loop

After every migration task:

```text
1. stop if the target is not visibly local
2. reset the local database from zero
3. load deterministic seed data
4. run database lint
5. run pgTAP/RLS tests
6. regenerate TypeScript database types
7. verify generation creates no unexplained diff
8. run affected API integration tests
```

These are planned steps, not commands to run during plan creation.

## Logical migration order

1. SUP-PRIMITIVES-001: extensions, `coditza_owner`, private schema, privileges,
   enums, shared functions;
2. profiles and Auth signup trigger;
3. modules, chapters, and theory sections;
4. exercises, options, and private exercise answer keys;
5. quizzes, questions, options, and private quiz answer keys;
6. completions, attempts, answers, progress, idempotency, and audit tables;
7. transactional workflow, bootstrap, and role-control functions;
8. grants and RLS policies;
9. test-only helpers, if unavoidable.

SUP-MFA-001 is a committed Auth configuration and headless-flow verification
task after profile creation; it creates no SQL migration, Auth table, or copied
factor state.

## Acceptance

- A clean local reset needs no Dashboard action.
- Migration history and a schema diff show no unexpected drift.
- Seeds never contain real credentials or real user data.
- Database types are generated, never hand-edited.
- Compose can reach the local CLI endpoint using the platform-specific tested
  path in the Compose plan; Linux loopback security is never widened merely to
  make a host gateway work.
