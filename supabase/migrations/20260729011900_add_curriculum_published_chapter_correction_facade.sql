-- SUP-FUNCTIONS-001 (curriculum lifecycle slice): one narrowly scoped,
-- server-only correction for a published chapter. It changes authored scalar
-- content only; it never changes hierarchy, lifecycle, descendants, or learner
-- records. Locking the parent module before the chapter serializes this change
-- with an archival of that parent while preserving the canonical hierarchy
-- lock order used by chapter-owned curriculum facades.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.curriculum_correct_published_chapter(
  p_actor_user_id uuid,
  p_chapter_id uuid,
  p_expected_row_version integer,
  p_reason_code text,
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
AS $curriculum_correct_published_chapter$
DECLARE
  v_module_id uuid;
  v_locked_module_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_actual_row_version integer;
  v_existing_title text;
  v_existing_summary_markdown text;
  v_existing_estimated_minutes integer;
  v_title text;
  v_summary_markdown text;
  v_estimated_minutes integer;
  v_content_changed boolean;
  v_next_row_version integer;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to correct a published chapter.';
  END IF;
  IF p_chapter_id IS NULL THEN
    RAISE EXCEPTION 'A published chapter is required to correct.';
  END IF;
  IF p_expected_row_version IS NULL OR p_expected_row_version <= 0 THEN
    RAISE EXCEPTION 'A positive expected published chapter version is required.';
  END IF;

  -- Lock and inspect the live profile before content, hierarchy, lifecycle, or
  -- version information is accessed. A held or demoted actor cannot use a
  -- previously observed staff role.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  IF p_reason_code IS DISTINCT FROM 'content_correction' THEN
    RAISE EXCEPTION 'Published chapter corrections require content_correction.';
  END IF;

  -- The shared object-key helper intentionally operates on JSON values. Guard
  -- SQL NULL explicitly so it cannot look like an empty correction.
  IF p_input IS NULL OR pg_catalog.jsonb_typeof(p_input) <> 'object' THEN
    RAISE EXCEPTION 'Published chapter correction input must be an object.';
  END IF;
  PERFORM private.assert_jsonb_object_keys(
    p_input,
    ARRAY[]::text[],
    ARRAY['title', 'summaryMarkdown', 'estimatedMinutes']::text[],
    'Published chapter correction input'
  );
  IF p_input = '{}'::jsonb THEN
    RAISE EXCEPTION 'A published chapter correction needs at least one allowed field.';
  END IF;

  -- Discover the current parent once, then lock the canonical module -> chapter
  -- path. The constrained chapter re-read proves it remained under that locked
  -- parent while the outer lock was acquired.
  SELECT chapter_entry.module_id
  INTO v_module_id
  FROM public.chapters AS chapter_entry
  WHERE chapter_entry.id = p_chapter_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The published chapter does not exist.';
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
    chapter_entry.title,
    chapter_entry.summary_markdown,
    chapter_entry.estimated_minutes
  INTO
    v_locked_module_id,
    v_chapter_status,
    v_actual_row_version,
    v_existing_title,
    v_existing_summary_markdown,
    v_existing_estimated_minutes
  FROM public.chapters AS chapter_entry
  WHERE chapter_entry.id = p_chapter_id
    AND chapter_entry.module_id = v_module_id
  FOR UPDATE;

  IF NOT FOUND OR v_locked_module_id IS DISTINCT FROM v_module_id THEN
    RAISE EXCEPTION 'The published chapter hierarchy changed concurrently; retry.';
  END IF;
  IF v_module_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A chapter cannot be corrected under an archived module.';
  END IF;
  IF v_chapter_status <> 'published'::public.content_status THEN
    RAISE EXCEPTION 'Only published chapters can be corrected.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The published chapter version is stale.';
  END IF;

  v_title := v_existing_title;
  IF p_input OPERATOR(pg_catalog.?) 'title' THEN
    v_title := private.assert_jsonb_string(
      p_input -> 'title',
      'Published chapter title'
    );
    IF v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
      OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
      RAISE EXCEPTION 'Published chapter title must be trimmed and between 1 and 160 characters.';
    END IF;
  END IF;

  v_summary_markdown := v_existing_summary_markdown;
  IF p_input OPERATOR(pg_catalog.?) 'summaryMarkdown' THEN
    v_summary_markdown := private.assert_jsonb_string(
      p_input -> 'summaryMarkdown',
      'Published chapter summaryMarkdown'
    );
    PERFORM private.assert_markdown_input(
      v_summary_markdown,
      5000,
      'Published chapter summaryMarkdown'
    );
  END IF;

  v_estimated_minutes := v_existing_estimated_minutes;
  IF p_input OPERATOR(pg_catalog.?) 'estimatedMinutes' THEN
    v_estimated_minutes := private.assert_jsonb_bounded_integer(
      p_input -> 'estimatedMinutes',
      1,
      1440,
      'Published chapter estimatedMinutes'
    );
  END IF;

  v_content_changed :=
    v_title IS DISTINCT FROM v_existing_title
    OR v_summary_markdown IS DISTINCT FROM v_existing_summary_markdown
    OR v_estimated_minutes IS DISTINCT FROM v_existing_estimated_minutes;

  -- A syntactically valid current-version correction that resolves to the same
  -- content is safe to retry but is not a correction event: do not advance the
  -- version or timestamps and do not append an audit row.
  IF NOT v_content_changed THEN
    v_response_body := pg_catalog.jsonb_build_object(
      'id', p_chapter_id::text,
      'rowVersion', v_actual_row_version
    );
    RETURN QUERY SELECT 200, v_response_body;
    RETURN;
  END IF;

  -- The module and chapter locks stabilize hierarchy and parent archival. Keep
  -- both the parent relationship and version predicates as final guards around
  -- the only authored-row write.
  UPDATE public.chapters AS chapter_entry
  SET
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
    RAISE EXCEPTION 'The published chapter version changed concurrently; retry.';
  END IF;

  -- Authored fields and raw before/after values are forbidden in audit. The
  -- distinct action and required reason preserve correction semantics without
  -- leaking corrected authored content.
  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'chapter_corrected',
    'chapter',
    p_chapter_id,
    ARRAY['content']::text[],
    '{"content":{"before":"redacted","after":"redacted"}}'::jsonb,
    p_reason_code,
    p_request_id
  );

  v_response_body := pg_catalog.jsonb_build_object(
    'id', p_chapter_id::text,
    'rowVersion', v_next_row_version
  );
  RETURN QUERY SELECT 200, v_response_body;
END;
$curriculum_correct_published_chapter$;

REVOKE ALL ON FUNCTION public.curriculum_correct_published_chapter(
  uuid, uuid, integer, text, jsonb, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.curriculum_correct_published_chapter(
  uuid, uuid, integer, text, jsonb, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
