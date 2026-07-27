# Handoff protocol for a weaker model

## Before acting

1. Confirm implementation is authorized in `STATUS.md`.
2. Read `README.md`, `TASKS.md`, `STATUS.md`, `NEXT.md`, fixed/open decisions,
   and the active task file.
3. Confirm every dependency and gate.
4. Inspect current files and user changes.
5. State the one task ID and exact intended files/checks.

## While acting

- Do the smallest coherent change for that task.
- Treat `<TBD>`, missing credentials, ambiguous environment, and unaccepted
  production/cost choices as blockers, not values to invent.
- Never select a frontend technology.
- Never modify Dashboard schema after migrations are established.
- For hosted Supabase, use Chrome and the Chrome operation file.
- Never read/repeat/store/screenshot/log secrets.
- Treat TOTP codes/seeds, QR SVG, `otpauth` URI, refresh tokens and complete
  factor/challenge/Auth bodies as secrets even in local tests.
- Do not touch production without an approved production task.
- Do not broaden scope or clean unrelated files.
- If a check fails, preserve a sanitized error and fix within scope; do not mark
  completion by inference.

## Before handing off

1. Run every active task verification and appropriate earlier phase gate.
2. Inspect the diff for scope, secrets, generated drift, and user changes.
3. Complete `../09-templates/00-task-report-template.md`.
4. Update `TASKS.md` and `STATUS.md` with objective non-secret evidence.
5. Put exactly one unblocked task in `NEXT.md` and make it the sole registry
   `next` row.
6. Leave a failed/blocked task unchecked.

## Blocked handoff

Record:

- exact missing decision/permission/credential/external state;
- why safe local alternatives are exhausted;
- the smallest user action needed;
- files/state already changed;
- safe rollback, if any;
- which task remains next after resolution.

Do not claim the whole project is blocked merely because a later production or
frontend decision is deferred; continue any independent safe task.
