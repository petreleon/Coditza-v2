# Authoritative task registry

This is the only task-status index. A task ID is executable only when it appears
as a heading in its linked owner file, except PLAN-001/002/003 which are owned by
the roadmap. `DB-*`, `QA-UNIT-*`, risk IDs, decision IDs, gates, and ordinary
checkboxes are acceptance cases—not separately schedulable tasks.

Allowed statuses are `next`, `not started`, `in progress`, `blocked`, `not
applicable`, and `complete`. Only one row may be `next` or `in progress`.
Changing a row to `complete` requires a task report containing the listed
evidence. `not applicable` requires the exact decision/ADR; it is not completion.

Modes:

- **review**: decisions/specification acceptance, no implementation;
- **local**: repository/local containers only, no hosted mutation;
- **hosted**: changes a non-production external system and needs its task's
  approval/credential safeguards;
- **production**: exact explicit production approval is mandatory.

## Phase 0

| ID | Mode | Hard prerequisite | Owner / permitted scope | Minimum evidence | Status |
| --- | --- | --- | --- | --- | --- |
| PLAN-001 | review | plan delivered | [roadmap](08-execution/00-roadmap.md) | [accepted changes/defaults recorded](08-execution/00-roadmap.md#plan-001--completion-record) | complete |
| PLAN-002 | review | PLAN-001 | [roadmap](08-execution/00-roadmap.md) | [explicit implementation request](08-execution/00-roadmap.md#plan-002--completion-record) | complete |
| PLAN-003 | review | PLAN-002 | [G0](08-execution/02-phase-gates.md) | [G0 checklist + synchronized STATUS/NEXT](08-execution/00-roadmap.md#plan-003--completion-record) | complete |
| PLAN-004 | review | PLAN-003 | [roadmap](08-execution/00-roadmap.md) — reconcile explicit operational directives | [executable Vercel/SMTP task paths + synchronized dependencies](08-execution/00-roadmap.md#plan-004--completion-record) | complete |

## Phase 1

| ID | Mode | Hard prerequisite | Owner / permitted scope | Minimum evidence | Status |
| --- | --- | --- | --- | --- | --- |
| ARC-TREE-002 | local | G0 + PLAN-004 | [target tree](02-architecture/01-target-project-structure.md) — first report/location only | report exists, no empty docs folders | next |
| ARC-TREE-001 | local | ARC-TREE-002 | [target tree](02-architecture/01-target-project-structure.md) — minimal root metadata | name/private/workspace/type, no version guesses | not started |
| ARC-DESIGN-001 | local | ARC-TREE-001 + G0 | [modular architecture](02-architecture/06-modular-hexagonal-architecture.md) — ADR/ownership/dependency contracts | accepted ownership + composition/RPC maps | not started |
| PRD-AUTH-001 | review | ARC-DESIGN-001 | [mandatory MFA](01-product/04-authentication-and-mfa.md) — provider-neutral Auth contract only | ADR + operations/state/error/conditional assurance, no SDK/UI claim | not started |
| PRD-WASM-001 | local | ARC-DESIGN-001 + G0 | [Python exercises](01-product/05-python-code-exercises.md) — package/verdict/determinism contract | canonical package/verdict vectors + server-authority/Auth-exclusion proof | not started |
| FOUND-001 | local | tree + architecture/Auth/Python contracts | [bootstrap](04-fastify/00-bootstrap-and-config.md) — API package/tool versions | version ADR + install/typecheck/build | not started |
| ARC-BOUND-001 | local | FOUND-001 + ARC-DESIGN-001 | [boundaries](02-architecture/00-system-boundaries.md) — import matrix/negative fixtures | every forbidden edge demonstrably fails | not started |
| FAST-CONFIG-001 | local | FOUND-001 | [bootstrap](04-fastify/00-bootstrap-and-config.md) — config module/tests | valid/missing/secret-redaction tests | not started |
| ARC-ENV-001 | local | FAST-CONFIG-001 | [environment contract](02-architecture/02-environments-and-secrets.md) | every variable parsed/typed/frozen | not started |
| FAST-BOOT-001 | local | typed config | [bootstrap](04-fastify/00-bootstrap-and-config.md) — app/server/tests | inject test + signal-safe startup/shutdown | not started |
| ARC-BOUND-002 | local | FAST-BOOT-001 | [boundaries](02-architecture/00-system-boundaries.md) | single factory/listener proof | not started |
| FAST-LIVE-001 | local | app factory | [health](04-fastify/05-openapi-health-and-readiness.md) | no-dependency 200 schema test | not started |
| ARC-DOCKER-001 | local | liveness | [Compose](02-architecture/03-docker-compose.md) — Dockerfile/compose/.dockerignore | config + host liveness + shutdown | not started |
| ARC-DOCKER-002 | local | ARC-DOCKER-001 | [Compose](02-architecture/03-docker-compose.md) — test profile/guide | disposable checks preserve exit codes | not started |
| ARC-DOCKER-003 | local | Docker artifacts | [Compose](02-architecture/03-docker-compose.md) — runtime image | clean non-root image/contents/SIGTERM proof | not started |
| QA-STRAT-001 | local | test scripts/container path | [test strategy](06-quality/00-testing-strategy.md) — test config/helpers | layer separation + remote-URL guard | not started |

## Phase 2

| ID | Mode | Hard prerequisite | Owner / permitted scope | Minimum evidence | Status |
| --- | --- | --- | --- | --- | --- |
| OPS-VERCEL-001 | review | G1 + ARC-DESIGN-001 + PRD-WASM-001 + user Vercel direction | [deployment topology](07-operations/01-deployment-environments.md) — Vercel/supplemental-host ADR only | current capability/topology evidence or explicit smallest decision blocker; no resource | not started |
| ARC-WASM-001 | local | G1 + PRD-WASM-001 + FOUND-001 + OPS-VERCEL-001; owns DEC-032 resolution | [WASM architecture](02-architecture/07-python-wasm-verification.md) — ADR/runtime lock/threat model | exact asset digests + compliant outer-sandbox/protocol proof | not started |
| SUP-LOCAL-001 | local | G1 | [local Supabase](03-supabase/01-local-cli-and-migrations.md) — CLI config | start/status/stop evidence, no remote | not started |
| SUP-LOCAL-002 | local | SUP-LOCAL-001 | [local Supabase](03-supabase/01-local-cli-and-migrations.md) — migrations/seed commands | two clean identical resets | not started |
| SUP-SMTP-LOCAL-001 | local | SUP-LOCAL-001 + SUP-LOCAL-002 + PRD-AUTH-001 + user-provided Gmail App Password at execution | [local Auth SMTP](03-supabase/14-local-smtp.md) — CLI-owned Auth transport only | sanitized local delivery/redaction/ignore proof; root Compose and hosted state unchanged | not started |
| SUP-PRIMITIVES-001 | local | migration discipline | [local Supabase](03-supabase/01-local-cli-and-migrations.md) — primitive migration | schemas/enums/extensions/default grants tests | not started |
| SUP-AUTH-001 | local | primitives | [Auth schema](03-supabase/06-auth-profiles-and-roles.md) — profile trigger migration/tests | learner/default/fallback/cascade tests | not started |
| PRD-ROLE-001 | local | SUP-AUTH-001 | [roles](01-product/01-roles-and-permissions.md) — requirement verification | client role ignored; one learner profile | not started |
| SUP-MFA-001 | local | FOUND-001 + local Auth + profile + PRD-AUTH-001 + SUP-SMTP-LOCAL-001 + DEC-030 | [TOTP MFA](03-supabase/12-mfa-totp.md) — local config/headless Auth flow | sanitized enroll/login AAL transitions + leak scan | not started |
| SUP-DATA-001 | local | Auth/profile primitives | [core schema](03-supabase/02-core-content-schema.md) — hierarchy migration/tests | constraints/indexes/hierarchy tests | not started |
| SUP-DATA-002 | local | core hierarchy | [assessment schema](03-supabase/03-assessment-schema.md) — assessment/private migration/tests | key isolation/definition/immutability tests | not started |
| SUP-DATA-003 | local | assessments | [learning schema](03-supabase/04-learning-progress-schema.md) — learning/audit migration/tests | attempt/progress/privacy constraints | not started |
| ARC-SEC-003 | local | audit table | [security flow](02-architecture/04-data-flow-and-security.md) — audit behavior | append-only sanitized user/system events | not started |
| SUP-FUNCTIONS-001 | local | all owned tables | [functions](03-supabase/05-functions-constraints-indexes.md) — workflow migration/tests | atomicity/normalization/concurrency evidence | not started |
| SUP-WASM-001 | local | SUP-DATA-002 + SUP-DATA-003 + SUP-FUNCTIONS-001 + ARC-WASM-001 | [Python verifier data](03-supabase/13-python-code-verification-data.md) — private definitions/jobs/evidence/RPCs | grants + lease/idempotent-finalize/progress/infrastructure-failure proof | not started |
| ARC-SEC-002 | local | SUP-FUNCTIONS-001 + SUP-WASM-001 | [security flow](02-architecture/04-data-flow-and-security.md) — function grants/contracts | fixed paths + actor rechecks + direct denial | not started |
| SUP-BOOTSTRAP-001 | local | profile/audit/locks | [Auth schema](03-supabase/06-auth-profiles-and-roles.md) — bootstrap script/function/test | zero-admin one-time serialized audit | not started |
| SUP-AUTH-002 | local | bootstrap/role function | [Auth schema](03-supabase/06-auth-profiles-and-roles.md) — role-control tests | last-admin concurrent protection | not started |
| SUP-AUTH-003 | local | FOUND-001 + local Auth + profile/audit/functions + SUP-AUTH-002 | [Auth schema](03-supabase/06-auth-profiles-and-roles.md) — hold function + isolated recovery executable | grants/transitions/partial-resume/audit evidence | not started |
| SUP-RLS-001 | local | complete schema/functions | [RLS/grants](03-supabase/07-rls-policy-matrix.md) — grant/RLS migrations/tests | real anon/user denial + server actor matrix | not started |
| SUP-SEED-001 | local | grants/bootstrap | [seed/types](03-supabase/08-seed-and-generated-types.md) — seed | deterministic learner/editor/admin/content | not started |
| SUP-TYPES-001 | local | final migrations | [seed/types](03-supabase/08-seed-and-generated-types.md) — generated DB types | regeneration produces no diff | not started |
| QA-DB-001 | local | seed/types | [DB quality](06-quality/03-database-and-rls-tests.md) | clean reset/schema/type evidence | not started |
| QA-RLS-001 | local | SUP-RLS-001 + fixtures | [DB quality](06-quality/03-database-and-rls-tests.md) | role/resource allow-deny matrix | not started |
| QA-DB-002 | local | workflow functions | [DB quality](06-quality/03-database-and-rls-tests.md) | deterministic race/rollback tests | not started |

## Phase 3

| ID | Mode | Hard prerequisite | Owner / permitted scope | Minimum evidence | Status |
| --- | --- | --- | --- | --- | --- |
| FAST-PLUGIN-001 | local | G2 | [plugins](04-fastify/01-plugins-and-request-lifecycle.md) — HTTP plugins/tests | limits/CORS/rate/proxy/content-type tests | not started |
| FAST-PLUGIN-002 | local | config + DB types + ARC-BOUND-001 | [plugins](04-fastify/01-plugins-and-request-lifecycle.md) — module adapter factories | raw client isolated; no global repository bag | not started |
| ARC-SEC-001 | local | FAST-PLUGIN-002 | [security flow](02-architecture/04-data-flow-and-security.md) — import/access acceptance | only verifier + narrow secret adapters | not started |
| FAST-AUTH-001 | local | verifier/identity adapter | [Fastify Auth](04-fastify/02-authentication-and-authorization.md) | auth/role decorator matrix | not started |
| FAST-MFA-001 | local | FAST-AUTH-001 + SUP-MFA-001 | [Fastify Auth](04-fastify/02-authentication-and-authorization.md) — AAL2 principal boundary | genuine AAL1 deny/AAL2 allow before profile/use case | not started |
| FAST-AUTH-002 | local | FAST-MFA-001 | [Fastify Auth](04-fastify/02-authentication-and-authorization.md) | fresh role + parallel-user/session isolation | not started |
| FAST-ERR-001 | local | app/Auth | [errors](04-fastify/04-errors-logging-and-security.md) | exact problem/status/redaction tests | not started |
| ARC-BOUND-003 | local | config/Auth/errors | [boundaries](02-architecture/00-system-boundaries.md) | missing/unknown states fail closed | not started |
| FAST-LAYER-001 | local | common Fastify + architecture inventory | [layers](04-fastify/03-domain-use-cases-ports-and-adapters.md) — module slices | ports/adapters/public-contract/composition tests | not started |
| FAST-PLUGIN-003 | local | registered common plugins | [plugins](04-fastify/01-plugins-and-request-lifecycle.md) | boot/auth-failure/shutdown tests | not started |
| FAST-HEALTH-001 | local | Supabase readiness adapter | [health](04-fastify/05-openapi-health-and-readiness.md) | ready failure/recovery/shutdown tests | not started |
| API-CATALOG-001 | local | common Fastify + core data + FAST-MFA-001 | [identity/catalog API](05-api/01-identity-and-catalog.md) — route slice | AAL2 schemas/ports/adapters/routes/security | not started |
| QA-MFA-001 | local | SUP-MFA-001 + SUP-AUTH-003 + FAST-MFA-001 + API-CATALOG-001 | [MFA E2E](06-quality/04-end-to-end-and-security.md) | registration/login/downgrade/hold/leak matrix | not started |
| API-CONTENT-001 | local | catalog + QA-MFA-001 + assessment projections | [content API](05-api/02-chapter-content.md) — route slice | safe content/no-preview/no-key tests | not started |
| PRD-ROLE-002 | local | protected routes + DB denial | [roles](01-product/01-roles-and-permissions.md) | HTTP adapter/use-case/DB boundary proof | not started |
| QA-API-001 | local | API-CATALOG-001 | [API quality](06-quality/02-api-integration-and-contract.md) | identity/catalog runtime contract | not started |
| QA-API-002 | local | API-CONTENT-001 | [API quality](06-quality/02-api-integration-and-contract.md) | content visibility/key-leak contract | not started |
| ARC-DOCKER-004 | local | readiness/read adapter | [Compose](02-architecture/03-docker-compose.md) | host/container URL+issuer connectivity | not started |
| ARC-ENV-002 | local | ARC-DOCKER-004 | [environment contract](02-architecture/02-environments-and-secrets.md) | wrong-remote guard + endpoint separation | not started |
| FAST-OAS-001 | local | all read routes | [health/OpenAPI](04-fastify/05-openapi-health-and-readiness.md) | deterministic validated leak-scanned spec | not started |

## Phase 4

| ID | Mode | Hard prerequisite | Owner / permitted scope | Minimum evidence | Status |
| --- | --- | --- | --- | --- | --- |
| PRD-LEARN-001 | local | G3 + grading functions | [learning rules](01-product/03-learning-and-grading-rules.md) — pure validator | SQL/TS golden vectors + shape matrix | not started |
| PRD-LEARN-002 | local | validator/idempotency table | [learning rules](01-product/03-learning-and-grading-rules.md) — idempotency helper | same-input replay/different-input conflict | not started |
| API-EXERCISE-001 | local | learning rules + exercise RPC | [exercise API](05-api/03-exercise-attempts.md) — route slice | submit/history/security/replay tests | not started |
| API-QUIZ-001 | local | learning rules + quiz RPCs | [quiz API](05-api/04-quiz-attempts.md) — route slice | limit/time/race/terminal replay tests | not started |
| FAST-WASM-001 | local | ARC-WASM-001 + SUP-WASM-001 + FAST-LAYER-001 + FAST-MFA-001 | [WASM runner](04-fastify/06-python-wasm-runner.md) — private controller/ports/adapter | secret-free isolated run + digest/retry/shutdown/backpressure tests | not started |
| API-WASM-001 | local | FAST-WASM-001 + SUP-WASM-001 + API-CONTENT-001 | [Python API](05-api/07-python-code-attempts.md) — reservation/status/safe projection | AAL2/schema/replay/owner/capacity/forged-result tests | not started |
| PRD-LEARN-003 | local | all learning sources | [learning rules](01-product/03-learning-and-grading-rules.md) — progress service/RPC | source/snapshot/reconciliation equality | not started |
| API-PROGRESS-001 | local | exercise/quiz/progress RPC | [progress API](05-api/05-progress.md) — route slice | exact denominator/timestamps/ownership | not started |
| QA-WASM-001 | local | PRD/ARC/SUP/FAST/API-WASM-001 | [WASM quality](06-quality/06-python-wasm-verification.md) — golden/adversarial suite | deterministic double-run + escape/resource/leak/client-trust/queue proof | not started |
| QA-DB-003 | local | implemented catalog/attempt/progress adapters + large fixtures | [DB quality](06-quality/03-database-and-rls-tests.md) | reviewed query plans/index rationale | not started |
| QA-API-003 | local | all learning APIs | [API quality](06-quality/02-api-integration-and-contract.md) | learning runtime/OpenAPI contract | not started |
| QA-E2E-001 | local | learning contract | [E2E quality](06-quality/04-end-to-end-and-security.md) | Compose learner journey evidence | not started |

## Phase 5

| ID | Mode | Hard prerequisite | Owner / permitted scope | Minimum evidence | Status |
| --- | --- | --- | --- | --- | --- |
| PRD-CONTENT-001 | local | G4 + authoring functions | [lifecycle](01-product/02-content-lifecycle.md) — draft service | exact mutation/reorder/version tests | not started |
| PRD-CONTENT-002 | local | draft service | [lifecycle](01-product/02-content-lifecycle.md) — publish service | locked validation/audit/idempotency | not started |
| PRD-CONTENT-003 | local | publish/archive functions | [lifecycle](01-product/02-content-lifecycle.md) — archive/clone/replace service | history/ID-map/position/progress proof | not started |
| API-ADMIN-001 | local | content use cases | [admin API](05-api/06-admin-content-and-roles.md) — exact routes | route matrix/corrections/keys/audit tests | not started |
| PRD-ROLE-003 | local | role function + API Auth | [roles](01-product/01-roles-and-permissions.md) — role service | reason/audit/final-admin behavior | not started |
| API-ADMIN-002 | local | role service | [admin API](05-api/06-admin-content-and-roles.md) — role route | HTTP role matrix/concurrency audit | not started |
| QA-API-004 | local | admin APIs | [API quality](06-quality/02-api-integration-and-contract.md) | authoring/admin contract | not started |
| QA-E2E-002 | local | API-ADMIN-001 | [E2E quality](06-quality/04-end-to-end-and-security.md) | editor build/publish/replace path | not started |
| QA-E2E-003 | local | API-ADMIN-002 | [E2E quality](06-quality/04-end-to-end-and-security.md) | bootstrap/admin role path | not started |

## Phase 6

| ID | Mode | Hard prerequisite | Owner / permitted scope | Minimum evidence | Status |
| --- | --- | --- | --- | --- | --- |
| QA-SEC-001 | local | G5 | [E2E/security](06-quality/04-end-to-end-and-security.md) | full leak/abuse/threat sign-off | not started |
| QA-CLIENT-001 | review | complete OpenAPI | [client contract](06-quality/05-performance-and-client-contract.md) | consumer-note/OpenAPI contract findings resolved | not started |
| OPS-WASM-001 | local | QA-WASM-001 + ARC-WASM-001 | [WASM supply chain](07-operations/07-python-wasm-supply-chain.md) | offline asset/SBOM/provenance/rollback/promotion-invariant proof | not started |
| OPS-CHECK-001 | local | all local checks | [CI](07-operations/00-ci-pipeline.md) — root verification entrypoint | clean/Compose run + cleanup evidence | not started |
| OPS-SOURCE-001 | hosted | OPS-CHECK-001 + user available; owns DEC-024 resolution | [CI](07-operations/00-ci-pipeline.md) — provider ADR only | owner/runner/registry/protection record | not started |
| OPS-CI-001 | hosted | source decision + local check | [CI](07-operations/00-ci-pipeline.md) — provider workflow | protected green revision, no remote DB | not started |
| OPS-OBS-001 | local | complete API | [observability](07-operations/02-observability.md) — metrics/logging | redacted failure/signal evidence | not started |
| OPS-ARTIFACT-001 | hosted | green CI + registry approval | [CI](07-operations/00-ci-pipeline.md) — registry image | digest/SBOM/scan/pull smoke | not started |

## Phase 7

| ID | Mode | Hard prerequisite | Owner / permitted scope | Minimum evidence | Status |
| --- | --- | --- | --- | --- | --- |
| OPS-HOST-001 | hosted | G6 + OPS-SOURCE-001 + OPS-VERCEL-001 + exact creation approval | [deployment](07-operations/01-deployment-environments.md) — Vercel public boundary + approved private-host shell | capability/ownership/cost matrix + service ID | not started |
| SUP-CHROME-001 | hosted | G6 + DEC-018 + approval | [Chrome development](03-supabase/00-chrome-dashboard-setup.md) | healthy `Coditza-dev` metadata | not started |
| SUP-CHROME-002 | hosted | dev project + Auth decisions | [Chrome development](03-supabase/00-chrome-dashboard-setup.md) | saved Auth/issuer evidence or explicit limitation | not started |
| ARC-ENV-003 | hosted | dev project + OPS-HOST-001 + DEC-024 + binding approval | [release credentials](02-architecture/05-release-credentials.md) — development scopes/metadata | sanitized identity/scope/dry-run matrix | not started |
| OPS-VERCEL-ENV-001 | hosted | OPS-VERCEL-001 + OPS-HOST-001 + SUP-CHROME-001/002 + ARC-ENV-003 + exact binding approval | [release credentials](02-architecture/05-release-credentials.md) — Vercel Development/Preview runtime scopes | sanitized Vercel name/scope/masking/target dry-run matrix; no production values | not started |
| SUP-CHROME-003 | hosted | dev/Auth + release identity + OPS-VERCEL-ENV-001 + digest | [Chrome development](03-supabase/00-chrome-dashboard-setup.md) | sanitized exact-target/config preflight, no deployment | not started |
| OPS-DEPLOY-DEV-001 | hosted | host + target preflight + dev identity + OPS-VERCEL-ENV-001 + image digest | [deployment](07-operations/01-deployment-environments.md) | one migration job + digest/readiness/security/smoke | not started |
| SUP-CHROME-STAGING-001 | hosted | DEC-027 approval + G6 | [optional staging](03-supabase/10-chrome-staging.md) | separate project/Auth/config metadata, no deployment | not started |
| ARC-ENV-STAGING-001 | hosted | optional staging project + host + binding/creation approval | [release credentials](02-architecture/05-release-credentials.md) — empty staging host shell + scopes | service ID + separate sanitized target/scope matrix | not started |
| OPS-DEPLOY-STAGING-001 | hosted | optional staging project + identity | [deployment](07-operations/01-deployment-environments.md) | one migration job + separate staging promotion report | not started |
| OPS-REC-001 | hosted | selected project/tier | [recovery](07-operations/03-backup-and-recovery.md) | capability/owner/RPO-RTO comparison | not started |
| OPS-RUNBOOK-001 | hosted | selected pre-production + OPS-REC-001 + DEC-029 accepted | [upgrade drills](07-operations/05-upgrades-rollbacks-and-runbooks.md) | owned dated drafts + exercise matrix + MFA-recovery drill | not started |
| QA-PERF-001 | hosted | selected pre-production deploy | [performance](06-quality/05-performance-and-client-contract.md) | bounded baseline/query evidence | not started |
| OPS-OBS-PREPROD-001 | hosted | selected pre-production deploy + QA-PERF-001 + OPS-OBS-001 + OPS-RUNBOOK-001 + monitoring approval | [observability](07-operations/02-observability.md) — exact pre-production bindings | dashboard/alert/safe-signal + runbook exercise evidence | not started |
| OPS-MAINT-001 | hosted | hosted deploy + scheduler + DEC-023 + OPS-RUNBOOK-001 | [maintenance](07-operations/06-maintenance-jobs.md) | concurrency/backlog/retention + runbook evidence | not started |
| OPS-UPGRADE-001 | hosted | pre-production + prior schema + OPS-RUNBOOK-001 | [upgrade drills](07-operations/05-upgrades-rollbacks-and-runbooks.md) | compatibility/failure/runbook simulation | not started |
| OPS-ROLLBACK-001 | hosted | candidate + previous digest or first-release baseline + OPS-RUNBOOK-001 | [upgrade drills](07-operations/05-upgrades-rollbacks-and-runbooks.md) | timed rollback/zero-traffic/runbook evidence | not started |
| OPS-REC-002 | hosted | recovery capability + OPS-RUNBOOK-001 + approval | [recovery](07-operations/03-backup-and-recovery.md) | measured sanitized restore/runbook drill | not started |
| OPS-REC-003 | hosted | restore drill | [upgrade drills](07-operations/05-upgrades-rollbacks-and-runbooks.md) | freshness alert + recurring schedule | not started |

## Phase 8

| ID | Mode | Hard prerequisite | Owner / permitted scope | Minimum evidence | Status |
| --- | --- | --- | --- | --- | --- |
| SUP-CHROME-PROD-001 | production | G7 + all named decisions + exact approval | [Chrome production](03-supabase/11-chrome-production.md) | approved project/Auth/recovery metadata | not started |
| ARC-ENV-PROD-001 | production | production project + host/registry + exact shell/binding approval | [release credentials](02-architecture/05-release-credentials.md) — empty production host shell + scopes | service ID + approver-stamped target/scope preflight | not started |
| OPS-DEPLOY-002 | production | project + runtime/release/smoke identities + migration/digest approval | [deployment](07-operations/01-deployment-environments.md) | one migration job + closed-traffic readiness/Auth smoke | not started |
| OPS-OBS-PROD-001 | production | production deploy + pre-production observability + monitoring approval | [observability](07-operations/02-observability.md) | alert/dashboard bindings + safe signal test | not started |
| OPS-MAINT-PROD-001 | production | production deploy + pre-production job proof + enable approval | [maintenance](07-operations/06-maintenance-jobs.md) | schedules/limits/alerts/first-result-or-due-time | not started |
| OPS-REC-PROD-001 | production | production deploy + recovery drills + backup approval | [recovery](07-operations/03-backup-and-recovery.md) | freshness/alert/recurring-drill ownership | not started |
| OPS-RELEASE-PROD-001 | production | deploy + production ops activation + exact traffic approval | [release checklist](07-operations/04-release-checklist.md) | smoke/observation/traffic/rollback record | not started |

## Registry synchronization rule

After a verified task:

1. attach the report/evidence path to its row (replace the generic evidence text
   with a link while preserving the requirement);
2. mark only that row `complete`;
3. choose the first unblocked roadmap row as `next`;
4. update `STATUS.md` and `NEXT.md` in the same change;
5. prove there is exactly one `next`, no earlier incomplete prerequisite, and no
   status inferred from merely creating files.
