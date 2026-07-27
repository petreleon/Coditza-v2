# Authentication and authorization

## Authentication contract

For protected routes:

1. Require exactly `Authorization: Bearer <token>`.
   Reject an empty token or header over 8 KiB before verification.
2. Reject missing, malformed, expired, wrong-issuer, or wrong-project tokens.
3. Verify cryptographically with current Supabase `getClaims`/JWKS guidance;
   never authorize from decoded-but-unverified claims.
4. Validate issuer/project, subject, expiration, and Supabase audience/platform
   role according to current official guidance. The JWT `role` is a Supabase
   platform role, not a Coditza role.
   Require UUID `sub`, exact configured `iss`/`aud`, future `exp`, and a
   satisfied `nbf` when present; require UUID `session_id` and do not add a
   custom expired-token grace period.
5. Interpret a missing `aal` as `aal1`. Reject missing/unknown/`aal1` with
   `403 mfa_required`; require exact `aal2` before profile lookup or any domain
   use case.
6. If the pinned, verified Supabase JWT contract reliably emits a signed TOTP
   method in `amr`, require it. If it does not, follow the accepted ADR:
   TOTP-only project configuration plus genuine Supabase Auth flow establishes
   the mechanism, while exact signed `aal2` is the server authorization signal.
   Never trust client-supplied factor type or unsigned assurance state.
7. Pass the verified subject to the identity module's narrow Supabase adapter,
   which selects only `id, role, security_hold_at` from `public.profiles`.
8. Reject missing profile, unknown Coditza role, or an active security hold.
   The hold check is live on every domain request and returns the stable safe
   `403 access_suspended` problem before a business use case.
9. Attach only:

```text
userId
role
aal = "aal2"
sessionId
```

10. Discard the raw token reference after verification; route/application code
    never receives it.
11. Never use email, display name, JWT platform role, or user-editable metadata
   as Coditza authorization.

## FAST-AUTH-001 — Decorators

- [ ] `authenticate` establishes the verified identity.
- [ ] `requireRole(role)` checks one exact role.
- [ ] `requireAnyRole(roles)` checks an explicit set.
- [ ] Decorators throw typed application errors rather than sending replies.
- [ ] Public health routes register outside protected encapsulation.
- [ ] All `/api/v1` Coditza domain routes require authentication by default.
- [ ] Every admin route explicitly requires editor/admin or admin.

## FAST-MFA-001 — Require exact AAL2

Prerequisites: FAST-AUTH-001, SUP-MFA-001 and the verified-claims adapter.

- [ ] Add a typed `requireAal2` pre-handler after cryptographic verification and
      before profile/role/database access.
- [ ] Return `401` for missing/invalid/expired/wrong-project tokens and
      `403 mfa_required` for an otherwise valid token below `aal2`.
- [ ] Treat missing AAL as `aal1`; fail closed for unknown values.
- [ ] Implement the accepted signed-`amr` TOTP rule when the pinned provider
      reliably emits it; otherwise enforce the documented TOTP-only
      configuration/AAL2 contract without inventing or trusting a client claim.
- [ ] Require a valid UUID `session_id` and expose only the constant
      `aal: "aal2"` plus `sessionId` in `VerifiedPrincipal`.
- [ ] Register every `/api/v1` domain adapter behind the AAL2 boundary; only
      liveness/readiness remain outside as already specified.
- [ ] Ensure role checks run after AAL2 and cannot turn `aal1` into a learner.
- [ ] Document that Fastify checks the current JWT, not `nextLevel` or live
      factor state, and that an already issued token can remain valid until
      `exp`.
- [ ] Test that an AAL failure performs no profile-adapter/outbound-port/use-case
      call.
- [ ] Keep passwords, TOTP material, factor/challenge bodies and refresh tokens
      absent from Fastify schemas, OpenAPI, logs and error details.

## FAST-AUTH-002 — Role freshness and isolation

- [ ] Read the current database role on each request in MVP; do not depend on
      stale JWT role metadata.
- [ ] Read and enforce `security_hold_at` in the same identity projection on
      every request; do not cache it. Prove an already issued genuine AAL2 token
      is denied on its next request after the hold is set.
- [ ] If a short role cache is later added, document revocation latency and add
      explicit invalidation before enabling it.
- [ ] Raw secret client stays inside the composition root/adapter factories;
      outbound adapters receive verified actor context separately.
- [ ] Every server-only workflow function receives actor ID from Fastify, reloads
      that actor's current Coditza role/ownership, and rejects inconsistency.
- [ ] No singleton stores current user data.

## Required tests

- absent header;
- wrong auth scheme;
- multiple/malformed values;
- expired token;
- valid `aal1`, missing/unknown AAL, and invalid/missing `session_id`;
- valid `aal2` after a successful TOTP challenge;
- token from another Supabase project;
- invalid signature;
- valid token with no profile;
- valid AAL2 token before/after setting and clearing an identity security hold;
- learner/editor/admin branches;
- changed role effective on next request;
- two simultaneous users remain isolated;
- authorization and token fields absent from logs/errors.

## Auth routes

Fastify does not proxy sign-up, confirmation, sign-in, MFA
enroll/list/challenge/verify/unenroll, refresh, logout, or password reset. Those
are direct Supabase Auth client operations governed by
[`PRD-AUTH-001`](../01-product/04-authentication-and-mfa.md). Fastify exposes
only `aal2`-authenticated profile/domain behavior.
