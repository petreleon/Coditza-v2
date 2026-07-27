# Coditza implementation status

- Plan version: 3
- Implementation authorization: **NOT GRANTED**
- Current phase: Planning
- Active implementation task: None
- Last verified implementation task: None
- Last updated: 2026-07-27

## Phase status

| Phase | Status | Gate |
| --- | --- | --- |
| 0 — Plan acceptance | In progress until user accepts this plan | G0 |
| 1 — Foundation and containers | Not started | G1 |
| 2 — Local Supabase and schema | Not started | G2 |
| 3 — Fastify identity/read slice | Not started | G3 |
| 4 — Learning workflows | Not started | G4 |
| 5 — Authoring/admin workflows | Not started | G5 |
| 6 — Full quality and security | Not started | G6 |
| 7 — Hosted development/pre-production | Not started | G7 |
| 8 — Production readiness/release | Not started | G8 |

## Blockers

- Implementation has not been requested.
- Hosted environment region/tier/owner, client origins/email mode,
  source/CI/registry, optional staging, and API deployment provider are
  deliberately deferred to their decision deadlines.
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

- Planning files only; no implementation evidence yet.

## Update rule

Future agents update this file only after objective verification. They must not
change “Implementation authorization” until the user explicitly requests
implementation.
