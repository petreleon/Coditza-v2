# Data flow and security architecture

## Read path

1. Client completes password plus TOTP with Supabase Auth and sends the refreshed
   access token to Fastify.
2. Auth plugin verifies signature/issuer/expiry with current official Supabase
   guidance.
3. Auth plugin validates UUID subject/session and exact `aal2`; `aal1`,
   missing, and unknown AAL never reach a domain adapter.
4. The identity Supabase adapter uses the secret client to load only that
   subject's profile ID, role, and security-hold timestamp; missing profile or
   active hold denies access.
5. Inbound adapter/use case receives
   `{ userId, role, aal: "aal2", sessionId }`, never the raw client/token.
6. A module-specific outbound adapter uses the secret client with an explicit safe column list and
   server-controlled actor context.
7. Persistence mapper converts a row/RPC result to an application result; the
   HTTP presenter separately builds the DTO.
8. Fastify response schema strips every undeclared field.

## Privileged write/grading path

1. Inbound adapter authenticates `aal2`, checks role, and validates transport.
2. One coordinating application use case constructs the command and invokes one
   outbound transaction port; it does not recreate database state.
3. A module-specific Supabase adapter calls one named server-only,
   transaction-safe database function and passes the verified actor ID outside
   the client payload.
4. PostgreSQL reloads that actor's current role/ownership, takes locks, validates
   references/current state, grades where applicable, and commits the durable
   result plus progress. It does not claim
   end-user `auth.uid()` verification under the server secret context.
5. Adapter returns a dedicated application result projection with no answer key.
6. Use case translates known outcomes; the inbound adapter maps them to stable
   public problem codes without recomputing score/status.

## ARC-WASM-001 local reference flow (not grading)

```text
developer command
  -> fixed local launch broker
  -> one inspected, auto-removed Docker container
  -> pinned Pyodide worker executes public synthetic cases
  -> local_public_proof result
```

This flow has no Fastify request, Supabase client, database row, Auth/TOTP
material, learner identity, private case plan, score, attempt, or finalization.
The broker's Docker CLI authority is scoped to this developer-local evidence
command and cannot be reused by a future API/controller process.

## Threats and required controls

| Threat | Required control |
| --- | --- |
| Forged/expired token | Cryptographic verification, issuer/expiry checks, fail closed |
| Password-only `aal1` session enters Coditza | Exact `aal2` check before profile/role/use case |
| TOTP secret/code leaks | Supabase-client-only flow; redaction and artifact scans |
| Revoked session leaves an old access JWT valid | live identity security hold for operator recovery; bounded JWT lifetime for ordinary factor changes |
| User promotes own role | Fastify admin path, server-only function, direct-user denial, audit |
| Learner reads a draft | Server query filters/authorization plus no direct Data API access |
| Learner reads answer keys | Private schema, server-only RPC projection, response schemas |
| Learner awards own score | No direct attempt-grade writes; server transaction grades |
| Duplicate network submission | Idempotency record and transaction/unique constraint |
| Cross-item option ID | Validate option ownership in domain policy/use case and database |
| Quiz changes mid-attempt | Immediate published-definition immutability plus stored `definitionVersion`; lifecycle row version is irrelevant |
| Over-fetch leaks internal data | Explicit select lists, DTO mapper, response schemas |
| Secret logged | Pino redaction plus tests and log review |
| Resource exhaustion | payload limits, pagination, timeouts, rate limits |
| Secret adapter overreach | narrow ports, explicit selects, actor checks, import rules |
| Module ownership drift | one-owner inventory, `public.ts` imports, negative boundary fixtures |
| Local proof mistaken for grading | `local_public_proof` result kind, no private plan/score/finalization path, later controller validation |
| Docker authority enters application runtime | standalone developer harness only; Fastify/controller import and socket authority forbidden |

## Tasks

### ARC-SEC-001 — Build least-privilege server access

- [ ] Create a stateless publishable-key verifier client and a separate required
      secret domain client.
- [ ] Keep the raw secret client inside infrastructure and construct
      module-specific adapters only in the composition root.
- [ ] Use explicit column selection for every query.
- [ ] Disable session persistence, auto-refresh, and URL session detection in
      every server client.
- [ ] Pass verified `aal2` actor context to outbound ports explicitly; never accept
      actor ID from route body/query/params.

### ARC-SEC-002 — Define transactional functions

- [ ] Use database functions for multi-row reorder, quiz start, quiz submit,
      progress recalculation, and role changes.
- [ ] Give every cross-module transaction one coordinating use case and one
      module-owned public RPC facade; private SQL helpers may be shared, but a
      generic public function may not bypass module ownership.
- [ ] Set an explicit safe `search_path` in every security-definer function.
- [ ] Revoke function execution from `PUBLIC`, `anon`, and `authenticated` by
      default; grant named entry functions only to the server role used by the
      current secret key.
- [ ] Reload and verify the passed actor's current role/ownership inside
      functions even when Fastify checked it.
- [ ] Test concurrent calls and retry behavior.

### ARC-SEC-003 — Audit privileged actions

The accepted record is private and owner-controlled. Its changed_fields names
and change_summary keys match exactly. Each summary entry has only before/after
values from a finite safe-code vocabulary: role/lifecycle/state facts may be
recorded, while arbitrary content and user-facing text use redacted or are not
recorded. Reasons are optional approved codes, never free text; the named
privileged workflow enforces a non-null code when its product contract requires
one. The only allowed post-insert mutation is Auth foreign-key anonymization of
a deleted user actor.

- [x] Record actor kind (`user` or `system`), nullable actor user ID, action,
      entity type/ID, sanitized before/after summary,
      reason where required, request ID, and timestamp.
- [x] Do not store tokens, answer payloads, answer keys, or full Markdown bodies
      in audit rows; also exclude TOTP codes/secrets, QR/`otpauth` material,
      refresh tokens, and Auth SDK bodies.
- [x] Make audit events append-only to normal application roles.
