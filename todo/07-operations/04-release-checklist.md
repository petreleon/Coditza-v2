# Release checklist

## Before hosted pre-production

- [ ] G0–G6 passed with evidence.
- [ ] CI green from the intended immutable revision.
- [ ] Database resets/migrates from zero and types have no drift.
- [ ] OpenAPI matches runtime.
- [ ] Full learner, editor, admin, RLS, concurrency, and security paths pass.
- [ ] Mandatory password → TOTP → `aal2` registration/login tests pass; `aal1`
      is denied before every domain use case.
- [ ] Docker/Compose health and shutdown pass.
- [ ] No high/critical issue, secret, answer leak, or unresolved schema drift.
- [ ] Development, plus staging when DEC-027 requires it, is verified in Chrome.

## Before production approval

- [ ] The selected pre-production environment uses the exact proposed image
      digest and migrations.
- [ ] Hosted project owner, region, tier, cost, domains, CORS/Auth URLs verified.
- [ ] DEC-017 privacy deletion and DEC-019/020 recovery/operations accepted.
- [ ] DEC-029 MFA-loss recovery, factor replacement, session/revocation window,
      and owned runbook are accepted before self-service signup.
- [ ] Backup/restore drill meets the accepted objective.
- [ ] Monitoring/alerts/runbook owners confirmed.
- [ ] Maintenance schedule, batch limits, backlog alerts, and retention owner
      confirmed.
- [ ] Migration compatibility/forward-fix plan reviewed.
- [ ] A previous compatible image is available, or for the first release the
      exercised zero-traffic/no-app rollback baseline and candidate redeploy
      evidence is accepted.
- [ ] Explicit production approval recorded.

## Production execution

## OPS-RELEASE-PROD-001 — Admit and observe production traffic

Prerequisites: OPS-DEPLOY-002, OPS-OBS-PROD-001, OPS-MAINT-PROD-001, and
OPS-REC-PROD-001 are complete; the exact endpoint/domain, digest, migration set,
release window, smoke identity, observation duration/thresholds, approver, and
rollback trigger are recorded. Obtain explicit user/owner approval to open the
named production traffic gate.

- [ ] Confirm `Coditza-prod` in Chrome before each environment action.
- [ ] Confirm OPS-DEPLOY-002 already applied migrations once and deployed the
      approved digest; do not rerun either operation here.
- [ ] Recheck internal liveness/readiness, monitoring receipt, backup freshness,
      maintenance schedule state, and previous-image or first-release
      zero-traffic rollback while traffic is still closed.
- [ ] Open only the approved production traffic gate, using a bounded canary/
      traffic step when the chosen provider supports it.
- [ ] Run liveness/readiness and non-destructive authenticated smoke checks.
- [ ] With approved production smoke identities and no captured credentials,
      prove password-only `aal1` is denied and TOTP-upgraded `aal2` succeeds
      before concluding the Auth smoke.
- [ ] Confirm no demo seed and no development/optional-staging URL, key, issuer,
      project ref, or synthetic test namespace.
- [ ] Observe the full agreed window and compare error/latency/dependency/auth/
      maintenance signals with the recorded thresholds.
- [ ] Close traffic or roll back immediately on a trigger; do not attempt an
      improvised destructive database rollback.
- [ ] Record the traffic action, approver, endpoint, digest, migration IDs,
      smoke result, observation result, warnings, and rollback status without
      secrets.

## After release

- [ ] Complete the observation window without unexplained regression.
- [ ] Verify a safe backup occurred/was scheduled as planned.
- [ ] Close or assign every release warning.
- [ ] Update status, runbooks, and release notes.
- [ ] Preserve rollback capability until the release is formally closed.
