# Coditza implementation status

- Plan version: 4
- Implementation authorization: **GRANTED** — user explicitly requested
  implementation on 2026-07-27; only task-scoped local work is currently
  authorized.
- Current phase: 2 — Local Supabase and database security
- Active implementation task: SUP-LOCAL-001 (next; local Supabase CLI setup)
- Last verified implementation task: ARC-WASM-001 local Python/WASM public proof
- Last updated: 2026-07-27

## Phase status

| Phase | Status | Gate |
| --- | --- | --- |
| 0 — Plan acceptance | Complete; G0 and PLAN-004 passed | G0 |
| 1 — Foundation and containers | Complete; QA-STRAT-001 and G1 passed | G1 |
| 2 — Local Supabase and schema | SUP-LOCAL-001 next; ARC-WASM-001 local public proof complete | G2 |
| 3 — Fastify identity/read slice | Not started | G3 |
| 4 — Learning workflows | Not started | G4 |
| 5 — Authoring/admin workflows | Not started | G5 |
| 6 — Full quality and security | Not started | G6 |
| 7 — Hosted development/pre-production | Not started | G7 |
| 8 — Production readiness/release | Not started | G8 |

## Blockers

- Exact Vercel team/project/region/tier/owner, client origins/email mode,
  source/CI/registry, optional staging, and the provider for the required
  private execution plane remain deferred to their named decision deadlines and
  approvals. ADR 0005 does not select any of them.
- Actual registration/login screens remain outside this backend plan until
  DEC-006 is changed by a later client request.
- DEC-032 has an accepted local public-proof boundary in ADR 0006. The
  authoritative protected controller/hosted-equivalence portion remains
  deferred to its named database/controller/QA/OPS tasks; an
  in-process/worker-thread/WASI-only fallback remains forbidden.
- Production self-service signup remains blocked until DEC-029 defines and
  approves lost-all-factors recovery.

## Open decisions

See `00-control/02-open-decisions.md`. Safe defaults may be used only according
to the deadlines in that file.

## Non-secret evidence

- [PRD-AUTH-001 report](../docs/implementation/PRD-AUTH-001.md); the direct
  Supabase Auth mandatory-TOTP ADR and provider-neutral state/error/AAL2
  contract exist without a client, SDK mapping, or external configuration.
- [PRD-WASM-001 report](../docs/implementation/PRD-WASM-001.md); the canonical
  Python source-package/verdict vectors, authoritative grading semantics, and
  Auth/TOTP exclusion contract exist without a runtime, launcher, or external
  configuration.
- [FOUND-001 report](../docs/implementation/FOUND-001.md); the checksum-verified
  Node 24.18.0/npm 11.16.0 private Fastify/TypeScript workspace, exact lockfile,
  strict ESM seams, and clean-install/typecheck/test/build evidence exist
  without application behavior or external state.
- [ARC-BOUND-001 report](../docs/implementation/ARC-BOUND-001.md); exact
  dependency-cruiser 18.1.0 rules enforce BND-001 through BND-010, with 63
  independently failing negative fixtures, four legal positive controls, and
  a clean complete API source scan under Node 24.18.0/npm 11.16.0.
- [FAST-CONFIG-001 report](../docs/implementation/FAST-CONFIG-001.md); one
  injected, immutable TypeBox API configuration parser validates all API-owned
  settings with safe error redaction, 136 focused tests, and no Fastify,
  Supabase-client, network, or hosted behavior.
- [ARC-ENV-001 report](../docs/implementation/ARC-ENV-001.md); all 33
  API-owned values are traced to one parser/schema/output/test contract, with
  hardened hosted CORS/loopback behavior, controller-only exclusion, 147 tests,
  and no external state.
- [FAST-BOOT-001 report](../docs/implementation/FAST-BOOT-001.md); one
  listener-free injected Fastify factory, frozen no-op composition boundary,
  ready-before-listen lifecycle, safe bounded shutdown, 154 tests, and no
  external state.
- [ARC-BOUND-002 report](../docs/implementation/ARC-BOUND-002.md); AST-backed
  one-factory/one-listener ownership, composition-leak regression protection,
  154 tests, and no external state.
- [FAST-LIVE-001 report](../docs/implementation/FAST-LIVE-001.md); one closed,
  dependency-free `GET /health/live` response, listener-free injection proof,
  155 tests, and no external state.
- [ARC-DOCKER-001 report](../docs/implementation/ARC-DOCKER-001.md); pinned
  non-root development image, ignored build context, Compose configuration,
  host liveness, source reload, graceful shutdown, and exact-project cleanup
  passed using synthetic local configuration.
- [ARC-DOCKER-002 report](../docs/implementation/ARC-DOCKER-002.md); isolated
  non-root/read-only/no-network Compose checks passed format, lint, typecheck,
  155 tests, boundary verification, build, exact nonzero exit propagation, and
  exact-project cleanup using safe placeholder configuration.
- [ARC-DOCKER-003 report](../docs/implementation/ARC-DOCKER-003.md); the final
  no-cache production image contains compiled production output only, has no
  source maps or excluded inputs, runs non-root/read-only with bounded tmpfs,
  serves loopback liveness, exits cleanly on SIGTERM, and leaves no disposable
  runtime resources.
- [QA-STRAT-001 report](../docs/implementation/QA-STRAT-001.md); explicit
  Vitest layer separation, deterministic in-memory Auth helpers, no-network
  local-target guard, sanitized ignored reports, 177 unit tests, and a
  read-only/no-network Compose checks proof now exist without Supabase or
  hosted state.
- [OPS-VERCEL-001 report](../docs/implementation/OPS-VERCEL-001.md) and
  [ADR 0005](../docs/adr/0005-vercel-public-api-and-private-grader-topology.md);
  official Vercel evidence now accepts Vercel for the public Fastify API while
  requiring an unselected, later-approved private execution plane. No hosted
  resource, secret, or billing action occurred.
- [ARC-WASM-001 report](../docs/implementation/ARC-WASM-001.md) and
  [ADR 0006](../docs/adr/0006-local-python-wasm-reference-proof.md); exact
  Pyodide/image assets and a hardened Docker public-proof runner passed local
  adversarial checks. It creates neither a controller nor an authoritative
  private-test/finalization path, and it selects no hosted provider.
- [G1 completion record](08-execution/00-roadmap.md#g1-completion-record);
  Foundation reproducibility is recorded from the accepted architecture/product
  contracts, current checks, Docker evidence, and scope review.

## Update rule

Future agents update this file only after objective verification. They must not
change “Implementation authorization” until the user explicitly requests
implementation.
