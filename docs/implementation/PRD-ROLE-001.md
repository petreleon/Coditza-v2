# PRD-ROLE-001 — Enforce default learner creation

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-28
Agent/person: Codex

Authorization checked: The user granted implementation. This was a local
requirement-verification task using the already approved SUP-AUTH-001 evidence;
it made no schema, Auth, hosted, or secret-dependent change.

Prerequisites/gate checked: SUP-AUTH-001 is complete at commit `04b8489`.
G2 remains open.

## Requirement-to-evidence mapping

| PRD-ROLE-001 requirement | Implemented local evidence |
| --- | --- |
| Create a profile row transactionally when an Auth user is created. | `on_auth_user_created_create_profile` is an `AFTER INSERT` row trigger on `auth.users`; the protected pgTAP suite inserts synthetic Auth rows and observes their profile rows. Its rollback assertion proves a failed profile insert aborts the originating Auth insert instead of leaving partial state. |
| Ignore a client-supplied role in sign-up metadata. | The trigger reads only `raw_user_meta_data.displayName`, explicitly inserts `'learner'::public.app_role`, and never reads role metadata. The valid-metadata pgTAP case supplies an attempted `admin` role and asserts stored `learner`. |
| Test a new user receives exactly `learner`. | The same protected suite proves one profile with the exact accepted display name, explicit `learner` role, null hold, and timestamps for a newly inserted synthetic Auth user. |
| Test duplicate trigger execution is safe. | The suite transactionally binds a second trigger to the same function after temporary ACLs are revoked, inserts one synthetic Auth row, and asserts exactly one unchanged learner profile through `ON CONFLICT (id) DO NOTHING`. |

## Verification

- Reviewed the committed migration, `auth_profiles_test.sql`, and
  [SUP-AUTH-001 completion report](SUP-AUTH-001.md).
- The source task's protected `npm run supabase:verify-auth-profiles:local`
  evidence passed 53 pgTAP assertions total (primitive regression plus 25
  profile assertions), fresh reset/history/diff/lint checks, loopback-only
  inspection, and the Dockerized Node 24 foundation gate.
- No new test run was necessary: this task only maps unchanged committed
  evidence to the product checklist. No implementation evidence was inferred
  beyond that report.

## Deliberate boundary

This verifies default learner creation at the local database level only. It does
not claim that a user has completed TOTP enrollment, possesses an AAL2 session,
or may use any Fastify domain route. SUP-MFA-001 and later Fastify/RLS tasks
remain responsible for those guarantees.

## External actions and secret safety

No Docker, Chrome, Dashboard, hosted Supabase, Gmail, SMTP, Vercel, credential,
or account action occurred during this verification. No Auth body, factor,
TOTP/QR/`otpauth` material, token, email, or other sensitive data was recorded.

## Next

SUP-DATA-001 is the sole next eligible task. It owns the local core hierarchy
schema and its task-owned proof; SMTP/MFA remains separately blocked by its
explicit prerequisites.
