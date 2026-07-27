# Risk register

| ID | Risk | Likelihood | Impact | Trigger | Mitigation |
| --- | --- | --- | --- | --- | --- |
| R-001 | Product/grading rule ambiguity causes schema rework | Medium | High | implementation guesses | fixed defaults, decision deadlines, ADR |
| R-002 | Correct answers leak | Medium | Critical | key field in table/API/log/OpenAPI | private schema, RPC, projections, schemas, scans/tests |
| R-003 | Secret enters source/log/chat/image | Medium | Critical | visible key/password/token | user-controlled transfer, redaction, secret scan, rotate |
| R-004 | Dev action targets production | Low | Critical | wrong project ref/browser tab | separate names/projects, pre-save checks, explicit flags/approval |
| R-005 | Dashboard schema drifts from migrations | Medium | High | manual table/SQL edit | migration-only, Chrome read-only verification, diff gate |
| R-006 | RLS and Fastify authorization disagree | Medium | Critical | route passes but direct API leaks | request-context tests at both layers |
| R-007 | Secret client becomes generic escape hatch | Medium | Critical | raw client imported in routes | narrow module adapters, lint boundary, code review |
| R-008 | Concurrent retries duplicate attempts/scores | Medium | High | network/concurrent submit | idempotency records, locks, unique constraints |
| R-009 | Progress cache drifts | Medium | High | source write without recalculation | transactional recalc, reconciliation/test comparison |
| R-010 | Published assessment changes historical grading | Medium | High | edit after publish | immediate immutability, version snapshot, archive/clone |
| R-011 | Compose duplicates/conflicts with Supabase | Medium | Medium | second Postgres/container ports | CLI owns Supabase; Compose owns API plus the private grader path only, with documented gateway |
| R-012 | Region/tier choice causes latency/cost/residency issue | Medium | High | rushed project creation | Chrome decision gate before creation |
| R-013 | Auth email/redirect unusable without client/SMTP | High | Medium | hosted signup enabled too early | defer exact URLs, selected-pre-production tests, provider decision |
| R-014 | User/minor privacy obligation unknown | Medium | Critical | real user data before review | DEC-001/017, minimal data, production gate |
| R-015 | Backup exists but restore fails | Medium | Critical | no drill | non-prod restore drill and RPO/RTO evidence |
| R-016 | Dependency/platform guidance changes | Medium | High | incompatible/latest install | official docs revalidation, pin versions, lockfile |
| R-017 | Unbounded/N+1 paths overload Supabase | Medium | High | growing content/history | cursors, query plan/load tests, indexes |
| R-018 | Timed quizzes harm accessibility | Medium | Medium | high-stakes timing | nullable default, accommodation decision/client contract |
| R-019 | Destructive cascade loses learning history | Low | Critical | content/user delete | restrict authored FKs, privacy procedure, restore |
| R-020 | Logs expose learner answers/free text | Medium | High | request body logging | redaction, safe audit schema, log tests |
| R-021 | TOTP QR/secret/code leaks | Medium | Critical | enrollment screenshot/log/test artifact | client-memory-only handling, redaction and scans |
| R-022 | Password-only AAL1 bypasses mandatory MFA | Medium | Critical | valid token accepted without assurance check | exact AAL2 pre-handler before profile/use case, E2E matrix |
| R-023 | Lost device causes lockout or unsafe reset | Medium | Critical | all factors lost | backup factor, DEC-029 identity-proof/recovery runbook, no public reset |
| R-024 | Old AAL2 JWT survives factor/session revocation and races Auth enrollment | Medium | High | factor removed while token unexpired | live identity hold; max-token-lifetime quarantine; second revoke/delete before enrollment; measured window for ordinary changes |
| R-025 | API plan claims registration UX without a client | High | Medium | headless test mistaken for user-facing flow | explicit no-frontend scope, client contract, later client decision/task |
| R-026 | Module boundaries decay into god adapters | Medium | High | cross-module deep import/global dependency bag | ownership inventory, composition root, negative import fixtures |
| R-027 | Client/browser provisional Python result is trusted | Medium | Critical | client submits pass/score/tests/runtime | closed source-only schema, server re-run, finalization RPC, forged-result tests |
| R-028 | WASM/`js` escape reaches host, network, or secrets | Medium | Critical | runner relies on Pyodide/Node worker/WASI alone | disposable outer sandbox, no network/secrets/mounts/socket, non-root/seccomp/limits, escape canary suite |
| R-029 | Runtime/package/fixture drift changes historical grading | Medium | Critical | CDN/latest/download or unpinned test bundle | self-hosted manifest hashes, immutable definition/evidence digests, offline CI, same-digest promotion |
| R-030 | Nondeterministic Python tests produce inconsistent verdicts | Medium | High | time/random/hash/external-state dependence | fixed deterministic fixtures, two-fresh-worker digest equality, mismatch incident |
| R-031 | Python queue/resource abuse exhausts API/controller/database | High | High | infinite loop/output/memory flood or burst submissions | async bounded queue, rate/backpressure, leases, concurrency/resource ceilings, circuit breaker |
| R-032 | Hidden Python tests or learner source leak | Medium | High | traceback/log/OpenAPI/report/status oracle | private definitions, safe projections, generic hidden feedback, redaction/scans, bounded output |
| R-033 | Grader crash/lease race duplicates or misattributes an attempt | Medium | High | controller death/late result/reclaim | deterministic replay, unguessable lease token, digest checks, idempotent finalization, concurrency tests |

## Review rule

- Review risks at each gate and after incidents/platform changes.
- Add owner/status/review date in the implementation risk log.
- A critical triggered risk closes the current deployment gate until mitigated.
- Any R-027 through R-030 trigger closes G-WASM; no production waiver may make
  a client result authoritative or treat WASM alone as isolation.
- Do not delete resolved risks; mark resolution and preserve rationale.
