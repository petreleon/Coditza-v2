# ARC-DOCKER-002 — Disposable foundation container checks

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: The user authorized the local Docker implementation
path. No hosted, production, credential, or real-environment action was used.
Prerequisites/gate checked: G0, PLAN-004, FOUND-001, FAST-CONFIG-001,
ARC-ENV-001, FAST-BOOT-001, ARC-BOUND-001/002, FAST-LIVE-001, and
ARC-DOCKER-001 are complete. ARC-DOCKER-002 was the sole `next` task before
work began.

## Decisions

- The foundation checks use a dedicated `checks` image stage, rather than the
  API development stage. It contains the pinned lockfile-installed dependencies,
  source/tests, TypeScript configuration, and the root ESLint/dependency-cruiser
  configuration required by the existing scripts.
- The stage sets `NODE_ENV=test` and disables the inherited API health check;
  one-off checks never start Fastify.
- The root Compose `checks` service is opt-in through the `checks` profile. It
  has no `env_file`, ports, bind mounts, dependencies, Docker socket, or usable
  network. It uses `network_mode: none`, a read-only filesystem, dropped Linux
  capabilities, `no-new-privileges`, and bounded tmpfs paths for npm and build
  output.
- The guide always passes `CODITZA_ENV_FILE=.env.example` and
  `--env-file .env.example`, so Compose does not select a real `.env` file.
  The check service does not receive either file.

## Scope

- Intended: an isolated, disposable Compose execution path for the existing
  `format:check`, `lint`, `typecheck`, `test`, and `build` commands, plus a
  reusable local operations guide.
- Explicitly excluded: API behavior, Supabase, SMTP, Auth, readiness, Python
  WASM, application modules, a Docker socket, any secret, browser, hosted, or
  production action.

## Changed

- `Dockerfile`: adds the non-root `checks` stage with the configuration files
  used by repository scripts and `HEALTHCHECK NONE`; the existing API
  development stage remains the normal Compose target.
- `compose.yaml`: adds profile-gated `checks` hardening and no API changes.
- `docs/operations/local-container-checks.md`: documents exact safe build/run,
  cleanup, and deliberate-failure commands.

## Verification

- Safe Compose resolution
  - Result: PASS.
  - Non-secret evidence: `CODITZA_ENV_FILE=.env.example docker compose
    --env-file .env.example -p coditza_arc_docker_002_verify --profile checks
    config --quiet` passed without reading or printing a real environment file.
- Image and isolation configuration
  - Result: PASS.
  - Non-secret evidence: the `checks` target built from the pinned Node image;
    the resolved service has `network_mode: none`, no ports or persistent
    mounts, `read_only`, `cap_drop: ALL`, `no-new-privileges`, `init`, and only
    bounded tmpfs paths. Selected image metadata confirmed user `node` and
    `HEALTHCHECK NONE`; no image environment list was inspected.
- Disposable foundation commands
  - Result: PASS.
  - Non-secret evidence: all commands used `docker compose ... --profile checks
    run --rm --no-deps -T checks npm ...`: `format:check`, `lint`, `typecheck`,
    `test`, and `build` exited zero. The containerized test run passed 155
    tests plus the 63-negative/4-positive boundary verifier.
- Failure propagation and cleanup
  - Result: PASS.
  - Non-secret evidence: `node --eval "process.exit(23)"` returned exit code
    `23` through Compose. After defensive exact-project cleanup without `-v`,
    project-scoped container, network, and volume queries were all empty.
- API regression smoke
  - Result: PASS.
  - Non-secret evidence: default Compose still resolved only `api`; a fresh
    synthetic local run reported Docker health `healthy` and exact host
    liveness `200 {"status":"ok"}`, then removed only its temporary
    container/network.
- Final local checks
  - Result: PASS.
  - Non-secret evidence: Node 24.18.0/npm 11.16.0 `format:check`, `lint`,
    `typecheck`, `test` (155 tests and the boundary verifier), and `build`
    passed after all task files were updated.

## Deviation resolved

Compose 2.40 does not implement a `run --no-ports` flag. The final guide uses
the secure Compose default: `run` publishes no ports unless `--service-ports`
is explicitly supplied, and the `checks` service declares none. A first
development-target attempt exposed missing root lint configuration; those files
now belong only to the dedicated `checks` stage.

## External actions

Only local Docker image builds and temporary Compose containers were used. No
real environment file, Supabase stack, SMTP transport, browser, GitHub, Vercel,
or other hosted resource was accessed or changed.

## Secret-safety confirmation

No credential, token, connection string, protected answer, TOTP/QR/`otpauth`,
factor/challenge material, or unsafe log was recorded. All runtime values were
safe placeholders or temporary synthetic local values outside the repository.

## Next

ARC-DOCKER-003 is the sole next task: verify the final production image from a
clean checkout, its non-root/runtime contents, read-only behavior where
supported, and graceful `SIGTERM` behavior. G1 remains closed until that task
and QA-STRAT-001 complete.
