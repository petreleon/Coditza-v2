# Content lifecycle and publishing rules

## States

Allowed transitions:

```text
draft -> published
draft -> archived
published -> archived
```

- New content starts as `draft`.
- Only valid draft content can be published.
- No state moves from `published` back to `draft`.
- Archived content cannot return to published in the MVP. Clone it into a new
  draft instead.
- Published exercises, quizzes, questions, options, and answer keys are
  immutable immediately. Archive and clone an assessment to change it.
- Published modules, chapters, and theory sections may receive versioned
  corrections while remaining published, but only through these machine-checked
  field allowlists:
  - module: `title`, `descriptionMarkdown`;
  - chapter: `title`, `summaryMarkdown`, `estimatedMinutes`;
  - theory section: `title`, `bodyMarkdown`, `estimatedMinutes`.
- A published correction requires `expectedVersion` and a non-empty
  `correctionReason`, increments database `row_version` (API `version`) exactly
  once, and emits an audit event naming changed fields. It cannot change slug,
  parent, position, status, identity, requirement/scoring rules, or timestamps
  directly.
- correctionReason is an approved non-content audit reason code, not free-form
  prose. The audit event stores only safe changed-field names and approved
  before/after codes; it never copies authored Markdown or prior/new content
  values.
- Existing theory completions survive an allowed published correction. An
  editor must create a new theory section for a new concept, new completion
  requirement, or any change that should reopen progress.
- Parent/position changes use dedicated workflows. Archived authored fields are
  read-only; position may change only as the mechanical result of a complete
  all-sibling reorder.
- The MVP exposes no authored-content hard-delete endpoint. Abandoned drafts are
  archived; physical purging is a separately approved maintenance/privacy task.
- Archiving a module or chapter atomically archives its still-draft/published
  descendants, preserves all historical references, recalculates affected
  progress once, and audits the affected IDs. It must not leave editable,
  permanently stranded descendants under an archived ancestor.
- A published item's learner visibility also requires every ancestor to be
  published.

## Publish validation

### Module

- slug, title, description, and position are valid;
- has at least one published chapter;
- all positions needed for learner order are deterministic.

### Chapter

- module exists and is not archived;
- slug, title, summary, position, and estimated time are valid;
- has at least one published theory section;
- has at least one published exercise;
- has at least one published quiz.

### Theory section

- non-empty title and Markdown body;
- parent chapter is not archived;
- valid non-negative position and estimated time.

### Exercise

- non-empty prompt;
- supported question type;
- positive integer points;
- choice types have valid options and a matching answer specification;
- short-text type has at least one non-empty accepted normalized answer.

### Quiz

- non-empty title and instructions;
- passing percent is from 0 through 100;
- positive `maxAttempts`/`timeLimitSeconds` when supplied;
- at least one question;
- every question has positive points and a valid answer specification.

## Authoring task sequence

### PRD-CONTENT-001 — Draft operations

- [ ] Create every item as draft.
- [ ] Require the shared database-backed idempotency key for every draft
      creation; a response-loss retry returns the original draft rather than
      appending another sibling.
- [ ] Chapter creation requires a non-archived module. Theory/exercise/quiz
      creation requires a non-archived chapter and module.
- [ ] Validate slug uniqueness within its defined scope.
- [ ] Create appends at the next locked sibling position. A client changes
      ordering only through the complete-list reorder endpoint; create bodies
      never supply `position`.
- [ ] Reorder siblings in one transaction.
- [ ] Prevent moving a child to a different parent through a generic update.
- [ ] Return validation problems with field-level details.
- [ ] Archive abandoned drafts instead of adding a generic hard-delete route.

### PRD-CONTENT-002 — Publish operation

- [ ] Lock the target row for the duration of validation and transition.
- [ ] Validate all direct and required descendant rules.
- [ ] Set `status=published` and `published_at` in the same transaction.
- [ ] Increment lifecycle `row_version` exactly once on the first transition;
      an idempotent repeat preserves it and does not duplicate audit.
- [ ] Emit an audit event.
- [ ] Make repeated publish requests idempotent.
- [ ] Recalculate affected current learner denominators when an item becomes
      published.

### PRD-CONTENT-003 — Archive/assessment-clone operation

- [ ] Archive without deleting attempts or historical result references.
- [ ] Increment each newly archived root/descendant `row_version` exactly once;
      an already archived repeat changes nothing.
- [ ] For module/chapter archive, lock and archive the complete descendant tree
      in one transaction and return the affected-ID summary.
- [ ] Exclude archived items from new catalog responses.
- [ ] Clone an exercise with its options/private key or a quiz with its complete
      question/option/private-key tree.
- [ ] Require the shared database-backed idempotency key for clone and replay
      the original new draft after response loss; never create a second clone.
- [ ] Clone only a published/archived assessment whose chapter and module are
      non-archived; edit an existing draft instead of cloning it.
- [ ] Clone only authored assessment content, never learner attempts/progress.
- [ ] Generate new IDs, place the clone in the same chapter as a draft, assign a
      conflict-free slug where applicable, and put it after existing siblings.
- [ ] Clear all published timestamps and reset clone `row_version` and
      `definition_version` to 1.
- [ ] Module/chapter/theory subtree cloning is not in MVP; recreate it explicitly
      if an archived hierarchy needs replacement.
- [ ] Reject archiving a child when its published parent would no longer satisfy
      publication requirements.
- [ ] Recalculate affected current learner denominators when an item is archived.
- [ ] For an assessment replacement, validate a draft clone and atomically
      publish it, transfer the old position, archive the old item, recalculate
      affected progress, and audit both IDs. No intermediate learner-visible
      state may contain two required replacements or none.
- [ ] Replacement requires distinct same-type/same-chapter IDs, old status
      `published`, replacement status `draft`, and a non-archived chapter/module
      chain.
- [ ] Replacement increments old/replacement `row_version` exactly once and
      preserves their frozen `definition_version`.

## Acceptance examples

- A published chapter under a draft module is invisible to learners.
- Publishing a quiz with a missing key fails without partially changing status.
- Reordering two siblings cannot leave duplicate effective ordering.
- Editing any published quiz returns `409 content_immutable`.
- Archiving a quiz preserves prior learner result retrieval.
