-- SUP-FUNCTIONS-001 (curriculum lifecycle slice): one narrowly scoped,
-- server-only correction for a published module. It changes authored scalar
-- content only; it never changes position, hierarchy, lifecycle, descendants,
-- or learner records and therefore locks only the target root row.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.curriculum_correct_published_module(
  p_actor_user_id uuid,
  p_module_id uuid,
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
AS $curriculum_correct_published_module$
DECLARE
  v_status public.content_status;
  v_actual_row_version integer;
  v_existing_title text;
  v_existing_description_markdown text;
  v_title text;
  v_description_markdown text;
  v_content_changed boolean;
  v_next_row_version integer;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to correct a published module.';
  END IF;
  IF p_module_id IS NULL THEN
    RAISE EXCEPTION 'A published module is required to correct.';
  END IF;
  IF p_expected_row_version IS NULL OR p_expected_row_version <= 0 THEN
    RAISE EXCEPTION 'A positive expected published module version is required.';
  END IF;

  -- Lock and inspect the live profile before content, lifecycle, or version
  -- information is accessed. A held or demoted actor cannot use a cached role.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  IF p_reason_code IS DISTINCT FROM 'content_correction' THEN
    RAISE EXCEPTION 'Published module corrections require content_correction.';
  END IF;

  -- The shared object-key helper intentionally operates on JSON values. Guard
  -- SQL NULL explicitly so it cannot look like an empty correction.
  IF p_input IS NULL OR pg_catalog.jsonb_typeof(p_input) <> 'object' THEN
    RAISE EXCEPTION 'Published module correction input must be an object.';
  END IF;
  PERFORM private.assert_jsonb_object_keys(
    p_input,
    ARRAY[]::text[],
    ARRAY['title', 'descriptionMarkdown']::text[],
    'Published module correction input'
  );
  IF p_input = '{}'::jsonb THEN
    RAISE EXCEPTION 'A published module correction needs at least one allowed field.';
  END IF;

  SELECT
    module_entry.status,
    module_entry.row_version,
    module_entry.title,
    module_entry.description_markdown
  INTO
    v_status,
    v_actual_row_version,
    v_existing_title,
    v_existing_description_markdown
  FROM public.modules AS module_entry
  WHERE module_entry.id = p_module_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The published module does not exist.';
  END IF;
  IF v_status <> 'published'::public.content_status THEN
    RAISE EXCEPTION 'Only published modules can be corrected.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The published module version is stale.';
  END IF;

  v_title := v_existing_title;
  IF p_input OPERATOR(pg_catalog.?) 'title' THEN
    v_title := private.assert_jsonb_string(
      p_input -> 'title',
      'Published module title'
    );
    IF v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
      OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
      RAISE EXCEPTION 'Published module title must be trimmed and between 1 and 160 characters.';
    END IF;
  END IF;

  v_description_markdown := v_existing_description_markdown;
  IF p_input OPERATOR(pg_catalog.?) 'descriptionMarkdown' THEN
    v_description_markdown := private.assert_jsonb_string(
      p_input -> 'descriptionMarkdown',
      'Published module descriptionMarkdown'
    );
    PERFORM private.assert_markdown_input(
      v_description_markdown,
      10000,
      'Published module descriptionMarkdown'
    );
  END IF;

  v_content_changed :=
    v_title IS DISTINCT FROM v_existing_title
    OR v_description_markdown IS DISTINCT FROM v_existing_description_markdown;

  -- A syntactically valid current-version correction that resolves to the same
  -- content is safe to retry but is not a correction event: do not advance the
  -- version or timestamps and do not append an audit row.
  IF NOT v_content_changed THEN
    v_response_body := pg_catalog.jsonb_build_object(
      'id', p_module_id::text,
      'rowVersion', v_actual_row_version
    );
    RETURN QUERY SELECT 200, v_response_body;
    RETURN;
  END IF;

  -- The root row lock is sufficient because this facade cannot modify sibling
  -- position or descendants. Keep the version predicate as a final defensive
  -- concurrency guard around the only authored-row write.
  UPDATE public.modules AS module_entry
  SET
    title = v_title,
    description_markdown = v_description_markdown,
    updated_by = p_actor_user_id
  WHERE module_entry.id = p_module_id
    AND module_entry.row_version = p_expected_row_version
  RETURNING module_entry.row_version
  INTO v_next_row_version;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The published module version changed concurrently; retry.';
  END IF;

  -- Authored fields and raw before/after values are forbidden in audit. The
  -- distinct action and required reason preserve correction semantics without
  -- leaking the corrected content.
  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'module_corrected',
    'module',
    p_module_id,
    ARRAY['content']::text[],
    '{"content":{"before":"redacted","after":"redacted"}}'::jsonb,
    p_reason_code,
    p_request_id
  );

  v_response_body := pg_catalog.jsonb_build_object(
    'id', p_module_id::text,
    'rowVersion', v_next_row_version
  );
  RETURN QUERY SELECT 200, v_response_body;
END;
$curriculum_correct_published_module$;

REVOKE ALL ON FUNCTION public.curriculum_correct_published_module(
  uuid, uuid, integer, text, jsonb, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.curriculum_correct_published_module(
  uuid, uuid, integer, text, jsonb, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
