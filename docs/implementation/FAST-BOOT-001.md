# FAST-BOOT-001 — App/server split

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: Implementation is authorized. This task changes only the
local Fastify construction/listening seam, focused synthetic tests, task
tracking, and local implementation evidence. It does not read `.env`, use a
credential, start a real listener, or change external state.
Prerequisites/gate checked: G0, PLAN-004, FOUND-001, ARC-BOUND-001,
FAST-CONFIG-001, and ARC-ENV-001 are complete. FAST-BOOT-001 was the sole
`next` task before work began.

## Scope

- Intended: introduce the one injected Fastify app factory, a typed no-op API
  composition boundary, the sole production listener entrypoint, and
  deterministic lifecycle tests.
- Explicitly excluded: routes, Fastify plugins/decorations, liveness/readiness,
  Supabase clients/adapters/database calls, Docker/Compose, Python/WASM,
  business modules, credentials, Chrome, SMTP, Vercel, and hosted state.

## Decisions/defaults used

- `buildApp({ config, dependencies }: BuildAppOptions)` is the only app
  factory. It accepts the existing immutable `ApiConfig` and a required typed
  composition boundary, but it never decorates Fastify or opens a socket.
- The factory applies only already-validated native transport settings: body,
  connection/request/handler/keep-alive timeouts, request-ID header, explicit
  `false` proxy trust, and Node's headers timeout. CORS, rate limiting,
  logging, Swagger, error handling, and routes remain with their owning later
  tasks.
- `bootstrap/composition-root.ts` constructs a frozen empty API composition
  boundary. No raw client, adapter, module, controller, resource, repository
  bag, service locator, or mutable request-global state exists yet.
- `server.ts` performs the only `listen` call after `await app.ready()`. Its
  import is inert; `startProductionServer()` runs only when the compiled module
  is the direct Node entrypoint.
- Startup and shutdown expose only fixed safe messages. On a close failure or
  configured shutdown deadline, only `server.ts` uses an injected termination
  capability; production maps it to non-zero `process.exit`. No app, route,
  plugin, composition dependency, or service receives that capability.

## Changed

- `apps/api/src/app.ts`: one listener-free `buildApp` Fastify factory with
  explicit configuration and dependency inputs.
- `apps/api/src/bootstrap/composition-root.ts`: typed, frozen no-op production
  composition boundary and dependency constructor.
- `apps/api/src/server.ts`: production configuration/dependency construction,
  ready-before-listen startup, fixed-message startup failure, signal-safe
  idempotent shutdown, bounded close, and direct-entry guard.
- `apps/api/test/support/create-test-api-config.ts`: synthetic injected
  configuration helper; it never reads or mutates `process.env`.
- `apps/api/test/app/build-app.test.ts`: `buildApp` plus `fastify.inject`
  evidence with no network listener.
- `apps/api/test/server/server-lifecycle.test.ts`: fake-only ready/listen,
  startup-redaction, signal, close-once, timeout, and forced-termination tests.

## Verification

- Target-runtime clean installation
  - Result: PASS.
  - Non-secret evidence: Node `24.18.0` and npm `11.16.0` ran
    `npm ci --ignore-scripts`, restoring 245 packages from the committed lock.
- `npm run format:check`
  - Result: PASS.
  - Non-secret evidence: Prettier accepted the complete source and test scope.
- `npm run lint`
  - Result: PASS.
  - Non-secret evidence: ESLint passed; dependency-cruiser scanned 11 source
    modules and 15 dependencies with no boundary violation.
- `npm run typecheck` and `npm run build`
  - Result: PASS.
  - Non-secret evidence: strict TypeScript completed without diagnostics and
    emitted only ignored local API artifacts.
- `npm test`
  - Result: PASS.
  - Non-secret evidence: Vitest ran 154 focused tests. The boundary verifier
    also passed all 63 negative fixtures and four positive controls.
- Scope and secret-safety review
  - Result: PASS.
  - Non-secret evidence: the app factory contains no `listen`, route, plugin,
    decoration, client, or network call; only `server.ts` has the production
    listener/termination path. Tests use fake lifecycle runtime dependencies
    and no real port. Errors, reports, and test assertions contain only fixed
    messages or explicit synthetic values. `.env` and all real local
    environment files were neither read nor changed.

## External actions

NONE. No browser, account, credential, Supabase project, database, Docker
runtime, SMTP service, Vercel resource, or deployment state was accessed or
changed.

## Deviations/ADRs

- A lifecycle audit found that merely setting a non-zero exit code would leave
  a process alive if Fastify close never settled. The server-only, injectable
  termination capability now handles that bounded failure path, with fake-only
  tests for ordinary shutdown and failed startup cleanup. This implements the
  existing bootstrap requirement and does not change an architectural decision.

## Risks/blockers

- The composition root has no resources to dispose yet. FAST-PLUGIN-002 and
  later module tasks must extend it with narrow facades and reverse-order
  disposal evidence rather than a global dependency bag.
- No liveness/readiness route, CORS, rate limit, logging, Auth, or external
  adapter exists; their later owners remain required before G1 or a real API
  release.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer,
TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
recorded. Test values are explicit non-secret fixtures. `.env` and every other
real local environment file were neither read nor changed.

## Next

ARC-BOUND-002 is the only unblocked next task. It can accept the one factory/
one listener boundary through local source and test evidence, making only a
minimal correction if that audit finds a real gap.
