# Chapter content read endpoints

All routes require authentication and an effectively published ancestor chain.

## Theory

### `GET /api/v1/chapters/:chapterId/theory`

- paginated by `position,id`;
- returns `id`, `chapterId`, `title`, `bodyMarkdown`, `position`,
  `estimatedMinutes`, and caller `completedAt`;
- never returns audit actor IDs or lifecycle internals.

### `GET /api/v1/theory-sections/:sectionId`

- same fields for one published section.

## Exercises

### `GET /api/v1/chapters/:chapterId/exercises`

### `GET /api/v1/exercises/:exerciseId`

Safe exercise DTO:

```text
id, chapterId, title, promptMarkdown, exerciseType, position, points,
isRequired, options[{id,labelMarkdown,position}],
callerSummary{attemptCount,isPassed,lastSubmittedAt}
```

`options` is empty for short text. It never contains correctness, answer spec,
accepted text, or private feedback. `lastSubmittedAt` is nullable.
For `python_code`, `options` is also empty and the safe runtime/starter/public
test projection is exactly the one in
[the Python API contract](07-python-code-attempts.md); hidden tests and digests
never appear.

## Quizzes

### `GET /api/v1/chapters/:chapterId/quizzes`

- lightweight metadata: ID, title, position, passing percent, attempt/time rules,
  required flag, learner attempt summary;
- does not include questions.

### `GET /api/v1/quizzes/:quizId`

Learner quiz detail is metadata-only so questions cannot be previewed without
consuming an attempt. Safe DTO:

```text
id, chapterId, title, instructionsMarkdown, position, passingPercent,
maxAttempts, timeLimitSeconds, isRequired,
learnerAttemptSummary{
  attemptsStarted,maxAttempts,remainingAttempts,activeAttemptId,
  lastFinalizedAt,lastPassed
}
```

Questions/options are returned only by starting or reading an owned active quiz
attempt. They never include correctness, accepted answers, feedback, or answer
specs before finalization. `remainingAttempts` is null when attempts are
unlimited; active/last fields are nullable.

## API-CONTENT-001 — Implement content reads

Order: theory, exercises, quiz list metadata, quiz metadata detail.

- [ ] Enforce ancestor-aware visibility in the server query and service; direct
      user Data API access remains denied.
- [ ] Use bounded pagination for collections.
- [ ] Validate stable order and intentional empty arrays.
- [ ] Prove a selected option from one exercise cannot influence another route.
- [ ] Prove learner quiz detail contains no questions and start consumes an
      attempt before returning them.
- [ ] Snapshot response schemas and scan for forbidden fields.
- [ ] Test editor/admin preview access only through separately protected admin
      endpoints; learner routes remain published-only even for staff callers.
- [ ] Update OpenAPI after each slice.
