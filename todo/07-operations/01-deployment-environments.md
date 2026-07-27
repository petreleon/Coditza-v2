# Deployment and environment promotion

The API hosting provider and registry are not selected. Keep the container
portable and record the final decision in an ADR.

## OPS-HOST-001 — Select the API host and create the development boundary

Prerequisites: G6; OPS-SOURCE-001 has resolved DEC-024 and named the image
registry; the user is available to resolve DEC-007. This task owns DEC-007—it is
not a prerequisite that must already be resolved. Before creating any account,
project, service, paid resource, domain, or billing commitment, state its exact
provider/name/region/tier/cost/owner and obtain user approval.

- [ ] Compare providers against required OCI-digest deployment, one-off release
      jobs, protected environment/secret scopes, HTTPS, health checks, a
      production traffic gate, scheduler support, structured logs/alerts,
      graceful shutdown, region, egress, quota, and cost. Also require the exact
      ARC-WASM-001 narrow launcher for disposable no-network/secret-free/
      non-root/read-only/resource-limited sandboxes; no API/controller Docker
      socket or worker-thread fallback.
- [ ] Select and record one provider in an ADR; do not add multiple half-working
      provider paths.
- [ ] Record the exact development deployment-environment identifier and a
      collision-free naming rule for optional staging and production. Naming a
      future production resource does not authorize creating it.
- [ ] After separate scoped approval, create or confirm the exact empty
      development host environment/service shell with public traffic disabled,
      no Coditza image, and no Supabase credential. Record its non-secret service
      identifier for ARC-ENV-003.
- [ ] Verify how the provider deploys an existing immutable digest without
      rebuilding and how it runs a serialized, separately credentialed release
      job.
- [ ] Verify the proxy chain, trusted-hop value, port/health contract, traffic
      gate, an operator-only internal/preview request path while public traffic
      remains at zero, scheduler concurrency, log destination, and rollback
      mechanism. If authenticated internal smoke is impossible behind the
      closed gate, the provider does not meet Coditza's production contract.
- [ ] Record owners, required approvals, quota/cost boundaries, and a
      provider-exit path that preserves the OCI image and Supabase data.

Evidence is the ADR, sanitized capability/ownership matrix, scoped external-
creation approval when needed, and non-secret empty development service ID. Do
not deploy the Coditza image or place Supabase credentials during this task.

## Environment isolation

- `Coditza-dev` and `Coditza-prod` are separate Supabase projects. A
  `Coditza-staging` project exists only when DEC-027 approves it.
- API services, secret stores, domains, CORS origins, Auth redirects, logs, and
  monitoring are separate.
- Production credentials are not placed on ordinary developer machines.
- Only synthetic data is used outside production.

## OPS-DEPLOY-DEV-001 — Development promotion

Prerequisites: OPS-HOST-001, SUP-CHROME-003, ARC-ENV-003, and the reviewed
OPS-ARTIFACT-001 digest.

1. acquire the provider's single migration/deploy concurrency lock;
2. select the exact reviewed revision and immutable API/controller/sandbox
   image plus Python runtime-manifest digests;
3. load the development release scope and prove its project reference,
   environment, URL/issuer mapping, registry, and service target all agree;
4. in the ephemeral release job, link the CLI to that exact reference, list and
   preview pending committed migrations, then apply them once;
5. never pull an unexplained remote baseline and never run a linked reset;
6. deploy those exact digests—without rebuilding or downloading Python
   packages—with separate API/controller runtime scopes;
7. wait for readiness, then inspect migrated tables/functions/grants/RLS
   read-only in Chrome;
8. run hosted direct-user denial/RLS tests plus namespaced safe smoke and
   synthetic learner flows, including password `aal1` denial, TOTP
   enroll/challenge/verify to `aal2`, a separate later-login challenge, and a
   synthetic Python job proving server-only finalization and the no-network/
   secret-free sandbox policy;
9. record digest, migration IDs, target reference, time, status, test evidence,
   and synthetic-data expiry/retention without secrets;
10. stop promotion on any failure and use a separately approved cleanup action
    for external synthetic rows/users.

Migrations run in a one-off release job, not at startup in every API replica.

## OPS-DEPLOY-STAGING-001 — Optional staging promotion

Prerequisites: SUP-CHROME-STAGING-001, ARC-ENV-STAGING-001,
OPS-HOST-001, and explicit DEC-027 approval.

- [ ] Acquire a staging-only lock, prove every target binding, then repeat the
      complete development CLI migration/deploy/Chrome-verification/security/
      smoke sequence, including the sanitized AAL1/TOTP/AAL2 matrix, against the
      exact staging project and scopes.
- [ ] Promote the same API/controller/sandbox/runtime digests; never rebuild or
      download packages.
- [ ] Use only namespaced synthetic data.
- [ ] Produce the stable deployed target/evidence consumed later by
      QA-PERF-001, OPS-UPGRADE-001, OPS-ROLLBACK-001, and OPS-REC-*; do not claim
      or duplicate those dedicated drills in this deployment task.
- [ ] Record a separate report; one execution must never target two
      environments.

## OPS-DEPLOY-002 — Production promotion

Prerequisites: G7, SUP-CHROME-PROD-001, explicit user/owner approval,
ARC-ENV-PROD-001, DEC-019/020 accepted, an exact migration/digest approval, and
approval for the named production smoke identity's creation/use/retention or
cleanup.

- [ ] Use an approved immutable image already verified in the selected hosted
      pre-production environment.
- [ ] Use the identical approved controller/sandbox/runtime-manifest digests and
      re-verify the no-network/secret-free launcher mapping.
- [ ] Confirm backup/restore readiness and migration compatibility.
- [ ] Confirm exact production project/domain/CORS/Auth settings in Chrome.
- [ ] Confirm the exact TOTP-only second-factor, session lifetime, factor limit,
      rate-limit and recovery-runbook metadata while traffic remains closed.
- [ ] Resolve the non-demo smoke identity, custodian, protected credential
      scope, permitted read-only data and cleanup/retention; create it only when
      the production approval explicitly includes that action.
- [ ] Keep public traffic admission closed (zero traffic weight, disabled route,
      or equivalent reviewed provider gate); stop if the host cannot provide the
      recorded gate.
- [ ] Acquire the production migration/deploy lock, prove all protected target
      bindings, link the ephemeral CLI job to the exact project reference,
      preview pending migrations, and apply them once.
- [ ] Deploy the approved digests without rebuild, package download, or demo
      seed and wait for API/controller internal readiness while traffic remains
      closed.
- [ ] Verify migrated schema/grants/RLS read-only in Chrome.
- [ ] Through the reviewed operator-only internal/preview path, and while public
      traffic weight remains zero, use an approved non-demo production smoke
      identity from protected credential storage to prove password-only `aal1`
      receives `403 mfa_required` and a genuine TOTP-upgraded `aal2` session can
      call one read-only domain route. Capture no password, TOTP, QR, token,
      factor/challenge body, email, or Auth response.
- [ ] Stop and close the gate on any smoke failure. Do not open public traffic,
      enable schedules, or claim release completion in this task.
- [ ] Record approver, digest, migration IDs, exact target, result, and rollback
      readiness plus sanitized closed-gate Auth-smoke outcomes without secrets.

OPS-DEPLOY-002 is the sole production migration/image owner.
OPS-RELEASE-PROD-001 later owns traffic admission, public-path smoke,
observation, and release closure.

## Runtime requirements

- HTTPS terminated by trusted hosting layer.
- `NODE_ENV=production`.
- HTTPS-only hosted Supabase URL/issuer values bound to the exact project ref.
- correct `trustProxy` for the actual proxy path.
- non-root container and runtime-only secrets.
- liveness/readiness and graceful shutdown.
- replicas/pool usage within Supabase plan limits.
- one API replica until a shared rate-limit store is selected and tested;
- bounded grader-controller replicas/concurrency with database leases and the
  ARC-WASM-001 sandbox policy;
- no local filesystem durability assumption.
- scheduled/bounded deletion of expired idempotency records and retention of
  logs/audit events according to DEC-023.
