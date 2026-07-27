# Coditza implementation status

- Plan version: 4
- Implementation authorization: **GRANTED** — user explicitly requested
  implementation on 2026-07-27; only task-scoped local work is currently
  authorized.
- Current phase: 1 — Foundation and API container
- Active implementation task: ARC-ENV-001 (next; not started)
- Last verified implementation task: FAST-CONFIG-001
- Last updated: 2026-07-27

## Phase status

| Phase | Status | Gate |
| --- | --- | --- |
| 0 — Plan acceptance | Complete; G0 and PLAN-004 passed | G0 |
| 1 — Foundation and containers | FAST-CONFIG-001 complete; ARC-ENV-001 next | G1 |
| 2 — Local Supabase and schema | Not started | G2 |
| 3 — Fastify identity/read slice | Not started | G3 |
| 4 — Learning workflows | Not started | G4 |
| 5 — Authoring/admin workflows | Not started | G5 |
| 6 — Full quality and security | Not started | G6 |
| 7 — Hosted development/pre-production | Not started | G7 |
| 8 — Production readiness/release | Not started | G8 |

## Blockers

- No active Phase-1 blocker. ARC-ENV-001 may accept the one API configuration
  parser through local inventory and separation evidence. It must not add a
  second parser, construct Fastify, routes, a listener, a Supabase client,
  Docker artifact, Python runtime/controller, credentials, or hosted state.
- Exact Vercel team/project/region/tier/owner, client origins/email mode,
  source/CI/registry, optional staging, and any supplemental private grader
  host remain deferred to their named decision deadlines and approvals.
- Actual registration/login screens remain outside this backend plan until
  DEC-006 is changed by a later client request.
- DEC-032 must be resolved by ARC-WASM-001 with a demonstrably hardened
  outer-sandbox launcher; an in-process/worker-thread/WASI-only fallback is
  forbidden.
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

## Update rule

Future agents update this file only after objective verification. They must not
change “Implementation authorization” until the user explicitly requests
implementation.
