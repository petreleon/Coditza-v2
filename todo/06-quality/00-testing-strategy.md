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

## QA-STRAT-001 — Establish the harness

- [ ] Configure Vitest projects or equivalent clear separation by layer.
- [ ] Create test config and user/token helpers without global shared user state.
- [ ] Add a hard guard rejecting non-local Supabase URLs in integration tests.
- [ ] Define the injectable Auth-test-helper interface and deterministic fake
      AAL states without starting Supabase. SUP-MFA-001 later implements the
      genuine local `aal1`/TOTP-`aal2` adapter and secret-safe cleanup.
- [ ] Make cleanup deterministic and safe under parallel tests.
- [ ] Publish sanitized JUnit/coverage reports in CI.
- [ ] Set coverage thresholds only after baseline; critical grading,
      authorization, and progress branches require 100% branch coverage.
- [ ] Document one command for the complete clean verification loop.
- [ ] Make `test:wasm` fail when it cannot use the approved hardened outer
      sandbox; never silently replace it with an in-process/worker-thread run.
