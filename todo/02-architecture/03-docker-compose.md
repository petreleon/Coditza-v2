# Docker image and Docker Compose plan

## Required design

Docker Compose initially runs the Fastify API. After ARC-WASM-001, it also
provides the exact private grader-controller and hardened disposable-sandbox
test path selected by that ADR. The official Supabase CLI starts and owns the
local Supabase containers. Do not add `postgres`, `auth`, `rest`, or a second
Supabase stack to `compose.yaml`.

On macOS/Windows, the container can normally reach the CLI's host-published URL
through `host.docker.internal`. A Linux host-gateway address does **not** reach a
service published only on host loopback, so a host-gateway entry alone is not an
accepted Linux solution. The implementation must inspect the current CLI bind
behavior and provide one tested Linux-only path:

- a reviewed Compose override using host networking, no `ports` mapping, and
  `HOST=127.0.0.1`; or
- an officially supported shared Docker network and stable Supabase API service
  hostname documented for the pinned CLI version.

Prefer the host-network override when the CLI is loopback-only. Keep it local,
prove the pinned Compose syntax actually removes inherited port publication,
and fail with a clear unsupported-platform message if neither path is verified.
Never widen the CLI service to `0.0.0.0` merely to make container connectivity
work, and never hard-code a developer-specific IP.

## Planned artifacts

- Root multi-stage `Dockerfile`.
- Root `.dockerignore`.
- Root `compose.yaml`.
- Linux-local connectivity override when required by the verified CLI bind.
- Optional later deployment override only after a host is selected.
- After ARC-WASM-001, immutable grader-controller/sandbox build definitions and
  a local no-network policy verification path; do not invent them in the
  foundation Docker task.
- Operations guide with host and Compose workflows.

## Image stages

1. **base** — pinned supported Node image, non-root working directory.
2. **dependencies** — reproducible `npm ci` using manifests/lockfile.
3. **build** — TypeScript compilation.
4. **runtime** — production dependencies and compiled output only, non-root user,
   init/signal-safe entrypoint.
5. **development** — development dependencies and a reload command, used only
   by the local Compose profile.

After the Node compatibility task, select the maintained official Debian-slim
variant and pin both immutable version and image digest in the reviewed
Dockerfile/ADR. Revalidate the digest per target architecture; never use
floating `node`, `lts`, or `latest`.

Do not copy `.env`, `.git`, test output, local Supabase state, or `todo/` into the
runtime image.

## Compose service requirements

### ARC-DOCKER-001 — Define `api`

- [ ] Build the development target for local work.
- [ ] Publish only the configured API port.
- [ ] Bind the source for reload without masking container-installed
      `node_modules`.
- [ ] Set `HOST=0.0.0.0`.
- [ ] Load ignored local environment values at runtime.
- [ ] Do not treat a Linux host-gateway mapping as sufficient for a loopback-only
      CLI service; keep the base service portable and document the tested
      Linux-only connectivity path.
- [ ] Use an API liveness health check.
- [ ] Implement the image health check with Node's built-in `fetch` so the
      runtime image contains the executable; do not assume `curl`/`wget`.
- [ ] Configure graceful stop time long enough for Fastify shutdown.
- [ ] Enable a minimal init/reaping mechanism supported by Compose and keep Node
      as the exec-form foreground process so signals reach it.
- [ ] Do not use privileged mode or mount the Docker socket.

### ARC-DOCKER-002 — Define foundation test execution

- [ ] Provide a Compose profile or documented `docker compose run --rm` path for
      lint, typecheck, unit, and build commands.
- [ ] Make test containers disposable and independent of developer global npm
      packages.
- [ ] Preserve useful test exit codes and reports.

### ARC-DOCKER-003 — Verify production image

- [ ] Build the final runtime stage from a clean checkout.
- [ ] Inspect that no source maps containing secrets, `.env`, npm cache, or test
      fixtures are present.
- [ ] Run as a non-root UID.
- [ ] Start with read-only filesystem where the target platform supports it.
- [ ] Exercise `SIGTERM` and verify no request is accepted after shutdown begins.

### ARC-DOCKER-004 — Verify API-to-local-Supabase connectivity

Prerequisites: local Supabase is initialized; Fastify Supabase plugin and
readiness route exist.

- [ ] Start the CLI-owned Supabase stack before API integration tests.
- [ ] Pass separate container-reachable URL and canonical JWT issuer at runtime.
- [ ] Start API through Compose and prove readiness plus a bounded
      readiness-adapter read.
- [ ] Test macOS/Windows `host.docker.internal` where supported.
- [ ] On Linux, prove the selected host-network or reviewed shared-network path
      reaches the loopback-secured CLI API without publishing Supabase publicly;
      a host-gateway-only test is not passing evidence.
- [ ] Prove stopping Compose does not stop/delete CLI-owned Supabase state.

## Python sandbox extension

FAST-WASM-001 extends the already verified Compose workflow without weakening
ARC-DOCKER-001:

- the controller has no public port and no container-engine socket;
- each learner run uses the ARC-WASM-001 disposable outer boundary, not merely
  a Compose service or Node worker thread;
- the sandbox network is absent, its filesystem is read-only except bounded
  per-run scratch, and API/controller secrets are not inherited;
- runtime assets/images are addressed by the lock-manifest digest;
- `docker compose down` and failed tests leave no worker, scratch volume, or
  lease that can be mistaken for a completed attempt.

If the selected local launcher cannot meet these rules without granting the API
or controller broad host/container authority, ARC-WASM-001 remains blocked.

## Planned local sequence

The future implementation guide must document this order:

```text
1. supabase start
2. supabase db reset
3. obtain local URL and keys without committing them
4. docker compose up --build api
5. wait for API health
6. run smoke/integration checks
7. docker compose down
8. supabase stop
```

These are future actions. Do not run them during plan creation.

## Acceptance checks

- `docker compose config` resolves with placeholder-safe local configuration.
- The API is reachable from the host and can reach local Supabase.
- Restarting the API does not reset Supabase data.
- Stopping Compose does not accidentally delete the CLI-owned Supabase volumes.
- The same runtime image can point to any approved hosted environment by
  changing validated runtime configuration only.
