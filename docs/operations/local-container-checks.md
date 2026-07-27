# Local container foundation checks

## Purpose

Run the current static and unit foundation checks in the pinned Coditza `checks`
image without starting the API. The profile is opt-in, has no ports, bind
mounts, runtime `env_file`, service dependencies, Docker socket, or network. It
runs as the image's non-root `node` user with all Linux capabilities dropped,
`no-new-privileges`, a read-only filesystem, and only bounded temporary writes
for npm and TypeScript build output.

The `checks` stage bakes the current source, tests, manifests, lockfile, and
root lint configuration into the image. Rebuild before a check whenever any of
those files change. Do not use `docker compose up` for these commands.

## Safe local command sequence

Run commands from the repository root. The explicit safe placeholder file and
`CODITZA_ENV_FILE` prevent Compose from selecting a developer's real `.env`
file while it resolves the normal API service; the `checks` service itself does
not receive an environment file.

```text
CODITZA_ENV_FILE=.env.example docker compose --env-file .env.example -p coditza_checks --profile checks config --quiet
CODITZA_ENV_FILE=.env.example docker compose --env-file .env.example -p coditza_checks --profile checks build checks
CODITZA_ENV_FILE=.env.example docker compose --env-file .env.example -p coditza_checks --profile checks run --rm --no-deps -T checks npm run format:check
CODITZA_ENV_FILE=.env.example docker compose --env-file .env.example -p coditza_checks --profile checks run --rm --no-deps -T checks npm run lint
CODITZA_ENV_FILE=.env.example docker compose --env-file .env.example -p coditza_checks --profile checks run --rm --no-deps -T checks npm run typecheck
CODITZA_ENV_FILE=.env.example docker compose --env-file .env.example -p coditza_checks --profile checks run --rm --no-deps -T checks npm test
CODITZA_ENV_FILE=.env.example docker compose --env-file .env.example -p coditza_checks --profile checks run --rm --no-deps -T checks npm run build
CODITZA_ENV_FILE=.env.example docker compose --env-file .env.example -p coditza_checks --profile checks down --remove-orphans
```

Each `run` command executes `npm` directly, so its exit status is the command
result. `--rm` removes the one-off container, `--no-deps` prevents service
startup, and `-T` disables an interactive terminal. Compose `run` does not
publish ports unless explicitly given `--service-ports`, and `checks` declares
no ports. Do not add `-v` to the cleanup command.

## Verify cleanup and failure propagation

Before accepting a change, prove both behaviors with an isolated project name:

```text
CODITZA_ENV_FILE=.env.example docker compose --env-file .env.example -p coditza_checks_verify --profile checks run --rm --no-deps -T checks node --eval "process.exit(23)"
docker ps --all --filter label=com.docker.compose.project=coditza_checks_verify
docker network ls --filter label=com.docker.compose.project=coditza_checks_verify
docker volume ls --filter label=com.docker.compose.project=coditza_checks_verify
```

The first command must return exit code `23`; the three listing commands must
show no project-scoped resource after it exits. Use the exact-project
`down --remove-orphans` command without `-v` only if Compose reports a leftover
container or network. Never prune global Docker resources as part of these
checks.

## Scope boundary

This is a static/unit foundation path only. It does not start Supabase, execute
database/API/end-to-end/Python-WASM tests, validate SMTP, or change a hosted
environment. Those paths require their own active tasks and credentials.
