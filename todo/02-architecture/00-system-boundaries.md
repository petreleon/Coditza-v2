# System boundaries

## Component flow

```text
Client
  |-- signup/confirm/password/TOTP/session --> Supabase Auth (publishable key)
  |-- Bearer aal2 access token ------------> Fastify HTTP adapter
                                               |-- verify token/aal2/role
                                               |-- application use case
                                               |-- outbound port
                                               |-- module Supabase adapter
                                               |-- named server-only RPC/read
                                               `-- structured logs/metrics

Chrome (operator only) ----------> Supabase Dashboard
Supabase CLI (developer/CI) -----> local Supabase Docker stack / linked migrations
Docker Compose -----------------> Fastify API and, after ARC-WASM-001,
                                   private grader-controller test runtime
Private grader controller ------> Supabase job RPCs
                                   `--> disposable outer sandbox
                                          `--> pinned Pyodide worker
```

An `aal1` token may call Supabase Auth enrollment/challenge APIs directly but
cannot enter a Coditza domain HTTP adapter.

## Responsibility matrix

| Component | Owns | Must not own |
| --- | --- | --- |
| Client | Supabase Auth flow state, session UI, rendering, sending answers | Domain authorization, grading, persistence of TOTP secrets |
| Supabase Auth | Passwords, TOTP factors, challenges, sessions, token issuance | Coditza roles/content/grading |
| Fastify inbound adapters | HTTP schema, auth/AAL/role pre-handlers, status/DTO mapping | SQL, domain policy, raw Auth bodies |
| Application use cases | Intent, orchestration, outbound port invocation, typed error translation | Fastify replies or Supabase client calls |
| Pure domain policy | Deterministic rules independent of current storage | HTTP, SQL, framework imports |
| Supabase outbound adapters | Explicit reads and named RPC calls, persistence mapping | Product decisions or HTTP formatting |
| PostgreSQL RPCs | Locks, current-state/ownership recheck, idempotency, grading/transition/progress transaction | End-user token verification or HTTP formatting |
| Grader controller | Claiming leased Python jobs, validating runtime/result digests, launching one sandbox, finalizing/retrying through narrow RPCs | Public HTTP, Auth/TOTP, business ownership, arbitrary commands |
| Python sandbox worker | Running one source/test package with pinned assets and hard limits | Authentication, Supabase/network/secrets, durable score/progress, trusting client results |
| Composition root | Constructing and injecting adapters/use cases | Business behavior or request state |
| Chrome Dashboard | Hosted project/settings inspection and approved configuration | Untracked schema authoring |
| Supabase CLI | Local stack, migrations, seed, tests, types, deploy | API process |
| Docker Compose | Repeatable API/controller runtime and local verifier-isolation tests | A duplicate Supabase/Postgres stack or a weaker substitute for the per-run outer sandbox |

## Architectural tasks

### ARC-BOUND-001 — Enforce module boundaries

- [x] Implement the import matrix from
      [the selected architecture](06-modular-hexagonal-architecture.md) before
      any Supabase adapter is added.
- [x] Domain/application code cannot import Fastify, TypeBox,
      `@supabase/supabase-js`, generated database types, or adapters.
- [x] Inbound HTTP adapters cannot access Supabase or outbound adapter internals.
- [x] Cross-module imports resolve only to the target module's `public.ts`;
      deep imports fail.
- [x] `shared` imports no module, and adapters cannot import another module's
      private adapter internals.
- [x] Add one negative fixture for every forbidden edge and prove lint/test
      fails when each edge is enabled.
- [x] Re-run the rules against every real module slice; no allowlist may name an
      individual production file merely to bypass the graph.

Completion evidence: [ARC-BOUND-001 report](../../docs/implementation/ARC-BOUND-001.md).

### ARC-BOUND-002 — Separate app construction from listening

- [ ] `buildApp({ config, dependencies }: BuildAppOptions)` is the single app
      factory signature and creates/returns a Fastify instance.
- [ ] `server.ts` is the only file that listens on a network port.
- [ ] Tests use `buildApp` and `fastify.inject`.
- [ ] Shutdown closes Fastify and dependency resources exactly once.

### ARC-BOUND-003 — Fail closed

- [ ] A missing/invalid token never becomes an anonymous domain request.
- [ ] Failure to load a profile role denies protected access.
- [ ] A missing/invalid secret client fails API startup and readiness rather than
      leaving a partially authorized server.
- [ ] Unknown content state and attempt state values produce an internal error
      and alert, not permissive behavior.
