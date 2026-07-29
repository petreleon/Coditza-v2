-- SUP-FUNCTIONS-001 (assessment authoring slice): server-only partial PATCH
-- for draft quiz root fields. Question/option/key replacement remains a
-- separate complete-definition workflow and must not share this facade.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.assessment_update_draft_quiz(
  p_actor_user_id uuid,
  p_quiz_id uuid,
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
AS $assessment_update_draft_quiz$
DECLARE
  v_chapter_id uuid;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_locked_chapter_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_quiz_status public.content_status;
  v_existing_slug text;
  v_existing_title text;
  v_existing_instructions_markdown text;
  v_existing_passing_percent integer;
  v_existing_max_attempts integer;
  v_existing_time_limit_seconds integer;
  v_existing_is_required boolean;
  v_actual_row_version integer;
  v_actual_definition_version integer;
  v_slug text;
  v_title text;
  v_instructions_markdown text;
  v_passing_percent integer;
  v_max_attempts integer;
  v_time_limit_seconds integer;
  v_is_required boolean;
  v_root_changed boolean;
  v_next_row_version integer;
  v_next_definition_version integer;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to update a quiz.';
  END IF;
  IF p_quiz_id IS NULL THEN
    RAISE EXCEPTION 'A draft quiz is required to update.';
  END IF;
  IF p_expected_row_version IS NULL OR p_expected_row_version <= 0 THEN
    RAISE EXCEPTION 'A positive expected draft quiz version is required.';
  END IF;

  -- Lock and inspect the live profile before any authoring content access.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  PERFORM private.assert_jsonb_object_keys(
    p_input,
    ARRAY[]::text[],
    ARRAY[
      'slug',
      'title',
      'instructionsMarkdown',
      'passingPercent',
      'maxAttempts',
      'timeLimitSeconds',
      'isRequired'
    ]::text[],
    'Draft quiz update input'
  );
  IF p_input = '{}'::jsonb THEN
    RAISE EXCEPTION 'A draft quiz update needs at least one allowed field.';
  END IF;

  -- Discover the current ancestor path without an inner lock, then acquire the
  -- canonical module -> chapter -> quiz locks and prove each relationship
  -- stayed stable while that outer lock was acquired.
  SELECT quiz.chapter_id
  INTO v_chapter_id
  FROM public.quizzes AS quiz
  WHERE quiz.id = p_quiz_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The draft quiz does not exist.';
  END IF;

  SELECT chapter.module_id
  INTO v_module_id
  FROM public.chapters AS chapter
  WHERE chapter.id = v_chapter_id;

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

  SELECT chapter.module_id, chapter.status
  INTO v_locked_module_id, v_chapter_status
  FROM public.chapters AS chapter
  WHERE chapter.id = v_chapter_id
    AND chapter.module_id = v_module_id
  FOR UPDATE;

  IF NOT FOUND OR v_locked_module_id IS DISTINCT FROM v_module_id THEN
    RAISE EXCEPTION 'The parent chapter hierarchy changed concurrently; retry.';
  END IF;

  SELECT
    quiz.chapter_id,
    quiz.status,
    quiz.slug,
    quiz.title,
    quiz.instructions_markdown,
    quiz.passing_percent,
    quiz.max_attempts,
    quiz.time_limit_seconds,
    quiz.is_required,
    quiz.row_version,
    quiz.definition_version
  INTO
    v_locked_chapter_id,
    v_quiz_status,
    v_existing_slug,
    v_existing_title,
    v_existing_instructions_markdown,
    v_existing_passing_percent,
    v_existing_max_attempts,
    v_existing_time_limit_seconds,
    v_existing_is_required,
    v_actual_row_version,
    v_actual_definition_version
  FROM public.quizzes AS quiz
  WHERE quiz.id = p_quiz_id
    AND quiz.chapter_id = v_chapter_id
  FOR UPDATE;

  IF NOT FOUND OR v_locked_chapter_id IS DISTINCT FROM v_chapter_id THEN
    RAISE EXCEPTION 'The draft quiz hierarchy changed concurrently; retry.';
  END IF;
  IF v_module_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A quiz cannot be updated under an archived module.';
  END IF;
  IF v_chapter_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A quiz cannot be updated under an archived chapter.';
  END IF;
  IF v_quiz_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft quizzes can be updated.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The quiz draft version is stale.';
  END IF;

  v_slug := v_existing_slug;
  IF p_input OPERATOR(pg_catalog.?) 'slug' THEN
    v_slug := private.assert_jsonb_string(
      p_input -> 'slug',
      'Draft quiz slug'
    );
    IF NOT private.is_valid_slug(v_slug) THEN
      RAISE EXCEPTION 'Draft quiz slug is invalid.';
    END IF;
  END IF;

  v_title := v_existing_title;
  IF p_input OPERATOR(pg_catalog.?) 'title' THEN
    v_title := private.assert_jsonb_string(
      p_input -> 'title',
      'Draft quiz title'
    );
    IF v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
      OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
      RAISE EXCEPTION 'Draft quiz title must be trimmed and between 1 and 160 characters.';
    END IF;
  END IF;

  v_instructions_markdown := v_existing_instructions_markdown;
  IF p_input OPERATOR(pg_catalog.?) 'instructionsMarkdown' THEN
    v_instructions_markdown := private.assert_jsonb_string(
      p_input -> 'instructionsMarkdown',
      'Draft quiz instructionsMarkdown'
    );
    PERFORM private.assert_markdown_input(
      v_instructions_markdown,
      20000,
      'Draft quiz instructionsMarkdown'
    );
  END IF;

  v_passing_percent := v_existing_passing_percent;
  IF p_input OPERATOR(pg_catalog.?) 'passingPercent' THEN
    v_passing_percent := private.assert_jsonb_bounded_integer(
      p_input -> 'passingPercent',
      0,
      100,
      'Draft quiz passingPercent'
    );
  END IF;

  v_max_attempts := v_existing_max_attempts;
  IF p_input OPERATOR(pg_catalog.?) 'maxAttempts' THEN
    IF pg_catalog.jsonb_typeof(p_input -> 'maxAttempts') = 'null' THEN
      v_max_attempts := NULL;
    ELSE
      v_max_attempts := private.assert_jsonb_bounded_integer(
        p_input -> 'maxAttempts',
        1,
        100,
        'Draft quiz maxAttempts'
      );
    END IF;
  END IF;

  v_time_limit_seconds := v_existing_time_limit_seconds;
  IF p_input OPERATOR(pg_catalog.?) 'timeLimitSeconds' THEN
    IF pg_catalog.jsonb_typeof(p_input -> 'timeLimitSeconds') = 'null' THEN
      v_time_limit_seconds := NULL;
    ELSE
      v_time_limit_seconds := private.assert_jsonb_bounded_integer(
        p_input -> 'timeLimitSeconds',
        30,
        86400,
        'Draft quiz timeLimitSeconds'
      );
    END IF;
  END IF;

  v_is_required := v_existing_is_required;
  IF p_input OPERATOR(pg_catalog.?) 'isRequired' THEN
    IF pg_catalog.jsonb_typeof(p_input -> 'isRequired') <> 'boolean' THEN
      RAISE EXCEPTION 'Draft quiz isRequired must be boolean.';
    END IF;
    v_is_required := (p_input ->> 'isRequired')::boolean;
  END IF;

  v_root_changed :=
    v_slug IS DISTINCT FROM v_existing_slug
    OR v_title IS DISTINCT FROM v_existing_title
    OR v_instructions_markdown IS DISTINCT FROM v_existing_instructions_markdown
    OR v_passing_percent IS DISTINCT FROM v_existing_passing_percent
    OR v_max_attempts IS DISTINCT FROM v_existing_max_attempts
    OR v_time_limit_seconds IS DISTINCT FROM v_existing_time_limit_seconds
    OR v_is_required IS DISTINCT FROM v_existing_is_required;

  IF NOT v_root_changed THEN
    v_response_body := pg_catalog.jsonb_build_object(
      'id', p_quiz_id::text,
      'rowVersion', v_actual_row_version,
      'definitionVersion', v_actual_definition_version
    );
    RETURN QUERY SELECT 200, v_response_body;
    RETURN;
  END IF;

  -- Attempts refer to the root's immutable definition version. A draft with
  -- retained attempts may not advance that version and conceal its history.
  IF EXISTS (
    SELECT 1
    FROM public.quiz_attempts AS attempt
    WHERE attempt.quiz_id = p_quiz_id
  ) THEN
    RAISE EXCEPTION 'A draft quiz with attempt history cannot change its definition.';
  END IF;

  UPDATE public.quizzes AS quiz
  SET
    slug = v_slug,
    title = v_title,
    instructions_markdown = v_instructions_markdown,
    passing_percent = v_passing_percent,
    max_attempts = v_max_attempts,
    time_limit_seconds = v_time_limit_seconds,
    is_required = v_is_required,
    definition_version = quiz.definition_version + 1,
    updated_by = p_actor_user_id
  WHERE quiz.id = p_quiz_id
    AND quiz.row_version = p_expected_row_version
  RETURNING quiz.row_version, quiz.definition_version
  INTO v_next_row_version, v_next_definition_version;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz draft version changed concurrently; retry.';
  END IF;

  -- The audit event names only the safe state transition, never authored
  -- fields, attempt data, question trees, answer keys, or raw values.
  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'quiz_updated',
    'quiz',
    p_quiz_id,
    ARRAY['definition']::text[],
    '{"definition":{"before":"draft","after":"updated"}}'::jsonb,
    NULL,
    p_request_id
  );

  v_response_body := pg_catalog.jsonb_build_object(
    'id', p_quiz_id::text,
    'rowVersion', v_next_row_version,
    'definitionVersion', v_next_definition_version
  );
  RETURN QUERY SELECT 200, v_response_body;
END;
$assessment_update_draft_quiz$;

REVOKE ALL ON FUNCTION public.assessment_update_draft_quiz(
  uuid, uuid, integer, jsonb, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.assessment_update_draft_quiz(
  uuid, uuid, integer, jsonb, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
