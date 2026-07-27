# Chrome workflow for hosted Supabase

Status: future execution only. Keep every checkbox unchecked during plan
creation.

## Operating rules

- Use Chrome and the existing user-approved Supabase session.
- Let the user handle login, CAPTCHA, 2FA, password-manager, payment, and secret
  entry when those controls appear.
- Before every save, verify organization, project name, project reference, and
  intended environment.
- Never read aloud, transcribe, screenshot, log, or commit passwords, tokens,
  secret keys, recovery codes, or connection strings.
- Stop before a paid selection, billing change, production project creation,
  destructive action, project pause/delete, or key rotation until the user
  explicitly approves the exact action.
- If the Dashboard labels differ from this plan, consult current official
  Supabase documentation instead of guessing.
- Chrome configures hosted project settings and verifies state. Tables,
  functions, grants, and RLS are created by committed migrations.
- Synthetic hosted users/data use an obvious run namespace such as
  `coditza-e2e-<UTC-date>-<run-id>` in safe metadata. Record creator, purpose,
  environment, and expiry without recording credentials.
- Cleanup is a separate scoped action: list exact synthetic targets, verify no
  real-user dependency, obtain approval for external deletion, then record what
  was removed. If deletion is not approved, document retention/expiry instead.

## SUP-CHROME-001 — Create the development project

Prerequisites: local schema foundation passes G2; DEC-018 region/tier is
confirmed.

- [ ] Open the official Supabase Dashboard in Chrome.
- [ ] Confirm the intended organization and billing owner.
- [ ] Select **New project**.
- [ ] Use the exact name `Coditza-dev`.
- [ ] Have the user generate and store the database password in an approved
      password manager without exposing it to the agent.
- [ ] Select the user-approved region nearest the intended API/users.
- [ ] Confirm the tier and any cost before final creation.
- [ ] Create the project and wait for healthy status.
- [ ] Record only project name, reference, region, tier, and timestamp.
- [ ] In the current API Keys/Connect area, have the user transfer the
      publishable and secret keys directly to approved local/deployment secret
      storage. Do not put values in chat or documentation.
- [ ] Confirm the implementation uses current key formats, not newly copied
      legacy keys.

Evidence: non-secret project metadata and a sanitized healthy-status record.

## SUP-CHROME-002 — Configure development Auth and TOTP safely

Prerequisites: development project exists; DEC-004/005/028/030/031 accepted.

- [ ] Enable email/password only.
- [ ] Keep social providers, anonymous sign-in, phone sign-in, and manual account
      linking disabled unless a later decision explicitly adds them.
- [ ] Enable Authenticator-app TOTP enrollment and verification; keep phone and
      every other second-factor method disabled.
- [ ] Set/verify the approved maximum of two enrolled TOTP factors where the
      current project setting supports it; otherwise record the limitation and
      keep client enforcement/test coverage.
- [ ] Require confirmed email for any non-local real-user flow.
- [ ] If DEC-025 is unresolved, keep self-service email flows out of scope,
      create only explicitly authorized synthetic users, and mark hosted Auth
      readiness incomplete.
- [ ] Once DEC-025 is resolved, configure the exact development Site URL and
      redirect allowlist; use no broad wildcards.
- [ ] Review password, access-token/session, abuse/rate-limit, MFA
      challenge/verify, and email settings against current official guidance;
      record the actual access-token lifetime and its stale-token window.
- [ ] Enable factor-enrolled/factor-removed security notifications only when the
      development email path is verified.
- [ ] Prefer current asymmetric JWT signing keys when supported.
- [ ] Verify the project's JWT issuer value and record only the non-secret
      issuer URL.
- [ ] Reload the settings page and confirm saved non-secret values.
- [ ] Record only boolean/magnitude settings. Never screenshot or record a QR
      code, `otpauth` URI, factor ID, secret, TOTP code, token, email, or Auth
      request/response body.

## SUP-CHROME-003 — Verify the development release target

Prerequisites: SUP-CHROME-001/002 and ARC-ENV-003 are complete; the candidate
revision and image digest are known. This is a Chrome/configuration preflight,
not a migration or API deployment.

- [ ] Confirm Chrome shows the exact `Coditza-dev` organization, project name,
      project reference, region, and tier.
- [ ] Confirm the recorded HTTPS API URL and JWT issuer belong to that reference
      and match the protected development environment metadata.
- [ ] Reload Auth/API settings and record only the non-secret saved values and
      key types.
- [ ] Confirm TOTP enroll/verify remains enabled, other MFA methods remain
      disabled, and the factor/session/rate-limit settings match the approved
      development record.
- [ ] Confirm the exact reviewed migration revision, immutable image digest, and
      one-off release-job target that OPS-DEPLOY-DEV-001 will use.
- [ ] Inspect current schema/migration state read-only. If an unexpected remote
      schema object or migration exists, stop and reconcile it through a reviewed
      migration; do not pull, baseline, edit, reset, or push in this task.
- [ ] Record a sanitized target-preflight report and the approver/owner.

OPS-DEPLOY-DEV-001 is the sole owner of CLI linking, migration preview/apply,
image deployment, hosted denial/security tests, smoke tests, and migration/image
evidence for development.

Optional staging and production are deliberately separate tasks:
[staging](10-chrome-staging.md) and [production](11-chrome-production.md).

## Immediate stop conditions

- The project/environment is ambiguous.
- A region change is requested after creation.
- Chrome requests a purchase or elevated permission not already approved.
- A secret is visible in a proposed screenshot or record.
- The hosted schema differs from migrations.
- The next action affects production and the current task is not an approved
  production task.
