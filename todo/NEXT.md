# Next task

The sole next implementation task is:

**SUP-DATA-002 — Implement and prove assessments.**

Prerequisites verified: G1, SUP-LOCAL-001/002, SUP-PRIMITIVES-001,
SUP-AUTH-001, PRD-ROLE-001, and SUP-DATA-001 are complete.
`SUP-SMTP-LOCAL-001` and SUP-MFA-001 remain separately ineligible; they do not
block this independent local assessment-schema task.

## Read first

1. README.md, TASKS.md, STATUS.md, and 00-control/00-scope-and-non-goals.md
2. 00-control/01-fixed-decisions.md and 00-control/02-open-decisions.md
3. 03-supabase/01-local-cli-and-migrations.md,
   03-supabase/02-core-content-schema.md,
   03-supabase/03-assessment-schema.md,
   03-supabase/05-functions-constraints-indexes.md,
   03-supabase/07-rls-policy-matrix.md, and
   03-supabase/09-database-tests.md
4. docs/implementation/SUP-PRIMITIVES-001.md, SUP-AUTH-001.md,
   PRD-ROLE-001.md, and SUP-DATA-001.md
5. 02-architecture/04-data-flow-and-security.md,
   08-execution/00-roadmap.md, 01-dependency-map.md, and
   03-handoff-protocol.md

## Permitted scope

1. Add only reviewed forward local migrations for assessment definitions in
   documented parent-to-child order: public exercise/quiz roots and their
   public options/questions first, then the matching private answer-key tables.
   Reuse the established content lifecycle helper for roots where its shared
   fields apply. Do not modify an applied migration.
2. Add only the narrow private validators and named database functions that
   SUP-DATA-002 explicitly requires for atomic draft-definition replacement and
   publish validation. They must be owner-controlled, fixed-search-path,
   default-deny, non-public helper surfaces; do not add Fastify or generic
   client-callable authoring APIs.
3. Implement the documented assessment invariants: UUID/default/timestamp
   conventions; bounded Markdown/text; scoped, deferrable positions and slugs;
   points/time/attempt/threshold bounds; initial-draft/lifecycle/row-version
   behavior; immutable published definitions; positive definition versions;
   private-key separation; exact answer-spec schemas; normalized short text;
   generated-ID option ownership; and required FK/list/actor indexes.
4. Apply the established `coditza_owner` ownership, RLS-enabled/not-forced
   state, no permissive direct user policies, unexposed private schema, and
   explicit default-deny privileges to every created Coditza object. Keep
   direct runtime table DML and private reads denied.
5. Add one exact allowlisted assessment pgTAP suite and fixed local verifier
   action that preserves primitive, profile, and core-hierarchy regressions.
   Use only synthetic transaction-rolled-back data and the protected
   reset/history/diff/lint workflow.

## Required proof

1. Catalog tests prove ownership, columns/defaults/FKs, RLS/no policies,
   indexes, private-key isolation, helper/function ACLs, and absence of direct
   runtime DML/private reads.
2. Tests prove malformed answer specs, invalid limits/bounds, duplicate or
   missing client references, cross-question/cross-exercise option IDs,
   scoped uniqueness, and stored keys containing generated IDs rather than
   client references.
3. Atomic draft-definition replacement is proven for options/keys and quiz
   question trees; it validates expected row version/definition version and
   rejects every published-assessment mutation. Publish validation proves the
   documented minimum option/question/quiz and Python-code constraints.
4. Fresh protected reset applies the complete reviewed history with empty
   public/private schema diffs and lint results; all fixed regression suites
   pass; the local stack stays loopback-only and credentials remain unread.
5. The completion report names changed type surface as deferred to
   SUP-TYPES-001 and identifies exactly one eligible next task.

## Explicitly forbidden

- Do not add attempts, submissions, completions, progress snapshots,
  idempotency/audit tables, Python verification jobs/evidence, admin/bootstrap
  role control, seeds, generated database types, Fastify routes, or client UI.
- Do not create a broad public RPC, expose `private`, grant direct user access,
  or add an effective-publication/user-token policy matrix ahead of its owning
  SUP-FUNCTIONS-001/SUP-RLS-001 tasks.
- Do not configure TOTP/MFA, Gmail SMTP, root Compose, Chrome/hosted Supabase,
  Vercel, or a deployment. Do not link/authenticate a CLI, use a remote URL,
  inspect credentials, or alter a prior applied migration.
- Do not introduce `authored_resource_type` unless one required static helper
  demonstrably needs it; never expose it as generic public input.

If a required assessment rule needs an unapproved policy, workflow outside this
task, external service, or product decision, stop at that boundary and record
it rather than broadening SUP-DATA-002.
