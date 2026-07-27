# Ordered implementation roadmap

No phase may begin before its previous gate passes. Work on one task ID at a
time. The authoritative per-task status is [TASKS.md](../TASKS.md); update it,
`../STATUS.md`, and `../NEXT.md` only after objective verification.

## Phase 0 — Accept and authorize the plan

1. [ ] PLAN-001 — User accepts or amends fixed decisions and safe defaults.
2. [ ] PLAN-002 — User explicitly authorizes implementation.
3. [ ] PLAN-003 — Verify and record G0.

No code, Supabase, Chrome, package installation, or Docker action before
PLAN-002.

## Phase 1 — Foundation and API container

Execute in this order:

1. [ ] ARC-TREE-002 — create the first implementation-report location/report.
2. [ ] ARC-TREE-001 — minimal root workspace metadata, no version guesses.
3. [ ] ARC-DESIGN-001 — freeze bounded-context ownership, ports/adapters,
   composition root and rule authority.
4. [ ] PRD-AUTH-001 — freeze the mandatory TOTP registration/login/factor
   client contract without claiming a UI.
5. [ ] PRD-WASM-001 — freeze `python_code` package, authoritative grading,
   deterministic verdict, and Auth/TOTP exclusion rules.
6. [ ] FOUND-001 — pinned API runtime/tooling baseline.
7. [ ] ARC-BOUND-001 — enforce the dependency graph with failing negative
   fixtures before any external adapter exists.
8. [ ] FAST-CONFIG-001 — typed fail-fast configuration.
9. [ ] ARC-ENV-001 — configuration implementation acceptance.
10. [ ] FAST-BOOT-001 — canonical app/server/composition-root split.
11. [ ] ARC-BOUND-002 — app/listener boundary acceptance.
12. [ ] FAST-LIVE-001 — dependency-free liveness route.
13. [ ] ARC-DOCKER-001 — local Compose API service.
14. [ ] ARC-DOCKER-002 — disposable container check path.
15. [ ] ARC-DOCKER-003 — production image proof.
16. [ ] QA-STRAT-001 — test harness, Auth helpers and local-environment guard.
17. [ ] Verify and record G1.

Outcome: a minimal tested Fastify process builds and runs through Compose; no
Supabase schema, domain routes, or remote state exists.

## Phase 2 — Local Supabase and database security

Execute in this order:

1. [ ] Resolve DEC-032 and run ARC-WASM-001 — select, threat-model, and pin the
   exact Pyodide/Python assets plus compliant local/hosted outer-sandbox
   launcher; no in-process fallback.
2. [ ] SUP-LOCAL-001 — initialize the CLI-owned local stack.
3. [ ] SUP-LOCAL-002 — migration/reset/seed discipline.
4. [ ] SUP-PRIMITIVES-001 — schemas, extensions, enums, common helpers.
5. [ ] SUP-AUTH-001 — signup profile trigger.
6. [ ] PRD-ROLE-001 — prove default learner creation.
7. [ ] Confirm or amend the documented DEC-030 two-factor safe default and
   record it as resolved; do not start SUP-MFA-001 with this prerequisite open.
8. [ ] SUP-MFA-001 — explicitly enable/prove local Authenticator TOTP and
   sanitized AAL transitions.
9. [ ] SUP-DATA-001 — module/chapter/theory hierarchy.
10. [ ] SUP-DATA-002 — exercises/quizzes/private keys.
11. [ ] SUP-DATA-003 — attempts/completions/progress/audit/idempotency.
12. [ ] ARC-SEC-003 — audit contract acceptance.
13. [ ] SUP-FUNCTIONS-001 — module-owned transactional workflows and helpers.
14. [ ] SUP-WASM-001 — private Python definitions/jobs/evidence plus
    reserve/claim/finalize transactions.
15. [ ] ARC-SEC-002 — database function security/atomicity acceptance.
16. [ ] SUP-BOOTSTRAP-001 — serialized first-admin path.
17. [ ] SUP-AUTH-002 — serialized role-control function.
18. [ ] SUP-AUTH-003 — operator-only identity security hold and recovery-order
    transaction.
19. [ ] SUP-RLS-001 — direct-user denial for both AALs and server-path matrix.
20. [ ] SUP-SEED-001 — deterministic local content/users; factors only through
   Auth test setup.
21. [ ] SUP-TYPES-001 — generated database types.
22. [ ] QA-DB-001 — clean reset/schema/type reproducibility.
23. [ ] QA-RLS-001 — real-token direct Data API denial.
24. [ ] QA-DB-002 — transaction/concurrency cases.
25. [ ] Verify every explicitly listed `DB-*` case in the
    [database test list](../03-supabase/09-database-tests.md) applicable to this
    phase and record G2.

Outcome: local Supabase is reproducible and secure. No hosted project is changed.

## Phase 3 — Fastify identity and safe read slice

Execute in this order:

1. [ ] FAST-PLUGIN-001 — HTTP safeguards.
2. [ ] FAST-PLUGIN-002 — verifier and composition-root-built module adapters.
3. [ ] ARC-SEC-001 — least-privilege server-access acceptance.
4. [ ] FAST-AUTH-001 — authentication/role decorators.
5. [ ] FAST-MFA-001 — require exact AAL2 before profile/use-case access.
6. [ ] FAST-AUTH-002 — fresh-role and request/session-isolation proof.
7. [ ] FAST-ERR-001 — root error/not-found/log-redaction behavior.
8. [ ] ARC-BOUND-003 — fail-closed behavior.
9. [ ] FAST-LAYER-001 — ports/adapters/module-public/composition boundaries.
10. [ ] FAST-PLUGIN-003 — lifecycle/boot/shutdown verification.
11. [ ] FAST-HEALTH-001 — Supabase readiness behavior.
12. [ ] API-CATALOG-001 — identity/curriculum read adapters.
13. [ ] QA-MFA-001 — full local registration and later-login AAL flow.
14. [ ] API-CONTENT-001 — theory/exercise/quiz safe reads.
15. [ ] PRD-ROLE-002 — three-layer authorization acceptance.
16. [ ] QA-API-001 — identity/catalog contract.
17. [ ] QA-API-002 — content contract.
18. [ ] ARC-DOCKER-004 — Compose-to-CLI Supabase connectivity.
19. [ ] ARC-ENV-002 — host/container/environment separation proof.
20. [ ] FAST-OAS-001 — generated OpenAPI drift/leak gate.
21. [ ] Verify and record G3.

Outcome: an authenticated learner traverses
module -> chapter -> theory/exercise/quiz without draft/key leakage.

## Phase 4 — Learning workflows

Execute in this order:

1. [ ] PRD-LEARN-001 — one answer validator/normalizer.
2. [ ] PRD-LEARN-002 — retry-safe idempotency contract.
3. [ ] API-EXERCISE-001 — exercise submissions/history.
4. [ ] API-QUIZ-001 — quiz start/save/read/submit/history.
5. [ ] FAST-WASM-001 — private controller, narrow execution ports, hardened
   server runner orchestration.
6. [ ] API-WASM-001 — Python job reservation/owner polling and explicit
   client-result rejection.
7. [ ] PRD-LEARN-003 — transactional progress/reconciliation contract.
8. [ ] API-PROGRESS-001 — completion and progress reads.
9. [ ] QA-WASM-001 — deterministic, escape/resource, hidden-test, forged-client,
   lease/crash/retry, and Auth/TOTP exclusion proof.
10. [ ] QA-DB-003 — supported plans for implemented catalog, attempt, and progress
   adapters using large synthetic fixtures.
11. [ ] QA-API-003 — learning contract.
12. [ ] QA-E2E-001 — complete learner path.
13. [ ] Verify and record G-WASM, re-run relevant
    QA-UNIT/DB/concurrency/security cases, and record G4.

Outcome: grading is deterministic and retry-safe; progress is explainable.

## Phase 5 — Authoring, publishing, and roles

Execute in this order:

1. [ ] PRD-CONTENT-001 — draft/update/reorder behavior.
2. [ ] PRD-CONTENT-002 — publication behavior.
3. [ ] PRD-CONTENT-003 — archive/clone/replace behavior.
4. [ ] API-ADMIN-001 — exact content/admin routes and audit.
5. [ ] PRD-ROLE-003 — admin role-change acceptance.
6. [ ] API-ADMIN-002 — HTTP role control.
7. [ ] QA-API-004 — admin contract.
8. [ ] QA-E2E-002 — editor authoring path.
9. [ ] QA-E2E-003 — bootstrap/admin role path.
10. [ ] Verify and record G5.

Outcome: editor/admin workflows preserve immutable assessment history and the
last admin.

## Phase 6 — Local release quality, CI, and image

Execute in this order:

1. [ ] QA-SEC-001 — complete security sign-off matrix.
2. [ ] QA-CLIENT-001 — future-consumer/OpenAPI contract review.
3. [ ] OPS-WASM-001 — runtime asset/SBOM/provenance/offline suite and immutable
   promotion invariant.
4. [ ] OPS-CHECK-001 — one provider-neutral clean verification command.
5. [ ] OPS-SOURCE-001 — resolve DEC-024 and record source/CI/registry ADR.
6. [ ] OPS-CI-001 — provider-specific protected CI.
7. [ ] OPS-OBS-001 — local instrumentation/redaction proof.
8. [ ] OPS-ARTIFACT-001 — publish and verify immutable API/controller/sandbox
   image and runtime-manifest digests.
9. [ ] Re-run all static/unit/database/API/contract/E2E/security/image checks
   from a clean revision and record G6.

Outcome: the exact commit and immutable image repeat all local evidence in CI.

## Phase 7 — Hosted development and pre-production

Execute only after each named external decision/approval:

1. [ ] OPS-HOST-001 — resolve DEC-007 and record the exact portable deployment
   boundary/provider, then create/confirm the approved empty development host
   service before any credential binding.
2. [ ] SUP-CHROME-001 — create `Coditza-dev` in Chrome after DEC-018 approval.
3. [ ] Reconfirm DEC-031 and resolve DEC-025 for the actual hosted signup/email
   mode; an earlier-deadline decision cannot be deferred to production.
4. [ ] SUP-CHROME-002 — configure development email/password plus mandatory
   TOTP; DEC-025 controls whether self-service email flows can be signed off.
5. [ ] ARC-ENV-003 — bind development runtime/release identities to the real
   project reference and selected host.
6. [ ] SUP-CHROME-003 — verify the exact development target/configuration
   without applying migrations or deploying an image.
7. [ ] OPS-DEPLOY-DEV-001 — alone apply development migrations, deploy the
   candidate digests, prove the hosted AAL1-deny/TOTP-AAL2 flow, and run the
   synthetic Python verifier smoke in the approved no-network outer sandbox.
8. [ ] Resolve DEC-027. If accepted, execute SUP-CHROME-STAGING-001,
   ARC-ENV-STAGING-001, then OPS-DEPLOY-STAGING-001; otherwise record all three
   as not applicable and use development with isolated synthetic data as
   pre-production.
9. [ ] OPS-REC-001 — confirm platform backup/PITR capability so the recovery
   runbook is provider-specific rather than guessed.
10. [ ] Resolve DEC-029 identity-proof, first-factor-compromise, audit,
    notification and operator approvals, then run OPS-RUNBOOK-001 to author the
    exercise matrix and invoke the existing security-hold recovery executable.
11. [ ] QA-PERF-001 — measure pre-production baselines.
12. [ ] OPS-OBS-PREPROD-001 — bind and safely exercise hosted dashboards and
    alerts for the selected pre-production environment.
13. [ ] Reconfirm DEC-023, then run OPS-MAINT-001 for bounded
    expiry/retention jobs and their alerts.
14. [ ] OPS-UPGRADE-001 — previous-schema-to-candidate compatibility drill.
15. [ ] OPS-ROLLBACK-001 — application rollback/partial rollout drill,
    including the first-release zero-traffic baseline when applicable.
16. [ ] OPS-REC-002 — approved non-production restore drill.
17. [ ] OPS-REC-003 — recurring backup freshness/restore schedule.
18. [ ] Verify hosted security/smoke/observability evidence and record G7.

## Phase 8 — Production approval and release

Execute in this order; Phase 7 never authorizes Phase 8 automatically:

1. [ ] Reconfirm the recorded DEC-017/018/019/020/023/025/026/029/030/031
   outcomes and exact release/Auth/MFA/recovery mode. Resolve only decisions
   whose documented deadline is now; any earlier-deadline decision still open
   means G7 failed and Phase 8 must stop.
2. [ ] Obtain explicit approval for the exact production project/cost/action.
3. [ ] SUP-CHROME-PROD-001 — create/configure `Coditza-prod`; do not migrate,
   deploy, enable operations, or admit traffic.
4. [ ] ARC-ENV-PROD-001 — after separate approval, create/confirm the empty
   closed-traffic production host shell and bind new production-only runtime/
   release identities to the exact project/host/registry.
5. [ ] OPS-DEPLOY-002 — alone run one serialized migration and deploy the
   approved API/controller/sandbox/runtime digests behind a closed traffic
   gate, then run the approved internal AAL1-deny/TOTP-AAL2 and synthetic
   Python-verifier smoke without opening public traffic.
6. [ ] OPS-OBS-PROD-001 — configure and test production dashboards/alerts.
7. [ ] OPS-MAINT-PROD-001 — explicitly enable bounded production schedules.
8. [ ] OPS-REC-PROD-001 — activate backup freshness alerts and recurring restore
   ownership.
9. [ ] OPS-RELEASE-PROD-001 — obtain exact traffic approval, admit traffic, run
   non-destructive smoke, observe the full window, and close/roll back on trigger.
10. [ ] Verify backup, rollback, evidence, status, and release notes; record G8.

Production creation, billing, migration, key rotation, or deployment always
stops for the explicit approval named by its task.
