# ARC-WASM-001 — Local Python/WASM reference proof

Outcome: COMPLETE (developer-local public-proof milestone)
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: The user authorized task-scoped local implementation and
direct commits/pushes. No hosted, credential, browser, production, or billing
action was used.
Prerequisites/gate checked: G1, ARC-DESIGN-001, PRD-WASM-001, FOUND-001, and
OPS-VERCEL-001 were complete before this task. ADR 0005 leaves the private
hosted execution plane unselected.

## Scope

- Intended: pin and exercise a hardened, disposable local Docker boundary for
  a Pyodide public-proof runner; lock its assets; reject malformed or forged
  protocol traffic; and record a truthful transition to the local Supabase
  work.
- Explicitly excluded: a grader controller, database job/lease/finalization
  path, private test plan, real learner grading, Vercel, Supabase, Chrome, SMTP,
  hosted private-runner selection, credentials, deployment, or browser UI.

## Decisions and boundary

- [ADR 0006](../adr/0006-local-python-wasm-reference-proof.md) accepts only a
  developer-local reference proof. Its `local_public_proof` result cannot be
  used as a learner verdict or sent to future finalization.
- The exact lock pins `pyodide@314.0.3`, its observed CPython `3.14.2` runtime,
  Node `24.18.0`, the `linux/arm64` image ID, every relevant Pyodide/image-side
  asset hash, the static seccomp policy, and the native gate.
- The local launch broker has Docker CLI authority only as a direct developer
  proof harness. It is not a controller adapter and must never be imported by
  Fastify or a future grader controller.

## Changed

- `Dockerfile.python-wasm-sandbox`: locked non-root Pyodide runner image with
  its compiled libseccomp Node-API gate.
- `scripts/python-wasm/`: runtime policy, deterministic public runner, local
  fixed-argument launcher, lock builder, static seccomp policy, native gate,
  and adversarial proof suite.
- `python-wasm-runtime.lock.json`: immutable local reference-lock metadata and
  image-side file hashes.
- `apps/api/test/wasm/require-approved-outer-sandbox.mjs` and package scripts:
  one focused entrypoint for the proof.
- Architecture, tracker, and ADR files: explicit public-proof boundary and the
  handoff to `SUP-LOCAL-001`.

## Verification

- `npm run format`
  - Result: PASS.
  - Non-secret evidence: all runtime sources and the local manifest are
    Prettier-formatted before the final image rebuild.
- `npm run build:wasm-local`
  - Result: PASS.
  - Non-secret evidence: the exact local Docker image was rebuilt from the
    pinned Node base and the manifest was refreshed with image ID
    `sha256:45767967a410ff8a3b3452809836504956a5a57073fb938ef83165c255f1337e`.
- `npm run test:wasm`
  - Result: PASS.
  - Non-secret evidence: the public-proof suite checked strict JSON/framing and
    digest binding; image-side hash agreement; deterministic hash/random/time;
    syntax, output, and CPU/wall classification; denied canary, JavaScript
    bridge, virtual-filesystem mutation, entropy, and socket attempts; locked
    Docker configuration; and detached-client container removal. Its final
    output was `ARC-WASM local public-proof sandbox checks passed.`
- `npm run check:foundation`
  - Result: PASS.
  - Non-secret evidence: format check, ESLint, dependency-cruiser, both
    TypeScript projects, 177 unit tests, the 63-negative/4-positive boundary
    fixture suite, and the API build all passed.

## Known boundary and remaining work

- The offline check is a warm-cache `npm ci --offline`/local asset-load proof;
  it is not a clean-cache air-gap, provenance, SBOM, or promotion proof.
- The local runner deliberately has no private test plan. `SUP-WASM-001`,
  `FAST-WASM-001`, `API-WASM-001`, and `QA-WASM-001` still own protected
  definitions, leases, finalization, controller isolation, and authoritative
  end-to-end validation.
- `OPS-HOST-001` still needs explicit user approval before it can select or
  create a hosted execution plane. A local Docker result is not transferable to
  a host by assertion.

## External actions

Only a local Docker build and disposable local containers were used. No hosted
resource, secret, personal email/SMTP connection, browser session, or provider
configuration was accessed or changed.

## Secret-safety confirmation

No credential, token, connection string, private test/answer, learner data,
TOTP/QR/`otpauth`/factor/challenge material, or unsafe log was recorded.

## Next

`SUP-LOCAL-001` is the sole next task. G1 and a working local Docker engine are
available; it can create the project-local Supabase CLI configuration without
remote state, credentials, or SMTP delivery.
