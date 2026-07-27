# Registration, login, and mandatory Authenticator MFA

## Product contract

Supabase Auth is the identity provider. Email/password is factor one and a TOTP
code from an Authenticator application is mandatory factor two. Fastify does not
proxy either factor and exposes no signup, login, TOTP, or recovery endpoint.

Registration creates the Auth identity before TOTP enrollment because the
Supabase enrollment API requires an authenticated `aal1` session. “TOTP required
for registration” therefore means the account cannot enter Coditza until the
enrollment challenge is verified and the session reaches `aal2`.

## Authoritative client state machine

| State | Supabase Auth evidence | Permitted action | Coditza domain API |
| --- | --- | --- | --- |
| `signed_out` | no session | sign up, confirm email, or password login | denied |
| `email_confirmation_pending` | user created, no usable session | confirm email, then obtain `aal1` | denied |
| `mfa_enrollment_required` | `currentLevel=aal1`, `nextLevel=aal1` | enroll and verify TOTP | denied |
| `mfa_challenge_required` | `currentLevel=aal1`, `nextLevel=aal2` | challenge and verify a chosen verified factor | denied |
| `authenticated` | `currentLevel=aal2`, `nextLevel=aal2` | enter Coditza | allowed |
| `stale_after_factor_change` | `currentLevel=aal2`, `nextLevel=aal1` | refresh immediately, then re-enroll | denied by client; bounded server acceptance ends with the old token |

Unknown combinations fail closed. The client never infers completion from the
presence of a session alone.

## Registration flow

1. Call Supabase `signUp` with email/password and the exact approved redirect.
2. If confirmation is enabled and no session is returned, show only the
   confirmation-pending state. After confirmation, obtain an `aal1` session.
3. Call `getAuthenticatorAssuranceLevel` and `listFactors`.
4. If there is no verified TOTP factor, call `mfa.enroll` once for the current
   enrollment attempt with `factorType: "totp"`.
5. Display the returned QR code and manual secret only in the active enrollment
   view. Keep the factor ID in session memory; never persist or log QR, URI, or
   secret.
6. Accept exactly the current TOTP code from the user and call
   `challengeAndVerify` (or the pinned equivalent challenge + verify pair).
7. Re-read the assurance level. Registration completes only when the factor is
   verified and `currentLevel` is `aal2`.
8. If enrollment is abandoned or reloaded, list factors and follow the current
   supported unverified-factor cleanup/resume behavior; never create factors in
   a render loop or silently accumulate them.

## Login flow

1. Call `signInWithPassword`; this establishes `aal1`.
2. Read `currentLevel` and `nextLevel`.
3. For `aal1 → aal2`, list only verified TOTP factors, let the user select one
   when multiple exist, and call `challengeAndVerify` with the entered code.
4. For `aal1 → aal1`, route to mandatory enrollment instead of the application.
5. For `aal2 → aal2`, continue.
6. After successful verification, re-read/refresh the session and send only the
   new `aal2` access token to Fastify.
7. A failed, expired, or rate-limited challenge stays on the MFA step with a
   safe error and bounded retry; it never falls back to `aal1` application
   access.

## Factor lifecycle and recovery

- Only a verified TOTP factor satisfies the policy.
- One factor is mandatory; a second factor on a separate device is the supported
  backup because recovery codes are not assumed.
- Allow at most two verified TOTP factors by DEC-030. Verify a replacement
  before removing the old factor.
- A future conforming client does not offer removal of the last verified
  factor. A user who removes it by calling Supabase directly is denied after
  session refresh and must enroll again.
- Self-service unenrollment requires an `aal2` session and an immediate session
  refresh afterward.
- Password reset does not bypass or remove MFA.
- “Every login” means every newly created Supabase sign-in session. Refreshing
  the same valid `aal2` session does not ask for a new code.
- Loss of all factors has no public API fallback. DEC-029 and the operations
  runbook must define identity proof, exact environment/user confirmation, an
  operator-only Coditza security hold, privileged factor deletion, all-session
  revocation, a residual-access-token quarantine, audit evidence, and fresh
  enrollment before production self-service signup. Set the security hold
  first; revoke/delete; wait the configured maximum access-token lifetime plus
  skew; revoke/delete again; then permit fresh TOTP enrollment and clear the
  hold only after verification.
- Never claim or generate recovery codes unless current Supabase project-user
  Auth explicitly supports them and a later approved ADR changes this contract.

## Security and privacy

- TOTP inputs are fixed six ASCII digits in the client; Supabase remains the
  verifier and time-window authority.
- Passwords, codes, QR SVG, `otpauth` URI, factor secret, refresh token, and
  complete factor objects are sensitive and excluded from Fastify, Coditza
  tables, telemetry, crash reports, screenshots, and test artifacts.
- Use Supabase Auth rate limits. Do not automatically retry a failed
  verification or create a new challenge on every render.
- Enable security notifications for factor enrollment/removal when verified
  email delivery exists.
- All roles, including editors/admins, follow the same minimum `aal2` policy.
- Authenticator specificity is proven from a verified signed `amr` method when
  the pinned Supabase JWT contract reliably supplies it. Otherwise it is proven
  by TOTP-only project configuration plus the genuine enrollment/challenge
  flow; unsigned client state is never trusted by Fastify.
- An issued stateless access JWT can remain cryptographically valid until its
  `exp`; provider session revocation stops continued refresh but must not be
  described as retroactively invalidating that JWT. Normal factor changes have
  the recorded bounded residual window. Operator recovery additionally sets a
  live Coditza security hold, so an old AAL2 token is denied at the profile
  check on its next domain request; the quarantine/re-delete step also prevents
  a still-valid old token from racing a replacement factor through Auth.

## PRD-AUTH-001 — Freeze the mandatory MFA client contract

Prerequisites: ARC-DESIGN-001 and current official Supabase Auth documentation.

- [x] Record an ADR stating mandatory TOTP, direct-to-Supabase Auth, and no
     Fastify credential proxy.
- [x] Record the required provider operations and expected result categories
     without pinning a package version that FOUND-001 has not selected.
- [x] Mark exact version-specific SDK calls/results as out of scope here and
     assign them exclusively to SUP-MFA-001 after FOUND-001.
- [x] Define the provider-neutral client interface for signup, confirmation,
     enrollment, challenge, verification, refresh, logout, and factor listing.
- [x] Define stable client states and safe error categories without exposing
     whether an unrelated email account exists.
- [x] Define resume/cleanup behavior for unverified factors and multiple-factor
     selection from verified factors only.
- [x] Define the `aal2` handoff to Fastify and prohibit domain calls with an
     `aal1` token.
- [x] Freeze the conditional assurance rule without claiming a provider
     observation: SUP-MFA-001 must test the pinned signed `amr`; require its
     TOTP method when reliable, otherwise use the reviewed TOTP-only
     configuration/AAL2 fallback.
- [x] Record that no UI is implemented in this backend repository and list the
     later frontend acceptance requirements without selecting a framework.
- [x] Resolve or explicitly block DEC-029 before production self-service signup.

Evidence is the approved ADR, provider-operation/state-transition contract,
safe error model, conditional assurance rule, threat review, and
client-contract fixtures without real credentials or enrollment material. It
contains no pinned SDK mapping or observed JWT claim.

Accepted evidence: [ADR 0002](../../docs/adr/0002-mandatory-totp-direct-supabase-auth.md),
[provider-neutral client contract](../../docs/implementation/auth-mfa-client-contract.md),
and [PRD-AUTH-001 report](../../docs/implementation/PRD-AUTH-001.md).
