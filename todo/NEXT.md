# Next task

The sole next implementation task is:

**SUP-DATA-001 — Implement and prove core hierarchy.**

Prerequisites verified: G1, SUP-LOCAL-001/002, SUP-PRIMITIVES-001,
SUP-AUTH-001, and PRD-ROLE-001 are complete. `SUP-SMTP-LOCAL-001` and
SUP-MFA-001 remain separately ineligible; they do not block the independent
local content-schema task.

## Read first

1. README.md, TASKS.md, STATUS.md, and 00-control/00-scope-and-non-goals.md
2. 00-control/01-fixed-decisions.md and 00-control/02-open-decisions.md
3. 03-supabase/01-local-cli-and-migrations.md,
   03-supabase/02-core-content-schema.md,
   03-supabase/05-functions-constraints-indexes.md,
   03-supabase/07-rls-policy-matrix.md, and
   03-supabase/09-database-tests.md
4. docs/implementation/SUP-PRIMITIVES-001.md, SUP-AUTH-001.md, and
   PRD-ROLE-001.md
5. 02-architecture/04-data-flow-and-security.md,
   08-execution/00-roadmap.md, 01-dependency-map.md, and
   03-handoff-protocol.md

## Permitted scope

1. Add only reviewed forward local migrations for the core hierarchy:
   `public.modules`, `public.chapters`, and `public.theory_sections`, plus the
   narrowly required private trigger helper(s). Create parents before children.
2. Give every created Coditza object the established `coditza_owner` ownership,
   default-deny grants, RLS enabled but not forced, and no permissive direct
   user policy. Keep `private` unexposed and do not grant direct DML to the
   runtime role.
3. Implement exactly the documented fields and constraints: UUID keys;
   lowercase kebab slugs; trimmed bounded Markdown/text; non-negative,
   deferrable sibling positions; lifecycle status/published-at consistency;
   positive row version; bounded estimated minutes; profile audit FKs with
   `ON DELETE SET NULL`; restrict parent deletes; timestamp and row-version
   update behavior; and all documented FK/list/actor indexes.
4. Add task-owned transaction-rolled-back pgTAP tests for parent/child shape,
   owner/RLS/grants, bounds, slug and sibling uniqueness, update behavior,
   restricted deletion, transactional full-sibling reorder, stale-version
   conflict, and effective child visibility beneath unpublished ancestors.
5. Extend the fixed local test allowlist/verifier only with an exact new core
   test path; preserve the primitive and profile regression suites. Use the
   protected reset/history/diff/lint workflow before recording completion.

## Explicitly forbidden

- Do not add exercises, quizzes, options, answer keys, attempts, completions,
  progress, audit/idempotency tables, workflow RPCs, role-control, seeds,
  generated types, or Fastify routes.
- Do not create `authored_resource_type` unless a required static private helper
  in this task genuinely needs it; never expose it as a generic public RPC
  input.
- Do not configure TOTP/MFA, Gmail SMTP, Auth UI/client flows, root Compose,
  Chrome/hosted Supabase, Vercel, or a deployment.
- Do not run `supabase link`, use a remote URL, authenticate a CLI, inspect
  credentials, or modify prior applied migrations.

## Required evidence before completion

1. A fresh protected local reset applies the new migration history with empty
   unexpected public/private schema diffs and lint results.
2. The fixed pgTAP suite proves all scope-owned hierarchy constraints and
   denials using synthetic, transaction-rolled-back data only.
3. The local stack remains loopback-only; credentials remain ignored and
   unread; no hosted action occurs.
4. The completion report records any changed type surface as deferred to
   SUP-TYPES-001 and names exactly one next eligible task.

If a required constraint or visibility rule needs an unapproved policy,
workflow function, external service, or product decision, stop at that boundary
and record it rather than broadening SUP-DATA-001.
