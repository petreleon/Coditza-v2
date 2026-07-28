-- SUP-PRIMITIVES-001: foundational Coditza database objects only.
-- No Auth profiles, content tables, RLS policies, users, fixtures, or public
-- workflow RPCs belong in this migration.
BEGIN;

DO $coditza_owner$
DECLARE
  owner_role oid;
  postgres_role oid;
BEGIN
  SELECT oid
  INTO owner_role
  FROM pg_catalog.pg_roles
  WHERE rolname = 'coditza_owner';

  SELECT oid
  INTO postgres_role
  FROM pg_catalog.pg_roles
  WHERE rolname = 'postgres';

  IF postgres_role IS NULL THEN
    RAISE EXCEPTION 'The reviewed migration operator role is unavailable.';
  END IF;

  IF owner_role IS NOT NULL THEN
    IF EXISTS (
      SELECT 1
      FROM pg_catalog.pg_roles
      WHERE oid = owner_role
        AND rolsuper
    ) THEN
      RAISE EXCEPTION 'The pre-existing coditza_owner role is a superuser.';
    END IF;

    IF EXISTS (
      SELECT 1
      FROM pg_catalog.pg_shdepend AS dependency
      WHERE dependency.refclassid = 'pg_authid'::pg_catalog.regclass
        AND dependency.refobjid = owner_role
        AND dependency.deptype = 'o'
    ) THEN
      RAISE EXCEPTION
        'The pre-existing coditza_owner role has unexpected object ownership.';
    END IF;

    IF EXISTS (
      SELECT 1
      FROM pg_catalog.pg_auth_members AS membership
      WHERE (membership.roleid = owner_role OR membership.member = owner_role)
        AND NOT (
          membership.roleid = owner_role
          AND membership.member = postgres_role
          AND NOT membership.inherit_option
          AND (
            (membership.admin_option AND NOT membership.set_option)
            OR (NOT membership.admin_option AND membership.set_option)
          )
        )
    ) THEN
      RAISE EXCEPTION
        'The pre-existing coditza_owner role has unsafe role membership.';
    END IF;
  ELSE
    CREATE ROLE coditza_owner
      NOSUPERUSER
      NOLOGIN
      NOINHERIT
      NOBYPASSRLS
      NOCREATEDB
      NOCREATEROLE
      NOREPLICATION
      CONNECTION LIMIT -1
      PASSWORD NULL
      VALID UNTIL 'infinity';

    SELECT oid
    INTO owner_role
    FROM pg_catalog.pg_roles
    WHERE rolname = 'coditza_owner';
  END IF;

  ALTER ROLE coditza_owner
    NOLOGIN
    NOINHERIT
    NOBYPASSRLS
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    CONNECTION LIMIT -1
    PASSWORD NULL
    VALID UNTIL 'infinity';
  ALTER ROLE coditza_owner RESET ALL;

  -- PostgreSQL gives a non-superuser CREATEROLE operator an immutable
  -- admin-only creator membership (ADMIN TRUE, INHERIT FALSE, SET FALSE).
  -- postgres is a trusted migration-only operator, never a Fastify or Data API
  -- runtime credential.
  -- Remove any separately issued migration-operator membership, then add the
  -- only permitted usable edge: SET-only and non-inheriting.
  REVOKE coditza_owner FROM postgres;
  GRANT coditza_owner TO postgres
    WITH ADMIN FALSE, INHERIT FALSE, SET TRUE;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_roles
    WHERE oid = owner_role
      AND NOT rolsuper
      AND NOT rolcanlogin
      AND NOT rolinherit
      AND NOT rolbypassrls
      AND NOT rolcreaterole
      AND NOT rolcreatedb
      AND NOT rolreplication
      AND rolconnlimit = -1
      AND rolvaliduntil = 'infinity'::pg_catalog.timestamptz
      AND rolconfig IS NULL
  ) THEN
    RAISE EXCEPTION 'The coditza_owner role attributes are unsafe.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE (membership.roleid = owner_role OR membership.member = owner_role)
      AND NOT (
        membership.roleid = owner_role
        AND membership.member = postgres_role
        AND NOT membership.inherit_option
        AND (
          (membership.admin_option AND NOT membership.set_option)
          OR (NOT membership.admin_option AND membership.set_option)
        )
      )
  )
  OR NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_auth_members AS membership
    WHERE membership.roleid = owner_role
      AND membership.member = postgres_role
      AND NOT membership.admin_option
      AND NOT membership.inherit_option
      AND membership.set_option
  )
  OR NOT pg_catalog.pg_has_role(postgres_role, owner_role, 'SET') THEN
    RAISE EXCEPTION 'The coditza_owner role membership is unsafe.';
  END IF;
END;
$coditza_owner$;

DO $private_schema$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_namespace
    WHERE nspname = 'private'
  ) THEN
    RAISE EXCEPTION 'The private schema already exists and cannot be reused.';
  END IF;
END;
$private_schema$;

GRANT USAGE, CREATE ON SCHEMA public TO coditza_owner;
CREATE SCHEMA private AUTHORIZATION coditza_owner;

SET LOCAL ROLE coditza_owner;

ALTER DEFAULT PRIVILEGES REVOKE ALL ON TABLES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE USAGE ON TYPES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON SCHEMAS FROM PUBLIC;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON TABLES FROM anon, authenticated, service_role, authenticator;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON SEQUENCES FROM anon, authenticated, service_role, authenticator;
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM anon, authenticated, service_role, authenticator;
ALTER DEFAULT PRIVILEGES REVOKE USAGE ON TYPES FROM anon, authenticated, service_role, authenticator;
ALTER DEFAULT PRIVILEGES REVOKE ALL ON SCHEMAS FROM anon, authenticated, service_role, authenticator;

CREATE TYPE public.app_role AS ENUM ('learner', 'editor', 'admin');
CREATE TYPE public.content_status AS ENUM ('draft', 'published', 'archived');
CREATE TYPE public.exercise_type AS ENUM (
  'single_choice',
  'multiple_choice',
  'short_text',
  'python_code'
);
CREATE TYPE public.question_type AS ENUM (
  'single_choice',
  'multiple_choice',
  'short_text'
);
CREATE TYPE public.quiz_attempt_status AS ENUM (
  'in_progress',
  'submitted',
  'expired'
);

CREATE FUNCTION private.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $set_updated_at$
BEGIN
  IF TG_OP <> 'UPDATE' THEN
    RAISE EXCEPTION 'private.set_updated_at may run only for UPDATE triggers.';
  END IF;

  NEW.updated_at := pg_catalog.clock_timestamp();
  RETURN NEW;
END;
$set_updated_at$;

CREATE FUNCTION private.normalize_short_text(input text)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
SECURITY INVOKER
SET search_path = ''
AS $normalize_short_text$
  SELECT pg_catalog.translate(
    pg_catalog.btrim(
      pg_catalog.regexp_replace(
        pg_catalog.normalize(input, 'NFKC'),
        E'[\\x09-\\x0D\\x20]+',
        ' ',
        'g'
      ),
      ' '
    ),
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
    'abcdefghijklmnopqrstuvwxyz'
  );
$normalize_short_text$;

CREATE FUNCTION private.is_valid_slug(input text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
SECURITY INVOKER
SET search_path = ''
AS $is_valid_slug$
  SELECT input = pg_catalog.btrim(input, ' ')
    AND input OPERATOR(pg_catalog.~) '^[a-z0-9]+(?:-[a-z0-9]+)*$';
$is_valid_slug$;

REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON TYPE public.app_role, public.content_status, public.exercise_type,
  public.question_type, public.quiz_attempt_status
  FROM PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.set_updated_at(), private.normalize_short_text(text),
  private.is_valid_slug(text)
  FROM PUBLIC, anon, authenticated, service_role, authenticator;

RESET ROLE;

COMMIT;
