# PRD-AUTH-001 — Freeze the mandatory TOTP client contract

Outcome: COMPLETE
Environment: REVIEW / LOCAL DOCUMENTATION
Date: 2026-07-27
Agent/person: Codex
Authorization checked: Implementation is authorized. This review task creates
only local architecture/product-contract documentation and makes no provider,
browser, credential, or hosted-state change.
Prerequisites/gate checked: ARC-DESIGN-001 and G0 are complete; PRD-AUTH-001
was the sole next task before this work began.
Decisions/defaults used:

- Email/password is factor one; Authenticator-app TOTP is mandatory factor two
  for all Coditza roles.
- Supabase Auth remains the direct identity provider. Fastify has no credential,
  MFA, factor, logout, or public recovery proxy route.
- A client may attempt a domain call only after a fresh provider AAL2/AAL2
  observation; later Fastify independently verifies the submitted token and
  requires AAL2 before profile access.
- Provider operation names/results are expressed as stable abstract operations.
  No SDK package, version, exact signature, JWT sample, or observed amr value
  is pinned here.
- DEC-029 remains explicitly production-blocking. There is no public
  lost-all-factors reset or invented recovery-code behavior.

## Scope

- Intended: record an Auth/MFA ADR; a provider-neutral signup, confirmation,
  enrollment, challenge, verification, refresh, logout, and factor-listing
  contract; state/error/threat/fixture rules; AAL2 handoff; conditional
  assurance; frontend acceptance; and the DEC-029 production block.
- Explicitly excluded: frontend code, SDK installation/version selection,
  Fastify endpoint, Supabase configuration, Chrome, local synthetic user,
  credential, email delivery, Docker, migration, deployment, and external
  state.

## Changed

- docs/adr/0002-mandatory-totp-direct-supabase-auth.md: accepted direct
  provider/MFA decision, current official source review, and production
  recovery boundary.
- docs/implementation/auth-mfa-client-contract.md: provider-neutral operation,
  state, error, transient-sensitive-data, AAL2-handoff, conditional assurance,
  factor lifecycle, threat, and credential-free fixture contract.
- docs/implementation/PRD-AUTH-001.md: this task report.
- todo/01-product/04-authentication-and-mfa.md, todo/TASKS.md,
  todo/STATUS.md, todo/NEXT.md, todo/README.md,
  todo/00-control/00-scope-and-non-goals.md, and
  todo/08-execution/00-roadmap.md: completion and next-task state.

## Verification

- Current official Supabase documentation review
  - Result: PASS
  - Non-secret evidence: current official documentation describes the
    enrollment/challenge/verification sequence, factor listing, AAL
    current/next levels, password sign-in, registration, refresh, and logout.
    The task recorded provider semantics only and deliberately deferred the
    actual SDK mapping to SUP-MFA-001.
- Contract completeness review against PRD-AUTH-001
  - Result: PASS
  - Non-secret evidence: every required abstract operation, safe error category,
    stable state, unverified-factor resume rule, verified-factor selection,
    AAL2 handoff, conditional amr rule, no-UI boundary, and credential-free
    fixture is explicit.
- DEC-029 review
  - Result: PASS
  - Non-secret evidence: local planning may proceed, but production
    self-service signup is visibly blocked until the required operator
    recovery decision/runbook evidence is accepted.
- Documentation link, sensitive-marker, source-tree, and whitespace checks
  - Result: PASS
  - Non-secret evidence: documentation has no credential/token/QR/URI samples,
    no application source or dependency was added, and no whitespace error
    exists.

## External actions

NONE. Official documentation was read only. No Chrome, Supabase project,
provider setting, email, credential, Vercel project, or deployment was accessed
or changed.

## Deviations/ADRs

- ADR 0002 records the direct-to-Supabase Auth and mandatory-TOTP decision.
- The product contract's provider-neutral wording is preserved. Current
  documentation was used only to validate operation categories, not to claim a
  selected SDK mapping or observed signed JWT/amr detail.

## Risks/blockers

- SUP-MFA-001 must map this contract to the exact version selected by FOUND-001,
  prove local configuration and genuine AAL transitions, inspect signed amr,
  and resolve/record unverified-enrollment behavior.
- DEC-029 blocks production self-service signup until its recovery proof/runbook
  is accepted. DEC-025 and DEC-026 separately block hosted self-service email
  sign-off.
- No frontend is selected or implemented.

## Secret-safety confirmation

No credential, token, connection string, email address, password, TOTP code,
factor/challenge ID, QR SVG, manual secret, otpauth URI, refresh token, or raw
provider response was recorded.

## Next

PRD-WASM-001 is the only unblocked next task. It may freeze Python source
package, verdict, deterministic-fixture, and Auth/TOTP-exclusion semantics with
credential-free golden vectors, but it may not select a runtime/launcher,
create source/dependencies, or change external state.
