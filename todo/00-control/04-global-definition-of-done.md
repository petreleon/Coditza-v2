# Global definition of done

## A single task is done only when

- [ ] Every prerequisite is complete.
- [ ] All listed behavior is implemented without unrelated scope.
- [ ] Every new public function, route, table, policy, and error code is tested at
      the appropriate layer.
- [ ] Formatting, lint, typecheck, and relevant tests pass.
- [ ] No secret, token, password, or personal data was added to source or logs.
- [ ] Documentation and generated contracts/types are updated.
- [ ] The task report contains reproducible evidence.
- [ ] The working tree contains no accidental generated files.
- [ ] The active task checkboxes are updated only after the evidence exists.

## The database is done only when

- [ ] A clean `supabase db reset` applies every migration and seed in order.
- [ ] RLS is enabled on every exposed table.
- [ ] Direct Data API tests prove `anon`/`authenticated` denial; Fastify and
      server-function tests separately cover learner/editor/admin,
      owner/non-owner capability.
- [ ] Foreign keys, checks, unique constraints, and indexes match the schema plan.
- [ ] Generated TypeScript database types match the reset database.
- [ ] No answer-key table is readable with a publishable key or user token.
- [ ] Remote Dashboard state matches committed migrations after deployment.

## The API is done only when

- [ ] Every route has request and response JSON Schemas.
- [ ] The OpenAPI document is generated and contains no secret/internal fields.
- [ ] Authentication and role checks fail closed.
- [ ] Every domain route requires a cryptographically verified `aal2` session;
      valid `aal1` fails before profile/use-case/database access.
- [ ] Authenticator specificity follows the pinned signed-`amr` rule or the
      accepted TOTP-only-configuration fallback; no client factor claim is
      trusted.
- [ ] An active identity security hold denies an otherwise valid AAL2 token
      before any business use case, and the hold is checked without caching.
- [ ] Collection endpoints have bounded cursor pagination.
- [ ] Errors follow the common Problem Details contract.
- [ ] Logs contain a request ID and redact security-sensitive fields.
- [ ] Liveness and readiness endpoints distinguish process health from dependency
      health.
- [ ] The API starts and becomes healthy through Docker Compose.

## A phase is done only when

- [ ] Every task in the phase meets its task-level definition of done.
- [ ] Its phase gate in `../08-execution/02-phase-gates.md` passes.
- [ ] No unresolved critical/high security issue remains.
- [ ] Any deviation has an approved ADR.
- [ ] The next phase's prerequisites are now true.

## The backend MVP is done only when

- [ ] A new learner receives one profile, completes TOTP enrollment, and can
      enter Coditza only with an `aal2` session.
- [ ] Every later password login requires a TOTP challenge before domain access.
- [ ] The learner sees published content and cannot see draft/archived content.
- [ ] The learner cannot read grading keys or another user's attempts/progress.
- [ ] Exercise and quiz submissions are graded exactly once and are safe to
      retry.
- [ ] Every `python_code` result is re-run authoritatively in the pinned
      server-side WASM worker inside the hardened outer sandbox; client/browser
      reports never award points.
- [ ] Python grading is deterministic by recorded runtime/harness/fixture/
      definition/submission digests, and infrastructure failure never becomes a
      learner failure.
- [ ] The Python runner has no network, secrets, host mounts, package downloads,
      or Auth/TOTP responsibility and passes all resource/escape/leak tests.
- [ ] Chapter and module progress follows the fixed completion rule.
- [ ] Editors can manage drafts and publish valid content but cannot manage
      roles.
- [ ] Admins can manage staff roles through an audited path.
- [ ] CI repeats local formatting, type, database, API, security, and image
      checks from a clean checkout.
- [ ] The selected hosted pre-production environment has passed smoke,
      migration, rollback, and recovery checks; a separate staging project is
      required only when DEC-027 approves it.
- [ ] Production remains a separately approved action.
- [ ] No Authenticator secret/code/QR, refresh token or Auth response is stored
      or exposed, and the factor-loss runbook/owner is accepted before
      production self-service signup; recovery includes the residual-token
      quarantine and second revoke/delete before replacement enrollment.
