-- SUP-FUNCTIONS-001 (curriculum lifecycle slice): one narrowly scoped,
-- server-only correction for a published theory section. It changes authored
-- scalar content only; it never changes hierarchy, lifecycle, descendants, or
-- learner records. Locking module -> chapter -> theory section serializes this
-- change with archival of either ancestor while preserving the canonical
-- hierarchy lock order used by section-owned curriculum facades.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.curriculum_correct_published_theory_section(
  p_actor_user_id uuid,
  p_theory_section_id uuid,
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
AS $curriculum_correct_published_theory_section$
DECLARE
  v_chapter_id uuid;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_locked_chapter_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_theory_section_status public.content_status;
  v_actual_row_version integer;
  v_existing_title text;
  v_existing_body_markdown text;
  v_existing_estimated_minutes integer;
  v_title text;
  v_body_markdown text;
  v_estimated_minutes integer;
  v_content_changed boolean;
  v_next_row_version integer;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to correct a published theory section.';
  END IF;
  IF p_theory_section_id IS NULL THEN
    RAISE EXCEPTION 'A published theory section is required to correct.';
  END IF;
  IF p_expected_row_version IS NULL OR p_expected_row_version <= 0 THEN
    RAISE EXCEPTION 'A positive expected published theory section version is required.';
  END IF;

  -- Lock and inspect the live profile before content, hierarchy, lifecycle, or
  -- version information is accessed. A held or demoted actor cannot use a
  -- previously observed staff role.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  IF p_reason_code IS DISTINCT FROM 'content_correction' THEN
    RAISE EXCEPTION 'Published theory section corrections require content_correction.';
  END IF;

  -- The shared object-key helper intentionally operates on JSON values. Guard
  -- SQL NULL explicitly so it cannot look like an empty correction.
  IF p_input IS NULL OR pg_catalog.jsonb_typeof(p_input) <> 'object' THEN
    RAISE EXCEPTION 'Published theory section correction input must be an object.';
  END IF;
  PERFORM private.assert_jsonb_object_keys(
    p_input,
    ARRAY[]::text[],
    ARRAY['title', 'bodyMarkdown', 'estimatedMinutes']::text[],
    'Published theory section correction input'
  );
  IF p_input = '{}'::jsonb THEN
    RAISE EXCEPTION 'A published theory section correction needs at least one allowed field.';
  END IF;

  -- Discover the current hierarchy once, then acquire canonical
  -- module -> chapter -> theory-section locks and prove every edge remained
  -- stable while its outer lock was acquired.
  SELECT theory_section_entry.chapter_id
  INTO v_chapter_id
  FROM public.theory_sections AS theory_section_entry
  WHERE theory_section_entry.id = p_theory_section_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The published theory section does not exist.';
  END IF;

  SELECT chapter_entry.module_id
  INTO v_module_id
  FROM public.chapters AS chapter_entry
  WHERE chapter_entry.id = v_chapter_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The parent chapter no longer exists.';
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
  WHERE chapter_entry.id = v_chapter_id
    AND chapter_entry.module_id = v_module_id
  FOR UPDATE;

  IF NOT FOUND OR v_locked_module_id IS DISTINCT FROM v_module_id THEN
    RAISE EXCEPTION 'The parent chapter hierarchy changed concurrently; retry.';
  END IF;

  SELECT
    theory_section_entry.chapter_id,
    theory_section_entry.status,
    theory_section_entry.row_version,
    theory_section_entry.title,
    theory_section_entry.body_markdown,
    theory_section_entry.estimated_minutes
  INTO
    v_locked_chapter_id,
    v_theory_section_status,
    v_actual_row_version,
    v_existing_title,
    v_existing_body_markdown,
    v_existing_estimated_minutes
  FROM public.theory_sections AS theory_section_entry
  WHERE theory_section_entry.id = p_theory_section_id
    AND theory_section_entry.chapter_id = v_chapter_id
  FOR UPDATE;

  IF NOT FOUND OR v_locked_chapter_id IS DISTINCT FROM v_chapter_id THEN
    RAISE EXCEPTION 'The published theory section hierarchy changed concurrently; retry.';
  END IF;
  IF v_module_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A theory section cannot be corrected under an archived module.';
  END IF;
  IF v_chapter_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A theory section cannot be corrected under an archived chapter.';
  END IF;
  IF v_theory_section_status <> 'published'::public.content_status THEN
    RAISE EXCEPTION 'Only published theory sections can be corrected.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The published theory section version is stale.';
  END IF;

  v_title := v_existing_title;
  IF p_input OPERATOR(pg_catalog.?) 'title' THEN
    v_title := private.assert_jsonb_string(
      p_input -> 'title',
      'Published theory section title'
    );
    IF v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
      OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
      RAISE EXCEPTION 'Published theory section title must be trimmed and between 1 and 160 characters.';
    END IF;
  END IF;

  v_body_markdown := v_existing_body_markdown;
  IF p_input OPERATOR(pg_catalog.?) 'bodyMarkdown' THEN
    v_body_markdown := private.assert_jsonb_string(
      p_input -> 'bodyMarkdown',
      'Published theory section bodyMarkdown'
    );
    PERFORM private.assert_markdown_input(
      v_body_markdown,
      100000,
      'Published theory section bodyMarkdown'
    );
  END IF;

  v_estimated_minutes := v_existing_estimated_minutes;
  IF p_input OPERATOR(pg_catalog.?) 'estimatedMinutes' THEN
    v_estimated_minutes := private.assert_jsonb_bounded_integer(
      p_input -> 'estimatedMinutes',
      1,
      1440,
      'Published theory section estimatedMinutes'
    );
  END IF;

  v_content_changed :=
    v_title IS DISTINCT FROM v_existing_title
    OR v_body_markdown IS DISTINCT FROM v_existing_body_markdown
    OR v_estimated_minutes IS DISTINCT FROM v_existing_estimated_minutes;

  -- A syntactically valid current-version correction that resolves to the same
  -- content is safe to retry but is not a correction event: do not advance the
  -- version or timestamps and do not append an audit row.
  IF NOT v_content_changed THEN
    v_response_body := pg_catalog.jsonb_build_object(
      'id', p_theory_section_id::text,
      'rowVersion', v_actual_row_version
    );
    RETURN QUERY SELECT 200, v_response_body;
    RETURN;
  END IF;

  -- The hierarchy locks stabilize both ancestors and the target. Keep the
  -- chapter relationship and version predicates as final guards around the
  -- only authored-row write.
  UPDATE public.theory_sections AS theory_section_entry
  SET
    title = v_title,
    body_markdown = v_body_markdown,
    estimated_minutes = v_estimated_minutes,
    updated_by = p_actor_user_id
  WHERE theory_section_entry.id = p_theory_section_id
    AND theory_section_entry.chapter_id = v_chapter_id
    AND theory_section_entry.row_version = p_expected_row_version
  RETURNING theory_section_entry.row_version
  INTO v_next_row_version;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The published theory section version changed concurrently; retry.';
  END IF;

  -- Authored fields and raw before/after values are forbidden in audit. The
  -- distinct action and required reason preserve correction semantics without
  -- leaking corrected authored content.
  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'theory_section_corrected',
    'theory_section',
    p_theory_section_id,
    ARRAY['content']::text[],
    '{"content":{"before":"redacted","after":"redacted"}}'::jsonb,
    p_reason_code,
    p_request_id
  );

  v_response_body := pg_catalog.jsonb_build_object(
    'id', p_theory_section_id::text,
    'rowVersion', v_next_row_version
  );
  RETURN QUERY SELECT 200, v_response_body;
END;
$curriculum_correct_published_theory_section$;

REVOKE ALL ON FUNCTION public.curriculum_correct_published_theory_section(
  uuid, uuid, integer, text, jsonb, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.curriculum_correct_published_theory_section(
  uuid, uuid, integer, text, jsonb, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
