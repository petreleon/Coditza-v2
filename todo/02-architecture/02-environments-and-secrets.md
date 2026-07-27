# Environments and secrets

## Environments

| Environment | Supabase | API runtime | Data rule |
| --- | --- | --- | --- |
| Local | Supabase CLI Docker stack | Host or Docker Compose | Disposable seed/test data |
| Development | Hosted `Coditza-dev` project | Developer-selected host | Synthetic development/test data only |
| Staging | Separate hosted project only if DEC-027 is accepted | Production-like container host | Synthetic test data only |
| Production | Separate hosted project | Approved container host | Real user data |

Never point local automated tests at development, staging, or production.

## Planned environment variables

| Name | Secret? | Type/default | Purpose |
| --- | ---: | --- | --- |
| `NODE_ENV` | No | `development\|test\|production` | Node/library mode |
| `APP_ENV` | No | `local\|development\|staging\|production` | exact data/deploy boundary |
| `HOST` | No | host string; local `127.0.0.1`, container `0.0.0.0` | bind host |
| `PORT` | No | integer 1–65535; local default `3000` | listen port |
| `API_PREFIX` | No | exactly `/api/v1` in MVP | route/OpenAPI base |
| `LOG_LEVEL` | No | validated Pino level; default `info` | log threshold |
| `CORS_ORIGINS` | No | comma-separated exact origins; empty only for an explicitly recorded API-only release mode | CORS allowlist |
| `TRUST_PROXY` | No | `false` or reviewed hop/address policy; default `false` | proxy trust |
| `BODY_LIMIT_BYTES` | No | positive integer; default `1048576` | global body ceiling |
| `RATE_LIMIT_MAX` | No | positive integer; default `100` | global requests/window |
| `RATE_LIMIT_WINDOW_MS` | No | positive integer; default `60000` | global rate window |
| `ATTEMPT_RATE_LIMIT_MAX` | No | positive integer; default `20` | attempt mutations/window |
| `ADMIN_RATE_LIMIT_MAX` | No | positive integer; default `30` | admin mutations/window |
| `CONNECTION_TIMEOUT_MS` | No | integer 1000–60000; default `10000` | incomplete socket bound |
| `REQUEST_RECEIVE_TIMEOUT_MS` | No | integer 1000–120000; default `30000` | request-body receive bound |
| `DEPENDENCY_TIMEOUT_MS` | No | integer 100–120000; default `10000` | each Supabase operation bound |
| `HANDLER_TIMEOUT_MS` | No | integer 1000–120000; default `15000` | total route-operation deadline |
| `KEEP_ALIVE_TIMEOUT_MS` | No | integer 1000–119999; default `65000` | idle keep-alive bound; must remain below headers timeout |
| `HEADERS_TIMEOUT_MS` | No | integer 1001–120000 and greater than keep-alive; default `66000` | header receive bound |
| `READINESS_TIMEOUT_MS` | No | integer 100–10000; default `2000` | dependency probe bound |
| `SHUTDOWN_TIMEOUT_MS` | No | integer 1000–60000; default `10000` | graceful stop bound |
| `SWAGGER_UI_ENABLED` | No | strict boolean; true only local by default | interactive OpenAPI UI exposure |
| `SUPABASE_URL` | No | absolute URL; HTTPS in every hosted environment, HTTP allowed only for local CLI | network endpoint used by the running API |
| `SUPABASE_PROJECT_REF` | No | `local` or exact hosted project reference | target/evidence guard |
| `SUPABASE_PUBLISHABLE_KEY` | Treat carefully | current publishable-key format | stateless token verifier |
| `SUPABASE_SECRET_KEY` | Yes | current secret-key format; required | server domain access |
| `SUPABASE_JWT_ISSUER` | No | exact absolute canonical issuer URL; HTTPS hosted, HTTP allowed only local | token `iss` check |
| `SUPABASE_JWT_AUDIENCE` | No | exact accepted audience; record from current project guidance | token `aud` check |
| `CURSOR_HMAC_SECRET` | Yes | base64url encoding of exactly 32 random bytes | signs versioned cursors |
| `REQUEST_ID_HEADER` | No | lower-case header; default `x-request-id` | trusted request-ID policy |
| `PYTHON_GRADER_ENABLED` | No | strict boolean; false until G-WASM | fail-closed feature/publication gate |
| `PYTHON_WASM_RUNTIME_MANIFEST` | No | absolute read-only file path | exact verified runtime lock manifest |
| `PYTHON_SANDBOX_LAUNCHER_PROFILE` | No | reviewed exact deployment mapping ID | selects one approved narrow outer-sandbox adapter, never a command |
| `PYTHON_GRADER_CONCURRENCY` | No | integer 1–8; default `2` | controller-wide active sandbox ceiling |
| `PYTHON_GRADER_CLAIM_BATCH_SIZE` | No | integer 1–8, at most concurrency; default `2` | bounded database claim |
| `PYTHON_GRADER_POLL_INTERVAL_MS` | No | integer 250–60000; default `1000` | idle queue polling |
| `PYTHON_GRADER_LEASE_MS` | No | integer 5000–120000; default `30000` and greater than the manifest wall limit plus teardown margin | crash/reclaim window |
| `PYTHON_GRADER_MAX_RETRIES` | No | integer 0–5; default `2` | infrastructure retry ceiling |
| `PYTHON_GRADER_QUEUE_LIMIT` | No | integer 1–10000; default `1000` | reservation backpressure ceiling |
| `ALLOW_HOSTED_TEST_TARGET` | No | absent normally; exact protected project ref | hosted-test runner guard only |

Add more variables only with a documented owner, validation, and environment
source.
`ALLOW_HOSTED_TEST_TARGET` is parsed only by the hosted-test launcher and is
never passed into the API container. `PYTHON_GRADER_*`,
`PYTHON_WASM_RUNTIME_MANIFEST`, and `PYTHON_SANDBOX_LAUNCHER_PROFILE` are owned
by the grader-controller config; the API receives only the enabled/capacity
state required to accept or reject reservations. Sandbox-launch credentials, if
the approved platform requires them, use a controller-only least-privilege
secret binding and are never inherited by the disposable worker.

`SUPABASE_URL` and `SUPABASE_JWT_ISSUER` are deliberately separate inputs. In
local Compose the URL may use a container-reachable host while the JWT still
contains the CLI's canonical host-published issuer. Never derive one local
value from the other. Capture both from current `supabase status` and test token
verification from host and container paths.

For a standard hosted project, startup must normalize and prove all of the
following before constructing a client:

1. `SUPABASE_PROJECT_REF` is a valid exact project reference;
2. `SUPABASE_URL` uses `https`, has no user info/query/fragment, and its host is
   exactly `<SUPABASE_PROJECT_REF>.supabase.co`;
3. `SUPABASE_JWT_ISSUER` uses `https` and exactly matches the issuer recorded
   from that project.

If a future approved custom Supabase domain makes rule 2 inapplicable, commit a
non-secret reviewed mapping of `APP_ENV -> project ref -> API origin -> issuer`
in deployment configuration. Startup must require an exact mapping match; an
arbitrary URL plus internally consistent keys is not sufficient. Production
must reject a complete development URL/key/issuer set even when
`APP_ENV=production`. Startup/internal deployment evidence may log only a safe
environment and project-ref fingerprint, never URLs containing credentials or
any key. Public liveness/readiness response bodies remain the exact minimal
schemas in the health contract and expose neither value.

Phase 1 is a liveness-only scaffold: tests inject a dependency bundle with no
database client, and its placeholder configuration never calls Supabase. From
FAST-PLUGIN-002 onward, all Supabase values above are mandatory, must come from
the ignored local environment, and startup fails if the secret-backed
module adapters cannot be constructed.

Valid mode pairs are explicit: tests use `NODE_ENV=test, APP_ENV=local`; local
development uses `development,local`; every hosted container uses
`NODE_ENV=production` with its exact `APP_ENV`; production requires
`production,production`. Reject every other pair.

## Secret rules

- `.env.example` contains names and safe placeholders, never real values.
- `.env`, `.env.*.local`, CLI temporary state, and platform credentials are
  ignored.
- Compose uses runtime environment interpolation or an ignored `env_file`.
- Docker build arguments must never carry secrets.
- CI uses protected secret storage and masks values.
- Logs redact authorization, cookies, keys, password fields, answer specs,
  database connection credentials, TOTP codes/secrets, QR/`otpauth` material,
  refresh tokens and factor/challenge/Auth response bodies.
- The sandbox receives an explicit empty environment allowlist; controller
  secrets and these environment variables are not inherited.
- Secret rotation has a staged overlap and rollback procedure.
- A secret leak triggers revocation/rotation, history review, and incident notes;
  merely deleting the file is insufficient.

## Tasks

### ARC-ENV-001 — Accept API configuration and environment separation

FAST-CONFIG-001 owns the one API parser and its TypeBox schema. Per
[ADR 0004](../../docs/adr/0004-configuration-ownership-and-phase-one-api-parser.md),
this task must reuse that parser rather than introduce another configuration
contract. It is an acceptance/proof task, not a second implementation task.

- [ ] Trace every API-owned variable in the table to the one `ConfigSchema`,
      raw parser, immutable output, and focused test. Record any gap as a
      FAST-CONFIG correction rather than adding a second source of truth.
- [ ] Review the accepted local/hosted mode pairs, standard hosted
      project-ref/URL/issuer relation, HTTPS rule, strict CORS behavior, and
      safe defaults. Confirm that a hosted API-only release still has no
      release-record mechanism and therefore fails closed.
- [ ] Prove `SUPABASE_URL` and `SUPABASE_JWT_ISSUER` remain separate inputs,
      and that errors, logs, and test artifacts do not expose supplied values.
- [ ] Prove the API exposes only the grader enabled/capacity projection and
      ignores controller-only manifest, launcher, queue-control, retry,
      sandbox-binding, and hosted-test variables.
- [ ] Publish an ARC-ENV-001 acceptance report with a fresh clean-install and
      verification record. Do not construct Fastify, a Supabase client, a
      Python controller, Docker, or hosted resources.

The controller-only runtime manifest, launcher profile, claim/poll/lease/retry
settings, sandbox binding, `python_code` publication/reservation behavior, and
G-WASM gate belong to ARC-WASM-001/FAST-WASM-001. The protected remote-test
guard, host/Compose proof, safe readiness logging, reviewed custom-domain
mapping, and target distinctness belong to ARC-ENV-002 after its listed
runtime prerequisites.

### ARC-ENV-002 — Prove separation

- [ ] Add tests that local/test configuration cannot use a known remote URL
      unless the separate hosted-test command receives
      `ALLOW_HOSTED_TEST_TARGET=<exact-project-ref>` from a protected
      environment matching `SUPABASE_PROJECT_REF`; no boolean bypass exists.
- [ ] Include the environment name in logs and readiness without exposing keys.
- [ ] Document how to obtain local values from `supabase status` without copying
      them into tracked files.
- [ ] Confirm development and production project refs differ; if DEC-027 adds
      staging, confirm all three refs differ before deploy.
- [ ] Prove `SUPABASE_URL` and `SUPABASE_JWT_ISSUER` are handled separately in
      host and Compose tests.
- [ ] Test the standard hosted project-ref mapping, a wrong-ref URL, a wrong
      issuer, HTTP in a hosted mode, and the reviewed custom-domain mapping path.
- [ ] Prove a production process fails before network access when given a
      self-consistent development URL/key/issuer set or any unrecorded mapping.
