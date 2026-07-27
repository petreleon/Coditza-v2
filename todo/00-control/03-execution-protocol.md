# Execution protocol

This protocol is written for an implementation model that must avoid guessing.

## Before starting any task

- [ ] Read `todo/README.md`, `todo/TASKS.md`, `01-fixed-decisions.md`, and the
      active task file.
- [ ] Confirm every prerequisite task is complete.
- [ ] Run a read-only repository status check and list relevant existing files.
- [ ] Look for repository-specific instructions such as `AGENTS.md`.
- [ ] Identify user-owned uncommitted changes and avoid overwriting them.
- [ ] State the exact task ID, intended files, assumptions, and verification.
- [ ] If the task changes external state, confirm that the task and user have
      authorized that exact change.

## While implementing

- Work on one task ID only. Do not bundle later roadmap work.
- Keep the request path explicit: HTTP schema/auth adapter -> one application
  use case -> narrow outbound port -> module-specific adapter -> presenter.
- Keep SQL changes in one forward migration for the active schema task.
- Add or update tests in the same task as behavior.
- Use placeholders only when the task explicitly permits them.
- Do not leave `TODO`, disabled tests, broad `any` types, swallowed errors, or
  hard-coded secrets as a substitute for completion.
- Do not weaken RLS, validation, CORS, rate limits, or tests to make a check pass.
- Never print access tokens, secret keys, passwords, full environment files, or
  raw request authorization headers.

## Verification order

Unless the task says otherwise, run checks from cheapest to most expensive:

1. formatting;
2. lint;
3. TypeScript typecheck;
4. unit tests;
5. local Supabase migration reset and database tests;
6. Fastify integration tests against local Supabase;
7. Docker image build and Compose health check;
8. end-to-end and security flows;
9. generated OpenAPI and database-type drift checks.

Record the exact command and exit status. A skipped command must have a written
reason and prevents a phase gate from passing unless the gate explicitly allows
the skip.

## External-state rules

- Chrome Dashboard actions must follow
  `../03-supabase/00-chrome-dashboard-setup.md`, plus the separate staging or
  production file when that exact environment is in scope.
- Pause before any action that can create cost, change billing, create a
  production project, delete data, rotate a key, or deploy production.
- Resolve the exact project name and environment before a Dashboard action.
- Prefer local migrations and tests before linking or pushing to a remote
  project.
- Never run a destructive command against a linked project unless the command
  explicitly names the target and the user approved it.

## Completion report

For each task, report:

- task ID and outcome;
- files created or changed;
- decisions/defaults used;
- commands and pass/fail results;
- external changes, if any;
- remaining risks or blockers;
- next eligible task ID.

Use `../09-templates/00-task-report-template.md`.
Update `../TASKS.md`, `../STATUS.md`, and `../NEXT.md` atomically after evidence.

## Mandatory stop conditions

Stop rather than guessing when:

- the resolved Supabase project/environment is unclear;
- a secret is missing and cannot safely be derived;
- a remote or destructive action lacks explicit authorization;
- current repository state conflicts with the task's expected structure;
- a fixed decision contradicts a new user request;
- a required test repeatedly fails for an unknown reason;
- a schema change would invalidate published attempts or progress;
- the desired production region, tier, domain, or deployment provider is needed
  but not confirmed.
