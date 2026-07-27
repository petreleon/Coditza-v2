# FAST-CONFIG-001 — Fail-fast typed API configuration

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: Implementation is authorized. This task changes only
the local API configuration contract, focused tests, planning clarification,
and local implementation documentation. It performs no Supabase, Docker,
Chrome, SMTP, Vercel, or other hosted action.
Prerequisites/gate checked: G0, PLAN-004, FOUND-001, and ARC-BOUND-001 are
complete. FAST-CONFIG-001 was the sole `next` task before work began.

## Scope

- Intended: replace the type-only configuration seam with one injected,
  TypeBox-validated, deeply immutable API configuration object; validate only
  API-owned inputs; prove parsing, safety, redaction, and no-side-effect
  behavior.
- Explicitly excluded: Fastify construction/plugins/routes/listening, a
  composition root, a Supabase client/adapter or database call, Docker/Compose,
  a Python runtime/controller, real business modules, credentials, Chrome,
  SMTP, Vercel, and all hosted state.

## Decision record

[ADR 0004](../adr/0004-configuration-ownership-and-phase-one-api-parser.md)
resolves the earlier ambiguous "every variable" wording. The API owns its
environment/server/CORS/limits/Supabase/cursor values plus only the Python
grader enabled/capacity projection. The private controller retains runtime
manifest, launcher profile, queue-control, retry, sandbox binding, and
hosted-test values.

The ADR also records these safety decisions:

- no proxy trust is accepted until a narrow reviewed policy exists;
- an empty CORS list is permitted only for local/test API-only operation, never
  changed to a wildcard, and cannot represent an unrecorded hosted release;
- Swagger is local-only; the Python grader cannot be enabled before G-WASM and
  private-controller evidence;
- the timeout relation makes the effective keep-alive range `1000`–`119999`
  ms and headers range `1001`–`120000` ms.

## Changed

- `apps/api/src/infrastructure/config/schema.ts`: the closed, single TypeBox
  `ConfigSchema` and its parsed configuration type.
- `apps/api/src/infrastructure/config/parser.ts`: pure injected-record parser,
  small `process.env` wrapper, strict scalar/list parsing, local/hosted safety
  checks, TypeBox `Value.Check`/`Value.Errors` validation, safe errors, and
  recursive freezing.
- `apps/api/src/infrastructure/config/types.ts` and `index.ts`: immutable
  public API contract, redacted error type, and controlled exports.
- `apps/api/src/app.ts`: replaces the obsolete injected marker type with
  `ApiConfig`; it still does not construct or listen with Fastify.
- `apps/api/test/config/parse-api-config.test.ts`: 136 focused injected-config
  tests, with no mutation of `process.env`.
- `docs/adr/0004-configuration-ownership-and-phase-one-api-parser.md` and the
  affected planning files: explicit ownership and timeout-bound clarification.

## Verification

- Target-runtime clean installation
  - Result: PASS
  - Non-secret evidence: Node `24.18.0` and npm `11.16.0` ran
    `npm ci --ignore-scripts`, restoring 245 packages from the committed lock.
- `npm run format:check`
  - Result: PASS
  - Non-secret evidence: Prettier accepted the complete source and test scope.
- `npm run lint` and `npm run boundaries`
  - Result: PASS
  - Non-secret evidence: ESLint passed; dependency-cruiser scanned 10 source
    modules and 12 dependencies with no boundary violation.
- `npm run typecheck` and `npm run build`
  - Result: PASS
  - Non-secret evidence: strict TypeScript completed without diagnostics and
    emitted only ignored local API build artifacts.
- `npm test`
  - Result: PASS
  - Non-secret evidence: Vitest ran 136 configuration tests; the boundary
    verifier also passed all 63 negative fixtures and four positive controls.
- Scope, source, and diff review
  - Result: PASS
  - Non-secret evidence: `git diff --check` passed. The parser's only runtime
    environment read is the explicitly exported production wrapper; the main
    parser accepts an injected record. No dotenv, Fastify construction,
    Supabase SDK/client, `fetch`, or database/network call was added.

## External actions

NONE. Verification used only local Node/npm artifacts and read-only official
documentation for the current Supabase key-prefix and JWT-claim contract. No
project, account, credential, browser, database, or deployment state was read
or changed.

## Risks/blockers

- ARC-ENV-001 accepts the one-parser ownership/separation evidence. ARC-ENV-002
  later owns protected hosted-test separation, remote-target guards,
  target-distinctness evidence, and approved custom-domain/host-Compose proof.
- A reviewed proxy topology, a recorded API-only hosted release mechanism, and
  G-WASM/private-controller evidence are required before their currently
  fail-closed settings can be enabled.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer,
TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
recorded. The test values are explicit non-secret fixtures. `.env` and every
other real local environment file were neither read nor changed.

## Next

ARC-ENV-001 is the next task. It must prove API configuration/environment
separation and deployment-target controls using this parser, without adding
Fastify behavior, hosted state, or controller-only configuration to the API.
