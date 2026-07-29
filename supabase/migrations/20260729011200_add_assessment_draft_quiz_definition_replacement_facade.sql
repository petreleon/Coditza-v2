-- SUP-FUNCTIONS-001 (assessment authoring slice): server-only atomic complete
-- draft-tree replacement. "Complete" means this payload replaces the entire
-- submitted tree; established incomplete-draft answerSpec semantics remain
-- valid until the separate publish workflow validates publishability.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION private.apply_draft_quiz_definition_replacement(
  p_quiz_id uuid,
  p_expected_row_version integer,
  p_definition jsonb,
  p_actor_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $apply_draft_quiz_definition_replacement$
DECLARE
  v_status public.content_status;
  v_actual_row_version integer;
  v_next_row_version integer;
  v_next_definition_version integer;
  v_questions jsonb;
  v_question jsonb;
  v_options jsonb;
  v_option jsonb;
  v_answer_spec_input jsonb;
  v_stored_answer_spec jsonb;
  v_stored_option_ids jsonb;
  v_question_ref text;
  v_question_id uuid;
  v_question_type text;
  v_option_ref text;
  v_option_id uuid;
  v_option_ref_to_id jsonb;
  v_question_mappings jsonb := '[]'::jsonb;
  v_option_mappings jsonb := '[]'::jsonb;
  v_feedback_correct text;
  v_feedback_incorrect text;
  v_marker_set boolean := false;
BEGIN
  IF p_quiz_id IS NULL THEN
    RAISE EXCEPTION 'A draft quiz is required to replace its definition.';
  END IF;
  IF p_expected_row_version IS NULL OR p_expected_row_version <= 0 THEN
    RAISE EXCEPTION 'A positive expected draft quiz version is required.';
  END IF;
  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A verified staff actor is required to replace a quiz definition.';
  END IF;

  SELECT quiz.status, quiz.row_version
  INTO v_status, v_actual_row_version
  FROM public.quizzes AS quiz
  WHERE quiz.id = p_quiz_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The draft quiz does not exist.';
  END IF;
  IF v_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft quizzes can replace their definition.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The quiz draft version is stale.';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.quiz_attempts AS attempt
    WHERE attempt.quiz_id = p_quiz_id
  ) THEN
    RAISE EXCEPTION 'A draft quiz with attempt history cannot replace its definition.';
  END IF;

  PERFORM private.validate_quiz_authoring_input(p_definition);

  BEGIN
    PERFORM pg_catalog.set_config(
      'coditza.assessment_tree_root',
      'quiz:' || p_quiz_id::text,
      true
    );
    v_marker_set := true;

    DELETE FROM private.quiz_question_answer_keys AS answer_key
    WHERE answer_key.question_id IN (
      SELECT question.id
      FROM public.quiz_questions AS question
      WHERE question.quiz_id = p_quiz_id
    );
    DELETE FROM public.quiz_question_options AS option_entry
    WHERE option_entry.question_id IN (
      SELECT question.id
      FROM public.quiz_questions AS question
      WHERE question.quiz_id = p_quiz_id
    );
    DELETE FROM public.quiz_questions AS question
    WHERE question.quiz_id = p_quiz_id;

    v_questions := p_definition -> 'questions';
    IF pg_catalog.jsonb_array_length(v_questions) > 0 THEN
      FOR v_question_index IN 0 .. pg_catalog.jsonb_array_length(v_questions) - 1 LOOP
        v_question := v_questions -> v_question_index;
        v_question_ref := v_question ->> 'clientRef';
        v_question_type := v_question ->> 'questionType';
        INSERT INTO public.quiz_questions (
          quiz_id,
          prompt_markdown,
          question_type,
          position,
          points
        )
        VALUES (
          p_quiz_id,
          v_question ->> 'promptMarkdown',
          v_question_type::public.question_type,
          v_question_index,
          (v_question ->> 'points')::integer
        )
        RETURNING id INTO v_question_id;

        v_question_mappings := v_question_mappings || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'clientRef',
            v_question_ref,
            'id',
            v_question_id::text
          )
        );

        v_options := v_question -> 'options';
        v_option_ref_to_id := '{}'::jsonb;
        IF pg_catalog.jsonb_array_length(v_options) > 0 THEN
          FOR v_option_index IN 0 .. pg_catalog.jsonb_array_length(v_options) - 1 LOOP
            v_option := v_options -> v_option_index;
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
            v_option_mappings := v_option_mappings || pg_catalog.jsonb_build_array(
              pg_catalog.jsonb_build_object(
                'questionClientRef',
                v_question_ref,
                'clientRef',
                v_option_ref,
                'id',
                v_option_id::text
              )
            );
          END LOOP;
        END IF;

        v_answer_spec_input := v_question -> 'answerSpec';
        IF pg_catalog.jsonb_typeof(v_answer_spec_input) <> 'null' THEN
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
            WHEN 'single_choice' THEN
              v_stored_answer_spec := pg_catalog.jsonb_build_object(
                'correctOptionId',
                v_option_ref_to_id ->> (v_answer_spec_input ->> 'correctOptionRef')
              );

            WHEN 'multiple_choice' THEN
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

            WHEN 'short_text' THEN
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
        END IF;
      END LOOP;
    END IF;

    -- The marker remains present through this one root update so the root
    -- trigger permits the tree-only definition-version advance. The authored
    -- lifecycle trigger supplies the matching single row-version increment.
    UPDATE public.quizzes AS quiz
    SET
      definition_version = quiz.definition_version + 1,
      updated_by = p_actor_user_id
    WHERE quiz.id = p_quiz_id
      AND quiz.row_version = p_expected_row_version
    RETURNING quiz.row_version, quiz.definition_version
    INTO v_next_row_version, v_next_definition_version;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'The quiz draft version changed concurrently; retry.';
    END IF;

    PERFORM pg_catalog.set_config('coditza.assessment_tree_root', '', true);
    v_marker_set := false;
  EXCEPTION WHEN OTHERS THEN
    IF v_marker_set THEN
      PERFORM pg_catalog.set_config('coditza.assessment_tree_root', '', true);
    END IF;
    RAISE;
  END;

  RETURN pg_catalog.jsonb_build_object(
    'quizId',
    p_quiz_id::text,
    'rowVersion',
    v_next_row_version,
    'definitionVersion',
    v_next_definition_version,
    'questionIdMappings',
    v_question_mappings,
    'optionIdMappings',
    v_option_mappings
  );
END;
$apply_draft_quiz_definition_replacement$;

CREATE FUNCTION public.assessment_replace_draft_quiz_definition(
  p_actor_user_id uuid,
  p_quiz_id uuid,
  p_expected_row_version integer,
  p_definition jsonb,
  p_request_id uuid
)
RETURNS TABLE (
  response_status integer,
  response_body jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $assessment_replace_draft_quiz_definition$
DECLARE
  v_chapter_id uuid;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_locked_chapter_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_quiz_status public.content_status;
  v_actual_row_version integer;
  v_patch_result jsonb;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to replace a quiz definition.';
  END IF;
  IF p_quiz_id IS NULL THEN
    RAISE EXCEPTION 'A draft quiz is required to replace its definition.';
  END IF;
  IF p_expected_row_version IS NULL OR p_expected_row_version <= 0 THEN
    RAISE EXCEPTION 'A positive expected draft quiz version is required.';
  END IF;

  -- Lock and inspect the live profile before any authoring content access.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  -- The payload is the entire submitted draft tree, but may intentionally
  -- contain an empty/incomplete draft as defined by the private envelope.
  PERFORM private.validate_quiz_authoring_input(p_definition);

  -- Discover the ancestor path without an inner lock, then take the canonical
  -- module -> chapter -> quiz locks and prove hierarchy stability at each step.
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

  SELECT quiz.chapter_id, quiz.status, quiz.row_version
  INTO v_locked_chapter_id, v_quiz_status, v_actual_row_version
  FROM public.quizzes AS quiz
  WHERE quiz.id = p_quiz_id
    AND quiz.chapter_id = v_chapter_id
  FOR UPDATE;

  IF NOT FOUND OR v_locked_chapter_id IS DISTINCT FROM v_chapter_id THEN
    RAISE EXCEPTION 'The draft quiz hierarchy changed concurrently; retry.';
  END IF;
  IF v_module_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A quiz definition cannot be replaced under an archived module.';
  END IF;
  IF v_chapter_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A quiz definition cannot be replaced under an archived chapter.';
  END IF;
  IF v_quiz_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft quizzes can replace their definition.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The quiz draft version is stale.';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.quiz_attempts AS attempt
    WHERE attempt.quiz_id = p_quiz_id
  ) THEN
    RAISE EXCEPTION 'A draft quiz with attempt history cannot replace its definition.';
  END IF;

  v_patch_result := private.apply_draft_quiz_definition_replacement(
    p_quiz_id,
    p_expected_row_version,
    p_definition,
    p_actor_user_id
  );

  -- Audit only the safe fact that one draft definition was replaced; it omits
  -- authored fields, answer keys, mappings, and raw before/after values.
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
    'rowVersion', (v_patch_result ->> 'rowVersion')::integer,
    'definitionVersion', (v_patch_result ->> 'definitionVersion')::integer,
    'questionIdMappings', v_patch_result -> 'questionIdMappings',
    'optionIdMappings', v_patch_result -> 'optionIdMappings'
  );
  RETURN QUERY SELECT 200, v_response_body;
END;
$assessment_replace_draft_quiz_definition$;

REVOKE ALL ON FUNCTION private.apply_draft_quiz_definition_replacement(
  uuid, integer, jsonb, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION public.assessment_replace_draft_quiz_definition(
  uuid, uuid, integer, jsonb, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.assessment_replace_draft_quiz_definition(
  uuid, uuid, integer, jsonb, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
