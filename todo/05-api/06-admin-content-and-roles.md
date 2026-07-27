# Admin, authoring, and role endpoints

All endpoints require authentication. Content endpoints require editor/admin;
role endpoints require admin. All responses use `private, no-store`.

## Content list, detail, and update routes

Every list accepts `status=draft|published|archived`, `limit`, and `cursor`.
Parented lists additionally require the named parent filter. Omitting `status`
means all statuses. Content list order is `position ASC, id ASC`. Detail/list
DTOs contain authored public fields, lifecycle
timestamps, version, and safe audit actor IDs, but never private answer specs.
Exercise/quiz DTOs additionally expose `definitionVersion`; attempt DTOs use
that value and never the lifecycle `version`.

| Resource | List/detail path | Required list filter | Draft PATCH fields | Published correction fields |
| --- | --- | --- | --- | --- |
| module | `/api/v1/admin/modules[/:id]` | none | `slug`, `title`, `descriptionMarkdown` | `title`, `descriptionMarkdown` |
| chapter | `/api/v1/admin/chapters[/:id]` | `moduleId` | `slug`, `title`, `summaryMarkdown`, `estimatedMinutes` | `title`, `summaryMarkdown`, `estimatedMinutes` |
| theory section | `/api/v1/admin/theory-sections[/:id]` | `chapterId` | `title`, `bodyMarkdown`, `estimatedMinutes` | `title`, `bodyMarkdown`, `estimatedMinutes` |
| exercise | `/api/v1/admin/exercises[/:id]` | `chapterId` | `title`, `promptMarkdown`, `exerciseType`, `points`, `isRequired`; scalar types use complete `options`, `answerSpec`, feedback, while `python_code` uses the complete private Python definition from PRD-WASM-001 | none |
| quiz | `/api/v1/admin/quizzes[/:id]` | `chapterId` | `slug`, `title`, `instructionsMarkdown`, `passingPercent`, `maxAttempts`, `timeLimitSeconds`, `isRequired` | none |

Square brackets in the table describe list versus detail forms; they are not
literal route characters. Each `PATCH .../:id` requires `expectedVersion` and
at least one allowed field. A published correction also requires non-empty
`correctionReason`. Parent, position, ID, status, timestamps, and unlisted fields
are always rejected. Draft exercise tree changes are atomic and increment the
exercise `version` and `definitionVersion` once. Draft quiz question trees use
the definition route
below. No authored-resource `DELETE` route exists.

## Lifecycle action routes

For each exact resource name `modules`, `chapters`, `theory-sections`,
`exercises`, and `quizzes`, implement:

- `POST /api/v1/admin/<resource>/:id/publish` with `{ expectedVersion }`;
- `POST /api/v1/admin/<resource>/:id/archive` with
  `{ expectedVersion, reason }`.

Repeated action against the same final state returns the same safe 200 state.
Module/chapter archive atomically archives descendants. Assessment-only routes:

- `POST /api/v1/admin/exercises/:id/clone`;
- `POST /api/v1/admin/quizzes/:id/clone`;
- `POST /api/v1/admin/exercises/:oldId/replace`;
- `POST /api/v1/admin/quizzes/:oldId/replace`.

Clone body is exactly `{ expectedVersion }` and returns 201 plus `Location` for
a new draft. Each clone requires a UUID `Idempotency-Key`; same-hash retry
replays the original 201/Location/body before checking current source state, and
different input conflicts. Replace body is exactly
`{ replacementId, expectedOldVersion, expectedReplacementVersion }`; it returns
200 after atomically validating/publishing the replacement, swapping positions,
archiving the old assessment, recalculating progress, and auditing both IDs.

Exact nesting for creation:

- `POST /api/v1/admin/modules`
- `POST /api/v1/admin/modules/:moduleId/chapters`
- `POST /api/v1/admin/chapters/:chapterId/theory-sections`
- `POST /api/v1/admin/chapters/:chapterId/exercises`
- `POST /api/v1/admin/chapters/:chapterId/quizzes`

Every create body uses the resource's draft fields, omits server fields, and
returns 201 plus `Location`. The parent comes only from the route. A client
cannot supply parent ID, position, status, version, actor, or timestamps in the
body; initial placement is the next deterministic sibling position.
Every create requires a UUID `Idempotency-Key` and uses the database step-zero
replay/conflict/expiry contract. The operation name includes the exact resource
type, and the canonical hash includes the route parent plus normalized body.
Chapter creation returns 409 when its module is archived. Theory/exercise/quiz
creation returns 409 when either chapter or module is archived. Clone/replace
enforce the exact source/status/ancestor preconditions from the lifecycle file.

## Assessment authoring

- Exercise create/update accepts its options and answer spec in one transaction.
- `python_code` exercise create/update instead accepts one closed, bounded
  runtime/starter/public/private-test/limit definition, rejects scalar
  options/answer specs, and never returns hidden tests on an ordinary admin
  list/detail response. Its protected authoring detail follows the same
  reauthentication/audit rules as scalar keys.
- `PUT /api/v1/admin/quizzes/:quizId/definition` atomically replaces the complete
  draft question/option/key tree and requires `expectedVersion`.
- Exercise option and quiz question/option inputs use the exact `clientRef` /
  `correctOptionRef(s)` contract from the assessment schema. Database UUIDs are
  not accepted for newly submitted tree references; the response includes the
  generated ref-to-ID mapping.
- Question/option array order is authoritative position 0..n-1; child
  `position` input is rejected. Complete-definition payloads also obey the
  aggregate 1 MiB/1,000,000-byte contract.
- `GET /api/v1/admin/exercises/:id/authoring` and
  `GET /api/v1/admin/quizzes/:id/authoring` may return protected answer specs only
  for a draft and only after staff authorization through a fixed-search-path
  database function.
- Never log/cache answer specs. Published definitions are cloned to draft before
  authoring.
- Publishing validates the entire definition and ancestor rules atomically.

## Reorder endpoints

- `PUT /api/v1/admin/modules/order`
- `PUT /api/v1/admin/modules/:moduleId/chapters/order`
- `PUT /api/v1/admin/chapters/:chapterId/theory-sections/order`
- `PUT /api/v1/admin/chapters/:chapterId/exercises/order`
- `PUT /api/v1/admin/chapters/:chapterId/quizzes/order`

Body contains the complete ordered sibling ID list plus current versions. The
exact body is `{ items: [{ id, expectedVersion }, ...] }`; array index becomes
position 0..n-1. It must include every sibling in the parent scope, including
draft, published, and archived rows, because the database uniqueness constraint
covers all statuses. The transaction rejects missing, duplicate, foreign, stale,
or extra IDs. Archived rows may move only through this complete reorder
transaction; their authored content remains read-only.
Each row whose position changes increments version once; an unchanged row
preserves version. Reissuing stale expected versions returns 409 and makes no
change; a current already-matching list returns 200 as a no-op without duplicate
audit.

## Role endpoint

### `PUT /api/v1/admin/users/:userId/role`

Body: `{ role: "learner"|"editor"|"admin", reason: string }`.

- exact target exists;
- actor is admin;
- no self-promotion shortcut or final-admin removal;
- idempotent when role already matches, but still returns current state;
- audit includes actor/target/previous/new role/reason/request ID; a same-role
  request records a safe `role_change_noop` event so the administrative request
  is accountable without changing state;
- returns profile ID/current role only, not Auth metadata.

## Audit endpoint

### `GET /api/v1/admin/audit-events`

- admin only;
- cursor-paginated by `createdAt DESC, id DESC`;
- optional bounded filters for actor, action, entity type/ID, and time window;
- safe fields only; never answer bodies/keys, tokens, full Markdown, or Auth
  metadata;
- `private, no-store`.

## API-ADMIN-001 — Implement content operations

- [ ] Build in hierarchy order: module, chapter, theory, exercise, quiz.
- [ ] Implement every exact list/detail/create/PATCH/action route and query/body
      contract above; reject bracket/template strings as literal paths.
- [ ] Add draft validation/version conflict/slug conflict per slice.
- [ ] Add publish/archive/clone/reorder transactions and audit.
- [ ] Prove every create and clone stores/replays its original
      201/Location/safe body, conflicts on changed input, and cannot duplicate
      after a committed response is lost or the source/parent state later
      changes.
- [ ] Prove published correction allowlists/reason/version/audit and that theory
      completions remain unchanged.
- [ ] Prove no hard-delete route and subtree archive preserves history.
- [ ] Prove learner forbidden and editor/admin matrix.
- [ ] Prove every published assessment is immutable.
- [ ] Prove keys appear only in protected draft-authoring responses and never in
      catalog/learner logs/OpenAPI schemas.

## API-ADMIN-002 — Implement role control

- [ ] First-admin bootstrap test.
- [ ] Admin success/idempotency/audit.
- [ ] learner/editor forbidden.
- [ ] final-admin protection and concurrent role-change test.
- [ ] no user-editable metadata authority.
