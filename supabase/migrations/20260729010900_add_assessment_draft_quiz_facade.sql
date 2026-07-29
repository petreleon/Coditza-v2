-- SUP-FUNCTIONS-001 (assessment authoring slice): one narrowly scoped,
-- server-only complete draft-quiz creation transaction. Future quiz reorders
-- and chapter archival must lock the same chapter row after the canonical
-- module-to-chapter hierarchy lock.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.assessment_create_draft_quiz(
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
AS $assessment_create_draft_quiz$
DECLARE
  v_replay record;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_slug text;
  v_title text;
  v_instructions_markdown text;
  v_passing_percent integer;
  v_max_attempts integer;
  v_time_limit_seconds integer;
  v_is_required boolean;
  v_definition jsonb;
  v_questions jsonb;
  v_question jsonb;
  v_question_options jsonb;
  v_option jsonb;
  v_question_type_text text;
  v_question_type public.question_type;
  v_answer_spec_input jsonb;
  v_stored_answer_spec jsonb;
  v_stored_option_ids jsonb;
  v_option_ref text;
  v_option_id uuid;
  v_option_ref_to_id jsonb;
  v_question_id uuid;
  v_feedback_correct text;
  v_feedback_incorrect text;
  v_last_position integer;
  v_position integer;
  v_quiz_id uuid;
  v_response_location text;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to create a quiz.';
  END IF;
  IF p_chapter_id IS NULL THEN
    RAISE EXCEPTION 'A parent chapter is required to create a quiz.';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'An idempotency key is required to create a quiz.';
  END IF;

  -- This live-profile lock intentionally precedes the replay lookup: a held
  -- or demoted actor cannot recover a historical authoring response.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  SELECT *
  INTO v_replay
  FROM private.acquire_idempotency_replay(
    p_actor_user_id,
    'admin_create_quiz',
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
      'instructionsMarkdown',
      'passingPercent',
      'maxAttempts',
      'timeLimitSeconds',
      'isRequired',
      'questions'
    ]::text[],
    ARRAY[
      'slug',
      'title',
      'instructionsMarkdown',
      'passingPercent',
      'maxAttempts',
      'timeLimitSeconds',
      'isRequired',
      'questions'
    ]::text[],
    'Draft complete-quiz input'
  );

  v_slug := private.assert_jsonb_string(
    p_input -> 'slug',
    'Draft quiz slug'
  );
  IF NOT private.is_valid_slug(v_slug) THEN
    RAISE EXCEPTION 'Draft quiz slug is invalid.';
  END IF;

  v_title := private.assert_jsonb_string(
    p_input -> 'title',
    'Draft quiz title'
  );
  IF v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
    OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
    RAISE EXCEPTION 'Draft quiz title must be trimmed and between 1 and 160 characters.';
  END IF;

  v_instructions_markdown := private.assert_jsonb_string(
    p_input -> 'instructionsMarkdown',
    'Draft quiz instructionsMarkdown'
  );
  PERFORM private.assert_markdown_input(
    v_instructions_markdown,
    20000,
    'Draft quiz instructionsMarkdown'
  );

  v_passing_percent := private.assert_jsonb_bounded_integer(
    p_input -> 'passingPercent',
    0,
    100,
    'Draft quiz passingPercent'
  );

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

  IF pg_catalog.jsonb_typeof(p_input -> 'isRequired') <> 'boolean' THEN
    RAISE EXCEPTION 'Draft quiz isRequired must be boolean.';
  END IF;
  v_is_required := (p_input ->> 'isRequired')::boolean;

  v_definition := pg_catalog.jsonb_build_object(
    'questions',
    p_input -> 'questions'
  );
  PERFORM private.validate_quiz_authoring_input(v_definition);
  v_questions := v_definition -> 'questions';

  -- The existing replacement helper allows incomplete draft definitions. This
  -- create facade intentionally makes only a complete, independently
  -- publishable quiz tree and validates that stronger contract before DML.
  IF pg_catalog.jsonb_array_length(v_questions) NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'Draft quiz creation requires between one and one hundred questions.';
  END IF;
  FOR v_question IN
    SELECT array_entry.value
    FROM pg_catalog.jsonb_array_elements(v_questions) AS array_entry(value)
  LOOP
    IF pg_catalog.jsonb_typeof(v_question -> 'answerSpec') = 'null' THEN
      RAISE EXCEPTION 'Draft quiz creation requires every question answer specification.';
    END IF;

    v_question_type_text := v_question ->> 'questionType';
    v_question_options := v_question -> 'options';
    IF v_question_type_text IN ('single_choice', 'multiple_choice')
      AND pg_catalog.jsonb_array_length(v_question_options) NOT BETWEEN 2 AND 20 THEN
      RAISE EXCEPTION 'Choice quiz questions require between two and twenty options.';
    END IF;
    IF v_question_type_text = 'short_text'
      AND pg_catalog.jsonb_array_length(v_question_options) <> 0 THEN
      RAISE EXCEPTION 'Short-text quiz questions cannot have options.';
    END IF;
  END LOOP;

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
    RAISE EXCEPTION 'A quiz cannot be created under an archived module.';
  END IF;
  IF v_chapter_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A quiz cannot be created under an archived chapter.';
  END IF;

  -- The locked chapter row is the stable quiz sibling-scope mutex. It must be
  -- held before an append position is read, and reorder/archive code must
  -- reuse it rather than lock only current quiz rows.
  SELECT COALESCE(pg_catalog.max(quiz.position), -1)
  INTO v_last_position
  FROM public.quizzes AS quiz
  WHERE quiz.chapter_id = p_chapter_id;

  IF v_last_position = 2147483647 THEN
    RAISE EXCEPTION 'The quiz position space is exhausted for this chapter.';
  END IF;
  v_position := v_last_position + 1;

  INSERT INTO public.quizzes (
    chapter_id,
    slug,
    title,
    instructions_markdown,
    position,
    passing_percent,
    max_attempts,
    time_limit_seconds,
    is_required,
    created_by,
    updated_by
  )
  VALUES (
    p_chapter_id,
    v_slug,
    v_title,
    v_instructions_markdown,
    v_position,
    v_passing_percent,
    v_max_attempts,
    v_time_limit_seconds,
    v_is_required,
    p_actor_user_id,
    p_actor_user_id
  )
  RETURNING id INTO v_quiz_id;

  -- New roots must retain row_version = definition_version = 1. The existing
  -- replacement helper increments both versions, so the initial complete
  -- question tree is constructed directly under the reviewed local marker.
  PERFORM pg_catalog.set_config(
    'coditza.assessment_tree_root',
    'quiz:' || v_quiz_id::text,
    true
  );

  FOR v_question_index IN 0 .. pg_catalog.jsonb_array_length(v_questions) - 1 LOOP
    v_question := v_questions -> v_question_index;
    v_question_type_text := v_question ->> 'questionType';
    v_question_type := v_question_type_text::public.question_type;

    INSERT INTO public.quiz_questions (
      quiz_id,
      prompt_markdown,
      question_type,
      position,
      points
    )
    VALUES (
      v_quiz_id,
      v_question ->> 'promptMarkdown',
      v_question_type,
      v_question_index,
      (v_question ->> 'points')::integer
    )
    RETURNING id INTO v_question_id;

    v_question_options := v_question -> 'options';
    v_option_ref_to_id := '{}'::jsonb;
    IF pg_catalog.jsonb_array_length(v_question_options) > 0 THEN
      FOR v_option_index IN 0 .. pg_catalog.jsonb_array_length(v_question_options) - 1 LOOP
        v_option := v_question_options -> v_option_index;
        v_option_ref := v_option ->> 'clientRef';

        INSERT INTO public.quiz_question_options (
          question_id,
          label_markdown,
          position
        )
        VALUES (
          v_question_id,
          v_option ->> 'labelMarkdown',
          v_option_index
        )
        RETURNING id INTO v_option_id;

        v_option_ref_to_id := v_option_ref_to_id
          || pg_catalog.jsonb_build_object(v_option_ref, v_option_id::text);
      END LOOP;
    END IF;

    v_answer_spec_input := v_question -> 'answerSpec';
    v_feedback_correct := private.optional_authoring_markdown(
      v_question,
      'feedbackCorrectMarkdown',
      'Quiz feedbackCorrectMarkdown'
    );
    v_feedback_incorrect := private.optional_authoring_markdown(
      v_question,
      'feedbackIncorrectMarkdown',
      'Quiz feedbackIncorrectMarkdown'
    );

    CASE v_question_type
      WHEN 'single_choice'::public.question_type THEN
        v_stored_answer_spec := pg_catalog.jsonb_build_object(
          'correctOptionId',
          v_option_ref_to_id ->> (v_answer_spec_input ->> 'correctOptionRef')
        );

      WHEN 'multiple_choice'::public.question_type THEN
        SELECT COALESCE(
          pg_catalog.jsonb_agg(
            pg_catalog.to_jsonb(mapped.option_id::text)
            ORDER BY mapped.option_id::text COLLATE "C"
          ),
          '[]'::jsonb
        )
        INTO v_stored_option_ids
        FROM (
          SELECT (
            v_option_ref_to_id ->> (array_entry.value #>> '{}')
          )::uuid AS option_id
          FROM pg_catalog.jsonb_array_elements(
            v_answer_spec_input -> 'correctOptionRefs'
          ) AS array_entry(value)
        ) AS mapped;
        v_stored_answer_spec := pg_catalog.jsonb_build_object(
          'correctOptionIds',
          v_stored_option_ids
        );

      WHEN 'short_text'::public.question_type THEN
        SELECT COALESCE(
          pg_catalog.jsonb_agg(
            pg_catalog.to_jsonb(
              private.normalize_short_text(array_entry.value #>> '{}')
            )
            ORDER BY array_entry.ordinality
          ),
          '[]'::jsonb
        )
        INTO v_stored_option_ids
        FROM pg_catalog.jsonb_array_elements(
          v_answer_spec_input -> 'acceptedAnswers'
        ) WITH ORDINALITY AS array_entry(value, ordinality);
        v_stored_answer_spec := pg_catalog.jsonb_build_object(
          'acceptedAnswers',
          v_stored_option_ids,
          'normalization',
          'nfkc_ascii_ws_ascii_lower_v1'
        );

      ELSE
        RAISE EXCEPTION 'Draft quiz question type is unsupported.';
    END CASE;

    INSERT INTO private.quiz_question_answer_keys (
      question_id,
      answer_spec,
      feedback_correct_markdown,
      feedback_incorrect_markdown,
      created_by,
      updated_by
    )
    VALUES (
      v_question_id,
      v_stored_answer_spec,
      v_feedback_correct,
      v_feedback_incorrect,
      p_actor_user_id,
      p_actor_user_id
    );
  END LOOP;

  PERFORM private.validate_quiz_definition(v_quiz_id);
  PERFORM pg_catalog.set_config('coditza.assessment_tree_root', '', true);

  v_response_location := '/api/v1/admin/quizzes/' || v_quiz_id::text;
  -- Store only the generic safe creation envelope; question/option mappings,
  -- answer specs, feedback, and authored Markdown are never idempotency state.
  v_response_body := pg_catalog.jsonb_build_object('id', v_quiz_id::text);

  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'quiz_created',
    'quiz',
    v_quiz_id,
    ARRAY['status']::text[],
    '{"status":{"before":"none","after":"draft"}}'::jsonb,
    NULL,
    p_request_id
  );

  PERFORM private.complete_idempotency(
    p_actor_user_id,
    'admin_create_quiz',
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash,
    v_quiz_id,
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
$assessment_create_draft_quiz$;

REVOKE ALL ON FUNCTION public.assessment_create_draft_quiz(
  uuid, uuid, jsonb, uuid, integer, bytea, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.assessment_create_draft_quiz(
  uuid, uuid, jsonb, uuid, integer, bytea, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
