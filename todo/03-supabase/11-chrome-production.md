# Production Supabase project in Chrome

Production is a separate, user-approved external action. Completing development
or optional staging never authorizes this file.

## SUP-CHROME-PROD-001 — Create and verify production

Prerequisites: G7 passes; DEC-017/018/019/020/025/026/029/030/031 are resolved
for the intended release mode; exact owner, budget, region, tier, recovery
capability, MFA recovery runbook, client URLs, and email ownership are
documented; the user explicitly approves creation of `Coditza-prod`.

- [ ] State the exact organization, environment, project name, region, tier,
      expected cost, and action before opening the creation control.
- [ ] Stop for login, CAPTCHA, 2FA, payment, or secret entry and let the user
      complete it.
- [ ] Create exactly `Coditza-prod`; do not clone development/staging data or
      credentials.
- [ ] Have the user place generated keys in an approved password-manager/
      bootstrap store without exposing them in chat, screenshots, logs, or
      tracked files. ARC-ENV-PROD-001 later creates the protected host scopes and
      performs the direct user-controlled transfer.
- [ ] Configure only the approved Auth methods, exact Site/redirect URLs,
      confirmed-email behavior, and verified production email delivery.
- [ ] Enable TOTP enrollment/verification for every role, disable other MFA
      methods, and verify the approved factor maximum, JWT/session lifetime,
      challenge/verify rate limits, and factor-change security notifications.
- [ ] If DEC-025 or DEC-026 deliberately selects API-only preview, keep
      self-service signup disabled and record that release limitation.
- [ ] Confirm backup/PITR capability matches the accepted objective before data
      admission.
- [ ] Confirm Dashboard schema authoring remains untouched and no demo seed or
      non-production data has been copied.
- [ ] Record only non-secret project/Auth/recovery metadata, approver, time, and
      healthy project state.
- [ ] Do not capture QR/`otpauth`, factor/challenge IDs, TOTP codes/secrets,
      credentials, tokens, emails, or Auth request/response bodies in evidence.

This task does not bind release credentials, apply migrations, deploy an image,
enable jobs/alerts, or admit traffic. Those actions belong, in order, to
ARC-ENV-PROD-001, OPS-DEPLOY-002, OPS-OBS-PROD-001,
OPS-MAINT-PROD-001, OPS-REC-PROD-001, and OPS-RELEASE-PROD-001.

Stop immediately if the target is ambiguous, hosted state drifts from committed
migrations, a secret would enter evidence, or any requested production action
falls outside the recorded approval. Drift is reported; it is never repaired in
Chrome.
