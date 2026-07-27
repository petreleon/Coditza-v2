# Deterministic seed data and generated types

## Seed content

Use fixed UUIDs reserved for local/test data and explicit positions. Include:

- one fully published module;
- two published chapters;
- at least two theory sections;
- one exercise of each supported type;
- the local `python_code` exercise uses only small deterministic fixtures,
  references the exact pinned runtime profile, and has no network/package
  download or hidden secret;
- one quiz containing each supported question type;
- one draft module with draft descendants;
- one archived assessment;
- required and optional assessment examples;
- answer keys in the private schema.

All learner-visible fixture text is Romanian. The published local fixture uses
an obvious title/slug such as `[TEST] Arhitectură software în Python` /
`test-arhitectura-python`; it is minimal schema/security test data, not the
canonical real course and never uses the reserved production slug
`arhitectura-software-python`. The real Module 1 source follows
`../../todo-curriculum-ro/`.

Normal development seeds contain authored content only. Authentication users,
attempts, and progress belong in test fixtures so production cannot accidentally
receive demo accounts/history.

## Rules

- No real email, password, access token, key, project reference, or production
  identifier.
- Seed data is deterministic after every clean reset.
- Seed order follows foreign keys.
- Seeds contain data, not schema definitions.
- Never apply development seed automatically to production.
- A published seed hierarchy must satisfy every publish validator.
- Seed Romanian must use correct diacritics and must not silently become the
  production curriculum source.

## SUP-SEED-001 — Add fixtures

- [ ] Create content seed data.
- [ ] Create isolated integration-test users for learner A, learner B, editor,
      and admin through test setup.
- [ ] Enroll synthetic TOTP factors only through Supabase Auth test helpers;
      never seed `auth` factor tables or persist seeds/codes/QR material.
- [ ] Assign roles through the tested bootstrap/admin path.
- [ ] Add attempt/progress fixtures only inside tests that need them.
- [ ] Prove a clean reset recreates the same IDs/order.
- [ ] Prove a user client cannot read seeded keys.
- [ ] Prove the Python public projection omits its private test bundle and
      hidden-test metadata.

## SUP-TYPES-001 — Generate database types

- [ ] Generate TypeScript types from the clean local schema.
- [ ] Store them at
      `apps/api/src/infrastructure/supabase/database.types.ts`.
- [ ] Add a generated-file header and never hand-edit them.
- [ ] Add a script that regenerates types.
- [ ] In CI, regenerate to a temporary/output path and fail on diff.
- [ ] Regenerate in every schema-changing task before completion.
