# SUP-FUNCTIONS-001 — staff authorization primitive slice

Status: **in progress**. This is the fourth bounded slice of
SUP-FUNCTIONS-001, not completion of the task.

## Scope completed in this slice

- Added three identity-owned private helpers over the live `public.profiles`
  row: `has_role`, `is_staff`, and `assert_active_staff_actor`.
- Made the authoring assertion take a row lock, require no active security hold,
  and allow only `editor` or `admin`. A later role/hold change therefore cannot
  race an in-flight authoring transaction past a stale boolean check.
- Kept role predicates private, `SECURITY INVOKER`, owner-controlled, fixed to
  an empty search path, and non-executable by `PUBLIC`, browser roles,
  `service_role`, or `authenticator`.
- Proved active editor/admin acceptance and rejection for a learner, missing
  profile, held editor, and a live-demoted editor. The test also proves that
  role reads use current profile data rather than JWT/Auth metadata.

## Deliberately not implemented

- First-admin bootstrap, audited role-control, final-admin protection, or
  identity-hold/recovery operations; those remain owned by SUP-BOOTSTRAP-001,
  SUP-AUTH-002, and SUP-AUTH-003.
- A public RPC, Fastify route, direct client grant, Auth claim, or hosted
  Supabase configuration.
- Any curriculum or assessment authoring/lifecycle operation. The next slice
  must call `private.assert_active_staff_actor`, never a bare role boolean,
  before it accesses a draft or answer key.

## Files

- `supabase/migrations/20260729010400_add_staff_authorization_predicates.sql`
- `supabase/tests/functions_test.sql`

## Verification

On 2026-07-29, the protected local function verifier passed after fresh reset
before and after every suite:

    npm run supabase:verify-functions:local

It reviewed 17 forward migrations, all predecessor pgTAP suites, and the
20-assertion server-only-function suite. The function-suite test digest was:

    8830a7750b80aab9cf5389056f0bd905e47471ad309582a2e7bc871bbd755f42

No browser, HTTP route, hosted Supabase, SMTP, MFA, Vercel, or secret value was
used.

The Docker Compose foundation gate also passed: formatting, lint and dependency
boundaries, TypeScript checks, the production build, and 184 unit tests.

## Continuation

Keep SUP-FUNCTIONS-001 active. The next bounded database slice is
`curriculum_create_draft_module`: a server-only, staff-asserted draft creation
facade with root-scope position serialization, strict input validation,
idempotency, safe replay projection, and sanitized audit evidence.
