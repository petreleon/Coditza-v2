# Backup, rollback, and recovery

## Principles

- API rollback and database recovery are different operations.
- Keep the previous immutable API image available.
- Prefer forward-fix migrations; do not edit/delete applied history.
- Use expand/migrate/contract for incompatible changes.
- Never claim recovery readiness without a restore drill.

## OPS-REC-001 — Confirm platform capability

In Chrome for each hosted project:

- [ ] Review the current tier's backup/PITR/retention capability.
- [ ] Compare it with DEC-019 RPO/RTO.
- [ ] Obtain approval before a paid tier/add-on.
- [ ] Record non-secret capability, owner, retention, and review date.
- [ ] Define who may initiate restore and how identity is verified.

## OPS-REC-002 — Restore drill

- [ ] Read the OPS-RUNBOOK-001 restore procedure and confirm its target/owner/
      approval stops before creating resources.
- [ ] Before creating anything, state the exact recovery project name,
      organization, region, tier/cost, source backup, intended retention,
      controller, and Chrome workflow; obtain explicit user approval for that
      project creation and any paid capacity.
- [ ] Use a new isolated project and protected recovery credential scope; never
      expose credentials or restore production data into development/staging.
- [ ] Restore/copy a backup into a new non-production project.
- [ ] Apply any forward migrations required by the chosen application image.
- [ ] Verify row counts/integrity, Auth profile linkage, content hierarchy,
      attempts, scores, and progress.
- [ ] Run security/RLS smoke tests.
- [ ] Measure recovery time and data point achieved.
- [ ] Update the restore runbook's central exercise-matrix row with dated,
      sanitized RPO/RTO/result evidence.
- [ ] Destroy test recovery resources only with explicit scoped approval.
- [ ] Record sanitized results and gaps.

## OPS-REC-PROD-001 — Activate production recovery verification

Prerequisites: SUP-CHROME-PROD-001, OPS-DEPLOY-002, OPS-REC-001/002/003, accepted
DEC-019, and explicit approval for any paid backup/PITR or monitoring change.

- [ ] Confirm the exact production project reference, tier, backup/PITR mode,
      retention, region, owner, RPO/RTO, and restore-authority procedure.
- [ ] Verify the first eligible production backup/freshness signal without
      restoring over production or exposing row contents.
- [ ] Bind a stale/missing-backup alert to the production project fingerprint,
      named owner, severity, and recovery runbook.
- [ ] Create the recurring restore-drill calendar/automation with an approved
      isolated target, data-handling rules, cost approval point, evidence owner,
      and next due date.
- [ ] Record safe capability/freshness timestamps and gaps. Never claim that a
      scheduled drill has passed before it actually runs.

This task activates production verification; every future recovery-project
creation/deletion still requires its own exact scoped approval.

## Rollback decision tree

- API-only regression: route traffic to the previous compatible image when one
  exists; on the first release, close traffic/scale the app out and use the
  exercised candidate-redeploy or forward-fix path.
- Migration applied but app failed: deploy a compatible prior/repair image or
  forward-fix; never blindly reverse data changes.
- Corrupt data: stop writes, preserve evidence, assess restore/PITR or corrective
  migration with owner approval.
- Credential exposure: revoke/rotate immediately, redeploy secret stores, audit
  access, and document incident.
- Answer-key exposure: stop affected endpoint, rotate credentials if relevant,
  preserve logs safely, identify affected assessments/users, replace compromised
  assessments, and follow incident/privacy communication ownership.

## Required runbooks

Local reset; failed migration; failed deploy; Supabase outage; connection
exhaustion; secret rotation/leak; Auth redirect/email failure; incorrect grading;
progress repair; user deletion/export; backup restore; security incident.

Ownership, required fields, verification, and recurring recovery are implemented
by [OPS-RUNBOOK-001 and OPS-REC-003](05-upgrades-rollbacks-and-runbooks.md).
