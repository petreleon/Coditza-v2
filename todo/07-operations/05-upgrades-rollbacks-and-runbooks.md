# Upgrade, rollback, and runbook drills

Claims about rollback or operations require exercised evidence in the selected
hosted pre-production environment (development, or staging if DEC-027 approves
it). Never run these drills first in production.

## OPS-UPGRADE-001 — Prove release-to-release compatibility

- [ ] Preserve a sanitized schema snapshot/fixture at the previous released
      migration; for the first release, the explicit pre-release baseline is an
      empty database at migration zero.
- [ ] Apply new migrations to that previous state, not only to an empty reset.
- [ ] For expand/migrate/contract changes, prove the previous API works after
      expansion, then the new API works, and run contraction only after old
      instances are retired.
- [ ] Test required data backfills for restartability, bounded batches, and
      idempotency.
- [ ] Simulate a failed transactional migration and a failed non-transactional
      step first locally and then only in an approved disposable
      non-production recovery target; prove the release job stops and records
      the exact recovery action.
- [ ] Follow the assigned migration-failure runbook and update its central
      exercise-matrix row with dated sanitized evidence.
- [ ] Record the compatibility window and minimum rollback-compatible schema.

## OPS-ROLLBACK-001 — Exercise application rollback

- [ ] Deploy the candidate digest in pre-production and create safe synthetic
      state.
- [ ] When a previous release exists, route back to its reviewed compatible
      digest without rebuilding it and verify health, authentication, permitted
      reads/writes, and no duplicate migration execution.
- [ ] For the first release, record that no previous digest exists, exercise the
      explicit rollback baseline by closing traffic/scaling the candidate out
      without deleting data, prove the service is unreachable publicly, then
      redeploy the same reviewed candidate and re-run health/Auth checks. Do not
      invent a “previous image.”
- [ ] Exercise the failed-deploy and partial-rollout runbooks.
- [ ] For an incompatible database change, prove forward-fix/repair instead of
      pretending a blind down migration is safe.
- [ ] Record duration, decision owner, evidence, gaps, and next corrective task.
- [ ] Update the assigned deployment/rollback rows in the central runbook
      exercise matrix.

## OPS-RUNBOOK-001 — Author, assign, and start the runbook matrix

Prerequisites: selected hosted pre-production deployment, OPS-REC-001 platform
capability evidence, accepted DEC-029, and explicit approval for the synthetic
MFA-recovery drill.

Create one small file per scenario under `docs/operations/` only when
implementation is authorized:

- local reset and clean seed;
- failed/partial migration;
- failed/partial deployment and API rollback;
- Supabase outage and connection exhaustion;
- secret rotation/leak;
- Auth redirect/email failure;
- Authenticator enrollment/login failure, factor compromise/loss/replacement,
  and suspected stale AAL2 session;
- incorrect grading and assessment replacement;
- progress reconciliation;
- user deletion/export;
- backup restore and backup-freshness failure;
- security/answer-key incident.

Each runbook names trigger, severity, owner, prerequisites, exact safe checks,
containment, recovery, verification, communication/escalation, evidence, and
stop/approval points. Create one exercise matrix that assigns each runbook to
the later task that can safely execute it. At OPS-RUNBOOK-001 completion,
unexecuted scenarios remain explicitly `not yet exercised`; authorship is not
misreported as a drill.

The later owning tasks update only their exercise/evidence row:

- OPS-OBS-PREPROD-001: outage, alert, Auth/MFA-signal runbooks;
- OPS-MAINT-001: expiry/purge failure and backlog runbooks;
- OPS-UPGRADE-001: migration failure/compatibility runbooks;
- OPS-ROLLBACK-001: failed/partial deployment and API rollback runbooks;
- OPS-REC-002/003: restore and backup-freshness runbooks;
- existing local QA/API tasks: grading, progress and answer-key containment
  cases already exercised locally.

OPS-RUNBOOK-001 itself performs the approved selected-pre-production
lost-all-factors drill by invoking the immutable executable built by
SUP-AUTH-003. It may create/update operations documentation and exercise that
executable, but may not edit application/operator code.

The lost-all-factors runbook remains blocked until DEC-029 is accepted. It must
require identity proof, exact environment/user confirmation, privileged
operator authorization, then execute this order: set the live Coditza identity
security hold; revoke all provider sessions and delete factors; quarantine for
the exact configured maximum access-token lifetime plus reviewed skew; revoke
sessions and delete any quarantine-created factor again; only then permit fresh
TOTP enrollment/verification; clear the hold last. The runbook also resolves
first-factor rotation when compromise is suspected. Provider/Coditza audit
evidence and user notification are mandatory. It may not expose a public reset
endpoint or treat email/password as sufficient identity proof.

G7 passes only after every matrix row marked production-critical is dated and
exercised by its owning task. OPS-RUNBOOK-001 completion alone cannot satisfy
that gate.

## OPS-REC-003 — Make recovery recurring

- [ ] Define a backup-freshness signal and alert owner.
- [ ] Schedule a restore drill at least quarterly or at the accepted stricter
      interval.
- [ ] Track measured RPO/RTO, last success, next due date, and unresolved gaps.
- [ ] Require a new drill after a material storage/Auth/migration change.
- [ ] Update the backup-freshness runbook's exercise-matrix row with the safe
      alert/schedule test and next due date.
- [ ] Never delete recovery projects or evidence without scoped approval and
      retention review.
