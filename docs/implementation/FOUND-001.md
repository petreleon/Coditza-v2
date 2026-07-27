# FOUND-001 — Establish API runtime and tooling baseline

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: Implementation is authorized. This task changes only
the local private npm workspace, locked tooling, and local implementation
documentation; it performs no Supabase, Docker, Chrome, SMTP, Vercel, or other
hosted action.
Prerequisites/gate checked: G0, ARC-TREE-001, ARC-TREE-002,
ARC-DESIGN-001, PRD-AUTH-001, and PRD-WASM-001 are complete. FOUND-001 was the
sole `next` task before work began.
Decisions/defaults used:

- Node.js 24.18.0 LTS and its bundled npm 11.16.0 are the exact local/CI/image
  baseline; the declared engine range intentionally remains within Node 24 and
  npm 11.
- The API is an ESM/NodeNext, strict TypeScript workspace. It emits `src` to
  `dist` and uses `.js` suffixes for every local TypeScript import.
- Fastify 5.10.0, `@fastify/type-provider-typebox` 6.1.0, and `typebox`
  1.0.13 are the minimal runtime foundation. No plugin, Supabase client,
  route, adapter, or database dependency is installed before its owning task.
- Type-only app, composition-root, configuration, and server contracts reserve
  the seams without claiming parsing, dependency construction, Fastify
  instantiation, routing, or a network listener. FAST-CONFIG-001,
  FAST-BOOT-001, and ARC-BOUND-001 own those next behaviors.

## Scope

- Intended: create a private npm workspace, lock a verified Fastify/TypeScript
  toolchain, enable strict ESM compilation/lint/format/test commands, reserve
  non-business seam and boundary-fixture locations, and record the decision.
- Explicitly excluded: configuration parsing, app factory/listener/liveness,
  Fastify plugin or route registration, domain modules, Supabase, Docker or
  Compose, Python/Pyodide runtime or sandbox selection, credentials, Chrome,
  SMTP, Vercel, and any hosted state.

## Changed

- `package.json`, `package-lock.json`, `.nvmrc`, and `tsconfig.base.json`:
  Node/npm baseline, reproducible workspaces, strict NodeNext compiler options,
  and root format/lint/typecheck/build/dev/start/test entrypoints.
- `eslint.config.js`: flat ESLint configuration for the API source with strict
  TypeScript recommendations and type-only import enforcement.
- `apps/api/package.json` and `apps/api/tsconfig.json`: private API package,
  exact Fastify/TypeBox dependencies, `src` to `dist` build boundary, and
  package-local scripts.
- `apps/api/src/app.ts`, `apps/api/src/server.ts`,
  `apps/api/src/bootstrap/composition-root.ts`, and
  `apps/api/src/infrastructure/config/types.ts`: type-only foundation seams;
  no executable configuration, framework creation, adapter, route, or listener
  behavior.
- `apps/api/test/boundaries/README.md`: tracked home reserved for
  ARC-BOUND-001's executable positive and negative import fixtures.
- `docs/adr/0003-node-fastify-toolchain-baseline.md`: exact version,
  compatibility, and deferred-dependency decision record.
- `todo/02-architecture/02-environments-and-secrets.md`: aligns the future
  configuration-validation reference with the selected `typebox/value` API.
- task trackers: record completion evidence and select ARC-BOUND-001 as the
  sole next task.

## Verification

- Official Node 24.18.0 macOS arm64 artifact checksum verification
  - Result: PASS
  - Non-secret evidence: the downloaded binary's SHA-256 matched the official
    Node 24.18.0 `SHASUMS256.txt` entry and reported Node `v24.18.0` with npm
    `11.16.0`.
- Target-runtime clean dependency installation
  - Result: PASS
  - Non-secret evidence: under that exact Node/npm pair,
    `npm ci --ignore-scripts` restored the committed lockfile (208 packages,
    210 audited, zero reported vulnerabilities) without lifecycle scripts.
- `npm run format:check`, `npm run lint`, and `npm run typecheck`
  - Result: PASS
  - Non-secret evidence: Prettier found no formatting drift, ESLint accepted
    the API source, and strict `tsc --noEmit` completed for `@coditza/api`.
- `npm run test`
  - Result: PASS
  - Non-secret evidence: Vitest 4.1.10 intentionally found no tests and exited
    zero through `--passWithNoTests`; ARC-BOUND-001 and QA-STRAT-001 own the
    first executable fixture/configuration suites.
- `npm run build`
  - Result: PASS
  - Non-secret evidence: the API emitted clean ESM declarations and JavaScript
    into ignored `apps/api/dist` using NodeNext resolution.
- Foundation scope and generated-drift review
  - Result: PASS
  - Non-secret evidence: `git diff --check` passed; source inspection found no
    executable `process.env`, `.listen(`, Fastify construction, Supabase client,
    Pyodide, external adapter, or business-module directory. The sole literal
    `process.env` occurrence is an explanatory comment that says it is not
    read. No empty business-module placeholder was added.
- Dependency compatibility review
  - Result: PASS
  - Non-secret evidence: the ADR records the official Fastify LTS/type-provider
    pairing and TypeBox/TypeScript compatibility. Unused Fastify plugins and
    the Supabase SDK remain deferred and absent from the lockfile.

## External actions

NONE. The official Node artifact was downloaded and checksum-verified locally;
no cloud project, repository setting, credential, email, browser, database, or
deployment state was read or changed.

## Deviations/ADRs

- ADR-0003 records the selected toolchain. The current TypeBox package line is
  `typebox`, so the future configuration checklist uses `typebox/value` rather
  than the older `@sinclair/typebox/value` import path.
- `dev` and `start` currently load a deliberately no-listener module. This is
  not liveness evidence: FAST-BOOT-001 is the only owner of app construction,
  network binding, and signal-safe shutdown.

## Risks/blockers

- ARC-BOUND-001 must add and prove import-boundary enforcement before an
  external adapter or business module can exist.
- FAST-CONFIG-001 must parse/validate/freeze configuration before any
  dependency is constructed. No environment value was read or recorded here.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer,
TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
recorded. `.env` was neither read nor changed.

## Next

ARC-BOUND-001 is the only unblocked next task: FOUND-001 and the accepted
architecture contract provide its foundation. It may choose and prove an
import-boundary enforcement approach plus real positive/negative fixtures, but
it may not add application behavior, configuration parsing, a listener,
Supabase, Docker, credentials, or hosted state.
