-- SUP-FUNCTIONS-001 (assessment authoring slice): one narrowly scoped,
-- server-only scalar draft-exercise creation transaction. Future exercise
-- reorders and chapter archival must lock the same chapter row after the
-- canonical module-to-chapter hierarchy lock.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.assessment_create_draft_exercise(
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
AS $assessment_create_draft_exercise$
DECLARE
  v_replay record;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_title text;
  v_prompt_markdown text;
  v_exercise_type_text text;
  v_exercise_type public.exercise_type;
  v_points integer;
  v_is_required boolean;
  v_definition jsonb;
  v_options jsonb;
  v_option jsonb;
  v_answer_spec_input jsonb;
  v_stored_answer_spec jsonb;
  v_stored_option_ids jsonb;
  v_option_ref text;
  v_option_id uuid;
  v_option_ref_to_id jsonb := '{}'::jsonb;
  v_feedback_correct text;
  v_feedback_incorrect text;
  v_last_position integer;
  v_position integer;
  v_exercise_id uuid;
  v_response_location text;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to create an exercise.';
  END IF;
  IF p_chapter_id IS NULL THEN
    RAISE EXCEPTION 'A parent chapter is required to create an exercise.';
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'An idempotency key is required to create an exercise.';
  END IF;

  -- This live-profile lock intentionally precedes the replay lookup: a held
  -- or demoted actor cannot recover a historical authoring response.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  SELECT *
  INTO v_replay
  FROM private.acquire_idempotency_replay(
    p_actor_user_id,
    'admin_create_exercise',
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
      'title',
      'promptMarkdown',
      'exerciseType',
      'points',
      'isRequired',
      'options',
      'answerSpec'
    ]::text[],
    ARRAY[
      'title',
      'promptMarkdown',
      'exerciseType',
      'points',
      'isRequired',
      'options',
      'answerSpec',
      'feedbackCorrectMarkdown',
      'feedbackIncorrectMarkdown'
    ]::text[],
    'Draft scalar-exercise input'
  );

  v_title := private.assert_jsonb_string(
    p_input -> 'title',
    'Draft exercise title'
  );
  IF v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
    OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
    RAISE EXCEPTION 'Draft exercise title must be trimmed and between 1 and 160 characters.';
  END IF;

  v_prompt_markdown := private.assert_jsonb_string(
    p_input -> 'promptMarkdown',
    'Draft exercise promptMarkdown'
  );
  PERFORM private.assert_markdown_input(
    v_prompt_markdown,
    50000,
    'Draft exercise promptMarkdown'
  );

  v_exercise_type_text := private.assert_jsonb_string(
    p_input -> 'exerciseType',
    'Draft exercise exerciseType'
  );
  IF v_exercise_type_text NOT IN (
    'single_choice',
    'multiple_choice',
    'short_text'
  ) THEN
    RAISE EXCEPTION 'Draft exercise type must be one supported scalar type.';
  END IF;
  v_exercise_type := v_exercise_type_text::public.exercise_type;

  v_points := private.assert_jsonb_bounded_integer(
    p_input -> 'points',
    1,
    1000,
    'Draft exercise points'
  );

  IF pg_catalog.jsonb_typeof(p_input -> 'isRequired') <> 'boolean' THEN
    RAISE EXCEPTION 'Draft exercise isRequired must be boolean.';
  END IF;
  v_is_required := (p_input ->> 'isRequired')::boolean;

  v_definition := pg_catalog.jsonb_build_object(
    'options',
    p_input -> 'options',
    'answerSpec',
    p_input -> 'answerSpec'
  );
  IF p_input OPERATOR(pg_catalog.?) 'feedbackCorrectMarkdown' THEN
    v_definition := v_definition || pg_catalog.jsonb_build_object(
      'feedbackCorrectMarkdown',
      p_input -> 'feedbackCorrectMarkdown'
    );
  END IF;
  IF p_input OPERATOR(pg_catalog.?) 'feedbackIncorrectMarkdown' THEN
    v_definition := v_definition || pg_catalog.jsonb_build_object(
      'feedbackIncorrectMarkdown',
      p_input -> 'feedbackIncorrectMarkdown'
    );
  END IF;

  IF pg_catalog.jsonb_typeof(v_definition -> 'answerSpec') = 'null' THEN
    RAISE EXCEPTION 'Draft scalar exercises require a complete answer specification.';
  END IF;
  PERFORM private.validate_exercise_authoring_input(
    v_exercise_type,
    v_definition
  );

  v_options := v_definition -> 'options';
  IF v_exercise_type IN (
    'single_choice'::public.exercise_type,
    'multiple_choice'::public.exercise_type
  ) AND pg_catalog.jsonb_array_length(v_options) NOT BETWEEN 2 AND 20 THEN
    RAISE EXCEPTION 'Choice draft exercises require between two and twenty options.';
  END IF;
  IF v_exercise_type = 'short_text'::public.exercise_type
    AND pg_catalog.jsonb_array_length(v_options) <> 0 THEN
    RAISE EXCEPTION 'Short-text draft exercises cannot have options.';
  END IF;

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
    RAISE EXCEPTION 'An exercise cannot be created under an archived module.';
  END IF;
  IF v_chapter_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'An exercise cannot be created under an archived chapter.';
  END IF;

  -- The locked chapter row is the stable exercise sibling-scope mutex. It must
  -- be held before an append position is read, and reorder/archive code must
  -- reuse it rather than lock only the current exercise rows.
  SELECT COALESCE(pg_catalog.max(exercise.position), -1)
  INTO v_last_position
  FROM public.exercises AS exercise
  WHERE exercise.chapter_id = p_chapter_id;

  IF v_last_position = 2147483647 THEN
    RAISE EXCEPTION 'The exercise position space is exhausted for this chapter.';
  END IF;
  v_position := v_last_position + 1;

  INSERT INTO public.exercises (
    chapter_id,
    title,
    prompt_markdown,
    exercise_type,
    position,
    points,
    is_required,
    created_by,
    updated_by
  )
  VALUES (
    p_chapter_id,
    v_title,
    v_prompt_markdown,
    v_exercise_type,
    v_position,
    v_points,
    v_is_required,
    p_actor_user_id,
    p_actor_user_id
  )
  RETURNING id INTO v_exercise_id;

  -- New roots must retain row_version = definition_version = 1. The existing
  -- replacement helper increments both versions, so initial scalar material
  -- is constructed directly under the reviewed transaction-local tree marker.
  PERFORM pg_catalog.set_config(
    'coditza.assessment_tree_root',
    'exercise:' || v_exercise_id::text,
    true
  );

  IF pg_catalog.jsonb_array_length(v_options) > 0 THEN
    FOR v_option_index IN 0 .. pg_catalog.jsonb_array_length(v_options) - 1 LOOP
      v_option := v_options -> v_option_index;
      v_option_ref := v_option ->> 'clientRef';

      INSERT INTO public.exercise_options (
        exercise_id,
        label_markdown,
        position
      )
      VALUES (
        v_exercise_id,
        v_option ->> 'labelMarkdown',
        v_option_index
      )
      RETURNING id INTO v_option_id;

      v_option_ref_to_id := v_option_ref_to_id || pg_catalog.jsonb_build_object(
        v_option_ref,
        v_option_id::text
      );
    END LOOP;
  END IF;

  v_answer_spec_input := v_definition -> 'answerSpec';
  v_feedback_correct := private.optional_authoring_markdown(
    v_definition,
    'feedbackCorrectMarkdown',
    'Exercise feedbackCorrectMarkdown'
  );
  v_feedback_incorrect := private.optional_authoring_markdown(
    v_definition,
    'feedbackIncorrectMarkdown',
    'Exercise feedbackIncorrectMarkdown'
  );

  CASE v_exercise_type
    WHEN 'single_choice'::public.exercise_type THEN
      v_stored_answer_spec := pg_catalog.jsonb_build_object(
        'correctOptionId',
        v_option_ref_to_id ->> (v_answer_spec_input ->> 'correctOptionRef')
      );

    WHEN 'multiple_choice'::public.exercise_type THEN
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

    WHEN 'short_text'::public.exercise_type THEN
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
      RAISE EXCEPTION 'Draft exercise type must be one supported scalar type.';
  END CASE;

  INSERT INTO private.exercise_answer_keys (
    exercise_id,
    answer_spec,
    feedback_correct_markdown,
    feedback_incorrect_markdown,
    created_by,
    updated_by
  )
  VALUES (
    v_exercise_id,
    v_stored_answer_spec,
    v_feedback_correct,
    v_feedback_incorrect,
    p_actor_user_id,
    p_actor_user_id
  );

  PERFORM private.validate_exercise_definition(v_exercise_id);
  PERFORM pg_catalog.set_config('coditza.assessment_tree_root', '', true);

  v_response_location := '/api/v1/admin/exercises/' || v_exercise_id::text;
  -- Store only the generic safe creation envelope; option mappings, answer
  -- specs, feedback, and authored Markdown are never idempotency state.
  v_response_body := pg_catalog.jsonb_build_object('id', v_exercise_id::text);

  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'exercise_created',
    'exercise',
    v_exercise_id,
    ARRAY['status']::text[],
    '{"status":{"before":"none","after":"draft"}}'::jsonb,
    NULL,
    p_request_id
  );

  PERFORM private.complete_idempotency(
    p_actor_user_id,
    'admin_create_exercise',
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash,
    v_exercise_id,
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
$assessment_create_draft_exercise$;

REVOKE ALL ON FUNCTION public.assessment_create_draft_exercise(
  uuid, uuid, jsonb, uuid, integer, bytea, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.assessment_create_draft_exercise(
  uuid, uuid, jsonb, uuid, integer, bytea, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
