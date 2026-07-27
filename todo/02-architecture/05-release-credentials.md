# Release credentials and non-runtime identity

This matrix is for future hosted migration, registry, and deployment jobs. It
is separate from API runtime configuration. Exact vendor variable names and CLI
flags must be rechecked against current official documentation at
implementation time; the logical purpose and isolation rules are fixed here.

## Credential matrix

| Logical value | Secret? | Stored by | Used only for |
| --- | ---: | --- | --- |
| Supabase project reference | No | protected environment metadata | selecting the exact remote project |
| Supabase CLI access token | Yes | protected release secret store | authenticating the CLI/control plane |
| Supabase database/release credential | Yes | protected release secret store | applying reviewed migrations |
| OCI registry repository | No | CI/environment config | exact image destination |
| OCI registry credential | Yes | protected CI secret store | pushing/pulling immutable images |
| API host deployment credential | Yes | protected deployment environment | deploying an approved digest |
| provenance/signing key, if adopted | Yes | dedicated signing service/store | artifact attestation only |

Do not reuse `SUPABASE_SECRET_KEY` as a migration credential. Do not give
migration/registry/deploy credentials to the API container. Development,
optional staging, and production use separate environment scopes and the
smallest privileges the selected provider supports.

## ARC-ENV-003 — Establish development release identities

Prerequisites: DEC-024 and OPS-HOST-001 are confirmed; `Coditza-dev` exists from
SUP-CHROME-001; its exact non-secret project reference is recorded; the
development credential-binding action is authorized.

- [ ] Revalidate current Supabase CLI authentication and database credential
      names; record names and owners, never values.
- [ ] Create only the protected development runtime/release scopes; this task
      does not create optional staging or production credentials.
- [ ] Bind each development job to the exact project reference, registry
      repository, immutable image source, Vercel public API service, any
      separately approved private grader host, and `APP_ENV`; fail if any target
      is missing or mismatched.
- [ ] Bind the runtime scope to the exact HTTPS Supabase URL/issuer mapping and
      current key types without copying secret values into evidence.
- [ ] Mask values and ensure logs/artifacts cannot echo them.
- [ ] Prove runtime containers do not receive release credentials.
- [ ] Record rotation/revocation owner and last verification date.

Evidence is a sanitized name/owner/scope matrix plus a successful least-
privilege dry run against the exact development target.

## OPS-VERCEL-ENV-001 — Bind Vercel development and preview runtime variables

Prerequisites: OPS-VERCEL-001 has recorded a compliant Vercel public-API
topology; OPS-HOST-001 has created or confirmed the approved empty Vercel
development service; SUP-CHROME-001/002 and ARC-ENV-003 are complete; the user
approves the exact development/preview binding action.

- [ ] Re-read the current Vercel documentation and identify the exact project,
      team, Development and Preview environment scopes. State their non-secret
      identifiers before changing anything.
- [ ] Use Chrome for the approved Vercel Dashboard binding flow. The user
      handles login, MFA, password-manager, and direct secret entry; do not
      screenshot, transcribe, or inspect secret values.
- [ ] Derive the complete runtime-variable inventory from the reviewed typed
      configuration contract, not from memory. Classify each as public,
      runtime-secret, release-only, or prohibited for Vercel. API runtime must
      never receive Supabase CLI, database-release, OCI-registry, sandbox-host,
      or deployment credentials.
- [ ] Have the user transfer values directly into the approved Vercel secret
      interface. Never paste, echo, screenshot, store, or report values. Do not
      use a source-controlled `.env` file as an import mechanism.
- [ ] Bind Development and Preview values only to the exact non-production
      Supabase target and approved CORS/Auth metadata. Reject a production URL,
      issuer, key, project reference, wildcard origin, or secret scope in a
      preview binding.
- [ ] Verify variable names, environment scope, masking, and target metadata
      without reading values. Perform a no-secret target/configuration dry run
      and prove the separate grader host, if one exists, receives its own
      minimal runtime scope rather than Vercel's API scope.
- [ ] Do not deploy an image, apply a migration, configure a Vercel Production
      variable, or create a production resource. ARC-ENV-PROD-001 owns any
      separately approved production Vercel binding.

Evidence is a sanitized Vercel project/environment/name/classification matrix,
approved-target proof, and masked dry-run result with no values.

## ARC-ENV-STAGING-001 — Establish optional staging release identities

Prerequisites: DEC-027 explicitly approves staging,
SUP-CHROME-STAGING-001 creates the exact project, OPS-HOST-001 is complete, and
the credential-binding action is authorized.

- [ ] Create distinct staging runtime/release scopes; never copy development or
      production credentials.
- [ ] Create or confirm the approved empty staging host environment/service
      identifier with no image and no public traffic before binding its scopes.
- [ ] Bind the exact staging project reference, HTTPS URL/issuer mapping,
      registry repository, approved API service, digest source, and `APP_ENV`.
- [ ] Require a sanitized least-privilege dry run against staging and prove the
      runtime receives no migration/registry credential.
- [ ] Record owner, approval rule, rotation/revocation path, and verification
      date without recording values.

If DEC-027 rejects staging, mark this task `not applicable` with that decision;
do not create placeholder secrets.

## ARC-ENV-PROD-001 — Establish production release identities

Prerequisites: G7; SUP-CHROME-PROD-001 creates the exact approved project;
OPS-HOST-001 and DEC-024 are resolved; the user approves binding credentials to
the named production project, host service, registry, and protected environment.

- [ ] State the exact project reference, organization, host service, registry
      repository, environment name, and action before changing external state.
- [ ] Create new production-only runtime and release scopes with protected
      approvals; do not copy a non-production credential.
- [ ] Create or confirm the approved empty production host environment/service
      shell with public traffic disabled before binding any scope; naming it in
      OPS-HOST-001 alone was not creation authorization.
- [ ] Have the user transfer values directly between approved secret stores;
      never expose values in chat, screenshots, reports, or shell history.
- [ ] Bind the exact project reference, HTTPS URL/issuer mapping, immutable
      digest source, `APP_ENV=production`, and production CORS/Auth metadata.
- [ ] If Vercel is the approved public API host, bind Vercel Production runtime
      values only after the exact production action is approved; record names,
      scopes, masking, and target metadata without values.
- [ ] Prove the runtime receives only runtime keys and the release job receives
      only its narrow migration/deploy credentials.
- [ ] Configure owner, rotation/revocation, break-glass approval, and last
      verification date.
- [ ] Run only non-mutating identity/target checks; migration and image
      deployment belong exclusively to OPS-DEPLOY-002.

Evidence is an approver-stamped, sanitized scope/binding matrix and target
preflight with no secret values.
