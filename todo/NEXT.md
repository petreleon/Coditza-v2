# Next task

The sole next implementation task is:

**SUP-LOCAL-002 — Establish migration discipline.**

Prerequisites verified: G1 and SUP-LOCAL-001 are complete. The pinned,
project-local Supabase CLI, isolated local state, loopback-only stack, and
no-op seed path already exist. This remains a **local** database-platform task.
It must not link to, create, configure, or mutate a hosted Supabase project.

## Read first

1. README.md, TASKS.md, and STATUS.md
2. 00-control/00-scope-and-non-goals.md
3. 00-control/01-fixed-decisions.md and 02-open-decisions.md
4. 03-supabase/01-local-cli-and-migrations.md in full
5. docs/implementation/SUP-LOCAL-001.md
6. 02-architecture/02-environments-and-secrets.md
7. 02-architecture/03-docker-compose.md
8. 08-execution/00-roadmap.md, 01-dependency-map.md, and
   03-handoff-protocol.md

## Permitted scope

1. Add only the local-only command path needed to reset and inspect the
   CLI-owned local database safely. It must fail closed if the target is not the
   reviewed local project.
2. Establish repeatable migration, reset, and deterministic seed discipline.
   Use explicit local targeting where the CLI supports it.
3. Run two clean, identical local resets through the protected local workflow
   and record non-secret proof of identical results.
4. Add no domain schema beyond what is strictly required to prove the workflow.
   The named schema, role, RLS, Auth, and content tasks retain their ownership.

## Explicitly forbidden

- Do not run supabase link, target a remote project, use a remote URL, or run a
  destructive linked reset.
- Do not open or configure a hosted dashboard, Vercel, Gmail SMTP, or a real
  personal email account.
- Do not put keys, passwords, app passwords, QR/TOTP material, or local CLI
  state in tracked files, Docker image layers, or root Compose values.
- Do not add a second PostgreSQL/Auth/REST stack to compose.yaml.
- Do not enable or prove Authenticator TOTP; SUP-MFA-001 owns that flow.

## Required evidence before completion

1. Two clean local resets complete with no remote target and equivalent
   non-secret schema/seed evidence.
2. Migration and seed commands are reproducible and leave no unexplained drift.
3. Existing loopback-only networking, ignored local credentials, and controlled
   local CLI state remain intact.
4. The task report proves there were no hosted mutations and names exactly one
   next eligible task.

If a command asks to authenticate, link, select a remote project, or relax the
local isolation boundary, stop that action and record the local-only blocker
rather than accepting a remote target.
