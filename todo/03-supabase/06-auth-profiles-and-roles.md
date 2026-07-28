# Auth, profiles, and roles

## Supabase Auth boundary

Supabase owns passwords, TOTP factors/secrets/codes, challenges, sessions,
refresh tokens, email confirmation, and access-token issuance. Fastify never
stores or accepts this material. A future client uses the publishable key for
Auth and sends only the resulting `aal2` access token to Fastify.

Profile creation occurs when the Auth identity is created, before mandatory MFA
enrollment may finish. A profile is not proof of completed registration and
does not grant an `aal1` session access to Coditza.

## `public.profiles`

- `id uuid primary key references auth.users(id) on delete cascade`
- `display_name text not null` with 1–80 character trimmed check
- `role app_role not null default learner`
- `security_hold_at timestamptz null`; this is a Coditza access-control flag,
  not copied Supabase factor/session state
- `created_at`, `updated_at`

Do not duplicate password data, provider secrets, full Auth metadata, email,
factor status/ID, TOTP secret/code, QR SVG or `otpauth` URI unless a later
approved feature proves it needs a separately governed non-secret projection.

For the signup projection, client-controlled Auth metadata has one accepted
JSON key: camelCase `displayName`. Database columns remain `snake_case`; no
legacy alias is accepted, and invalid or absent metadata uses `Learner`.

## SUP-AUTH-001 — Signup profile

- [x] Create a fixed-search-path security-definer trigger function.
- [x] Insert a profile for each new Auth user.
- [x] Accept a trimmed 1–80 character display name only when valid; otherwise use
      the non-identifying constant `Learner`. Do not derive it from email.
- [x] Always force role `learner`, ignoring client metadata.
- [x] Initialize `security_hold_at` to null and deny all user-writable access to
      it.
- [x] Make duplicate invocation harmless or clearly constrained.
- [x] Test signup rollback if profile creation fails.
- [x] Test profile creation at `aal1` does not imply domain API access and stores
      no factor/enrollment metadata.
- [x] Test account deletion follows the approved cascade policy.

## SUP-AUTH-002 — Role control

The required reason for a privileged identity operation is an approved
non-content audit reason code, not free text. Role transitions must use the
safe before/after role codes from the audit contract.

- [ ] Prevent direct user updates to `role` with column grants/policies.
- [ ] Admin role-change function receives the Fastify-verified actor ID from the
      identity Supabase adapter and loads its current role from `profiles`.
- [ ] Require a non-empty reason.
- [ ] Prevent self-promotion and removal of the last admin.
- [ ] Serialize bootstrap, promotion, demotion, admin-account deletion, and any
      admin-count change with one transaction-scoped advisory lock (or one
      explicitly locked singleton row), then lock the target/recount/update.
- [ ] Add a `BEFORE DELETE` profile trigger that takes the same lock and rejects
      deletion of the final admin, including an `auth.users` cascade; direct
      Auth-admin deletion must not bypass the invariant.
- [ ] Append a sanitized audit event.
- [ ] Ensure the change is visible on the next request without waiting for JWT
      metadata refresh.

## SUP-BOOTSTRAP-001 — First-admin bootstrap

The bootstrap reason is an approved reason code; the script must not accept or
persist a free-form explanation.

Do not edit `profiles.role` manually in the Dashboard.

1. Create/confirm the intended Auth user in the correct non-production project.
2. Run a future server-side bootstrap script using secret credentials from
   runtime storage.
3. Require the exact project reference, exact user UUID, typed environment
   confirmation, and reason.
4. Permit it only when no admin exists.
5. Acquire the same serialization lock used by all admin-count changes.
6. Write an audit record with `actor_kind=system` and no fabricated actor user.
7. Delete/disable the bootstrap capability after the first admin or make its
   no-admin precondition permanent.

Production bootstrap is separately approved and never reused from development.

## SUP-AUTH-003 — Build the identity hold and recovery operator

Identity-hold transitions use the approved security_hold reason code and safe
before/after hold-state codes. No free-form operator note, factor state, email,
or Auth material belongs in the audit row.

Prerequisites: profile/audit tables, workflow-function security, and
SUP-AUTH-002.

- [ ] Add one identity-owned server-system function that locks the target
      profile, sets or clears `security_hold_at`, requires a non-empty reason,
      and appends a sanitized audit event in the same transaction.
- [ ] Expose no Fastify route or client-callable function for this operation;
      `PUBLIC`, `anon`, and `authenticated` execution remains denied.
- [ ] Implement one isolated operator executable under `scripts/` with its own
      minimal entrypoint and explicit `begin`, `prepare-enrollment`, `status`,
      and `complete` stages; it is never imported into or registered by
      Fastify.
- [ ] Require exact environment, project reference, target user UUID, action and
      non-empty reason. Default to local only; every hosted invocation requires
      the matching task/runbook and typed environment/user confirmation.
- [ ] Make setting an existing hold and clearing an absent hold explicit
      idempotent outcomes; never silently overwrite unrelated identity state.
- [ ] In `begin`, set the hold first, then use current supported Admin Auth APIs
      to revoke every session and delete all existing TOTP factors. If a later
      step fails, keep the hold active and make rerunning `begin` safely resume;
      never compensate by clearing the hold.
- [ ] Record a non-secret quarantine boundary from the actual configured maximum
      access-token lifetime plus reviewed clock skew. Before that boundary, do
      not permit replacement enrollment; an old access JWT may still call Auth
      even though Coditza domain access is held.
- [ ] In `prepare-enrollment`, refuse to run before the quarantine boundary,
      revoke sessions again, delete any factor created during quarantine, and
      record the reset complete. Use a current provider account-disable control
      as defense in depth when proven, but never substitute it for the measured
      residual-token boundary without official guarantees and an ADR.
- [ ] Keep fresh TOTP enrollment/verification direct between the user/headless
      harness and Supabase Auth. In `complete`, query provider state in memory,
      require the successful `prepare-enrollment` stage plus at least one
      currently verified TOTP factor, and only then clear the hold. Do not
      accept a client boolean or factor ID as proof.
- [ ] Make `status` return only environment/target fingerprints, stage and
      boolean/count summaries; never factor IDs, email, tokens or Auth bodies.
- [ ] Pin the exact Admin Auth operations to the FOUND-001 SDK/provider version
      and add an ADR if global session revocation requires a different current
      supported management API.
- [ ] Prove every transition and reason is audited without token, email,
      factor/challenge, QR, secret, or TOTP material.
- [ ] Record that session revocation prevents refresh but an issued access JWT
      may remain cryptographically valid until `exp`; the live profile hold is
      the immediate Coditza-domain containment.

Evidence includes local function/grant/concurrency/audit tests, executable
unit/integration tests against synthetic local Auth, residual-token quarantine,
factor-race cleanup, partial-failure/resume tests, and the recovery state
machine. End-to-end denial of an old AAL2 token belongs to FAST-AUTH-002 and
QA-MFA-001. OPS-RUNBOOK-001 later owns an approved invocation of this
already-built executable in selected pre-production; it may not implement or
edit the executable.

## Token verification requirements

- Require exactly one Bearer token.
- Use current Supabase verified-claims/JWKS guidance; never merely decode.
- Validate signature, expiration, issuer, intended project, and expected
  audience/platform-role claims according to current Supabase guidance. JWT
  `role` is a Supabase platform claim; `profiles.role` remains the only Coditza
  role authority.
- Validate a UUID `session_id`. Treat a missing `aal` as `aal1`; every domain
  route requires exact `aal2` before loading the profile.
- Use the slower Auth-server verification fallback if the project signing-key
  mode requires it.
- Load the profile, current role, and `security_hold_at` after token
  verification.
- Treat missing profile, unknown role, active security hold, or dependency error
  as denial.
- Never log or cache the raw token.
- Never query or copy factor secrets/codes through a Coditza adapter.
