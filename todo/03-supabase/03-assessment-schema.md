# Exercise and quiz schema

## Exercises

### `public.exercises`

| Column | Rule |
| --- | --- |
| `id` | primary key |
| `chapter_id` | required chapter FK, restrict delete |
| `title` | required, 1–160 characters |
| `prompt_markdown` | required, 1–50,000 characters |
| `exercise_type` | `single_choice`, `multiple_choice`, `short_text`, or `python_code` |
| `position` | unique within chapter, deferrable |
| `points` | integer 1–1,000 |
| `is_required` | default true |
| `status`, `row_version`, `published_at` | lifecycle/concurrency fields |
| `definition_version` | positive; increments on each draft definition mutation and freezes on publish |
| audit timestamps/actors | common convention |

### `public.exercise_options`

- `id uuid primary key`
- `exercise_id uuid not null references exercises on delete restrict`
- `label_markdown text not null` with trimmed length 1–10,000
- `position integer not null`
- timestamps
- unique deferrable `(exercise_id, position)`
- composite unique `(exercise_id, id)` for ownership validation

### `private.exercise_answer_keys`

- `exercise_id uuid primary key references public.exercises on delete restrict`
- `answer_spec jsonb not null`
- `feedback_correct_markdown text null`
- `feedback_incorrect_markdown text null`
- audit timestamps/actors

Each feedback value is null or bounded non-blank Markdown of 1–20,000
characters. Its source is preserved: leading Markdown indentation is not
silently trimmed because it can be semantically meaningful.

The `private` schema is not exposed through the Data API and grants no table
read/write access to `PUBLIC`, `anon`, or `authenticated`. Set matching default
privileges. Server-only RPC entry functions live in `public`, revoke user-facing
execute grants, and internally access `private`; never query private tables via
client `.from(...)`.

## Quizzes

### `public.quizzes`

| Column | Rule |
| --- | --- |
| `id` | primary key |
| `chapter_id` | required chapter FK, restrict delete |
| `slug` | required, unique within chapter |
| `title` | required, 1–160 characters |
| `instructions_markdown` | required, 1–20,000 characters |
| `position` | unique within chapter, deferrable |
| `passing_percent` | integer 0–100, default 70 |
| `max_attempts` | null or integer 1–100 |
| `time_limit_seconds` | null or integer 30–86,400 |
| `is_required` | default true |
| `status`, `row_version`, `published_at` | lifecycle/concurrency fields |
| `definition_version` | positive; increments on each draft definition mutation and freezes on publish |
| audit timestamps/actors | common convention |

### `public.quiz_questions`

- `id uuid primary key`
- `quiz_id uuid not null references quizzes on delete restrict`
- `prompt_markdown text not null`, trimmed 1–50,000 characters
- `question_type question_type not null`
- `position integer not null`
- `points integer not null check between 1 and 1,000`
- timestamps
- unique deferrable `(quiz_id, position)`

### `public.quiz_question_options`

- `id uuid primary key`
- `question_id uuid not null references quiz_questions on delete restrict`
- `label_markdown text not null`, trimmed 1–10,000 characters
- `position integer not null`
- timestamps
- unique deferrable `(question_id, position)`
- composite unique `(question_id, id)`

### `private.quiz_question_answer_keys`

- `question_id uuid primary key references public.quiz_questions on delete
  restrict`
- `answer_spec jsonb not null`
- `feedback_correct_markdown text null`
- `feedback_incorrect_markdown text null`
- audit timestamps/actors

Each feedback value is null or bounded non-blank Markdown of 1–20,000
characters. Its source is preserved: leading Markdown indentation is not
silently trimmed because it can be semantically meaningful.

## Exact answer-spec shapes

```json
{"correctOptionId":"<uuid>"}
```

for `single_choice`.

```json
{"correctOptionIds":["<uuid>","<uuid>"]}
```

for `multiple_choice`; IDs must be unique and non-empty.
Store `correctOptionIds` in ascending UUID-text order; clone rewrites and
re-sorts them. Grading still uses set equality.

```json
{
  "acceptedAnswers":["normalized answer"],
  "normalization":"nfkc_ascii_ws_ascii_lower_v1"
}
```

for `short_text`.

No other keys are allowed. Choice IDs must belong to the exact exercise/question.
Authoring input may provide unnormalized accepted strings, but the one domain
normalizer converts them before storage; database validation requires each
stored string to equal `private.normalize_short_text(value)`.
The publish validator enforces:

- single choice: at least two options and one matching key;
- single/multiple choice: 2–20 options;
- multiple choice: one or more matching key IDs;
- short text: no options and one or more unique accepted normalized answers;
- short text: 1–20 accepted answers, each 1–4,000 characters after
  normalization;
- quiz: 1–100 questions;
- every accepted answer is already normalized with the exact version named in
  its answer spec; authoring rejects any other version;
- every quiz has at least one question and positive total points.
- `python_code` is valid only for an exercise, has no option/scalar answer-key
  rows, and has one complete digest-pinned private definition from
  [SUP-WASM-001](13-python-code-verification-data.md);
- quiz questions reject `python_code`.

Until SUP-WASM-001 supplies that approved private definition, database publish
validation fails closed for every `python_code` exercise. SUP-DATA-002 must not
invent a placeholder table or a weaker definition merely to make Python content
publishable.

## Exact create/complete-definition reference contract

New question/option UUIDs do not exist when an author submits one atomic
definition. Therefore authoring input never pretends to know them:

- every submitted new question has a unique `clientRef`;
- every submitted option has a `clientRef` unique within its exercise/question;
- a client ref matches `^[A-Za-z][A-Za-z0-9_-]{0,63}$`;
- choice authoring input uses `correctOptionRef` or unique
  `correctOptionRefs`, never database IDs;
- quiz question answer specs may reference only option refs inside that exact
  question;
- client refs are transaction-local and never stored or exposed to learners.

The server validates the ref graph, then the database function generates UUIDs,
builds question/option ref-to-ID maps, rewrites the stored answer specs to the
ID shapes above, validates again, and commits atomically. The protected
authoring response returns generated `{clientRef,id}` mappings plus the safe
draft definition so a client can reconcile. Complete draft-tree replacement
generates new child UUIDs; old unpublished child/key rows are removed under the
locked draft-root exception.

### SUP-DATA-002 private draft-definition envelope

The database helpers are private, owner-only primitives—not public RPCs. Their
closed JSONB envelopes make the later Fastify schemas mechanically derivable:

```json
{
  "options": [
    { "clientRef": "optionA", "labelMarkdown": "..." }
  ],
  "answerSpec": { "correctOptionRef": "optionA" },
  "feedbackCorrectMarkdown": null,
  "feedbackIncorrectMarkdown": null
}
```

is the exercise shape. `options` and `answerSpec` are required; feedback fields
are optional and, if present, are `null` or bounded Markdown. A draft may use
`"answerSpec": null` only with absent/null feedback; no key row is persisted,
so publish validation later rejects the incomplete draft. For a non-null answer
spec, the authoring-only shapes are exactly:

- `single_choice`: `{ "correctOptionRef": "optionA" }`
- `multiple_choice`: `{ "correctOptionRefs": ["optionA", "optionB"] }`
- `short_text`: `{ "acceptedAnswers": ["raw answer"], "normalization": "nfkc_ascii_ws_ascii_lower_v1" }`

The quiz envelope is `{ "questions": [...] }`. Every question requires
`clientRef`, `promptMarkdown`, `questionType`, `points`, `options`, and
`answerSpec`; the same optional feedback fields and per-question answer-spec
rules apply. Unknown fields—including `id`, any parent ID, `position`, versions,
actors, status, and timestamps—are rejected. Array index is the stored position.
Question refs are unique per quiz; option refs are unique only per exact
question. Questions are capped at 100 and options at 20 before expansion.

The functions return controlled generated-ID mappings and post-mutation version
numbers only. The staff-only ID/key projection and any public/server facade are
owned by SUP-FUNCTIONS-001. JSONB has already canonicalized duplicate object
keys before a database function receives it; raw duplicate-object-key rejection
belongs to the later Fastify parser boundary, while this layer rejects duplicate
references and answer-array values.

Question array index becomes question `position`; each option array index becomes
option `position`. Child input rejects an explicit `position`. The UTF-8 raw HTTP
body must fit the 1 MiB route limit and the database also rejects a canonical
definition JSON representation over 1,000,000 bytes. Component/count maxima are
ceilings, not permission to exceed this aggregate definition limit.

## Immutability rule

- A published exercise/quiz definition, options, keys, points, threshold, and
  time policy are immutable immediately; it never returns to draft.
- `row_version` tracks lifecycle/position/concurrency changes. A separate
  `definition_version` identifies the immutable assessment definition used by
  attempts. Publish/archive/reorder/replace lifecycle changes never change
  `definition_version`.
- Replacement means clone authored rows to new IDs in draft state and archive
  the old assessment. Historical attempts retain old FKs.
- Clone functions build old-to-new question/option ID maps and rewrite every
  `correctOptionId`/`correctOptionIds` inside the new private answer specs before
  validation.
- Replacing under globally unique sibling positions swaps the old row to the
  draft's temporary position and the new row to the old learner position inside
  one deferred-constraint transaction.
- A clone starts with `row_version=1` and `definition_version=1`.

## Draft-tree version rule

- All option, question, and private-key changes occur through one named function.
- The function locks the owning exercise/quiz, checks API `expectedVersion`
  against `row_version`, changes the complete tree atomically, and increments
  both `row_version` and `definition_version` exactly once.
- Any other draft mutation that changes assessment behavior increments both;
  position-only reorder changes `row_version` only.
- Only while the locked root is `draft` and has no attempts, the named complete-
  definition function may delete omitted private keys/options/questions in
  child-first order and insert the replacement tree in the same transaction.
  This is not a root-resource hard delete and cannot target published/archived
  history.
- Direct child/key writes are revoked so neither version can become stale.

## SUP-DATA-002 — Implement and prove assessments

- [x] Create public definitions before private keys.
- [x] Lock down `private` schema privileges in the same migration.
- [x] Add database validators for answer-spec structure and option ownership.
- [x] Test duplicate/missing/cross-question client refs and prove every stored
      answer spec contains generated IDs, never client refs.
- [x] Add atomic authoring functions for replacing draft options/keys and quiz
      question trees.
- [x] Add publish validation covering every rule above.
- [x] Test malformed specs, cross-item option IDs, empty quiz, invalid limits,
      and every published-assessment mutation.
- [x] Prove learner/staff tokens cannot select private key data.
