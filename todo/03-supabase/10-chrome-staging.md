# Optional staging Supabase project in Chrome

Staging is not assumed. If DEC-027 keeps its safe default, skip this task and
use hosted development with synthetic data as the pre-production environment.
Skipping is recorded as “not applicable by DEC-027,” not falsely completed.

## SUP-CHROME-STAGING-001 — Create and configure staging

Prerequisites: G6 passes; DEC-027 explicitly approves a separate environment;
DEC-018 region/tier/owner/cost is confirmed for this project; user authorizes
project creation.

- [ ] Open the official Supabase Dashboard in Chrome and verify organization.
- [ ] Stop for any unapproved purchase/billing change.
- [ ] Create exactly `Coditza-staging`; never rename/reuse development.
- [ ] Have the user place generated credentials directly in the staging secret
      bootstrap store; never copy development credentials or expose values.
- [ ] Configure Auth from resolved DEC-004/005/025/028/030/031: email/password
      first factor, confirmed email when applicable, TOTP enroll/verify enabled,
      other MFA disabled, approved factor maximum, session lifetime and current
      Auth/MFA rate limits. If email delivery is not ready, use approved
      synthetic users only.
- [ ] Verify one synthetic password → `aal1` → TOTP → `aal2` flow without
      recording credentials, QR/`otpauth`, factor/challenge IDs or Auth bodies.
- [ ] Record and verify the non-secret project reference, HTTPS API URL, JWT
      issuer, region/tier, key types, exact redirect settings, and owner.
- [ ] Confirm the Dashboard schema is untouched; do not apply migrations, create
      tables, deploy an API image, or run domain smoke/security tests in this
      task.
- [ ] Treat any cleanup/deletion as a separate explicitly approved action.

ARC-ENV-STAGING-001 binds protected credentials after this task.
OPS-DEPLOY-STAGING-001 alone applies migrations, deploys the digest, and runs
hosted tests. This task never creates, configures, or mutates production.
