# ARC-DOCKER-001 — Local API Compose service

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: The user authorized the local Docker task. No hosted,
production, credential, or real-environment action was used.
Prerequisites/gate checked: G0, PLAN-004, FOUND-001, FAST-CONFIG-001,
ARC-ENV-001, FAST-BOOT-001, ARC-BOUND-002, and FAST-LIVE-001 are complete.
ARC-DOCKER-001 was the sole `next` task before work began.
Decisions/defaults used:

- The Docker Official Image multi-platform index is pinned to
  `node:24.18.0-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d`.
- The development process is direct Node 24 watch mode with the installed
  `tsx` preload, so `server.ts` remains the actual entry module and Node
  forwards `SIGTERM` to Fastify during watch restarts and Compose shutdown.
- Runtime verification uses only synthetic, valid non-secret configuration;
  `.env.example` is structural-only because its intentionally safe placeholders
  cannot start the API.

## Scope

- Intended: define one local non-privileged API Compose service, a pinned
  multi-stage image, explicit Docker build-context exclusions, liveness, and
  graceful shutdown evidence.
- Explicitly excluded: a Supabase stack, root Compose SMTP, credentials,
  readiness, Auth, Python/WASM, business modules, a Docker socket, hosted
  state, and a frontend.

## Implemented changes

- `Dockerfile`: pinned Node 24.18.0 Bookworm-slim multi-stage base,
  dependencies, build, development, production-dependencies, and runtime
  stages. It runs as the built-in non-root `node` user and provides a Node
  `fetch` liveness health check without `curl` or `wget`.
- `compose.yaml`: one `api` service only, an ignored runtime environment path,
  `HOST=0.0.0.0`, loopback-only publication of the configured API port,
  `init`, a 70-second stop grace period, and a read-only source-only bind mount
  that does not mask container-installed `node_modules`.
- `.dockerignore`: explicitly excludes environment files, repository/tooling
  state, all Supabase state, curriculum/implementation plans, dependencies,
  generated output, and common test artifacts from the build context.

These artifacts are accepted for this task because the required container
runtime evidence and final repository checks below passed. They are ready for
the scoped local commit; no hosted action is part of this task.

## Verification completed

- Node 24.18.0 source-watch liveness/shutdown harness
  - Result: PASS.
  - Non-secret evidence: with synthetic configuration on loopback port 3001,
    direct `node --import tsx --watch ... apps/api/src/server.ts` returned the
    exact `GET /health/live` response and stopped cleanly after `SIGTERM`.
- Placeholder-safe Compose validation
  - Result: PASS.
  - Non-secret evidence: `CODITZA_ENV_FILE=.env.example docker compose
    --env-file .env.example config --quiet` accepted the one-service model
    without reading a real `.env` or printing values.
- Development image build
  - Result: PASS.
  - Non-secret evidence: Compose built the development target from a 76.10 kB
    ignored context; `npm ci --ignore-scripts` completed in the pinned image.
- Image metadata inspection
  - Result: PASS.
  - Non-secret evidence: the built image declares user `node`, direct Node
    source-watch command, Node-based `/health/live` health check, and the
    inherited official image entrypoint. No environment list was inspected.
- Local code gates
  - Result: PASS.
  - Non-secret evidence: `npm run format:check`, `npm run lint`,
    `npm run typecheck`, `npm test` (155 tests and full boundary verifier), and
    `npm run build` passed on Node 24.18.0/npm 11.16.0. `git diff --check`
    passed.
- Final post-tracker code gates
  - Result: PASS.
  - Non-secret evidence: after the runtime evidence and tracker synchronization,
    `format:check`, `lint`, `typecheck`, `test` (155 tests plus the boundary
    verifier), and `build` passed again on Node 24.18.0/npm 11.16.0.

## Container runtime acceptance

- Isolated configuration and start
  - Result: PASS.
  - Non-secret evidence: an isolated `coditza_arc_docker_001_recheck` Compose
    project accepted `config --quiet` using only a temporary synthetic runtime
    file, then `up --build --detach api` built and started the development
    target. The real `.env` file was neither read nor printed.
- Health and host liveness
  - Result: PASS.
  - Non-secret evidence: Docker reported the image health as `healthy`; exact
    host `GET http://127.0.0.1:3001/health/live` returned `200` with only
    `{"status":"ok"}`.
- Container surface inspection
  - Result: PASS.
  - Non-secret evidence: selected safe fields showed user `node`, direct
    exec-form Node source-watch command, inherited official entrypoint,
    `privileged=false`, `init=true`, one read-only
    `apps/api/src -> /workspace/apps/api/src` bind, and only
    `127.0.0.1:3001` published. No environment list was inspected; there was
    no Docker-socket or `node_modules` mount.
- Source reload
  - Result: PASS.
  - Non-secret evidence: a temporary non-functional source comment caused the
    Node watch child process to restart while the watch supervisor remained;
    host liveness recovered with the exact response. The comment was removed
    and `git diff -- apps/api/src/server.ts` was empty.
- Graceful shutdown and cleanup
  - Result: PASS.
  - Non-secret evidence: plain `docker compose stop api` exited successfully;
    the retained container finished with exit code `0` and host liveness became
    unreachable. `down --remove-orphans` then removed only the verification
    container/network; exact-project checks found zero containers, networks,
    and volumes.

## Transient Docker recovery

The initial temporary Docker project had stalled lifecycle events. Once the
daemon released its stopped resources, only exact Coditza-named containers and
empty networks were removed. Docker/Colima was not restarted, no volumes or
images were removed, and unrelated user containers were not touched. The fresh
isolated project above supplied the missing acceptance evidence.

## External actions

Only local Docker image builds and temporary API-only Compose resources were
used. No real environment file was read, printed, modified, or mounted; no
Supabase, SMTP, browser, Vercel, GitHub, or other hosted resource was accessed
or changed.

## Secret-safety confirmation

No credential, token, connection string, private data, protected answer,
TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
recorded. The temporary runtime configuration used only synthetic values and
was stored outside the repository.

## Next

ARC-DOCKER-002 is now the sole next task. It may define only the disposable
foundation container-check path; it must not begin Supabase, SMTP, curriculum,
or hosted work.
