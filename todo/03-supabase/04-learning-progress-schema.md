# Attempts, completion, and progress schema

## `public.theory_section_completions`

- `user_id uuid references auth.users on delete cascade`
- `theory_section_id uuid references theory_sections on delete restrict`
- `completed_at timestamptz not null default now()`
- primary key `(user_id, theory_section_id)`
- indexes on section and user/time

Only effectively published sections can be completed.

## `public.exercise_attempts`

| Column | Rule |
| --- | --- |
| `id` | primary key |
| `user_id` | Auth user FK, cascade on account deletion |
| `exercise_id` | restrict delete |
| `exercise_definition_version` | frozen definition snapshot |
| `answer` | validated JSONB learner payload |
| `is_correct` | server/database generated |
| `points_earned` | integer, zero or full points in MVP |
| `points_possible` | positive snapshot |
| `submitted_at` | server timestamp |
| `created_at` | audit timestamp |

Attempts are immutable after insert. Index `(user_id, exercise_id,
submitted_at desc, id)`.

For `python_code`, `answer` stores the validated canonical source package and
the attempt has one associated digest/verdict evidence row specified by
[SUP-WASM-001](13-python-code-verification-data.md). The private grading job is
not an attempt: infrastructure failure creates no attempt and changes no
progress.

## `public.quiz_attempts`

| Column | Rule |
| --- | --- |
| `id` | primary key |
| `user_id` | `auth.users(id)` FK with `on delete cascade` |
| `quiz_id` | restrict delete |
| `quiz_definition_version` | frozen definition snapshot |
| `attempt_number` | positive, unique per user/quiz |
| `status` | `in_progress`, `submitted`, or `expired` |
| `started_at` | server time |
| `expires_at` | null or server-derived deadline |
| `submitted_at` | null until finalized |
| `points_earned`, `points_possible` | null until final, valid bounded integers |
| `score_percent` | null or numeric(5,2), 0–100 |
| `passed` | null until final |
| timestamps | common fields |

Constraints:

- unique `(user_id, quiz_id, attempt_number)`;
- partial unique index allows only one `in_progress` attempt per user/quiz;
- submitted/expired field consistency checks;
- `expires_at` is null for an untimed frozen quiz definition and non-null for a
  timed one; only non-null deadlines may transition to `expired`;
- score and pass fields cannot be supplied by an ordinary table grant.

## `public.quiz_attempt_answers`

- `attempt_id uuid references quiz_attempts on delete cascade`
- `question_id uuid references quiz_questions on delete restrict`
- `answer jsonb not null`
- `answered_at timestamptz not null`
- `is_correct boolean null` until finalization
- `points_earned integer null` until finalization
- primary key `(attempt_id, question_id)`

The database function verifies that question belongs to the attempt's quiz and
frozen definition and that selected options belong to that question. Because a
published definition is immutable and its rows are retained, save/submit never
compare against current `row_version`; archive/reorder/replacement cannot
invalidate an active or historical attempt.

## `public.chapter_progress`

- `user_id uuid references auth.users on delete cascade`
- `chapter_id uuid references chapters on delete restrict`
- `theory_percent numeric(5,2) not null`
- `exercise_percent numeric(5,2) not null`
- `quiz_percent numeric(5,2) not null`
- `overall_percent numeric(5,2) not null`
- `first_completed_at timestamptz null`
- `completed_at timestamptz null`
- `updated_at timestamptz not null`
- primary key `(user_id, chapter_id)`

This is a recalculable snapshot, not the source of grading truth. Module progress
is aggregated from published chapters and this table; do not add a second cache
until measured performance requires it. `first_completed_at` is never cleared;
`completed_at` is cleared when current required content reopens the chapter.
Module `completedAt` is derived as the maximum current chapter `completed_at`
only when at least one published chapter exists and every published chapter is
currently complete; otherwise it is null.

Do not eagerly create one row per learner/chapter at signup. Progress reads
start from the current effectively published curriculum and left-join this
snapshot plus aggregate source counts, so a missing snapshot never hides a
module/chapter. With no learning sources, synthesize: completed count 0,
non-empty required category percent 0, empty required category percent 100,
overall percent from the fixed weighting rule, and both timestamps null. If
source activity exists without a snapshot, return the from-source aggregate,
emit a safe reconciliation-mismatch signal, and require the admin reconciliation
path; never silently insert/repair during a GET.

## `private.idempotency_records`

- `user_id uuid references auth.users(id) on delete cascade`, `operation`, and
  UUID `idempotency_key` form the unique key;
- `operation` is constrained to exactly `exercise_submit`, `quiz_start`,
  `python_grading_reserve`,
  `admin_create_module`, `admin_create_chapter`,
  `admin_create_theory_section`, `admin_create_exercise`,
  `admin_create_quiz`, `admin_clone_exercise`, or `admin_clone_quiz`;
- store canonicalization version, canonical request hash, result resource ID,
  original success status, original safe `Location`, original safe response
  body JSONB, creation time, and expiry;
- canonicalization version is positive; request hash is `bytea` constrained to
  exactly 32 bytes;
- a repeated key with the same hash returns the prior result;
- the same key with a different hash produces a conflict;
- `expires_at` is database-set to `created_at + interval '24 hours'` for the
  DEC-023 default; ordinary callers cannot choose it;
- a record is live exactly while database `now() < expires_at`; at or after the
  boundary it does not replay or conflict and the key may begin a new operation;
- request reuse and cleanup take the same
  `(user_id, operation, idempotency_key)` advisory lock. Under that lock they
  re-read the row: a request deletes/replaces an expired record before running,
  while cleanup deletes only if it is still expired. Scheduler timing therefore
  never lengthens or shortens the 24-hour semantic window;
- automatic cleanup is an operations task, never a substitute for request-time
  expiry handling.

## `private.audit_events`

- UUID ID;
- `actor_kind` is exactly `user` or `system`;
- nullable `actor_user_id` references `auth.users(id) on delete set null`;
  system events require null, user events require a non-null actor at insertion
  but retain a null actor after approved account deletion;
- action, entity type/ID, safe changed-field summary, reason when required,
  request ID, timestamp;
- append-only to application paths;
- never store tokens, answer payloads/keys, complete content bodies, or passwords.

## SUP-DATA-003 — Implement and prove learning records

- [ ] Create tables in dependency order.
- [ ] Add immutable-attempt protections.
- [ ] Add indexes for ownership, pagination, policy, and progress queries.
- [ ] Create atomic start/save/submit and recalculation functions.
- [ ] Test cross-user/cross-question references, duplicate active attempts,
      attempt limits, time expiry, and repeat submission.
- [ ] Compare every stored progress snapshot with a from-source calculation.
- [ ] Test account deletion against the approved privacy rule.
