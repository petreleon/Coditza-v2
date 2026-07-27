# ADR 0003: Node and Fastify toolchain baseline

Status: accepted

Date: 2026-07-27

Related tasks: FOUND-001, ARC-BOUND-001, FAST-CONFIG-001, FAST-BOOT-001.

## Decision

Coditza targets Node.js **24.18.0 LTS** (`.nvmrc`) and npm **11.16.0**
(`packageManager`). The workspace requires Node `>=24.18.0 <25` and npm
`>=11.16.0 <12`; CI and the later image task must use the exact Node 24.18.0
release rather than treating the broad engine range as a deployment selection.

The API baseline uses exact versions locked in `package-lock.json`:

| Role                     | Package/version                                                  |
| ------------------------ | ---------------------------------------------------------------- |
| HTTP framework           | `fastify` 5.10.0                                                 |
| Fastify TypeBox provider | `@fastify/type-provider-typebox` 6.1.0                           |
| TypeBox peer             | `typebox` 1.0.13                                                 |
| compiler                 | `typescript` 6.0.3                                               |
| Node declarations        | `@types/node` 24.13.3                                            |
| development runner       | `tsx` 4.23.1                                                     |
| tests/coverage           | `vitest` and `@vitest/coverage-v8` 4.1.10                        |
| lint                     | `eslint` 10.8.0, `@eslint/js` 10.0.1, `typescript-eslint` 8.65.0 |
| formatting               | `prettier` 3.9.6                                                 |

Use strict TypeScript, ESM, NodeNext module/resolution, ES2024 output, and
emitted `.js` relative suffixes. `apps/api/dist/server.js` remains the future
runtime entrypoint; it is deliberately a compiled no-listener module until
FAST-BOOT-001 owns the app factory, startup, and shutdown behavior.

## Compatibility evidence

- [Node 24.18.0 LTS](https://nodejs.org/en/blog/release/v24.18.0) is the
  current selected LTS release. Its checksum-verified official macOS binary
  reports bundled npm 11.16.0.
- [Fastify's LTS policy](https://fastify.dev/docs/latest/Reference/LTS/) tests a
  supported Fastify major against Node releases supported by Node's LTS policy.
  Fastify 5.10.0 is the current Fastify 5 line selected here.
- The [Fastify Type Provider documentation](https://fastify.dev/docs/latest/Reference/Type-Providers/)
  specifies the current `typebox` plus `@fastify/type-provider-typebox`
  pairing. Provider 6.1.0 declares `typebox ^1.0.13`.
- TypeBox 1 supports TypeScript 6+, while `typescript-eslint` 8.65.0 permits
  TypeScript below 6.1. TypeScript 6.0.3 satisfies both published constraints.

## Deferred compatible packages

The following current compatible candidates were checked but are not installed
in FOUND-001 because no active foundation source imports or registers them:

| Later owner     | Candidate checked                                                                                                                |
| --------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| FAST-PLUGIN-001 | `fastify-plugin` 6.0.0, `@fastify/cors` 11.3.0, `@fastify/helmet` 13.1.0, `@fastify/rate-limit` 11.1.0, `@fastify/swagger` 9.8.1 |
| FAST-PLUGIN-002 | `@supabase/supabase-js` 2.110.8 (published Node engine `>=22`)                                                                   |

Their owning tasks must recheck release notes/compatibility before adding them
to the lockfile. This avoids treating unused security or database packages as
part of the liveness-only foundation.

## Consequences

- The current TypeBox package is `typebox`, not the former
  `@sinclair/typebox` package line. Future configuration validation imports its
  compatible `typebox/value` API.
- FOUND-001 creates type-only app/config/composition/server seams so code
  compiles without claiming configuration parsing, an app factory, a listener,
  Fastify route/plugin behavior, external adapters, or import-boundary
  enforcement.
- A host with a newer Node release can create the lockfile only when it honors
  the declared package manager; the exact Node 24.18.0 runtime is re-proven by
  the later image/CI tasks.
