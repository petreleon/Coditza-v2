# Database, migration, and RLS quality gate

This file coordinates the detailed cases in
`../03-supabase/09-database-tests.md`.

## QA-DB-001 — Clean reproducibility

- [ ] Start the official local Supabase stack.
- [ ] Reset from an empty database using only committed migrations.
- [ ] Load deterministic seed data.
- [ ] Run database lint and all pgTAP tests.
- [ ] Regenerate database types and show no drift.
- [ ] Stop/restart and prove persisted local data behavior is understood.
- [ ] Repeat in CI from a clean checkout.

## QA-RLS-001 — Direct Data API matrix

For each public table/view/function, record expected privileges and test as
anonymous, authenticated learner/editor/admin tokens, and server context.

- [ ] Prove all user-facing roles are denied SELECT/INSERT/UPDATE/DELETE/EXECUTE
      on Coditza domain objects.
- [ ] Prove RLS is enabled and default privileges keep newly created objects
      closed.
- [ ] Test answer-key/private schema denial.
- [ ] Test the server role has only intended table/function privileges.
- [ ] Test each server-only function reloads passed actor role/ownership,
      validates references/state, and returns safe columns.
- [ ] Test no Fastify input can override the server-derived actor ID.

## QA-DB-002 — Transactions/concurrency

- [ ] Two reorder operations cannot corrupt positions.
- [ ] Two quiz starts cannot exceed max or create two active attempts.
- [ ] Two submits settle one result.
- [ ] Two first-admin/final-admin role changes preserve an admin.
- [ ] A failed nested authoring/publish operation leaves old draft unchanged.
- [ ] Source write and progress snapshot either both commit or both roll back.

## QA-DB-003 — Query plans

- [ ] Load large synthetic fixtures.
- [ ] Inspect catalog, attempt history, progress, and RLS-filtered query plans.
- [ ] Verify intended indexes are used where selective.
- [ ] Record baseline plan/latency without personal data.
- [ ] Remove redundant indexes only after comparison and migration review.

Gate failure in this file blocks every remote migration push.
