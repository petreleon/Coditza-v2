# Learning, grading, and progress rules

## Theory completion

- A completion is unique for `(user_id, theory_section_id)`.
- Marking complete is idempotent and records the first completion time.
- A learner may remove a completion only while the chapter's
  `first_completed_at` is null. Once the chapter has ever completed, removal is
  permanently denied even if current `completed_at` later becomes null.
- An allowed published theory correction preserves existing completions. A new
  learning requirement uses a new section ID and follows DEC-021.
- Archived sections do not appear in new progress denominators.

## Supported answer payloads

The API validates a payload according to the authored item type:

| Type | Learner payload | Grading |
| --- | --- | --- |
| `single_choice` | one `optionId` | exact option ID match |
| `multiple_choice` | unique array of `optionIds` | exact set equality; order ignored |
| `short_text` | one `text` string | exact match after the DEC-011 normalization |
| `python_code` (exercise only) | canonical bounded `files[{path,content}]` package | all required tests pass in the authoritative pinned server WASM sandbox |

Reject unknown fields, duplicate selected options, options from another item,
empty/over-4,000-character short text, more than 20 selected options, and
payloads that do not match the authored type.

The exact Python package, deterministic fixture, verdict, retry, and
infrastructure-failure rules are owned by
[PRD-WASM-001](05-python-code-exercises.md). Quiz questions reject
`python_code`.

## Exercise attempts

- Submission creates one immutable attempt.
- It snapshots the exercise's frozen `definitionVersion`; later lifecycle
  `version` changes do not alter grading/history.
- Scalar grading and insert happen in one server-controlled operation. A
  `python_code` submission first creates an idempotent private grading job; only
  its server-side sandbox finalization transaction may insert the immutable
  attempt and recalculate progress.
- Full points are awarded only for a correct response; otherwise zero.
- Repeated submissions create separate attempts.
- `isPassed` for an exercise means at least one correct attempt exists.
- An idempotency key prevents a network retry from creating a duplicate attempt.
- Re-execution after a grader crash is allowed for the same deterministic job;
  only one final attempt/result is committed.

## Quiz attempts

- Starting an attempt atomically assigns the next attempt number and enforces the
  quiz's maximum-attempt rule.
- Every started attempt consumes one attempt number, even if it later expires.
- The attempt records the immutable quiz `definitionVersion`. Lifecycle
  `version` is separate and is never used to invalidate an attempt.
- A learner may save one answer per question while the attempt is in progress.
- A null quiz time limit creates an untimed attempt with `expiresAt=null`.
  Untimed attempts remain editable until manual submission. A timed attempt is
  editable only while database `now() < expiresAt`.
- Submitted/expired attempts cannot be edited.
- Submission locks the attempt, grades all expected questions once, stores the
  result, and changes status in one transaction.
- Omitted answers receive zero.
- PostgreSQL score percent is
  `floor((points_earned::numeric * 10000) / points_possible) / 100`; the explicit
  numeric cast prevents integer division and yields two decimal places without
  binary floating-point.
- `passed` is `scorePercent >= passingPercent`.
- Retrying either terminal status (`submitted` or `expired`) returns the stored
  result without grading again.

## Progress calculation

For each chapter:

- `theoryPercent` = completed published sections / published sections * 100.
- `exercisePercent` = required published exercises passed / required published
  exercises * 100.
- `quizPercent` = required published quizzes passed / required published quizzes
  * 100.
- A category with zero required items counts as 100, although publish rules make
  the initial chapter contain all three categories.
- For a non-empty category, store
  `floor((completed_count::numeric * 10000) / total_count) / 100` as
  `numeric(5,2)`.
- `overallPercent` is the integer floor of the three category percentages'
  arithmetic mean.
- `firstCompletedAt` is set only the first time all three categories reach 100.
- `completedAt` represents current completion: set when currently 100 and
  cleared if newly published required content reopens progress.
- Recalculation preserves `completedAt` while the chapter remains 100, sets it
  only on a transition from incomplete to complete, and clears it only on a
  transition back below 100. `firstCompletedAt` is set on the first such
  completion transition and never changed.
- Recalculation is idempotent and occurs after completion/attempt state changes.

For each module:

- percent is completed published chapters / published chapters * 100;
- calculate its non-empty percent with the same two-decimal floor formula;
- completion occurs when every currently published chapter is complete;
- API results explain numerator and denominator to avoid misleading clients.
- current module `completedAt` is derived, not stored: when at least one
  published chapter exists and all are currently complete, it is the maximum
  current chapter `completed_at`; otherwise it is null;
- no module `firstCompletedAt` exists in the MVP.

## Planned tasks

### PRD-LEARN-001 — Centralize answer validation

- [ ] Implement one domain validator used by exercises and quiz questions.
- [ ] Normalize short text on both authoring and grading paths.
- [ ] Reject references to options outside the target item.
- [ ] Keep keys and authored explanations out of learner input schemas.

### PRD-LEARN-002 — Make grading retry-safe

- [ ] Require a UUID idempotency key for exercise submission and quiz start.
- [ ] Scope keys by user plus operation.
- [ ] Store and return the first successful response for a repeated key.
- [ ] Reject reuse of a key with a different request hash.

### PRD-LEARN-003 — Recalculate progress

- [ ] Perform source write and progress recalculation transactionally where
      possible through a database function.
- [ ] Add an admin-only reconciliation job/function for repairing snapshots.
- [ ] Compare stored snapshots with a from-source calculation in tests.
- [ ] Never accept progress percentages from a client.
