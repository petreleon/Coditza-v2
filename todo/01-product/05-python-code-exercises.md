# Python code exercise contract

## Scope

`python_code` is an exercise-only assessment type for the Romanian Python
course. It is not a quiz-question type. Scalar exercises and quiz questions
continue to use `single_choice`, `multiple_choice`, and `short_text`.

A learner submits source files, never a score, verdict, test report, runtime
version, user ID, or exercise definition. A future client may execute the
public tests in a browser Web Worker for provisional feedback, but Coditza
always re-runs the submission on the server. Only that server run may create an
attempt, award points, or update progress.

Supabase Auth remains completely outside this execution path. Passwords, access
and refresh tokens, TOTP factors/codes/QR material, Auth responses, and the
server Supabase key must never be placed in a Python runner request or
environment.

## Canonical source package

The request body for a Python exercise contains:

```json
{
  "files": [
    {"path": "main.py", "content": "def solve(value):\n    return value\n"}
  ]
}
```

The MVP contract is deliberately bounded:

- 1 through 16 regular text files;
- at most 64 KiB UTF-8 per file and 256 KiB UTF-8 in aggregate;
- path length 1 through 160 ASCII characters;
- relative POSIX paths matching only letters, digits, `_`, `-`, `.`, and `/`;
- every submitted source path ends in `.py`;
- no absolute path, backslash, empty segment, `.`/`..` segment, leading slash,
  NUL, binary content, symlink, hard link, device entry, or archive input;
- paths are unique both byte-for-byte and after ASCII case-folding so the same
  package cannot mean different things on different filesystems;
- canonical order is ascending path byte order; file content is preserved
  exactly and included in the versioned RFC-8785 request hash.

The runner creates files itself inside a new per-run virtual directory. It
never extracts a learner-supplied archive and never follows a learner-supplied
link.

## Authored definition

Each `python_code` exercise freezes all of the following at publication:

- entry-point module/function contract;
- safe starter files;
- safe public-test descriptions and fixtures;
- private authoritative cases in the closed declarative harness format; no
  arbitrary hidden Python test source;
- exact points and pass rule;
- verifier contract version;
- runtime profile ID and runtime-manifest digest;
- test-fixture digest;
- per-run wall, CPU, memory, file, process, and output limits;
- allowed Python packages, which must already exist in the pinned runtime
  bundle.

The MVP awards full points only when every required authoritative test passes.
There is no partial credit. Public tests are educational hints, not a subset a
learner can claim to have passed.

## Verdicts

These learner-caused terminal verdicts create one immutable zero/full-points
attempt:

- `passed`;
- `tests_failed`;
- `syntax_error`;
- `runtime_error`;
- `time_limit_exceeded`;
- `memory_limit_exceeded`;
- `output_limit_exceeded`.

These infrastructure outcomes do **not** create a failed learner attempt or
change progress: sandbox launch failure, runner protocol violation, missing or
mismatched runtime asset, internal harness failure, and dependency outage.
They remain retryable under the original idempotency reservation and are
reported only with a safe generic service error.

Hidden case plans, inputs/expected values, private tracebacks, filesystem
contents, and per-hidden-test timing are never returned. Learner stdout/stderr
from hidden cases is discarded rather than sanitized. Learner feedback contains
only an allowlisted verdict, public-test feedback, compiler location when safe,
and bounded/sanitized output from the public/compile phase.

## Determinism contract

An authoritative run records the submission, definition, fixture, harness, and
runtime-manifest digests. The harness fixes the random seed, hash seed where the
pinned runtime supports it, timezone (`UTC`), locale, newline policy, and
logical fixture clock. Tests may not depend on wall-clock time, network,
filesystem iteration order, external state, or unseeded randomness.

Resource measurements and timestamps are excluded from the canonical verdict
digest. Two fresh workers receiving the same five input digests must produce
the same canonical verdict digest. A mismatch is a grading-system incident,
not a learner failure.

## PRD-WASM-001 — Freeze Python exercise semantics

Prerequisites: G0 and the accepted modular-architecture ADR.

- [ ] Add `python_code` only to the exercise type union and reject it for quiz
      questions.
- [ ] Implement the exact canonical source-package validator and golden
      vectors, including traversal, case-collision, NUL, size, and duplicate
      cases.
- [ ] Freeze the authored-definition, verdict, no-partial-credit, feedback, and
      deterministic-fixture contracts above.
- [ ] Prove no public/browser result field is accepted by an authoritative
      submission use case.
- [ ] Record the distinction between learner verdicts and infrastructure
      outcomes in the API, database, retry, and progress specifications.
- [ ] Keep all Auth/TOTP operations and material outside the verifier contract.

Evidence is a reviewed product contract plus canonical request/verdict vectors
shared by the API, database adapters, runner protocol, and tests.
