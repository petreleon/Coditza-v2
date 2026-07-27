# Unit-test plan

## Configuration and infrastructure

- [ ] QA-UNIT-001 — Valid config parses into exact typed values.
- [ ] QA-UNIT-002 — Missing/invalid URLs, ports, booleans, limits, origins, and
      secrets fail without echoing values.
- [ ] QA-UNIT-003 — Logger redaction removes every sensitive path.
- [ ] QA-UNIT-004 — Database-adapter/RPC errors map to stable application errors.
- [ ] QA-UNIT-005 — Cursor encoding/decoding preserves order and rejects tamper.

## Auth and authorization

- [ ] QA-UNIT-010 — Bearer parser handles absent/malformed/multiple schemes.
- [ ] QA-UNIT-011 — Role predicates cover every role/capability.
- [ ] QA-UNIT-012 — Missing profile and unknown role fail closed.
- [ ] QA-UNIT-013 — Content ownership/state checks conceal resources as planned.
- [ ] QA-UNIT-014 — Verified `aal1`, missing/unknown AAL and invalid session ID
      fail before profile/use-case calls; exact `aal2` constructs the narrow
      principal.
- [ ] QA-UNIT-015 — `mfa_required` is distinct from invalid token and role
      errors without exposing factor/account state.

## Architecture boundaries

- [ ] QA-UNIT-016 — Every forbidden domain/application/framework/adapter/deep
      cross-module import negative fixture fails.
- [ ] QA-UNIT-017 — Composition root injects module ports without exposing a
      raw client, global repository bag or request-scoped service locator.

## Content and publishing

- [ ] QA-UNIT-020 — Slug/title/Markdown/domain bounds.
- [ ] QA-UNIT-021 — Module/chapter/item publish prerequisites.
- [ ] QA-UNIT-022 — Draft/published/archived transitions.
- [ ] QA-UNIT-023 — Immediate published-assessment immutability rule.
- [ ] QA-UNIT-024 — Reorder list validation detects missing/duplicate/foreign IDs.

## Answer validation and grading

- [ ] QA-UNIT-030 — Single-choice valid, wrong, missing, and foreign option.
- [ ] QA-UNIT-031 — Multiple-choice exact set equality, duplicate/order handling.
- [ ] QA-UNIT-032 — Short-text `nfkc_ascii_ws_ascii_lower_v1` golden vectors
      match SQL exactly, including non-ASCII case-sensitive examples.
- [ ] QA-UNIT-033 — Answer shape mismatch and unknown property rejection.
- [ ] QA-UNIT-034 — Exercise zero/full points.
- [ ] QA-UNIT-035 — Quiz points, two-decimal floor rounding, and exact pass
      threshold, including 1/3 = 33.33, 2/3 = 66.66, and 3/3 = 100.00.
- [ ] QA-UNIT-036 — Omitted quiz answers score zero.
- [ ] QA-UNIT-037 — Python package canonicalization rejects traversal,
      absolute/backslash paths, duplicates, ASCII case collisions, NUL/binary,
      file/count/aggregate overflow, and unknown submission fields.
- [ ] QA-UNIT-038 — Python runner-result validation rejects client scores,
      unknown verdicts/fields, digest mismatch, oversized output, and stale
      leases; infrastructure failure never maps to a learner verdict.

## Progress

- [ ] QA-UNIT-040 — Each category numerator/denominator.
- [ ] QA-UNIT-041 — Optional and empty category rule.
- [ ] QA-UNIT-042 — Equal-third overall calculation and completion timestamp.
- [ ] QA-UNIT-043 — Module published-chapter aggregation.
- [ ] QA-UNIT-044 — Archive/new-publication recalculation behavior.

## Application use cases

Every application use case has tests with fake outbound ports for:

- success;
- not found/ownership;
- wrong role;
- invalid state;
- version/idempotency conflict;
- outbound-adapter/dependency failure;
- expected audit call;
- no later write after an earlier failure.

Unit tests must not initialize Fastify, Docker, or Supabase.
