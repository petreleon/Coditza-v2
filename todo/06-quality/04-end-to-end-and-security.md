# End-to-end backend and security tests

Run against the Compose API connected to a freshly reset local Supabase stack.

## QA-E2E-001 — Learner happy path

1. Register/confirm a learner, enroll/verify TOTP and obtain genuine `aal2`.
2. List modules and open a chapter.
3. Read and complete all theory sections.
4. Submit one wrong and one correct exercise attempt.
5. Submit one failing and one passing `python_code` job, poll the authoritative
   result, and prove provisional/forged client success cannot change it.
6. Start quiz, save answers, reload attempt, and submit.
7. Verify permitted feedback and no answer keys/hidden Python tests.
8. Verify chapter/module progress counts and completion.

## QA-E2E-002 — Content authoring path

1. Editor completes a genuine password+TOTP login and creates
   module/chapter/theory/exercise/quiz drafts.
2. Invalid assessment publish fails atomically.
3. Editor fixes definition through protected authoring route.
4. Publish children/chapter/module in valid order.
5. Learner sees content in deterministic order.
6. Editor mutation of the published assessment fails before any attempt.
7. Learner attempts assessment and the same mutation still fails.
8. Editor clones/archives/replaces it; old result remains readable.

## QA-E2E-003 — Role path

1. Bootstrap the first local admin and enroll/verify its TOTP factor.
2. Admin grants editor with reason.
3. Editor authoring succeeds and role mutation fails.
4. Admin attempts final-admin removal and is denied.
5. Audit records safe before/after facts and request IDs.

## Security abuse cases

- invalid/wrong-project/expired JWT;
- forged `aal2`, valid `aal1`, missing/unknown AAL and invalid `session_id`;
- wrong/malformed/out-of-window TOTP, abandoned enrollment, multiple-factor
  selection, and provider rate limiting;
- cross-user IDs on attempts/progress;
- draft ID guessing;
- option/question ID from another assessment;
- client-supplied score/pass/user/role fields;
- oversized Markdown/answers/arrays;
- injection-shaped strings;
- duplicate/concurrent starts/submits;
- rate-limit exhaustion;
- wildcard/unapproved CORS origin;
- answer-key field probing;
- secret/log/OpenAPI/container-layer scan.
- Python sandbox escape/network/filesystem/secret/resource exhaustion, forged
  browser report, hidden-test oracle, lease/crash/retry, and runtime-digest
  mismatch.
- QR SVG, `otpauth`, TOTP seed/code, refresh-token, factor/challenge and Auth
  request/response artifact scan.

## QA-MFA-001 — Registration and later-login assurance

Prerequisites: SUP-MFA-001, SUP-AUTH-003, FAST-MFA-001 and API-CATALOG-001.

- [ ] Sign up one synthetic user, handle the configured email-confirmation
      state, and prove its profile alone does not grant access.
- [ ] With a genuine password-only `aal1` token, call `/me` and one catalog
      route; both return `403 mfa_required` before profile/use-case execution.
- [ ] Enroll one TOTP factor, challenge/verify with an in-memory test
      Authenticator, refresh, and prove exact `aal2` succeeds.
- [ ] Create a new password login session; prove it starts below `aal2`, requires
      a fresh challenge, then succeeds with the new `aal2` token.
- [ ] Prove ordinary refresh of that same `aal2` session follows DEC-031 without
      an extra challenge.
- [ ] Exercise two verified factors and select the requested factor rather than
      assuming array index zero.
- [ ] Prove password reset/email possession does not bypass the TOTP step.
- [ ] Prove factor replacement verifies the new factor before old-factor
      removal; after removal, refresh and measure/document any bounded stale JWT
      window instead of claiming instant revocation.
- [ ] Set the operator security hold for the synthetic user and prove its
      already issued AAL2 token receives `403 access_suspended` on the next
      request; try to create a factor during the residual-token quarantine,
      prove `prepare-enrollment` removes/refuses it, then exercise the second
      revocation/deletion, fresh TOTP verification, and hold clearing in the
      approved order.
- [ ] Forge/alter AAL in a token and prove signature verification rejects it;
      test missing/unknown AAL and invalid session ID separately.
- [ ] Exercise the accepted TOTP-mechanism proof: when signed `amr` is stable,
      require its pinned TOTP method and reject a verified token without it;
      otherwise prove other MFA methods are disabled and retain the ADR plus
      genuine TOTP-flow evidence.
- [ ] Prove direct Data API access remains denied with both genuine AAL levels.
- [ ] Scan source, database, OpenAPI, logs, reports and test artifacts for every
      TOTP/Auth sensitive form; retain only sanitized state names/outcomes.

## QA-SEC-001 — Sign-off

- [ ] Every abuse case fails with the intended safe code.
- [ ] Logs contain request correlation but no token/key/answer/free text.
- [ ] Direct Data API and Fastify checks agree.
- [ ] Dependency and container scans are reviewed.
- [ ] No high/critical unresolved finding.
- [ ] Mandatory MFA, module-boundary, downgrade and factor-loss threat findings
      are resolved or keep the gate closed.
- [ ] A failed security check blocks deployment; do not weaken it for the gate.
