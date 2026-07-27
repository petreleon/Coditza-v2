# Database acceptance tests

Use pgTAP/Supabase database tests where possible and API integration tests where
an Auth/Data API context is required.

## Migration and schema

- [ ] DB-001 — Clean local reset applies every migration and seed.
- [ ] DB-002 — Post-reset schema diff has no unexpected change.
- [ ] DB-003 — Required schemas/types/tables/functions/indexes exist.
- [ ] DB-004 — Invalid text, slug, position, time, point, threshold, row-version,
      and definition-version values fail.
- [ ] DB-005 — Scoped slug/position uniqueness works.
- [ ] DB-006 — Restricted content delete preserves history.
- [ ] DB-007 — Generated TypeScript types have no drift.

## Publication and answer safety

- [ ] DB-010 — Invalid exercise definition cannot publish.
- [ ] DB-011 — Empty/invalid quiz cannot publish.
- [ ] DB-012 — Cross-item option IDs are rejected.
- [ ] DB-013 — Published child under non-published parent is learner-invisible.
- [ ] DB-014 — Every published assessment is immutable, with or without attempts.
- [ ] DB-015 — No publishable/user token can read answer-key tables.
- [ ] DB-016 — SQL short-text normalization matches the pinned golden vectors
      and rejects unknown normalization versions.

## Identity and RLS

- [ ] DB-020 — Signup creates exactly one learner profile.
- [ ] DB-021 — `anon`/`authenticated` cannot directly select/mutate profiles,
      content, attempts, progress, roles, or server workflow functions.
- [ ] DB-022 — New-object default privileges remain deny-by-default.
- [ ] DB-023 — Private schema/tables are absent from user-facing Data API access.
- [ ] DB-024 — Server workflow reloads the passed actor and enforces
      learner/editor/admin capability/ownership.
- [ ] DB-025 — Serialized bootstrap/admin changes protect the final admin,
      including concurrent demotion/deletion, and audit correctly.
- [ ] DB-026 — No Coditza migration/table/type/seed duplicates Supabase Auth
      factor state, TOTP secret/code, QR/`otpauth`, challenge or refresh token.
- [ ] DB-027 — Signup initializes `security_hold_at` null, and no user-facing
      role can read, set, or clear it directly.
- [ ] DB-028 — The operator system function alone can idempotently set/clear the
      hold under a profile lock; every transition/reason is safely audited and
      concurrent calls end in one explicit recorded state.

## Attempts and grading

- [ ] DB-030 — Scalar exercise grading handles all three scalar types and stores
      no client score; `python_code` cannot enter the scalar grader.
- [ ] DB-031 — Duplicate exercise idempotency key returns one attempt.
- [ ] DB-032 — Concurrent quiz starts produce one active attempt and respect max.
- [ ] DB-033 — Wrong quiz question/option references fail.
- [ ] DB-034 — Save/remove lock the attempt and cannot commit after concurrent
      submit/expiry; identical PUT preserves `answered_at`, changed PUT advances
      it, and exact-deadline races have one valid outcome.
- [ ] DB-035 — Repeat/concurrent submit returns one stored result.
- [ ] DB-036 — Expired submit follows the recorded auto-submit rule.
- [ ] DB-060 — Untimed start stores no deadline; save/remove work until manual
      submit, manual submit becomes `submitted`, and no expiry path selects it.
- [ ] DB-056 — A new-start request that finalizes a stale last-allowed attempt
      commits finalization/progress while returning the structured limit denial.
- [ ] DB-037 — Score percent rounding and threshold boundary are exact.
- [ ] DB-038 — Old attempt remains valid after old content is archived/replaced.
- [ ] DB-039 — An active attempt remains saveable/submittable after assessment
      reorder, archive, or atomic replacement; lifecycle `row_version` never
      substitutes for its frozen `definition_version`.
- [ ] DB-063 — Python reservation is one-per-idempotency key; direct users
      cannot read/claim/finalize jobs or hidden definitions.
- [ ] DB-064 — Concurrent claims, lease expiry/theft, controller crash, replay,
      and repeated finalization produce at most one immutable attempt.
- [ ] DB-065 — Python learner verdict derives zero/full points and progress in
      one finalization transaction; infrastructure failure creates no attempt.
- [ ] DB-066 — Definition/submission/runtime/harness/fixture/result digest
      mismatch, client score, unknown verdict, or stale lease fails closed.

## Progress

- [ ] DB-040 — Theory completion is idempotent.
- [ ] DB-041 — Failed exercise/quiz does not complete a required item.
- [ ] DB-042 — Correct exercise and passing quiz do.
- [ ] DB-043 — Optional items do not block chapter completion.
- [ ] DB-044 — Draft/archived items do not enter the current denominator.
- [ ] DB-045 — Stored chapter snapshot equals from-source calculation.
- [ ] DB-046 — Module aggregation uses published chapters only and derives
      current `completedAt` as their maximum only when all are currently
      complete.
- [ ] DB-047 — Reconciliation repairs a deliberately corrupted snapshot.
- [ ] DB-048 — New required content clears current completion while preserving
      first completion.
- [ ] DB-049 — Publishing or archiving theory, exercise, or quiz content updates
      every affected learner snapshot synchronously in the same transaction; no
      unspecified dirty-marker/read-repair path is allowed.

## Performance and privilege

- [ ] DB-050 — Every FK and server authorization/filter predicate has a
      supporting index where needed.
- [ ] DB-051 — Catalog and progress query plans are reviewed on large synthetic
      fixtures.
- [ ] DB-052 — No per-item N+1 database loop is required for a progress response.
- [ ] DB-053 — Security-definer functions have fixed search paths and minimal
      execute grants.
- [ ] DB-054 — Cross-workflow races follow the canonical lock order: descendant
      create/update versus ancestor archive, create/clone versus reorder,
      quiz start versus archive/replace, exercise submit versus
      archive/replace, theory completion versus section/chapter/module archive,
      save/remove versus submit/scheduled expiry, and learner progress writes
      versus publish/archive all end in one valid state without deadlock,
      stranded content, duplicate grading, late answers, or lost progress.
- [ ] DB-055 — Same-hash exercise/quiz-start replay returns stored success after
      later archive/replacement/terminal/limit changes; a different hash
      conflicts, and a failed first transaction leaves no idempotency record.
- [ ] DB-057 — Every admin draft create and assessment clone returns one row/tree
      under concurrent same-key calls; a same-hash retry after parent/source
      lifecycle change replays the original 201/Location/safe body, while changed
      input conflicts.
- [ ] DB-058 — Idempotency is live immediately before `expires_at`, fresh exactly
      at/after it, and request reuse racing the purge worker cannot lose the new
      record or extend the old replay window.
- [ ] DB-059 — Attempt list/detail functions reload actor ownership, conceal
      cross-user rows, preserve archived historical results, return only the
      selected safe feedback branch, and emit one ordered terminal quiz result
      per frozen question including omitted answers without any key/spec.
- [ ] DB-061 — Progress reads begin from published curriculum: a fresh user with
      no snapshot sees every module/chapter with exact zero/empty-category
      defaults, while a missing snapshot with source activity returns a set-based
      from-source value, signals mismatch, and does not write during GET.
- [ ] DB-062 — Every Coditza table/function has the exact owner/role attributes;
      RLS is enabled and not forced, runtime cannot assume `coditza_owner` or
      perform direct DML/private reads, and runtime EXECUTE of each named
      security-definer function succeeds with its expected allow/deny result.

All tests must name the acting role/user, expected allow/deny result, and exact
resource. A denied test that fails for an unrelated syntax error is not valid
security evidence.
