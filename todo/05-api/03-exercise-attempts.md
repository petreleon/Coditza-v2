# Exercise attempt endpoints

This file owns the three scalar exercise types. `python_code` uses the
asynchronous, always-server-reexecuted contract in
[Python code exercise endpoints](07-python-code-attempts.md); it must never be
routed through the scalar database grader below.

## `POST /api/v1/exercises/:exerciseId/attempts`

Requires:

- authenticated user;
- effectively published exercise;
- UUID `Idempotency-Key` header;
- answer object matching the exercise type.

Accepted answer shapes:

```json
{"optionId":"<uuid>"}
```

```json
{"optionIds":["<uuid>","<uuid>"]}
```

```json
{"text":"learner response"}
```

Only the matching shape is valid. Unknown fields, duplicate choice IDs,
cross-exercise option IDs, and excessive text fail.

The server/database:

1. performs idempotency step zero and immediately replays/conflicts when found;
2. for a new key, locks module -> chapter -> exercise and rechecks effective
   publication;
3. validates and normalizes the answer;
4. acquires the learner/chapter progress lock;
5. grades with the private key and inserts one immutable attempt;
6. recalculates progress and stores the complete idempotency result;
7. returns no raw key.

New and replayed calls return the original 201 result/Location; a replay also
sets `Idempotency-Replayed: true`. Result fields:

```text
id, exerciseId, exerciseDefinitionVersion, submittedAt, isCorrect,
pointsEarned, pointsPossible, feedbackMarkdown
```

Authored feedback may explain the result but the response never includes
`correctOptionId(s)` or `acceptedAnswers`.

## `GET /api/v1/me/exercise-attempts`

- query: optional `exerciseId`, `limit`, `cursor`;
- always scopes by authenticated user, never an input user ID;
- history order `submittedAt desc,id desc`;
- returns the same safe result plus the learner's own submitted answer; DEC-010
  governs correctness/feedback timing, while another user's answer is never
  available;
- uses `list_own_exercise_attempts`, which reloads the actor/ownership and returns
  only the feedback branch selected by the immutable stored result.

## `GET /api/v1/me/exercise-attempts/:attemptId`

- owner only;
- inaccessible other-user attempt returns 404;
- immutable historical result remains accessible after content archive;
- uses `get_own_exercise_attempt`; neither the runtime role nor the HTTP
  adapter directly reads answer-key/private rows.

## API-EXERCISE-001 — Implement and verify

- [ ] Pure answer-shape/normalization/grading unit tests for all three scalar
      types and explicit `python_code` rejection.
- [ ] RPC/outbound-adapter concurrency and idempotency tests.
- [ ] Route tests for every scalar answer type and invalid reference.
- [ ] Cross-user history isolation.
- [ ] Draft/archived exercise rejection.
- [ ] Same-hash replay still succeeds after later archive/replacement; a new key
      races archive/replace under the shared lock and has one valid outcome.
- [ ] Response and log scans for keys/free text.
- [ ] Progress change only after correct result.
