-- SUP-FUNCTIONS-001 (curriculum authoring slice): one narrowly scoped,
-- server-only partial PATCH for a draft chapter. Parent-module locking keeps
-- this update serialized with module archival while this facade leaves sibling
-- position, hierarchy, lifecycle, and descendants untouched.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.curriculum_update_draft_chapter(
  p_actor_user_id uuid,
  p_chapter_id uuid,
  p_expected_row_version integer,
  p_input jsonb,
  p_request_id uuid
)
RETURNS TABLE (
  response_status integer,
  response_body jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $curriculum_update_draft_chapter$
DECLARE
  v_module_id uuid;
  v_locked_module_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_actual_row_version integer;
  v_existing_slug text;
  v_existing_title text;
  v_existing_summary_markdown text;
  v_existing_estimated_minutes integer;
  v_slug text;
  v_title text;
  v_summary_markdown text;
  v_estimated_minutes integer;
  v_content_changed boolean;
  v_next_row_version integer;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to update a chapter.';
  END IF;
  IF p_chapter_id IS NULL THEN
    RAISE EXCEPTION 'A draft chapter is required to update.';
  END IF;
  IF p_expected_row_version IS NULL OR p_expected_row_version <= 0 THEN
    RAISE EXCEPTION 'A positive expected draft chapter version is required.';
  END IF;

  -- Lock and inspect the live profile before content, hierarchy, lifecycle, or
  -- version information is accessed. A held or demoted actor cannot rely on a
  -- previously observed staff role.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  -- The shared object-key helper intentionally operates on JSON values. Guard
  -- SQL NULL explicitly so it cannot look like an empty no-op patch.
  IF p_input IS NULL OR pg_catalog.jsonb_typeof(p_input) <> 'object' THEN
    RAISE EXCEPTION 'Draft chapter update input must be an object.';
  END IF;
  PERFORM private.assert_jsonb_object_keys(
    p_input,
    ARRAY[]::text[],
    ARRAY[
      'slug',
      'title',
      'summaryMarkdown',
      'estimatedMinutes'
    ]::text[],
    'Draft chapter update input'
  );
  IF p_input = '{}'::jsonb THEN
    RAISE EXCEPTION 'A draft chapter update needs at least one allowed field.';
  END IF;

  -- Discover the current parent once, then take canonical module -> chapter
  -- locks. The constrained chapter re-read proves it stayed below that locked
  -- parent while the outer lock was acquired.
  SELECT chapter_entry.module_id
  INTO v_module_id
  FROM public.chapters AS chapter_entry
  WHERE chapter_entry.id = p_chapter_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The draft chapter does not exist.';
  END IF;

  SELECT module_entry.status
  INTO v_module_status
  FROM public.modules AS module_entry
  WHERE module_entry.id = v_module_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The parent module no longer exists.';
  END IF;

  SELECT
    chapter_entry.module_id,
    chapter_entry.status,
    chapter_entry.row_version,
    chapter_entry.slug,
    chapter_entry.title,
    chapter_entry.summary_markdown,
    chapter_entry.estimated_minutes
  INTO
    v_locked_module_id,
    v_chapter_status,
    v_actual_row_version,
    v_existing_slug,
    v_existing_title,
    v_existing_summary_markdown,
    v_existing_estimated_minutes
  FROM public.chapters AS chapter_entry
  WHERE chapter_entry.id = p_chapter_id
    AND chapter_entry.module_id = v_module_id
  FOR UPDATE;

  IF NOT FOUND OR v_locked_module_id IS DISTINCT FROM v_module_id THEN
    RAISE EXCEPTION 'The draft chapter hierarchy changed concurrently; retry.';
  END IF;
  IF v_module_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A chapter cannot be updated under an archived module.';
  END IF;
  IF v_chapter_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft chapters can be updated.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The chapter draft version is stale.';
  END IF;

  v_slug := v_existing_slug;
  IF p_input OPERATOR(pg_catalog.?) 'slug' THEN
    v_slug := private.assert_jsonb_string(
      p_input -> 'slug',
      'Draft chapter slug'
    );
    IF NOT private.is_valid_slug(v_slug) THEN
      RAISE EXCEPTION 'Draft chapter slug is invalid.';
    END IF;
  END IF;

  v_title := v_existing_title;
  IF p_input OPERATOR(pg_catalog.?) 'title' THEN
    v_title := private.assert_jsonb_string(
      p_input -> 'title',
      'Draft chapter title'
    );
    IF v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
      OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
      RAISE EXCEPTION 'Draft chapter title must be trimmed and between 1 and 160 characters.';
    END IF;
  END IF;

  v_summary_markdown := v_existing_summary_markdown;
  IF p_input OPERATOR(pg_catalog.?) 'summaryMarkdown' THEN
    v_summary_markdown := private.assert_jsonb_string(
      p_input -> 'summaryMarkdown',
      'Draft chapter summaryMarkdown'
    );
    PERFORM private.assert_markdown_input(
      v_summary_markdown,
      5000,
      'Draft chapter summaryMarkdown'
    );
  END IF;

  v_estimated_minutes := v_existing_estimated_minutes;
  IF p_input OPERATOR(pg_catalog.?) 'estimatedMinutes' THEN
    v_estimated_minutes := private.assert_jsonb_bounded_integer(
      p_input -> 'estimatedMinutes',
      1,
      1440,
      'Draft chapter estimatedMinutes'
    );
  END IF;

  v_content_changed :=
    v_slug IS DISTINCT FROM v_existing_slug
    OR v_title IS DISTINCT FROM v_existing_title
    OR v_summary_markdown IS DISTINCT FROM v_existing_summary_markdown
    OR v_estimated_minutes IS DISTINCT FROM v_existing_estimated_minutes;

  -- Do not run an UPDATE for a no-op: the shared lifecycle trigger increments
  -- row_version on every UPDATE, including one whose authored values match.
  IF NOT v_content_changed THEN
    v_response_body := pg_catalog.jsonb_build_object(
      'id', p_chapter_id::text,
      'rowVersion', v_actual_row_version
    );
    RETURN QUERY SELECT 200, v_response_body;
    RETURN;
  END IF;

  -- The parent and chapter locks stabilize hierarchy and archival. Keep both
  -- the parent relationship and version predicates as final guards around the
  -- only authored-row write.
  UPDATE public.chapters AS chapter_entry
  SET
    slug = v_slug,
    title = v_title,
    summary_markdown = v_summary_markdown,
    estimated_minutes = v_estimated_minutes,
    updated_by = p_actor_user_id
  WHERE chapter_entry.id = p_chapter_id
    AND chapter_entry.module_id = v_module_id
    AND chapter_entry.row_version = p_expected_row_version
  RETURNING chapter_entry.row_version
  INTO v_next_row_version;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The chapter draft changed concurrently; retry.';
  END IF;

  -- Authored fields and raw before/after values are forbidden in audit. This
  -- emits only the approved redacted fact that content changed.
  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'chapter_updated',
    'chapter',
    p_chapter_id,
    ARRAY['content']::text[],
    '{"content":{"before":"redacted","after":"redacted"}}'::jsonb,
    NULL,
    p_request_id
  );

  v_response_body := pg_catalog.jsonb_build_object(
    'id', p_chapter_id::text,
    'rowVersion', v_next_row_version
  );
  RETURN QUERY SELECT 200, v_response_body;
END;
$curriculum_update_draft_chapter$;

REVOKE ALL ON FUNCTION public.curriculum_update_draft_chapter(
  uuid, uuid, integer, jsonb, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.curriculum_update_draft_chapter(
  uuid, uuid, integer, jsonb, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
