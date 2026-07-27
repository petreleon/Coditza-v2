# Observability and audit operations

## Logs

- structured JSON in shared environments;
- request ID, environment, route pattern, status, duration, safe user ID, error
  code;
- never authorization/cookies/keys/passwords/connection strings/answer
  payloads/keys/free-text responses;
- production log access is least-privilege and retained for an approved period.

## Metrics

Track without high-cardinality answer/content labels:

- request count, error count, latency by route/status class;
- active requests and rate-limit count;
- auth failure count;
- `mfa_required` count and sanitized MFA enrollment/challenge/verification
  failure/rate-limit signals available from the Auth provider, without user,
  factor or challenge labels;
- Supabase dependency error/latency and readiness;
- quiz start/submit/pass outcome counts without answer details;
- idempotency replay/conflict count;
- Python grading queue depth/oldest age, claim/finalize/retry/dead count,
  sandbox launch/limit verdict, manifest/determinism mismatch, and controller
  saturation—without source, hidden tests, output, user, or Auth labels;
- progress-reconciliation mismatch count;
- maintenance success/failure, processed count, backlog age, and last success;
- process/container resource usage.

## Alerts

After selected pre-production baselines:

- sustained readiness failure;
- elevated 5xx/dependency errors;
- unusual auth/rate-limit spikes;
- unusual MFA downgrade/failure/reset signals;
- latency regression;
- database connection/quota pressure;
- progress reconciliation mismatch;
- failed migration/deploy/backup verification.

Every alert has an owner, severity, runbook, deduplication window, and safe
notification content.

## OPS-OBS-001 — Verify instrumentation

- [ ] Unit-test redaction and metric labels.
- [ ] Trace one request by request ID across route/service/dependency log events.
- [ ] Simulate Supabase failure and confirm readiness/alert behavior.
- [ ] Prove health probes do not flood normal request metrics/quota.
- [ ] Confirm audit events are distinct from operational logs and append-only.
- [ ] Review log examples for user/answer/secret leakage.
- [ ] Prove Auth/TOTP metrics and alerts contain no email, factor/challenge ID,
      QR/URI/secret/code, token or Auth body.

## OPS-OBS-PREPROD-001 — Activate selected pre-production observability

Prerequisites: OPS-OBS-001, OPS-RUNBOOK-001, the selected hosted
pre-production deployment, QA-PERF-001 baselines, known host/monitoring
provider, and explicit approval for the named monitoring resources, access and
cost.

- [ ] Resolve the exact development or optional-staging service, Supabase
      project-ref fingerprint, log source, environment label, owner and on-call
      destination; reject every production or mismatched source.
- [ ] Bind hosted log routing and dashboards to that exact source with the
      approved retention and least-privilege viewer access.
- [ ] Configure baseline-derived readiness, 5xx/dependency, latency,
      Auth/MFA-downgrade/failure, rate-limit and resource-pressure alerts; label
      them proposed operational thresholds rather than contractual SLOs.
- [ ] Link every alert to an owner, severity, deduplication window and exercised
      runbook. Later maintenance/recovery tasks add and prove their own signals.
- [ ] Trigger and acknowledge safe synthetic signals, including a redacted
      `mfa_required`/Auth failure signal, without inducing an outage or storing
      user, factor, challenge, token, email, answer or content data.
- [ ] Record sanitized dashboard/alert identifiers, provider limitation,
      threshold rationale, owner, test time/result and cost tier.
- [ ] Make no production monitoring change in this task.

This task supplies the hosted observability evidence for G7. Local
OPS-OBS-001 instrumentation evidence alone cannot pass that gate.

## OPS-OBS-PROD-001 — Activate production observability

Prerequisites: OPS-OBS-PREPROD-001, SUP-CHROME-PROD-001, ARC-ENV-PROD-001,
OPS-DEPLOY-002, accepted DEC-020 thresholds, and explicit approval for the named
production monitoring resources/cost.

- [ ] Bind dashboards/log routing to the exact production service, environment,
      project-ref fingerprint, and owner; reject a non-production source.
- [ ] Configure the approved retention and least-privilege viewer/on-call access.
- [ ] Create every required alert with threshold/window/severity/owner/runbook
      and a safe notification template.
- [ ] Verify redaction and low-cardinality labels on production-formatted
      synthetic signals without logging user content, answers, URLs, or keys.
- [ ] Trigger and acknowledge a safe test signal; do not induce a real database
      outage or expose public traffic.
- [ ] Record dashboard/alert identifiers, owner, test time/result, and cost tier
      without secret webhook tokens.

This task configures monitoring only. It does not admit public traffic or mark
the production release complete.
