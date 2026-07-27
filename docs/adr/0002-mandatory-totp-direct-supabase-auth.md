# ADR 0002 — Mandatory TOTP through direct Supabase Auth

- Status: Accepted
- Date: 2026-07-27
- Decision owners: Coditza identity and product architecture
- Scope: future client contract only; no client implementation or provider setup

## Context

Coditza requires email/password as factor one and an Authenticator-app TOTP
factor as mandatory factor two for every learner, editor, and admin. Supabase
Auth owns the email/password, session, factor, challenge, verification, and
token lifecycle. A Fastify credential proxy would expand the sensitive-data
surface and would duplicate provider responsibilities.

Current official Supabase documentation confirms the provider-level model:
a conventional sign-in yields AAL1, TOTP enrollment starts from an authenticated
session, and the enrollment/challenge/verification sequence can upgrade a
session to AAL2. It also describes factor listing, session refresh, and logout.
The exact SDK release, method signatures, result fields, and project
configuration are intentionally not pinned here.

## Decision

1. The future client communicates directly with Supabase Auth using the
   publishable key for sign-up, email-confirmation continuation, password
   sign-in, factor listing, TOTP enrollment, challenge, verification, refresh,
   and logout.
2. Fastify exposes no registration, password, sign-in, sign-out, TOTP,
   factor-management, or public recovery endpoint. It receives only a
   subsequently issued access token on a Coditza domain request.
3. The client treats only verified AAL2 as authorization to begin Coditza
   domain API calls. A profile created at AAL1, a session, a visible QR code,
   a listed factor, or a claimed frontend success never grants domain access.
4. Authenticator-app TOTP is mandatory. Phone and other factor choices are not
   a Coditza fallback. The local/provider configuration task must explicitly
   prove the approved factor configuration.
5. Passwords, TOTP codes, QR SVG, manual secret, otpauth URI, refresh token,
   full provider response, and factor/challenge identifiers are transient
   sensitive data. They never enter Fastify, Coditza tables, logs, telemetry,
   screenshots, fixtures, reports, Python/WASM, or the grader controller.
6. The client re-reads assurance after every enrollment verification, login
   challenge verification, factor removal, session refresh, or provider error.
   Unknown, null, contradictory, or stale assurance state fails closed.
7. SUP-MFA-001, after FOUND-001 selects the actual SDK/toolchain, exclusively
   maps these abstract operations to pinned SDK calls and proves the signed
   JWT/amr behavior. This ADR does not assert an observed amr claim or select a
   frontend framework.

## Resulting policy

A direct Supabase Auth client can show a provider-neutral state machine before
the user reaches Coditza. Once it holds an AAL2 access token, it sends that
token in the normal Authorization bearer header. Fastify later verifies it
cryptographically, requires AAL2 before profile lookup, and independently
enforces current role/security-hold policy. The client never sends a score,
factor type assertion, session state, or user identity as authority.

A standard login is not complete at password success. The direct provider flow
must reach the state documented in the companion client contract before any
domain endpoint is attempted.

## DEC-029 production boundary

DEC-029 is explicitly unresolved for production. There is no public
lost-all-factors reset, recovery code assumption, or Fastify workaround.
The planned identity operator flow remains the only future recovery direction:
set a live Coditza hold, revoke/delete provider factors/sessions, wait the
measured residual-token quarantine, repeat provider cleanup, require fresh
verified TOTP, and clear the hold last.

Therefore local review and later synthetic local MFA proof may proceed, but
production self-service signup remains blocked until the identity-proof,
first-factor-compromise, audit, notification, operator-approval, and runbook
details are accepted.

## Consequences

- A later frontend must implement the documented provider-neutral interface
  without adding a new authentication backend.
- A later Supabase task must prove actual TOTP configuration and factor behavior
  using synthetic local users only.
- A later Fastify task must reject AAL1 before any profile/database/use-case
  access.
- The direct client must not expose account existence through error text.
- No SDK package/version, UI framework, hosted origin, redirect URL, email
  delivery path, or provider project setting is selected by this ADR.

## Sources reviewed on 2026-07-27

- [Supabase TOTP MFA guide](https://supabase.com/docs/guides/auth/auth-mfa/totp)
- [Supabase AAL reference](https://supabase.com/docs/reference/javascript/auth-mfa-getauthenticatorassurancelevel)
- [Supabase sign-up reference](https://supabase.com/docs/reference/javascript/auth-signup)
- [Supabase password sign-in reference](https://supabase.com/docs/reference/javascript/auth-signinwithpassword)
- [Supabase MFA overview](https://supabase.com/docs/guides/auth/auth-mfa)
- [Supabase refresh-session reference](https://supabase.com/docs/reference/javascript/auth-refreshsession)
- [Supabase sign-out reference](https://supabase.com/docs/reference/javascript/auth-signout)
