# QA-STRAT-001 — Establish the test harness

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: The user authorized implementation, local Docker
verification, and direct commits/pushes. This task made no hosted, production,
credential, Supabase, SMTP, Chrome, Vercel, or external-state change.
Prerequisites/gate checked: G0, PLAN-004, FOUND-001, ARC-BOUND-001/002,
FAST-CONFIG-001, ARC-ENV-001, FAST-BOOT-001, FAST-LIVE-001, and
ARC-DOCKER-001 through ARC-DOCKER-003 are complete. QA-STRAT-001 was the sole
next task before work began.

## Decisions

- Vitest is configured in apps/api so the existing Docker checks stage copies
  the test configuration with the API files. Its environment-file loading is
  disabled, and its runner config loader keeps the read-only checks container
  from writing temporary files under node_modules.
- Unit is the only passing current product layer. Integration, contract,
  database, end-to-end, and security selectors intentionally fail when empty;
  they cannot be mistaken for implemented coverage. The WASM selector stops
  until ARC-WASM-001 approves a hardened outer sandbox.
- Fake identity and Auth helpers are deterministic, frozen, instance-local
  test data only. They issue opaque object tokens and model injected aal1 or
  aal2 principal state; they never model passwords, login, factors, TOTP,
  QR data, signed credentials, or Supabase sessions.
- The test-only Supabase guard accepts only project ref local, HTTP loopback
  values, and the reviewed Compose-only API bridge form. It validates separate
  API URL and issuer values synchronously before a future client factory runs.

## Scope

- Intended: explicit layer selectors, local-only helper factories, no-network
  target validation, report sanitation, test type checking, and a reproducible
  local/container foundation loop.
- Explicitly excluded: application behavior, routes, Supabase initialization or
  client construction, real environment-file access, hosted bypasses, real
  Auth/TOTP fixtures, CI, credentials, browsers, deployments, and external
  state.

## Changed

- package.json: explicit layer scripts, test typecheck, artifact-free default
  test command, sanitized coverage command, and foundation check command.
- apps/api/vitest.config.ts and apps/api/tsconfig.test.json: named Vitest
  projects, disabled environment-file discovery, no empty-layer pass, report
  configuration, and test-only type coverage.
- apps/api/test/support: deterministic synthetic identities, opaque fake Auth,
  in-memory scoped cleanup, local-target guard, report verifier, and focused
  tests.
- apps/api/test/wasm: explicit hardened-outer-sandbox stop command.
- apps/api/test/config/parse-api-config.test.ts: narrow test-data type
  correction so the expanded test typecheck remains strict.
- todo/06-quality/00-testing-strategy.md: current local verification and
  completed harness checklist.

## Verification

- npm run check:foundation
  - Result: PASS.
  - Non-secret evidence: formatting, lint, source and test type checks, 177
    unit tests, 63 negative plus four positive boundary fixtures, and the API
    build all pass without Supabase or a network target.
- npm run test:integration, test:contract, test:db, test:e2e, and
  test:security
  - Result: expected nonzero exit.
  - Non-secret evidence: each reports no test files for its named reserved
    project rather than a false success.
- npm run test:wasm
  - Result: expected nonzero exit.
  - Non-secret evidence: it stops with the explicit ARC-WASM-001 hardened
    outer-sandbox requirement.
- npm run test:coverage
  - Result: PASS.
  - Non-secret evidence: 177 unit tests pass; only coverage-final.json,
    junit.xml, and lcov.info are emitted under apps/api/coverage. The report
    verifier rejects unexpected output and likely credential, Auth, answer, or
    console markers. Git confirms all three are ignored.
- Local-target guard vectors
  - Result: PASS.
  - Non-secret evidence: accepted loopback and reviewed Compose bridge forms;
    rejected non-local refs, HTTPS, hosted Supabase, public/private network
    targets, credentials, query/fragment, and malformed input. The rejection
    test proves the injected factory and fetch were never called.
- Isolated Compose checks
  - Result: PASS.
  - Non-secret evidence: a rebuilt checks image used .env.example placeholders,
    read-only filesystem, and no network. It passed the complete 177-test
    foundation loop. Exact-project cleanup left no containers, networks, or
    volumes.
- git diff --check
  - Result: PASS.

## External actions

Only a disposable local Docker checks image/container was built and run. No
Supabase service, hosted account, project, deployment, credential, or browser
action occurred.

## Deviations/ADRs

The default Vitest config bundler attempted to create a temporary directory
under read-only node_modules in the checks container. The test scripts now use
the supported runner config loader; no Docker runtime behavior changed.

## Risks/blockers

No blocker for this task. The next phase begins with a read-only Vercel
topology review. A supplemental private grader host, if required by that
research, must stop for a separate explicit user approval before it is selected
or created.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer,
TOTP/QR/otpauth/factor/challenge material, or unsafe log was recorded.

## Next

OPS-VERCEL-001 is the sole next task after the recorded G1 gate. It may conduct
read-only official capability research and write a local topology ADR; it may
not create, authenticate, configure, or deploy any Vercel or other hosted
resource.
