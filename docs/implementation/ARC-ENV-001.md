# ARC-ENV-001 — Accept API configuration and environment separation

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: Implementation is authorized. This task audited and
minimally hardened the existing local API configuration parser, its tests, and
its task documentation. It did not read `.env`, use a credential, construct
Fastify/Supabase/Docker/Python infrastructure, use Chrome, or change hosted
state.
Prerequisites/gate checked: G0, PLAN-004, FOUND-001, ARC-BOUND-001, and
FAST-CONFIG-001 are complete. ARC-ENV-001 was the sole `next` task before work
began.

## Scope

- Intended: accept one existing TypeBox API configuration contract through a
  complete variable inventory, redaction/separation review, focused security
  corrections, and clean local evidence.
- Explicitly excluded: another configuration schema/parser, Fastify
  construction/routes/listening, Supabase client/adapter/database calls,
  Docker/Compose, Python controller/runtime, credentials, Chrome, SMTP,
  Vercel, and any hosted resource.

## Inventory: API-owned configuration

Every listed variable maps to the one closed `ConfigSchema`, injected parser,
deeply frozen output, and a focused test in
`apps/api/test/config/parse-api-config.test.ts`. `SCHEMA_PATH_TO_VARIABLE`
contains the same 33 API-owned inputs for safe TypeBox diagnostics.

| Variable | Immutable output | Validation and focused evidence |
| --- | --- | --- |
| `NODE_ENV` | `environment.nodeEnv` | required enum; approved-pair and invalid-enum tests |
| `APP_ENV` | `environment.appEnv` | required enum; approved-pair and invalid-enum tests |
| `HOST` | `server.host` | required trimmed text; missing and isolated invalid-host tests |
| `PORT` | `server.port` | local default, hosted requirement, strict integer and `1`–`65535` bounds |
| `API_PREFIX` | `server.apiPrefix` | required literal `/api/v1`; invalid-prefix tests |
| `LOG_LEVEL` | `server.logLevel` | default `info`; supported/invalid Pino-level tests |
| `CORS_ORIGINS` | `cors.origins` | required exact-origin list; normalization, explicit-port, duplicate, wildcard, HTTPS-hosted, empty-hosted, and loopback tests |
| `TRUST_PROXY` | `server.trustProxy` | default and only accepted value `false`; strict/fail-closed tests |
| `BODY_LIMIT_BYTES` | `limits.bodyLimitBytes` | documented default and positive-integer tests |
| `RATE_LIMIT_MAX` | `limits.rateLimit.max` | documented default and positive-integer tests |
| `RATE_LIMIT_WINDOW_MS` | `limits.rateLimit.windowMs` | documented default and positive-integer tests |
| `ATTEMPT_RATE_LIMIT_MAX` | `limits.rateLimit.attemptMax` | documented default and positive-integer tests |
| `ADMIN_RATE_LIMIT_MAX` | `limits.rateLimit.adminMax` | documented default and positive-integer tests |
| `CONNECTION_TIMEOUT_MS` | `limits.timeouts.connectionMs` | documented default and inclusive boundary tests |
| `REQUEST_RECEIVE_TIMEOUT_MS` | `limits.timeouts.requestReceiveMs` | documented default and inclusive boundary tests |
| `DEPENDENCY_TIMEOUT_MS` | `limits.timeouts.dependencyMs` | documented default and inclusive boundary tests |
| `HANDLER_TIMEOUT_MS` | `limits.timeouts.handlerMs` | documented default and inclusive boundary tests |
| `KEEP_ALIVE_TIMEOUT_MS` | `limits.timeouts.keepAliveMs` | default, effective `1000`–`119999` bounds, and relation tests |
| `HEADERS_TIMEOUT_MS` | `limits.timeouts.headersMs` | default, effective `1001`–`120000` bounds, and strict-greater relation tests |
| `READINESS_TIMEOUT_MS` | `limits.timeouts.readinessMs` | documented default and inclusive boundary tests |
| `SHUTDOWN_TIMEOUT_MS` | `limits.timeouts.shutdownMs` | documented default and inclusive boundary tests |
| `SWAGGER_UI_ENABLED` | `server.swaggerUiEnabled` | strict boolean; local/hosted defaults and hosted fail-closed tests |
| `SUPABASE_URL` | `supabase.url` | independent endpoint parsing, malformed-form, HTTPS-hosted, and mapping tests |
| `SUPABASE_PROJECT_REF` | `supabase.projectRef` | local/hosted relation and standard-ref mapping tests |
| `SUPABASE_PUBLISHABLE_KEY` | `supabase.publishableKey` | current opaque prefix, wrong-kind/legacy rejection, and redaction tests |
| `SUPABASE_SECRET_KEY` | `supabase.secretKey` | current opaque prefix, wrong-kind/legacy rejection, and redaction tests |
| `SUPABASE_JWT_ISSUER` | `supabase.jwtIssuer` | independent canonical `/auth/v1` parsing, HTTPS-hosted, and mapping tests |
| `SUPABASE_JWT_AUDIENCE` | `supabase.jwtAudience` | exact `authenticated` audience and rejection test |
| `CURSOR_HMAC_SECRET` | `cursor.hmacSecret` | required canonical unpadded base64url 32-byte round-trip and redaction tests |
| `REQUEST_ID_HEADER` | `server.requestIdHeader` | default lower-case header and allowed/rejected syntax tests |
| `PYTHON_GRADER_ENABLED` | `pythonGrader.enabled` | strict default false and pre-G-WASM fail-closed test |
| `PYTHON_GRADER_CONCURRENCY` | `pythonGrader.concurrency` | default and inclusive `1`–`8` tests |
| `PYTHON_GRADER_QUEUE_LIMIT` | `pythonGrader.queueLimit` | default and inclusive `1`–`10000` tests |

## Acceptance findings and corrections

- The parser keeps `SUPABASE_URL` and `SUPABASE_JWT_ISSUER` as separate
  normalized inputs; local tests prove they may intentionally differ.
- Hosted CORS is now HTTPS-only. It preserves an explicitly supplied port,
  including a default port, while semantic duplicate detection still rejects an
  explicit-default and omitted-default pair.
- Production loopback detection now rejects canonical DNS-root variants such as
  `localhost.`, subdomains ending in `.localhost.`, IPv4 loopback, IPv6
  loopback, and IPv4-mapped IPv6 loopback representations.
- The acceptance suite adds isolated host validation, the hosted Swagger
  default, a non-canonical 43-character base64url cursor case, controller-only
  sandbox-binding input, and redaction of valid sensitive fixture values when
  an unrelated field fails.
- `TRUST_PROXY`, hosted Swagger, and Python grader enablement remain
  deliberately fail-closed. No parser setting constructs a proxy, Swagger UI,
  or sandbox capability.

## Controller separation

The API parser ignores and does not expose the controller-only runtime
manifest, launcher profile, claim batch, poll interval, lease, retry limit,
sandbox binding, and `ALLOW_HOSTED_TEST_TARGET`. Their parsing and any
secret-backed launcher binding remain private-controller work.

## Deferred controls

The following are intentionally **not** claimed by this local acceptance task:

- the protected local/test-to-hosted target override and known remote-target
  guard;
- real development/production target distinctness;
- reviewed custom-domain mapping;
- host/Compose URL-versus-issuer connectivity proof; and
- readiness logging that safely identifies a target.

Those controls require later runtime/deployment prerequisites and are owned by
ARC-ENV-002. This parser therefore never treats a local injected record as
proof that a remote target is safe to contact.

## Verification

- `npm run format:check`, `npm run lint`, and `npm run typecheck`
  - Result: PASS under Node `24.18.0` and npm `11.16.0`.
  - Non-secret evidence: formatting passed; ESLint passed; dependency-cruiser
    scanned 10 production modules/12 dependencies with no boundary violation;
    strict TypeScript completed without diagnostics.
- `npm test`
  - Result: PASS.
  - Non-secret evidence: Vitest ran 147 configuration tests. The full boundary
    verifier also passed all 63 negative fixtures and four positive controls.
- Scope and secret-safety review
  - Result: PASS.
  - Non-secret evidence: source contains only the explicit `process.env`
    wrapper; no dotenv, Fastify construction, Supabase SDK/client, network
    call, or controller-only configuration parser exists. Error, stack, JSON,
    and inspection tests contain no supplied fixture value. `.env` and other
    real local environment files were neither read nor changed.

## External actions

NONE. No provider, browser, account, credential, database, Docker runtime, or
deployment state was accessed or changed.

## Deviations

- Strict TypeScript caught an unchecked regular-expression capture while the
  IPv4-mapped IPv6 loopback guard was being hardened. The parser now checks the
  capture before parsing it; the final clean-install typecheck, build, and test
  suite all pass. No behavior was weakened to resolve the diagnostic.

## Risks/blockers

- ARC-ENV-002 remains necessary before any integration test can be permitted to
  target a non-local Supabase endpoint.
- A reviewed proxy topology, recorded hosted API-only release mechanism,
  completed G-WASM evidence, and private controller configuration are required
  before their corresponding settings can be enabled.

## Next

FAST-BOOT-001 is the next task. It may consume this immutable injected
configuration contract to introduce the canonical app/server split, but it may
not add routes, Supabase adapters, Docker, Python, credentials, or hosted
state.
