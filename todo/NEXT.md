# Next task

The next implementation task is:

**ARC-DOCKER-003 — Verify production image.**

Prerequisites verified: ARC-DOCKER-001 and ARC-DOCKER-002 are complete. The
development API path is runtime-verified, and the profile-gated foundation
checks are isolated, disposable, non-root, read-only, and networkless.

## Read first

1. `README.md`
2. `TASKS.md`
3. `STATUS.md`
4. `00-control/00-scope-and-non-goals.md`
5. `00-control/01-fixed-decisions.md`
6. `00-control/03-execution-protocol.md`
7. `02-architecture/02-environments-and-secrets.md`
8. `02-architecture/03-docker-compose.md`
9. `04-fastify/00-bootstrap-and-config.md`
10. `04-fastify/05-openapi-health-and-readiness.md`
11. `06-quality/00-testing-strategy.md`
12. `08-execution/00-roadmap.md`
13. `08-execution/01-dependency-map.md`
14. `08-execution/03-handoff-protocol.md`
15. `../Dockerfile`, `../compose.yaml`, `../.dockerignore`, and
    `../.env.example` (never a real `.env` file)
16. `../docs/implementation/ARC-DOCKER-001.md` and
    `../docs/implementation/ARC-DOCKER-002.md`

## Permitted scope

From a clean committed checkout, build and verify only the existing `runtime`
stage. Prove the image contains compiled production output and production
dependencies only; runs as a non-root UID; does not contain `.env`, source
maps, npm cache, test fixtures, or plan files; starts with a read-only
filesystem when Docker supports it; and handles `SIGTERM` so no liveness
request is accepted after shutdown begins.

Use only an ignored synthetic local runtime file for test configuration. Inspect
selected safe image/container fields and file names only—never image/container
environment lists or any real environment file. Keep every temporary container,
network, and filesystem mount scoped to an exact project/name, then remove it
without `-v` and verify cleanup.

Do not add an application feature, Supabase service, SMTP, Auth, readiness,
Python/WASM, source/CI system, browser/Chrome action, secret, hosted resource,
frontend, or deployment. Do not modify the accepted development/check paths
unless a completed production-image verification proves a narrow correction is
required.

## Required verification before completion

- Begin from a clean, committed working tree; use Node 24.18.0/npm 11.16.0.
- Build the runtime target without printing a real environment value; inspect
  the resulting image contents and selected configuration safely.
- Prove non-root execution and API liveness under a read-only filesystem with
  bounded temporary writable paths only if needed.
- Send ordinary `SIGTERM`, verify clean exit, and prove host liveness is not
  reachable afterward.
- Prove no excluded runtime contents: source maps, `.env`, npm cache, test
  fixtures, Docker socket/mount, or plan/documentation input.
- Run local and containerized foundation checks, `git diff --check`, and a
  focused secret/scope review.
- Create `docs/implementation/ARC-DOCKER-003.md` and synchronize the relevant
  checklist, registry, status, roadmap, scope guardrail, README, and this file
  only after all acceptance evidence passes.

QA-STRAT-001 follows ARC-DOCKER-003. Supabase, curriculum authoring, SMTP,
Chrome, Vercel, and all hosted/production tasks remain out of scope until their
own prerequisites and authority are satisfied.
