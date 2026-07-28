BEGIN;

GRANT USAGE ON SCHEMA extensions TO coditza_owner;

SELECT extensions.plan(25);

SELECT extensions.ok(
  (
    SELECT relation_entry.relowner = 'coditza_owner'::pg_catalog.regrole
    FROM pg_catalog.pg_class AS relation_entry
    WHERE relation_entry.oid = 'public.profiles'::pg_catalog.regclass
  ),
  'profiles is owned by coditza_owner'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
      = ARRAY[
        'id',
        'display_name',
        'role',
        'security_hold_at',
        'created_at',
        'updated_at'
      ]::text[]
    FROM pg_catalog.pg_attribute AS attribute_entry
    WHERE attribute_entry.attrelid = 'public.profiles'::pg_catalog.regclass
      AND attribute_entry.attnum > 0
      AND NOT attribute_entry.attisdropped
  ),
  'profiles has exactly the six approved non-secret projection columns'
);

SELECT extensions.ok(
  (
    SELECT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_attribute AS attribute_entry
      WHERE attribute_entry.attrelid = 'public.profiles'::pg_catalog.regclass
        AND attribute_entry.attname = 'id'
        AND attribute_entry.atttypid = 'uuid'::pg_catalog.regtype
        AND attribute_entry.attnotnull
    )
      AND EXISTS (
        SELECT 1
        FROM pg_catalog.pg_attribute AS attribute_entry
        WHERE attribute_entry.attrelid = 'public.profiles'::pg_catalog.regclass
          AND attribute_entry.attname = 'display_name'
          AND attribute_entry.atttypid = 'text'::pg_catalog.regtype
          AND attribute_entry.attnotnull
      )
      AND EXISTS (
        SELECT 1
        FROM pg_catalog.pg_attribute AS attribute_entry
        WHERE attribute_entry.attrelid = 'public.profiles'::pg_catalog.regclass
          AND attribute_entry.attname = 'role'
          AND attribute_entry.atttypid = 'public.app_role'::pg_catalog.regtype
          AND attribute_entry.attnotnull
      )
      AND EXISTS (
        SELECT 1
        FROM pg_catalog.pg_attribute AS attribute_entry
        WHERE attribute_entry.attrelid = 'public.profiles'::pg_catalog.regclass
          AND attribute_entry.attname = 'security_hold_at'
          AND attribute_entry.atttypid = 'timestamp with time zone'::pg_catalog.regtype
          AND NOT attribute_entry.attnotnull
      )
      AND (
        SELECT count(*) = 2
        FROM pg_catalog.pg_attribute AS attribute_entry
        WHERE attribute_entry.attrelid = 'public.profiles'::pg_catalog.regclass
          AND attribute_entry.attname IN ('created_at', 'updated_at')
          AND attribute_entry.atttypid = 'timestamp with time zone'::pg_catalog.regtype
          AND attribute_entry.attnotnull
          AND attribute_entry.atthasdef
      )
  ),
  'profiles uses the approved UUID, text, role, nullable hold, and timestamp types'
);

SELECT extensions.ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_constraint AS constraint_entry
    WHERE constraint_entry.conrelid = 'public.profiles'::pg_catalog.regclass
      AND constraint_entry.contype = 'p'
      AND constraint_entry.conkey = ARRAY[1]::smallint[]
  )
    AND EXISTS (
      SELECT 1
      FROM pg_catalog.pg_constraint AS constraint_entry
      WHERE constraint_entry.conrelid = 'public.profiles'::pg_catalog.regclass
        AND constraint_entry.contype = 'f'
        AND constraint_entry.conkey = ARRAY[1]::smallint[]
        AND constraint_entry.confrelid = 'auth.users'::pg_catalog.regclass
        AND constraint_entry.confdeltype = 'c'
    ),
  'profiles has an Auth-user primary-key foreign key with delete cascade'
);

SELECT extensions.ok(
  (
    SELECT relation_entry.relrowsecurity
      AND NOT relation_entry.relforcerowsecurity
    FROM pg_catalog.pg_class AS relation_entry
    WHERE relation_entry.oid = 'public.profiles'::pg_catalog.regclass
  )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_policy AS policy_entry
      WHERE policy_entry.polrelid = 'public.profiles'::pg_catalog.regclass
    ),
  'profiles has RLS enabled without force or permissive user policies'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_table_privilege(
      runtime_role.rolname,
      'public.profiles'::pg_catalog.regclass,
      'SELECT'
    )
      OR pg_catalog.has_table_privilege(
        runtime_role.rolname,
        'public.profiles'::pg_catalog.regclass,
        'INSERT'
      )
      OR pg_catalog.has_table_privilege(
        runtime_role.rolname,
        'public.profiles'::pg_catalog.regclass,
        'UPDATE'
      )
      OR pg_catalog.has_table_privilege(
        runtime_role.rolname,
        'public.profiles'::pg_catalog.regclass,
        'DELETE'
      )
      OR pg_catalog.has_column_privilege(
        runtime_role.rolname,
        'public.profiles'::pg_catalog.regclass,
        'role',
        'UPDATE'
      )
      OR pg_catalog.has_column_privilege(
        runtime_role.rolname,
        'public.profiles'::pg_catalog.regclass,
        'security_hold_at',
        'UPDATE'
      )
  ),
  'runtime roles have no direct profile read/write or role/hold update privilege'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_namespace AS namespace_entry
    CROSS JOIN LATERAL pg_catalog.unnest(namespace_entry.nspacl) AS acl_entry(item)
    WHERE namespace_entry.nspname = 'private'
      AND acl_entry.item::text OPERATOR(pg_catalog.~)
        '^(postgres|anon|authenticated|service_role|authenticator)='
  )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_type AS type_entry
      CROSS JOIN LATERAL pg_catalog.unnest(type_entry.typacl) AS acl_entry(item)
      WHERE type_entry.oid = 'public.app_role'::pg_catalog.regtype
        AND acl_entry.item::text OPERATOR(pg_catalog.~)
          '^(postgres|anon|authenticated|service_role|authenticator)='
    )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_proc AS procedure_entry
      CROSS JOIN LATERAL pg_catalog.unnest(procedure_entry.proacl) AS acl_entry(item)
      WHERE procedure_entry.oid = 'private.create_profile_for_auth_user()'::pg_catalog.regprocedure
        AND acl_entry.item::text OPERATOR(pg_catalog.~)
          '^(postgres|anon|authenticated|service_role|authenticator)='
    ),
  'migration-only temporary ACL entries are absent from the type, private schema, and trigger function'
);

SELECT extensions.ok(
  (
    SELECT procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
      AND procedure_entry.prosecdef
      AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid = 'private.create_profile_for_auth_user()'::pg_catalog.regprocedure
  ),
  'profile trigger function is owner-controlled SECURITY DEFINER with an empty search path'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('postgres'), ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_function_privilege(
      runtime_role.rolname,
      'private.create_profile_for_auth_user()'::pg_catalog.regprocedure,
      'EXECUTE'
    )
  ),
  'migration and runtime roles cannot call the profile trigger function directly'
);

SELECT extensions.ok(
  EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger AS trigger_entry
    WHERE trigger_entry.tgrelid = 'auth.users'::pg_catalog.regclass
      AND trigger_entry.tgfoid = 'private.create_profile_for_auth_user()'::pg_catalog.regprocedure
      AND NOT trigger_entry.tgisinternal
      AND (trigger_entry.tgtype::integer & 1) = 1
      AND (trigger_entry.tgtype::integer & 2) = 0
      AND (trigger_entry.tgtype::integer & 4) = 4
  ),
  'Auth profile trigger is an AFTER INSERT row trigger bound to the private function'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.pg_get_functiondef(procedure_entry.oid) LIKE '%NEW.raw_user_meta_data%'
      AND pg_catalog.pg_get_functiondef(procedure_entry.oid) LIKE '%displayName%'
      AND pg_catalog.pg_get_functiondef(procedure_entry.oid) LIKE '%ON CONFLICT (id) DO NOTHING%'
      AND pg_catalog.pg_get_functiondef(procedure_entry.oid) NOT LIKE '%NEW.email%'
      AND pg_catalog.pg_get_functiondef(procedure_entry.oid) NOT LIKE '%raw_app_meta_data%'
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid = 'private.create_profile_for_auth_user()'::pg_catalog.regprocedure
  ),
  'profile trigger reads only the approved displayName metadata input and is replay-safe'
);

INSERT INTO auth.users (
  id,
  aud,
  role,
  email,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
VALUES (
  '11111111-1111-1111-1111-111111111111',
  'authenticated',
  'authenticated',
  'valid-name-1111@profiles.invalid',
  '{}'::jsonb,
  '{"displayName":"Adela","role":"admin","securityHoldAt":"2099-01-01T00:00:00Z"}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
);

SELECT extensions.ok(
  (
    SELECT profile_entry.display_name = 'Adela'
    FROM public.profiles AS profile_entry
    WHERE profile_entry.id = '11111111-1111-1111-1111-111111111111'
  ),
  'an already-trimmed valid displayName metadata value is retained exactly'
);

SELECT extensions.ok(
  (
    SELECT profile_entry.role = 'learner'::public.app_role
      AND profile_entry.security_hold_at IS NULL
      AND profile_entry.created_at IS NOT NULL
      AND profile_entry.updated_at IS NOT NULL
    FROM public.profiles AS profile_entry
    WHERE profile_entry.id = '11111111-1111-1111-1111-111111111111'
  ),
  'client role and hold metadata are ignored while learner and null hold are explicit'
);

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET display_name = 'Adela'
WHERE id = '11111111-1111-1111-1111-111111111111';
RESET ROLE;

SELECT extensions.ok(
  (
    SELECT profile_entry.updated_at > profile_entry.created_at
    FROM public.profiles AS profile_entry
    WHERE profile_entry.id = '11111111-1111-1111-1111-111111111111'
  ),
  'the owner-only profile update trigger advances updated_at'
);

SET LOCAL ROLE coditza_owner;
DO $profiles_name_constraint$
BEGIN
  BEGIN
    UPDATE public.profiles
    SET display_name = ' Adela'
    WHERE id = '11111111-1111-1111-1111-111111111111';
    RAISE EXCEPTION 'untrimmed profile display names must fail';
  EXCEPTION
    WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE public.profiles
    SET display_name = ''
    WHERE id = '11111111-1111-1111-1111-111111111111';
    RAISE EXCEPTION 'blank profile display names must fail';
  EXCEPTION
    WHEN check_violation THEN NULL;
  END;

  BEGIN
    UPDATE public.profiles
    SET display_name = pg_catalog.repeat('x', 81)
    WHERE id = '11111111-1111-1111-1111-111111111111';
    RAISE EXCEPTION 'overlong profile display names must fail';
  EXCEPTION
    WHEN check_violation THEN NULL;
  END;
END;
$profiles_name_constraint$;
RESET ROLE;

SELECT extensions.ok(
  TRUE,
  'profile constraints reject direct untrimmed, blank, and overlong display names'
);

INSERT INTO auth.users (
  id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
VALUES (
  '22222222-2222-2222-2222-222222222222',
  'authenticated',
  'authenticated',
  'would-be-name-2222@profiles.invalid',
  '{}'::jsonb,
  '{}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
);

SELECT extensions.ok(
  (
    SELECT profile_entry.display_name = 'Learner'
    FROM public.profiles AS profile_entry
    WHERE profile_entry.id = '22222222-2222-2222-2222-222222222222'
  ),
  'missing displayName uses Learner rather than deriving a name from email'
);

INSERT INTO auth.users (
  id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
VALUES (
  '33333333-3333-3333-3333-333333333333',
  'authenticated',
  'authenticated',
  'json-null-3333@profiles.invalid',
  '{}'::jsonb,
  '{"displayName":null}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
);

SELECT extensions.ok(
  (
    SELECT profile_entry.display_name = 'Learner'
    FROM public.profiles AS profile_entry
    WHERE profile_entry.id = '33333333-3333-3333-3333-333333333333'
  ),
  'JSON-null displayName uses Learner'
);

INSERT INTO auth.users (
  id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
VALUES (
  '44444444-4444-4444-4444-444444444444',
  'authenticated',
  'authenticated',
  'non-string-4444@profiles.invalid',
  '{}'::jsonb,
  '{"displayName":["not-a-name"]}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
);

SELECT extensions.ok(
  (
    SELECT profile_entry.display_name = 'Learner'
    FROM public.profiles AS profile_entry
    WHERE profile_entry.id = '44444444-4444-4444-4444-444444444444'
  ),
  'non-string displayName uses Learner'
);

INSERT INTO auth.users (
  id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
VALUES (
  '55555555-5555-5555-5555-555555555555',
  'authenticated',
  'authenticated',
  'empty-and-untrimmed-5555@profiles.invalid',
  '{}'::jsonb,
  '{"displayName":""}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
), (
  '66666666-6666-6666-6666-666666666666',
  'authenticated',
  'authenticated',
  'untrimmed-6666@profiles.invalid',
  '{}'::jsonb,
  '{"displayName":" Adela "}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
);

SELECT extensions.ok(
  (
    SELECT count(*) = 2
      AND pg_catalog.bool_and(profile_entry.display_name = 'Learner')
    FROM public.profiles AS profile_entry
    WHERE profile_entry.id IN (
      '55555555-5555-5555-5555-555555555555',
      '66666666-6666-6666-6666-666666666666'
    )
  ),
  'empty and untrimmed displayName values use Learner'
);

INSERT INTO auth.users (
  id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
VALUES (
  '77777777-7777-7777-7777-777777777777',
  'authenticated',
  'authenticated',
  'overlong-7777@profiles.invalid',
  '{}'::jsonb,
  pg_catalog.jsonb_build_object('displayName', pg_catalog.repeat('x', 81)),
  pg_catalog.now(),
  pg_catalog.now()
);

SELECT extensions.ok(
  (
    SELECT profile_entry.display_name = 'Learner'
    FROM public.profiles AS profile_entry
    WHERE profile_entry.id = '77777777-7777-7777-7777-777777777777'
  ),
  'overlong displayName uses Learner'
);

INSERT INTO auth.users (
  id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
VALUES (
  '88888888-8888-8888-8888-888888888888',
  'authenticated',
  'authenticated',
  'snake-case-alias-8888@profiles.invalid',
  '{}'::jsonb,
  '{"display_name":"Alias must not be accepted"}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
);

SELECT extensions.ok(
  (
    SELECT profile_entry.display_name = 'Learner'
    FROM public.profiles AS profile_entry
    WHERE profile_entry.id = '88888888-8888-8888-8888-888888888888'
  ),
  'only the fixed camelCase displayName metadata key is accepted'
);

SET LOCAL ROLE coditza_owner;
GRANT USAGE ON SCHEMA private TO postgres;
GRANT EXECUTE ON FUNCTION private.create_profile_for_auth_user() TO postgres;
RESET ROLE;

CREATE TRIGGER _pgtap_duplicate_profile_trigger
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION private.create_profile_for_auth_user();

SET LOCAL ROLE coditza_owner;
REVOKE USAGE ON SCHEMA private FROM postgres;
REVOKE ALL ON FUNCTION private.create_profile_for_auth_user() FROM postgres;
RESET ROLE;

INSERT INTO auth.users (
  id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
VALUES (
  '99999999-9999-9999-9999-999999999999',
  'authenticated',
  'authenticated',
  'duplicate-trigger-9999@profiles.invalid',
  '{}'::jsonb,
  '{"displayName":"Duplicate safe"}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
);

SELECT extensions.ok(
  (
    SELECT count(*) = 1
      AND min(profile_entry.display_name) = 'Duplicate safe'
      AND min(profile_entry.role)::text = 'learner'
      AND bool_and(profile_entry.security_hold_at IS NULL)
    FROM public.profiles AS profile_entry
    WHERE profile_entry.id = '99999999-9999-9999-9999-999999999999'
  ),
  'a second bound trigger still leaves one learner profile after its grants are revoked'
);

SET LOCAL ROLE coditza_owner;
ALTER TABLE public.profiles
ADD CONSTRAINT _pgtap_profile_insertion_failure
CHECK (id <> 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid);
RESET ROLE;

DO $profile_insert_rollback$
DECLARE
  profile_insert_failed boolean := false;
BEGIN
  BEGIN
    INSERT INTO auth.users (
      id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
    )
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'authenticated',
      'authenticated',
      'rollback-aaaaaaaa@profiles.invalid',
      '{}'::jsonb,
      '{"displayName":"Rollback probe"}'::jsonb,
      pg_catalog.now(),
      pg_catalog.now()
    );
  EXCEPTION
    WHEN check_violation THEN
      profile_insert_failed := true;
  END;

  IF NOT profile_insert_failed THEN
    RAISE EXCEPTION 'the profile constraint must abort the Auth insert';
  END IF;
END;
$profile_insert_rollback$;

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM auth.users AS auth_user
    WHERE auth_user.id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  )
    AND NOT EXISTS (
      SELECT 1
      FROM public.profiles AS profile_entry
      WHERE profile_entry.id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    ),
  'a failed profile insertion rolls back the originating Auth-user insert'
);

INSERT INTO auth.users (
  id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
VALUES (
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'authenticated',
  'authenticated',
  'cascade-bbbbbbbb@profiles.invalid',
  '{}'::jsonb,
  '{"displayName":"Cascade probe"}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
);

DELETE FROM auth.users
WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM public.profiles AS profile_entry
    WHERE profile_entry.id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
  ),
  'deleting an Auth user cascades to its profile'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated')
    ) AS user_role(rolname)
    WHERE pg_catalog.has_table_privilege(
      user_role.rolname,
      'public.profiles'::pg_catalog.regclass,
      'SELECT'
    )
      OR pg_catalog.has_table_privilege(
        user_role.rolname,
        'public.profiles'::pg_catalog.regclass,
        'INSERT'
      )
      OR pg_catalog.has_table_privilege(
        user_role.rolname,
        'public.profiles'::pg_catalog.regclass,
        'UPDATE'
      )
      OR pg_catalog.has_table_privilege(
        user_role.rolname,
        'public.profiles'::pg_catalog.regclass,
        'DELETE'
      )
  ),
  'profile creation alone gives neither anonymous nor AAL1 user data access'
);

SELECT * FROM extensions.finish();

ROLLBACK;
