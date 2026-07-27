# Errors, logging, and API security

## Typed error families

- validation;
- authentication;
- insufficient authenticator assurance;
- authorization;
- account access suspended by a live identity security hold;
- not found/concealed;
- version or idempotency conflict;
- invalid lifecycle/domain state;
- rate limit;
- dependency unavailable;
- operation timeout;
- unexpected internal.

Map known PostgreSQL constraint/function codes by stable constraint/function
name. Never return raw Supabase/PostgreSQL messages, codes, query fragments, or
stack traces.

## Problem response

All errors use `application/problem+json` with:

- `type`, `title`, `status`, `detail`, `instance`;
- stable `code`;
- `requestId`;
- optional safe `errors` array of `{ field, code, message }`.

`detail` is user-safe. The log contains diagnostic context keyed by request ID.
For code `<code>`, `type` is the stable
`urn:coditza:problem:<code>` and `instance` is
`urn:coditza:request:<requestId>`; do not place a query string, token, or
resource contents in either. Validation `field` values use JSON Pointer for
body data and the prefixes `/params`, `/query`, or `/headers` for other inputs.
`title` is a fixed code-specific phrase, never a raw dependency message.

## FAST-ERR-001 — Global handlers

- [ ] One not-found handler uses the same format.
- [ ] One error handler maps validation, rate-limit, application,
      outbound-adapter/dependency, and unexpected errors.
- [ ] Validation never echoes authorization or oversized raw values.
- [ ] Inaccessible resource may map to 404 when revealing existence is unsafe.
- [ ] Unexpected error is logged once and returned as generic `500
      internal_error`.
- [ ] A dependency-call deadline returns fixed `503 dependency_unavailable`; a
      total handler deadline returns fixed `504 operation_timeout`; a client
      disconnect emits no response.
- [ ] Error response schemas are registered in OpenAPI.

## Logging rules

Use structured Fastify/Pino logs. Include:

- request ID, environment, method, route pattern, safe status, duration;
- safe user ID after authentication;
- stable application error code;
- dependency name and operation category, not credentials/query contents.

Redact:

- authorization/cookies;
- publishable/secret keys, passwords, connection strings;
- TOTP codes/secrets, QR SVG, `otpauth` URIs, refresh tokens, and
  factor/challenge/Auth SDK bodies;
- answer payloads and answer specs;
- raw Markdown bodies and free-text learner input;
- email and Auth metadata by default.

No `console.log` in runtime request code. Pretty output is local-only.

## Security checklist

- [ ] Exact CORS allowlist.
- [ ] Helmet reviewed.
- [ ] Global and route-level rate limits.
- [ ] Payload and string/array limits.
- [ ] JSON Schema has `additionalProperties: false` for request objects.
- [ ] Parameterized Supabase/RPC use only.
- [ ] Markdown raw HTML is treated as untrusted and rendered/sanitized by a
      future client.
- [ ] Secret key never appears in client artifacts or OpenAPI examples.
- [ ] Swagger UI disabled or separately protected in production.
- [ ] Dependencies and lockfile audited; findings triaged rather than blindly
      suppressed.
- [ ] Security-definer/RLS tests pass.
- [ ] Attempt times use server/database time.
- [ ] Idempotency and concurrency paths are tested.
