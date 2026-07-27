# Fixed decisions

These decisions are authoritative until the user explicitly changes them or an
approved ADR supersedes one.

## Product and language

- The product and repository name is `Coditza`.
- Learner-facing authored content is initially Romanian (`ro-RO`) with correct
  diacritics. Python/code identifiers remain in English.
- The first real course module is titled `Arhitectură software în Python` and is
  planned separately in the repository-root `todo-curriculum-ro/`.
- Code identifiers use the correct English forms `quiz` and `quizzes`.
- A module contains one or more chapters.
- A publishable chapter contains at least one published theory section, one
  published exercise, and one published quiz.
- Theory is stored as multiple ordered sections, not one unstructured chapter
  blob.
- `python_code` is an exercise-only type with bounded multi-file source
  submissions. Quiz questions remain limited to the three scalar answer types.
- Python exercise points/progress come only from a fresh authoritative
  server-side Python-on-WebAssembly run. A future browser Web Worker may run
  public tests for provisional feedback but its report is never trusted.
- Content bodies use Markdown source. Raw HTML is always untrusted and a future
  client must disable or sanitize it so it can never execute.

## Backend

- Use TypeScript in strict mode, ECMAScript modules, Node.js, and Fastify.
- Use one deployable modular monolith. Inside it, each bounded context follows
  ports and adapters: domain, application/use cases and outbound ports,
  inbound HTTP adapters, and outbound Supabase adapters.
- Untrusted Python is the sole justified process/deployment exception: a
  private grader controller from the same reviewed release claims assessment
  jobs and launches a disposable hardened outer sandbox containing the pinned
  Pyodide worker. It is not a public domain service and owns no data.
- The fixed bounded contexts are `identity`, `curriculum`, `assessment`,
  `progress`, and `operations`. Health is a platform adapter, not a business
  context. Learner and admin HTTP routes live in the module that owns the
  behavior; `catalog` and `authoring` are not separate owners of the same data.
- Cross-module code imports only the target module's `public.ts`. Domain and
  application code never imports Fastify, TypeBox, Supabase, generated database
  types, or another module's adapter internals.
- A single Fastify API composition root constructs module-specific adapters and
  injects ports into use cases. Approved one-off operator executables have
  isolated minimal entrypoints and are never imported into the API. Do not add
  a global repository bag, service locator, runtime DI framework, event bus,
  ORM, or microservice boundary in the MVP.
- A separate grader-controller composition root constructs only assessment
  queue, runtime-manifest, sandbox-launch, and safe-metrics adapters. It has no
  public listener, cannot be imported by Fastify, and cannot become a general
  job/command execution framework.
- At bootstrap time, choose the current active Node.js LTS supported by the
  current Fastify major, then pin exact versions in the lockfile, container
  image, CI, and an ADR. Do not copy a stale version from this plan.
- Use `npm` and npm workspaces. The API package lives in `apps/api`.
- Build a REST API under `/api/v1`.
- Use Fastify JSON Schemas and the official TypeBox type provider so request
  validation, response serialization, and TypeScript types share one source.
- Use the logger provided by Fastify/Pino. Do not use ad hoc `console.log` in
  request paths.

## Supabase

- Supabase provides hosted PostgreSQL and Supabase Auth.
- Email/password is the first factor. TOTP from an Authenticator application is
  mandatory for every learner, editor, and admin.
- Registration is considered complete only after an existing `aal1` session
  enrolls and verifies a TOTP factor and the refreshed session is `aal2`.
- Every later login performs password authentication to `aal1`, then a
  challenge/verification with one verified TOTP factor to obtain `aal2`.
- Fastify rejects every `/api/v1` domain request whose verified token is not
  `aal2`. Health endpoints remain the only public Fastify routes.
- Supabase Auth alone owns factor secrets, QR/`otpauth` enrollment material,
  TOTP verification, passwords, refresh tokens, and factor state. None is
  copied into `profiles`, Coditza tables, logs, analytics, screenshots, or
  reports.
- Auth registration/login, JWT/AAL checks, and TOTP challenge/verification
  never run in Python/WASM and no Auth/TOTP material enters a grading job,
  controller, sandbox, fixture, log, or report.
- Supabase Auth recovery codes are not assumed. A second TOTP factor on a
  separate device is the supported backup; loss of all factors follows the
  separately approved recovery decision/runbook and never a public reset route.
  Operator recovery sets a live Coditza identity security hold before factor
  deletion/session revocation, waits the measured residual access-token window,
  revokes/deletes again, and clears the hold only after fresh TOTP verification.
  This prevents old JWT domain access and Auth-factor enrollment races.
- Use the Supabase CLI for local migrations, reset, seed, type generation, and
  database tests. Its local stack runs in Docker.
- SQL migration files are the only source of truth for schema, functions,
  grants, indexes, triggers, and RLS policies.
- Use current publishable and secret API keys. Do not start a new implementation
  with legacy `anon` or `service_role` keys.
- A client calls Supabase Auth directly with the publishable key for signup,
  confirmation, password login, TOTP enrollment/challenge/verification, factor
  listing, session refresh, and logout. All Coditza domain reads and writes go
  through Fastify.
- Fastify verifies the Supabase access token with a stateless publishable-key
  verifier, then uses one server-only secret-key client for Coditza domain
  adapters and named transaction functions.
- `anon` and `authenticated` receive no direct Coditza table mutation/read or
  workflow-function access. RLS remains enabled with deny-by-default policies.
- Fastify is the cryptographic end-user authorization boundary. It passes the
  verified user ID as a server-controlled function argument; a client body never
  supplies it. PostgreSQL rechecks that actor's current role, ownership,
  references, and state, but does not falsely claim to derive `auth.uid()` from
  the secret-key server call.
- Once the Phase-3 domain plugin exists, the secret client is required at API
  startup, never attached to a request, and available only through narrow
  module-specific Supabase adapters. The Phase-1 liveness-only scaffold has no
  database client. A
  first-admin/system operation uses an explicit system actor in audit data.
- Never put authorization roles in user-editable metadata. The current role is
  loaded from `public.profiles`.
- Every Data API table has RLS enabled and explicit deny-oriented grants.
- Answer-key tables live in an unexposed private schema; only named server-only
  functions may read/write them.
- Coditza objects/functions use the inaccessible `coditza_owner` table-owner/
  security-definer pattern specified by the RLS plan. The API runtime cannot
  assume that role or directly mutate Coditza tables.

## Containers

- A root `compose.yaml` is required for the Fastify API and, after
  ARC-WASM-001, the private grader-controller/isolation test wiring. Compose is
  not itself the per-submission security boundary.
- The normal bridged API container listens on `0.0.0.0`. A Linux-only local
  host-network connectivity path binds the API to `127.0.0.1` and publishes no
  Compose port.
- The Compose stack does not define another PostgreSQL database and does not
  duplicate the Supabase CLI stack.
- On macOS/Windows, the API container reaches the Supabase CLI endpoint through
  a documented host gateway such as `host.docker.internal`. On Linux, a gateway
  alone is not sufficient when the CLI is loopback-only; use the tested
  host-network override or a current officially supported shared Docker network
  described in the Compose plan. Never widen Supabase to public interfaces.
- Secrets enter the container at runtime. They are never copied into an image
  layer.
- WebAssembly or Node worker threads alone are not a security sandbox.
  Authoritative learner code runs in a disposable non-root outer sandbox with
  no network, secrets, host mounts, container socket, or package downloads and
  with hard CPU/wall/memory/process/file/output limits.

## Data conventions

- Primary identifiers are UUIDs generated by PostgreSQL.
- PostgreSQL names are `snake_case`; JSON/API names are `camelCase`.
- Time is stored as `timestamptz` in UTC and serialized as ISO 8601.
- Ordered children use non-negative integer `position` values and a stable UUID
  tiebreaker.
- Money and floating-point scoring are not needed. Points are integers; percent
  is calculated with a defined rounding rule.
- Content is soft-retired with `archived`. Published exercises, quizzes,
  questions, options, and answer keys are immutable immediately after
  publication; replace them by cloning to new draft IDs.
- Destructive cascades are avoided for authored content. User-owned progress and
  attempts follow an explicit privacy deletion policy.

## API/security conventions

- Authentication uses `Authorization: Bearer <access-token>` and requires the
  verified JWT claims `aal=aal2` and a valid `session_id` for every Coditza
  domain route.
- When the pinned Supabase JWT contract reliably emits signed TOTP `amr`
  evidence, Fastify requires it. Otherwise the reviewed TOTP-only Auth
  configuration plus genuine Supabase MFA flow establishes the factor type;
  Fastify never trusts a client-supplied factor claim.
- Successful responses use `{ "data": ..., "meta": ... }`; omit `meta` when it
  has no fields.
- Errors use `application/problem+json` with stable machine-readable codes and a
  request ID.
- All route bodies, params, queries, and responses have schemas.
- Pagination is cursor based; unbounded collection endpoints are forbidden.
- Learner responses may contain ordinary option IDs, but never reveal which IDs
  are correct, serialize a correct-answer association, expose accepted answers,
  or expose raw answer specifications.
- CORS is allowlist based. Rate limiting is stricter on Auth-adjacent and attempt
  submission routes.
- `python_code` submission accepts source only. Client/browser score, verdict,
  tests, runtime choice, definition, actor, and progress fields are rejected.

## Delivery

- Hosted development and production use separate Supabase projects and
  separate secrets. A separate staging project is created only if DEC-027 is
  accepted; otherwise development is the synthetic pre-production environment.
- Chrome is used for later hosted Supabase Dashboard configuration and visual
  verification. Schema authoring remains migration-first.
- Production creation, billing changes, destructive remote migrations, key
  rotation, and production deployment require explicit user approval.
- No frontend framework or hosting provider is assumed.
- Browser Pyodide/Web Worker behavior is only a future client adapter contract;
  it does not resolve DEC-006 or authorize a frontend.
