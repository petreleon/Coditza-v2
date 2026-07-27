# Testing strategy and quality commands

## Test layers

| Layer | Main subject | Dependencies |
| --- | --- | --- |
| Static | formatting, lint, type safety, import boundaries | none |
| Unit | pure grading/progress, use cases, ports, presenters, config | fakes only |
| Database | migrations, constraints, functions, grants, RLS | local Supabase |
| API integration | Fastify adapters plus Supabase adapters/RPCs | local Supabase |
| Contract | runtime JSON schemas and generated OpenAPI | built app |
| End-to-end backend | complete learner/editor/admin workflows | Compose API + local Supabase |
| Security | identity isolation, answer/secret leakage, abuse | all relevant layers |
| Python sandbox | canonical packages, pinned runtime, deterministic fixtures, escape/resource/queue failure | hardened disposable outer sandbox |
| Image/runtime | build, non-root, health, shutdown | Docker/Compose |

## Rules

- Tests use deterministic synthetic fixtures and isolated users.
- No automated test may target development, staging, or production by default.
- Time, UUID generation, and outbound ports are injectable in unit tests.
- Integration tests use database-generated time for attempt expiry.
- Tests assert both allowed and denied behavior.
- A security denial counts only if it failed for the intended authorization
  reason.
- Every bug fix adds a regression test at the lowest meaningful layer.
- Disabled/skipped/focused tests fail CI unless a reviewed allowlist explains a
  temporary platform limitation.
- Tests never print tokens, keys, answer specs, or free-text learner answers.
- Tests keep TOTP seeds/codes, QR/`otpauth`, refresh tokens and complete Auth
  responses only in memory and redact them even on assertion failure.
- Static boundary tests include negative fixtures for every forbidden
  module/layer dependency, not only a lint configuration snapshot.

## Planned scripts

```text
format
format:check
lint
typecheck
build
test:unit
test:db
test:integration
test:contract
test:e2e
test:security
test:wasm
test:coverage
db:start
db:stop
db:reset
db:lint
db:types
openapi:generate
check
```

`check` must run static checks, unit tests, local database reset/lint/tests,
generated-type drift, API integration/contract/security tests, production build,
Python WASM offline/determinism/sandbox tests, and Docker image verification in
a documented order.

## Current foundation verification

Run npm run check:foundation for the current local-only loop: formatting, lint,
source and test type checks, the unit project, dependency-boundary fixtures, and
the API build. It does not load an environment file, construct a Supabase
client, start Supabase, or contact a network target. The reserved integration,
contract, database, end-to-end, security, and WASM selectors fail until their
task-owned suites exist; they must never turn an empty future layer into a pass.
Vitest uses its runner config loader so the same command works in the
read-only, networkless Compose checks container without writing under
node_modules.

Run npm run test:coverage only when a sanitized local report is needed. It
creates ignored JSON, LCOV, and JUnit artifacts under apps/api/coverage and
rejects unexpected files or likely credential, Auth, answer, or console output.
No coverage threshold is set before a reviewed baseline.

## QA-STRAT-001 — Establish the harness

- [x] Configure Vitest projects or equivalent clear separation by layer.
- [x] Create test config and user/token helpers without global shared user state.
- [x] Add a hard guard rejecting non-local Supabase URLs in integration tests.
- [x] Define the injectable Auth-test-helper interface and deterministic fake
      AAL states without starting Supabase. SUP-MFA-001 later implements the
      genuine local `aal1`/TOTP-`aal2` adapter and secret-safe cleanup.
- [x] Make cleanup deterministic and safe under parallel tests.
- [x] Configure sanitized, ignored JUnit/coverage artifacts for later CI
      publication. This task does not create a CI workflow; OPS-CI-001 owns
      that external publication path.
- [x] Leave coverage thresholds unset until a reviewed baseline; critical grading,
      authorization, and progress branches require 100% branch coverage.
- [x] Document one command for the complete clean verification loop.
- [x] Make test:wasm fail when it cannot use the approved hardened outer
      sandbox; never silently replace it with an in-process/worker-thread run.
