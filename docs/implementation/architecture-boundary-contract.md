# Coditza boundary, composition, and negative-fixture contract

Status: accepted by ARC-DESIGN-001 on 2026-07-27.

This document turns ADR 0001 and the ownership inventory into constraints that
a later implementation can enforce. It intentionally does not choose a
TypeScript lint package, a Node version, Fastify version, or a sandbox launcher;
those choices belong to their gated tasks.

## Deployment graph

Coditza has one public business deployment and one business database.

~~~text
Internet
  |
  v
Fastify API process
  |
  v
Supabase/PostgreSQL
  |
  +-- Supabase Auth is an external identity-provider boundary

Private assessment execution exception:
grader-controller process -> disposable hardened sandbox -> pinned Pyodide worker
                                no network, no secret, no host mount, no socket
~~~

The grader-controller is not a public service, has no listener, owns no
business data, and uses the same reviewed release. It is the only permitted
process/deployment exception for learner Python. No microservice, broker,
separate application database, ORM, generic event bus, distributed cache, or
runtime DI container is authorized.

## Module structure and public contracts

Future files follow this shape only when an active task creates its first real
file.

~~~text
modules/<context>/
  domain/
  application/
    ports/
    use-cases/
  adapters/
    inbound/http/
    outbound/supabase/
  public.ts
~~~

A public.ts file is a narrow application-facing contract. It may export named
interfaces, input/output DTOs, opaque identifier types, and factory-free use
case facades. It must not export a Fastify plugin, TypeBox schema, Supabase
client, generated database type, database mapper, port implementation, domain
entity mutable state, test helper, configuration, or raw credential capability.

The default cross-module import is no import. These are the complete allowed
application-level cross-module contracts:

| Exporter | Consumer | Permitted contract | Permitted use | Forbidden use |
| --- | --- | --- | --- | --- |
| curriculum.public.ts | assessment | PublishedCurriculumReadContract | Read effective module/chapter state needed before an assessment workflow begins. | Content mutation, direct tables, lifecycle use cases, adapters. |
| curriculum.public.ts | progress | PublishedCurriculumReadContract | Read published hierarchy needed to calculate or project learner progress. | Content mutation, direct tables, adapters. |
| assessment.public.ts | progress | AssessmentProgressSourceContract | Read safe immutable assessment source counts/results needed for progress projection/reconciliation. | Answer keys, hidden tests, grading mutation, queue access, adapters. |
| any other public.ts | any other context | None | None without a new ADR and inventory entry. | All imports. |

A durable cross-context write does not add a public.ts contract by default.
The named coordinator uses private SQL collaborators in the one transaction
identified in the ownership inventory. In particular, curriculum publication
may call an assessment private publication validator, and assessment attempts
may call progress recalculation; neither relationship permits a foreign
application adapter import.

## Layer import matrix

An arrow means the source layer may import the target category. Anything absent
is denied.

| Source layer | Own domain | Own application/ports | Own adapters | Target public.ts allowlist | Shared kernel | Infrastructure | Fastify/TypeBox | Supabase/generated DB types |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| shared/kernel | no | no | no | no | yes | no | no | no |
| module domain | yes | no | no | no | yes | no | no | no |
| module application | yes | yes | no | only named read contract | yes | no | no | no |
| inbound HTTP adapter | own DTO/facade only | yes | no | no direct foreign import | platform HTTP utilities | bounded | yes | no |
| outbound Supabase adapter | own port/domain | yes | own mapping only | no direct foreign import | bounded | Supabase boundary only | no | yes |
| module public.ts | own application contract only | yes | no | no re-export of foreign private internals | yes | no | no | no |
| platform infrastructure | no product workflow | no | platform only | no | bounded | yes | bounded | bounded |
| API composition root | no new business behavior | module factories/facades only | yes, for construction only | public facades only | bounded | yes | yes | one raw client only here |
| app.ts | no | registered route facades only | no | no | no | HTTP setup only | yes | no |
| server.ts | no | no | no | no | no | startup/shutdown only | yes | no |
| grader-controller root | no | assessment queue/finalization contract only | its approved adapters | assessment only | runner protocol DTOs only | bounded | no | narrow queue credential remains inside adapter |
| sandbox worker | no Coditza module import | versioned runner protocol only | no | no | protocol primitives only | no | no | no |
| one-off executable | task-specific contract only | minimum needed | its approved adapters only | no ambient import | bounded | bounded | never registered | narrow adapter only |

The matrix is stricter than folder proximity. For example, an HTTP adapter may
not import an adjacent outbound adapter; the composition root injects the
application facade instead.

## Shared-kernel allowlist

The shared kernel is intentionally small:

- opaque IDs and immutable primitive value helpers;
- result/error algebra with no HTTP presentation;
- exhaustive-case and assertion helpers;
- stable, technology-free DTO primitives;
- pure canonicalization/vector helpers only when a product contract explicitly
  requires the same deterministic behavior.

It must not contain a business use case, role rule, content lifecycle rule,
repository, database model, Fastify/TypeBox schema, Supabase helper, logger,
configuration object, dependency registry, or a catch-all utils area. A new
shared-kernel export requires a demonstrated use by at least two contexts and
an ADR/inventory review showing that it is not a hidden product owner.

## Composition-root contract

### Public Fastify API

The future API root is apps/api/src/bootstrap/composition-root.ts. It is the
only long-running API wiring point and must construct in this order:

1. parsed frozen configuration and platform observability;
2. verified-claims adapter;
3. exactly one raw server-secret Supabase client;
4. narrow module-specific Supabase adapters from that client;
5. domain/application use cases by injecting their outbound ports;
6. inbound route facades, each receiving only a use-case facade;
7. Fastify route registration; and
8. reverse-order resource disposal.

The API app factory accepts already constructed or explicitly injected test
dependencies and does not listen. The server entrypoint alone listens and
handles signal-safe shutdown.

Fastify decorations may carry platform HTTP facilities and the request-scoped
verified principal. They may never carry a raw Supabase client, repository bag,
services bag, module adapter collection, mutable global principal, generic
request context, or service locator. Route code validates and presents HTTP;
it neither reconstructs a score nor creates cross-context transactions.

### Private grader-controller

The future grader-controller has a separate composition root. It may construct
only:

1. the assessment queue/finalization adapter;
2. a runtime-manifest reader that verifies locked assets;
3. a hardened outer-sandbox launcher; and
4. a safe metrics adapter.

It may not import Fastify, install a route, call identity/Auth/TOTP code, reuse
the API composition root, expose a database client, dispatch arbitrary
commands, or become a generic worker framework. The sandbox sits outside the
business dependency graph and receives only a versioned secret-free runner
protocol. It receives no network, database, Auth material, server secret,
host mount, container socket, package download path, or unbounded resource
capability.

## Isolated executable contract

| Logical entrypoint | Sole owner | Allowed construction | Required exclusion |
| --- | --- | --- | --- |
| Supabase migration/reset/seed/type generation | platform database kernel | Supabase CLI only | Not imported by the API or a module. |
| First-admin bootstrap | identity | Exact bootstrap facade and narrow system adapter | No Fastify route, plugin, or raw-client reuse. |
| Identity recovery hold | identity | Staged begin, prepare-enrollment, status, complete operator contract | No API import or registration; no public recovery endpoint. |
| Explicit maintenance command | operations | Compile-time allowlisted job facade and confirmed target adapter | No generic shell/command runner or arbitrary job name. |
| Private grader-controller | assessment | Queue, manifest, sandbox, safe metrics adapters | No Fastify listener, identity/Auth/TOTP, or API root. |

Exact filenames stay with the tasks that implement each entrypoint. Every
entrypoint must be non-importable from Fastify by the boundary rule and must
close resources before exit.

## Generic lifecycle RPC conversion

The following logical plan labels are not callable public functions:
create_draft_content, update_draft_content, correct_published_content,
publish_content, archive_content, reorder_content, clone_assessment, and
replace_published_assessment.

They are converted to the module-prefixed closed facade families listed in the
[ownership inventory](architecture-ownership-inventory.md#server-only-rpc-facade-ownership).
A public facade names its owned resource and accepts only its closed input
shape. Private helpers may use static case branches for local reuse, but no
helper can interpolate a resource name into SQL, be called by a user, or cross
the curriculum/assessment boundary through a generic type argument.

## Negative-fixture strategy

ARC-BOUND-001 selects the enforcement tool only after FOUND-001 selects the
toolchain. Regardless of tool, it must implement this behavior:

1. Maintain isolated fixture files that each contain one forbidden import or
   capability edge.
2. Run each fixture independently and assert a non-zero result plus a stable
   rule identifier; a merely failing general TypeScript compile is insufficient.
3. Include one positive control for an allowed own-layer import and one positive
   control for each listed public.ts edge.
4. Run the same rules across every real production source file.
5. Prohibit production-file exemptions, path aliases that bypass the rule, and
   fixture exclusions from the boundary-test command.
6. Fail CI when a fixture unexpectedly passes, a positive control fails, or a
   new source path is outside the rule set.

The required negative cases are:

| Rule ID | Fixture must prove |
| --- | --- |
| BND-001 | shared/kernel cannot import a business module, Fastify, Supabase, or generated database types. |
| BND-002 | module domain/application cannot import Fastify, TypeBox, Supabase, generated database types, or adapters. |
| BND-003 | inbound HTTP adapter cannot import an outbound adapter, raw client, or generated database type. |
| BND-004 | outbound Supabase adapter cannot import a foreign module adapter or HTTP concern. |
| BND-005 | a module cannot deep-import another module; only an allowlisted target public.ts import is legal. |
| BND-006 | a public.ts file cannot re-export an adapter, raw client, generated database type, or foreign private contract. |
| BND-007 | API route/app/server code cannot import an operator executable or grader-controller root. |
| BND-008 | grader-controller cannot import Fastify, identity/Auth/TOTP code, the API root, or a raw-client escape. |
| BND-009 | no Fastify decoration/request type may contain a raw client, repository bag, services bag, or service locator. |
| BND-010 | a one-off executable cannot be registered as a Fastify plugin or reuse the API composition root. |

A source-level import test is not enough for BND-009. FAST-PLUGIN-002 and
ARC-BOUND-002 must also inspect the runtime decoration surface and prove the
raw client is held only by narrow adapters constructed at the composition root.

## Review checklist

ARC-DESIGN-001 accepts this contract only with the following fixed outcomes:

- one public Fastify process and one Supabase/PostgreSQL database;
- exactly five business contexts plus non-business platform health/kernel;
- one unique owner per artifact in the companion inventory;
- only the three listed cross-context application read contracts;
- cross-context writes coordinated by one named owner/RPC, not multiple
  adapters;
- no generic public lifecycle RPC;
- no raw client in Fastify/request state;
- no speculative infrastructure; and
- a later executable negative-fixture suite that proves forbidden edges fail.
