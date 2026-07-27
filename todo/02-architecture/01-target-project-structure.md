# Target project structure

This is a future target. Do not create it during the planning-only task.

```text
Coditza/
├── apps/
│   └── api/
│       ├── src/
│       │   ├── app.ts
│       │   ├── server.ts
│       │   ├── bootstrap/
│       │   │   └── composition-root.ts
│       │   ├── infrastructure/
│       │   │   ├── config/
│       │   │   ├── http/
│       │   │   ├── observability/
│       │   │   └── supabase/
│       │   │       ├── database.types.ts
│       │   │       └── clients.ts
│       │   ├── shared/
│       │   │   └── kernel/
│       │   └── modules/
│       │       ├── identity/
│       │       ├── curriculum/
│       │       ├── assessment/
│       │       ├── progress/
│       │       └── operations/
│       └── test/
│           ├── unit/
│           ├── integration/
│           └── helpers/
│   └── grader-controller/
│       ├── src/
│       │   ├── controller.ts
│       │   ├── composition-root.ts
│       │   └── adapters/
│       └── test/
├── supabase/
│   ├── config.toml
│   ├── migrations/
│   ├── seed.sql
│   └── tests/
├── docs/
│   ├── adr/
│   ├── api/
│   ├── operations/
│   └── implementation/
├── scripts/
├── todo/
├── .dockerignore
├── .env.example
├── .gitignore
├── .nvmrc
├── compose.yaml
├── Dockerfile
├── package.json
├── package-lock.json
├── python-wasm-runtime.lock.json
└── tsconfig.base.json
```

## Business-module internal shape

Each module may contain only the parts its active use case needs:

```text
modules/<context>/
├── domain/
├── application/
│   ├── ports/
│   └── use-cases/
├── adapters/
│   ├── inbound/http/
│   └── outbound/supabase/
└── public.ts
```

Do not create empty placeholder directories. Create a directory only in the task
that adds its first real file. Persistence mappers stay with the outbound
adapter; HTTP presenters stay with the inbound adapter. Do not create generic
`service.ts`, `repository.ts`, or CRUD abstractions spanning unrelated use
cases.

`apps/grader-controller` is created only by FAST-WASM-001 after ARC-WASM-001
approves the isolated execution architecture. It is an internal worker
entrypoint from the same release, not a public Fastify service. Exact runtime
assets live in a content-addressed, lock-manifest-verified location selected by
ARC-WASM-001; they are not downloaded by a running application.

## TypeScript/ESM contract

- Root and API `package.json` files contain `"type": "module"`.
- The base compiler configuration uses strict mode, `module: "NodeNext"`,
  `moduleResolution: "NodeNext"`, and the ECMAScript target supported by the
  chosen Node LTS.
- The API compiler uses `rootDir: "src"` and `outDir: "dist"`; tests use a
  separate no-emit configuration if needed.
- Relative imports in TypeScript source include the emitted `.js` suffix, for
  example `import { buildApp } from "./app.js"`.
- Runtime starts `dist/server.js`; production does not execute TypeScript
  directly.
- Do not add path aliases unless Node runtime resolution and test resolution are
  configured and proven identically.

## Planned tasks

### ARC-TREE-001 — Create root workspace

- [ ] Add minimal root package metadata with name `Coditza`, `"private": true`,
      `"type": "module"`, and no dependencies/scripts yet.
- [ ] Declare only `apps/*` as npm workspaces.
- [ ] Add only root ignore/editor files that do not require a tool-version
      choice.
- [ ] Do not invent Node/npm/Fastify/TypeScript versions, create `apps/api`,
      add scripts/TypeScript config, install packages, or generate a lockfile;
      FOUND-001 owns those after compatibility selection.

### ARC-TREE-002 — Establish documentation locations

- [ ] As the first local task, create only `docs/implementation/` together with
      this task's first real report; do not create empty documentation folders.
- [ ] Later tasks create ADR, generated API, and operations folders only with
      their first real document.
- [ ] Keep generated OpenAPI in `docs/api/openapi.json`.
- [ ] Keep secrets and runtime output out of `docs/`.

## Later integrated acceptance checks

- After FOUND-001, a clean install from the lockfile succeeds.
- Root scripts work without globally installed Node packages.
- Import boundaries are enforced by lint rules.
- No source file reaches across business modules except through `public.ts`.
- `bootstrap/composition-root.ts` is the sole dependency-wiring location and no
  global repository bag exists inside the API; each approved one-off operator
  script has its own minimal non-importable entrypoint.
