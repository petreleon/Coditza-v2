# Final backend acceptance scenarios

## Identity and isolation

- [ ] A new confirmed Auth user gets one learner profile but no domain access at
      `aal1`.
- [ ] Registration TOTP enrollment reaches genuine `aal2`; a later password
      login requires a fresh TOTP challenge before `/me` succeeds.
- [ ] Missing/unknown/forged AAL, wrong-project token and invalid session ID fail
      before profile/use-case execution.
- [ ] Signed TOTP `amr` is enforced when reliably supplied by the pinned
      provider; otherwise the accepted TOTP-only configuration fallback is
      proven and no unsigned factor claim is trusted.
- [ ] Two verified factors can be selected/replaced safely; password reset does
      not bypass MFA and the approved lost-factor policy is exercised.
- [ ] Lost-factor recovery keeps the live hold through the measured residual
      JWT quarantine, performs the second revoke/delete, and clears only after a
      fresh verified TOTP factor.
- [ ] Missing/invalid/wrong-project token is denied safely.
- [ ] Learner cannot become staff or access another learner's data.
- [ ] Admin role workflow is audited and preserves at least one admin.
- [ ] Learner/editor/admin all satisfy the same AAL2 floor.

## Content

- [ ] Editor builds a valid module -> chapter -> theory/exercise/quiz hierarchy.
- [ ] Learner sees published ordered content only.
- [ ] Published child under draft/archived parent is hidden.
- [ ] Invalid content cannot publish and a failure is atomic.
- [ ] Attempted assessment cannot mutate; clone/archive preserves history.

## Exercises/quizzes

- [ ] All three scalar answer types validate and grade deterministically.
- [ ] `python_code` accepts only the canonical bounded multi-file package and
      rejects client/browser score, verdict, tests, actor, definition, and
      runtime fields.
- [ ] A future browser Web Worker can provide only provisional public-test
      feedback; every attempt/progress result is re-run and finalized by the
      authoritative server sandbox.
- [ ] The exact self-hosted Pyodide/Python/assets/packages/harness/fixtures are
      digest-pinned; two fresh workers produce the same canonical verdict.
- [ ] The outer sandbox blocks network, secrets/Auth/TOTP, host mounts,
      container socket, privilege, package downloads, process/file/resource
      abuse, and every adversarial escape case.
- [ ] Hidden Python tests/source/private tracebacks never leak, and grader
      infrastructure failure never becomes a failed learner attempt.
- [ ] Learner cannot read keys through API, Data API, logs, docs, or errors.
- [ ] Exercise retry creates one result per idempotency key.
- [ ] Quiz start/save/reload/submit handles time, limits, partial answers, and
      concurrent/repeated calls.
- [ ] Only server/database plus the digest-validated authoritative WASM result
      computes score/pass; the database finalization still derives zero/full
      points and commits progress exactly once.

## Progress

- [ ] Theory, required exercises, and required quizzes follow the documented
      completion rule.
- [ ] Optional/draft/archived content affects denominators correctly.
- [ ] Chapter snapshot equals source and module summary is explainable.
- [ ] Reconciliation repairs a mismatch without changing grading history.

## Runtime and delivery

- [ ] Clean checkout passes CI and builds one non-root image.
- [ ] Clean checkout verifies the Python runtime manifest offline and builds/
      scans the exact API, grader-controller, and sandbox artifacts without
      runtime downloads.
- [ ] Compose API connects to CLI-owned local Supabase without duplicate DB.
- [ ] OpenAPI/types/migrations are reproducible.
- [ ] Module ownership/import boundaries and the sole Fastify API composition
      root are machine-enforced; isolated one-off entrypoints are inventoried
      and no global repository/service locator exists.
- [ ] Health, shutdown, logging, redaction, CORS, limits, and alerts work.
- [ ] Development, plus optional staging when DEC-027 approves it, has Chrome
      settings matching migrations/config.
- [ ] Restore drill, rollback, secrets, owners, and production approval complete.
- [ ] Production safe smoke/observation passes without demo data.

The MVP is not complete if any scenario is skipped, waived without an allowed
ADR, or proven only by an implementation claim rather than objective evidence.
