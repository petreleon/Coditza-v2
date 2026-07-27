# Next task

The next implementation task is:

**ARC-DOCKER-001 — Define the local API Compose service.**

Prerequisites already verified: G0, PLAN-004, FOUND-001, FAST-CONFIG-001,
ARC-ENV-001, FAST-BOOT-001, ARC-BOUND-002, and FAST-LIVE-001 are complete.
This is the sole task allowed to create Docker/Compose artifacts now.

Read first:

1. `README.md`
2. `TASKS.md`
3. `STATUS.md`
4. `00-control/00-scope-and-non-goals.md`
5. `00-control/01-fixed-decisions.md`
6. `00-control/02-open-decisions.md`
7. `00-control/03-execution-protocol.md`
8. `02-architecture/02-environments-and-secrets.md`
9. `02-architecture/03-docker-compose.md`
10. `04-fastify/00-bootstrap-and-config.md`
11. `04-fastify/05-openapi-health-and-readiness.md`
12. `06-quality/00-testing-strategy.md`
13. `08-execution/00-roadmap.md`
14. `08-execution/01-dependency-map.md`
15. `08-execution/03-handoff-protocol.md`
16. `../docs/adr/0003-node-fastify-toolchain-baseline.md`
17. `../docs/implementation/FAST-LIVE-001.md`
18. `../.dockerignore`
19. `../.env.example` (never read a real `.env` file)

Implement only the local Compose API path. Preserve the accepted app/listener
split and `GET /health/live`; do not create a second Supabase stack or use an
external platform.

## Required work

- Create the root multi-stage `Dockerfile` and root `compose.yaml` for the API
  development service. Use the reviewed pinned Node 24 Debian-slim base/image
  digest required by the Docker plan; do not use floating `node`, `lts`, or
  `latest` tags.
- Review and, if needed, tighten the root `.dockerignore` so `.env`, `.git`,
  test output, local Supabase state, and `todo/` cannot enter the image. Keep
  explicit exclusions requested by the user and do not copy or reveal real
  environment contents.
- Configure one non-privileged API service only: source reload without masking
  container-installed `node_modules`, `HOST=0.0.0.0`, only the configured API
  port, ignored local runtime environment loading, `init`, an adequate graceful
  stop period, and an exec-form Node foreground process. Do not mount the
  Docker socket.
- Use `GET /health/live` as the image health check through Node's built-in
  `fetch`; do not add `curl`/`wget` merely for health.
- Validate configuration without printing secrets, build/start the local image,
  prove host liveness, and prove safe SIGTERM/Compose shutdown. Record any
  platform-specific CLI-Supabase connectivity limitation without weakening
  loopback-only security; no Supabase connectivity work belongs here.
- Create `docs/implementation/ARC-DOCKER-001.md`, then synchronize the Compose
  checklist, task registry, status, roadmap, scope guardrail, README, and this
  file only after all acceptance evidence passes.

## Required verification

- Use Node `24.18.0` and npm `11.16.0` for clean local package checks before
  the container path.
- Use a Docker/Compose configuration check that is placeholder-safe and does
  not print a real `.env` value. Verify the Docker build context contains none
  of the excluded inputs.
- Build the development API image, start only the API service, and prove host
  `GET /health/live` reaches `200` without Docker owning/stopping any Supabase
  state. Exercise the configured graceful stop and inspect the container user,
  entry process, health, mounts, published ports, and privilege/socket surface.
- Run `git diff --check`, source/secret review, `npm run format:check`,
  `npm run lint`, `npm run typecheck`, `npm test`, and `npm run build`.

Do not add `postgres`, `auth`, `rest`, a second Supabase stack, root Compose
SMTP, a Supabase client/adapter, readiness, Auth, CORS, rate limiting,
OpenAPI, Python/WASM, business modules, credentials, Chrome actions, Vercel
resources, hosted state, or a frontend. Do not read, print, commit, or modify a
real `.env` file.
