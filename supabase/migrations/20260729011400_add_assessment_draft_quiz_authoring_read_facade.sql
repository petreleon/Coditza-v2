-- SUP-FUNCTIONS-001 (assessment authoring slice): a narrowly scoped,
-- server-only protected projection of one nested draft quiz definition.
-- It remains distinct from ordinary quiz detail/list reads, which must never
-- expose stored answer specifications or feedback.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.assessment_get_draft_quiz_authoring(
  p_actor_user_id uuid,
  p_quiz_id uuid,
  p_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $assessment_get_draft_quiz_authoring$
DECLARE
  v_chapter_id uuid;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_locked_quiz_chapter_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_quiz_status public.content_status;
  v_questions jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to read a draft quiz definition.';
  END IF;
  IF p_quiz_id IS NULL THEN
    RAISE EXCEPTION 'A draft quiz is required to read its authoring definition.';
  END IF;

  -- Lock and inspect the live profile before any protected content access.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  -- Discover the hierarchy once, then take canonical shared locks. Legal
  -- draft-tree writers take the corresponding root update lock before they
  -- set the marker or touch questions, options, or private keys.
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

  SELECT quiz.chapter_id, quiz.status
  INTO v_locked_quiz_chapter_id, v_quiz_status
  FROM public.quizzes AS quiz
  WHERE quiz.id = p_quiz_id
    AND quiz.chapter_id = v_chapter_id
  FOR SHARE;

  IF NOT FOUND OR v_locked_quiz_chapter_id IS DISTINCT FROM v_chapter_id THEN
    RAISE EXCEPTION 'The draft quiz hierarchy changed concurrently; retry.';
  END IF;
  IF v_module_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A draft quiz definition cannot be read under an archived module.';
  END IF;
  IF v_chapter_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A draft quiz definition cannot be read under an archived chapter.';
  END IF;
  IF v_quiz_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft quiz definitions are available for protected authoring.';
  END IF;

  SELECT COALESCE(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'id', question_entry.id::text,
        'promptMarkdown', question_entry.prompt_markdown,
        'questionType', question_entry.question_type::text,
        'points', question_entry.points,
        'options', option_projection.options,
        'answerSpec', answer_key.answer_spec,
        'feedbackCorrectMarkdown', answer_key.feedback_correct_markdown,
        'feedbackIncorrectMarkdown', answer_key.feedback_incorrect_markdown
      )
      ORDER BY question_entry.position, question_entry.id
    ),
    '[]'::jsonb
  )
  INTO v_questions
  FROM public.quiz_questions AS question_entry
  LEFT JOIN private.quiz_question_answer_keys AS answer_key
    ON answer_key.question_id = question_entry.id
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
    FROM public.quiz_question_options AS option_entry
    WHERE option_entry.question_id = question_entry.id
  ) AS option_projection
  WHERE question_entry.quiz_id = p_quiz_id;

  -- This records protected-definition access only. No authored content,
  -- answer specification, feedback, mapping, or key metadata enters audit.
  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'quiz_authoring_accessed',
    'quiz',
    p_quiz_id,
    ARRAY[]::text[],
    '{}'::jsonb,
    NULL,
    p_request_id
  );

  RETURN pg_catalog.jsonb_build_object('questions', v_questions);
END;
$assessment_get_draft_quiz_authoring$;

REVOKE ALL ON FUNCTION public.assessment_get_draft_quiz_authoring(
  uuid, uuid, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.assessment_get_draft_quiz_authoring(
  uuid, uuid, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
