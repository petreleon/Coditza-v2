# Local Supabase CLI and migration workflow

## SUP-LOCAL-001 — Initialize the local stack

Prerequisites: FOUND-001 workspace baseline; Docker runtime available.

- [x] Add a pinned, reviewed Supabase CLI dependency or an equally reproducible
      project-local invocation.
- [x] Initialize `supabase/config.toml`.
- [x] Commit `config.toml` and the intentionally empty `seed.sql` path.
      Schema migrations and database tests are deliberately deferred to
      SUP-LOCAL-002.
- [x] Keep the non-secret TOTP policy explicit in `config.toml`: the maximum
      enrolled-factor count is two, while activation and flow proof remain owned
      by SUP-MFA-001 rather than a SQL migration.
- [x] Ignore `.temp/`, branch state, local backups, and environment secrets.
- [x] Start the local Supabase stack through the CLI.
- [x] Record its non-secret URL/port mapping; obtain keys only into ignored local
      environment storage.
- [x] Determine that visual Studio inspection was unnecessary; Chrome was not
      opened.
- [x] Confirm no local service is publicly exposed.

## SUP-LOCAL-002 — Establish migration discipline

- [x] Create one named migration per coherent schema step. The completed
      workflow-only baseline has no application schema effect; each later
      coherent schema change must receive its own named forward migration.
- [x] Require schemas, tables, types, functions, triggers, indexes, grants,
      and RLS to be introduced through reviewed migrations. None exists yet;
      their named owner tasks retain implementation responsibility.
- [x] Record the forward-only rule: never edit a migration after it has been
      applied to a shared environment.
- [x] Require a new forward migration for every subsequent change.
- [x] Review the generated local public-schema diff after each reset; the
      baseline is empty and unrelated extension or system drift is rejected.
- [x] Use the protected fixed commands with explicit `--local` targeting for
      reset, history, diff, and lint. Linking, remote URLs, and linked-target
      flags are outside this workflow and are rejected by its fixed interface.
- [x] Never use a destructive linked reset; the workflow has no linked target.
- [x] Record expand/migrate/contract as the required sequence for a future
      breaking change.

After SUP-LOCAL-001/002 and PRD-AUTH-001, SUP-SMTP-LOCAL-001 owns optional
user-requested Gmail SMTP delivery for the CLI-owned local Auth service. It is
not a root Compose service, migration, hosted Dashboard action, or production
email decision.

## SUP-PRIMITIVES-001 — Create database primitives

Prerequisites: SUP-LOCAL-001/002.

- [x] Check extension availability before adding one. No application extension
      is required or created at this stage; pgTAP is transient test tooling
      only.
- [x] Create the exact `coditza_owner` role with
      `NOLOGIN NOINHERIT NOBYPASSRLS NOCREATEDB NOCREATEROLE NOREPLICATION`;
      grant no role membership to `service_role`, `anon`, or `authenticated`.
      Because roles are cluster-level and may survive a local schema reset, use
      an existence-guarded migration that revalidates/sets every attribute and
      fails on unexpected ownership/membership; never drop/recreate it casually.
      The documented PostgreSQL creator-admin edge and the separate controlled
      non-inheriting migration `SET ROLE` edge are the only permitted owner
      memberships. The `postgres` operator is migration-only and never a
      Fastify/Data API runtime credential.
- [x] Create the unexposed `private` schema and revoke/default-deny privileges.
- [x] Create `app_role`, `content_status`, `exercise_type`, `question_type`, and
      `quiz_attempt_status` before any table references them.
- [x] Evaluate a private/internal `authored_resource_type` with exactly `module`,
      `chapter`, `theory_section`, `exercise`, and `quiz` only if shared static
      workflow helpers need it. No helper needs it yet, so it is intentionally
      not created or exposed as a generic public RPC input.
- [x] Create shared timestamp/slug/text helpers that do not depend on profiles or
      content tables.
- [x] Add pgTAP checks for enum values, schema exposure, function search paths,
      owner-role attributes/membership, object ownership, and default privileges.
- [x] Complete a clean reset before SUP-AUTH-001.

## Required local feedback loop

After every migration task:

```text
1. stop if the target is not visibly local
2. reset the local database from zero
3. load deterministic seed data
4. run database lint
5. run pgTAP/RLS tests
6. record whether a changed type surface exists; generate TypeScript database
   types only when the final-migrations task SUP-TYPES-001 is active
7. during SUP-TYPES-001, verify generation creates no unexplained diff
8. run affected API integration tests
```

For a workflow-only migration with no owned database object or generated type
surface, record why steps 5–8 are not applicable; never claim them as passed.
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
