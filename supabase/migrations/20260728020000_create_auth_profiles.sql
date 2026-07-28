-- SUP-AUTH-001: create the minimal Coditza profile projection for each Auth
-- identity. Supabase Auth remains authoritative for all credentials, sessions,
-- factors, and MFA state.
BEGIN;

-- The trusted migration operator can reference auth.users, but it must not own
-- Coditza application objects. Give it temporary type access only so it can
-- create the FK-bearing table, then transfer ownership and revoke before the
-- transaction commits. This never grants coditza_owner access to auth.*.
SET LOCAL ROLE coditza_owner;
GRANT USAGE ON TYPE public.app_role TO postgres;
RESET ROLE;

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name text NOT NULL,
  role public.app_role NOT NULL DEFAULT 'learner'::public.app_role,
  security_hold_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT profiles_display_name_trimmed_length_check CHECK (
    display_name = pg_catalog.btrim(display_name)
    AND pg_catalog.char_length(display_name) BETWEEN 1 AND 80
  )
);

ALTER TABLE public.profiles OWNER TO coditza_owner;

SET LOCAL ROLE coditza_owner;

REVOKE USAGE ON TYPE public.app_role FROM postgres;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

CREATE TRIGGER profiles_set_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

-- Auth metadata is client-controlled JSON. SUP-AUTH-001 accepts exactly the
-- fixed camelCase `displayName` key and only an already-trimmed JSON string.
-- Nothing is derived from the Auth email or any factor/session metadata.
CREATE FUNCTION private.create_profile_for_auth_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $create_profile_for_auth_user$
DECLARE
  candidate_display_name text;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RAISE EXCEPTION
      'private.create_profile_for_auth_user may run only for INSERT triggers.';
  END IF;

  IF pg_catalog.jsonb_typeof(NEW.raw_user_meta_data -> 'displayName') = 'string' THEN
    candidate_display_name := NEW.raw_user_meta_data ->> 'displayName';
  END IF;

  IF candidate_display_name IS NULL
    OR candidate_display_name <> pg_catalog.btrim(candidate_display_name)
    OR pg_catalog.char_length(candidate_display_name) NOT BETWEEN 1 AND 80 THEN
    candidate_display_name := 'Learner';
  END IF;

  INSERT INTO public.profiles (
    id,
    display_name,
    role,
    security_hold_at
  )
  VALUES (
    NEW.id,
    candidate_display_name,
    'learner'::public.app_role,
    NULL
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
END;
$create_profile_for_auth_user$;

-- CREATE TRIGGER checks the trigger function ACL. The trusted migration
-- operator receives temporary private-schema/function access solely to bind
-- the trigger, and every temporary privilege is removed before COMMIT.
GRANT USAGE ON SCHEMA private TO postgres;
GRANT EXECUTE ON FUNCTION private.create_profile_for_auth_user() TO postgres;
RESET ROLE;

CREATE TRIGGER on_auth_user_created_create_profile
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION private.create_profile_for_auth_user();

SET LOCAL ROLE coditza_owner;

REVOKE USAGE ON SCHEMA private FROM postgres;
REVOKE ALL ON FUNCTION private.create_profile_for_auth_user()
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON TABLE public.profiles
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

RESET ROLE;

COMMIT;
