# ADR 0004: Configuration ownership and the phase-one API parser

Status: accepted

Date: 2026-07-27

Related tasks: FAST-CONFIG-001, ARC-ENV-001, ARC-ENV-002, ARC-WASM-001,
FAST-WASM-001.

## Context

The environment contract intentionally lists settings consumed by both the API
process and the private Python grader controller. Earlier task wording said to
validate "every variable" while the same contract says that the controller
owns the runtime manifest, launcher profile, lease, polling, retry, and
hosted-test settings. Treating that wording literally would put controller
secrets and sandbox deployment details in the public API configuration object.
It would also create two competing API schemas when ARC-ENV-001 begins.

## Decision

FAST-CONFIG-001 creates exactly one pure API parser:

```text
parseApiConfig(raw injected environment) -> deeply immutable ApiConfig
```

It owns the following API settings, and no controller-only setting:

- environment pair, server, CORS, proxy, request-ID, Swagger, body, rate, and
  HTTP timeout settings;
- Supabase URL, project reference, publishable key, secret key, JWT issuer and
  audience, plus the cursor HMAC secret;
- the safe Python grader projection only: enabled, concurrency, and queue
  limit.

The parser is synchronous and side-effect free. It parses raw strings first,
checks the resulting plain object with one closed TypeBox `ConfigSchema`, then
returns recursively frozen plain data. Its small production wrapper may pass
`process.env`, but it does not load dotenv, construct Fastify, construct a
Supabase client, or make a network call.

The accepted opaque key prefixes follow the current
[Supabase API-key guidance](https://supabase.com/docs/guides/getting-started/api-keys):
`sb_publishable_` for the API publishable key and `sb_secret_` for the
server-only key. The API accepts the `authenticated` JWT audience used by the
learner-authentication path, with issuer validation aligned to Supabase's
[JWT claims reference](https://supabase.com/docs/guides/auth/jwt-fields).

The following remain controller-owned and must neither be parsed nor exposed
by `ApiConfig`: `PYTHON_WASM_RUNTIME_MANIFEST`,
`PYTHON_SANDBOX_LAUNCHER_PROFILE`, claim-batch size, polling interval, lease,
maximum retries, sandbox-launch bindings, and `ALLOW_HOSTED_TEST_TARGET`.
They are introduced only with the private controller composition root and its
WASM security evidence.

FAST-CONFIG-001 validates safe local-versus-hosted syntax and the standard
hosted Supabase URL/project-reference/issuer relationship. ARC-ENV-001 is a
local acceptance task: it inventories and proves this one parser's ownership,
redaction, and controller separation without adding a second schema.
ARC-ENV-002, after its runtime prerequisites, owns the protected hosted-test
control, remote-target guard, custom-domain mapping proof, target-distinctness
evidence, and host/Compose separation tests.

There is no configuration field or tracked deployment artifact that can prove
an API-only hosted release today. Therefore an empty CORS list is accepted
only for the documented local/test API-only mode and is rejected in hosted
environments until a later deployment task supplies an auditable release
record. Hosted allowlist origins must use HTTPS. The parser normalizes scheme
and host casing while preserving every explicitly supplied port (including a
default port); duplicate detection remains semantic, so an explicit default
port and its omitted equivalent cannot appear together. The list is never
rewritten to `*`.

`TRUST_PROXY` has no reviewed hop/address-policy grammar yet. The parser
accepts only the explicit safe value `false`; a later task must add a narrow,
reviewed policy representation before any proxy trust can be enabled.

The original independent upper bounds of `120000` milliseconds for both
keep-alive and headers timeouts conflict with the required strict relation
`HEADERS_TIMEOUT_MS > KEEP_ALIVE_TIMEOUT_MS`. The effective API contract sets
the keep-alive range to `1000`–`119999` and the headers range to
`1001`–`120000`. This preserves the documented default and headers ceiling
while ensuring every accepted endpoint can participate in a valid pair.

The Python grader projection may parse its strict boolean, but `true` remains
fail-closed until G-WASM and the private controller configuration are complete.
No API parser setting creates a sandbox capability.

## Consequences

- The API has one discoverable, injectable configuration contract without
  importing controller deployment data or secrets.
- Fastify bootstrap can consume typed configuration later without moving
  validation into a listener or test-global environment mutation.
- Configuration errors can identify only variable names and fixed reasons;
  supplied values, including publishable and secret keys, never appear in
  messages, stacks, logs, snapshots, or documentation.
- Future deployment work must extend the accepted mapping/evidence around the
  parser rather than weakening its local and hosted safety checks.
