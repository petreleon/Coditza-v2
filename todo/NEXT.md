# Next task

The sole next implementation task is:

**PRD-ROLE-001 — Enforce default learner creation.**

`SUP-AUTH-001` is complete. Its local migration and protected pgTAP suite
already establish the product behavior that this task must verify: an Auth-user
insert yields exactly one `learner` profile, ignores client role metadata, and
handles a replayed trigger safely. This is a **local requirement-verification
task**; it must not change the validated profile schema or add a new migration.

## Read first

1. README.md, TASKS.md, STATUS.md, and 00-control/00-scope-and-non-goals.md
2. 00-control/01-fixed-decisions.md and 01-product/01-roles-and-permissions.md
3. 03-supabase/06-auth-profiles-and-roles.md and
   03-supabase/09-database-tests.md
4. docs/implementation/SUP-AUTH-001.md and the current
   supabase/migrations/20260728020000_create_auth_profiles.sql and
   supabase/tests/auth_profiles_test.sql
5. 08-execution/00-roadmap.md, 01-dependency-map.md, and
   03-handoff-protocol.md

## Permitted scope

1. Trace each PRD-ROLE-001 checklist item to the completed profile migration
   and its task-owned local proof.
2. Verify that only `raw_user_meta_data.displayName` is accepted, client role
   metadata is ignored, the persisted role is explicitly `learner`, and the
   duplicate trigger proof leaves exactly one profile.
3. Update the four PRD-ROLE-001 checklist items, tracking files, and one
   concise non-secret implementation report.
4. Re-run the fixed protected local verifier only if the verification/report
   work changes the evidence surface; do not add a new test suite merely to
   duplicate SUP-AUTH-001.

## Explicitly forbidden

- Do not change `public.profiles`, its trigger, grants, RLS, or the migration
  history; a defect must be recorded and handed back to a new scoped database
  task rather than patched here.
- Do not configure TOTP/MFA, Gmail SMTP, Auth UI/client flows, Fastify routes,
  role-control/bootstrap/recovery functions, content tables, seeds, generated
  types, root Compose services, hosted resources, or frontend code.
- Do not run `supabase link`, authenticate a CLI, use a remote URL, open
  Chrome, inspect credentials, or create a deployment.

## Required evidence before completion

1. Every product checklist item maps to a concrete migration/test assertion
   with the exact learner/default/replay outcome.
2. The report states that MFA/AAL and Fastify domain authorization remain
   deferred; this verification does not claim a real end-user token flow.
3. No tracked secret, Auth body, factor/QR/TOTP material, user data, or hosted
   action appears in the change.
4. The completion record names exactly one next eligible task after the
   product verification.

If the existing protected evidence is incomplete or contradictory, do not
silently repair the database in this task. Record the discrepancy and return
the tracker to a newly scoped implementation task.
