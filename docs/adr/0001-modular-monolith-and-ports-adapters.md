# ADR 0001 — Modular monolith with ports and adapters

- Status: Accepted
- Date: 2026-07-27
- Decision owners: Coditza architecture
- Scope: the public API, business modules, database access, approved operators,
  and the isolated Python verification plane

## Context

Coditza needs atomic publishing, grading, attempt-limit, audit, and progress
workflows over one PostgreSQL database while keeping Supabase Auth separate from
Coditza domain data. A flat route-to-service-to-repository layout would make
data ownership, transaction coordination, and privileged database access
ambiguous. Splitting the MVP into business microservices would add distributed
consistency and operational work without evidence that it is needed.

Untrusted Python is different: executing learner code is a security boundary,
not a business bounded context. It needs a private controller and disposable
outer sandbox, but neither may become a second public backend or data owner.

## Decision

Coditza is a single deployable Fastify modular monolith backed by one
Supabase/PostgreSQL database. Its business contexts are:

1. identity;
2. curriculum;
3. assessment;
4. progress; and
5. operations.

Health is a platform adapter, not a business context. The Python
grader-controller is a private assessment execution component from the same
reviewed release, not a public API or independent domain service.

Each context uses the following inward dependency direction:

~~~text
inbound HTTP adapter -> application use case -> domain policy/entity
outbound Supabase adapter -> application port
composition root -> adapters and use cases
~~~

The only approved cross-context code dependency is a target context's explicit
public.ts contract. A context must not import another context's domain,
application internals, adapters, database mappings, or tests. Shared kernel
code has no business workflow and depends on no business context.

Each cross-context durable write has exactly one named coordinator and one
module-specific public PostgreSQL facade. The coordinator may call
collaborating private SQL helpers inside one transaction; it must not combine
multiple foreign adapters in application code to simulate a transaction.

The Fastify API composition root is the only long-running public API wiring
location. It constructs the claims verifier, one raw server-secret Supabase
client, narrow module adapters, use cases, route facades, and shutdown order.
The raw client is never decorated onto Fastify or a request. Repository bags,
service locators, runtime DI containers, generic repositories, generic CRUD
services, ORMs, event buses, and business microservices are excluded.

The grader-controller has a separate minimal root. It may construct only the
assessment queue adapter, verified runtime-manifest reader, hardened
sandbox-launch adapter, and safe metrics adapter. It has no HTTP listener,
does not import identity/Auth/TOTP code, does not expose a raw client, and
cannot execute arbitrary commands. A sandbox receives only the versioned,
secret-free runner protocol and never a database or network capability.

One-off migration, first-admin bootstrap, recovery-hold, and maintenance
executables have isolated entrypoints. They are neither imported into nor
registered by Fastify and construct only the adapters named in the approved
operator contract.

## Consequences

### Positive

- PostgreSQL transactions remain the authority for current-state checks,
  locking, idempotency, audit records, scoring, and progress mutation.
- Context ownership makes private answer data, Auth material, and grader
  capabilities auditable.
- Pure policies and application use cases can be tested without Fastify or
  Supabase while database-specific transaction rules remain explicit.
- The public API remains one deployable unit for the MVP, avoiding speculative
  distributed infrastructure.

### Costs and constraints

- A context must define a public contract before another context can use it.
- Route grouping is not ownership: catalog and authoring are API groupings
  only.
- No new process, database, queue product, or service boundary may be added
  without measured need and a new ADR covering data ownership, consistency,
  operations, and security.
- The grader-controller and outer sandbox require their own later security and
  deployment approval; this ADR does not approve a launcher or hosted runner.

## Authority boundaries

Supabase Auth owns passwords, sessions, refresh tokens, factor secrets, TOTP
codes, QR/otpauth enrollment material, and access-token issuance. Fastify
validates an AAL2 access token before a domain route and passes only its
verified actor identity to narrow domain adapters. It never accepts, proxies,
stores, or forwards Auth credential material to the Python execution plane.

The inventory and boundary contract accompanying this ADR are normative for
future implementation:

- [artifact ownership inventory](../implementation/architecture-ownership-inventory.md);
- [boundary, composition, and negative-fixture contract](../implementation/architecture-boundary-contract.md).

## Rejected alternatives

| Alternative | Rejection reason |
| --- | --- |
| Flat route/service/repository stack | It obscures context ownership and encourages a generic privileged data layer. |
| Business microservices | The MVP has no measured scaling, team, or failure-isolation evidence to justify distributed consistency and deployment cost. |
| Shared global Supabase client/repository bag | It makes raw privileged access available from request code and defeats narrow adapter boundaries. |
| Generic public lifecycle RPC with a resource-type argument | It becomes a cross-context privilege and validation escape hatch. |
| In-process Python, worker thread, or WASI alone | These do not satisfy the required outer sandbox boundary for untrusted learner code. |

## Review triggers

Review this ADR only when measured load, reliability, team ownership, or
security evidence requires a different deployment boundary, or when a future
approved product feature changes a listed context's ownership. Any review must
preserve a unique owner for every durable artifact and define migration and
consistency handling before code changes.
