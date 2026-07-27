# REST API conventions

## Base and media types

- Base path: `/api/v1`.
- Request/response data: `application/json`.
- Errors: `application/problem+json`.
- Auth: `Authorization: Bearer <Supabase aal2 access token>`.
- IDs: UUID strings.
- Timestamps: UTC ISO 8601.
- JSON properties: `camelCase`.

## Success envelopes

Single resource:

```json
{"data":{"id":"<uuid>"}}
```

Collection:

```json
{
  "data": [],
  "meta": {
    "nextCursor": null,
    "hasMore": false
  }
}
```

## Pagination

- default `limit=20`, minimum 1, maximum 100;
- opaque, versioned HMAC-SHA-256 cursor over the documented ordering tuple;
- encode RFC-8785 canonical JSON payload
  `{v:1, scope:"<operationId>", filter:{...}, values:[...]}` and its MAC as
  `<base64url(payloadBytes)>.<base64url(macBytes)>`; `filter` is the normalized
  non-pagination query filter; compute
  `HMAC-SHA-256(key, UTF8("coditza-cursor-v1.") || payloadBytes)`, check decoded
  lengths before constant-time comparison, require exact endpoint/filter, and
  reject invalid version/signature/shape;
- catalog order is `position ASC, id ASC`;
- exercise history order is `submittedAt DESC, id DESC`;
- quiz-attempt history order is
  `coalesce(submittedAt, startedAt) DESC, id DESC`;
- do not accept arbitrary sort fields in MVP;
- do not return total counts unless a use case proves they are needed;
- invalid or endpoint/filter-mismatched cursor returns `400 validation_failed`;
  normal concurrent inserts/reorders follow ordinary keyset-pagination
  semantics and do not claim snapshot isolation.

## Write semantics

- `POST` creation returns 201 and a `Location` header. The deliberate exception
  is a new `python_code` grading reservation, which returns 202 and an
  owner-status `Location`; only finalization creates the immutable attempt.
- `PUT` is an idempotent complete operation; `PATCH` is a partial draft update.
- Mutation payloads reject unknown properties.
- Mutable draft PATCH includes `expectedVersion`; conflict returns 409.
- The exact retry-sensitive operations requiring a UUID `Idempotency-Key`
  header are exercise submission, quiz start, every admin draft-content `POST`,
  exercise/quiz clone, and Python grading reservation. No implementation may
  omit the key or invent a second retry scheme for these operations.
- Reusing a key with different input returns 409.
- Reusing a key with the same canonical input replays the original status,
  `Location`, and body, and adds `Idempotency-Replayed: true`; it does not switch
  from 201 to 200.
- Lifecycle changes use explicit action endpoints, never generic status PATCH.

The idempotency request hash is SHA-256 over RFC 8785-canonical JSON containing
operation name, resource ID, and normalized domain input. Multiple-choice IDs
are sorted/unique and short text uses the grading normalization before hashing.
Python files use the exact validated ascending path order and exact content
from PRD-WASM-001; browser/runtime/verdict fields are not accepted.
The exact bytes are
`UTF8("coditza-idempotency-v1.") || canonicalJsonBytes`; store the 32-byte
digest and canonicalization version `1`. A future form uses a new version and
must not reinterpret stored keys.

Idempotency is step zero inside the database transaction. Acquire a transaction
advisory lock derived from `(userId, operation, idempotencyKey)` first;
collisions may only over-serialize. Then:

1. an existing same-version/same-hash record immediately replays its stored
   status, `Location`, and body;
2. an existing different version/hash returns `409 idempotency_conflict`;
3. only an absent record proceeds to current publication, attempt-limit, active-
   state, and domain checks, then stores the complete successful result before
   commit.

A same-hash replay wins even if the resource was later archived, its attempt is
now terminal, or the current maximum is reached. A failed first transaction
stores nothing.

Python grading uses the same step-zero key lock but stores/replays the durable
202 job reservation before execution. Its later finalization stores the
completed safe result exactly once. Infrastructure retries reuse that job and
never reinterpret the request hash or create a failed attempt.

A record is live only while database `now() < expiresAt`. At or after expiry,
the request and cleanup worker serialize on the same key lock, re-read the row,
and treat the key as fresh; the request replaces the expired row and cleanup may
delete only the still-expired row. Do not let cleanup schedule latency extend
the semantic retention window.

## Status rules

| Status | Use |
| --- | --- |
| 200 | successful read/update/action with response |
| 201 | new resource/attempt |
| 204 | successful delete-like idempotent completion removal |
| 400 | JSON/schema/header/query validation failure |
| 401 | missing/invalid authentication |
| 403 | authenticated but MFA/AAL or role/capability requirement is not met |
| 404 | absent or intentionally concealed inaccessible resource |
| 409 | version, slug, idempotency, immutable state, or active-attempt conflict |
| 413 | payload exceeds the configured limit |
| 415 | unsupported request content type |
| 422 | valid request shape violates domain workflow |
| 429 | rate limited |
| 500 | unexpected internal error |
| 503 | required dependency unavailable, including one dependency-call deadline |
| 504 | total handler budget exhausted before a response |

## Stable problem codes

| Code | Status |
| --- | ---: |
| `validation_failed` | 400 |
| `auth_required`, `token_invalid` | 401 |
| `mfa_required`, `role_required`, `access_suspended` | 403 |
| `not_found` | 404 |
| `version_conflict`, `slug_conflict`, `idempotency_conflict`, `content_immutable`, `active_attempt_conflict`, `attempt_expired` | 409 |
| `payload_too_large` | 413 |
| `unsupported_media_type` | 415 |
| `invalid_state_transition`, `content_invalid`, `attempt_limit_reached`, `answer_invalid` | 422 |
| `rate_limited` | 429 |
| `internal_error` | 500 |
| `dependency_unavailable`, `grading_capacity_unavailable`, `grader_unavailable` | 503 |
| `operation_timeout` | 504 |

A Supabase operation reaching `DEPENDENCY_TIMEOUT_MS` maps to
`503 dependency_unavailable` with a fixed safe detail. Exhausting the overall
`HANDLER_TIMEOUT_MS` maps to `504 operation_timeout`. If the client disconnects,
abort propagated work where supported, log only safe cancellation context, and
emit no HTTP response. A transaction already accepted by the database may still
commit, so mutation reconciliation/idempotency rules remain mandatory.

Submitting an already terminal quiz attempt is a successful idempotent replay,
not an `attempt_already_submitted` error.

## Caching and privacy

- Profile, attempts, progress, admin, and authoring responses use
  `Cache-Control: private, no-store`.
- Published catalog may use private short-lived conditional caching only after
  authorization and invalidation are tested.
- Never include answer keys, raw accepted answers, secret values, internal SQL
  errors, or another user's data.
- Response schemas and explicit database select lists are both required.
