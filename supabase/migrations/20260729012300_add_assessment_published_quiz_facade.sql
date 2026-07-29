-- SUP-FUNCTIONS-001 (assessment lifecycle slice): publish one validated
-- draft quiz. This deliberately owns only the quiz root transition;
-- definition authoring, reordering, and ancestor lifecycle changes remain
-- separate workflows with their own lock protocols.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.assessment_publish_quiz(
  p_actor_user_id uuid,
  p_quiz_id uuid,
  p_expected_row_version integer,
  p_request_id uuid
)
RETURNS TABLE (
  response_status integer,
  response_body jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $assessment_publish_quiz$
DECLARE
  v_chapter_id uuid;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_locked_chapter_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_quiz_status public.content_status;
  v_actual_row_version integer;
  v_slug text;
  v_title text;
  v_instructions_markdown text;
  v_position integer;
  v_passing_percent integer;
  v_max_attempts integer;
  v_time_limit_seconds integer;
  v_is_required boolean;
  v_published_at timestamptz;
  v_next_row_version integer;
  v_affected_user_ids uuid[];
  v_affected_user_id uuid;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to publish a quiz.';
  END IF;
  IF p_quiz_id IS NULL THEN
    RAISE EXCEPTION 'A draft quiz is required to publish.';
  END IF;
  IF p_expected_row_version IS NULL OR p_expected_row_version <= 0 THEN
    RAISE EXCEPTION 'A positive expected draft quiz version is required.';
  END IF;

  -- A held or demoted actor must fail before hierarchy, authoring root,
  -- definition, lifecycle, version, or learner-progress source access.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  -- Discover first, then acquire every authored row in the canonical outer to
  -- inner order and prove the discovered path did not move during locking.
  SELECT quiz_entry.chapter_id
  INTO v_chapter_id
  FROM public.quizzes AS quiz_entry
  WHERE quiz_entry.id = p_quiz_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz does not exist.';
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
    quiz_entry.chapter_id,
    quiz_entry.status,
    quiz_entry.row_version,
    quiz_entry.slug,
    quiz_entry.title,
    quiz_entry.instructions_markdown,
    quiz_entry.position,
    quiz_entry.passing_percent,
    quiz_entry.max_attempts,
    quiz_entry.time_limit_seconds,
    quiz_entry.is_required,
    quiz_entry.published_at
  INTO
    v_locked_chapter_id,
    v_quiz_status,
    v_actual_row_version,
    v_slug,
    v_title,
    v_instructions_markdown,
    v_position,
    v_passing_percent,
    v_max_attempts,
    v_time_limit_seconds,
    v_is_required,
    v_published_at
  FROM public.quizzes AS quiz_entry
  WHERE quiz_entry.id = p_quiz_id
    AND quiz_entry.chapter_id = v_chapter_id
  FOR UPDATE;

  IF NOT FOUND OR v_locked_chapter_id IS DISTINCT FROM v_chapter_id THEN
    RAISE EXCEPTION 'The quiz hierarchy changed concurrently; retry.';
  END IF;
  IF v_module_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A quiz cannot publish under an archived module.';
  END IF;
  IF v_chapter_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A quiz cannot publish under an archived chapter.';
  END IF;
  IF v_quiz_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'An archived quiz cannot be published.';
  END IF;

  -- State-based retry deliberately precedes the expected-version comparison:
  -- a caller can repeat its original draft request without causing a second
  -- root write, audit row, progress recalculation, or replay record.
  IF v_quiz_status = 'published'::public.content_status THEN
    v_response_body := pg_catalog.jsonb_build_object(
      'id', p_quiz_id::text,
      'rowVersion', v_actual_row_version
    );
    RETURN QUERY SELECT 200, v_response_body;
    RETURN;
  END IF;
  IF v_quiz_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft quizzes can be published.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The draft quiz version is stale.';
  END IF;

  -- Revalidate the fully locked root to protect publication from malformed
  -- legacy rows. The definition guard is authoritative for the entire
  -- question/option/answer-key tree; this lifecycle facade must not recreate
  -- that validation or alter definition_version.
  IF v_slug IS NULL OR NOT private.is_valid_slug(v_slug) THEN
    RAISE EXCEPTION 'Draft quiz slug is invalid to publish.';
  END IF;
  IF v_title IS NULL
    OR v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
    OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
    RAISE EXCEPTION 'Draft quiz title must be trimmed and between 1 and 160 characters to publish.';
  END IF;
  PERFORM private.assert_markdown_input(
    v_instructions_markdown,
    20000,
    'Draft quiz instructionsMarkdown'
  );
  IF v_position IS NULL OR v_position < 0 THEN
    RAISE EXCEPTION 'Draft quiz position must be valid to publish.';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.quizzes AS sibling_entry
    WHERE sibling_entry.chapter_id = v_chapter_id
      AND sibling_entry.position = v_position
      AND sibling_entry.id <> p_quiz_id
  ) THEN
    RAISE EXCEPTION 'Draft quiz position is not unique within its chapter.';
  END IF;
  IF v_passing_percent IS NULL OR v_passing_percent NOT BETWEEN 0 AND 100 THEN
    RAISE EXCEPTION 'Draft quiz passingPercent must be between 0 and 100 to publish.';
  END IF;
  IF v_max_attempts IS NOT NULL
    AND v_max_attempts NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'Draft quiz maxAttempts must be null or between 1 and 100 to publish.';
  END IF;
  IF v_time_limit_seconds IS NOT NULL
    AND v_time_limit_seconds NOT BETWEEN 30 AND 86400 THEN
    RAISE EXCEPTION 'Draft quiz timeLimitSeconds must be null or between 30 and 86400 to publish.';
  END IF;
  IF v_is_required IS NULL THEN
    RAISE EXCEPTION 'Draft quiz isRequired must be present to publish.';
  END IF;
  IF v_published_at IS NOT NULL THEN
    RAISE EXCEPTION 'A draft quiz cannot already have a publication timestamp.';
  END IF;
  PERFORM private.validate_quiz_definition(p_quiz_id);

  -- The authored-row lifecycle and timestamp triggers own the exact version
  -- and updated-at changes. Do not rewrite definition, position, parent, or
  -- immutable creation fields in this lifecycle facade.
  UPDATE public.quizzes AS quiz_entry
  SET
    status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp(),
    updated_by = p_actor_user_id
  WHERE quiz_entry.id = p_quiz_id
    AND quiz_entry.chapter_id = v_chapter_id
    AND quiz_entry.status = 'draft'::public.content_status
    AND quiz_entry.row_version = p_expected_row_version
  RETURNING quiz_entry.row_version
  INTO v_next_row_version;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The draft quiz version changed concurrently; retry.';
  END IF;

  -- A published child under a draft ancestor is not learner-visible. Avoid
  -- reading any progress source or creating/changing a snapshot until both
  -- locked ancestors are published.
  IF v_module_status = 'published'::public.content_status
    AND v_chapter_status = 'published'::public.content_status THEN
    SELECT COALESCE(
      pg_catalog.array_agg(affected_user.user_id ORDER BY affected_user.user_id),
      ARRAY[]::uuid[]
    )
    INTO v_affected_user_ids
    FROM (
      SELECT progress_entry.user_id
      FROM public.chapter_progress AS progress_entry
      WHERE progress_entry.chapter_id = v_chapter_id

      UNION

      SELECT completion_entry.user_id
      FROM public.theory_section_completions AS completion_entry
      JOIN public.theory_sections AS theory_entry
        ON theory_entry.id = completion_entry.theory_section_id
      WHERE theory_entry.chapter_id = v_chapter_id

      UNION

      SELECT attempt_entry.user_id
      FROM public.exercise_attempts AS attempt_entry
      JOIN public.exercises AS exercise_entry
        ON exercise_entry.id = attempt_entry.exercise_id
      WHERE exercise_entry.chapter_id = v_chapter_id

      UNION

      SELECT attempt_entry.user_id
      FROM public.quiz_attempts AS attempt_entry
      JOIN public.quizzes AS quiz_entry
        ON quiz_entry.id = attempt_entry.quiz_id
      WHERE quiz_entry.chapter_id = v_chapter_id
    ) AS affected_user;

    -- Acquire every shared advisory key in the documented UUID order before
    -- the recalculator takes its per-user snapshot lock and write.
    FOREACH v_affected_user_id IN ARRAY v_affected_user_ids LOOP
      PERFORM private.lock_chapter_progress(
        v_affected_user_id,
        v_chapter_id
      );
    END LOOP;
    FOREACH v_affected_user_id IN ARRAY v_affected_user_ids LOOP
      PERFORM private.recalculate_chapter_progress(
        v_affected_user_id,
        v_chapter_id
      );
    END LOOP;
  END IF;

  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'quiz_published',
    'quiz',
    p_quiz_id,
    ARRAY['status']::text[],
    '{"status":{"before":"draft","after":"published"}}'::jsonb,
    NULL,
    p_request_id
  );

  v_response_body := pg_catalog.jsonb_build_object(
    'id', p_quiz_id::text,
    'rowVersion', v_next_row_version
  );
  RETURN QUERY SELECT 200, v_response_body;
END;
$assessment_publish_quiz$;

REVOKE ALL ON FUNCTION public.assessment_publish_quiz(
  uuid, uuid, integer, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.assessment_publish_quiz(
  uuid, uuid, integer, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
