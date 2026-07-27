# Task dependency map

The roadmap supplies total order. This table highlights hard technical
dependencies; a task also requires its prior phase gate and its exact row in
`../TASKS.md`.

| Task/group | Hard prerequisites | Unlocks |
| --- | --- | --- |
| PLAN-001/002/003 | this plan, user direction | G0 |
| PLAN-004 | G0 + explicit user Vercel/Gmail-SMTP direction | an executable local/hosted operational path |
| ARC-TREE-001/002 | G0 + PLAN-004 | FOUND-001 and evidence locations |
| ARC-DESIGN-001 + PRD-AUTH-001 + PRD-WASM-001 | tree + G0 | module design + provider-neutral Auth and Python-verifier product contracts |
| FOUND-001 | tree + architecture/Auth/Python contracts | config, boundary tests, app, containers |
| ARC-BOUND-001 | FOUND-001 + architecture matrix | all production module/adapters |
| FAST-CONFIG + ARC-ENV-001 | FOUND-001 | dependency construction |
| FAST-BOOT + ARC-BOUND-002 + FAST-LIVE | typed config | Compose API |
| ARC-DOCKER-001/002/003 + QA-STRAT-001 | liveness + app factory + local test harness | G1/local runtime |
| OPS-VERCEL-001 | G1 + architecture/Python contracts + user Vercel direction | reviewed public-API/private-grader deployment topology |
| ARC-WASM-001 | G1 + PRD-WASM-001 + FOUND-001 + OPS-VERCEL-001; owns DEC-032 resolution | exact runtime manifest + compliant sandbox boundary |
| SUP-LOCAL-001/002 | G1 + Docker engine | migrations/schema |
| SUP-SMTP-LOCAL-001 | CLI local stack + Auth contract + user-provided Gmail App Password | local Auth delivery proof; no root Compose SMTP |
| SUP-PRIMITIVES-001 | local migration discipline | Auth/content objects |
| SUP-AUTH-001 + PRD-ROLE-001 | `app_role`, private/public schemas | user-owned rows |
| SUP-MFA-001 | local Auth + profile + client contract + local SMTP proof | genuine AAL fixtures/Fastify MFA |
| SUP-DATA-001 | primitives/auth actor columns | assessments |
| SUP-DATA-002 | content hierarchy/private schema | grading/attempts |
| SUP-DATA-003 | assessment definitions | audit/idempotency/progress |
| SUP-WASM-001 | assessment/learning tables + functions + ARC-WASM-001 | private Python jobs/evidence and server-only reserve/claim/finalize |
| SUP-FUNCTIONS + ARC-SEC-002/003 | every owned table/private key | safe transactions |
| SUP-BOOTSTRAP + SUP-AUTH-002 | profile/audit/function primitives | admin fixtures |
| SUP-AUTH-003 | profile/audit/functions + role control | immediate Coditza recovery hold |
| SUP-RLS-001 | all tables/functions/roles | server adapter tests |
| SUP-SEED/TYPES | complete migrations/grants/bootstrap path | DB/API tests |
| QA-DB-001/002 + QA-RLS | seed/types/functions | G2/Fastify domain access |
| FAST-PLUGIN-001/002 | config + generated DB types + import boundaries | Auth/module adapters |
| ARC-SEC-001 + FAST-AUTH-001 + FAST-MFA-001/FAST-AUTH-002 | verifier, local MFA and identity adapter | AAL2-protected routes |
| FAST-ERR/LAYER/BOUND | app/Auth/common schemas | stable route slices |
| API-CATALOG + QA-MFA-001 | common Fastify + core content + AAL2 | API-CONTENT |
| API-CONTENT | catalog + assessment safe projections | learning routes |
| ARC-DOCKER-004 + ARC-ENV-002 | readiness + catalog adapter | G3 |
| PRD-LEARN-001/002 | DB functions + common errors | exercise/quiz routes |
| API-EXERCISE/QUIZ | grading/idempotency RPCs | progress |
| FAST-WASM-001 | SUP-WASM-001 + Fastify layers/MFA + ARC-WASM-001 | authoritative private grader controller |
| API-WASM-001 | FAST-WASM-001 + content/idempotency contracts | Python reservation/polling |
| QA-WASM-001 | PRD/ARC/SUP/FAST/API-WASM-001 | G-WASM/G4 |
| PRD-LEARN-003 + API-PROGRESS | all learning sources | learner E2E/G4 |
| QA-DB-003 | implemented catalog/attempt/progress adapters + large fixtures | G4/query-plan evidence |
| PRD-CONTENT-001/002/003 | content RPCs + audit | API-ADMIN-001 |
| PRD-ROLE-003 | role RPC + bootstrap | API-ADMIN-002 |
| API-ADMIN tasks | protected authoring RPCs | editor/admin E2E/G5 |
| OPS-CHECK-001 | every local check | CI |
| OPS-WASM-001 | QA-WASM-001 + pinned runtime assets | G6 verifier supply-chain evidence |
| OPS-SOURCE-001 | OPS-CHECK-001 + user availability; resolves DEC-024 | provider CI/registry |
| OPS-CI-001 | source decision + local command | immutable artifact |
| OPS-ARTIFACT-001 | green CI + registry authorization | hosted deploy |
| OPS-HOST-001 | G6 + OPS-SOURCE-001 + OPS-VERCEL-001 + scoped creation approval | exact Vercel public boundary and approved private-host shell |
| SUP-CHROME-001/002 | G6 + hosted project/Auth decisions | real development target |
| ARC-ENV-003 | dev project + selected host + binding authorization | dev target preflight |
| OPS-VERCEL-ENV-001 | Vercel topology + host + dev Auth/identity + binding approval | masked Development/Preview API runtime binding |
| SUP-CHROME-003 | dev project/Auth/identity + Vercel env binding + digest | development deployment |
| OPS-DEPLOY-DEV-001 | hosted dev + release identity + Vercel env binding + digest | pre-production drills |
| optional staging Chrome -> identity -> deploy | DEC-027 approval + dev evidence | optional staging drills |
| OPS-REC-001 | selected project/tier | provider-specific recovery facts |
| OPS-RUNBOOK-001 | selected pre-production + recovery facts + DEC-029 | assigned exercise matrix + MFA-recovery drill |
| QA-PERF + OPS-OBS-PREPROD-001 | selected pre-production + local instrumentation + runbook matrix | hosted baselines/dashboards/alerts |
| OPS-MAINT/UPGRADE/ROLLBACK | hosted deployment + assigned runbooks | exercised operational rows |
| OPS-REC-002/003 | recovery capability + assigned runbook + approved target | restore/freshness evidence for G7 |
| SUP-CHROME-PROD-001 | G7 + explicit production approval/decisions | production identity binding |
| ARC-ENV-PROD-001 | exact production project + host/registry + shell/binding approval | empty closed-traffic service + production scopes |
| OPS-DEPLOY-002 | production identity + reviewed migration/digest | production ops activation |
| OPS-OBS/MAINT/REC-PROD | closed-traffic deploy + exact activation approvals | traffic admission |
| OPS-RELEASE-PROD-001 | all production ops active + exact traffic approval | G8 |

## Hard blockers

- No application file before PLAN-002 and G0.
- No domain route before migrations, direct-user denial, generated types, and
  common error/auth behavior plus genuine AAL1-deny/AAL2-allow proof.
- No external adapter before ARC-BOUND-001 proves every forbidden import edge.
- No Coditza domain access at `aal1`; registration/login TOTP calls go only to
  Supabase Auth.
- No privileged mutation before verified actor propagation and database role/
  ownership recheck.
- No attempt route before private keys and atomic grading functions.
- No `python_code` publication/reservation before ARC-WASM-001 and SUP-WASM-001;
  no authoritative result before FAST/API/QA-WASM-001 and G-WASM.
- No client/browser score, verdict, tests, actor, definition, or runtime choice
  may enter finalization.
- No Python runner fallback to Fastify/in-process code, a Node worker thread,
  Node WASI alone, or a container-engine socket mounted in API/controller.
- No ARC-WASM-001 launcher selection before OPS-VERCEL-001 records whether the
  user-required Vercel public API topology needs an explicitly approved private
  runner host.
- No grader deployment on a host that cannot prove disposable no-network,
  secret-free, non-root, read-only, resource-limited outer sandboxes.
- No Auth/TOTP operation or material may enter a Python grading process.
- No progress endpoint before exercise/quiz finalization is correct.
- No remote migration before clean local database/security gates.
- No provider-specific CI before DEC-024 and OPS-SOURCE-001.
- No hosted credential use before the matching ARC-ENV-003,
  ARC-ENV-STAGING-001, or ARC-ENV-PROD-001 task.
- No Vercel Development/Preview runtime binding before OPS-VERCEL-ENV-001; no
  Vercel Production binding before ARC-ENV-PROD-001 and exact approval.
- No hosted Python verifier deployment before OPS-WASM-001 and exact immutable
  API/controller/sandbox/runtime digests exist.
- No optional staging project before DEC-027 approval.
- No production project or deployment before G7 and exact explicit approval.
- No production traffic before the production observability, maintenance,
  recovery, and traffic-approval tasks pass.

## Parallel work rule

Only tasks with no shared files and all prerequisites satisfied may run in
parallel. Merge one result at a time and rerun the shared gate afterward.
Database migrations, route registry, package manifests/lockfile, Compose,
generated OpenAPI/types, architecture ownership inventory/composition root, and
deployment state are serialization points.
