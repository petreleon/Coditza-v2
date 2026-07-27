# Next task

The next implementation task is:

**FAST-CONFIG-001 — Fail-fast typed configuration.**

Prerequisites already verified: G0, PLAN-004, FOUND-001, and ARC-BOUND-001 are
complete. This is the sole task allowed to change implementation files now.

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
18. `../docs/implementation/ARC-BOUND-001.md`
19. `../docs/implementation/architecture-boundary-contract.md`

Implement only a local, fail-fast API configuration parser and its tests.

## Required design

- Replace the type-only foundation configuration seam with one typed,
  deeply immutable configuration object and one `ConfigSchema`. Use the already
  installed `typebox` package and its compatible `typebox/value`
  `Value.Check`/`Value.Errors` API. Do not add a second schema/validation
  library.
- Make the main parser accept an explicitly injected raw environment record,
  such as `Readonly<Record<string, string | undefined>>`. Tests must call that
  parser with local records and must not mutate `process.env`. A very small
  production-only wrapper may pass `process.env`; it must not load `.env`,
  construct a dependency, or create side effects.
- Parse raw strings first with small explicit helpers, then validate the parsed
  object with the one TypeBox schema. Never use JavaScript truthiness for a
  numeric or boolean environment value.
- Cover API-owned configuration from the environment contract: the
  `NODE_ENV`/`APP_ENV` pair; host, port, prefix, log level, trusted-proxy mode,
  request-ID header, Swagger switch; CORS; body/rate/readiness/shutdown and
  request-timeout limits; Supabase URL/project ref/publishable key/secret
  key/JWT issuer/audience; and the cursor HMAC secret.
- Keep `SUPABASE_URL` and `SUPABASE_JWT_ISSUER` as separate validated values.
  Validate syntax and local-versus-hosted safety that belongs to this parser,
  but do not instantiate a Supabase client, make a network call, or derive one
  from the other.
- The API may expose only the Python grader enabled/capacity projection:
  `PYTHON_GRADER_ENABLED`, `PYTHON_GRADER_CONCURRENCY`, and
  `PYTHON_GRADER_QUEUE_LIMIT`. Do not parse or expose the controller-only
  manifest, launcher-profile, claim/poll/lease/retry, sandbox binding, or
  `ALLOW_HOSTED_TEST_TARGET` values here; ARC-ENV-001 and the private
  controller path own their broader separation proof.
- Implement strict integer and boolean parsing. Preserve the documented
  inclusive numeric limits/defaults. Make `false` a real boolean false, never a
  truthy string.
- Parse `CORS_ORIGINS` as a comma-separated list of exact absolute `http` or
  `https` origins. Reject credentials, paths, queries, fragments, malformed
  values, duplicates after normalization, wildcard production values, and
  localhost origins in production. Normalize scheme/host casing while
  preserving an explicit port. Empty CORS remains valid only for the explicitly
  recorded API-only mode; do not silently turn it into `*`.
- Validation errors may identify variable names and safe validation reasons but
  must never echo `SUPABASE_SECRET_KEY`, `CURSOR_HMAC_SECRET`, publishable key,
  or another supplied value. Freeze every exported object/array deeply enough
  that consumers cannot mutate configuration after parsing.
- Update `.env.example` only if it needs a safe placeholder or documented
  local default. Do not read, print, copy, edit, or stage `.env` or any other
  real local environment file.

## Required tests and evidence

- Add focused Vitest tests for a valid injected record; every required missing
  variable; each parser boundary/invalid value; strict `false`; valid and
  rejected CORS normalization cases; safe mode pairs; secret-redacted errors;
  and immutability. Use a non-secret sentinel in redaction tests and assert the
  sentinel never reaches an error, snapshot, or log.
- Assert parsing performs no network call and does not require Fastify or a
  Supabase SDK client. Do not create an app factory merely to satisfy an older
  wording about a valid config "building" an app: FAST-BOOT-001 exclusively
  owns `buildApp`, routes, and listening.
- Keep the existing BND-001 through BND-010 graph clean. If the parser creates
  a new API source path, it must fit the ARC-BOUND-001 production-path contract
  and pass the static scan; do not weaken a boundary rule or add an exemption.
- Before trackers move, run a clean Node 24.18.0/npm 11.16.0 install plus
  format check, lint, typecheck, tests, build, boundary checks, `git diff
  --check`, and a scoped secret-safety review. Create a FAST-CONFIG-001 report,
  then mark that task complete and make ARC-ENV-001 the sole next task only if
  all evidence passes.

Do not add Fastify construction/plugins/routes/listening, a composition root,
Supabase client/adapter, Docker/Compose, a Python runtime/controller, real
business module, credential, Chrome action, SMTP configuration, Vercel
resource, hosted state, or a frontend. Do not change production, staging, or
development platform configuration.
