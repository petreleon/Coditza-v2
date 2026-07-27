# Next task

The sole next implementation task is:

**SUP-PRIMITIVES-001 — Create database primitives.**

Prerequisites verified: G1, SUP-LOCAL-001, and SUP-LOCAL-002 are complete.
The protected local migration/reset/seed workflow, isolated CLI state, and
loopback-only stack are available. This remains a **local** database-platform
task; it must not link to, create, configure, or mutate a hosted project.

## Read first

1. README.md, TASKS.md, STATUS.md, and 00-control/00-scope-and-non-goals.md
2. 00-control/01-fixed-decisions.md and 00-control/02-open-decisions.md
3. 03-supabase/01-local-cli-and-migrations.md and 09-database-tests.md in full
4. docs/implementation/SUP-LOCAL-001.md and SUP-LOCAL-002.md
5. 02-architecture/02-environments-and-secrets.md and 03-docker-compose.md
6. 03-supabase/06-auth-profiles-and-roles.md and 07-rls-policy-matrix.md
7. 08-execution/00-roadmap.md, 01-dependency-map.md, and
   03-handoff-protocol.md

## Permitted scope

1. Create one or more reviewed forward local migrations for only the primitive
   objects named by SUP-PRIMITIVES-001: checked extensions, the hardened
   `coditza_owner` role, unexposed `private` schema/default-deny privileges,
   required enums, and shared helpers independent of profiles and content.
2. Add the task-owned pgTAP checks for role attributes/membership, ownership,
   schema exposure, default privileges, enums, and function search paths.
3. Use the protected `--local` reset workflow, inspect migration history/diff/
   lint, defer generated database types to SUP-TYPES-001 after final migrations,
   and record non-secret local proof.
4. Keep the existing loopback bindings, private CLI workspaces, ignored
   credential storage, and root Compose boundary intact.

## Explicitly forbidden

- Do not run `supabase link`, use a remote URL, authenticate a CLI, or run a
  destructive linked reset.
- Do not configure Gmail SMTP or use the personal mailbox. SUP-SMTP-LOCAL-001
  is ineligible until the user supplies a Gmail App Password through the
  approved ignored local mechanism.
- Do not add Auth profile logic, user data, TOTP/MFA, content tables, exercise
  or quiz data, RLS policies, root Compose services, hosted resources, or a
  frontend.
- Do not put keys, passwords, app passwords, QR/TOTP material, or local CLI
  state in tracked files, image layers, or root Compose values.

## Required evidence before completion

1. Fresh local reset, exact migration history, empty unexpected diff, and lint
   pass through the protected local-only workflow.
2. pgTAP proves the task-owned primitive ownership, privilege, enum, and helper
   contracts without leaking credentials or user data.
3. The local stack remains loopback-only; captured credentials remain ignored
   and unread; no hosted action occurs.
4. The completion report names exactly one eligible next task.

If a command asks to authenticate, link, select a remote project, or relax the
local isolation boundary, stop that action and record the blocker rather than
accepting a remote target.
