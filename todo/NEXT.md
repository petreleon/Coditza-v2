# Next task

The sole next implementation task is:

**ARC-SEC-003 — Accept the privileged-action audit contract (next; not
started).**

Prerequisite verified: SUP-DATA-003 completed the local private audit store,
its append-only helper, safe-summary validation, direct-access denial, account
deletion behavior, and protected verification. SUP-SMTP-LOCAL-001 and
SUP-MFA-001 remain independently ineligible; neither blocks this local audit
contract acceptance.

This is a narrow architecture/security acceptance task. It must map the
approved privileged-action audit requirements to the completed database
boundary and prove that normal application roles cannot append, alter, delete,
or read audit events directly. It does not authorize a public API, a generic
audit event bus, or a new client-facing query surface.

## Read first

1. README.md, TASKS.md, STATUS.md, and 00-control/00-scope-and-non-goals.md.
2. 00-control/01-fixed-decisions.md and 00-control/02-open-decisions.md.
3. 02-architecture/04-data-flow-and-security.md,
   02-architecture/06-modular-hexagonal-architecture.md,
   03-supabase/04-learning-progress-schema.md,
   03-supabase/05-functions-constraints-indexes.md, and
   03-supabase/07-rls-policy-matrix.md.
4. docs/implementation/SUP-DATA-003.md and the preceding Supabase completion
   reports needed to understand the owner/private-schema convention.
5. 08-execution/00-roadmap.md, 08-execution/01-dependency-map.md, and
   08-execution/03-handoff-protocol.md.

## Permitted scope

1. Produce an explicit acceptance mapping for every required audit field:
   actor kind, nullable actor user ID, action, entity type/ID, sanitized
   change summary, required reason, request ID, timestamp, ownership, and
   account-deletion handling.
2. Verify and document that audit entries are append-only through the intended
   owner-controlled helper and that normal runtime roles have no direct table
   read, insert, update, delete, or routine-execution access.
3. Verify and document the safe-summary contract: no password, token, refresh
   token, TOTP code/secret, QR or otpauth material, answer payload, answer key,
   or complete Markdown/content body can enter an audit event.
4. Reuse the reviewed protected local verifier and add only task-owned,
   narrowly necessary proof. A forward-only migration is permitted only if an
   objective audit-contract gap is found; do not modify an applied migration.
5. Record one non-secret completion report with exact checks, result,
   limitations, and exactly one next eligible task.

## Required proof

1. The report maps each ARC-SEC-003 requirement to an implemented constraint,
   helper, privilege, test, or documented operational boundary.
2. Direct runtime-role access and mutation are denied; no permissive RLS policy
   or public routine bypass exists.
3. Safe-summary validation rejects the forbidden secret, answer, and full-body
   categories without logging their contents in test output or reports.
4. A protected fresh local reset, the relevant regression suites, schema diff,
   lint, loopback assertion, and the repository foundation checks pass if code
   changes. Credentials remain unread and no hosted state changes.
5. The task report identifies only the next eligible task and leaves all other
   ownership boundaries intact.

## Explicitly forbidden

- Do not add Fastify routes, public RPCs, direct user policies, audit list/read
  endpoints, client UI, generated types, generic audit buses, or a new policy
  matrix.
- Do not configure Gmail SMTP, TOTP/MFA, Chrome, hosted Supabase, Vercel,
  deployment, billing, CLI authentication, a secret, or remote URL.
- Do not implement admin/bootstrap/role-control workflows, Python-verifier
  definitions/jobs/evidence, a controller, learner authoring, or public
  application modules.
- Do not alter applied migrations, weaken default denial, or broaden the audit
  schema beyond the documented privileged-action contract.

If an audit requirement needs a public surface, a product decision, an external
service, or a workflow owned by another task, stop at that boundary and record
it rather than expanding ARC-SEC-003.
