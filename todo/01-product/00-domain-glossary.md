# Domain glossary

Use these meanings consistently in SQL, TypeScript, API paths, tests, and docs.

| Term | Exact meaning |
| --- | --- |
| User | An identity managed by Supabase Auth |
| Profile | Coditza data linked one-to-one to a Supabase Auth user |
| Learner | A user allowed to consume published content and own attempts/progress |
| Editor | A staff user allowed to create, validate, publish, archive, and reorder content |
| Admin | A staff user with editor powers plus staff-role administration |
| Module | The top-level ordered learning unit |
| Chapter | An ordered child of exactly one module |
| Theory section | An ordered Markdown reading unit inside exactly one chapter |
| Exercise | A short, independently submitted graded activity inside a chapter |
| Python code exercise | An exercise of type `python_code` whose bounded source package is graded by the authoritative server WASM runner |
| Quiz | An ordered assessment inside a chapter containing one or more questions |
| Question | A graded child of one quiz |
| Option | An ordered selectable answer belonging to a choice exercise/question |
| Answer key | Server-only data used to grade an exercise or quiz question |
| Attempt | A learner's immutable submitted exercise response or stateful quiz session |
| Grading job | A private durable reservation/lease used to run a Python submission before exactly one attempt is finalized |
| Provisional result | Untrusted public-test feedback from a future browser worker; never a score or progress source |
| Authoritative result | The digest-bound server sandbox verdict accepted by the finalization transaction |
| Completion | A learner assertion that a published theory section was read |
| Progress | A server-calculated snapshot derived from completions and passing attempts |
| Draft | Content editable by staff and invisible to learners |
| Published | Content visible when every ancestor is also published |
| Archived | Retired content hidden from new learning flows but retained for history |
| Required | An exercise/quiz that must be passed for chapter completion |

## Hierarchy invariants

- A child has exactly one parent; cross-module chapter reuse is not part of MVP.
- Every ordered child has a `position >= 0`.
- API ordering is always `position ASC, id ASC`.
- A learner sees a content item only if it and every ancestor are published.
- A publishable chapter contains at least one valid published item of each
  category: theory, exercise, and quiz.
- A quiz contains at least one question, and every choice question has enough
  valid options and a valid answer key.

## Naming rules

- Database table names are plural: `modules`, `chapters`, `theory_sections`.
- API collection paths are plural and lower-case.
- TypeScript domain types are singular PascalCase.
- Do not use `lesson` as a synonym for chapter.
- Do not call a quiz question an exercise.
- Do not expose the word `answer_key` in public API response types.
