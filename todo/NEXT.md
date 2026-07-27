# Next task

The sole next implementation task is:

**SUP-LOCAL-001 — Initialize the local Supabase CLI stack.**

Prerequisites verified: G1 is complete and the Docker engine is available. This
is a **local** database-platform task. It must not link to, create, configure,
or mutate a hosted Supabase project; use Chrome only if a later owner file
explicitly requires visual inspection of the locally running Studio.

## Read first

1. `README.md`, `TASKS.md`, and `STATUS.md`
2. `00-control/00-scope-and-non-goals.md`
3. `00-control/01-fixed-decisions.md` and `02-open-decisions.md`
4. `03-supabase/01-local-cli-and-migrations.md` in full
5. `03-supabase/14-local-smtp.md` only for its explicit future SMTP boundary
6. `02-architecture/02-environments-and-secrets.md`
7. `02-architecture/03-docker-compose.md`
8. `08-execution/00-roadmap.md`, `01-dependency-map.md`, and
   `03-handoff-protocol.md`

## Permitted scope

1. Add one pinned, reviewed project-local Supabase CLI invocation.
2. Initialize and commit `supabase/config.toml` plus the required ignored local
   state rules. Do not add a hand-maintained Supabase Compose stack.
3. Start, inspect, and stop only the CLI-owned local stack.
4. Record non-secret local URL/port metadata; keep keys only in ignored local
   environment storage.
5. Establish the repeatable local migration/reset discipline, but do not create
   unrelated application schema, Auth flows, SMTP delivery, or hosted state.

## Explicitly forbidden

- Do not run `supabase link`, target a remote project, use a remote URL, or
  perform a destructive linked reset.
- Do not open or configure a hosted dashboard, Vercel, Gmail SMTP, or a real
  personal email account.
- Do not put local keys, passwords, app passwords, QR/TOTP material, or CLI
  temporary state in tracked files, Docker image layers, or root Compose values.
- Do not add a second PostgreSQL/Auth/REST stack to `compose.yaml`.

## Required evidence before completion

1. A clean local start/status/stop sequence succeeds with no remote target.
2. `supabase/config.toml`, ignore rules, and CLI invocation are reproducible.
3. Local URL/port mapping is recorded without printing a key.
4. No local service is made publicly reachable.
5. The task report proves there were no hosted mutations and names the next
   single eligible task, `SUP-LOCAL-002`.

If any command asks to authenticate, link, or select a remote project, stop that
action and record the local-only blocker rather than accepting a remote target.
