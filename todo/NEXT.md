# Next task

The next implementation task is:

**FAST-LIVE-001 — Implement foundation liveness.**

Prerequisites already verified: G0, PLAN-004, FOUND-001, ARC-BOUND-001,
FAST-CONFIG-001, ARC-ENV-001, FAST-BOOT-001, and ARC-BOUND-002 are complete.
This is the sole task allowed to change implementation files now.

Read first:

1. `README.md`
2. `TASKS.md`
3. `STATUS.md`
4. `00-control/00-scope-and-non-goals.md`
5. `00-control/01-fixed-decisions.md`
6. `00-control/02-open-decisions.md`
7. `00-control/03-execution-protocol.md`
8. `02-architecture/00-system-boundaries.md`
9. `02-architecture/02-environments-and-secrets.md`
10. `04-fastify/00-bootstrap-and-config.md`
11. `04-fastify/05-openapi-health-and-readiness.md`
12. `06-quality/00-testing-strategy.md`
13. `08-execution/00-roadmap.md`
14. `08-execution/01-dependency-map.md`
15. `08-execution/03-handoff-protocol.md`
16. `../docs/adr/0001-modular-monolith-and-ports-adapters.md`
17. `../docs/adr/0003-node-fastify-toolchain-baseline.md`
18. `../docs/adr/0004-configuration-ownership-and-phase-one-api-parser.md`
19. `../docs/implementation/FAST-BOOT-001.md`
20. `../docs/implementation/ARC-BOUND-002.md`
21. `../docs/implementation/architecture-boundary-contract.md`

Implement only the first local, dependency-free liveness endpoint. Preserve the
accepted `buildApp`/`server.ts` split; do not introduce a second bootstrap or a
real listener in a test.

## Required work

- Register exactly `GET /health/live` in `buildApp` with a closed response
  schema and the exact successful body `{ "status": "ok" }`.
- Return `200` solely when the Fastify process can serve this route. It must not
  read configuration after startup, call Supabase, use a network client, query a
  database, inspect a secret, authenticate a caller, or expose build/version,
  URL, project, dependency, or error details.
- Add a focused `fastify.inject` test that proves the exact `200` response and
  proves the route does not cause the Fastify server to listen. Keep existing
  factory/lifecycle tests and the AST ownership contract green.
- Do not add a rate-limit plugin in this task. The health specification's
  separate limiter remains owned by FAST-PLUGIN-001; record a conflict rather
  than selecting/installing a plugin early.
- Create `docs/implementation/FAST-LIVE-001.md`, then synchronize the health
  checklist, task registry, status, roadmap, scope guardrail, and this file
  only after all acceptance evidence passes.

## Required verification

- Use Node `24.18.0` and npm `11.16.0` for a clean `npm ci --ignore-scripts`,
  `npm run format:check`, `npm run lint`, `npm run typecheck`, `npm test`, and
  `npm run build`.
- Run `git diff --check`, the full dependency-boundary verifier, and a scoped
  source/secret review of intended tracked files. Confirm the liveness route is
  the only new route, has no external dependency edge, and does not weaken the
  app/listener or composition-leak contracts.

Do not add readiness behavior, Fastify plugins, Auth, CORS, logging, OpenAPI,
rate limiting, Supabase clients/adapters, Docker/Compose, Python/WASM runtime/
controller, real business modules, credentials, Chrome actions, SMTP
configuration, Vercel resources, hosted state, or a frontend. Do not create or
alter a production, staging, or development platform configuration.
