# Official references

These links were reviewed while preparing the plan on 2026-07-27. They are
references, not version pins. Re-open them at implementation time because
interfaces and security guidance can change.

## Fastify

- [Latest Fastify documentation](https://fastify.dev/docs/latest/)
- [Getting started and plugin loading](https://fastify.dev/docs/latest/Guides/Getting-Started/)
- [Validation and serialization](https://fastify.dev/docs/latest/Reference/Validation-and-Serialization/)
- [Type providers](https://fastify.dev/docs/latest/Reference/Type-Providers/)
- [Server and inject API](https://fastify.dev/docs/latest/Reference/Server/)
- [LTS policy](https://fastify.dev/docs/latest/Reference/LTS/)

## Supabase

- [Local development workflow](https://supabase.com/docs/guides/local-development/cli-workflows)
- [Database migrations](https://supabase.com/docs/guides/local-development/database-migrations)
- [Database testing overview](https://supabase.com/docs/guides/local-development/testing/overview)
- [Row Level Security](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Securing data and API keys](https://supabase.com/docs/guides/database/secure-data)
- [Current API key types](https://supabase.com/docs/guides/getting-started/api-keys)
- [Supabase JWT verification](https://supabase.com/docs/guides/auth/jwts)
- [`auth.getClaims()` reference](https://supabase.com/docs/reference/javascript/auth-getclaims)
- [Supabase Auth MFA overview](https://supabase.com/docs/guides/auth/auth-mfa)
- [Authenticator-app TOTP enrollment and login](https://supabase.com/docs/guides/auth/auth-mfa/totp)
- [Supabase JavaScript MFA reference](https://supabase.com/docs/reference/javascript/auth-mfa)
- [Supabase JWT claims, including `aal` and `session_id`](https://supabase.com/docs/guides/auth/jwt-fields)
- [Supabase Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits)
- [Supabase local CLI Auth/MFA configuration](https://supabase.com/docs/guides/local-development/cli/config)

## Docker and PostgreSQL

- [Docker Compose specification](https://docs.docker.com/reference/compose-file/)
- [Compose service, healthcheck, and `extra_hosts` reference](https://docs.docker.com/reference/compose-file/services/)
- [Docker multi-stage builds](https://docs.docker.com/build/building/multi-stage/)
- [PostgreSQL string functions and normalization](https://www.postgresql.org/docs/17/functions-string.html)

## Python on WebAssembly

- [Pyodide documentation](https://pyodide.org/en/stable/)
- [Pyodide Web Worker guidance](https://pyodide.org/en/stable/usage/webworker.html)
- [Pyodide package loading](https://pyodide.org/en/stable/usage/loading-packages.html)
- [Node.js WASI documentation and security warning](https://nodejs.org/api/wasi.html)

## Protocol standards

- [RFC 8785 — JSON Canonicalization Scheme](https://www.rfc-editor.org/rfc/rfc8785)
- [RFC 9457 — Problem Details for HTTP APIs](https://www.rfc-editor.org/rfc/rfc9457)

## Revalidation checklist

- [ ] Confirm the supported Node.js version for the chosen Fastify major.
- [ ] Confirm every `@fastify/*` plugin supports that Fastify major.
- [ ] Confirm the current Supabase CLI migration and type-generation commands.
- [ ] Confirm publishable/secret key names and Dashboard locations.
- [ ] Confirm the project uses asymmetric Auth signing keys or document the
      slower server-verification fallback.
- [ ] Confirm current TOTP enroll/challenge/verify/list/unenroll behavior,
      factor limits, AAL refresh behavior, and the absence/presence of recovery
      codes before implementing the client contract.
- [ ] Confirm local and hosted TOTP enrollment/verification settings and Auth
      rate limits have not changed.
- [ ] Confirm current RLS recommendations and test tooling.
- [ ] Confirm the available PostgreSQL major supports the pinned normalization
      expression and rerun SQL/TypeScript golden vectors.
- [ ] Confirm current Compose healthcheck/host-gateway syntax on macOS and the
      selected Linux CI runner.
- [ ] Confirm the exact supported Pyodide/Python/Node combination, asset list,
      module Web Worker API, package bundle, and license/vulnerability state.
- [ ] Reconfirm that WebAssembly/Node WASI is not accepted as the outer security
      sandbox and prove the selected launcher independently enforces isolation.
- [ ] Record any changed guidance in an ADR before implementation.
