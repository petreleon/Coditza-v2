# Next task

The next implementation task is:

**QA-STRAT-001 — Establish the test harness.**

Prerequisites verified: ARC-DOCKER-001 through ARC-DOCKER-003 are complete.
The local API and final production image are verified, and the existing
container check path runs the present foundation commands without a Supabase
service. G1 is not yet complete.

## Read first

1. README.md
2. TASKS.md
3. STATUS.md
4. 00-control/00-scope-and-non-goals.md
5. 00-control/01-fixed-decisions.md
6. 00-control/03-execution-protocol.md
7. 02-architecture/00-system-boundaries.md
8. 02-architecture/02-environments-and-secrets.md
9. 02-architecture/03-docker-compose.md
10. 04-fastify/00-bootstrap-and-config.md
11. 06-quality/00-testing-strategy.md
12. 06-quality/01-unit-tests.md
13. 06-quality/02-api-integration-and-contract.md
14. 08-execution/00-roadmap.md
15. 08-execution/01-dependency-map.md
16. 08-execution/02-phase-gates.md
17. 08-execution/03-handoff-protocol.md
18. ../package.json, ../apps/api/package.json, existing Vitest tests/support,
    Dockerfile, compose.yaml, and .gitignore
19. ../docs/implementation/ARC-DOCKER-001.md through
    ../docs/implementation/ARC-DOCKER-003.md

## Permitted scope

Establish only the local test-harness structure and its no-network safety
contracts. Use the already locked Vitest/coverage dependencies; do not add
packages or change pinned versions unless a task-scoped verification proves
the existing lockfile cannot express a required harness feature.

Permitted artifacts are a Vitest configuration and scripts, focused test
support/factories and their tests, layer-specific test folders or clear project
selectors, ignored sanitized report configuration, the QA-STRAT-001 report,
and the usual task/checklist/tracker updates after all evidence passes.

Do not start or initialize Supabase, invoke its CLI, construct a Supabase
client, make any HTTP/DNS/network request, read a real .env file, add a hosted
test bypass, add real JWT/TOTP/QR/otpauth/factor data, add application routes
or domain behavior, add CI, use Chrome, or change Docker runtime behavior.
ALLOW_HOSTED_TEST_TARGET belongs to ARC-ENV-002 and is not a QA-STRAT-001
bypass.

## Required implementation

1. Preserve the existing fast, listener-free foundation tests and the separate
   dependency-boundary verifier. Give tests a clear layer identity using
   Vitest projects or an equivalent explicit selector:
   - unit covers pure configuration, app-factory, lifecycle, helpers, and
     future domain/application tests with no listener, database, network, or
     real time;
   - integration is reserved for local-Supabase-backed adapters and must run
     its local-target guard before any adapter/client can be constructed;
   - contract, database, end-to-end, security, and WASM layers have explicit
     reserved selectors rather than silently joining the unit suite.
   Empty future layers must be visibly empty/reserved, not misreported as
   passed coverage of an unimplemented system.
2. Keep a one-command foundation loop that runs current static checks, unit
   tests, the boundary verifier, and build without requiring Supabase. Add
   narrow layer scripts only when their behavior is explicit; retain a
   compatibility-safe npm test command for the current foundation checks.
3. Create test factories that return a new synthetic actor/principal and fake
   token representation for every call. They must be deterministic under
   injected IDs/time, have no global mutable user/session state, and be safe
   under parallel execution. A fake token must be an opaque test value, never
   a real JWT or signed credential.
4. Define an injectable Auth-test-helper interface with deterministic aal1 and
   aal2 states. It models only the principal assurance state needed by future
   Fastify tests; it must not claim an actual login, password validation,
   factor enrollment, TOTP verification, QR generation, or Supabase session.
   SUP-MFA-001 later owns genuine local Auth fixtures and secret-safe cleanup.
5. Implement a test-only local Supabase target guard that parses supplied
   target metadata without making a connection. The normal integration path
   must require SUPABASE_PROJECT_REF=local and an HTTP local target. Its
   documented allowlist may include loopback/local-host forms and only the
   reviewed container-reachable local form needed by a later Compose test; it
   must reject https, any .supabase.co host, arbitrary public/private LAN
   address, credentials, query/fragment, a non-local project ref, and malformed
   URLs. Keep SUPABASE_URL and SUPABASE_JWT_ISSUER as separate values; do not
   derive one from the other.
6. Test the guard with positive synthetic local examples and negative remote
   examples. Tests must prove rejection occurs before any network-capable
   dependency is created. Do not use a real URL, token, key, or environment
   file as a fixture.
7. Make teardown deterministic and scoped to a per-test fixture namespace.
   At this task it may clean only in-memory state. It must never issue a
   destructive database/hosted cleanup command.
8. Configure coverage and JUnit outputs only as sanitized, ignored local
   artifacts. Do not set arbitrary coverage thresholds before a baseline; the
   later critical-branch requirement remains intact.

## Required verification before completion

- Prove the existing foundation test command still reports the current tests
  and boundary fixtures, with no network/Supabase requirement.
- Exercise every named test-layer selector and show that a reserved empty layer
  cannot be mistaken for a successful integration or security system test.
- Run deterministic, parallel-safe factory/helper tests for fresh identities
  and aal1/aal2 behavior.
- Run local-target guard vectors covering accepted loopback/local forms and
  rejected HTTPS, hosted Supabase, non-local project ref, arbitrary network
  address, credentials, query/fragment, and malformed values; assert no
  network client is instantiated.
- Verify generated JUnit/coverage artifacts contain no keys, tokens, TOTP
  material, full Auth responses, answer keys, or learner text, and are ignored.
- Run format:check, lint, typecheck, the foundation test command, all new
  harness tests, build, git diff --check, and the isolated Compose checks
  using placeholder-only configuration. Review the diff for scope and secret
  safety.
- Create docs/implementation/QA-STRAT-001.md and synchronize the testing
  checklist, registry, status, roadmap, scope guardrail, README, and this file
  only after all acceptance evidence passes.

After QA-STRAT-001, verify and record G1 before starting any local Supabase,
schema, Auth, curriculum, SMTP, Chrome, Vercel, or other hosted task.
