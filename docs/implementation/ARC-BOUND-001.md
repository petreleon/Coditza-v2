# ARC-BOUND-001 — Enforce module boundaries

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: Implementation is authorized. This task changes only
the local dependency graph, test-only fixtures, locked development tooling, and
local implementation documentation; it performs no Supabase, Docker, Chrome,
SMTP, Vercel, or other hosted action.
Prerequisites/gate checked: G0, ARC-DESIGN-001, and FOUND-001 are complete.
ARC-BOUND-001 was the sole `next` task before work began.
Decisions/defaults used:

- `dependency-cruiser` 18.1.0 is an exact, lockfile-backed development
  dependency. Under Node 24.18.0 it supports TypeScript 6.0.3 and the project's
  `.ts`/ESM dependency graph.
- The stable rule identifiers are `BND-001` through `BND-010`. They default to
  denying business-module, platform, API-wiring, adapter, raw-client, grader,
  and one-off-executable edges except for the architecture contract's explicit
  allowlists.
- The only cross-module application imports accepted are assessment to
  `curriculum.public.ts`, and progress to `curriculum.public.ts` or
  `assessment.public.ts`. `public.ts` is otherwise an own-application-contract
  boundary.
- Type-only imports are dependency edges. The boundary configuration enables
  `tsPreCompilationDeps`, and fixtures use them deliberately so a later
  type-only escape is detected.

## Scope

- Intended: lock one compatible dependency-graph tool, encode the accepted
  import matrix, prove every named forbidden category with an isolated failing
  fixture, prove the allowed own-layer/public-contract controls, and scan the
  full real API source graph without bypasses.
- Explicitly excluded: configuration parsing, Fastify construction/routes or
  listening, Supabase clients/adapters, Docker/Compose, Python runtime or
  controller, real business modules, credentials, Chrome, SMTP, Vercel, and
  hosted state. BND-009 runtime decoration proof and BND-010 runtime
  registration proof remain owned by FAST-PLUGIN-002 and ARC-BOUND-002.

## Changed

- `package.json` and `package-lock.json`: add exact
  `dependency-cruiser@18.1.0`; add production-graph and fixture-verification
  scripts; make lint include the clean production boundary scan.
- `.dependency-cruiser.cjs`: CJS configuration that enforces the selected
  shared-kernel, layer, cross-module, public-contract, API/grader, Fastify
  capability, and operator boundaries with `BND-001` through `BND-010`.
- `apps/api/test/boundaries/fixture-manifest.mjs`,
  `apps/api/test/boundaries/verify-fixtures.mjs`, and
  `apps/api/test/boundaries/README.md`: a closed manifest plus a deterministic
  verifier. It rejects unlisted/non-TypeScript fixtures, dynamic/CommonJS
  fixture edges, source-path drift, TS/package alias bypasses (including local
  `extends` chains), and dependency-cruiser scan exclusions.
- `apps/api/test/boundaries/fixtures/`: 63 isolated negative fixtures and four
  positive controls. These mirror only test paths and do not create production
  business-module or adapter directories.

## Verification

- Dependency-cruiser compatibility inspection
  - Result: PASS
  - Non-secret evidence: `dependency-cruiser@18.1.0` under Node `v24.18.0`
    reports its supported runtime range as `^22 || ^24 || >=26`, recognizes
    TypeScript `6.0.3`, and enables `.ts`/ESM parsing.
- Target-runtime clean installation
  - Result: PASS
  - Non-secret evidence: Node `24.18.0` and npm `11.16.0` ran
    `npm ci --ignore-scripts`; the exact lockfile restored 245 packages, 247
    were audited, and npm reported zero vulnerabilities.
- `npm run boundaries`
  - Result: PASS
  - Non-secret evidence: dependency-cruiser scanned all current
    `apps/api/src` files and reported no violation (5 modules, 4 dependencies
    cruised).
- `npm run test:boundaries`
  - Result: PASS
  - Non-secret evidence: 63 negative fixtures each failed independently with
    exactly their expected `BND-001` through `BND-010` identifier; four
    positive controls passed: own application to domain, assessment to
    curriculum public contract, and both progress public-contract imports.
- Production-scan and bypass guards
  - Result: PASS
  - Non-secret evidence: every production TypeScript path matches the declared
    architecture shape; new paths fail. No TypeScript `baseUrl`/`paths` occurs
    in either checked config or its local extends chain, no root/API package
    `imports` alias exists, production source has no `#` alias import, and the
    boundary configuration permits no `exclude`, `includeOnly`, `focus`,
    non-`node_modules` ignore, or source `pathNot` exemption. The fixture root
    is closed to the manifest and each fixture has exactly one static edge.
- `npm run format:check`, `npm run lint`, `npm run typecheck`, `npm run test`,
  and `npm run build`
  - Result: PASS
  - Non-secret evidence: all commands passed under the pinned Node/npm pair.
    `npm run test` ran the boundary verifier after Vitest's intentional
    zero-test exit; build emitted only ignored API artifacts.
- Scope, source, and diff review
  - Result: PASS
  - Non-secret evidence: `git diff --check` passed. `apps/api/src` remains the
    four type-only foundation files; no real business module, adapter,
    Supabase client, configuration reader, Fastify app/listener, Docker
    artifact, Python runtime, credential, or hosted-state artifact was added.

## External actions

NONE. The task installed a lockfile-pinned public npm development dependency
and used temporary public Node/npm artifact runners for local verification; no
project, account, credential, browser, database, deployment, or provider state
was read or changed.

## Deviations/ADRs

- The repository uses a CJS dependency-cruiser configuration because its
  loader supports that configuration form in this ESM workspace. Supplying the
  API `tsconfig.json` to dependency-cruiser caused its resolver to look for
  `apps/api/tsconfig.base.json` and fail with TS5083. The configuration instead
  uses normal NodeNext `.js` relative paths plus `tsPreCompilationDeps`; the
  verifier rejects TypeScript/package aliases, so this introduces no alternate
  graph-resolution path.
- No new ADR is needed: the selected tool operationalizes the already accepted
  ADR 0001 boundary contract without changing its architecture.

## Risks/blockers

- A future source location outside the declared architecture fails the boundary
  verifier until the owning task changes the architecture contract, rule, and
  isolated fixture together.
- FAST-PLUGIN-002 and ARC-BOUND-002 must still prove the runtime surfaces that
  BND-009 and BND-010 intentionally do not construct in this static-only task.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer,
TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
recorded. `.env` was neither read nor changed.

## Next

FAST-CONFIG-001 is the only unblocked next task: FOUND-001 provides the strict
toolchain and ARC-BOUND-001 now protects the architecture graph. It may replace
the type-only configuration seam with a tested, immutable, TypeBox-validated
API configuration parser; it may not construct Fastify, a listener, Supabase,
Docker, credentials, or hosted state.
