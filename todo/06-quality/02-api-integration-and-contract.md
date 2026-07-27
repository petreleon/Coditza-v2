# API integration and contract tests

Use `buildApp` and `fastify.inject()` so route tests do not open a port. Use
local Supabase for outbound-adapter/RPC integration; use injected fakes only when
testing a transport edge that does not need database behavior.

## Per-route matrix

For every endpoint test:

- valid request/status/headers/body;
- invalid UUID, query, cursor, body, unknown property, content type;
- missing/invalid token;
- otherwise valid `aal1` token rejected as `403 mfa_required` before profile,
  role, outbound-port and use-case execution;
- wrong role;
- not found or concealed resource;
- version/idempotency/domain conflict where applicable;
- dependency failure mapping;
- response JSON Schema compliance;
- absence of internal/forbidden fields;
- OpenAPI operation and examples.

## QA-API-001 — Identity/catalog contract

- [ ] `/me` never exposes email/Auth metadata/secret fields.
- [ ] module/chapter order and cursor boundaries are deterministic.
- [ ] learner sees only effectively published hierarchy.
- [ ] anonymous and invalid tokens fail.
- [ ] genuine TOTP `aal2` succeeds; genuine password-only `aal1` fails with the
      exact safe problem.
- [ ] response data maps to camelCase.

## QA-API-002 — Content contract

- [ ] theory/exercise/quiz endpoints return intentional empty arrays.
- [ ] exercise/quiz options contain no correctness fields.
- [ ] short-text content contains no accepted-answer hints.
- [ ] large but allowed Markdown is serialized correctly.
- [ ] response schema strips an injected internal persistence-adapter field.

## QA-API-003 — Learning contract

- [ ] exercise idempotent replay and conflict.
- [ ] quiz start/save/delete/submit state/status codes.
- [ ] own history pagination and cross-user concealment.
- [ ] expiry/attempt-limit/version conflicts.
- [ ] save/delete versus submit/expiry races and omitted-answer null projection.
- [ ] progress counts and completion endpoints.
- [ ] Python reservation/polling/replay/capacity/owner-concealment behavior and
      explicit rejection of client/browser verdicts.

## QA-API-004 — Admin contract

- [ ] learner/editor/admin matrix.
- [ ] draft version and publish validation errors.
- [ ] atomic quiz-definition replacement.
- [ ] authoring answer specs only on protected draft route.
- [ ] role-change reason/final-admin/audit.

## Contract drift

- [ ] Generate OpenAPI from the exact built app.
- [ ] Validate it as OpenAPI.
- [ ] Fail CI on unexplained generated diff.
- [ ] Scan learner schemas/examples for `answerSpec`, `correctOption`,
      `acceptedAnswers`, secret keys, and database `snake_case`.
- [ ] Confirm every documented response status has a runtime schema/test.
- [ ] Confirm no signup/password/TOTP/factor/challenge schema was accidentally
      added to Fastify/OpenAPI.
- [ ] Confirm no hidden Python test, private fixture/digest/traceback, learner
      source example, or sandbox-internal field appears in OpenAPI.
