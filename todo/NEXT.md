# Next task

The next implementation task is:

**ARC-BOUND-001 — Enforce module boundaries.**

Prerequisites already verified: G0, ARC-DESIGN-001, and FOUND-001 are complete.
This is the sole task allowed to change implementation files now.

Read first:

1. `README.md`
2. `TASKS.md`
3. `STATUS.md`
4. `00-control/01-fixed-decisions.md`
5. `00-control/03-execution-protocol.md`
6. `02-architecture/00-system-boundaries.md`
7. `02-architecture/01-target-project-structure.md`
8. `02-architecture/06-modular-hexagonal-architecture.md`
9. `04-fastify/00-bootstrap-and-config.md`
10. `06-quality/00-testing-strategy.md`
11. `08-execution/00-roadmap.md`
12. `08-execution/01-dependency-map.md`
13. `08-execution/03-handoff-protocol.md`
14. `../docs/adr/0001-modular-monolith-and-ports-adapters.md`
15. `../docs/adr/0003-node-fastify-toolchain-baseline.md`
16. `../docs/implementation/architecture-boundary-contract.md`
17. `../docs/implementation/architecture-ownership-inventory.md`
18. `../docs/implementation/FOUND-001.md`

Implement only the architecture import matrix and its reproducible evidence:

- Select and lock one compatible dependency-graph enforcement tool; retain
  ESLint for code style rather than treating a generic TypeScript failure as a
  boundary proof.
- Give every forbidden case its stable `BND-001` through `BND-010` rule ID.
  Each isolated negative fixture must contain one forbidden edge and must be
  verified independently as a non-zero failure with that exact ID.
- Add positive controls for one legal own-layer import plus the three allowed
  public contracts: curriculum -> assessment, curriculum -> progress, and
  assessment -> progress.
- Run the same rules over every `apps/api/src` production file. New source paths
  outside the configured graph, per-production-file exemptions, TypeScript path
  aliases that bypass the graph, and fixture exclusions from the boundary
  command must fail.
- Keep fixtures test-only. Do not create empty real module directories merely
  to make the test graph exist.
- Record a task report and synchronize the task registry only after all
  negative and positive cases, production scan, clean install, formatting,
  lint, typecheck, and diff/secret-safety checks pass.

Do not add configuration parsing, Fastify construction/routes/listening,
Supabase clients/adapters, Docker/Compose, a Python runtime/controller, real
business modules, credentials, Chrome actions, SMTP, Vercel resources, or any
hosted state. BND-009 runtime decoration proof and BND-010 runtime registration
proof remain explicitly owned by FAST-PLUGIN-002 and ARC-BOUND-002; this task
may prove their source-level import/capability fixtures only.
