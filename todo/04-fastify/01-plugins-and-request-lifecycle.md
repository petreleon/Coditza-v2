# Plugins and request lifecycle

## Registration order

Register dependencies before consumers:

1. Fastify construction with logger, request IDs, body/time limits, trust proxy;
2. security headers;
3. CORS;
4. rate limiting;
5. OpenAPI schema support;
6. stateless publishable-key Auth verifier;
7. composition-root-created module facades backed by module-specific Supabase
   adapters; the raw secret client remains infrastructure-private;
8. authentication, exact `aal2`, and authorization decorators;
9. root-scoped common error/not-found behavior;
10. health routes;
11. versioned domain routes.

Use Fastify plugins and encapsulation deliberately. Decorate before use and type
every decoration through TypeScript declaration merging.

The app factory installs `setErrorHandler` and `setNotFoundHandler` directly on
the root Fastify instance before registering route plugins. Do not register
either as an encapsulated sibling plugin. Type providers do not propagate
through encapsulation: every route plugin begins from the received instance
with `.withTypeProvider<TypeBoxTypeProvider>()` before declaring routes.

## FAST-PLUGIN-001 — HTTP safeguards

- [ ] Set a documented global body limit and smaller route-specific limits where
      assessment payloads permit.
- [ ] Use 4 KiB for profile PATCH and 32 KiB for learner answer mutations;
      the Python source-package route and admin complete-definition routes may
      use the 1 MiB global ceiling, while decoded Python files still obey the
      64 KiB/file and 256 KiB aggregate product limits.
- [ ] Accept JSON for mutation routes; reject unexpected content types.
- [ ] Configure Helmet with reviewed defaults.
- [ ] Parse an exact CORS allowlist; never reflect arbitrary origins.
- [ ] CORS allows `Authorization`, `Content-Type`, and `Idempotency-Key`; exposes
      `Location`, `Idempotency-Replayed`, and the configured request-ID header;
      allows exactly `GET, HEAD, POST, PUT, PATCH, DELETE` plus preflight; uses
      no cookies/credentials in MVP; and handles preflight without exposing
      domain data.
- [ ] Apply a global rate limit plus stricter attempt/admin mutation limits.
- [ ] Key the global limiter by trusted effective client IP. After successful
      authentication, key attempt/admin mutation limiters by `userId` (with IP
      retained in safe diagnostic context); an IP change must not reset a
      user's mutation quota.
- [ ] Document that in-memory rate-limit state is valid only for one API replica;
      select a reviewed shared store before running multiple replicas.
- [ ] Generate UUID request IDs. Accept an incoming ID only from a trusted proxy
      and only after length/format validation.
- [ ] Configure `trustProxy` only from explicit environment topology.
- [ ] Define connection/request/keep-alive timeouts compatible with the host.
- [ ] Treat `REQUEST_RECEIVE_TIMEOUT_MS` only as Fastify/Node body-receive
      protection. Add one per-request `AbortController` for client disconnect
      and `HANDLER_TIMEOUT_MS`, pass its signal through use cases/outbound
      ports/adapters, and bound each Supabase call by `DEPENDENCY_TIMEOUT_MS`
      using the current supported abort API.
- [ ] Test slow body, slow dependency, client disconnect, and handler deadline.
      Map a dependency-call deadline to `503 dependency_unavailable`, total
      handler-budget exhaustion to `504 operation_timeout`, and a disconnected
      client to no response.
      A transport abort may not cancel a database transaction already accepted;
      mutation clients reconcile with GET and reuse required idempotency keys.

## FAST-PLUGIN-002 — Supabase dependencies

- [ ] Create one server-scoped client with the publishable key for token
      verification only.
- [ ] Create one required server-only domain dependency with the secret key;
      keep it private to the composition root and adapter factories.
- [ ] Disable session persistence, auto-refresh, and URL session detection in
      both server clients.
- [ ] Construct one narrow adapter per application port; never expose a global
      dependency/service bag through Fastify decoration.
- [ ] Give each inbound HTTP adapter only its module's use-case facade.
- [ ] Add tests that verified actor context is passed explicitly and concurrent
      requests never mix user IDs/roles/AAL/session IDs.

## Request path

1. Fastify assigns request ID and applies transport limits.
2. Route JSON Schema validates syntax only.
3. Authentication pre-handler verifies a token if route requires it.
4. MFA pre-handler requires exact `aal2` and valid `session_id`.
5. Identity adapter loads current profile role for the verified subject.
6. Authorization pre-handler checks role.
7. HTTP adapter calls one application use case with verified principal.
8. Use case calls typed outbound ports; an adapter maps rows/RPC outcomes.
9. HTTP presenter builds an allowlisted DTO.
10. Response JSON Schema serializes only declared fields.
11. Completion log records safe status/duration.

Do not make database calls inside JSON Schema validation. Do not put business
logic in hooks that run for unrelated routes.

## FAST-PLUGIN-003 — Lifecycle verification

- [ ] Plugin boot order is covered by an app-ready test.
- [ ] Nested route plugins prove TypeBox request/reply inference without unsafe
      casts, and root handlers catch errors/not-found from every route scope.
- [ ] Liveness works without authentication.
- [ ] Protected routes never execute their handler after auth failure.
- [ ] `aal1`, missing/unknown AAL and invalid session ID never load a profile or
      execute a domain handler.
- [ ] Oversized/incorrect-content-type requests fail before use-case execution.
- [ ] Rate-limit responses follow the common problem contract.
- [ ] App shutdown closes dependencies exactly once.
- [ ] Composition-root resources close once in reverse construction order.
