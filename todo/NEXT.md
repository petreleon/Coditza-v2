# Next task

The next implementation task is:

**ARC-ENV-001 — Accept API configuration and environment separation.**

Prerequisites already verified: G0, PLAN-004, FOUND-001, ARC-BOUND-001, and
FAST-CONFIG-001 are complete. This is the sole task allowed to change
implementation files now.

Read first:

1. `README.md`
2. `TASKS.md`
3. `STATUS.md`
4. `00-control/00-scope-and-non-goals.md`
5. `00-control/01-fixed-decisions.md`
6. `00-control/02-open-decisions.md`
7. `00-control/03-execution-protocol.md`
8. `02-architecture/00-system-boundaries.md`
9. `02-architecture/02-environments-and-secrets.md`
10. `02-architecture/04-data-flow-and-security.md`
11. `04-fastify/00-bootstrap-and-config.md`
12. `06-quality/00-testing-strategy.md`
13. `08-execution/00-roadmap.md`
14. `08-execution/01-dependency-map.md`
15. `08-execution/03-handoff-protocol.md`
16. `../docs/adr/0001-modular-monolith-and-ports-adapters.md`
17. `../docs/adr/0003-node-fastify-toolchain-baseline.md`
18. `../docs/adr/0004-configuration-ownership-and-phase-one-api-parser.md`
19. `../docs/implementation/FAST-CONFIG-001.md`
20. `../docs/implementation/architecture-boundary-contract.md`

Perform a local acceptance and separation audit of the existing API parser;
do not create a second configuration implementation.

## Required work

- Build a traceable inventory from every API-owned environment variable in the
  environment table to the existing `ConfigSchema`, parsing rule, immutable
  output field, and focused test. If a real gap is found, make the smallest
  correction in the existing configuration module and add a focused test; do
  not introduce another schema or a parallel `process.env` reader.
- Recheck and document the exact accepted mode pairs, local-versus-hosted
  Supabase syntax/mapping rules, empty-CORS fail-closed behavior for hosted
  releases, proxy/SWAGGER/Python-grader gates, and the effective timeout
  relation. Verify that `SUPABASE_URL` and `SUPABASE_JWT_ISSUER` are separate
  values rather than derived aliases.
- Prove controller-only values are not parsed or exposed by the API:
  runtime manifest, launcher profile, claim/poll/lease/retry settings,
  sandbox binding, and `ALLOW_HOSTED_TEST_TARGET`. Keep all of them out of the
  API test fixture except as inert injected unknown keys.
- Prove errors and any test/report artifacts name fields/reasons only and do
  not include supplied key, cursor, or other environment values. Do not read,
  print, edit, or stage `.env` or another real local environment file.
- Create `docs/implementation/ARC-ENV-001.md` with the inventory, scope,
  decisions, checks, and explicit deferred controls. Then update the task
  registry, status, roadmap, and this file only after all required local
  verification passes.

## Required verification

- Use Node `24.18.0` and npm `11.16.0` for a clean `npm ci --ignore-scripts`,
  `npm run format:check`, `npm run lint`, `npm run typecheck`, `npm test`, and
  `npm run build`.
- Run `git diff --check`, the full dependency-boundary verifier, and a scoped
  secret-safety review of only intended tracked files.
- Record the results in the report. Move ARC-ENV-001 to `complete` and make
  FAST-BOOT-001 the sole `next` task only if all acceptance evidence passes.

Do not add Fastify construction/plugins/routes/listening, a composition root,
Supabase client/adapter, Docker/Compose, a Python runtime/controller, real
business module, credential, Chrome action, SMTP configuration, Vercel
resource, hosted state, or a frontend. Do not create or alter a production,
staging, or development platform configuration.
