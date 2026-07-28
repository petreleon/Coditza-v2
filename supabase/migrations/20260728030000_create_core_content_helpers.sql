-- SUP-DATA-001: owner-only lifecycle semantics shared by the first authored
-- content hierarchy. This is a trigger helper, not a callable workflow API.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION private.enforce_authored_row_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_authored_row_lifecycle$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status IS DISTINCT FROM 'draft'::public.content_status
      OR NEW.published_at IS NOT NULL
      OR NEW.row_version IS DISTINCT FROM 1 THEN
      RAISE EXCEPTION
        'New authored content must begin as draft with no publication timestamp and row version 1.';
    END IF;

    RETURN NEW;
  END IF;

  IF TG_OP <> 'UPDATE' THEN
    RAISE EXCEPTION
      'private.enforce_authored_row_lifecycle may run only for INSERT or UPDATE triggers.';
  END IF;

  IF OLD.status = 'published'::public.content_status
    AND NEW.status = 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Published authored content cannot return to draft.';
  END IF;

  IF OLD.status = 'archived'::public.content_status
    AND NEW.status <> 'archived'::public.content_status THEN
    RAISE EXCEPTION 'Archived authored content cannot be reopened.';
  END IF;

  IF OLD.published_at IS NOT NULL
    AND NEW.published_at IS DISTINCT FROM OLD.published_at THEN
    RAISE EXCEPTION 'The first publication timestamp is immutable.';
  END IF;

  IF OLD.status = 'draft'::public.content_status
    AND NEW.status = 'archived'::public.content_status
    AND NEW.published_at IS NOT NULL THEN
    RAISE EXCEPTION 'Never-published content cannot invent a publication timestamp.';
  END IF;

  NEW.row_version := OLD.row_version + 1;
  RETURN NEW;
END;
$enforce_authored_row_lifecycle$;

REVOKE ALL ON FUNCTION private.enforce_authored_row_lifecycle()
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

RESET ROLE;

COMMIT;
