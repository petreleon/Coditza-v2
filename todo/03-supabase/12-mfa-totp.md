# Supabase Authenticator-app TOTP configuration

## Boundary

Supabase Auth owns TOTP factor records, secrets, challenges, verification and
session upgrade. Coditza migrations create no TOTP table, trigger, function or
copy of factor state.

Local configuration must explicitly enable current TOTP enrollment and
verification settings. At implementation time, verify the exact CLI keys; the
current planned intent is:

```toml
[auth.mfa]
max_enrolled_factors = 2

[auth.mfa.totp]
enroll_enabled = true
verify_enabled = true
```

Do not copy this snippet blindly if the pinned CLI schema differs. Phone and
other MFA factors remain disabled. Email/password remains the only first factor.

## Local acceptance flow

Use a headless client with synthetic local users and in-memory credentials:

1. sign up and obtain/confirm an `aal1` session;
2. prove the profile exists while the client state remains registration
   incomplete; do not claim or test Fastify enforcement before FAST-MFA-001;
3. enroll a TOTP factor and capture QR/secret only inside the current test
   process;
4. generate a code with a test-only Authenticator implementation, challenge and
   verify;
5. prove the refreshed session is `aal2`;
6. start a new password session, prove it is `aal1`, then challenge one verified
   factor and reach `aal2`;
7. enroll/select a second factor, replace safely, and exercise approved
   unenrollment behavior;
8. clean all synthetic users/factors without writing credential material to
   reports.

Tests may use an in-memory TOTP seed only within one process. They must never
snapshot it, print it, put it in a fixture, or commit an `otpauth` URI.

## SUP-MFA-001 — Enable and prove local TOTP MFA

Prerequisites: FOUND-001, SUP-LOCAL-002, SUP-SMTP-LOCAL-001, SUP-AUTH-001,
PRD-AUTH-001 and resolved DEC-030.

- [ ] Re-open current official CLI/Auth MFA documentation and record the pinned
      config/API names.
- [ ] Using the exact `supabase-js` version selected by FOUND-001, map every
      PRD-AUTH-001 state transition to the current SDK calls/results and keep
      that mapping with the Auth ADR.
- [ ] Enable TOTP enrollment and verification explicitly in committed local
      `supabase/config.toml`; disable phone/other factors and set the approved
      maximum.
- [ ] Prove profile creation can occur at `aal1` but does not mean Coditza access
      is complete in the product/client contract; no factor data is copied into
      the profile and this Phase-2 task does not claim a Fastify denial.
- [ ] Test enroll → list → challenge → verify and exact `aal1 → aal2`
      transitions with a synthetic user.
- [ ] Implement the genuine local Auth test-helper adapter behind the interface
      created by QA-STRAT-001; keep deterministic fakes available for Phase-1
      tests that do not start Supabase.
- [ ] Test a fresh password login requires a new challenge, while refresh of the
      same `aal2` session preserves the approved assurance behavior.
- [ ] Test multiple-factor selection uses verified TOTP factors only.
- [ ] Inspect genuine verified JWTs from the pinned local stack for a stable,
      signed `amr` TOTP method. Require it when the provider contract reliably
      supplies it; otherwise record an ADR that TOTP-only project configuration,
      genuine provider flow, and exact `aal2` are the enforceable contract.
- [ ] Test abandoned/unverified enrollment resume or cleanup according to the
      pinned SDK; repeated rendering/calls cannot accumulate factors.
- [ ] Test replacement is verified before removal and final-factor removal is
      not offered by the reference client.
- [ ] Prove wrong/malformed codes and codes outside the provider-accepted time
      window never upgrade the session; measure and record same-code replay
      behavior from the pinned provider without adding a custom TOTP verifier.
- [ ] Prove provider rate limiting never degrades to application access or
      triggers an automatic verification retry.
- [ ] Prove password reset/email possession alone does not bypass a verified
      TOTP factor.
- [ ] Scan database, logs, reports and tracked files for codes, QR SVG,
      `otpauth`, seed/secret, refresh token, challenge/factor bodies and real
      credentials.

Evidence contains configuration names, sanitized state transitions, factor
counts/statuses only, negative-case outcomes and scan results. It contains no
factor ID, QR, secret, TOTP code, token, email or Auth response body.
