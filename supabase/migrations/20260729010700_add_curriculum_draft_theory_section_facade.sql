-- SUP-FUNCTIONS-001 (curriculum authoring slice): one narrowly scoped,
-- server-only draft-theory-section creation transaction. Future theory-section
-- reorders and chapter archival must lock this same chapter row after the
-- canonical module-to-chapter hierarchy lock.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.curriculum_create_draft_theory_section(
  p_actor_user_id uuid,
  p_chapter_id uuid,
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
AS $curriculum_create_draft_theory_section$
DECLARE
  v_replay record;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_title text;
  v_body_markdown text;
  v_estimated_minutes integer;
  v_last_position integer;
  v_position integer;
  v_theory_section_id uuid;
  v_response_location text;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to create a theory section.';
  END IF;
  IF p_chapter_id IS NULL THEN
    RAISE EXCEPTION 'A parent chapter is required to create a theory section.';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'An idempotency key is required to create a theory section.';
  END IF;

  -- This live-profile lock intentionally precedes the replay lookup: a held
  -- or demoted actor cannot recover a historical authoring response.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  SELECT *
  INTO v_replay
  FROM private.acquire_idempotency_replay(
    p_actor_user_id,
    'admin_create_theory_section',
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
      'title',
      'bodyMarkdown',
      'estimatedMinutes'
    ]::text[],
    ARRAY[
      'title',
      'bodyMarkdown',
      'estimatedMinutes'
    ]::text[],
    'Draft theory-section input'
  );

  v_title := private.assert_jsonb_string(
    p_input -> 'title',
    'Draft theory-section title'
  );
  IF v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
    OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
    RAISE EXCEPTION 'Draft theory-section title must be trimmed and between 1 and 160 characters.';
  END IF;

  v_body_markdown := private.assert_jsonb_string(
    p_input -> 'bodyMarkdown',
    'Draft theory-section bodyMarkdown'
  );
  PERFORM private.assert_markdown_input(
    v_body_markdown,
    100000,
    'Draft theory-section bodyMarkdown'
  );

  v_estimated_minutes := private.assert_jsonb_bounded_integer(
    p_input -> 'estimatedMinutes',
    1,
    1440,
    'Draft theory-section estimatedMinutes'
  );

  -- Resolve the outer lock target without taking the inner chapter lock, then
  -- take the canonical module -> chapter hierarchy locks. The second chapter
  -- read proves it remained in that module while the outer lock was acquired.
  SELECT chapter_entry.module_id
  INTO v_module_id
  FROM public.chapters AS chapter_entry
  WHERE chapter_entry.id = p_chapter_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The parent chapter does not exist.';
  END IF;

  SELECT module_entry.status
  INTO v_module_status
  FROM public.modules AS module_entry
  WHERE module_entry.id = v_module_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The parent module no longer exists.';
  END IF;

  SELECT chapter_entry.module_id, chapter_entry.status
  INTO v_locked_module_id, v_chapter_status
  FROM public.chapters AS chapter_entry
  WHERE chapter_entry.id = p_chapter_id
    AND chapter_entry.module_id = v_module_id
  FOR UPDATE;

  IF NOT FOUND OR v_locked_module_id IS DISTINCT FROM v_module_id THEN
    RAISE EXCEPTION 'The parent chapter hierarchy changed concurrently; retry.';
  END IF;
  IF v_module_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A theory section cannot be created under an archived module.';
  END IF;
  IF v_chapter_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A theory section cannot be created under an archived chapter.';
  END IF;

  -- The locked chapter row is the stable sibling-scope mutex. It must be held
  -- before an append position is read, and archival/reorder code must reuse it
  -- rather than lock only the current theory-section rows.
  SELECT COALESCE(pg_catalog.max(theory_section.position), -1)
  INTO v_last_position
  FROM public.theory_sections AS theory_section
  WHERE theory_section.chapter_id = p_chapter_id;

  IF v_last_position = 2147483647 THEN
    RAISE EXCEPTION 'The theory-section position space is exhausted for this chapter.';
  END IF;
  v_position := v_last_position + 1;

  INSERT INTO public.theory_sections (
    chapter_id,
    title,
    body_markdown,
    position,
    estimated_minutes,
    created_by,
    updated_by
  )
  VALUES (
    p_chapter_id,
    v_title,
    v_body_markdown,
    v_position,
    v_estimated_minutes,
    p_actor_user_id,
    p_actor_user_id
  )
  RETURNING id INTO v_theory_section_id;

  v_response_location :=
    '/api/v1/admin/theory-sections/' || v_theory_section_id::text;
  -- Keep stored replays free of authored content. The generic validator for
  -- future admin creation operations intentionally permits this exact DTO.
  v_response_body := pg_catalog.jsonb_build_object(
    'id',
    v_theory_section_id::text
  );

  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'theory_section_created',
    'theory_section',
    v_theory_section_id,
    ARRAY['status']::text[],
    '{"status":{"before":"none","after":"draft"}}'::jsonb,
    NULL,
    p_request_id
  );

  PERFORM private.complete_idempotency(
    p_actor_user_id,
    'admin_create_theory_section',
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash,
    v_theory_section_id,
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
$curriculum_create_draft_theory_section$;

REVOKE ALL ON FUNCTION public.curriculum_create_draft_theory_section(
  uuid, uuid, jsonb, uuid, integer, bytea, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.curriculum_create_draft_theory_section(
  uuid, uuid, jsonb, uuid, integer, bytea, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
