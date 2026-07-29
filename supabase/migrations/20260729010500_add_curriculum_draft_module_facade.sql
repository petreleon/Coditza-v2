-- SUP-FUNCTIONS-001 (curriculum authoring slice): one narrowly scoped,
-- server-only draft-module creation transaction. Future root-module reorders
-- must reuse private.lock_module_root_scope() before reading or changing the
-- root position set.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION private.lock_module_root_scope()
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $lock_module_root_scope$
BEGIN
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'coditza:curriculum:modules-root-scope',
      0
    )
  );
END;
$lock_module_root_scope$;

CREATE FUNCTION public.curriculum_create_draft_module(
  p_actor_user_id uuid,
  p_input jsonb,
  p_idempotency_key uuid,
  p_canonicalization_version integer,
  p_request_hash bytea,
  p_request_id uuid
)
RETURNS TABLE (
  response_status integer,
  response_location text,
  idempotency_replayed boolean,
  response_body jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $curriculum_create_draft_module$
DECLARE
  v_replay record;
  v_slug text;
  v_title text;
  v_description_markdown text;
  v_last_position integer;
  v_position integer;
  v_module_id uuid;
  v_response_location text;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to create a module.';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'An idempotency key is required to create a module.';
  END IF;

  -- This live-profile lock intentionally precedes the replay lookup: a held
  -- or demoted actor cannot recover a historical authoring response.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  SELECT *
  INTO v_replay
  FROM private.acquire_idempotency_replay(
    p_actor_user_id,
    'admin_create_module',
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash
  );
  IF v_replay.replayed THEN
    RETURN QUERY SELECT
      v_replay.response_status,
      v_replay.response_location,
      true,
      v_replay.response_body;
    RETURN;
  END IF;

  PERFORM private.assert_jsonb_object_keys(
    p_input,
    ARRAY['slug', 'title', 'descriptionMarkdown']::text[],
    ARRAY['slug', 'title', 'descriptionMarkdown']::text[],
    'Draft module input'
  );

  v_slug := private.assert_jsonb_string(
    p_input -> 'slug',
    'Draft module slug'
  );
  IF NOT private.is_valid_slug(v_slug) THEN
    RAISE EXCEPTION 'Draft module slug is invalid.';
  END IF;

  v_title := private.assert_jsonb_string(
    p_input -> 'title',
    'Draft module title'
  );
  IF v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
    OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
    RAISE EXCEPTION 'Draft module title must be trimmed and between 1 and 160 characters.';
  END IF;

  v_description_markdown := private.assert_jsonb_string(
    p_input -> 'descriptionMarkdown',
    'Draft module descriptionMarkdown'
  );
  PERFORM private.assert_markdown_input(
    v_description_markdown,
    10000,
    'Draft module descriptionMarkdown'
  );

  -- Root modules have no parent row to lock. The fixed transaction advisory
  -- lock serializes both creation and the later complete-list reorder facade.
  PERFORM private.lock_module_root_scope();
  SELECT COALESCE(pg_catalog.max(module_entry.position), -1)
  INTO v_last_position
  FROM public.modules AS module_entry;

  IF v_last_position = 2147483647 THEN
    RAISE EXCEPTION 'The root module position space is exhausted.';
  END IF;
  v_position := v_last_position + 1;

  INSERT INTO public.modules (
    slug,
    title,
    description_markdown,
    position,
    created_by,
    updated_by
  )
  VALUES (
    v_slug,
    v_title,
    v_description_markdown,
    v_position,
    p_actor_user_id,
    p_actor_user_id
  )
  RETURNING id INTO v_module_id;

  v_response_location := '/api/v1/admin/modules/' || v_module_id::text;
  -- Keep stored replays free of authored content. The generic validator for
  -- future admin creation operations intentionally permits this exact DTO.
  v_response_body := pg_catalog.jsonb_build_object('id', v_module_id::text);

  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'module_created',
    'module',
    v_module_id,
    ARRAY['status']::text[],
    '{"status":{"before":"none","after":"draft"}}'::jsonb,
    NULL,
    p_request_id
  );

  PERFORM private.complete_idempotency(
    p_actor_user_id,
    'admin_create_module',
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash,
    v_module_id,
    201,
    v_response_location,
    v_response_body
  );

  RETURN QUERY SELECT
    201,
    v_response_location,
    false,
    v_response_body;
END;
$curriculum_create_draft_module$;

REVOKE ALL ON FUNCTION private.lock_module_root_scope()
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION public.curriculum_create_draft_module(
  uuid, jsonb, uuid, integer, bytea, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.curriculum_create_draft_module(
  uuid, jsonb, uuid, integer, bytea, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
