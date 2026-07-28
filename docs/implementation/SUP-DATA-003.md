# SUP-DATA-003 — Learning records, progress, idempotency, and audit

## Outcome

**Status:** complete
**Execution mode:** local only
**Date:** 2026-07-29

The approved learning-record data boundary is implemented and verified. It adds
owner-controlled learning sources, immutable graded history, recalculable
chapter-progress snapshots, private idempotency records, and append-only
sanitized audit events. No hosted resource, Auth configuration, SMTP setting,
MFA setting, browser configuration, or secret was read or changed.

## Delivered scope

- Added three forward-only migrations:
  - 20260728050000_create_learning_public_records.sql;
  - 20260728050100_create_learning_private_records.sql; and
  - 20260728050200_create_learning_record_primitives.sql.
- Added public completion, exercise-attempt, quiz-attempt, quiz-answer, and
  chapter-progress records with ownership, retention, lifecycle, and
  definition-snapshot constraints.
- Added private idempotency and audit tables with default-deny privileges, RLS
  enabled without public policies, and owner-only helper execution.
- Added narrow database primitives for effective-publication checks, held-actor
  rejection, immutable attempt workflows, timed quiz expiry/finalization,
  deterministic chapter-progress recalculation, idempotency replay/conflict/
  expiry handling, and sanitized append-only audit writes.
- Added the task-owned 28-assertion pgTAP suite and the fixed
  verify-learning-records local launcher action. The action runs protected
  resets, all preceding database regression suites, schema drift checks, lint,
  loopback checks, and deterministic-state comparison.

Python-code grading remains fail-closed: this task accepts no Python attempt or
progress change. The private definitions, job reservation/claim/finalization,
verdict evidence, and authoritative Python/WASM execution plane remain owned by
SUP-WASM-001.

## Verification evidence

The canonical local verification command passed after a protected reset:

    npm run supabase:verify-learning-records:local

It applied 11 reviewed migrations, passed the primitive, Auth-profile,
core-content, assessment-definition, and learning-record pgTAP suites, and
reported clean public/private schema diff and lint results.

- Migration-and-seed manifest SHA-256:
  0263f832baadb42b3c29981d6416f38a25723a7e89da524ff64433f1af4a0e5d
- Primitive suite SHA-256:
  8b7399cc7bdab6f0c62752a16e04c13badbf4b09f56f0ea0344fdc8c63614220
- Auth-profile suite SHA-256:
  61f56dcf8a00e57af212f7842d530839d33a03c2b022287ca083deb3e44322e9
- Core-content suite SHA-256:
  09ad934f6a477f459eea88fc03f92d30208e5c368fcbed59980f294dba204634
- Assessment-definition suite SHA-256:
  b4273e77df5277584ad730633fd8079d51d74f7cb214aef85aad01386d9a0e1c
- Learning-record suite SHA-256:
  7fa700ab89839ac62a70483a95b1ce72b60d51a992189fb1e568af2a3705bd42
- Final reset fingerprint SHA-256:
  78ff14856f9eb45aa7a215e388fd3fa5dcf5c03448d5e08fef65833ba4759f67

The assessment gate also passed after the learning migrations:

    npm run supabase:verify-assessments:local

The repository foundation gate passed in the disposable Docker checks profile:

    docker compose --profile checks run --build --rm checks npm run check:foundation

That run passed formatting, lint, type checking, 177 unit tests, 63 negative
boundary fixtures, four positive controls, and the API build. Formatting,
Node syntax checking for the local launcher, and whitespace checking also
passed.

An attempted launcher override with a Docker target environment value was
refused before database execution. This confirms the reviewed local launcher
does not accept an alternate Docker target.

## Security and privacy interpretation

- Public learning tables have no direct application grants and have RLS enabled
  with no permissive policies. Private tables and helpers remain inaccessible
  to runtime roles.
- Completion writes and attempts require the relevant effective-publication
  hierarchy and an active learner profile; a security-held profile is rejected.
- Graded records retain their definition version and cannot be rewritten after
  their permitted workflow transition. Quiz finalization uses retained frozen
  definitions rather than the current lifecycle state.
- Chapter-progress values are deterministic, source-derived snapshots. Empty
  source categories use the documented 100-percent semantic while timestamps
  remain null until actual completion activity exists.
- Idempotency records use an exact operation allowlist, a 32-byte canonical
  request hash, a database-derived 24-hour boundary, and safe response-storage
  limits.
- Audit writes validate a narrow safe summary and reject answer payloads,
  answer keys, tokens, passwords, and complete content bodies. Account deletion
  cascades learner-owned records and retains audit history with a null actor
  reference as approved.

## Local Docker recovery note

During diagnosis, an unwrapped local Supabase reset accidentally used the
default Docker network while the reviewed stack used its project-specific
network. This left the existing Storage service unable to resolve its database
container. No migration or data-model defect was involved and no volume was
deleted. The reviewed local stop/start launcher restored the project-specific
loopback stack, after which all protected database and foundation gates passed.
Future verification uses the fixed launcher action only.

## Deferred and unchanged

- Gmail SMTP remains blocked until the user provides a Gmail App Password
  through the approved ignored local mechanism.
- Authenticator-app TOTP remains owned by its SMTP and MFA task path.
- No Chrome action, hosted Supabase action, Vercel action, GitHub visibility
  action, deployment, or environment-secret configuration was performed.

## Next task

ARC-SEC-003 is the sole next eligible task. It must accept and prove the
privileged-action audit contract over this completed local audit store without
adding a public API, policy matrix, Auth flow, SMTP, MFA, Python grader, or
hosted resource.
