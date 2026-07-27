# Provider-neutral mandatory TOTP client contract

Status: accepted by PRD-AUTH-001 on 2026-07-27.

This is a contract for a future client. There is no frontend, SDK package,
framework, endpoint, test user, or provider configuration in this repository
task. The contract describes behavior against Supabase Auth without freezing a
version-specific call signature.

## Authority and trust boundary

Supabase Auth is the only authority for email/password, email confirmation,
sessions, refresh, TOTP enrollment, factor state, challenges, verification, and
issued access tokens. The client communicates with it using a publishable key.

Fastify is not an Auth proxy. It has no route for registration, confirmation,
password sign-in, TOTP enrollment/challenge/verification, factor management,
logout, or recovery. The client may call a Coditza domain endpoint only after it
has re-read direct provider assurance as AAL2. Later Fastify independently
verifies the submitted token and rejects anything below AAL2 before profile
lookup.

The client must not treat a profile, a current session, a factor list, a QR
code, a frontend boolean, a decoded unverified JWT, or a browser assertion as
proof that Coditza access is permitted.

## Provider-neutral operation surface

| Abstract operation | Input/allowed output | Required behavior |
| --- | --- | --- |
| startRegistration | email/password and an approved redirect intent; safe registration outcome | Ask Supabase Auth to create the identity. Return only whether confirmation is pending, an AAL1 session can continue, or a safe generic failure occurred. |
| continueAfterConfirmation | no credential supplied to Coditza | Observe the provider's confirmed-session outcome or require a normal password sign-in. Never infer confirmation from an email address or a client callback alone. |
| signInWithPassword | email/password; AAL1-or-safe-failure outcome | Start a new provider session, then immediately reload assurance. Map wrong credentials, unknown account, and unsupported account mode to the same safe visible category. |
| readAssurance | current direct-provider session; current/next assurance or safe failure | Read current and next assurance before selecting every client state and after every relevant Auth action. |
| listTotpFactors | current provider session; transient TOTP descriptors | Return only factor handles/statuses needed to choose a verified TOTP factor or resume one enrollment. Never persist or log factor objects. |
| beginTotpEnrollment | current AAL1 session; transient enrollment display material and factor handle | Start exactly one user-initiated TOTP enrollment. QR/manual secret is shown only in the active enrollment view and is retained only in memory. |
| requestTotpChallenge | selected in-memory factor handle; transient challenge handle or safe failure | Start a challenge only after an explicit user action. It never runs from rendering, polling, or automatic retry. |
| verifyTotpCode | selected factor/challenge handles and one six-ASCII-digit user input; safe success/failure | Ask the provider to verify, clear the typed code promptly, then reload assurance. A provider success is insufficient until AAL2 is observed. |
| refreshCurrentSession | current provider session; refreshed/expired/safe-failure outcome | Refresh only through the provider, discard stale client state, then re-read assurance. |
| logout | explicit requested scope; completed/safe-failure outcome | Invoke provider logout with an explicit scope selected by the future client contract; do not rely on a provider default that could log out unrelated sessions. Exact SDK mapping is deferred. |
| requestFactorRemoval | verified AAL2 session and selected verified factor handle | Future client behavior only: never offer removal of the final verified factor, immediately refresh/re-read assurance after a successful removal, and route any downgrade to enrollment. Exact provider mapping is deferred. |

No operation returns provider credentials, QR content, manual secret, refresh
token, raw factor record, raw challenge record, or raw provider error to
application state beyond its immediate sensitive boundary.

## Stable client states

| State | Required provider evidence | Permitted action | Coditza domain API |
| --- | --- | --- | --- |
| signed_out | No usable direct-provider session. | Start registration or password sign-in. | Denied. |
| email_confirmation_pending | Identity exists but no usable AAL1 session. | Explain that confirmation is pending; continue only after a real provider session exists. | Denied. |
| mfa_enrollment_required | Current AAL1 and next AAL1. | Inspect factors; start or safely resume the mandatory TOTP enrollment path. | Denied. |
| mfa_challenge_required | Current AAL1 and next AAL2. | Select one verified TOTP factor, request a challenge, and verify one code. | Denied. |
| authenticated | Current AAL2 and next AAL2, after the latest assurance read. | Make a Coditza domain request with the provider-issued token. | Eligible; Fastify still verifies independently. |
| stale_after_factor_change | Current AAL2 and next AAL1. | Refresh immediately, discard access state, then route to enrollment or challenge from fresh evidence. | Denied by client. |
| auth_state_unknown | Null, unknown, contradictory, expired, or provider-error assurance evidence. | Clear sensitive transient state and recover through a fresh safe provider action. | Denied. |

An active enrollment view is a local, non-authoritative substate of
mfa_enrollment_required. It must keep only the current enrollment handle and
display material in memory, never automatically create another enrollment, and
clear that material on cancellation, completion, replacement, reload, or error.

## Registration and later-login transitions

### Registration

1. The client starts email/password registration through Supabase Auth.
2. If email confirmation is required and no usable session exists, it enters
   email_confirmation_pending and makes no Coditza domain request.
3. Once it has a real AAL1 session, it reads assurance and factors.
4. If no verified TOTP factor exists, it enters mfa_enrollment_required.
5. A user explicitly begins enrollment, scans the temporary QR or enters the
   temporary manual secret into an Authenticator app, then explicitly submits
   a TOTP code.
6. The client challenges and verifies through the provider, clears temporary
   code/display material, and re-reads assurance.
7. It enters authenticated only on fresh AAL2/AAL2 evidence. Any other outcome
   fails closed.

### Later password login

1. The client starts password sign-in through Supabase Auth and obtains at most
   an AAL1 session.
2. It reads assurance before showing application content.
3. AAL1/AAL2 enters mfa_challenge_required. The client lists and displays only
   verified TOTP factors, lets the user select one when there are several, then
   performs one explicit challenge/verification path.
4. AAL1/AAL1 enters mfa_enrollment_required, not Coditza.
5. AAL2/AAL2 enters authenticated.
6. AAL2/AAL1 enters stale_after_factor_change and is refreshed before any
   domain request.
7. Every unknown or failed result enters auth_state_unknown or signed_out, never
   the application.

The client must not automatically retry a failed code verification, create a
new challenge on every render, or silently fall back to password-only access.
Provider rate limiting and transient service errors remain a safe retry-later
experience with no AAL1 bypass.

## Enrollment resume and factor selection

At entry, reload, and post-error the client lists factors before it creates a
new enrollment:

1. If one or two verified TOTP factors exist, it selects only from those
   verified factors for a login challenge. It does not create a replacement
   factor merely because a view re-rendered.
2. If no verified factor exists but an unverified enrollment is visible, the
   client preserves only its current in-memory enrollment handle for a user-
   initiated resume. It does not synthesize a second enrollment.
3. If the page was reloaded or the handle is unavailable, exact
   provider-specific unverified-factor cleanup/resume behavior is deferred to
   SUP-MFA-001. Until it is proven, the safe client behavior is to show a
   recoverable setup state and avoid creating another factor automatically.
4. Coditza permits at most two verified TOTP factors. A replacement must be
   verified before removal of the old factor; removal of the final verified
   factor is never offered.
5. Factor handles and friendly labels are transient UI data. They must not
   appear in telemetry, errors, screenshots, test fixtures, Fastify requests,
   or database rows.

## Safe result and error model

The future provider adapter maps raw results to these stable categories:

| Category | User-visible treatment | Prohibited disclosure |
| --- | --- | --- |
| registration_submitted | Confirmation-pending or continue-with-AAL1 instruction. | Whether a different person already owns an email. |
| invalid_credentials_or_account_mode | One generic sign-in failure. | Account existence, password validity, social/provider linkage. |
| confirmation_required | Generic confirmation instruction. | Token/session body or account enumeration. |
| mfa_setup_required | Mandatory enrollment instruction. | QR/manual secret in an error body. |
| mfa_code_rejected | Stay on the challenge with bounded manual retry. | Raw provider diagnostic, factor details, timing window. |
| mfa_rate_limited | Retry later; do not start a bypass or automatic retry loop. | Raw rate-limit internals. |
| factor_unavailable | Ask for another verified factor or the approved recovery path. | Unverified factor details or other-user data. |
| session_expired_or_revoked | Clear transient state and sign in again. | Token or session material. |
| auth_service_unavailable | Generic retry-later outcome. | Provider error body or infrastructure detail. |
| unexpected_auth_state | Fail closed and offer a safe restart. | Parsed token claims or factor/challenge bodies. |

The client logs only category, non-sensitive correlation data, and coarse
transition state when approved. It never logs raw provider error text,
credential material, email addresses, code values, QR data, URI, factor/challenge
objects, access tokens, refresh tokens, or complete session responses.

## AAL2 handoff to Fastify

A Coditza domain request may be attempted only after the most recent
readAssurance result is AAL2/AAL2 and the client has the resulting current
provider-issued access token. The client sends that token only in the standard
Authorization bearer header. It never sends password, TOTP code, factor handle,
challenge handle, next assurance level, QR/manual secret, refresh token, user
ID, role, or client-computed assurance to Fastify.

The later Fastify boundary is authoritative for the request: it cryptographically
checks the token, issuer, audience, expiry, session ID, exact AAL2, current
profile role, and security hold. The client AAL check prevents an accidental
domain call; it never replaces server authorization.

## Conditional TOTP assurance rule

SUP-MFA-001 must inspect genuine signed access tokens from the SDK version and
local configuration selected by FOUND-001. If the verified contract reliably
contains a signed amr method that identifies TOTP, Fastify requires that method
as well as AAL2. If it does not reliably contain that evidence, Fastify uses
the reviewed TOTP-only project configuration plus the genuine enrollment/login
flow and exact signed AAL2 as the enforceable policy.

This contract records no observed amr value, no JWT sample, and no SDK-specific
claim mapping. An unsigned browser assertion, factor list, or frontend state
never satisfies the conditional rule.

## Recovery and production block

Loss of all factors has no public self-service reset or invented recovery-code
path. The user is encouraged to retain a second verified Authenticator factor.
Any recovery is the isolated identity operator process in ADR 0002 and remains
blocked by DEC-029 until identity proof, first-factor compromise handling,
operator approval, audit, notification, quarantine duration, and runbook
evidence are accepted.

Production self-service signup is additionally blocked until the separately
named email delivery, redirect-origin, and hosted Auth decisions are resolved.
This client contract does not change those decisions.

## Threat review

| Threat | Required control |
| --- | --- |
| Password-only session enters Coditza | Client denies domain calls before fresh AAL2 and Fastify later rejects AAL1 before profile lookup. |
| Credential/TOTP material reaches Fastify or Python | Direct provider client only; no Auth proxy; explicit sensitive-material exclusions. |
| Account enumeration | Generic registration/sign-in error categories and no raw provider message. |
| Factor accumulation after render/reload | Factor list before enrollment; explicit user initiation; one in-memory enrollment; no automatic creation. |
| Unverified factor used at login | Only verified TOTP factors are selectable for a challenge. |
| A stale AAL2 session persists after factor change | Re-read/refresh and fail closed on AAL2/AAL1; Fastify independently checks each request. |
| Client lies about MFA | Server trusts only its cryptographic token verification and conditional signed claim evidence. |
| Lost-factor bypass | No public recovery route or invented recovery codes; DEC-029 remains production-blocking. |
| Provider outage/rate limit bypasses MFA | Safe retry-later state; no automatic retry loop or AAL1 fallback. |

## Contract fixtures without credentials

Future tests may use a deterministic fake provider that emits only abstract
result categories and no real Auth material. The following fixtures must exist
before a client is accepted:

| Fixture | Input state/event | Expected state | Domain request permitted |
| --- | --- | --- | --- |
| registration confirmation | registration_submitted with no session | email_confirmation_pending | no |
| new enrollment | fresh AAL1/AAL1 with no verified factor | mfa_enrollment_required | no |
| verified login factor | fresh AAL1/AAL2 plus verified factor | mfa_challenge_required | no |
| successful verification | provider success then fresh AAL2/AAL2 | authenticated | yes |
| rejected code | mfa_code_rejected | mfa_challenge_required | no |
| stale token | observed AAL2/AAL1 | stale_after_factor_change | no |
| unknown assurance | null/contradictory assurance | auth_state_unknown | no |
| lost all factors | no verified factor after refresh | mfa_enrollment_required or approved operator path | no |
| provider outage | auth_service_unavailable | auth_state_unknown | no |

Fixtures contain no email address, password, token, factor ID, challenge ID,
TOTP code, QR material, manual secret, URI, or provider response body.

## Later frontend acceptance requirements

No frontend framework is selected or implemented here. When a future client is
approved, it must:

- use this provider-neutral state and error contract;
- implement all direct Supabase Auth actions without a Fastify credential proxy;
- keep sensitive enrollment and session material out of persistence, telemetry,
  screenshots, crash reports, and test artifacts;
- block all Coditza domain API calls outside authenticated;
- render a verified-factor selector when multiple verified factors exist;
- avoid unverified-factor accumulation and final-factor removal;
- demonstrate registration, confirmation, enrollment, later login, downgrade,
  rate-limit, and safe-error fixtures without real credentials; and
- prove the future API client sends only the current AAL2 bearer token to
  Fastify.

## Deliberately deferred to SUP-MFA-001

- exact SDK package and version;
- exact SDK method names, parameters, return fields, and error codes;
- local Supabase config keys and TOTP enablement;
- real local synthetic-user enroll/list/challenge/verify behavior;
- signed JWT/amr observation and the final conditional server rule;
- factor cleanup/resume details after reload;
- provider rate-limit/replay/window observations; and
- any actual client or UI implementation.
