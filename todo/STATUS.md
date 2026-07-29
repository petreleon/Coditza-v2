# Coditza implementation status

- Plan version: 4
- Implementation authorization: **GRANTED** — user explicitly requested
  implementation on 2026-07-27; only task-scoped local work is currently
  authorized.
- Current phase: 2 — Local Supabase and database security
- Active implementation task: SUP-FUNCTIONS-001 (in progress) — named
  server-only transactional workflow facades, grants, normalization, and proof.
  Its assessment learner-mutation, learner-progress, learner-history,
  staff-authorization primitive, curriculum draft-module, and draft-chapter
  slices are implemented and verified; remaining owner families and real
  concurrency proof are still required.
- Last verified implementation slice: SUP-FUNCTIONS-001 curriculum draft-chapter
  creation facade with protected local verification
- Last updated: 2026-07-29

## Phase status

| Phase | Status | Gate |
| --- | --- | --- |
| 0 — Plan acceptance | Complete; G0 and PLAN-004 passed | G0 |
| 1 — Foundation and containers | Complete; QA-STRAT-001 and G1 passed | G1 |
| 2 — Local Supabase and schema | SUP-LOCAL-001/002, SUP-PRIMITIVES-001, SUP-AUTH-001, PRD-ROLE-001, SUP-DATA-001/002/003, and ARC-SEC-003 complete; SUP-FUNCTIONS-001 is in progress | G2 |
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
- SUP-SMTP-LOCAL-001 is not eligible until the user supplies a Gmail App
  Password through the approved ignored local mechanism. It does not block the
  independent SUP-FUNCTIONS-001 task.

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
- [SUP-LOCAL-001 report](../docs/implementation/SUP-LOCAL-001.md); a pinned
  project-local Supabase CLI completed isolated local start, status, credential
  capture, and stop checks. Its published services were loopback-only, captured
  credentials remained ignored and mode-0600, and no hosted resource, schema,
  Auth flow, SMTP setting, or root Compose value changed.
- [SUP-LOCAL-002 report](../docs/implementation/SUP-LOCAL-002.md); protected
  local migration/reset/seed discipline completed two identical fresh resets
  with exact migration history, deterministic seed evidence, an empty
  public-schema diff and lint result, released shadow-diff port, and no hosted
  mutation or domain schema.
- [SUP-PRIMITIVES-001 report](../docs/implementation/SUP-PRIMITIVES-001.md);
  the hardened owner role, private schema, default-deny privileges, enums, and
  table-independent helpers passed protected local reset, pgTAP, drift, and
  cleanup verification without an application extension, hosted mutation, or
  secret disclosure.
- [SUP-AUTH-001 report](../docs/implementation/SUP-AUTH-001.md); the
  `profiles` projection, fixed-path owner trigger, default learner/fallback,
  cascade/rollback behavior, direct-access denial, and absence of Auth factor
  state passed protected local reset, pgTAP, drift, and cleanup verification.
- [PRD-ROLE-001 report](../docs/implementation/PRD-ROLE-001.md); each product
  requirement for transactional default-learner creation maps to the completed
  local profile migration and protected pgTAP evidence, without claiming MFA
  or Fastify authorization is complete.
- [SUP-DATA-001 report](../docs/implementation/SUP-DATA-001.md); the
  owner-controlled module/chapter/theory hierarchy, initial-draft lifecycle,
  default denial, RLS state, constraints, versions, reorders, and effective
  visibility passed protected local pgTAP/reset/diff/lint evidence without a
  hosted mutation or secret disclosure.
- [SUP-DATA-002 report](../docs/implementation/SUP-DATA-002.md); public
  exercise/quiz definitions and private answer keys passed deterministic local
  resets, primitive/profile/core regressions, 38 assessment assertions,
  public/private diff and lint checks, and the pinned Node 24 foundation gate
  without hosted mutation or secret disclosure.
- [SUP-DATA-003 report](../docs/implementation/SUP-DATA-003.md); learning
  records, immutable attempts, source-derived progress, private idempotency,
  append-only audit, and 28 task assertions passed deterministic local resets,
  all prior regressions, public/private diff and lint checks, and the pinned
  Node 24 foundation gate without hosted mutation or secret disclosure.
- [ARC-SEC-003 report](../docs/implementation/ARC-SEC-003.md); the privileged
  audit contract now uses closed reason codes and safe before/after codes,
  rejects secret/content-bearing categories, denies runtime access, retains
  only anonymized user actors after account deletion, and passed 11 dedicated
  assertions plus all protected local regressions and the foundation gate.
- [SUP-FUNCTIONS-001 slice report](../docs/implementation/SUP-FUNCTIONS-001-slice-01.md);
  the first server-only assessment learner-facade slice adds structured
  idempotency replay, exact safe response schemas, service-role-only grants,
  audit-safe mutations, and matching SQL/TypeScript normalization vectors.
  It does not claim completion of the remaining function families.
- [SUP-FUNCTIONS-001 learner-progress slice report](../docs/implementation/SUP-FUNCTIONS-001-slice-02.md);
  service-role-only theory completion and current-curriculum progress reads
  now have active-profile guards, audited transitions, fresh-learner defaults,
  source fallback for a missing snapshot, and protected local verification.
- [SUP-FUNCTIONS-001 learner-history slice report](../docs/implementation/SUP-FUNCTIONS-001-slice-03.md);
  service-role-only own exercise/quiz history now preserves archived immutable
  definitions, applies owner-only keyset reads, keeps active quiz detail
  start-safe, and projects terminal omitted questions without answer keys.
- [SUP-FUNCTIONS-001 staff-authorization slice report](../docs/implementation/SUP-FUNCTIONS-001-slice-04.md);
  private live-profile role helpers now accept only active editor/admin actors
  for later authoring and reject learner, missing, held, and live-demoted
  profiles without granting runtime access.
- [SUP-FUNCTIONS-001 curriculum draft-module slice report](../docs/implementation/SUP-FUNCTIONS-001-slice-05.md);
  a service-role-only facade now creates one draft root module under a fixed
  position lock, validates exact input, denies held replay, stores only a safe
  ID replay envelope, and appends a sanitized audit transition.
- [SUP-FUNCTIONS-001 curriculum draft-chapter slice report](../docs/implementation/SUP-FUNCTIONS-001-slice-06.md);
  a service-role-only facade now locks a parent module before it appends a draft
  chapter across all sibling states, validates exact input, preserves a safe
  replay after later archive, denies held replay, and appends a sanitized audit
  transition.
- [G1 completion record](08-execution/00-roadmap.md#g1-completion-record);
  Foundation reproducibility is recorded from the accepted architecture/product
  contracts, current checks, Docker evidence, and scope review.

## Update rule

Future agents update this file only after objective verification. They must not
change “Implementation authorization” until the user explicitly requests
implementation.
