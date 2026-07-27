# Completion and progress endpoints

## Theory completion

### `PUT /api/v1/me/theory-sections/:sectionId/completion`

- no body;
- section must be effectively published;
- idempotently records first completion time;
- recalculates chapter progress;
- returns `{ sectionId, completedAt, chapterProgress }`.

### `DELETE /api/v1/me/theory-sections/:sectionId/completion`

- allowed only while the chapter's persisted `firstCompletedAt` is null;
- idempotent;
- returns 204 and recalculates progress.

## Progress reads

### `GET /api/v1/me/progress`

Paginated module summaries:

```text
moduleId, title, completedPublishedChapters, totalPublishedChapters,
percent, completedAt
```

Order is the current published module `position ASC, moduleId ASC`; module
detail chapter entries use published chapter `position ASC, chapterId ASC`.
The database read starts with published curriculum and left-joins the caller's
snapshot/source aggregates. It must never start from `chapter_progress` or inner-
join a fresh learner's missing row away.

### `GET /api/v1/me/progress/modules/:moduleId`

Returns module summary and ordered chapter entries:

```text
chapterId, title,
theory{completed,total,percent},
exercises{completed,total,percent},
quizzes{completed,total,percent},
overallPercent, completedAt
```

All counts use the current effectively published/required curriculum. The
response always includes numerators/denominators so a client can explain change
after content publication/archive.

Module `completedAt` is null unless at least one published chapter exists and
all published chapters currently have non-null `completedAt`; when complete it
is the maximum of those current chapter timestamps. It is derived at read time
and the module DTO has no `firstCompletedAt`.

Chapter detail also returns `firstCompletedAt`. `completedAt` is current and may
be null after newly published required content reopens a previously completed
chapter; `firstCompletedAt` remains unchanged.

For a caller with no learning history, every published module/chapter still
appears. Each non-empty required category is 0%, an empty required category is
100%, completed counts are zero, and timestamps are null. If sources exist but a
snapshot is unexpectedly missing, return one set-based from-source result, emit
the safe mismatch metric, and leave repair to the explicit admin reconciliation
operation; GET never writes.

## Admin reconciliation

### `POST /api/v1/admin/progress/reconcile`

Admin only. Body is exactly `{ userId, chapterId, reason }`. The function
derives progress from immutable sources under the common progress lock, replaces
only the recalculable snapshot, and returns safe
`{ before, after, changed }` percentages/timestamps. It never changes answers,
grades, attempts, or completion sources and always writes a sanitized audit
event.

## API-PROGRESS-001 — Implement and verify

- [ ] Completion idempotency and remove restriction.
- [ ] Denominator/default weighting rules from the product plan.
- [ ] Required versus optional content.
- [ ] Draft/archived exclusion.
- [ ] Snapshot recalculation in the same workflow as a source change.
- [ ] Admin-only reconciliation path and audit.
- [ ] No client-supplied percentage; learner routes never accept a user ID, and
      only the exact admin reconciliation body accepts a target user ID.
- [ ] One aggregate query/RPC, not an N+1 route loop.
- [ ] A brand-new learner with no `chapter_progress` rows sees every published
      module/chapter with exact zero/empty-category defaults and null timestamps.
- [ ] A deliberately missing snapshot with sources returns the from-source
      values, emits the safe mismatch signal, and performs no GET-time write.
- [ ] Server-side owner authorization, cross-user route tests, and direct Data
      API denial.
- [ ] Progress remains explainable after curriculum changes.
