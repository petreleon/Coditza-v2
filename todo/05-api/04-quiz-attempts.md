# Quiz attempt endpoints

## Start

### `POST /api/v1/quizzes/:quizId/attempts`

- requires UUID `Idempotency-Key`;
- performs idempotency replay/conflict before any current quiz/attempt checks;
- atomically verifies publication, max attempts, and no existing active attempt;
- finalizes any stale active attempt whose deadline passed before deciding
  whether another attempt is allowed;
- if that finalization consumes the last allowed attempt, the RPC commits the
  terminal result/progress and returns a structured
  `422 attempt_limit_reached` outcome instead of throwing/rolling back;
- every start consumes an attempt number, including an attempt that expires;
- snapshots quiz `definitionVersion`, attempt number, start/deadline; later
  lifecycle `version` changes never invalidate the attempt;
- repeated key returns the same attempt;
- returns the original 201 status/Location/body for a replay and adds
  `Idempotency-Replayed: true`.

Safe result:

```text
id, quizId, quizDefinitionVersion, attemptNumber, status, startedAt, expiresAt,
questions[{
  id,promptMarkdown,questionType,position,points,
  options[{id,labelMarkdown,position}]
}],
savedAnswers[{questionId,answer,answeredAt}]
```

No key/correctness/feedback is present before submission.

## Read/save

### `GET /api/v1/me/quiz-attempts`

Paginated own history with optional quiz/status filters. Stable order is
`coalesce(submittedAt, startedAt) DESC, id DESC` so active attempts do not have a
null cursor component. List rows are:

```text
id, quizId, quizDefinitionVersion, attemptNumber, status, startedAt, expiresAt,
submittedAt, pointsEarned, pointsPossible, scorePercent, passed
```

Final-result fields are null while in progress.
The assessment Supabase adapter calls `list_own_quiz_attempts`; the function
reloads the actor,
applies the owner filter and exact functional-keyset order, and returns no
answer-key/feedback definition columns.

### `GET /api/v1/me/quiz-attempts/:attemptId`

Returns the start-safe question/option definition, saved answers, and
timing/state. If finalized, it additionally returns the exact submit-result
grading fields/feedback; otherwise it returns no correctness/feedback. The
assessment Supabase adapter calls `get_own_quiz_attempt`, which reloads
ownership and uses the
retained immutable definition. For a terminal result it begins from every frozen
question and left-joins answers, so omitted questions appear with null answer,
zero points, and only the applicable incorrect feedback. The runtime role never
directly reads private keys.

### `PUT /api/v1/me/quiz-attempts/:attemptId/answers/:questionId`

- body is the question-type answer union;
- database function locks the attempt first, then rechecks owner,
  `in_progress`, and `(expiresAt is null OR now() < expiresAt)`;
- idempotent upsert: an identical answer preserves `answeredAt`; a changed
  answer receives database `now()`;
- question/option must belong to attempt definition;
- returns saved answer and timestamp, never correctness.

### `DELETE /api/v1/me/quiz-attempts/:attemptId/answers/:questionId`

- takes the same attempt lock, then rechecks owner, `in_progress`, and
  `(expiresAt is null OR now() < expiresAt)`;
- idempotently removes a saved answer;
- returns 204.

## Submit

### `POST /api/v1/me/quiz-attempts/:attemptId/submit`

One database transaction:

1. lock attempt;
2. verify owner;
3. return the stored result without grading if status is terminal
   (`submitted` or `expired`);
4. if `expiresAt is not null AND now() >= expiresAt`, use saved answers and
   finalize with status `expired`; an untimed attempt can only finalize as
   `submitted`;
5. grade every question against private keys;
6. give omitted answers zero;
7. calculate points, two-decimal percent, and pass;
8. finalize answers/attempt and recalculate progress.

Result:

```text
id, quizId, quizDefinitionVersion, attemptNumber, status, submittedAt,
pointsEarned, pointsPossible, scorePercent, passed,
answers[{questionId,submittedAnswer,isCorrect,pointsEarned,feedbackMarkdown}]
```

For both terminal statuses, populate `submittedAt`, score, pass, and per-answer
grades. Return exactly one answer-result item per frozen question in question
position/ID order. If no answer row exists, use `submittedAnswer: null`,
`isCorrect: false`, `pointsEarned: 0`, and the safe authored incorrect feedback
(null when none). Never return raw correct options/accepted answers.

## API-QUIZ-001 — Implement and verify

- [ ] Atomic start and attempt-limit concurrency.
- [ ] Same-hash start replay succeeds after archive, terminalization, or current
      limit exhaustion; new keys enforce current state.
- [ ] Stable question order; shuffling is not in MVP.
- [ ] Save/remove answer ownership, state, deadline, and reference validation.
- [ ] Exact grading/rounding/threshold tests.
- [ ] Empty/partial answer behavior.
- [ ] Concurrent/repeated submission produces one result.
- [ ] Save-versus-submit, delete-versus-submit, and save/delete-versus-scheduled-
      expiry races serialize on the attempt lock; no answer changes after
      grading.
- [ ] Expiry at the exact boundary uses database time.
- [ ] Untimed start stores a null deadline; save/delete remain available until
      manual submit, submit produces `submitted`, and the expiry worker never
      selects it.
- [ ] A denied new start after stale finalization preserves the terminal attempt
      and progress despite returning 422.
- [ ] Old attempt survives quiz archive/replacement.
- [ ] Cross-user access and direct score manipulation fail.
- [ ] List/detail functions recheck owner, conceal cross-user attempts, include
      every omitted terminal question, select only the applicable feedback
      branch, and return no private key/spec.
- [ ] Strict attempt-write rate limits and safe logs.
