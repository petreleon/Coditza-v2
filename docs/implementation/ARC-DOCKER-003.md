# ARC-DOCKER-003 — Verify production image

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: The user authorized local Docker implementation and
direct commits/pushes. No hosted, production, credential, or real-environment
action was used.
Prerequisites/gate checked: G0, PLAN-004, FOUND-001, FAST-CONFIG-001,
ARC-ENV-001, FAST-BOOT-001, ARC-BOUND-001/002, FAST-LIVE-001,
ARC-DOCKER-001, and ARC-DOCKER-002 are complete. ARC-DOCKER-003 was the sole
next task before work began.

## Decisions

- Verification builds the existing final runtime target directly; Compose
  intentionally continues to target the development image.
- A first clean, no-cache runtime build found emitted TypeScript source maps in
  the application payload. The narrow runtime-only correction removes all
  .map files after the compiled output and production dependencies are copied.
  Node does not require these maps to start the compiled server.
- Runtime proof uses a mode-600 synthetic configuration file outside the
  repository. It contains only placeholder values, is never printed or
  inspected, and no real .env file is read.
- The live disposable container uses the image user, a read-only root
  filesystem, bounded /tmp tmpfs, Docker init, dropped capabilities,
  no-new-privileges, zero mounts, and a loopback-only published port.

## Scope

- Intended: build and inspect only the existing production runtime image; prove
  its runtime contents, non-root/read-only operation, liveness, graceful
  shutdown, and safe cleanup.
- Explicitly excluded: application features, Supabase, SMTP, Auth, readiness,
  Python WASM, Compose behavior changes, browser, credentials, hosted, or
  production actions.

## Changed

- Dockerfile: removes source-map files from the final runtime filesystem after
  its compiled application output and production dependencies are copied.
- docs/implementation/ARC-DOCKER-003.md: records sanitized local image/runtime
  evidence.

## Verification

- Clean runtime build and metadata inspection
  - Result: PASS.
  - Non-secret evidence: a no-cache final-stage build began from clean commit
    72611f4. The corrected final stage also rebuilt no-cache from the pinned
    Node base. Selected metadata confirmed user node, working directory
    /workspace, the compiled server command, and the built-in Node liveness
    health check; no image environment list or history was inspected.
- Runtime content policy
  - Result: PASS.
  - Non-secret evidence: a disposable networkless/read-only Node probe found
    only apps and node_modules at /workspace, and only dist and package.json
    under apps/api. It found compiled server.js and Fastify, while rejecting
    .env/.env.example, .git, todo, docs, supabase, source/tests, npm cache
    locations, direct development tools, and source maps. A prior probe caught
    the emitted maps; the narrow correction was made and the final probe passed.
- Hardened live runtime
  - Result: PASS.
  - Non-secret evidence: the temporary image container was healthy and returned
    the exact loopback liveness response 200 with status ok. Selected safe
    settings confirmed user node, read-only root, init enabled, no privilege,
    cap-drop ALL, no-new-privileges, zero mounts, and only a 127.0.0.1 port
    mapping. An in-container probe confirmed non-root execution, an EROFS
    application-root write denial, writable temporary storage only, and
    continued liveness afterward.
- Graceful shutdown and cleanup
  - Result: PASS.
  - Non-secret evidence: ordinary SIGTERM made the liveness endpoint unavailable
    immediately; the container exited with code 0 and OOMKilled false. The
    exact disposable container was removed without volumes, and a
    task-label-scoped container query was empty.
- Local foundation checks
  - Result: PASS.
  - Non-secret evidence: Node 24.18.0/npm 11.16.0 format:check, lint,
    typecheck, test, and build passed. Tests reported 155 passing tests plus
    the 63-negative/4-positive boundary verifier.
- Containerized foundation checks and cleanup
  - Result: PASS.
  - Non-secret evidence: placeholder-only Compose resolution and the isolated
    checks image passed format:check, lint, typecheck, test, and build. After
    exact-project cleanup without volume deletion, project-scoped container,
    network, and volume queries were empty.

## Deviation resolved

The initial production-image probe exposed source maps that the earlier
foundation build intentionally emitted. Removing them only in the final
runtime stage preserves development diagnostics and check-image behavior while
meeting the production image policy.

## External actions

Only local Docker image builds and temporary local containers were used. No
real environment file, Supabase stack, SMTP transport, browser, GitHub, Vercel,
or other hosted resource was accessed or changed.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer,
TOTP/QR/otpauth/factor/challenge material, or unsafe log was recorded. The
temporary runtime configuration used only synthetic placeholders outside the
repository.

## Next

QA-STRAT-001 is the sole next task: establish test-layer separation,
in-memory Auth-test helpers, and a no-network local Supabase target guard.
G1 remains closed until that task completes.
