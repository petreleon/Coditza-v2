# Next task

The next implementation task is:

**FAST-BOOT-001 — App/server split.**

Prerequisites already verified: G0, PLAN-004, FOUND-001, ARC-BOUND-001,
FAST-CONFIG-001, and ARC-ENV-001 are complete. This is the sole task allowed
to change implementation files now.

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
22. `../docs/implementation/architecture-boundary-contract.md`

Implement only a minimal canonical Fastify factory/server split using the
existing injected `ApiConfig` contract. Do not add endpoint behavior.

## Required work

- Define exactly one `buildApp({ config, dependencies }: BuildAppOptions)` app
  factory. Both properties are required; it creates and returns a Fastify
  instance but never calls `listen`.
- Define the minimum typed dependency/composition contract needed for this
  foundation. The production `server.ts` is the only network entry point and
  constructs configuration/dependencies explicitly; tests pass explicit fakes.
  Do not make a service locator, repository bag, raw-client decoration, or
  mutable request-global state.
- Keep `bootstrap/composition-root.ts` as the sole future production wiring
  point. At this foundation stage it may return a typed empty/no-op composition
  boundary only; it must not construct a Supabase client, business module,
  controller, or external dependency.
- Make the server wait for `app.ready()` before listen, fail startup without
  exposing configuration, and handle `SIGTERM`/`SIGINT` by closing Fastify
  exactly once within the injected shutdown timeout. Keep `process.exit()` out
  of services/routes/plugins.
- Add focused tests using `buildApp` and `fastify.inject`; use fake injected
  dependencies and never mutate `process.env`. Test no listener from the app
  factory, ready-before-listen ordering, startup error safety, and idempotent
  signal shutdown without opening a real network port where a fake is enough.
- Create `docs/implementation/FAST-BOOT-001.md`, then synchronize the tracker
  only after all acceptance evidence passes.

## Required verification

- Use Node `24.18.0` and npm `11.16.0` for a clean `npm ci --ignore-scripts`,
  `npm run format:check`, `npm run lint`, `npm run typecheck`, `npm test`, and
  `npm run build`.
- Run `git diff --check`, the full dependency-boundary verifier, and a scoped
  secret/scope review of intended tracked files.

Do not add routes, Fastify plugins, health behavior, Supabase client/adapters,
Docker/Compose, Python/WASM runtime/controller, real business module,
credential, Chrome action, SMTP configuration, Vercel resource, hosted state,
or a frontend. Do not create or alter a production, staging, or development
platform configuration.
