# Modular-monolith and hexagonal architecture

## Selected architecture

Coditza's public business backend is one deployable Fastify modular-monolith
process and one Supabase/PostgreSQL database. Each business module uses ports
and adapters; deployment boundaries are not confused with code boundaries.
Untrusted Python adds only the private grader-controller process and disposable
sandboxes from the same reviewed release; they own no business data or public
API.

This selection replaces the ambiguous flat
`route -> service -> repository -> Supabase` folder convention. It does not add
business microservices, a message broker, runtime DI container, ORM, or generic
event bus. The private grader-controller/sandbox execution plane is the single
security-boundary exception for untrusted Python, not a new domain owner.

## Why this architecture fits Coditza

- Publishing, grading, attempt limits and progress updates need strong
  PostgreSQL transactions. One process/database keeps those guarantees explicit
  and avoids distributed consistency work before there is measured need.
- Context ownership prevents a single “content service” or generic data layer
  from accumulating every rule.
- Ports and adapters keep Fastify, Supabase and test doubles at the edges, so
  pure policies and use cases are testable without hiding database-specific
  transactional behavior.
- One deployment is operationally appropriate for the MVP; internal boundaries
  still make a later extraction possible if independent scaling, ownership or
  release evidence justifies it.
- No module may be extracted into a service merely for style. Reconsider a
  deployment boundary only with measured load/failure/team-ownership evidence
  and a separate ADR covering data ownership and consistency.

## Bounded contexts and ownership

| Module | Owns | Does not own |
| --- | --- | --- |
| `identity` | profiles, roles, live security holds, first-admin bootstrap, verified principal/AAL policy, own-profile use cases | passwords, TOTP secrets/codes, Supabase sessions |
| `curriculum` | modules, chapters, theory, learner catalog queries, and admin lifecycle for those resources | assessments, attempts, progress |
| `assessment` | exercise/quiz definitions, options, private keys/tests, attempts, Python grading jobs/controller contracts, grading, quiz expiry | chapter progress summaries or Auth/TOTP |
| `progress` | theory completion, chapter/module progress, reconciliation | grading keys or assessment mutation |
| `operations` | audit projections, idempotency storage policy, maintenance/system workflows | learner/editor business decisions |
| platform health | liveness/readiness only | business rules or domain data |

Learner and admin routes are inbound adapters of the owning context.
`catalog`, `authoring`, and `admin` are use-case/API groupings, not additional
data owners.

Known cross-context transactions use this coordinator map:

| Workflow | Public facade/coordinator | Allowed collaborators |
| --- | --- | --- |
| module/chapter/theory create, correction, reorder, publish or archive | `curriculum` | `progress` recalculation and `operations` audit/idempotency helpers |
| exercise/quiz draft, publish, archive, clone or replacement | `assessment` | curriculum ancestor checks, `progress` recalculation and `operations` audit/idempotency helpers |
| exercise submission or quiz start/save/submit/expiry | `assessment` | curriculum publication checks, `progress` recalculation and operations idempotency helpers |
| Python grading reserve/claim/sandbox/finalize/retry | `assessment` | curriculum publication checks, `progress` recalculation and operations safe metrics; sandbox receives no module capability |
| theory completion and progress read/reconciliation | `progress` | curriculum publication/read models and operations audit for reconciliation |
| profile, role, bootstrap or identity security hold | `identity` | operations audit helper |
| idempotency purge | `operations` | none |
| expired-quiz finalization | `assessment` | progress recalculation |
| liveness/readiness | platform health | bounded infrastructure adapter only |

For a write row, a private collaborator is a non-runtime-executable SQL helper
inside the same RPC transaction. For a read-only row, collaboration may instead
use a module-public application query contract. It never means that one
application use case imports another context's private adapter.

Before implementation, every table, private table, public/server RPC, route, and
scheduled job receives exactly one owner in a machine-checked inventory.
Cross-context transactional writes receive one named coordinating use case and
one named PostgreSQL RPC adapter. A use case never imports several foreign
adapters to imitate a transaction.

## Module shape

```text
modules/<context>/
├── domain/
│   ├── entities/
│   ├── value-objects/
│   ├── policies/
│   └── errors.ts
├── application/
│   ├── ports/
│   └── use-cases/
├── adapters/
│   ├── inbound/http/
│   └── outbound/supabase/
└── public.ts
```

Create only directories required by the active feature. Query use cases may use
purpose-built read-model ports; do not force every read through an aggregate or
create generic CRUD repositories.

## Dependency rules

Allowed dependencies point inward:

```text
HTTP adapter ──> application use case ──> domain
Supabase adapter ──implements──────────> application port
composition root ──constructs─────────> adapters + use cases
```

- `domain` imports only its own domain and the minimal shared kernel.
- `application` imports its own domain and ports.
- adapters may import their module's application/domain plus their external
  technology.
- cross-module imports use only the target module's `public.ts` application
  contract.
- `shared` imports no business module and contains no product workflow.
- only infrastructure code imports `@supabase/supabase-js` or generated database
  types; only inbound HTTP adapters import Fastify/TypeBox.
- a persistence mapper and an HTTP presenter are separate objects.
- the raw secret client and a global repository/service bag are never decorated
  onto Fastify or a request.

## API composition root

Inside the long-running Fastify API executable,
`bootstrap/composition-root.ts` is the only place that:

1. constructs the verified-claims adapter and one raw server secret client;
2. constructs module-specific Supabase adapters from that client;
3. injects outbound ports into application use cases;
4. injects only inbound use-case facades into HTTP route adapters;
5. registers module routes with Fastify;
6. owns startup and reverse-order disposal.

Fastify decorations are limited to genuine HTTP/platform facilities and the
request-scoped verified principal. There is no `repositories` or `services`
service locator.

The grader controller has its own minimal composition root. It constructs only
the assessment queue adapter, verified runtime-manifest reader, hardened
sandbox-launch adapter, and safe metrics. It cannot register HTTP, import
identity/Auth/TOTP adapters, expose a raw Supabase client, or execute an
arbitrary command. The disposable sandbox is beyond the domain dependency
graph and communicates only through the versioned secret-free runner protocol.

One-off migration, first-admin, recovery-hold and maintenance operator
executables are not part of the Fastify runtime. Each has one small explicit
entrypoint that constructs only its required adapters, requires the task's
environment/approval confirmations, closes resources, and exits. Such an
entrypoint is never imported into Fastify and cannot become a second API
composition root or a reusable raw-client escape hatch.

SUP-AUTH-003 exclusively owns the staged identity-recovery executable.
OPS-RUNBOOK-001 may invoke the already-reviewed artifact in selected
pre-production but cannot implement or modify it.

## Rule-authority matrix

| Concern | Authority |
| --- | --- |
| HTTP syntax/schema/status/presentation | inbound Fastify adapter |
| user intent and orchestration | one application use case |
| deterministic rule independent of current storage | pure domain policy plus versioned golden fixtures |
| locking, current-state/ownership recheck, idempotency, durable transition, score write, progress mutation | one PostgreSQL RPC transaction |
| SQL/TypeScript duplicated normalization or grading behavior | normative product specification and shared golden vectors |
| Python program execution verdict | pinned server WASM worker inside the approved outer sandbox; database finalization validates digests and derives zero/full points |

Fastify never recomputes or overrides an authoritative score/status returned by
the transaction. PostgreSQL does not format HTTP responses. Module-specific
public RPC facades may share private SQL helpers, but a public generic
type-switched RPC cannot become a cross-context escape hatch.

## ARC-DESIGN-001 — Freeze module ownership and dependency graph

Prerequisites: ARC-TREE-001 and G0.

- [ ] Create an ADR for the modular-monolith/ports-and-adapters decision.
- [ ] Create the exact table/RPC/route/job ownership inventory and reject
      unowned or multiply owned artifacts.
- [ ] Record every allowed cross-module public contract and coordinating
      transaction; default to no cross-module import.
- [ ] Record the layer import matrix and the narrow shared-kernel allowlist.
- [ ] Fix the composition-root contract and prohibit global repository bags,
      service locators and request-bound raw clients.
- [ ] Inventory every allowed one-off executable and its isolated entrypoint;
      prove none is imported or registered by the API.
- [ ] Map current generic lifecycle RPC plans to module-specific public facades
      with private shared helpers where necessary.
- [ ] Define a negative-fixture strategy proving each forbidden import fails.
- [ ] Confirm the design still deploys as one process/database and adds no
      speculative infrastructure.

Evidence is the accepted ADR, ownership inventory, dependency matrix,
composition graph, RPC-coordinator map, and review with no ambiguous owner.
