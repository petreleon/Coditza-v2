# Fastify bootstrap and configuration

## FOUND-001 — API runtime and tooling baseline

Prerequisites: implementation explicitly authorized; G0 accepted;
ARC-TREE-001, ARC-TREE-002, ARC-DESIGN-001 and PRD-AUTH-001 complete.
PRD-WASM-001 is also complete; FOUND-001 does not install Pyodide or choose a
sandbox because ARC-WASM-001 owns that exact compatibility/security decision
after G1.

Planned files:

- the ARC-TREE-001 root files, updated only as required for verified packages;
- `apps/api/package.json`, `tsconfig.json`;
- `apps/api/src/app.ts`, `server.ts`, and configuration module;
- version ADR under the ARC-TREE-002 documentation rule.

Tasks:

- [x] Recheck current Fastify LTS and official-plugin compatibility.
- [x] Choose the compatible active Node LTS and record exact Node, npm, Fastify,
      TypeScript, and plugin versions in an ADR.
- [x] Create a private npm workspace with strict TypeScript and ESM.
- [x] Create the composition-root seam and module-boundary test locations
      without empty business-module placeholders.
- [x] Set `"type":"module"`, NodeNext module/resolution, `src` -> `dist`, and
      `.js` relative import suffixes exactly as specified by ARC-TREE-001.
- [x] Install only the dependencies required by the active foundation task.
- [x] Commit a reproducible lockfile; do not use floating versions in CI/images.
- [x] Add format, lint, typecheck, build, dev, start, and test scripts.
- [x] Prove clean install, typecheck, empty test command, and build.

Completion evidence: [FOUND-001 report](../../docs/implementation/FOUND-001.md)
and [ADR 0003](../../docs/adr/0003-node-fastify-toolchain-baseline.md).

Do not initialize Supabase, add domain routes, or create Docker/Compose artifacts
in FOUND-001; ARC-DOCKER-001/002/003 own those files.

## Planned runtime dependencies

Verify compatible majors before installing:

- `fastify`, `fastify-plugin`;
- `@fastify/type-provider-typebox` and its compatible TypeBox package;
- `@fastify/cors`, `@fastify/helmet`, `@fastify/rate-limit`;
- `@fastify/swagger`; add Swagger UI only if local interactive docs are needed;
- `@supabase/supabase-js`.

Planned developer tooling:

- TypeScript and Node types;
- `tsx` or the chosen minimal development runner;
- ESLint with TypeScript support;
- Prettier;
- Vitest and coverage support;
- local Supabase CLI invocation.

Avoid an ORM, query builder, alternate logger, generic dependency-injection
framework, or validation framework unless an ADR proves it is necessary.

## FAST-BOOT-001 — App/server split

- [x] The only app factory signature is
      `buildApp({ config, dependencies }: BuildAppOptions)`; both properties are
      required, production `server.ts` constructs them, and tests pass explicit
      fakes.
- [x] `bootstrap/composition-root.ts` is the sole production wiring point. At
      this foundation stage it returns only a frozen typed no-op boundary;
      future adapters/use cases must pass only narrow inbound facades to routes.
- [x] No Fastify decoration/request property contains the raw secret client, a
      repository bag, or a service locator.
- [x] `app.ts` never calls `listen`.
- [x] `server.ts` is the only network entry point.
- [x] Tests call `buildApp` and `fastify.inject`.
- [x] The server waits for `app.ready()` before listening.
- [x] Startup failure exits non-zero without leaking config.
- [x] `SIGTERM`/`SIGINT` stop accepting work, close Fastify once, and respect a
      finite shutdown timeout.
- [x] No service/route/plugin calls `process.exit()`.

Completion evidence: [FAST-BOOT-001 report](../../docs/implementation/FAST-BOOT-001.md).

## FAST-CONFIG-001 — Fail-fast typed configuration

Validate before constructing dependencies:

- every API-owned variable in
  `../02-architecture/02-environments-and-secrets.md`, as delimited by
  [ADR 0004](../../docs/adr/0004-configuration-ownership-and-phase-one-api-parser.md);
- `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SECRET_KEY`;
- `SUPABASE_JWT_ISSUER`;
- `CURSOR_HMAC_SECRET`;
- `CORS_ORIGINS`;
- request body, rate-limit, readiness, and shutdown limits.

Rules:

- numeric/boolean values are parsed, never tested as truthy strings;
- raw strings are explicitly parsed, then checked with the one TypeBox
  `ConfigSchema` and `Value.Check`/`Value.Errors`;
- production rejects wildcard CORS and localhost origins;
- every CORS entry is an absolute `http`/`https` origin with no credentials,
  path, query, or fragment; hosted entries must use `https`; normalize
  scheme/host casing, preserve explicit port, and reject duplicates;
- tests pass config explicitly rather than repeatedly mutating global env;
- validation errors name fields but never echo secret values;
- the exported configuration object is immutable;
- `.env.example` contains safe placeholders only.

Acceptance:

- each missing/invalid variable has a focused test;
- valid injected API configuration parses without constructing an app;
  FAST-BOOT-001 exclusively owns the app factory;
- no secret appears in logs, snapshots, thrown messages, or generated docs.

Completion evidence: [FAST-CONFIG-001 report](../../docs/implementation/FAST-CONFIG-001.md)
and [ADR 0004](../../docs/adr/0004-configuration-ownership-and-phase-one-api-parser.md).
