# Coditza implementation status

- Plan version: 4
- Implementation authorization: **GRANTED** — user explicitly requested
  implementation on 2026-07-27; only task-scoped local work is currently
  authorized.
- Current phase: 1 — Foundation and API container
- Active implementation task: PRD-AUTH-001 (next; not started)
- Last verified implementation task: ARC-DESIGN-001
- Last updated: 2026-07-27

## Phase status

| Phase | Status | Gate |
| --- | --- | --- |
| 0 — Plan acceptance | Complete; G0 and PLAN-004 passed | G0 |
| 1 — Foundation and containers | ARC-DESIGN-001 complete; PRD-AUTH-001 next | G1 |
| 2 — Local Supabase and schema | Not started | G2 |
| 3 — Fastify identity/read slice | Not started | G3 |
| 4 — Learning workflows | Not started | G4 |
| 5 — Authoring/admin workflows | Not started | G5 |
| 6 — Full quality and security | Not started | G6 |
| 7 — Hosted development/pre-production | Not started | G7 |
| 8 — Production readiness/release | Not started | G8 |

## Blockers

- No active Phase-1 blocker. PRD-AUTH-001 is a review task limited to a
  provider-neutral mandatory-TOTP client contract; it must not claim an SDK
  mapping, UI, or external configuration.
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

- [ARC-DESIGN-001 report](../docs/implementation/ARC-DESIGN-001.md); the
  accepted ADR, single-owner inventory, composition boundary, RPC coordinator
  map, and negative-fixture strategy exist without application or
  infrastructure artifacts.

## Update rule

Future agents update this file only after objective verification. They must not
change “Implementation authorization” until the user explicitly requests
implementation.
