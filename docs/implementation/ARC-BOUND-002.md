# ARC-BOUND-002 — App/listener boundary acceptance

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: Implementation is authorized. This task accepts the
existing local Fastify app/listener split, adds only a focused static regression
guard, updates task evidence, and does not read `.env`, open a real listener,
or change external state.
Prerequisites/gate checked: G0, PLAN-004, FOUND-001, ARC-BOUND-001,
FAST-CONFIG-001, ARC-ENV-001, and FAST-BOOT-001 are complete.
ARC-BOUND-002 was the sole `next` task before work began.

## Scope

- Intended: prove and durably protect the existing one app-factory/one
  server-listener boundary with local source and synthetic-test evidence.
- Explicitly excluded: routes, plugins, liveness/readiness behavior, Supabase
  clients/adapters/database calls, Docker/Compose, Python/WASM, business
  modules, credentials, Chrome, SMTP, Vercel, and hosted state.

## Changed

- `apps/api/test/boundaries/verify-fixtures.mjs`: parses every production API
  TypeScript file with the installed TypeScript AST and rejects a second
  default Fastify factory, a second `buildApp`, a listener outside `server.ts`,
  an out-of-order readiness/listen sequence, a second/directly unguarded
  production startup call, a direct `startServer()` call outside
  `startProductionServer()`, an import/re-export/dynamic load of `server.ts`,
  an extra `process.exit`, or an attempt to attach the
  `dependencies`/`composition` boundary to Fastify, a request, or a reply.
- `docs/implementation/ARC-BOUND-002.md` and task trackers: record only the
  accepted evidence and advance the sole executable task to FAST-LIVE-001.

## Source and test inventory

| Concern                   | Current production evidence                                                                                                                 | Regression/dynamic evidence                                                                                                                                                                                                                                                                         |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| App factory               | `apps/api/src/app.ts` has the sole exported `buildApp({ config, dependencies }: BuildAppOptions)` and the sole `Fastify(...)` construction. | AST contract requires the exact readonly `config: ApiConfig` and `dependencies: ApiApplicationDependencies` inputs and keeps construction inside `buildApp`; `build-app.test.ts` injects requests without a socket.                                                                                 |
| Listener ownership        | `apps/api/src/app.ts` has no listener; `apps/api/src/server.ts` alone awaits `app.listen(...)`.                                             | AST contract rejects any other `listen` access/call; lifecycle tests use only fake `ready`/`listen` methods and never bind a port.                                                                                                                                                                  |
| Inert import/direct entry | `server.ts` constructs configuration/dependencies only in `startProductionServer()` and calls it only under top-level `import.meta.main`.   | AST confirms the sole startup invocation is inside that guard and catch-handled, and that the sole direct `startServer()` call remains inside `startProductionServer()`; importing the lifecycle module in tests does not create a listener.                                                        |
| Lifecycle safety          | `server.ts` awaits `app.ready()` before listening and is the sole direct `process.exit()` owner.                                            | AST fixes the source ordering/ownership; fake lifecycle tests prove fixed-message startup failure, both signals, one close, timeout handling, and server-only forced termination.                                                                                                                   |
| Composition boundary      | `BuildAppOptions` is immutable and the no-op composition remains typed/frozen. No Fastify request/instance decoration or bag exists.        | AST rejects assignment, `Object`/`Reflect` mutation, or Fastify decoration that passes `dependencies` or `composition` to `app`, `request`, or `reply`. A temporary local-only `app.context = dependencies` mutation failed the verifier with that exact rule and was reverted before final checks. |

The stage-specific source inventory also found no `@supabase/supabase-js`,
`createClient`, route registration, plugin registration, Fastify decoration, or
network-client construction in `apps/api/src`. Those absences are accepted for
this foundation stage but are not encoded as permanent bans: their authorized
future tasks may introduce narrow implementations while preserving the factory,
listener, and composition-leak invariants above.

The server module itself is likewise production-private: the guard rejects
static imports, re-exports, `import()`, and `require()` references that resolve
to `server.ts`, so an aliased `startServer` binding cannot create a second
startup path. A temporary `startServer as boot` import from `app.ts` failed the
verifier and was also reverted before final checks.

## Verification

- Target-runtime clean installation
  - Result: PASS.
  - Non-secret evidence: Node `24.18.0` and npm `11.16.0` ran
    `npm ci --ignore-scripts`, restoring 245 packages from the committed lock.
- `npm run format:check`
  - Result: PASS.
  - Non-secret evidence: Prettier accepted the complete configured source/test
    scope.
- `npm run lint`
  - Result: PASS.
  - Non-secret evidence: ESLint passed and dependency-cruiser scanned 11
    production modules and 15 dependencies with no violation.
- `npm run typecheck` and `npm run build`
  - Result: PASS.
  - Non-secret evidence: strict TypeScript completed without diagnostics.
- `npm test`
  - Result: PASS.
  - Non-secret evidence: Vitest ran 154 tests; the full boundary verifier
    passed 63 negative fixtures, four positive controls, the production graph,
    and the app/listener ownership contract.
- Source, diff, and secret-safety review
  - Result: PASS.
  - Non-secret evidence: the scoped source inventory found one Fastify
    construction, one `buildApp` definition, `await app.ready()` before the
    sole `await app.listen()`, and one direct `process.exit()` in `server.ts`.
    It found no foundation route/plugin/decoration/raw-client/network-client
    call. `git diff --check` passed. Only the verifier, this report, and task
    trackers are intended tracked changes; `.env` and all real environment
    files were neither read nor changed.

## External actions

NONE. No browser, account, credential, Supabase project, database, Docker
runtime, SMTP service, Vercel resource, or deployment state was accessed or
changed.

## Deviations/ADRs

- A focused acceptance audit found one real durability gap: behavior tests did
  not prevent a future second factory/listener or accidental Fastify exposure
  of the composition boundary. The existing boundary verifier now owns that
  AST-based regression guard.
- The initial guard was narrowed after review so it protects permanent
  invariants only. It deliberately does not globally forbid future routes,
  plugins, Fastify type imports, declaration merging, or Supabase adapters;
  those belong to their authorized later tasks.

## Risks/blockers

- No liveness/readiness endpoint or external dependency exists yet. FAST-LIVE-001
  owns the first dependency-free `GET /health/live` route and its inject test.
- Future composition-root work must keep passing narrow typed facades rather
  than decorating Fastify/request state with a client, repository, service, or
  generic dependency bag.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer,
TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
recorded. Test values are explicit non-secret fixtures. `.env` and every other
real local environment file were neither read nor changed.

## Next

FAST-LIVE-001 is the only unblocked next task. Its prerequisite app factory is
accepted, and it may add only the dependency-free liveness route, schema, test,
and task evidence before Docker/Compose or external work begins.
