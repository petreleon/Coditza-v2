-- SUP-FUNCTIONS-001 (assessment authoring slice): a narrowly scoped,
-- server-only protected projection of one scalar draft exercise definition.
-- This is intentionally separate from the nested quiz projection and from
-- ordinary admin detail/list reads, which must never expose answer material.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.assessment_get_draft_exercise_authoring(
  p_actor_user_id uuid,
  p_exercise_id uuid,
  p_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $assessment_get_draft_exercise_authoring$
DECLARE
  v_chapter_id uuid;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_locked_exercise_chapter_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_exercise_status public.content_status;
  v_exercise_type public.exercise_type;
  v_result jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to read a draft exercise definition.';
  END IF;
  IF p_exercise_id IS NULL THEN
    RAISE EXCEPTION 'A draft exercise is required to read its authoring definition.';
  END IF;

  -- Lock and inspect the live profile before any protected content access.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  -- Discover the hierarchy once, then take canonical shared locks. Every
  -- named draft writer takes the corresponding root update lock before a
  -- marker-gated child write, so this stabilizes the returned tree.
  SELECT exercise.chapter_id
  INTO v_chapter_id
  FROM public.exercises AS exercise
  WHERE exercise.id = p_exercise_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The draft exercise does not exist.';
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
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The parent module no longer exists.';
  END IF;

  SELECT chapter.module_id, chapter.status
  INTO v_locked_module_id, v_chapter_status
  FROM public.chapters AS chapter
  WHERE chapter.id = v_chapter_id
    AND chapter.module_id = v_module_id
  FOR SHARE;

  IF NOT FOUND OR v_locked_module_id IS DISTINCT FROM v_module_id THEN
    RAISE EXCEPTION 'The parent chapter hierarchy changed concurrently; retry.';
  END IF;

  SELECT exercise.chapter_id, exercise.status, exercise.exercise_type
  INTO v_locked_exercise_chapter_id, v_exercise_status, v_exercise_type
  FROM public.exercises AS exercise
  WHERE exercise.id = p_exercise_id
    AND exercise.chapter_id = v_chapter_id
  FOR SHARE;

  IF NOT FOUND OR v_locked_exercise_chapter_id IS DISTINCT FROM v_chapter_id THEN
    RAISE EXCEPTION 'The draft exercise hierarchy changed concurrently; retry.';
  END IF;
  IF v_module_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A draft exercise definition cannot be read under an archived module.';
  END IF;
  IF v_chapter_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A draft exercise definition cannot be read under an archived chapter.';
  END IF;
  IF v_exercise_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft exercise definitions are available for protected authoring.';
  END IF;
  IF v_exercise_type NOT IN (
    'single_choice'::public.exercise_type,
    'multiple_choice'::public.exercise_type,
    'short_text'::public.exercise_type
  ) THEN
    -- The private Python definition/projection belongs to SUP-WASM-001.
    RAISE EXCEPTION 'This protected authoring facade supports scalar draft exercises only.';
  END IF;

  SELECT pg_catalog.jsonb_build_object(
    'options', option_projection.options,
    'answerSpec', answer_key.answer_spec,
    'feedbackCorrectMarkdown', answer_key.feedback_correct_markdown,
    'feedbackIncorrectMarkdown', answer_key.feedback_incorrect_markdown
  )
  INTO v_result
  FROM public.exercises AS exercise
  LEFT JOIN private.exercise_answer_keys AS answer_key
    ON answer_key.exercise_id = exercise.id
  CROSS JOIN LATERAL (
    SELECT COALESCE(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', option_entry.id::text,
          'labelMarkdown', option_entry.label_markdown
        )
        ORDER BY option_entry.position, option_entry.id
      ),
      '[]'::jsonb
    ) AS options
    FROM public.exercise_options AS option_entry
    WHERE option_entry.exercise_id = exercise.id
  ) AS option_projection
  WHERE exercise.id = p_exercise_id;

  IF v_result IS NULL THEN
    RAISE EXCEPTION 'The draft exercise authoring definition disappeared concurrently; retry.';
  END IF;

  -- This records only protected-definition access. It intentionally exposes
  -- no authored content, answer key, mapping, or key metadata in the audit.
  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'exercise_authoring_accessed',
    'exercise',
    p_exercise_id,
    ARRAY[]::text[],
    '{}'::jsonb,
    NULL,
    p_request_id
  );

  RETURN v_result;
END;
$assessment_get_draft_exercise_authoring$;

REVOKE ALL ON FUNCTION public.assessment_get_draft_exercise_authoring(
  uuid, uuid, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.assessment_get_draft_exercise_authoring(
  uuid, uuid, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
