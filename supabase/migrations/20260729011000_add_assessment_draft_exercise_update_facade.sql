-- SUP-FUNCTIONS-001 (assessment authoring slice): server-only partial PATCH
-- for scalar draft exercises. The public facade owns staff authorization and
-- canonical ancestor locking; the private helper owns the one-root-update,
-- complete-tree mutation so definition and row versions cannot double-advance.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION private.apply_draft_exercise_patch(
  p_exercise_id uuid,
  p_expected_row_version integer,
  p_next_title text,
  p_next_prompt_markdown text,
  p_next_exercise_type public.exercise_type,
  p_next_points integer,
  p_next_is_required boolean,
  p_replace_tree boolean,
  p_definition jsonb,
  p_actor_user_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $apply_draft_exercise_patch$
DECLARE
  v_current_exercise_type public.exercise_type;
  v_status public.content_status;
  v_actual_row_version integer;
  v_current_title text;
  v_current_prompt_markdown text;
  v_current_points integer;
  v_current_is_required boolean;
  v_root_changed boolean;
  v_options jsonb;
  v_option jsonb;
  v_answer_spec_input jsonb;
  v_stored_answer_spec jsonb;
  v_stored_option_ids jsonb;
  v_option_ref text;
  v_option_id uuid;
  v_option_ref_to_id jsonb := '{}'::jsonb;
  v_option_mappings jsonb := '[]'::jsonb;
  v_feedback_correct text;
  v_feedback_incorrect text;
  v_next_row_version integer;
  v_next_definition_version integer;
BEGIN
  IF p_exercise_id IS NULL THEN
    RAISE EXCEPTION 'A draft exercise is required to apply an update.';
  END IF;
  IF p_expected_row_version IS NULL OR p_expected_row_version <= 0 THEN
    RAISE EXCEPTION 'A positive expected draft exercise version is required.';
  END IF;
  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to update an exercise.';
  END IF;
  IF p_replace_tree IS NULL THEN
    RAISE EXCEPTION 'The draft exercise tree replacement flag is required.';
  END IF;

  SELECT
    exercise.exercise_type,
    exercise.status,
    exercise.row_version,
    exercise.title,
    exercise.prompt_markdown,
    exercise.points,
    exercise.is_required
  INTO
    v_current_exercise_type,
    v_status,
    v_actual_row_version,
    v_current_title,
    v_current_prompt_markdown,
    v_current_points,
    v_current_is_required
  FROM public.exercises AS exercise
  WHERE exercise.id = p_exercise_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The draft exercise does not exist.';
  END IF;
  IF v_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft exercises can be updated.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The exercise draft version is stale.';
  END IF;
  IF v_current_exercise_type NOT IN (
    'single_choice'::public.exercise_type,
    'multiple_choice'::public.exercise_type,
    'short_text'::public.exercise_type
  ) OR p_next_exercise_type NOT IN (
    'single_choice'::public.exercise_type,
    'multiple_choice'::public.exercise_type,
    'short_text'::public.exercise_type
  ) THEN
    RAISE EXCEPTION 'This facade supports scalar draft exercises only.';
  END IF;

  IF p_next_title IS NULL
    OR p_next_title IS DISTINCT FROM pg_catalog.btrim(p_next_title)
    OR pg_catalog.char_length(p_next_title) NOT BETWEEN 1 AND 160 THEN
    RAISE EXCEPTION 'Draft exercise title must be trimmed and between 1 and 160 characters.';
  END IF;
  PERFORM private.assert_markdown_input(
    p_next_prompt_markdown,
    50000,
    'Draft exercise promptMarkdown'
  );
  IF p_next_points IS NULL OR p_next_points NOT BETWEEN 1 AND 1000 THEN
    RAISE EXCEPTION 'Draft exercise points must be between 1 and 1000.';
  END IF;
  IF p_next_is_required IS NULL THEN
    RAISE EXCEPTION 'Draft exercise isRequired must be boolean.';
  END IF;

  v_root_changed :=
    p_next_title IS DISTINCT FROM v_current_title
    OR p_next_prompt_markdown IS DISTINCT FROM v_current_prompt_markdown
    OR p_next_exercise_type IS DISTINCT FROM v_current_exercise_type
    OR p_next_points IS DISTINCT FROM v_current_points
    OR p_next_is_required IS DISTINCT FROM v_current_is_required;

  IF NOT p_replace_tree AND p_definition IS NOT NULL THEN
    RAISE EXCEPTION 'A definition is allowed only with a complete tree replacement.';
  END IF;
  IF NOT p_replace_tree AND p_next_exercise_type IS DISTINCT FROM v_current_exercise_type THEN
    RAISE EXCEPTION 'Changing a draft exercise type requires a complete tree replacement.';
  END IF;

  IF NOT p_replace_tree AND NOT v_root_changed THEN
    RETURN pg_catalog.jsonb_build_object(
      'exerciseId', p_exercise_id::text,
      'rowVersion', v_actual_row_version,
      'definitionVersion', (
        SELECT exercise.definition_version
        FROM public.exercises AS exercise
        WHERE exercise.id = p_exercise_id
      ),
      'optionIdMappings', '[]'::jsonb
    );
  END IF;

  IF p_replace_tree THEN
    IF p_definition IS NULL THEN
      RAISE EXCEPTION 'A complete scalar draft definition is required.';
    END IF;
    PERFORM private.validate_exercise_authoring_input(
      p_next_exercise_type,
      p_definition
    );
  END IF;

  -- A published exercise cannot return to draft, so this is a defensive
  -- invariant for malformed historical rows. Any learner history freezes the
  -- draft root as well: a new definition would not match retained attempts.
  IF EXISTS (
    SELECT 1
    FROM public.exercise_attempts AS attempt
    WHERE attempt.exercise_id = p_exercise_id
  ) THEN
    RAISE EXCEPTION 'A draft exercise with learner attempts cannot be updated.';
  END IF;

  IF p_replace_tree THEN
    PERFORM pg_catalog.set_config(
      'coditza.assessment_tree_root',
      'exercise:' || p_exercise_id::text,
      true
    );

    DELETE FROM private.exercise_answer_keys AS answer_key
    WHERE answer_key.exercise_id = p_exercise_id;
    DELETE FROM public.exercise_options AS option_entry
    WHERE option_entry.exercise_id = p_exercise_id;
  END IF;

  -- This is the only root update in either the root-only or tree-replacement
  -- branch. The lifecycle trigger advances row_version once, while this update
  -- advances definition_version once. For a tree-only patch the marker authorizes
  -- the latter; for root fields the root validator sees the authored change.
  UPDATE public.exercises AS exercise
  SET
    title = p_next_title,
    prompt_markdown = p_next_prompt_markdown,
    exercise_type = p_next_exercise_type,
    points = p_next_points,
    is_required = p_next_is_required,
    definition_version = exercise.definition_version + 1,
    updated_by = p_actor_user_id
  WHERE exercise.id = p_exercise_id
  RETURNING row_version, definition_version
  INTO v_next_row_version, v_next_definition_version;

  IF p_replace_tree THEN
    v_options := p_definition -> 'options';
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
          p_exercise_id,
          v_option ->> 'labelMarkdown',
          v_option_index
        )
        RETURNING id INTO v_option_id;

        v_option_ref_to_id := v_option_ref_to_id
          || pg_catalog.jsonb_build_object(v_option_ref, v_option_id::text);
        v_option_mappings := v_option_mappings || pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'clientRef', v_option_ref,
            'id', v_option_id::text
          )
        );
      END LOOP;
    END IF;

    v_answer_spec_input := p_definition -> 'answerSpec';
    IF pg_catalog.jsonb_typeof(v_answer_spec_input) <> 'null' THEN
      v_feedback_correct := private.optional_authoring_markdown(
        p_definition,
        'feedbackCorrectMarkdown',
        'Exercise feedbackCorrectMarkdown'
      );
      v_feedback_incorrect := private.optional_authoring_markdown(
        p_definition,
        'feedbackIncorrectMarkdown',
        'Exercise feedbackIncorrectMarkdown'
      );

      CASE p_next_exercise_type
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
          RAISE EXCEPTION 'This facade supports scalar draft exercises only.';
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
        p_exercise_id,
        v_stored_answer_spec,
        v_feedback_correct,
        v_feedback_incorrect,
        p_actor_user_id,
        p_actor_user_id
      );
    END IF;

    PERFORM pg_catalog.set_config('coditza.assessment_tree_root', '', true);
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'exerciseId', p_exercise_id::text,
    'rowVersion', v_next_row_version,
    'definitionVersion', v_next_definition_version,
    'optionIdMappings', v_option_mappings
  );
END;
$apply_draft_exercise_patch$;

CREATE FUNCTION public.assessment_update_draft_exercise(
  p_actor_user_id uuid,
  p_exercise_id uuid,
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
AS $assessment_update_draft_exercise$
DECLARE
  v_chapter_id uuid;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_locked_chapter_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_exercise_status public.content_status;
  v_existing_title text;
  v_existing_prompt_markdown text;
  v_existing_exercise_type public.exercise_type;
  v_existing_points integer;
  v_existing_is_required boolean;
  v_actual_row_version integer;
  v_actual_definition_version integer;
  v_title text;
  v_prompt_markdown text;
  v_exercise_type_text text;
  v_exercise_type public.exercise_type;
  v_points integer;
  v_is_required boolean;
  v_replace_tree boolean;
  v_definition jsonb;
  v_root_changed boolean;
  v_patch_result jsonb;
  v_next_row_version integer;
  v_next_definition_version integer;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to update an exercise.';
  END IF;
  IF p_exercise_id IS NULL THEN
    RAISE EXCEPTION 'A draft exercise is required to update.';
  END IF;
  IF p_expected_row_version IS NULL OR p_expected_row_version <= 0 THEN
    RAISE EXCEPTION 'A positive expected draft exercise version is required.';
  END IF;

  -- Lock and inspect the live profile before any authoring content access.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  PERFORM private.assert_jsonb_object_keys(
    p_input,
    ARRAY[]::text[],
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
    'Draft exercise update input'
  );
  IF p_input = '{}'::jsonb THEN
    RAISE EXCEPTION 'A draft exercise update needs at least one allowed field.';
  END IF;

  v_replace_tree :=
    p_input OPERATOR(pg_catalog.?) 'options'
    OR p_input OPERATOR(pg_catalog.?) 'answerSpec'
    OR p_input OPERATOR(pg_catalog.?) 'feedbackCorrectMarkdown'
    OR p_input OPERATOR(pg_catalog.?) 'feedbackIncorrectMarkdown';
  IF v_replace_tree
    AND (
      NOT (p_input OPERATOR(pg_catalog.?) 'options')
      OR NOT (p_input OPERATOR(pg_catalog.?) 'answerSpec')
    ) THEN
    RAISE EXCEPTION
      'A draft exercise tree update requires both options and answerSpec.';
  END IF;

  -- Discover the current ancestor path without an inner lock, then acquire the
  -- canonical module -> chapter -> exercise locks and prove each relationship
  -- stayed stable while that outer lock was acquired.
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
    exercise.chapter_id,
    exercise.status,
    exercise.title,
    exercise.prompt_markdown,
    exercise.exercise_type,
    exercise.points,
    exercise.is_required,
    exercise.row_version,
    exercise.definition_version
  INTO
    v_locked_chapter_id,
    v_exercise_status,
    v_existing_title,
    v_existing_prompt_markdown,
    v_existing_exercise_type,
    v_existing_points,
    v_existing_is_required,
    v_actual_row_version,
    v_actual_definition_version
  FROM public.exercises AS exercise
  WHERE exercise.id = p_exercise_id
    AND exercise.chapter_id = v_chapter_id
  FOR UPDATE;

  IF NOT FOUND OR v_locked_chapter_id IS DISTINCT FROM v_chapter_id THEN
    RAISE EXCEPTION 'The draft exercise hierarchy changed concurrently; retry.';
  END IF;
  IF v_module_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'An exercise cannot be updated under an archived module.';
  END IF;
  IF v_chapter_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'An exercise cannot be updated under an archived chapter.';
  END IF;
  IF v_exercise_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft exercises can be updated.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The exercise draft version is stale.';
  END IF;
  IF v_existing_exercise_type NOT IN (
    'single_choice'::public.exercise_type,
    'multiple_choice'::public.exercise_type,
    'short_text'::public.exercise_type
  ) THEN
    RAISE EXCEPTION 'This facade supports scalar draft exercises only.';
  END IF;

  v_title := v_existing_title;
  IF p_input OPERATOR(pg_catalog.?) 'title' THEN
    v_title := private.assert_jsonb_string(
      p_input -> 'title',
      'Draft exercise title'
    );
    IF v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
      OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
      RAISE EXCEPTION 'Draft exercise title must be trimmed and between 1 and 160 characters.';
    END IF;
  END IF;

  v_prompt_markdown := v_existing_prompt_markdown;
  IF p_input OPERATOR(pg_catalog.?) 'promptMarkdown' THEN
    v_prompt_markdown := private.assert_jsonb_string(
      p_input -> 'promptMarkdown',
      'Draft exercise promptMarkdown'
    );
    PERFORM private.assert_markdown_input(
      v_prompt_markdown,
      50000,
      'Draft exercise promptMarkdown'
    );
  END IF;

  v_exercise_type := v_existing_exercise_type;
  IF p_input OPERATOR(pg_catalog.?) 'exerciseType' THEN
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
  END IF;

  v_points := v_existing_points;
  IF p_input OPERATOR(pg_catalog.?) 'points' THEN
    v_points := private.assert_jsonb_bounded_integer(
      p_input -> 'points',
      1,
      1000,
      'Draft exercise points'
    );
  END IF;

  v_is_required := v_existing_is_required;
  IF p_input OPERATOR(pg_catalog.?) 'isRequired' THEN
    IF pg_catalog.jsonb_typeof(p_input -> 'isRequired') <> 'boolean' THEN
      RAISE EXCEPTION 'Draft exercise isRequired must be boolean.';
    END IF;
    v_is_required := (p_input ->> 'isRequired')::boolean;
  END IF;

  IF NOT v_replace_tree
    AND v_exercise_type IS DISTINCT FROM v_existing_exercise_type THEN
    RAISE EXCEPTION 'Changing a draft exercise type requires a complete tree replacement.';
  END IF;

  IF v_replace_tree THEN
    v_definition := pg_catalog.jsonb_build_object(
      'options', p_input -> 'options',
      'answerSpec', p_input -> 'answerSpec'
    );
    IF p_input OPERATOR(pg_catalog.?) 'feedbackCorrectMarkdown' THEN
      v_definition := v_definition || pg_catalog.jsonb_build_object(
        'feedbackCorrectMarkdown', p_input -> 'feedbackCorrectMarkdown'
      );
    END IF;
    IF p_input OPERATOR(pg_catalog.?) 'feedbackIncorrectMarkdown' THEN
      v_definition := v_definition || pg_catalog.jsonb_build_object(
        'feedbackIncorrectMarkdown', p_input -> 'feedbackIncorrectMarkdown'
      );
    END IF;
    PERFORM private.validate_exercise_authoring_input(
      v_exercise_type,
      v_definition
    );
  END IF;

  v_root_changed :=
    v_title IS DISTINCT FROM v_existing_title
    OR v_prompt_markdown IS DISTINCT FROM v_existing_prompt_markdown
    OR v_exercise_type IS DISTINCT FROM v_existing_exercise_type
    OR v_points IS DISTINCT FROM v_existing_points
    OR v_is_required IS DISTINCT FROM v_existing_is_required;

  IF NOT v_replace_tree AND NOT v_root_changed THEN
    v_response_body := pg_catalog.jsonb_build_object(
      'id', p_exercise_id::text,
      'rowVersion', v_actual_row_version,
      'definitionVersion', v_actual_definition_version
    );
    RETURN QUERY SELECT 200, v_response_body;
    RETURN;
  END IF;

  v_patch_result := private.apply_draft_exercise_patch(
    p_exercise_id,
    p_expected_row_version,
    v_title,
    v_prompt_markdown,
    v_exercise_type,
    v_points,
    v_is_required,
    v_replace_tree,
    v_definition,
    p_actor_user_id
  );
  v_next_row_version := (v_patch_result ->> 'rowVersion')::integer;
  v_next_definition_version := (v_patch_result ->> 'definitionVersion')::integer;

  -- The audit record describes only the safe fact that a draft definition was
  -- changed. It deliberately omits authored fields, answer keys, mappings, and
  -- raw before/after values.
  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'exercise_updated',
    'exercise',
    p_exercise_id,
    ARRAY['definition']::text[],
    '{"definition":{"before":"draft","after":"updated"}}'::jsonb,
    NULL,
    p_request_id
  );

  v_response_body := pg_catalog.jsonb_build_object(
    'id', p_exercise_id::text,
    'rowVersion', v_next_row_version,
    'definitionVersion', v_next_definition_version
  );
  RETURN QUERY SELECT 200, v_response_body;
END;
$assessment_update_draft_exercise$;

REVOKE ALL ON FUNCTION private.apply_draft_exercise_patch(
  uuid, integer, text, text, public.exercise_type, integer, boolean, boolean,
  jsonb, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION public.assessment_update_draft_exercise(
  uuid, uuid, integer, jsonb, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.assessment_update_draft_exercise(
  uuid, uuid, integer, jsonb, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
