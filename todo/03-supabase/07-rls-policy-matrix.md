# Row Level Security and grants

## Chosen trust model

Fastify is the only Coditza domain API. A browser/client may call Supabase
directly only for Auth. Both `aal1` and `aal2` user tokens remain denied from
Coditza tables/functions; requiring MFA must never accidentally grant direct
Data API access. This is enforced at PostgreSQL/Data API level:

- `PUBLIC`, `anon`, and `authenticated` receive no direct Coditza table,
  sequence, private-schema, or workflow-function access;
- RLS is enabled on every `public` table and has no permissive user policy;
- the current Supabase secret key maps to the server role and bypasses RLS, so
  the raw client is a high-impact secret restricted to one database plugin;
- bypassing RLS does not authorize direct Coditza writes: revoke table DML from
  the runtime role and grant it only exact safe-column reads plus entry-function
  execute;
- server adapters/functions accept a Fastify-verified actor ID separately,
  reload its current Coditza role/ownership, and enforce domain rules;
- PostgreSQL does **not** claim to cryptographically derive the end user with
  `auth.uid()` on a secret-key call. Fastify is that authorization boundary.
- PostgreSQL cannot independently inspect the original end-user `aal` on a
  secret-key server call. Fastify verifies `aal2`; database functions then
  recheck the passed actor's current role/ownership/state.

Revalidate current key/role behavior against official Supabase documentation
before implementing migrations.

## Exact owner/execution pattern

- Migrations create one `coditza_owner` PostgreSQL role with
  `NOLOGIN NOINHERIT NOBYPASSRLS NOCREATEDB NOCREATEROLE NOREPLICATION`.
- `coditza_owner` owns every Coditza `public`/`private` table, sequence, helper,
  and security-definer function. The migration operator may create/alter those
  objects, but the API runtime never receives that operator identity.
- RLS is enabled on every Coditza public table but is **not** forced. PostgreSQL
  therefore lets the table-owning security-definer role execute the named
  function body while user-facing roles remain policy-denied.
- The secret-mapped runtime role has no membership in `coditza_owner`, cannot
  `SET ROLE` to it, does not own any entry function/table/schema, and receives
  only exact safe-column reads plus exact entry-function `EXECUTE`.
- Every entry function is `SECURITY DEFINER`, owned by `coditza_owner`, uses an
  empty/fixed search path with schema-qualified references, and reloads the
  passed actor. Helpers are not executable by the runtime role.
- Do not enable `FORCE ROW LEVEL SECURITY` on these owner-executed tables unless
  a later migration first introduces and tests explicit owner-role policies.
- If a target platform cannot create/preserve this role and ownership pattern,
  stop the remote migration. Do not silently make `service_role` the owner or
  add permissive user policies.

## Direct-access matrix

| Resource/action | `anon` | `authenticated` (any Coditza role) | server secret role |
| --- | --- | --- | --- |
| Profiles/content/attempts/progress select | Deny | Deny | Narrow explicit projections |
| Direct table insert/update/delete | Deny | Deny | Deny; named security-definer functions only |
| Answer-key/private tables | Deny | Deny | No direct access; function owner accesses only inside named functions |
| Learner workflow functions | Deny | Deny | Execute with verified actor ID |
| Staff/admin workflow functions | Deny | Deny | Execute with verified actor ID |
| Audit/idempotency | Deny | Deny | Named adapter/function only |
| Identity security hold | Deny | Deny | Named operator system function only; absent from HTTP composition |

The learner/editor/admin capability matrix is enforced and tested through
Fastify plus server-only functions, not by exposing direct Data API policies.

## Migration requirements

- Apply grants/revokes only to Coditza-owned objects created by these migrations
  in `public` and `private`, for every actual migration owner.
- Never alter privileges, default privileges, or objects in Supabase-managed
  `auth`, `storage`, extension/system schemas, or unrelated project functions.
- Revoke all Coditza-owned table/sequence/function privileges from `PUBLIC`,
  `anon`, and `authenticated`.
- Set equivalent default privileges for future objects so a new table/function
  does not become callable accidentally.
- Do not list `private` among Data API exposed schemas.
- Revoke `private` table access from all user-facing roles and grant the server
  runtime role no direct private-table access.
- Revoke `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE`, `REFERENCES`, and `TRIGGER` on
  every Coditza table from the secret-mapped runtime role. Grant only the exact
  safe public-table `SELECT` columns required by named read adapters.
- Apply/verify the exact `coditza_owner` ownership pattern above; do not replace
  it with a vaguely privileged runtime or migration role.
- Revoke function execution from `PUBLIC` after every function creation.
- Grant server-role execute only on exact entry functions; helpers remain
  private/not directly executable.
- Enable RLS immediately in the same migration that creates each public table.
- Use explicit safe column selects in server reads despite server bypass.
- Index actor/owner/parent/status columns used by server authorization queries.

## Function actor contract

- Fastify extracts `userId` from a verified token; route bodies cannot contain
  or override it.
- A module-specific outbound adapter calls a server-only function with
  `p_actor_user_id`.
- Function locks/loads that profile and checks its current Coditza role.
- Learner functions require actor ownership; staff functions require exact role.
- System jobs use distinct system entry functions and audit `actor_kind=system`,
  never a fabricated user.
- Identity security hold uses its dedicated operator system entry function and
  is never wired to an HTTP route or ordinary module use-case facade.
- First-admin bootstrap is the one no-existing-admin system workflow and is
  serialized/audited.

## SUP-RLS-001 — Prove direct denial and server authorization

Direct Data API tests with real local Auth contexts:

- [ ] anonymous cannot read or mutate any Coditza domain table/function;
- [ ] learner A/B, editor, and admin tokens all receive the same direct denial;
- [ ] otherwise valid `aal1` and `aal2` tokens receive the same direct denial;
- [ ] no user token can access the `private` schema or named server workflow;
- [ ] no user token can execute the operator identity-security-hold function;
- [ ] default privileges keep a newly created test object closed.

Server-path tests:

- [ ] a valid secret client can call only granted named functions;
- [ ] owner inspection proves every Coditza table/entry function is owned by
      `coditza_owner`, RLS is enabled/not forced, and the role has the exact
      NOLOGIN/NOINHERIT/NOBYPASSRLS attributes;
- [ ] runtime membership/`SET ROLE coditza_owner` fails, while runtime
      `EXECUTE` on a named function succeeds through the definer owner;
- [ ] the secret-mapped runtime role is denied direct insert/update/delete on
      every Coditza public/private table and denied all direct private reads;
- [ ] each allowed public read proves its exact safe column projection, while a
      forbidden column read fails at PostgreSQL privilege level;
- [ ] learner actor succeeds only for own allowed API workflow;
- [ ] learner actor cannot impersonate another passed actor through any public
      route because Fastify supplies the actor separately;
- [ ] editor/admin role checks, final-admin rules, and ownership checks run again
      inside functions;
- [ ] functions return safe projections with no answer key/private columns;
- [ ] raw secret client is absent from route/domain imports and logs.

Test grants separately from RLS state and test the Fastify role matrix
separately from direct Data API denial.
