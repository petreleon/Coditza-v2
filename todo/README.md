# Coditza implementation plan

## Purpose

This directory is the implementation blueprint for **Coditza**. Coditza is a
learning platform with this fixed hierarchy:

`module -> chapter -> theory sections + exercises + quizzes`

The planned backend is a modular monolith on Node.js and Fastify, with
hexagonal boundaries inside each business module. Supabase provides PostgreSQL,
email/password identity, mandatory Authenticator-app TOTP MFA, and—only if media
is later approved—Storage. Docker Compose is required for running the Fastify
API. Python code exercises are graded with a pinned Pyodide runtime in a
hardened authoritative server sandbox; a future browser Web Worker is
provisional only. Chrome is required for later Supabase Dashboard
configuration.

## Current repository state

Implementation is authorized and G0 has passed, but PLAN-004 must first add
executable paths for the user's Vercel and local Gmail SMTP requirements. No
local implementation task is permitted until that review succeeds. Planning
files plus the separately requested root `.env`, `.env.example`, `.gitignore`,
and `.dockerignore` safety files may exist. The existing hosted-project
environment values do not authorize a schema or deployment action; every
hosted, production, secret-dependent, and destructive task retains its explicit
safeguards.

Implementation tracking starts in [TASKS.md](TASKS.md), [STATUS.md](STATUS.md),
and [NEXT.md](NEXT.md). They name the single task currently permitted by the
execution protocol.

The separate Romanian content-production plan starts at
[todo-curriculum-ro](../todo-curriculum-ro/README.md). Its first real module is
`Arhitectură software în Python`; content authorization is independent from
backend implementation authorization.

## How an implementation agent must use this plan

1. Read this file and every file in `00-control/`.
2. Read `TASKS.md` and `08-execution/00-roadmap.md`; identify the sole `next`
   task and confirm every prerequisite.
3. Work on exactly that one task ID.
4. Read every prerequisite named by that task before changing files.
5. Inspect the current repository and preserve unrelated user changes.
6. Implement only the files listed by the active task.
7. Run every verification listed by the task.
8. Mark a checkbox complete only when its verification passes.
9. Record commands, results, and deviations in the implementation report
   described by `08-execution/03-handoff-protocol.md`.
10. Stop at every phase gate. Never silently skip a gate.

If a task conflicts with `00-control/01-fixed-decisions.md`, the fixed decision
wins. If two task files conflict, stop and resolve the conflict in an ADR before
implementation.

## Category index

| Order | Category | Purpose |
| --- | --- | --- |
| 00 | [Control](00-control/00-scope-and-non-goals.md) | Scope, decisions, rules, completion standards |
| 01 | [Product](01-product/00-domain-glossary.md) | Learning hierarchy, roles, publishing, grading |
| 02 | [Architecture](02-architecture/00-system-boundaries.md) | Boundaries, target tree, environments, Compose |
| 03 | [Supabase](03-supabase/00-chrome-dashboard-setup.md) | Dashboard, migrations, schema, Auth, RLS, tests |
| 04 | [Fastify](04-fastify/00-bootstrap-and-config.md) | Server bootstrap, plugins, auth, use cases/adapters, errors |
| 05 | [API](05-api/00-api-conventions.md) | Exact REST resources and behavior |
| 06 | [Quality](06-quality/00-testing-strategy.md) | Unit, integration, RLS, end-to-end, security |
| 07 | [Operations](07-operations/00-ci-pipeline.md) | CI, deployment, monitoring, recovery, release |
| 08 | [Execution](08-execution/00-roadmap.md) | Order, dependencies, gates, handoff, acceptance |
| 09 | [Templates](09-templates/00-task-report-template.md) | Repeatable implementation and ADR records |

The cross-category task/status index is [TASKS.md](TASKS.md). Checkbox IDs such
as `DB-*` and `QA-UNIT-*` are verification cases owned by their linked task, not
permission to start an unscheduled parallel task.

## Non-negotiable boundaries

- Domain data goes through Fastify. A client may use Supabase directly only for
  Supabase Auth registration, confirmation, password, session, and TOTP
  operations. Migrations revoke `anon`/`authenticated` domain table and
  workflow-function access so this is enforced, not merely a client convention.
- Every Coditza user must finish TOTP enrollment and present an access token
  with `aal2` before any `/api/v1` domain route is usable. Fastify never receives
  a password, TOTP code, QR code, or enrollment secret.
- Business modules expose public application contracts only. Fastify and
  Supabase are adapters; domain/application code cannot import them.
- The Supabase migration files are the schema source of truth. Do not make
  untracked schema changes in the hosted Dashboard.
- Use a publishable key for public/client-safe operations and a secret key only
  inside the server. Never expose or log a secret or legacy service-role key.
- Row Level Security is required on every table exposed through Supabase's Data
  API. User-facing Supabase roles are deny-by-default; the high-impact server
  secret client remains behind module-specific adapters/functions, has no
  direct Coditza table DML, and receives only safe-column reads plus exact
  entry-function execution.
- Correct answers and grading keys are never returned by learner endpoints.
- `python_code` source is always re-run server-side in the pinned WASM worker
  inside the approved outer sandbox. No client/browser verdict, score, tests,
  actor, or runtime choice is trusted.
- WebAssembly alone is not the security boundary: the authoritative worker has
  no network, secrets, host mounts, container socket, package downloads, or
  Auth/TOTP role and is constrained by hard resource limits.
- Published assessed content is immutable in the MVP. Archive and replace it
  rather than editing history under existing attempts.
- The local Supabase stack is owned by the Supabase CLI. Docker Compose owns the
  Fastify API and, after ARC-WASM-001, private grader-controller/isolation test
  wiring; it must not start a competing standalone PostgreSQL service or be
  mistaken for the per-submission security boundary.
- No frontend technology is selected or implemented by this plan. Registration
  and login are specified and tested through a provider-neutral client contract
  and a headless local harness; actual screens remain a later client task.
- The future browser public-test Worker contract does not change that
  no-frontend decision and cannot award attempts or progress.

## Plan completion marker

The planning phase is complete when all files listed in this index and the
Romanian curriculum index exist, all relative links resolve, task IDs are
unique, and no implementation file exists outside the two plan roots. The four
explicitly requested root environment/ignore safety files above are allowed
exceptions and do not satisfy an implementation task.
