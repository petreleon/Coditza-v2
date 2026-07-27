# Next task

The next implementation task is:

**ARC-BOUND-002 — Accept the app/listener boundary.**

Prerequisites already verified: G0, PLAN-004, FOUND-001, ARC-BOUND-001,
FAST-CONFIG-001, ARC-ENV-001, and FAST-BOOT-001 are complete. This is the sole
task allowed to change implementation files now.

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
10. `02-architecture/04-data-flow-and-security.md`
11. `04-fastify/00-bootstrap-and-config.md`
12. `06-quality/00-testing-strategy.md`
13. `08-execution/00-roadmap.md`
14. `08-execution/01-dependency-map.md`
15. `08-execution/03-handoff-protocol.md`
16. `../docs/adr/0001-modular-monolith-and-ports-adapters.md`
17. `../docs/adr/0003-node-fastify-toolchain-baseline.md`
18. `../docs/adr/0004-configuration-ownership-and-phase-one-api-parser.md`
19. `../docs/implementation/ARC-BOUND-001.md`
20. `../docs/implementation/FAST-CONFIG-001.md`
21. `../docs/implementation/ARC-ENV-001.md`
22. `../docs/implementation/FAST-BOOT-001.md`
23. `../docs/implementation/architecture-boundary-contract.md`

Perform a local acceptance of the existing app/listener split. Do not replace it
with a second bootstrap design.

## Required work

- Build a traceable source/test inventory proving there is exactly one
  production `buildApp({ config, dependencies }: BuildAppOptions)` factory,
  `app.ts` contains no `listen`, and `server.ts` is the only production file
  that listens. Imports must remain inert unless the compiled server is the
  direct Node entrypoint.
- Prove the app factory accepts explicit immutable configuration and a typed
  composition boundary, never exposes that boundary via a Fastify decoration or
  request property, and never constructs a raw client, repository bag, service
  locator, route, plugin, or external resource.
- Recheck ready-before-listen, safe fixed-message startup failure, both signal
  paths, close-once behavior, and bounded server-only termination. The current
  no-op composition has no resource to close; do not introduce a placeholder
  resource merely to simulate later work.
- Reuse the existing synthetic `buildApp`/`fastify.inject` and fake lifecycle
  tests. Add only a focused regression test if the audit finds a concrete gap;
  never bind a real port when a fake lifecycle surface proves the requirement.
- Create `docs/implementation/ARC-BOUND-002.md`, then synchronize the task
  registry, status, roadmap, and this file only after all acceptance evidence
  passes.

## Required verification

- Use Node `24.18.0` and npm `11.16.0` for a clean `npm ci --ignore-scripts`,
  `npm run format:check`, `npm run lint`, `npm run typecheck`, `npm test`, and
  `npm run build`.
- Run `git diff --check`, the full dependency-boundary verifier, and a scoped
  source/secret review of intended tracked files. Include a source inventory of
  `listen`, `buildApp`, `process.exit`, Fastify decoration, client, route, and
  plugin calls.

Do not add routes, Fastify plugins, liveness/readiness behavior, Supabase
clients/adapters, Docker/Compose, Python/WASM runtime/controller, real business
modules, credentials, Chrome actions, SMTP configuration, Vercel resources,
hosted state, or a frontend. Do not create or alter a production, staging, or
development platform configuration.
