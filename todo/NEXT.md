# Next task

The sole next implementation task is:

**SUP-AUTH-001 — Signup profile.**

Prerequisites verified: G1, SUP-LOCAL-001, SUP-LOCAL-002, and
SUP-PRIMITIVES-001 are complete. The protected local-only reset/test workflow
exists, its owner/private-schema foundations are verified, and the stack stays
loopback-only. This remains a **local** database-platform task; it must not
link to, create, configure, or mutate a hosted project.

## Read first

1. README.md, TASKS.md, STATUS.md, and 00-control/00-scope-and-non-goals.md
2. 00-control/01-fixed-decisions.md and 00-control/02-open-decisions.md
3. 03-supabase/01-local-cli-and-migrations.md,
   03-supabase/06-auth-profiles-and-roles.md, and
   03-supabase/09-database-tests.md in full
4. docs/implementation/SUP-LOCAL-001.md, SUP-LOCAL-002.md, and
   SUP-PRIMITIVES-001.md
5. 02-architecture/02-environments-and-secrets.md,
   02-architecture/04-data-flow-and-security.md, and
   03-docker-compose.md
6. 03-supabase/07-rls-policy-matrix.md, 03-supabase/12-mfa-totp.md, and
   08-execution/00-roadmap.md, 01-dependency-map.md, and
   03-handoff-protocol.md

## Permitted scope

1. Add one reviewed forward local migration for public.profiles and the
   profile-creation trigger only. The table must be owned by coditza_owner and
   contain:
   - id uuid primary key referencing auth.users(id) with ON DELETE CASCADE;
   - a trimmed 1–80-character display_name;
   - role app_role not null default learner;
   - nullable security_hold_at;
   - created/updated timestamps and the already-owned timestamp trigger.
2. Add one fixed-search-path SECURITY DEFINER trigger function owned by
   coditza_owner that runs for new auth.users rows:
   - accept a valid trimmed display-name metadata value only;
   - otherwise use the literal non-identifying fallback Learner;
   - always persist learner, ignoring client role metadata;
   - initialize security_hold_at to null;
   - never derive data from email and never persist password, email, JWT,
     session, factor, QR, otpauth, secret, or TOTP state;
   - make duplicate invocation harmless or explicitly constrained.
3. Apply owner/default-grant/RLS rules needed for this newly created table so
   users cannot directly write role or security_hold_at. Do not claim the later
   complete RLS matrix; that belongs to SUP-RLS-001.
4. Add task-owned local pgTAP tests covering exactly one default learner
   profile, valid and fallback names, ignored client role metadata, null hold,
   duplicate-trigger behavior, failed profile insertion rolling back signup,
   and auth.users deletion cascade. Prove no factor/enrollment data is copied.
   Treat the AAL1 result here as database/direct-access evidence only; full
   Fastify AAL enforcement belongs to later MFA/Fastify tasks.
5. Use the protected local reset/history/diff/lint/test workflow and record
   non-secret local proof. Defer generated TypeScript database types until
   SUP-TYPES-001 after final migrations.

## Explicitly forbidden

- Do not run supabase link, use a remote URL, authenticate a CLI, or run a
  destructive linked reset.
- Do not configure Gmail SMTP or use the personal mailbox. SUP-SMTP-LOCAL-001
  is ineligible until the user supplies a Gmail App Password through the
  approved ignored local mechanism.
- Do not enable/configure TOTP/MFA or build registration/login UI/client flows.
- Do not add Fastify routes, role-control/bootstrap/recovery functions, content
  tables, exercises, quizzes, seeds, generated types, root Compose services,
  hosted resources, or a frontend.
- Do not put keys, passwords, app passwords, QR/TOTP material, Auth bodies, or
  local CLI state in tracked files, image layers, or root Compose values.

## Required evidence before completion

1. Fresh protected local reset applies the named profile migration, exact
   history, empty unexpected public/private diff, and lint pass.
2. Task-owned pgTAP proves profile defaults/fallback/cascade/rollback,
   direct-write denial, no factor-state copy, and the exact fixed-search-path
   trigger ownership/privilege contract without leaking credentials or user
   data.
3. The local stack remains loopback-only; captured credentials remain ignored
   and unread; no hosted action occurs.
4. The completion report names exactly one eligible next task.

If a command asks to authenticate, link, select a remote project, relax the
local isolation boundary, or use real account data, stop that action and record
the blocker rather than accepting a remote target.
