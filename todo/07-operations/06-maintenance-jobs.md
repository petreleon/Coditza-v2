# Bounded maintenance jobs

Maintenance is invoked by the selected API host scheduler or one serialized
worker using server-only credentials. Do not assume Supabase cron, an always-on
API replica, or a local filesystem. Jobs call named system functions and never
expose generic SQL execution.

Use a one-off command in the same immutable image, for example the implemented
equivalent of `node dist/jobs/maintenance.js --job <fixed-name>`; do not expose
a public maintenance HTTP route. The command requires typed `APP_ENV`, verifies
the project reference/URL, and accepts only a compile-time allowlist of job
names.

## OPS-MAINT-001 — Schedule safe retention/finalization

Prerequisites: hosted development deployment, host/scheduler selected,
SUP-FUNCTIONS-001, OPS-RUNBOOK-001, DEC-023, and explicit production retention
approval before production enablement.

- [ ] Run expired quiz finalization in bounded batches; use database time,
      `FOR UPDATE SKIP LOCKED`, the same row lock/grader as manual submit, and
      recalculate progress exactly once.
- [ ] Delete expired idempotency records in bounded batches by indexed
      `expires_at`; never delete unexpired rows.
- [ ] Apply application-log retention in the logging provider, not a database
      function.
- [ ] Apply audit retention/anonymization only through an approved system path
      matching DEC-017/023 and legal/privacy ownership.
- [ ] Use one concurrency key per environment, finite timeout, retry with
      backoff, maximum batch/runtime, and a resumable cursor/count.
- [ ] Emit counts, duration, environment, and stable failure code, never answer
      bodies, tokens, user free text, keys, or row dumps.
- [ ] Alert on repeated failure/backlog age and document manual safe replay.
- [ ] Test two concurrent workers, partial failure, retry, and zero-work runs in
      local/pre-production before enabling production.
- [ ] Exercise the assigned failure/backlog/manual-replay runbook and update only
      its row in the central runbook matrix with dated sanitized evidence.

The deployment record names schedule, batch size, timeout, alert owner, last
success, and disable/rollback procedure. Running a job in one environment never
authorizes another.

## OPS-MAINT-PROD-001 — Enable production maintenance schedules

Prerequisites: OPS-DEPLOY-002, OPS-MAINT-001 has passed in the selected hosted
pre-production environment, OPS-HOST-001 records the scheduler, DEC-023 and
production retention ownership are approved, and the user approves enabling the
exact named production schedules.

- [ ] State the production service/project-ref fingerprint, job names, cron/time
      zone, batch/runtime limits, concurrency keys, estimated cost, and owner
      before enabling anything.
- [ ] Create each schedule disabled first with the production-only runtime
      scope; prove no release credential and no non-production target is present.
- [ ] Run the implemented bounded dry-run/preflight, then enable one job at a
      time and observe one authorized bounded execution or record why the first
      due run is later.
- [ ] Configure last-success/backlog/failure alerts and a one-control disable
      procedure.
- [ ] Record non-secret scheduler IDs, exact configuration, approval, first
      result/due time, and rollback owner.

Do not infer production authorization from OPS-MAINT-001 and do not expose a
public maintenance route.
