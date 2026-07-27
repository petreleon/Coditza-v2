# OpenAPI, liveness, and readiness

## Health routes

### `GET /health/live`

- no Auth and no external dependency call;
- returns `200` when the process event loop and Fastify instance are serving;
- response: `{ "status": "ok" }`;
- minimal separate rate limit;
- no build versions, URLs, project refs, or internal details.

### `GET /health/ready`

- no Auth but minimal response;
- uses a short timeout;
- verifies required plugins initialized and makes a bounded read-only Supabase
  `server_readiness()` RPC probe;
- returns `200 { "status": "ready" }` or `503 { "status": "not_ready" }`;
- logs dependency category/request ID without returning database details;
- readiness failure does not terminate the process.

Health responses are deliberately exempt from the universal Problem Details
shape so probes receive one minimal stable schema.

## FAST-LIVE-001 — Implement foundation liveness

- [ ] Add `/health/live` during Phase 1 with its response schema/test.
- [ ] Use it for Compose health with an executable guaranteed to exist in the
      runtime image; prefer a Node-based check rather than adding `curl` only for
      health.
- [ ] Prove it has no Supabase dependency.

## FAST-HEALTH-001 — Verify runtime behavior

- [ ] Foundation liveness still succeeds when Supabase is unavailable.
- [ ] Readiness fails quickly and safely when Supabase is unavailable.
- [ ] Readiness recovers without process restart.
- [ ] Compose health check targets liveness.
- [ ] Deployment traffic gate targets readiness.
- [ ] Shutdown changes readiness before connections close.

## OpenAPI

- OpenAPI is derived from the same Fastify route schemas used at runtime.
- Generate a committed `docs/api/openapi.json` deterministically.
- API title is `Coditza API`; version matches the API contract/release.
- Bearer security scheme is defined once and applied to protected routes.
- Every route includes operation ID, tags, params/query/body, all expected
  responses, and safe examples.
- Internal tables, keys, answer specs, secret fields, and privileged DTOs do not
  appear in learner schemas.
- Swagger UI may run locally; production default is off.
- OpenAPI schema registration/generation is always enabled; only the interactive
  UI is controlled by `SWAGGER_UI_ENABLED`.

## FAST-OAS-001 — Contract drift gate

- [ ] Generate OpenAPI after app readiness without opening a port.
- [ ] Validate the document.
- [ ] Compare generated output in CI and fail on unexplained diff.
- [ ] Run response-schema tests for every status family.
- [ ] Scan all schemas/examples for secret values/fields, and scan learner
      schemas specifically for answer-spec/correct-answer internals. Protected
      authoring schemas may describe an `answerSpec` shape but contain no real
      answer example.
