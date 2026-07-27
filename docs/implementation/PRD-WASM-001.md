# PRD-WASM-001 — Freeze Python exercise semantics

Outcome: COMPLETE
Environment: LOCAL DOCUMENTATION
Date: 2026-07-27
Agent/person: Codex
Authorization checked: Implementation is authorized. This task changes only
local product/verification documentation and makes no runtime, credential,
browser, Docker, Supabase, Vercel, or other external-state change.
Prerequisites/gate checked: G0 and ARC-DESIGN-001 are complete; PRD-WASM-001
was the sole next task before this work began.
Decisions/defaults used:

- A `python_code` submission is a closed, bounded multi-file source package;
  it is never a quiz type and never accepts a client score, verdict, test
  report, definition, actor, runtime choice, or progress assertion.
- Canonical package, idempotency, and learner-verdict values use RFC 8785 JSON
  canonicalization plus domain-separated SHA-256 digests. File order alone is
  normalized; source text, Unicode, line endings, whitespace, and encoding
  cookie text are preserved exactly.
- Only seven allowlisted learner terminal verdicts create an immutable attempt:
  `passed` awards frozen full points; all other learner verdicts award zero.
  Every runner/protocol/asset/lease/determinism failure remains infrastructure
  work and never becomes a learner attempt or progress mutation.
- The authoritative route is a future server-side runner only. A browser public
  test preview is non-authoritative. Auth/TOTP, identity, raw database clients,
  secrets, and raw source/package echoes are excluded from the learner-facing
  runner request/result; private declarative cases use only a later-proven
  trusted harness-initialization handoff.
- This task deliberately selects neither a Pyodide asset nor a launcher. The
  hardened outer sandbox remains owned by ARC-WASM-001; persistence, controller,
  HTTP routes, and runtime proof remain later named tasks.

## Scope

- Intended: freeze an explicit source-package validation/canonicalization
  contract, frozen authored-definition and closed protocol semantics,
  deterministic fixture/verdict rules, learner-versus-infrastructure outcomes,
  Auth/TOTP/database exclusion, and credential-free golden vectors.
- Explicitly excluded: Python/Pyodide download or execution, runtime/version or
  asset selection, outer-sandbox or Vercel topology selection, application
  code/dependencies, database object/migration, Fastify controller/API, Docker,
  credentials, Chrome, Supabase configuration, SMTP, deployment, and external
  state.

## Changed

- docs/implementation/python-exercise-verification-contract.md: normative
  closed request/package/idempotency/verdict/protocol/authority contract.
- docs/implementation/python-exercise-golden-vectors.md: deterministic source,
  idempotency, verdict, resource-precedence, invalid-input, forged-client, and
  sensitive-boundary vectors.
- docs/implementation/PRD-WASM-001.md: this completion report.
- todo/01-product/05-python-code-exercises.md,
  todo/02-architecture/07-python-wasm-verification.md, todo/TASKS.md,
  todo/STATUS.md, todo/NEXT.md, todo/README.md,
  todo/00-control/00-scope-and-non-goals.md, and
  todo/08-execution/00-roadmap.md: evidence, protected private-case handoff,
  and sole-next-task synchronization.

## Verification

- Canonical source/idempotency/verdict hash assertion
  - Result: PASS
  - Non-secret evidence: a local Node SHA-256/RFC-8785-key-order assertion
    verified seven source-package digests, one reservation idempotency digest,
    and all seven learner-verdict digests against the published vectors.
- Contract and vector completeness review
  - Result: PASS
  - Non-secret evidence: the contract fixes UTF-8/duplicate-member/scalar,
    closed-shape, traversal/case/NUL/size, canonical-order, deterministic
    resource-precedence, full-or-zero scoring, retry/dead, and no-browser-trust
    behavior; vectors cover valid boundaries, malformed/duplicate JSON,
    Unicode/byte limits, forged fields, and sensitive boundaries.
- Scope and authority review
  - Result: PASS
  - Non-secret evidence: no source package, runtime asset, launcher, database,
    API/controller, dependency, Docker artifact, credential, hosted resource,
    or browser configuration was added or changed.
- Whitespace, sensitive-marker, and task-registry preflight
  - Result: PASS
  - Non-secret evidence: the staged change has no whitespace error; credential
    scan found no value-shaped secret or TOTP/QR/URI payload; PRD-WASM-001 is
    complete and FOUND-001 is the sole eligible next task.

## External actions

NONE. No Chrome, Supabase project, provider setting, SMTP credential, Vercel
project, deployment, Python execution, or runtime download was accessed or
changed.

## Deviations/ADRs

- NONE. The established modular-monolith, direct-Supabase-Auth, mandatory-TOTP,
  and hardened-server-authority decisions are preserved.

## Risks/blockers

- ARC-WASM-001 must select a pinned Pyodide/Python runtime and prove the
  compliant disposable outer sandbox after G1 and OPS-VERCEL-001; neither a
  Node worker thread nor WebAssembly alone satisfies that boundary.
- SUP-WASM-001, FAST-WASM-001, API-WASM-001, and QA-WASM-001 must implement and
  prove the durable job, controller, HTTP, and end-to-end behavior before a
  Python exercise can be published or accepted.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer,
TOTP/QR/`otpauth`/factor/challenge material, unsafe source/runtime artifact, or
unsafe screenshot/log was recorded.

## Next

FOUND-001 is the only unblocked next task: all tree, architecture, Auth, and
Python semantic prerequisites are complete. It may select current compatible
API/tool versions and create the minimal strict TypeScript/Fastify workspace,
but it may not start Supabase, create Docker artifacts, select a Python runtime,
or change external state.
