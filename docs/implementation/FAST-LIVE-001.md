# FAST-LIVE-001 — Foundation liveness acceptance

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: The user explicitly authorized implementation. This is
the sole local task after ARC-BOUND-002 and changes no external state.
Prerequisites/gate checked: G0, PLAN-004, FOUND-001, ARC-BOUND-001,
FAST-CONFIG-001, ARC-ENV-001, FAST-BOOT-001, and ARC-BOUND-002 are complete.
FAST-LIVE-001 was the sole `next` task before work began.
Decisions/defaults used:

- The canonical injected `buildApp` factory remains the only route owner; the
  canonical `server.ts` remains the only real-listener owner.
- Liveness has one closed TypeBox response schema with the literal successful
  body `{ "status": "ok" }` and no request schema, Auth, configuration read,
  external call, or dependency facade.
- Fastify normally exposes a `HEAD` sibling for a `GET` route. The route
  explicitly sets `exposeHeadRoute: false` so this task registers exactly the
  required `GET /health/live` endpoint.

## Scope

- Intended: add the first dependency-free liveness route, its closed response
  schema, a listener-free inject test, and objective local evidence.
- Explicitly excluded: readiness, Fastify plugins, rate limiting, Auth, CORS,
  logging, OpenAPI, Supabase clients/adapters/database access, Docker/Compose,
  Python/WASM, business modules, credentials, Chrome, SMTP, Vercel, and hosted
  state.

## Changed

- `apps/api/src/app.ts`: registers the sole foundation route
  `GET /health/live` in `buildApp`, bound to a closed TypeBox response schema;
  its handler returns only `{ status: "ok" }` and disables Fastify's implicit
  `HEAD` sibling.
- `apps/api/test/app/build-app.test.ts`: adds a `fastify.inject` regression
  test for the exact `200` body, no listener, no injected Auth material, no
  dependency access, and no implicit `HEAD` endpoint.
- `docs/implementation/FAST-LIVE-001.md` and task trackers: record accepted
  evidence and advance the sole executable task to ARC-DOCKER-001.

## Source and test inventory

| Concern | Production evidence | Regression evidence |
| --- | --- | --- |
| Route ownership | `app.ts` contains the only new route registration: `app.get("/health/live", ...)` inside the accepted `buildApp` factory. | The full AST app/listener ownership contract remains green. |
| Minimal response | The `200` response is a closed object with one literal `status: "ok"` property; no version, URL, project, dependency, or error detail is present. | `fastify.inject` asserts exact `200` JSON `{ status: "ok" }`. |
| No listener | The factory still has no `listen` call. | The focused test checks `app.server.listening === false` before and after injection. |
| No external/dependency access | The handler is a static value and does not use `config` or `dependencies`; no Supabase or network import/call is present. | The test passes a proxy that throws on every dependency property read, then receives the successful liveness response. |
| Exact method surface | `exposeHeadRoute: false` prevents Fastify's default auto-created `HEAD` route. | A `HEAD /health/live` injection receives `404`. |

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
  - Non-secret evidence: ESLint passed and dependency-cruiser scanned 12
    production modules and 17 dependencies with no violation.
- `npm run typecheck` and `npm run build`
  - Result: PASS.
  - Non-secret evidence: strict TypeScript completed without diagnostics.
- `npm test`
  - Result: PASS.
  - Non-secret evidence: Vitest ran 155 tests; the full boundary verifier
    passed 63 negative fixtures, four positive controls, the production graph,
    and the app/listener ownership contract.
- Focused liveness injection
  - Result: PASS.
  - Non-secret evidence: `GET /health/live` returned exact closed JSON with
    status `200` while the Fastify server stayed unlistened; implicit `HEAD`
    returned `404`.
- Source, diff, and secret-safety review
  - Result: PASS.
  - Non-secret evidence: the scoped source inventory found exactly one new
    route registration, no Supabase import/client, no network or database call,
    no `process.env` access, no Auth input, and no Fastify decoration. The
    full boundary verifier passed and `git diff --check` passed. Only this
    route/test, report, and synchronized task evidence are intended changes;
    `.env` and every real environment file were neither read nor changed.

## External actions

NONE. No browser, account, credential, Supabase project, database, Docker
runtime, SMTP service, Vercel resource, or deployment state was accessed or
changed.

## Deviations/ADRs

- The health specification calls for a minimal separate limiter, while this
  task explicitly prohibits installing or selecting a Fastify plugin. The
  limiter is deliberately deferred to FAST-PLUGIN-001; no plugin or rate-limit
  policy was chosen early.

## Risks/blockers

- The route is liveness only. It intentionally does not answer readiness or
  test Supabase, and it remains unauthenticated/minimal for infrastructure
  probing.
- The Compose image health check is not implemented here; ARC-DOCKER-001 owns
  using this endpoint with Node's built-in `fetch` inside the image.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer,
TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
recorded. Test values are explicit non-secret fixtures. `.env` and every other
real local environment file were neither read nor changed.

## Next

ARC-DOCKER-001 is the only unblocked next task. The accepted liveness endpoint
now exists for its local Compose service health check; it may create only the
reviewed Docker/Compose artifacts and local verification evidence.
