-- SUP-FUNCTIONS-001 (curriculum authoring slice): one narrowly scoped,
-- server-only draft-chapter creation transaction. Future chapter reorders and
-- module archival must lock this same parent module row before changing its
-- child scope.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.curriculum_create_draft_chapter(
  p_actor_user_id uuid,
  p_module_id uuid,
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
AS $curriculum_create_draft_chapter$
DECLARE
  v_replay record;
  v_parent_status public.content_status;
  v_slug text;
  v_title text;
  v_summary_markdown text;
  v_estimated_minutes integer;
  v_last_position integer;
  v_position integer;
  v_chapter_id uuid;
  v_response_location text;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to create a chapter.';
  END IF;
  IF p_module_id IS NULL THEN
    RAISE EXCEPTION 'A parent module is required to create a chapter.';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'An idempotency key is required to create a chapter.';
  END IF;

  -- This live-profile lock intentionally precedes the replay lookup: a held
  -- or demoted actor cannot recover a historical authoring response.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  SELECT *
  INTO v_replay
  FROM private.acquire_idempotency_replay(
    p_actor_user_id,
    'admin_create_chapter',
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
    ARRAY[
      'slug',
      'title',
      'summaryMarkdown',
      'estimatedMinutes'
    ]::text[],
    ARRAY[
      'slug',
      'title',
      'summaryMarkdown',
      'estimatedMinutes'
    ]::text[],
    'Draft chapter input'
  );

  v_slug := private.assert_jsonb_string(
    p_input -> 'slug',
    'Draft chapter slug'
  );
  IF NOT private.is_valid_slug(v_slug) THEN
    RAISE EXCEPTION 'Draft chapter slug is invalid.';
  END IF;

  v_title := private.assert_jsonb_string(
    p_input -> 'title',
    'Draft chapter title'
  );
  IF v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
    OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
    RAISE EXCEPTION 'Draft chapter title must be trimmed and between 1 and 160 characters.';
  END IF;

  v_summary_markdown := private.assert_jsonb_string(
    p_input -> 'summaryMarkdown',
    'Draft chapter summaryMarkdown'
  );
  PERFORM private.assert_markdown_input(
    v_summary_markdown,
    5000,
    'Draft chapter summaryMarkdown'
  );

  v_estimated_minutes := private.assert_jsonb_bounded_integer(
    p_input -> 'estimatedMinutes',
    1,
    1440,
    'Draft chapter estimatedMinutes'
  );

  -- The parent row is the stable sibling-scope mutex. It must be locked before
  -- an append position is read, and archival/reorder code must reuse this row
  -- lock rather than lock only the current child rows.
  SELECT module_entry.status
  INTO v_parent_status
  FROM public.modules AS module_entry
  WHERE module_entry.id = p_module_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The parent module does not exist.';
  END IF;
  IF v_parent_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A chapter cannot be created under an archived module.';
  END IF;

  SELECT COALESCE(pg_catalog.max(chapter_entry.position), -1)
  INTO v_last_position
  FROM public.chapters AS chapter_entry
  WHERE chapter_entry.module_id = p_module_id;

  IF v_last_position = 2147483647 THEN
    RAISE EXCEPTION 'The chapter position space is exhausted for this module.';
  END IF;
  v_position := v_last_position + 1;

  INSERT INTO public.chapters (
    module_id,
    slug,
    title,
    summary_markdown,
    position,
    estimated_minutes,
    created_by,
    updated_by
  )
  VALUES (
    p_module_id,
    v_slug,
    v_title,
    v_summary_markdown,
    v_position,
    v_estimated_minutes,
    p_actor_user_id,
    p_actor_user_id
  )
  RETURNING id INTO v_chapter_id;

  v_response_location := '/api/v1/admin/chapters/' || v_chapter_id::text;
  -- Keep stored replays free of authored content. The generic validator for
  -- future admin creation operations intentionally permits this exact DTO.
  v_response_body := pg_catalog.jsonb_build_object('id', v_chapter_id::text);

  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'chapter_created',
    'chapter',
    v_chapter_id,
    ARRAY['status']::text[],
    '{"status":{"before":"none","after":"draft"}}'::jsonb,
    NULL,
    p_request_id
  );

  PERFORM private.complete_idempotency(
    p_actor_user_id,
    'admin_create_chapter',
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash,
    v_chapter_id,
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
$curriculum_create_draft_chapter$;

REVOKE ALL ON FUNCTION public.curriculum_create_draft_chapter(
  uuid, uuid, jsonb, uuid, integer, bytea, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.curriculum_create_draft_chapter(
  uuid, uuid, jsonb, uuid, integer, bytea, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
