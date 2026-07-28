# Next task

The sole next implementation task is:

**SUP-DATA-003 — Implement and prove learning records (next; not started).**

Prerequisites verified: G1, SUP-LOCAL-001/002, SUP-PRIMITIVES-001,
SUP-AUTH-001, PRD-ROLE-001, SUP-DATA-001, and SUP-DATA-002 are complete.
SUP-SMTP-LOCAL-001 and SUP-MFA-001 remain separately ineligible; neither blocks
this independent local learning-records task.

The boundary is deliberately narrow: add the durable source-of-truth and
recalculable learning records required by the approved data plan, with a fixed
local proof. Do not turn this database task into public APIs, hosted setup, or
an incomplete Python-grading implementation.

## Read first

1. README.md, TASKS.md, STATUS.md, and 00-control/00-scope-and-non-goals.md.
2. 00-control/01-fixed-decisions.md and 00-control/02-open-decisions.md.
3. 03-supabase/01-local-cli-and-migrations.md,
   03-supabase/03-assessment-schema.md,
   03-supabase/04-learning-progress-schema.md,
   03-supabase/05-functions-constraints-indexes.md,
   03-supabase/07-rls-policy-matrix.md,
   03-supabase/09-database-tests.md, and
   03-supabase/13-python-code-verification-data.md.
4. docs/implementation/SUP-PRIMITIVES-001.md, SUP-AUTH-001.md,
   SUP-DATA-001.md, and SUP-DATA-002.md.
5. 02-architecture/04-data-flow-and-security.md,
   08-execution/00-roadmap.md, 01-dependency-map.md, and
   03-handoff-protocol.md.

## Permitted scope

1. Add only forward local migrations, in dependency order, for
   `theory_section_completions`, `exercise_attempts`, `quiz_attempts`,
   `quiz_attempt_answers`, `chapter_progress`, private idempotency records, and
   private append-only audit events. Follow the established owner, UUID,
   timestamp, foreign-key, default-deny, and RLS-enabled conventions. Do not
   modify an applied migration.
2. Encode the documented immutable attempt, frozen definition-version, bounded
   answer/score/timestamp, unique attempt-number, one-active-quiz-attempt,
   finalization/expiry, and progress-snapshot invariants. Completion rows may
   reference only effectively published theory. A missing snapshot must remain
   readable as a from-source aggregate; it must not be silently inserted during
   a read.
3. Add only narrowly scoped owner-controlled database functions required for
   atomic exercise submission, quiz start/save/submit/expiry behavior,
   idempotency replay/conflict/expiry, audit append, and deterministic progress
   recalculation. Use fixed search paths, explicit grants/revocations, actor
   checks, and private helper surfaces. No function may expose answer keys or
   create a broad client-callable authoring/grading API.
4. Keep Python-code grading fail-closed. An infrastructure failure creates no
   attempt and changes no progress. Reserve/claim/finalize jobs, private
   artifacts, digest/verdict evidence, and the authoritative WASM execution
   plane belong to SUP-WASM-001, not this task.
5. Add an exact allowlisted local pgTAP suite and verifier action for learning
   records. It must preserve all primitive, profile, core-content, and
   assessment regressions and use only synthetic data rolled back by each test
   transaction.

## Required proof

1. Catalog, ACL, RLS/no-policy, index, constraint, and schema-isolation tests
   cover every public and private object, including direct runtime DML/private
   read denial and owner-only helper execution.
2. Tests prove theory completion publication checks; cross-user, cross-quiz,
   and cross-question references fail; attempts are immutable after their
   permitted workflow transition; duplicate active quiz attempts, invalid
   limits, expiry, and repeat submission fail safely; and published definition
   history is used rather than current mutable state.
3. Tests prove idempotency uses the canonical request hash and its 24-hour
   window correctly, permits a fresh record after expiry, and cannot disclose
   unsafe responses. Audit events are append-only, preserve the approved
   account-deletion privacy behavior, and reject tokens, answers, keys, and
   complete content bodies.
4. For representative source states, every stored chapter-progress snapshot
   equals a from-source recalculation, with the documented empty/missing-source
   and timestamp rules. Account deletion follows the approved cascade/set-null
   rule without leaving unsafe identity data.
5. A fresh protected reset applies the complete reviewed history with clean
   public/private schema diff and lint results. All fixed regression suites and
   the task suite pass, the stack remains loopback-only, and credentials remain
   unread. The completion report identifies exactly one next eligible task.

## Explicitly forbidden

- Do not add Fastify routes, public RPCs, direct user policies, client UI,
  generated database types, seeds, admin/bootstrap or role-control workflows,
  learner authoring, broad policy-matrix work, or a hosted action.
- Do not configure TOTP/MFA, Gmail SMTP, root Compose, Chrome, hosted
  Supabase, Vercel, deployment, billing, or a remote URL. Do not authenticate a
  CLI, inspect credentials, or alter prior applied migrations.
- Do not implement private Python definitions, verifier jobs, controller
  selection, hidden-test execution, or finalization evidence before
  SUP-WASM-001. Do not add a placeholder that lets `python_code` grading pass.

If a rule requires an unapproved policy, product decision, external service, or
workflow owned by another task, stop at that boundary and record it rather than
broadening SUP-DATA-003.
