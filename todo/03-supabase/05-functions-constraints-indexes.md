# Database functions, constraints, and indexes

## Required helper functions

Sensitive helpers live in `private`. Server-only RPC entry functions live in
`public` only because the Supabase Data API exposes named functions there; their
execute grants are revoked from `PUBLIC`, `anon`, and `authenticated`. They
return explicit safe record types and are callable only with the server secret.

The table below names logical operations, not permission to create one generic
cross-context RPC. ARC-DESIGN-001 expands every operation into exactly one
module-owned public facade, or into explicitly named facades when curriculum
and assessment variants are required. A cross-context transaction has one
recorded coordinating context and one public facade. Static dispatch and shared
SQL helpers may live in `private`, but the runtime cannot execute them directly.

- `private.set_updated_at()` — sets `updated_at` only during update.
- `private.normalize_short_text(text)` — exact
  `nfkc_ascii_ws_ascii_lower_v1` behavior: apply PostgreSQL `normalize(input,
  NFKC)`, replace runs of ASCII U+0009 through U+000D and U+0020 with one
  U+0020, trim U+0020, then use `translate` to map ASCII `A-Z` to `a-z`.
  Non-ASCII letters remain case-sensitive; do not use locale-dependent
  `lower()`.
- `private.has_role(actor_user_id, app_role)` — checks current profile role.
- `private.is_staff(actor_user_id)` — true for editor/admin.
- `private.assert_active_staff_actor(actor_user_id)` — locks the live profile,
  requires no security hold, and requires editor/admin before authoring reads
  or writes.
- `private.is_effectively_published_<resource>(id)` — or equivalent stable SQL
  used consistently by policies and workflows.
- `private.validate_exercise_definition(id)`.
- `private.validate_quiz_definition(id)`.
- `private.recalculate_chapter_progress(user_id, chapter_id)`.

## Required transactional workflow functions

| Function | Caller/context | Required behavior |
| --- | --- | --- |
| `update_own_profile(actor_id, display_name)` | server secret + verified actor | lock/load exact profile, validate name, update only that actor |
| `create_draft_content(actor_id, type, parent_id, input, idempotency_key, canonical_version, request_hash)` | server secret + verified staff actor | idempotency step zero; static type branch/exact input allowlist; chapter requires non-archived module, lower items require non-archived chapter+module; next position; audit/result |
| `update_draft_content(actor_id, type, id, expected_version, input)` | server secret + verified staff actor | static type/field allowlist; atomic root/tree change; one row-version increment and, for behavior changes, one definition-version increment; audit |
| `correct_published_content(actor_id, type, id, expected_version, reason_code, input)` | server secret + verified staff actor | module/chapter/theory correction allowlist only; required approved reason code; preserve completion; audit |
| `replace_draft_quiz_definition(actor_id, quiz_id, expected_version, definition)` | server secret + verified staff actor | validate/replace complete question-option-key tree, increment row/definition versions once, no partial state |
| `get_draft_assessment_authoring(actor_id, type, id)` | server secret + verified staff actor | reload staff role, require draft, return protected ID-based definition/key projection, audit access |
| `start_quiz_attempt(actor_id, quiz_id, idempotency_key, canonical_version, request_hash)` | server secret + verified authenticated owner actor | idempotency step zero; for new key lock ancestors/quiz, recheck publication, finalize stale attempt, enforce limit, create deadline/result |
| `save_quiz_answer(actor_id, attempt_id, question_id, answer)` | server secret + verified owner actor | lock attempt; recheck owner/in-progress and `(expires_at is null or now() < expires_at)`; validate; identical retry preserves timestamp |
| `remove_quiz_answer(actor_id, attempt_id, question_id)` | server secret + verified owner actor | same attempt lock/rechecks as save; idempotent delete while untimed or before a non-null deadline |
| `submit_quiz_attempt(actor_id, attempt_id)` | server secret + verified owner actor | one row lock shared with expiry cleanup; both terminal statuses replay stored result; otherwise grade once/finalize/progress |
| `submit_exercise_attempt(actor_id, exercise_id, answer, idempotency_key, canonical_version, request_hash)` | server secret + verified authenticated owner actor | idempotency step zero; for new key lock ancestors/exercise, recheck publication, grade, insert attempt/progress |
| `reserve_python_grading_job(actor_id, exercise_id, files, idempotency_key, canonical_version, request_hash)` | server secret + verified authenticated owner actor | idempotency step zero; validate package, lock/recheck ancestors/exercise/runtime definition, enforce queue bound, create/replay one job |
| `claim_python_grading_jobs(controller_id, batch_limit, lease_ms)` | dedicated grader-controller server context only | bounded eligible `FOR UPDATE SKIP LOCKED`; lease and return minimal source/private-test/limit bundle |
| `finalize_python_grading_job(job_id, lease_token, result)` | dedicated grader-controller server context only | validate lease/closed result/digests; learner verdict inserts one attempt and recalculates progress exactly once; infrastructure result only retries/dead-letters |
| `list_own_exercise_attempts(actor_id, exercise_id_filter, cursor, limit)` | server secret + verified authenticated owner actor | reload actor; bounded owner-only keyset list; select correct/incorrect immutable feedback by stored result; return safe answer/result projection |
| `get_own_exercise_attempt(actor_id, attempt_id)` | server secret + verified authenticated owner actor | reload actor; conceal non-owner as absent; return immutable answer/result plus only result-selected feedback |
| `set_theory_completion(actor_id, section_id, completed)` | server secret + verified authenticated owner actor | lock ancestors/section, recheck publication, progress lock; idempotent insert; delete only before first chapter completion |
| `list_own_quiz_attempts(actor_id, quiz_id_filter, status_filter, cursor, limit)` | server secret + verified authenticated owner actor | reload actor; bounded owner-only functional-keyset list; return no private definition/key/feedback columns |
| `get_own_quiz_attempt(actor_id, attempt_id)` | server secret + verified authenticated owner actor | reload actor; conceal non-owner; safe immutable question/options + saved answers; if terminal left-join every frozen question and return result-selected feedback, including omitted questions |
| `reorder_content(actor_id, parent, ordered_ids, expected_versions)` | server secret + verified staff actor | exact all-sibling set including archived rows, one transaction, audit |
| `publish_content(actor_id, type, id, expected_version)` | server secret + verified staff actor | validate descendants/keys, transition, recalculate affected learner denominators, audit |
| `archive_content(actor_id, type, id, expected_version, reason_code)` | server secret + verified staff actor | required approved reason code, subtree/parent validity/history, recalculate affected learner denominators, audit |
| `clone_assessment(actor_id, type, id, expected_version, idempotency_key, canonical_version, request_hash)` | server secret + verified staff actor | idempotency step zero; published/archived source only; require non-archived chapter+module; lock/version-check, new tree IDs, remap answer specs, validate, draft/result |
| `replace_published_assessment(actor_id, old_id, draft_replacement_id, expected_versions)` | server secret + verified staff actor | distinct IDs; same chapter/type; old published, replacement draft, ancestors non-archived; swap positions, publish/archive, progress, audit |
| `list_own_progress_modules(actor_id, cursor, limit)` | server secret + verified authenticated owner actor | reload actor; start from published modules/chapters, left-join caller snapshots/source aggregates, synthesize missing zero/default state, stable keyset order |
| `get_own_module_progress(actor_id, module_id)` | server secret + verified authenticated owner actor | reload actor; require published module; return every published chapter in order using snapshot or from-source missing-row fallback; no N+1 |
| `reconcile_chapter_progress(actor_id, target_user_id, chapter_id, reason_code)` | server secret + verified admin actor | required approved reason code, progress lock, derive sources, replace snapshot only, audit safe before/after |
| `list_audit_events(actor_id, filters, cursor, limit)` | server secret + verified admin actor | reload admin role, bounded filters/keyset order, return safe projection from private audit table |
| `change_user_role(actor_id, target_user_id, role, reason_code)` | server secret + verified admin actor | serialize all admin-count changes, protect final admin, audit safe old/new role codes |
| `bootstrap_first_admin(target_user_id, reason_code)` | separately invoked server system context | serialize, require zero admins, promote once, system audit |
| `server_readiness()` | server secret only | bounded constant result proving Data API/database/function access; no row/user/secret data |
| `finalize_expired_quiz_attempts(batch_limit)` | scheduled server system context | select only in-progress rows where `expires_at is not null and now() >= expires_at`, bounded `FOR UPDATE SKIP LOCKED`; grade/finalize each once and recalculate owner progress |
| `purge_expired_idempotency(batch_limit)` | scheduled server system context | bounded expired selection; for each row take its request-key advisory lock, re-read, delete only when `expires_at <= now()`, return count only |

The operator-only `set_identity_security_hold` function is specified and owned
exclusively by SUP-AUTH-003 after these shared function-security/audit
primitives exist. It follows the same security-definer rules but is not part of
SUP-FUNCTIONS-001 and is never an HTTP/runtime use-case facade.

Every audited function passes the closed audit contract: safe changed-field
names, a change-summary object with exactly matching keys and approved
before/after codes, an optional approved reason code, and a server-generated
request UUID. It must never pass raw previous/new values, Markdown, answer
material, Auth material, or free-form reason text. A function requiring a reason
enforces its non-null approved code itself; the generic audit helper does not
guess which action requires one.

`start_quiz_attempt` returns a structured success-or-domain-outcome record for
expected denials. If it finalizes a stale attempt and then finds no remaining
attempt allowance, it commits finalization/progress and returns
`attempt_limit_reached`; it must not raise an exception that rolls the work back.
Fastify maps that outcome to 422. No idempotency success record is stored for the
denied new start.

Every security-definer function must:

- be owned by exact `coditza_owner`; its table-owner execution works with RLS
  enabled and not forced, while the runtime has no owner membership;
- set `search_path` to a safe explicit value or empty and schema-qualify objects;
- accept actor ID only from a narrow module-specific server adapter, then
  lock/load that
  profile and recheck its current role/ownership;
- document that Fastify verified the end-user token; secret-key PostgreSQL calls
  cannot independently derive the end user with `auth.uid()`;
- validate authorization again inside PostgreSQL;
- receive explicit execute grant for the server role only;
- avoid returning private columns;
- have concurrency and privilege tests.

Module-specific lifecycle/reorder facades accept only their owning context's
closed input variants or expose separate named operations. If a private helper
accepts `authored_resource_type`, it uses schema-qualified static `CASE`
branches and rejects unsupported values. No public runtime RPC may use that type
as a generic curriculum/assessment escape hatch, and no helper may interpolate a
client/server string into a SQL identifier or query.
Every create/clone/reorder/replace operation takes one consistent sibling-scope
lock (parent row, or a documented advisory key for root modules) before reading
or assigning positions, so two concurrent authors cannot choose the same slot.
Every audited workflow also accepts the server-generated UUID request ID; route
input cannot override it. For the exact key-required operations in the API
conventions, Fastify computes the RFC-8785/versioned idempotency hash and the
database atomically stores/compares it with the key.

At idempotency step zero, the key lock is acquired before every domain/lifecycle
lock. A live same-hash row replays; a live different-hash row conflicts. At
database `now() >= expires_at`, the request removes/replaces the expired row
under that same lock and proceeds as a fresh operation. The purge function uses
the identical lock and boundary, so cleanup racing reuse cannot delete the new
record. Purge may collect a bounded non-locking candidate ID/key list first, but
it must acquire the advisory key lock before taking a row lock or deleting and
must recheck the full key plus expiry afterward; this preserves global lock
order and avoids a request-versus-purge deadlock.

## Canonical lock protocol

All content functions use the same outer-to-inner order:

1. root-module list operations take one fixed transaction advisory lock;
2. operations inside a module lock the module row;
3. operations inside a chapter then lock the chapter row;
4. operations on one assessment/theory row then lock it;
5. operations on multiple same-level rows lock UUIDs in ascending order;
6. affected `(user_id, chapter_id)` progress keys are last, in ascending UUID
   order.

Child create/update/reorder/publish/clone/replace must take its ancestor locks,
so module/chapter subtree archive cannot race a descendant write. Quiz start and
assessment archive/replace take the same assessment-row lock. Attempt
save/remove/submit and scheduled expiry begin with the same attempt-row lock and
do not depend on the current lifecycle `row_version`; immutable retained
definitions make concurrent archive/replace safe. Every learner source write
and every curriculum-denominator change serializes the affected progress key
before recalculation. Advisory progress-key hash collisions may over-serialize
but must never weaken correctness.

For a curriculum-denominator change, “affected learners” is the distinct union
of users with a chapter-progress row, theory completion, exercise attempt, or
quiz attempt in each affected chapter. Recalculate that set synchronously with
set-based SQL in the lifecycle transaction—never a per-user network loop and
never a truncated batch. Pre-production query/latency evidence must establish
the supported set size. If the operation cannot fit the reviewed transaction
budget, production is blocked pending an explicit versioned dirty-marker/batch
design; the implementation may not silently switch semantics.

“Learner workflow” means any authenticated Coditza role acting on its own
learning data; editor/admin retain learner capabilities. It does not require
the app role to equal `learner`.

For a new idempotency key, quiz start and exercise submit—and for every theory
completion change—lock module -> chapter -> target, recheck effective
publication under those locks, acquire the learner/chapter progress lock, and
only then write source state and recalculate. Existing idempotency replay
returns at step zero without requiring current curriculum locks.

All draft child-tree changes (options, questions, keys) lock the owning
exercise/quiz and increment both root `row_version` and `definition_version`
exactly once. Direct child/key mutation outside the named function is denied.

Attempt read functions join retained immutable assessment definitions through
the function owner; the runtime role receives no direct private/key-table grant.
For feedback, choose only `feedback_correct_markdown` or
`feedback_incorrect_markdown` from the stored grading result and never return
the unused branch, correct IDs, accepted text, or an answer specification.
Terminal quiz detail starts from the complete frozen question set and left-joins
saved/graded answers so omitted questions cannot disappear.

## SUP-FUNCTIONS-001 — Implement workflow primitives

- [ ] Implement every curriculum, assessment, progress, operations, and
      platform helper/workflow in this file after its owning tables exist,
      except `reserve_python_grading_job`, `claim_python_grading_jobs`, and
      `finalize_python_grading_job`; SUP-WASM-001 exclusively owns those three
      after the shared function-security/idempotency primitives pass. Identity
      profile, role, bootstrap, and security-hold facades are separately owned
      by their identity tasks and are not implicitly pulled into this task.
- [ ] Apply the accepted ARC-DESIGN-001 ownership/RPC-coordinator map: every
      public facade has one context owner, and no generic public type-switched
      lifecycle function spans curriculum and assessment.
- [ ] Pin the exact normalization expression and run identical SQL/TypeScript
      golden vectors: composed/decomposed accents, ASCII case, tab/newline/space
      runs, empty-after-trim input, and non-ASCII case distinction.
- [ ] Treat the product specification and golden vectors as normative where SQL
      and TypeScript duplicate a pure rule; treat the committed transaction
      result as authoritative for current-state transitions and scores.
- [ ] Keep actor, authorization, locking, idempotency, audit, and progress
      changes in the same transaction.
- [ ] Grant execution only to the server path and prove direct user denial.
- [ ] Add concurrency tests before any HTTP mutation task uses a function.

Implementation note (2026-07-29): five forward-only slices are present:
structured idempotency replay, exact safe exercise/quiz-start response schemas,
assessment learner mutations, matching SQL/TypeScript normalization vectors,
service-role-only theory completion/current-curriculum progress reads with
source fallback, own archived assessment-history projections, a repaired module
progress next-cursor, live locked staff authorization predicates, and the first
named curriculum draft-module facade with a fixed root-scope position lock,
ID-only replay, and sanitized audit transition. They are documented in
[slice 01](../../docs/implementation/SUP-FUNCTIONS-001-slice-01.md) and
[slice 02](../../docs/implementation/SUP-FUNCTIONS-001-slice-02.md) and
[slice 03](../../docs/implementation/SUP-FUNCTIONS-001-slice-03.md) and
[slice 04](../../docs/implementation/SUP-FUNCTIONS-001-slice-04.md) and
[slice 05](../../docs/implementation/SUP-FUNCTIONS-001-slice-05.md).
Remaining authoring/lifecycle/operations facades and real two-session race
proof remain open; each authoring facade must use the locked active-staff
assertion rather than a bare role boolean.

## Constraint checklist

- [ ] Nonblank/length checks for authored text.
- [ ] Slug pattern and scoped uniqueness.
- [ ] Deferrable sibling-position uniqueness.
- [ ] Positive row/definition version, points, attempt, and time values.
- [ ] Percent values from 0 through 100.
- [ ] Parent-child and option ownership.
- [ ] Published timestamp/state consistency.
- [ ] Attempt lifecycle field consistency and immutability.
- [ ] Points earned never exceed possible.
- [ ] One active quiz attempt.
- [ ] Answer specs match question type.
- [ ] Content with learner history cannot be deleted or mutated incompatibly.

## Index checklist

- Every foreign key.
- Every `(user_id, resource_id)` ownership lookup.
- Content learner filters: parent, status, position, ID.
- Attempts: `(user_id, submitted_at desc, id)` and
  `(user_id, quiz_id, attempt_number)`.
- Quiz-history keyset order:
  `(user_id, coalesce(submitted_at, started_at) desc, id desc)`; add optional
  quiz/status-leading variants only when measured plans require them.
- Expiry worker:
  `(expires_at, id) where status = 'in_progress' and expires_at is not null`.
- Progress primary/lookup keys.
- Policy role and parent columns.
- Idempotency expiry and audit timestamp.

Use `EXPLAIN (ANALYZE, BUFFERS)` only against synthetic local data or the
explicitly selected hosted pre-production environment. Add an index from an
observed access pattern, not speculation, except foreign-key, RLS-support,
documented keyset, and bounded-maintenance indexes required above.
