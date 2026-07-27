# Ordered implementation roadmap

No phase may begin before its previous gate passes. Work on one task ID at a
time. The authoritative per-task status is [TASKS.md](../TASKS.md); update it,
`../STATUS.md`, and `../NEXT.md` only after objective verification.

## Phase 0 — Accept and authorize the plan

1. [x] PLAN-001 — User accepts or amends fixed decisions and safe defaults.
2. [x] PLAN-002 — User explicitly authorizes implementation.
3. [x] PLAN-003 — Verify and record G0.
4. [x] PLAN-004 — Reconcile the user-required Vercel deployment, Vercel
   environment configuration, and local Gmail SMTP paths before implementation.

No code, Supabase, Chrome, package installation, or Docker action before
PLAN-002. PLAN-004 has resolved the newly identified task-path gaps; each
future external action still retains its named approval and secret safeguards.

## PLAN-001 — Completion record

- Outcome: COMPLETE
- Environment: NONE
- Date: 2026-07-27
- Agent/person: Codex, recording the user's direction
- Authorization checked: Review-only task; no implementation action was taken.
- Prerequisites/gate checked: Plan delivered; `PLAN-001` was the sole `next`
  task; the repository had no tracked or untracked implementation changes.
- Decisions/defaults used:

- Product name remains `Coditza`; the public source repository is
  `petreleon/Coditza-v2`.
- Learner-facing course material is Romanian (`ro-RO`), beginning with
  `Arhitectură software în Python`.
- The backend remains a TypeScript/Fastify modular monolith with Supabase for
  PostgreSQL and Auth, using the bounded contexts and ports/adapters rules in
  the fixed decisions.
- Password authentication is followed by mandatory Authenticator-app TOTP for
  registration completion and every later login; Coditza domain routes require
  `aal2`.
- Python exercises use a pinned, self-hosted Python-on-WebAssembly runtime; a
  server-side run in an independently hardened outer sandbox is authoritative.
- Vercel is the requested eventual deployment destination. Its compatibility
  with the public Fastify API and the separate private grader remains a later
  deployment decision; this record creates no Vercel resource or commitment.
- Local SMTP is intended to use `petreleonardos@gmail.com` when the dedicated
  SMTP task is eligible. A Gmail App Password is required then and has not
  been requested, stored, or recorded here.

### Scope

- Intended: record acceptance of the fixed architecture, MFA, language, WASM,
  deployment-intent, and SMTP-safe-default decisions.
- Explicitly excluded: application code, package installation, Docker,
  Supabase, Chrome, Vercel, SMTP, or other external-state work.

### Changed

- `todo/08-execution/00-roadmap.md`: this planning-review record and task
  checkbox.
- `todo/TASKS.md`, `todo/STATUS.md`, and `todo/NEXT.md`: synchronized task
  state.

### Verification

- Read the fixed decisions, open decisions, execution protocol, roadmap, G0
  gate, architecture, MFA, and Python/WASM contracts.
  - Result: PASS
  - Non-secret evidence: the user's stated requirements agree with the
    recorded defaults; undecided remote/cost-sensitive choices remain deferred.
- `git status --short --branch`
  - Result: PASS
  - Non-secret evidence: `main...origin/main` with no user-owned working-tree
    changes before this review record.

### External actions

- NONE. Earlier explicitly requested GitHub repository setup is outside this
  review task and is not used as authorization for future hosted work.

### Deviations/ADRs

- This review record deliberately lives in the roadmap. ARC-TREE-002 remains
  the first local task allowed to create `docs/implementation/` and its first
  real implementation report.

### Risks/blockers

- `PLAN-002` must separately record the user's explicit implementation
  authorization before any application, Docker, Supabase, package, or Chrome
  work begins.
- A Gmail App Password is still required only when SMTP configuration becomes
  an eligible task; no credential has been requested or stored.

### Secret-safety confirmation

- No credential, token, connection string, private data, protected answer,
  TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
  recorded.

### Next

- `PLAN-002` is the only unblocked next task because the user explicitly asked
  to continue and complete the implementation after accepting these decisions.

## PLAN-002 — Completion record

- Outcome: COMPLETE
- Environment: NONE
- Date: 2026-07-27
- Agent/person: Codex, recording the user's direction
- Authorization checked: The user explicitly directed Coditza to continue and
  complete the work, and the active goal expressly requests end-to-end
  implementation and shipping.
- Prerequisites/gate checked: `PLAN-001` is complete and recorded in this
  roadmap; `PLAN-002` was the sole `next` task; `main` was clean at commit
  `501a2f8` before this task.
- Decisions/defaults used:

- Implementation is authorized only within the approved roadmap and one-task
  execution protocol.
- Local implementation may begin only after `PLAN-003` verifies G0.
- Each later hosted, billing-sensitive, production, secret-dependent, or
  destructive action still requires the task-specific approval and safeguards;
  this authorization does not infer them.
- The requested Vercel release remains a post-implementation hosted task, and
  Gmail SMTP remains blocked until the required Gmail App Password is supplied
  to the eligible configuration task.

### Scope

- Intended: record the received implementation authorization and update the
  planning-control state.
- Explicitly excluded: application code, package installation, Docker,
  Supabase, Chrome, Vercel, SMTP, or other external-state work.

### Changed

- `todo/08-execution/00-roadmap.md`: this authorization record and task
  checkbox.
- `todo/TASKS.md`, `todo/STATUS.md`, `todo/NEXT.md`, `todo/README.md`, and
  `todo/00-control/00-scope-and-non-goals.md`: synchronized authorization
  state and G0 restriction.

### Verification

- Reviewed the user's explicit requests to continue and complete Coditza and
  the active goal objective.
  - Result: PASS
  - Non-secret evidence: both authorize implementation rather than only
    planning or review.
- `git log -1 --oneline`
  - Result: PASS
  - Non-secret evidence: `501a2f8 Record Coditza plan acceptance` confirms the
    prerequisite review was committed before this task.

### External actions

- NONE.

### Deviations/ADRs

- NONE.

### Risks/blockers

- `PLAN-003` must verify the complete G0 checklist and synchronize task state
  before `ARC-TREE-002` may create the first local implementation files.
- SMTP, Vercel resource creation, production deployment, and missing secrets
  retain their task-specific stop conditions.

### Secret-safety confirmation

- No credential, token, connection string, private data, protected answer,
  TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
  recorded.

### Next

- `PLAN-003` is the only unblocked next task because it can now formally check
  G0 and select `ARC-TREE-002` without inferring any external authority.

## PLAN-003 — Completion record

- Outcome: COMPLETE
- Environment: NONE
- Date: 2026-07-27
- Agent/person: Codex
- Authorization checked: `PLAN-002` records the user's explicit
  implementation authorization; this task creates no external authority.
- Prerequisites/gate checked: `PLAN-001` and `PLAN-002` are complete;
  `PLAN-003` was the sole `next` task; the working tree was clean before this
  review.
- Decisions/defaults used:

- The fixed decisions are reviewed and remain the authority for the modular
  monolith, Fastify/Supabase split, mandatory TOTP `aal2`, no selected frontend,
  and authoritative isolated Python-on-WASM execution.
- The fixed product/repository wording now distinguishes product `Coditza` from
  the public repository `Coditza-v2` requested by the user.
- DEC-029 remains an explicit production blocker. The user-requested eventual
  Vercel release and Gmail SMTP configuration remain task-scoped future work;
  neither implies provider compatibility, a hosted resource, production
  permission, billing approval, nor a secret.

### Scope

- Intended: verify every G0 condition and advance the single permitted task to
  `ARC-TREE-002`.
- Explicitly excluded: application code, package installation, Docker,
  Supabase, Chrome, Vercel, SMTP, credentials, or other external-state work.

### Changed

- `todo/00-control/01-fixed-decisions.md`: corrected the product/repository
  naming distinction from the user's public-repository direction.
- `todo/08-execution/00-roadmap.md`: this G0 record and task checkbox.
- `todo/TASKS.md`, `todo/STATUS.md`, `todo/NEXT.md`, `todo/README.md`, and
  `todo/00-control/00-scope-and-non-goals.md`: synchronized post-G0 state.

### Verification

- G0 fixed-decision/default review.
  - Result: PASS
  - Non-secret evidence: PLAN-001 records the accepted architecture, Romanian
    course direction, mandatory TOTP, and Python/WASM authority; DEC-029 is
    visibly retained as a production blocker.
- G0 implementation-authorization review.
  - Result: PASS
  - Non-secret evidence: PLAN-002 records the explicit user request to continue
    and complete Coditza.
- G0 task-state synchronization preflight.
  - Result: PASS
  - Non-secret evidence: PLAN-001/002 are complete, no prior local task is
    incomplete, and `ARC-TREE-002` is the first roadmap task after G0.
- `git status --short --branch` and `test ! -e docs`
  - Result: PASS
  - Non-secret evidence: clean `main...origin/main`; no implementation-report
    directory exists before its owning task.

### External actions

- NONE. No external or production authority is inferred from G0.

### Deviations/ADRs

- NONE.

### Risks/blockers

- `ARC-TREE-002` may now create only `docs/implementation/` and its first real
  report. It must not create application files, dependencies, Docker artifacts,
  or empty documentation folders.
- Hosted targets, SMTP credentials, Vercel capability/cost validation, and
  production release remain deferred to their named tasks and approvals.

### Secret-safety confirmation

- No credential, token, connection string, private data, protected answer,
  TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
  recorded.

### Next

- `ARC-TREE-002` is the only unblocked next task because G0 has passed and it
  is the first local foundation task in the ordered roadmap.

## PLAN-004 — Completion record

- Outcome: COMPLETE
- Environment: NONE
- Date: 2026-07-27
- Agent/person: Codex
- Authorization checked: The user explicitly requested eventual Vercel
  deployment/environment configuration and local Gmail SMTP delivery while
  authorizing end-to-end implementation. No external action is authorized by
  this review alone.
- Prerequisites/gate checked: PLAN-003 and G0 are complete; PLAN-004 was the
  sole `next` task; no local implementation artifact existed before this review.
- Decisions/defaults used:

- Vercel is the required future public API target, but OPS-VERCEL-001 now
  verifies current capability and prevents Vercel/serverless assumptions from
  becoming a private grader or outer sandbox decision.
- A supplemental private grader host can be considered only after that review
  and a separate explicit user approval; it cannot replace Vercel silently.
- Local Gmail SMTP is an explicit SUP-SMTP-LOCAL-001 task through the
  CLI-owned local Supabase Auth stack, never root Compose. It requires a Gmail
  App Password supplied only when that task is active.
- OPS-VERCEL-ENV-001 owns Vercel Development/Preview variable scopes, masking,
  and target verification. ARC-ENV-PROD-001 retains production-only binding.
- Romanian curriculum authoring remains independently controlled by its
  CURR-PLAN tasks; the user's end-to-end objective supplies its later explicit
  authorization evidence without mixing it into backend work.

### Scope

- Intended: repair every executable task/dependency path needed for the stated
  Vercel, Gmail SMTP, and environment-variable requirements.
- Explicitly excluded: application code, package installation, Docker/Supabase
  startup, Chrome, Vercel project creation, SMTP configuration, credentials,
  deployment, or billing changes.

### Changed

- `todo/03-supabase/14-local-smtp.md`: explicit local Auth SMTP task and
  secret/delivery boundaries.
- Supabase, Docker, architecture, release-credential, deployment, risk, and
  decision plans: synchronized Vercel/Gmail ownership and stop conditions.
- `todo/TASKS.md`, `todo/08-execution/00-roadmap.md`, and dependency map:
  ordered OPS-VERCEL-001, SUP-SMTP-LOCAL-001, and OPS-VERCEL-ENV-001 paths.
- `todo/STATUS.md`, `todo/NEXT.md`, `todo/README.md`, and scope control:
  synchronized post-review state.

### Verification

- Reviewed the Docker ownership, local Supabase Auth, Python/WASM, release
  credential, and hosted deployment contracts against the user's directions.
  - Result: PASS
  - Non-secret evidence: root Compose remains API/grader-only; SMTP, Vercel
    topology, Vercel environment variables, and production bindings each have
    one named owner task and no bypass path.
- Task/dependency registry and relative-link validation.
  - Result: PASS
  - Non-secret evidence: every new task has an owner, ordered prerequisite,
    and minimum evidence; ARC-TREE-002 is again the sole next local task.
- `git diff --check`
  - Result: PASS (exit 0)
  - Non-secret evidence: the complete plan amendment has no whitespace errors.
- Read-only repository-local Markdown relative-target check
  - Result: PASS (exit 0; 77 Markdown files checked)
  - Non-secret evidence: no new or existing plan link points to a missing local
    target.

### External actions

- NONE.

### Deviations/ADRs

- NONE. OPS-VERCEL-001 owns the future topology ADR after current official
  documentation is reviewed.

### Risks/blockers

- The future OPS-VERCEL-001 task may need the user's approval for a supplemental
  private grader host if Vercel alone cannot meet the sandbox architecture.
- SUP-SMTP-LOCAL-001 will stop until the user supplies a Gmail App Password
  through an approved ignored local secret mechanism.

### Secret-safety confirmation

- No credential, token, connection string, private data, protected answer,
  TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
  recorded.

### Next

- `ARC-TREE-002` is the sole next task because G0 and PLAN-004 are complete and
  it creates only the first implementation-report location/report.

## Phase 1 — Foundation and API container

Execute in this order:

1. [x] ARC-TREE-002 — create the first implementation-report location/report.
2. [x] ARC-TREE-001 — minimal root workspace metadata, no version guesses.
3. [x] ARC-DESIGN-001 — freeze bounded-context ownership, ports/adapters,
   composition root and rule authority.
4. [x] PRD-AUTH-001 — freeze the mandatory TOTP registration/login/factor
   client contract without claiming a UI.
5. [x] PRD-WASM-001 — freeze `python_code` package, authoritative grading,
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

1. [ ] OPS-VERCEL-001 — use current official Vercel documentation to verify the
   required public-API/private-grader topology before selecting a hosted
   Python/WASM launcher; do not create an external resource.
2. [ ] Resolve DEC-032 and run ARC-WASM-001 — select, threat-model, and pin the
   exact Pyodide/Python assets plus compliant local/hosted outer-sandbox
   launcher; no in-process fallback.
3. [ ] SUP-LOCAL-001 — initialize the CLI-owned local stack.
4. [ ] SUP-LOCAL-002 — migration/reset/seed discipline.
5. [ ] SUP-SMTP-LOCAL-001 — configure the CLI-owned local Auth SMTP path with a
   user-provided Gmail App Password; do not alter root Compose or hosted SMTP.
6. [ ] SUP-PRIMITIVES-001 — schemas, extensions, enums, common helpers.
7. [ ] SUP-AUTH-001 — signup profile trigger.
8. [ ] PRD-ROLE-001 — prove default learner creation.
9. [ ] Confirm or amend the documented DEC-030 two-factor safe default and
   record it as resolved; do not start SUP-MFA-001 with this prerequisite open.
10. [ ] SUP-MFA-001 — explicitly enable/prove local Authenticator TOTP and
   sanitized AAL transitions.
11. [ ] SUP-DATA-001 — module/chapter/theory hierarchy.
12. [ ] SUP-DATA-002 — exercises/quizzes/private keys.
13. [ ] SUP-DATA-003 — attempts/completions/progress/audit/idempotency.
14. [ ] ARC-SEC-003 — audit contract acceptance.
15. [ ] SUP-FUNCTIONS-001 — module-owned transactional workflows and helpers.
16. [ ] SUP-WASM-001 — private Python definitions/jobs/evidence plus
    reserve/claim/finalize transactions.
17. [ ] ARC-SEC-002 — database function security/atomicity acceptance.
18. [ ] SUP-BOOTSTRAP-001 — serialized first-admin path.
19. [ ] SUP-AUTH-002 — serialized role-control function.
20. [ ] SUP-AUTH-003 — operator-only identity security hold and recovery-order
    transaction.
21. [ ] SUP-RLS-001 — direct-user denial for both AALs and server-path matrix.
22. [ ] SUP-SEED-001 — deterministic local content/users; factors only through
   Auth test setup.
23. [ ] SUP-TYPES-001 — generated database types.
24. [ ] QA-DB-001 — clean reset/schema/type reproducibility.
25. [ ] QA-RLS-001 — real-token direct Data API denial.
26. [ ] QA-DB-002 — transaction/concurrency cases.
27. [ ] Verify every explicitly listed `DB-*` case in the
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

1. [ ] OPS-HOST-001 — confirm the reviewed Vercel public boundary and any
   explicitly approved private grader host, then create/confirm the approved
   empty development service boundary before any credential binding.
2. [ ] SUP-CHROME-001 — create `Coditza-dev` in Chrome after DEC-018 approval.
3. [ ] Reconfirm DEC-031 and resolve DEC-025 for the actual hosted signup/email
   mode; an earlier-deadline decision cannot be deferred to production.
4. [ ] SUP-CHROME-002 — configure development email/password plus mandatory
   TOTP; DEC-025 controls whether self-service email flows can be signed off.
5. [ ] ARC-ENV-003 — bind development runtime/release identities to the real
   project reference and selected host.
6. [ ] OPS-VERCEL-ENV-001 — bind only the approved Vercel Development/Preview
   runtime-variable names and scopes; production remains separately approved.
7. [ ] SUP-CHROME-003 — verify the exact development target/configuration
   without applying migrations or deploying an image.
8. [ ] OPS-DEPLOY-DEV-001 — alone apply development migrations, deploy the
   candidate digests, prove the hosted AAL1-deny/TOTP-AAL2 flow, and run the
   synthetic Python verifier smoke in the approved no-network outer sandbox.
9. [ ] Resolve DEC-027. If accepted, execute SUP-CHROME-STAGING-001,
   ARC-ENV-STAGING-001, then OPS-DEPLOY-STAGING-001; otherwise record all three
   as not applicable and use development with isolated synthetic data as
   pre-production.
10. [ ] OPS-REC-001 — confirm platform backup/PITR capability so the recovery
   runbook is provider-specific rather than guessed.
11. [ ] Resolve DEC-029 identity-proof, first-factor-compromise, audit,
    notification and operator approvals, then run OPS-RUNBOOK-001 to author the
    exercise matrix and invoke the existing security-hold recovery executable.
12. [ ] QA-PERF-001 — measure pre-production baselines.
13. [ ] OPS-OBS-PREPROD-001 — bind and safely exercise hosted dashboards and
    alerts for the selected pre-production environment.
14. [ ] Reconfirm DEC-023, then run OPS-MAINT-001 for bounded
    expiry/retention jobs and their alerts.
15. [ ] OPS-UPGRADE-001 — previous-schema-to-candidate compatibility drill.
16. [ ] OPS-ROLLBACK-001 — application rollback/partial rollout drill,
    including the first-release zero-traffic baseline when applicable.
17. [ ] OPS-REC-002 — approved non-production restore drill.
18. [ ] OPS-REC-003 — recurring backup freshness/restore schedule.
19. [ ] Verify hosted security/smoke/observability evidence and record G7.

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
