# Next task

The next implementation task is:

**ARC-DOCKER-002 — Define foundation test execution.**

Prerequisite verified: ARC-DOCKER-001 is complete. Its report records a
non-root development image, safe ignored build context, host liveness, source
reload, graceful shutdown, and exact-project cleanup using synthetic local
configuration.

## Read first

1. `README.md`
2. `TASKS.md`
3. `STATUS.md`
4. `00-control/00-scope-and-non-goals.md`
5. `00-control/01-fixed-decisions.md`
6. `00-control/03-execution-protocol.md`
7. `02-architecture/03-docker-compose.md`
8. `04-fastify/00-bootstrap-and-config.md`
9. `06-quality/00-testing-strategy.md`
10. `08-execution/00-roadmap.md`
11. `08-execution/01-dependency-map.md`
12. `08-execution/03-handoff-protocol.md`
13. `../docs/implementation/ARC-DOCKER-001.md`
14. `../Dockerfile`, `../compose.yaml`, `../.dockerignore`, and
    `../.env.example` (never a real `.env` file)

## Permitted scope

Define one disposable, containerized foundation-check path or documented
equivalent for the existing API workspace. It must run the existing
`format:check`, `lint`, `typecheck`, `test`, and `build` commands with the
project's pinned dependencies, preserve each command's exit code, and leave no
test container or volume behind.

The path must not rely on a developer-global npm install, publish a service
port, start the API watcher, mount the Docker socket, use privileged mode, or
read, print, create, commit, or modify a real `.env` file. Use an ignored
synthetic runtime file or the safe placeholder configuration only where Compose
requires configuration resolution.

Do not add Supabase services, SMTP, Auth, readiness, application modules,
browser/Chrome work, Python/WASM runtime work, secrets, external state, a
frontend, or hosted actions. Do not change the accepted ARC-DOCKER-001 runtime
service unless a completed verification proves a narrow correction is required.

## Required verification before completion

- Validate Compose without exposing a real environment value.
- Run every foundation check through the documented container path and prove its
  exit status is preserved.
- Confirm disposable containers use `--rm` or equivalent cleanup and leave no
  project-scoped containers, networks, or volumes after success and a deliberate
  nonzero command check.
- Run the normal local `npm run format:check`, `npm run lint`,
  `npm run typecheck`, `npm test`, and `npm run build` using Node 24.18.0 and
  npm 11.16.0.
- Review build context, diffs, secret safety, and `git diff --check`.
- Create `docs/implementation/ARC-DOCKER-002.md` and synchronize only the
  relevant Compose checklist, task registry, status, roadmap, scope guardrail,
  README, and this file after every acceptance check passes.

ARC-DOCKER-003, Supabase, curriculum authoring, SMTP, Chrome, Vercel, and all
hosted/production tasks remain out of scope until their own prerequisites and
authority are satisfied.
