# Domain use cases, ports, and adapters

This is the normative Fastify module-slice contract; generic layered naming
does not override the architecture selected by ARC-DESIGN-001.

## Dependency direction

```text
HTTP adapter -> application use case -> domain policy
                       |
                       `-> outbound port <- Supabase adapter -> named RPC/read
```

## Inbound HTTP adapter responsibilities

- declare schemas and authentication/role pre-handlers;
- extract already validated inputs;
- call one application use case;
- set status/Location header;
- return a DTO.

HTTP adapters contain no Supabase query, grading, state transition, or
persistence-row mapping.

## Application use-case responsibilities

- accept one typed intent and verified principal;
- perform capability-level orchestration independent of Fastify;
- pass server-derived actor context to narrow outbound ports;
- throw typed domain/application errors;
- return domain results independent of Fastify replies.

## Domain-policy responsibilities

- deterministic validation, normalization and calculation that does not require
  current storage;
- no framework, database, clock/network or cross-module adapter import;
- conformance to versioned golden vectors where SQL repeats the rule.

## Outbound port/adapter responsibilities

- each use case owns the smallest required port;
- Supabase adapters perform explicit column-select queries and named RPC calls;
- translate known constraint/RPC failures into typed adapter/application error
  categories;
- return typed records/results;
- no HTTP status, request/reply object, or product permission guess.

## Mapper/presenter responsibilities

- convert database `snake_case` to API `camelCase`;
- whitelist every output field;
- never spread a raw database row into a response;
- never accept/return an answer-key shape in a learner mapper.
- keep persistence mapping in the outbound adapter and HTTP presentation in the
  inbound adapter; one mapper never serves both boundaries.

## Domain module order

1. identity and health;
2. curriculum catalog queries;
3. curriculum authoring/lifecycle;
4. assessment definitions and grading/attempts;
5. progress/completion/reconciliation;
6. identity administration and operations/audit.

For each slice, complete domain policy, application use case and ports,
Supabase adapter, persistence mapper, HTTP adapter/presenter, unit tests,
integration tests, RLS tests, and OpenAPI before starting the next.

## FAST-LAYER-001 — Enforce boundaries

- [ ] Add lint import restrictions so HTTP adapters cannot import Supabase or
      another module's private adapters.
- [ ] Define outbound port interfaces beside the consuming application use case.
- [ ] Inject fake outbound ports into use cases for unit tests.
- [ ] Implement the exact module ownership inventory from ARC-DESIGN-001; admin
      and learner routes remain adapters of the same owning module.
- [ ] Put only stable kernel primitives under `shared`; HTTP pagination/schema
      fragments remain infrastructure HTTP concerns.
- [ ] Avoid circular imports and cross-domain private adapter imports.
- [ ] Permit cross-module imports only through `public.ts` application
      contracts; prohibit another module's adapter import.
- [ ] Use the composition root for all wiring and expose no global repository
      bag/service locator.
- [ ] Use database RPCs for every multi-row atomic workflow; multiple independent
      Supabase client calls are not treated as a transaction.
- [ ] Name one coordinator/transaction port for every cross-module write and
      accept the RPC result as authoritative; Fastify does not re-grade or
      recalculate status.

## Outbound port and Supabase-adapter allowlist

The raw secret client is never injected into a use case or request. Narrow
module-owned ports cover:

- safe catalog/profile reads with explicit projections;
- own-profile update through `update_own_profile`;
- learner completion/attempt/progress functions with server-derived actor ID;
- Python grading reservation/status functions plus a separate controller-only
  claim/finalize adapter and hardened `PythonSandboxPort`;
- staff content mutation/authoring RPCs;
- safe retrieval/update of draft answer specs through staff-authorized RPCs;
- first-admin bootstrap and admin role mutation;
- progress reconciliation/maintenance;
- a bounded readiness probe.

Every method requires actor context or an explicitly documented system context
and has a security test. Do not expose a generic `query` or raw client escape
hatch.
