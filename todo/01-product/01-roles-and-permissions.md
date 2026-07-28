# Roles and permissions

## Role source

`public.profiles.role` is the authoritative role. New users receive `learner`.
Only an admin-only audited server operation may grant or revoke `editor` or
`admin`. A user cannot update their own role.

## Capability matrix

| Capability | Anonymous | Learner | Editor | Admin |
| --- | ---: | ---: | ---: | ---: |
| Use Supabase sign-up/sign-in | Yes | Yes | Yes | Yes |
| Enroll/challenge own TOTP factor through Supabase Auth | After account creation | Yes | Yes | Yes |
| Read own profile | No | Yes | Yes | Yes |
| Update own display name | No | Yes | Yes | Yes |
| Read published catalog/content | No | Yes | Yes | Yes |
| Mark own theory complete | No | Yes | Yes | Yes |
| Submit/read own attempts | No | Yes | Yes | Yes |
| Read own progress | No | Yes | Yes | Yes |
| Read another learner's data | No | No | No | No by default |
| Read draft/archived content | No | No | Yes | Yes |
| Create/edit/publish/archive content | No | No | Yes | Yes |
| Read answer keys from learner/read APIs | No | No | No | No |
| Manage draft answer keys through protected authoring API | No | No | Yes | Yes |
| Change staff roles | No | No | No | Yes |
| Change hosted environment settings | No | No | No | Separately authorized operator action |

Every Coditza capability below direct Supabase Auth requires a genuine `aal2`
session. Role never bypasses MFA. An active identity security hold overrides
every learner/editor/admin domain capability until the operator recovery
sequence clears it; it does not block the direct Supabase Auth steps needed to
enroll a fresh factor.

## Planned tasks

### PRD-ROLE-001 — Enforce default learner creation

- [x] Create a profile row transactionally when an Auth user is created.
- [x] Ignore any client-supplied role in sign-up metadata.
- [x] Test a new user receives exactly `learner`.
- [x] Test duplicate trigger execution is safe.

### PRD-ROLE-002 — Enforce authorization at three layers

- [ ] Inbound adapter requires a valid `aal2` principal and, where needed, a
      role.
- [ ] Application use case and authoritative PostgreSQL RPC check their assigned
      capability/state responsibilities.
- [ ] RLS/grants deny direct access that the API does not intend.
- [ ] Outbound adapters requiring the secret client are constructed only in the
      composition root and are not exported to arbitrary HTTP code.

### PRD-ROLE-003 — Build admin role change behavior

- [ ] Accept target user ID, target role, and mandatory reason.
- [ ] Disallow changing one's own last-admin role.
- [ ] Ensure at least one admin remains.
- [ ] Write an audit event with actor, target, previous/new role, reason, time,
      and request ID.
- [ ] Never return Auth credentials or sensitive metadata.

The mandatory reason is the approved role_change reason code, not user-provided
free text. The audit delta records only the safe previous/new role codes
learner, editor, or admin; it never records profile/Auth metadata.

## Acceptance examples

- A learner calling an editor route receives `403 role_required`.
- An editor calling a role-management route receives `403 role_required`.
- An admin cannot demote the only remaining admin.
- Changing a role takes effect on the next API request because role lookup uses
  current profile data rather than stale user-editable JWT metadata.
