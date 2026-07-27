# Phase gates

## G0 — Plan accepted and implementation authorized

- fixed decisions/defaults reviewed;
- modular-monolith/TOTP decisions and the no-frontend client deliverable are
  understood; DEC-029 remains an explicit production blocker if unresolved;
- implementation explicitly authorized by the user;
- TASKS/STATUS/NEXT name the same first local task;
- no external or production authority is inferred.

## G1 — Foundation reproducible

Status: PASSED on 2026-07-27. The synchronized completion record is in the
roadmap; QA-STRAT-001 supplies the current no-network test-harness evidence.

- clean npm install, format, lint, typecheck, unit harness, and build pass;
- modular ownership/composition/RPC maps are accepted and negative import
  fixtures prove the dependency graph can fail;
- mandatory registration/login MFA state contract is accepted without claiming
  user-facing screens or credential proxying;
- `python_code` source/package/verdict semantics and the rule that only a
  server-side authoritative run awards points are accepted;
- canonical app/server split and dependency-free liveness pass;
- production image builds/runs non-root;
- Docker Compose starts API, reports liveness, and handles shutdown;
- static/container tests do not require Supabase initialization;
- no domain/remote implementation slipped in.

## G2 — Local data foundation secure

- clean Supabase reset/seed/lint/tests pass;
- schema/constraints/functions/indexes match migrations;
- Python private definitions, grading jobs, leases, evidence, and
  reserve/claim/finalize functions pass concurrency/idempotency/grant tests;
- the exact Pyodide/Python runtime manifest and compliant outer-sandbox
  architecture are pinned; worker-thread/WASI-only fallback is absent;
- private keys are inaccessible;
- direct `anon`/`authenticated` domain denial and server-actor function matrix
  pass;
- bootstrap and concurrent last-admin protection pass;
- operator identity-security-hold transitions/grants/audit pass; the future
  factor-recovery order is fixed without claiming session revocation erases an
  issued access JWT;
- local TOTP enrollment/verification is explicitly enabled; genuine synthetic
  sessions prove `aal1 → aal2`, multiple-factor selection and no secret
  persistence;
- the CLI-owned local Auth SMTP path proves one sanitized Gmail delivery with
  an ignored App Password, while root Compose and hosted SMTP remain unchanged;
- generated types have no drift;
- no hosted project/schema change was needed.

## G3 — Read slice complete

- token/issuer/audience/session/AAL/profile-role verification and request
  isolation pass;
- a live identity security hold denies an already issued genuine AAL2 token
  before any business use case;
- every domain route rejects genuine `aal1` as `mfa_required` before
  profile/use-case access and accepts genuine TOTP `aal2`;
- registration enrollment and a separate later password login both reach AAL2
  through the exact client contract; refresh follows DEC-031;
- module -> chapter -> theory/exercise/quiz safe reads pass;
- Python exercise reads expose only starter/public-test/runtime metadata and no
  hidden fixture/count/digest;
- drafts/archived/keys do not leak;
- pagination/errors/OpenAPI match runtime;
- Compose API reaches CLI-owned Supabase with separate network URL and canonical
  issuer settings;
- liveness/readiness and recovery after dependency failure behave correctly.

## G4 — Learning complete

- exercise and quiz workflows handle all answer types;
- `python_code` reservation/polling/finalization passes G-WASM;
- normalization golden vectors match SQL and TypeScript;
- attempt concurrency/idempotency/time/limit rules pass;
- no client score/key/actor trust exists;
- progress snapshots match source and are owner-only;
- learner end-to-end path passes through Compose;
- the learner path starts from genuine password+TOTP AAL2 and has no bypass.

## G-WASM — Python verifier authoritative and isolated

This is a mandatory component of G4 and every later gate:

- exact Pyodide, CPython, loader/WASM/stdlib/package/harness/worker assets are
  self-hosted, immutable, and verified from the runtime lock manifest;
- a future browser module Web Worker may run only public tests and remains
  provisional; forged client score/verdict/runtime/test reports are rejected;
- every score/progress result comes from a fresh server run inside the approved
  disposable outer sandbox, never an in-process/worker-thread/WASI-only runner;
- the outer sandbox independently enforces no network/DNS, no secrets/Auth/TOTP,
  no host/container socket or mounts, read-only assets, non-root/no privilege,
  bounded writable files, and hard CPU/wall/memory/process/output limits;
- canonical multi-file packages, deterministic fixtures, exact echoed digests,
  and two-fresh-worker verdict equality pass;
- hidden tests/expected values/private tracebacks and learner source never leak
  through API, OpenAPI, logs, metrics, reports, or artifacts;
- queue capacity, idempotency, lease loss/controller crash/retry/shutdown,
  repeated finalization, and infrastructure-versus-learner failure semantics
  pass;
- Supabase owns Auth/TOTP unchanged; the controller/worker performs no
  registration, login, token/AAL, factor, or code verification.

## G5 — Authoring/admin complete

- exact draft/correction/publish/archive/clone/replace/reorder routes pass;
- no authored hard-delete API exists and subtree archive preserves history;
- immediate published-assessment immutability holds;
- answer specs appear only in protected draft-authoring paths;
- role changes/final-admin/bootstrap/audit pass;
- editor/admin end-to-end paths pass;
- editor/admin paths use the same genuine AAL2 floor as learners.

## G6 — Local release quality

- complete static/unit/database/API/contract/E2E/security suite passes clean;
- OpenAPI/types have no drift;
- provider-neutral check and selected provider CI repeat the result;
- immutable image digest, SBOM/provenance where supported, and pull-by-digest
  smoke evidence exist;
- dependency/secret/container scans are reviewed;
- OPS-WASM-001 verifies offline runtime assets, Python-package SBOM/licenses/
  vulnerabilities, sandbox policy, provenance, and immutable promotion rules;
- no unresolved high/critical issue;
- client contract review is recorded;
- forged/downgraded AAL, factor lifecycle, stale-token window, TOTP material
  leakage and module-boundary abuse cases pass.

## G7 — Hosted pre-production ready

- hosted development is configured in Chrome; optional staging is either
  verified or explicitly not applicable by DEC-027;
- selected pre-production Auth has TOTP enroll/verify enabled, other factors
  disabled, and synthetic password→AAL1→TOTP→AAL2 plus AAL1-denial evidence;
- committed migrations match hosted state;
- exact candidate image digest works in the chosen pre-production environment;
- exact grader-controller/sandbox image plus Python runtime-manifest digests
  work on the selected host with no-network/secret-free isolation, and the
  synthetic G-WASM smoke passes;
- the Vercel Development/Preview public-API runtime-variable scopes are masked,
  point only to the exact non-production target, and contain no release or
  private-grader credentials;
- hosted security/E2E/smoke and performance baseline pass with synthetic data;
- observability, alerts, owned runbooks, upgrade, rollback, and partial-failure
  drills work;
- every production-critical row in the central runbook exercise matrix names
  its owning task and has dated selected-pre-production evidence; authored-only
  rows do not pass;
- bounded maintenance jobs handle concurrency/retry/backlog without leaking
  sensitive data;
- restore drill and recurring backup-freshness ownership meet the proposed
  RPO/RTO;
- production release mode, decisions, and cost implications are ready for
  explicit approval.
- DEC-029 recovery policy/runbook is accepted and exercised in non-production
  before production self-service signup.

## G8 — Production release complete

- explicit production approval and `Coditza-prod` verification exist;
- production-only runtime/release scopes match the exact project, host, and
  registry;
- reviewed migrations and approved image digest are deployed once;
- Vercel Production runtime-variable names/scopes are bound only to the exact
  approved production target without release or private-grader credentials;
- the approved API/controller/sandbox/runtime digests are promoted unchanged;
- Auth/client/email/MFA mode matches DEC-025/026/028/029/030/031 and contains no
  invented URLs or recovery bypass;
- closed-traffic smoke proves password-only AAL1 denial and TOTP AAL2 success
  for the production configuration;
- closed-traffic synthetic Python smoke proves the production sandbox policy
  and server-only authoritative result path without exposing hidden fixtures;
- no demo data or wrong-environment setting is present;
- production dashboards/alerts, bounded maintenance schedules, backup-freshness
  monitoring, and recurring restore ownership are active and verified;
- smoke and observation window pass;
- backup/recovery/rollback remain ready;
- evidence/status/release notes are complete.

Any failed item keeps the gate closed. A waiver requires an ADR naming risk,
owner, expiry, and compensating control; security/privacy/key-isolation failures
cannot be waived for production.
