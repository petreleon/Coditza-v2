# ARC-SEC-003 — Privileged-action audit contract

## Outcome

**Status:** complete
**Execution mode:** local only
**Date:** 2026-07-29

The privileged-action audit contract is accepted and proved over the local
Supabase store. The completed boundary is private, owner-controlled,
append-only, and unavailable to normal runtime roles. It records safe actor,
entity, request, timestamp, reason-code, and change-delta metadata without
accepting content or Auth material.

## Scope

- Intended: validate the existing audit boundary, close its free-text and
  opaque-summary gap with a forward-only migration, add focused proof, and
  document the contract for later function owners.
- Excluded: Fastify routes, public RPCs, audit reads, user policies, generic
  event buses, role/bootstrap workflows, SMTP, TOTP/MFA, Chrome, hosted
  Supabase, Vercel, deployment, and credentials.

## Accepted contract

- Every event has a user or system actor kind, nullable actor user ID, action,
  entity type/ID, request ID, and database timestamp. User events require an
  actor at insertion; system events require none.
- Changed-field names and structured delta keys match exactly. Each delta is an
  object with only before and after values drawn from a finite safe-code
  vocabulary. Role, lifecycle, and state facts may be recorded; ordinary
  text-bearing changes use redacted and raw previous/new values are never
  stored.
- Reasons are nullable only where the owning workflow does not require one.
  When required, they are one approved non-content code, not free text. The
  concrete future function decides mandatory reason-code use.
- Audit records cannot contain token, refresh-token, password, TOTP/OTP,
  QR/otpauth, answer, answer-key, Markdown/content-body, source, test, email,
  or Auth-SDK material through either field names, delta values, or reason.
- Normal runtime roles cannot use the private schema, read or mutate the audit
  table, or execute its append helper. The private append helper is owned by
  coditza_owner and has an empty search path.
- Inserts require the internal workflow marker established by the owner helper.
  Updates and deletes are rejected, except the database foreign-key-driven
  actor-user nulling performed when an Auth user is deleted.

## Changed

- 20260729000000_harden_privileged_audit_contract.sql: added the structured
  change-summary column, closed reason-code constraint, safe-delta validator,
  nine-argument append helper, trigger hardening, and default-deny routine
  privileges.
- audit_contract_test.sql: added 11 local pgTAP assertions covering catalog,
  grants, helper ownership, valid user/system events, actor consistency, closed
  safe deltas, secret/content category rejection, append-only behavior, direct
  runtime denial, and account-deletion anonymization.
- local-stack.mjs and package.json: added the fixed audit-contract verifier
  action and script. It runs all preceding database suites between protected
  deterministic resets.
- Existing learning-record regression tests and future-task documentation now
  use the closed audit contract.

## Verification

Command:

    npm run supabase:verify-audit-contract:local

Result: PASS.

- 12 reviewed migrations applied.
- Primitive, Auth-profile, core-content, assessment-definition,
  learning-record, and audit-contract pgTAP suites passed.
- Public/private schema diff and lint passed, as did loopback and deterministic
  before/after reset checks.
- Manifest SHA-256:
  fedbe65c13402985e83685045ffad110032b94225210fdaaa41bf401a419542c
- Current learning-record suite SHA-256:
  acf1f0b4a39d6be192ac2cf64d6c6f04fca2692b1843a4d72b747405d1792842
- Audit-contract suite SHA-256:
  96cf379ab91170f628e4627bc9a2b8a9959182ef790c221ce90581f7be1e0f62
- Audit-contract reset fingerprint SHA-256:
  e158a793c4510b24b249ca91eb29c9a8e0d7ef865581995bcc66c2277cfa04a2

Command:

    docker compose --profile checks run --build --rm checks npm run check:foundation

Result: PASS — formatting, lint, type checking, 177 unit tests, 63 negative
boundary fixtures, four positive controls, and the API build passed.

The launcher also refused a hostile Docker target override before it could
execute a database action.

## Limitations and next-owner rule

There are no privileged business workflows yet. SUP-FUNCTIONS-001 must make
each owned workflow append an audit event in the same transaction and must
enforce the action-specific reason-code requirement. It must use safe role,
lifecycle, or state codes where facts are meaningful, and redacted where a
field is text-bearing. Extending either closed vocabulary requires a reviewed
forward migration and task-owned tests.

## External actions

Only local Docker/Supabase verification ran. No hosted project, browser,
environment variable, SMTP setting, MFA setting, Vercel resource, GitHub
setting, or credential changed.

## Secret-safety confirmation

No credential, token, connection string, TOTP/QR/otpauth material, private
answer, complete content body, or unsafe screenshot/log was read, stored, or
reported.

## Next

SUP-FUNCTIONS-001 is the sole next eligible task. All currently owned tables
and the hardened audit contract now exist; that task owns the server-only
transactional workflow facades, their grants, normalization vectors, and
concurrency proof.
