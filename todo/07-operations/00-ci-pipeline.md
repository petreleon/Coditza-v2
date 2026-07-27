# CI pipeline

Remain provider-neutral until source hosting is chosen. CI must have Docker
because the local Supabase stack and API image are part of verification.

## OPS-CHECK-001 — Create one provider-neutral verification entrypoint

- [ ] Add one documented root command that runs the local checks below in the
      fixed fail-fast order.
- [ ] Make cleanup run after success or failure.
- [ ] Reject remote Supabase URLs/credentials.
- [ ] Produce only sanitized, deterministic reports.
- [ ] Run the command from a clean checkout and from the Compose test path.

## OPS-SOURCE-001 — Select source, CI, and registry

Prerequisites: OPS-CHECK-001 is complete and the user is available to resolve
DEC-024. This task owns that decision; DEC-024 is not a prerequisite that must
already be resolved.

- [ ] Inspect any existing Git remote without changing it.
- [ ] Ask the user to confirm the source host, CI runner, repository owner, and
      OCI registry/repository; do not create external resources by assumption.
- [ ] Record runner Docker capability, protected-environment support, retention,
      billing owner, and least-privilege credential owner in an ADR.
- [ ] Confirm which branches/checks are protected and who can approve
      production.
- [ ] Keep provider-specific syntax out of the provider-neutral local command.

## Pull-request pipeline order

1. checkout the exact revision;
2. install pinned Node/npm and `npm ci`;
3. format check;
4. lint/import boundaries;
5. TypeScript typecheck;
6. unit tests;
7. verify the exact Python WASM runtime manifest/assets offline;
8. start local Supabase;
9. clean database reset and seed;
10. database lint/tests and RLS matrix;
11. regenerate database types and fail on diff;
12. API integration/contract/security tests;
13. run the Python WASM deterministic/adversarial suite in the approved outer
    sandbox, never an in-process fallback;
14. generate OpenAPI and fail on unexplained diff;
15. production TypeScript build;
16. API/controller/sandbox image build;
17. Compose smoke/health/shutdown/queue-crash test;
18. dependency, Python package, secret, SBOM, and container scan;
19. upload sanitized reports;
20. stop containers/sandboxes in an always-run cleanup step.

## OPS-CI-001 — Implement CI safely

Prerequisites: OPS-CHECK-001 and OPS-SOURCE-001; exact provider recorded.

- [ ] Use no development/staging/production credentials.
- [ ] Guard integration configuration so only local URLs are accepted.
- [ ] Cache only by lockfile/tool version; never cache secrets or database state.
- [ ] Cancel superseded runs on the same branch.
- [ ] Require all gates before merging.
- [ ] Mask environment values and sanitize reports.
- [ ] Pin third-party actions/plugins by immutable version.
- [ ] Set timeouts for every job.
- [ ] Preserve failing logs/artifacts without tokens/answers.

## Main-branch artifact

- Build one immutable production image after PR gates.
- Tag by commit digest, not only `latest`.
- Generate an SBOM/provenance where the chosen platform supports it.
- Do not push/deploy until a registry/environment task explicitly authorizes it.
- Promote the same verified digest; do not rebuild separately for production.

## OPS-ARTIFACT-001 — Publish an immutable image

Prerequisites: OPS-CI-001 is green; registry/repository and credential scope are
confirmed; publishing is authorized.

- [ ] Build from the exact reviewed commit with the same production Dockerfile.
- [ ] Scan and create an SBOM/provenance record.
- [ ] Push a commit tag and record the immutable content digest.
- [ ] Verify a clean pull by digest and a non-root smoke run.
- [ ] Never publish secrets, local state, `todo/`, or mutable-only evidence.
- [ ] Promote that digest unchanged through every hosted environment.
