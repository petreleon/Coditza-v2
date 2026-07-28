BEGIN;

GRANT USAGE ON SCHEMA extensions TO coditza_owner;

SELECT extensions.plan(28);

SET LOCAL ROLE coditza_owner;

CREATE TABLE private._pgtap_default_table (
  id integer PRIMARY KEY
);
CREATE SEQUENCE private._pgtap_default_sequence;
CREATE TYPE private._pgtap_default_type AS ENUM ('probe');
CREATE FUNCTION private._pgtap_default_function()
RETURNS integer
LANGUAGE sql
IMMUTABLE
SET search_path = ''
AS $default_function$
  SELECT 1;
$default_function$;
CREATE TABLE private._pgtap_updated_at_probe (
  id integer PRIMARY KEY,
  payload integer NOT NULL,
  updated_at timestamptz NOT NULL
);
CREATE TRIGGER _pgtap_set_updated_at
BEFORE UPDATE ON private._pgtap_updated_at_probe
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();
INSERT INTO private._pgtap_updated_at_probe (id, payload, updated_at)
VALUES (1, 0, '2000-01-01 00:00:00+00');
UPDATE private._pgtap_updated_at_probe
SET payload = 1
WHERE id = 1;

SELECT extensions.ok(
  (
    SELECT NOT rolsuper
      AND NOT rolcanlogin
      AND NOT rolinherit
      AND NOT rolbypassrls
      AND NOT rolcreaterole
      AND NOT rolcreatedb
      AND NOT rolreplication
      AND rolconnlimit = -1
      AND rolvaliduntil = 'infinity'::pg_catalog.timestamptz
      AND rolconfig IS NULL
    FROM pg_catalog.pg_roles
    WHERE rolname = 'coditza_owner'
  ),
  'coditza_owner has the exact non-login, non-privileged attributes'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE (
      membership.roleid = 'coditza_owner'::pg_catalog.regrole
      OR membership.member = 'coditza_owner'::pg_catalog.regrole
    )
      AND NOT (
        membership.roleid = 'coditza_owner'::pg_catalog.regrole
        AND membership.member = 'postgres'::pg_catalog.regrole
        AND NOT membership.inherit_option
        AND (
          (membership.admin_option AND NOT membership.set_option)
          OR (NOT membership.admin_option AND membership.set_option)
        )
      )
  )
    AND EXISTS (
      SELECT 1
      FROM pg_catalog.pg_auth_members AS membership
      WHERE membership.roleid = 'coditza_owner'::pg_catalog.regrole
        AND membership.member = 'postgres'::pg_catalog.regrole
        AND NOT membership.admin_option
        AND NOT membership.inherit_option
        AND membership.set_option
    )
    AND pg_catalog.pg_has_role('postgres', 'coditza_owner', 'SET'),
  'only the migration operator has the documented non-inheriting owner memberships'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.pg_has_role(
      runtime_role.rolname,
      'coditza_owner',
      'SET'
    )
  ),
  'no runtime role can set the owner role'
);

SELECT extensions.ok(
  pg_catalog.to_regnamespace('private') IS NOT NULL,
  'private schema exists'
);

SELECT extensions.ok(
  (
    SELECT nspowner = 'coditza_owner'::pg_catalog.regrole
    FROM pg_catalog.pg_namespace
    WHERE nspname = 'private'
  ),
  'private schema is owned by coditza_owner'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_schema_privilege(runtime_role.rolname, 'private', 'USAGE')
      OR pg_catalog.has_schema_privilege(runtime_role.rolname, 'private', 'CREATE')
  ),
  'runtime roles have no private-schema access'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(enum_value.enumlabel::text ORDER BY enum_value.enumsortorder)
    FROM pg_catalog.pg_enum AS enum_value
    WHERE enum_value.enumtypid = 'public.app_role'::pg_catalog.regtype
  ) = ARRAY['learner', 'editor', 'admin']::text[],
  'app_role labels and order are exact'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(enum_value.enumlabel::text ORDER BY enum_value.enumsortorder)
    FROM pg_catalog.pg_enum AS enum_value
    WHERE enum_value.enumtypid = 'public.content_status'::pg_catalog.regtype
  ) = ARRAY['draft', 'published', 'archived']::text[],
  'content_status labels and order are exact'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(enum_value.enumlabel::text ORDER BY enum_value.enumsortorder)
    FROM pg_catalog.pg_enum AS enum_value
    WHERE enum_value.enumtypid = 'public.exercise_type'::pg_catalog.regtype
  ) = ARRAY[
    'single_choice',
    'multiple_choice',
    'short_text',
    'python_code'
  ]::text[],
  'exercise_type labels and order are exact'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(enum_value.enumlabel::text ORDER BY enum_value.enumsortorder)
    FROM pg_catalog.pg_enum AS enum_value
    WHERE enum_value.enumtypid = 'public.question_type'::pg_catalog.regtype
  ) = ARRAY['single_choice', 'multiple_choice', 'short_text']::text[],
  'question_type labels and order are exact'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(enum_value.enumlabel::text ORDER BY enum_value.enumsortorder)
    FROM pg_catalog.pg_enum AS enum_value
    WHERE enum_value.enumtypid = 'public.quiz_attempt_status'::pg_catalog.regtype
  ) = ARRAY['in_progress', 'submitted', 'expired']::text[],
  'quiz_attempt_status labels and order are exact'
);

SELECT extensions.ok(
  (
    SELECT count(*) = 5
      AND pg_catalog.bool_and(type_entry.typowner = 'coditza_owner'::pg_catalog.regrole)
    FROM pg_catalog.pg_type AS type_entry
    WHERE type_entry.oid IN (
      'public.app_role'::pg_catalog.regtype,
      'public.content_status'::pg_catalog.regtype,
      'public.exercise_type'::pg_catalog.regtype,
      'public.question_type'::pg_catalog.regtype,
      'public.quiz_attempt_status'::pg_catalog.regtype
    )
  ),
  'all primitive public types are owned by coditza_owner'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    CROSS JOIN pg_catalog.pg_type AS type_entry
    WHERE type_entry.oid IN (
      'public.app_role'::pg_catalog.regtype,
      'public.content_status'::pg_catalog.regtype,
      'public.exercise_type'::pg_catalog.regtype,
      'public.question_type'::pg_catalog.regtype,
      'public.quiz_attempt_status'::pg_catalog.regtype
    )
      AND pg_catalog.has_type_privilege(runtime_role.rolname, type_entry.oid, 'USAGE')
  ),
  'runtime roles have no direct primitive-type usage'
);

SELECT extensions.ok(
  (
    SELECT count(*) = 3
      AND pg_catalog.bool_and(procedure.proowner = 'coditza_owner'::pg_catalog.regrole)
    FROM pg_catalog.pg_proc AS procedure
    WHERE procedure.oid IN (
      'private.set_updated_at()'::pg_catalog.regprocedure,
      'private.normalize_short_text(text)'::pg_catalog.regprocedure,
      'private.is_valid_slug(text)'::pg_catalog.regprocedure
    )
  ),
  'all primitive helpers are owned by coditza_owner'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    CROSS JOIN pg_catalog.pg_proc AS procedure
    WHERE procedure.oid IN (
      'private.set_updated_at()'::pg_catalog.regprocedure,
      'private.normalize_short_text(text)'::pg_catalog.regprocedure,
      'private.is_valid_slug(text)'::pg_catalog.regprocedure
    )
      AND pg_catalog.has_function_privilege(
        runtime_role.rolname,
        procedure.oid,
        'EXECUTE'
      )
  ),
  'runtime roles have no direct primitive-helper execution'
);

SELECT extensions.ok(
  (
    SELECT count(*) = 3
      AND pg_catalog.bool_and(
        procedure.proconfig @> ARRAY['search_path=""']::text[]
      )
    FROM pg_catalog.pg_proc AS procedure
    WHERE procedure.oid IN (
      'private.set_updated_at()'::pg_catalog.regprocedure,
      'private.normalize_short_text(text)'::pg_catalog.regprocedure,
      'private.is_valid_slug(text)'::pg_catalog.regprocedure
    )
  ),
  'primitive helpers use an explicit empty search path'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_table_privilege(
      runtime_role.rolname,
      'private._pgtap_default_table'::pg_catalog.regclass,
      'SELECT'
    )
  ),
  'owner default privileges deny future table reads'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_sequence_privilege(
      runtime_role.rolname,
      'private._pgtap_default_sequence'::pg_catalog.regclass,
      'USAGE'
    )
  ),
  'owner default privileges deny future sequence usage'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_function_privilege(
      runtime_role.rolname,
      'private._pgtap_default_function()'::pg_catalog.regprocedure,
      'EXECUTE'
    )
  ),
  'owner default privileges deny future function execution'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_type_privilege(
      runtime_role.rolname,
      'private._pgtap_default_type'::pg_catalog.regtype,
      'USAGE'
    )
  ),
  'owner default privileges deny future type usage'
);

SELECT extensions.ok(
  (
    SELECT updated_at > '2000-01-01 00:00:00+00'::pg_catalog.timestamptz
    FROM private._pgtap_updated_at_probe
    WHERE id = 1
  ),
  'set_updated_at changes updated_at during an update'
);

SELECT extensions.ok(
  private.normalize_short_text(E'\t  ABC\r\nDEF  ') = 'abc def',
  'normalize_short_text collapses ASCII whitespace and lowercases ASCII only'
);

SELECT extensions.ok(
  private.normalize_short_text('Ａ') = 'a',
  'normalize_short_text applies NFKC before ASCII lowercase translation'
);

SELECT extensions.ok(
  private.normalize_short_text('É') = 'É',
  'normalize_short_text does not locale-lowercase non-ASCII letters'
);

SELECT extensions.ok(
  private.normalize_short_text(NULL) IS NULL,
  'normalize_short_text preserves null input'
);

SELECT extensions.ok(
  private.is_valid_slug('architecture-python'),
  'is_valid_slug accepts lowercase kebab-case slugs'
);

SELECT extensions.ok(
  NOT private.is_valid_slug(' architecture-python')
    AND NOT private.is_valid_slug('Architecture-python')
    AND NOT private.is_valid_slug('architecture--python')
    AND NOT private.is_valid_slug(''),
  'is_valid_slug rejects untrimmed or malformed values'
);

SELECT extensions.ok(
  pg_catalog.to_regtype('private.authored_resource_type') IS NULL,
  'the conditional authored_resource_type is not created without a helper need'
);

RESET ROLE;

SELECT * FROM extensions.finish();

ROLLBACK;
