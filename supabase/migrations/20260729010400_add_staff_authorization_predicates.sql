-- SUP-FUNCTIONS-001 (staff authorization primitive slice): identity-owned,
-- server-internal role predicates for the later authoring/lifecycle facades.
-- They deliberately read the live profile row instead of any JWT metadata.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION private.has_role(
  p_actor_user_id uuid,
  p_required_role public.app_role
)
RETURNS boolean
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $has_role$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles AS profile
    WHERE profile.id = p_actor_user_id
      AND profile.role = p_required_role
  );
$has_role$;

CREATE FUNCTION private.is_staff(p_actor_user_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $is_staff$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles AS profile
    WHERE profile.id = p_actor_user_id
      AND profile.role IN (
        'editor'::public.app_role,
        'admin'::public.app_role
      )
  );
$is_staff$;

CREATE FUNCTION private.assert_active_staff_actor(p_actor_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_active_staff_actor$
DECLARE
  v_role public.app_role;
BEGIN
  SELECT profile.role
  INTO v_role
  FROM public.profiles AS profile
  WHERE profile.id = p_actor_user_id
    AND profile.security_hold_at IS NULL
  FOR UPDATE;

  IF NOT FOUND
    OR v_role NOT IN (
      'editor'::public.app_role,
      'admin'::public.app_role
    ) THEN
    RAISE EXCEPTION
      'Content authoring requires an active editor or administrator profile.';
  END IF;
END;
$assert_active_staff_actor$;

REVOKE ALL ON FUNCTION private.has_role(uuid, public.app_role)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.is_staff(uuid)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.assert_active_staff_actor(uuid)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

RESET ROLE;

COMMIT;
