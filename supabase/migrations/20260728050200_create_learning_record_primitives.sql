-- SUP-DATA-003: owner-only workflow primitives and state guards for learning
-- records. These are not public RPC facades and receive no runtime grants.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION private.assert_effectively_published_theory_section(
  p_theory_section_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_effectively_published_theory_section$
DECLARE
  v_chapter_id uuid;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_locked_chapter_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_theory_status public.content_status;
BEGIN
  -- Lock the curriculum tree outer-to-inner. The initial parent lookup is
  -- deliberately rechecked after each lock so a concurrent reparent/change
  -- fails safely instead of validating a mixed hierarchy snapshot.
  SELECT theory_section.chapter_id
  INTO v_chapter_id
  FROM public.theory_sections AS theory_section
  WHERE theory_section.id = p_theory_section_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Theory completion requires an effectively published theory section.';
  END IF;

  SELECT chapter.module_id
  INTO v_module_id
  FROM public.chapters AS chapter
  WHERE chapter.id = v_chapter_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Theory completion hierarchy changed concurrently; retry.';
  END IF;

  SELECT module_entry.status
  INTO v_module_status
  FROM public.modules AS module_entry
  WHERE module_entry.id = v_module_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Theory completion hierarchy changed concurrently; retry.';
  END IF;

  SELECT chapter.module_id, chapter.status
  INTO v_locked_module_id, v_chapter_status
  FROM public.chapters AS chapter
  WHERE chapter.id = v_chapter_id
  FOR UPDATE;
  IF NOT FOUND OR v_locked_module_id IS DISTINCT FROM v_module_id THEN
    RAISE EXCEPTION 'Theory completion hierarchy changed concurrently; retry.';
  END IF;

  SELECT theory_section.chapter_id, theory_section.status
  INTO v_locked_chapter_id, v_theory_status
  FROM public.theory_sections AS theory_section
  WHERE theory_section.id = p_theory_section_id
  FOR UPDATE;
  IF NOT FOUND OR v_locked_chapter_id IS DISTINCT FROM v_chapter_id THEN
    RAISE EXCEPTION 'Theory completion hierarchy changed concurrently; retry.';
  END IF;

  IF v_theory_status <> 'published'::public.content_status
    OR v_chapter_status <> 'published'::public.content_status
    OR v_module_status <> 'published'::public.content_status THEN
    RAISE EXCEPTION 'Theory completion requires an effectively published theory section.';
  END IF;

  RETURN v_chapter_id;
END;
$assert_effectively_published_theory_section$;

CREATE FUNCTION private.assert_effectively_published_exercise(
  p_exercise_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_effectively_published_exercise$
DECLARE
  v_chapter_id uuid;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_locked_chapter_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_exercise_status public.content_status;
BEGIN
  SELECT exercise.chapter_id
  INTO v_chapter_id
  FROM public.exercises AS exercise
  WHERE exercise.id = p_exercise_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Exercise submission requires an effectively published exercise.';
  END IF;

  SELECT chapter.module_id
  INTO v_module_id
  FROM public.chapters AS chapter
  WHERE chapter.id = v_chapter_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Exercise hierarchy changed concurrently; retry.';
  END IF;

  SELECT module_entry.status
  INTO v_module_status
  FROM public.modules AS module_entry
  WHERE module_entry.id = v_module_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Exercise hierarchy changed concurrently; retry.';
  END IF;

  SELECT chapter.module_id, chapter.status
  INTO v_locked_module_id, v_chapter_status
  FROM public.chapters AS chapter
  WHERE chapter.id = v_chapter_id
  FOR UPDATE;
  IF NOT FOUND OR v_locked_module_id IS DISTINCT FROM v_module_id THEN
    RAISE EXCEPTION 'Exercise hierarchy changed concurrently; retry.';
  END IF;

  SELECT exercise.chapter_id, exercise.status
  INTO v_locked_chapter_id, v_exercise_status
  FROM public.exercises AS exercise
  WHERE exercise.id = p_exercise_id
  FOR UPDATE;
  IF NOT FOUND OR v_locked_chapter_id IS DISTINCT FROM v_chapter_id THEN
    RAISE EXCEPTION 'Exercise hierarchy changed concurrently; retry.';
  END IF;

  IF v_exercise_status <> 'published'::public.content_status
    OR v_chapter_status <> 'published'::public.content_status
    OR v_module_status <> 'published'::public.content_status THEN
    RAISE EXCEPTION 'Exercise submission requires an effectively published exercise.';
  END IF;

  RETURN v_chapter_id;
END;
$assert_effectively_published_exercise$;

CREATE FUNCTION private.assert_effectively_published_quiz(
  p_quiz_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_effectively_published_quiz$
DECLARE
  v_chapter_id uuid;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_locked_chapter_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_quiz_status public.content_status;
BEGIN
  SELECT quiz.chapter_id
  INTO v_chapter_id
  FROM public.quizzes AS quiz
  WHERE quiz.id = p_quiz_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quiz start requires an effectively published quiz.';
  END IF;

  SELECT chapter.module_id
  INTO v_module_id
  FROM public.chapters AS chapter
  WHERE chapter.id = v_chapter_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quiz hierarchy changed concurrently; retry.';
  END IF;

  SELECT module_entry.status
  INTO v_module_status
  FROM public.modules AS module_entry
  WHERE module_entry.id = v_module_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Quiz hierarchy changed concurrently; retry.';
  END IF;

  SELECT chapter.module_id, chapter.status
  INTO v_locked_module_id, v_chapter_status
  FROM public.chapters AS chapter
  WHERE chapter.id = v_chapter_id
  FOR UPDATE;
  IF NOT FOUND OR v_locked_module_id IS DISTINCT FROM v_module_id THEN
    RAISE EXCEPTION 'Quiz hierarchy changed concurrently; retry.';
  END IF;

  SELECT quiz.chapter_id, quiz.status
  INTO v_locked_chapter_id, v_quiz_status
  FROM public.quizzes AS quiz
  WHERE quiz.id = p_quiz_id
  FOR UPDATE;
  IF NOT FOUND OR v_locked_chapter_id IS DISTINCT FROM v_chapter_id THEN
    RAISE EXCEPTION 'Quiz hierarchy changed concurrently; retry.';
  END IF;

  IF v_quiz_status <> 'published'::public.content_status
    OR v_chapter_status <> 'published'::public.content_status
    OR v_module_status <> 'published'::public.content_status THEN
    RAISE EXCEPTION 'Quiz start requires an effectively published quiz.';
  END IF;

  RETURN v_chapter_id;
END;
$assert_effectively_published_quiz$;

CREATE FUNCTION private.lock_chapter_progress(
  p_user_id uuid,
  p_chapter_id uuid
)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $lock_chapter_progress$
  SELECT pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'coditza:chapter-progress:' || p_user_id::text || ':' || p_chapter_id::text,
      0
    )
  );
$lock_chapter_progress$;

CREATE FUNCTION private.assert_learning_write_marker(p_expected_marker text)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_learning_write_marker$
BEGIN
  IF pg_catalog.current_setting('coditza.learning_write', true)
    IS DISTINCT FROM p_expected_marker THEN
    RAISE EXCEPTION 'Learning records may change only through their owner-only workflow primitive.';
  END IF;
END;
$assert_learning_write_marker$;

CREATE FUNCTION private.assert_active_learning_actor(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_active_learning_actor$
BEGIN
  PERFORM 1
  FROM public.profiles AS profile
  WHERE profile.id = p_user_id
    AND profile.security_hold_at IS NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Learning-record workflows require an active learner profile.';
  END IF;
END;
$assert_active_learning_actor$;

CREATE FUNCTION private.assert_exact_jsonb_object_keys(
  p_value jsonb,
  p_keys text[],
  p_context text
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_exact_jsonb_object_keys$
BEGIN
  PERFORM private.assert_jsonb_object_keys(
    p_value,
    p_keys,
    p_keys,
    p_context
  );
END;
$assert_exact_jsonb_object_keys$;

CREATE FUNCTION private.grade_scalar_exercise_answer(
  p_exercise_id uuid,
  p_answer jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $grade_scalar_exercise_answer$
DECLARE
  v_exercise_type public.exercise_type;
  v_points_possible integer;
  v_answer_spec jsonb;
  v_option_id uuid;
  v_option_ids uuid[] := ARRAY[]::uuid[];
  v_normalized_option_ids jsonb;
  v_text text;
  v_normalized_text text;
  v_is_correct boolean;
  v_normalized_answer jsonb;
BEGIN
  SELECT exercise.exercise_type, exercise.points, answer_key.answer_spec
  INTO v_exercise_type, v_points_possible, v_answer_spec
  FROM public.exercises AS exercise
  LEFT JOIN private.exercise_answer_keys AS answer_key
    ON answer_key.exercise_id = exercise.id
  WHERE exercise.id = p_exercise_id;

  IF NOT FOUND OR v_answer_spec IS NULL THEN
    RAISE EXCEPTION 'The scalar exercise definition is unavailable.';
  END IF;

  IF v_exercise_type = 'python_code'::public.exercise_type THEN
    RAISE EXCEPTION 'Python exercises cannot enter the scalar exercise grader.';
  END IF;

  CASE v_exercise_type
    WHEN 'single_choice'::public.exercise_type THEN
      PERFORM private.assert_exact_jsonb_object_keys(
        p_answer,
        ARRAY['optionId']::text[],
        'Single-choice exercise answer'
      );
      v_option_id := private.assert_canonical_uuid_text(
        private.assert_jsonb_string(
          p_answer -> 'optionId',
          'Single-choice exercise optionId'
        ),
        'Single-choice exercise optionId'
      );
      IF NOT EXISTS (
        SELECT 1
        FROM public.exercise_options AS option_entry
        WHERE option_entry.id = v_option_id
          AND option_entry.exercise_id = p_exercise_id
      ) THEN
        RAISE EXCEPTION 'The exercise answer references an option from another exercise.';
      END IF;
      v_normalized_answer := pg_catalog.jsonb_build_object(
        'optionId',
        v_option_id::text
      );
      v_is_correct := (v_answer_spec ->> 'correctOptionId') = v_option_id::text;

    WHEN 'multiple_choice'::public.exercise_type THEN
      PERFORM private.assert_exact_jsonb_object_keys(
        p_answer,
        ARRAY['optionIds']::text[],
        'Multiple-choice exercise answer'
      );
      IF pg_catalog.jsonb_typeof(p_answer -> 'optionIds') <> 'array'
        OR pg_catalog.jsonb_array_length(p_answer -> 'optionIds') NOT BETWEEN 1 AND 20 THEN
        RAISE EXCEPTION 'Multiple-choice exercise optionIds must contain one through twenty options.';
      END IF;

      FOR v_text IN
        SELECT private.assert_jsonb_string(
          option_value.value,
          'Multiple-choice exercise option ID'
        )
        FROM pg_catalog.jsonb_array_elements(p_answer -> 'optionIds')
          AS option_value(value)
      LOOP
        v_option_id := private.assert_canonical_uuid_text(
          v_text,
          'Multiple-choice exercise option ID'
        );
        IF v_option_id = ANY (v_option_ids) THEN
          RAISE EXCEPTION 'Multiple-choice exercise option IDs must be unique.';
        END IF;
        IF NOT EXISTS (
          SELECT 1
          FROM public.exercise_options AS option_entry
          WHERE option_entry.id = v_option_id
            AND option_entry.exercise_id = p_exercise_id
        ) THEN
          RAISE EXCEPTION 'The exercise answer references an option from another exercise.';
        END IF;
        v_option_ids := pg_catalog.array_append(v_option_ids, v_option_id);
      END LOOP;

      SELECT pg_catalog.jsonb_agg(
        pg_catalog.to_jsonb(option_id::text)
        ORDER BY option_id::text COLLATE "C"
      )
      INTO v_normalized_option_ids
      FROM pg_catalog.unnest(v_option_ids) AS option_id;
      v_normalized_answer := pg_catalog.jsonb_build_object(
        'optionIds',
        v_normalized_option_ids
      );
      v_is_correct := (v_answer_spec -> 'correctOptionIds') = v_normalized_option_ids;

    WHEN 'short_text'::public.exercise_type THEN
      PERFORM private.assert_exact_jsonb_object_keys(
        p_answer,
        ARRAY['text']::text[],
        'Short-text exercise answer'
      );
      v_text := private.assert_jsonb_string(
        p_answer -> 'text',
        'Short-text exercise text'
      );
      IF pg_catalog.char_length(v_text) NOT BETWEEN 1 AND 4000 THEN
        RAISE EXCEPTION 'Short-text exercise text is outside its approved length.';
      END IF;
      v_normalized_text := private.normalize_short_text(v_text);
      IF v_normalized_text = '' THEN
        RAISE EXCEPTION 'Short-text exercise text cannot normalize to empty.';
      END IF;
      v_normalized_answer := pg_catalog.jsonb_build_object('text', v_text);
      v_is_correct := EXISTS (
        SELECT 1
        FROM pg_catalog.jsonb_array_elements_text(
          v_answer_spec -> 'acceptedAnswers'
        ) AS accepted_answer(value)
        WHERE accepted_answer.value = v_normalized_text
      );

    ELSE
      RAISE EXCEPTION 'Unsupported scalar exercise type.';
  END CASE;

  RETURN pg_catalog.jsonb_build_object(
    'answer',
    v_normalized_answer,
    'isCorrect',
    v_is_correct,
    'pointsEarned',
    CASE WHEN v_is_correct THEN v_points_possible ELSE 0 END,
    'pointsPossible',
    v_points_possible
  );
END;
$grade_scalar_exercise_answer$;

CREATE FUNCTION private.grade_quiz_question_answer(
  p_question_id uuid,
  p_answer jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $grade_quiz_question_answer$
DECLARE
  v_question_type public.question_type;
  v_points_possible integer;
  v_answer_spec jsonb;
  v_option_id uuid;
  v_option_ids uuid[] := ARRAY[]::uuid[];
  v_normalized_option_ids jsonb;
  v_text text;
  v_normalized_text text;
  v_is_correct boolean;
  v_normalized_answer jsonb;
BEGIN
  SELECT question.question_type, question.points, answer_key.answer_spec
  INTO v_question_type, v_points_possible, v_answer_spec
  FROM public.quiz_questions AS question
  JOIN private.quiz_question_answer_keys AS answer_key
    ON answer_key.question_id = question.id
  WHERE question.id = p_question_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz question definition is unavailable.';
  END IF;

  CASE v_question_type
    WHEN 'single_choice'::public.question_type THEN
      PERFORM private.assert_exact_jsonb_object_keys(
        p_answer,
        ARRAY['optionId']::text[],
        'Single-choice quiz answer'
      );
      v_option_id := private.assert_canonical_uuid_text(
        private.assert_jsonb_string(
          p_answer -> 'optionId',
          'Single-choice quiz optionId'
        ),
        'Single-choice quiz optionId'
      );
      IF NOT EXISTS (
        SELECT 1
        FROM public.quiz_question_options AS option_entry
        WHERE option_entry.id = v_option_id
          AND option_entry.question_id = p_question_id
      ) THEN
        RAISE EXCEPTION 'The quiz answer references an option from another question.';
      END IF;
      v_normalized_answer := pg_catalog.jsonb_build_object(
        'optionId',
        v_option_id::text
      );
      v_is_correct := (v_answer_spec ->> 'correctOptionId') = v_option_id::text;

    WHEN 'multiple_choice'::public.question_type THEN
      PERFORM private.assert_exact_jsonb_object_keys(
        p_answer,
        ARRAY['optionIds']::text[],
        'Multiple-choice quiz answer'
      );
      IF pg_catalog.jsonb_typeof(p_answer -> 'optionIds') <> 'array'
        OR pg_catalog.jsonb_array_length(p_answer -> 'optionIds') NOT BETWEEN 1 AND 20 THEN
        RAISE EXCEPTION 'Multiple-choice quiz optionIds must contain one through twenty options.';
      END IF;

      FOR v_text IN
        SELECT private.assert_jsonb_string(
          option_value.value,
          'Multiple-choice quiz option ID'
        )
        FROM pg_catalog.jsonb_array_elements(p_answer -> 'optionIds')
          AS option_value(value)
      LOOP
        v_option_id := private.assert_canonical_uuid_text(
          v_text,
          'Multiple-choice quiz option ID'
        );
        IF v_option_id = ANY (v_option_ids) THEN
          RAISE EXCEPTION 'Multiple-choice quiz option IDs must be unique.';
        END IF;
        IF NOT EXISTS (
          SELECT 1
          FROM public.quiz_question_options AS option_entry
          WHERE option_entry.id = v_option_id
            AND option_entry.question_id = p_question_id
        ) THEN
          RAISE EXCEPTION 'The quiz answer references an option from another question.';
        END IF;
        v_option_ids := pg_catalog.array_append(v_option_ids, v_option_id);
      END LOOP;

      SELECT pg_catalog.jsonb_agg(
        pg_catalog.to_jsonb(option_id::text)
        ORDER BY option_id::text COLLATE "C"
      )
      INTO v_normalized_option_ids
      FROM pg_catalog.unnest(v_option_ids) AS option_id;
      v_normalized_answer := pg_catalog.jsonb_build_object(
        'optionIds',
        v_normalized_option_ids
      );
      v_is_correct := (v_answer_spec -> 'correctOptionIds') = v_normalized_option_ids;

    WHEN 'short_text'::public.question_type THEN
      PERFORM private.assert_exact_jsonb_object_keys(
        p_answer,
        ARRAY['text']::text[],
        'Short-text quiz answer'
      );
      v_text := private.assert_jsonb_string(
        p_answer -> 'text',
        'Short-text quiz text'
      );
      IF pg_catalog.char_length(v_text) NOT BETWEEN 1 AND 4000 THEN
        RAISE EXCEPTION 'Short-text quiz text is outside its approved length.';
      END IF;
      v_normalized_text := private.normalize_short_text(v_text);
      IF v_normalized_text = '' THEN
        RAISE EXCEPTION 'Short-text quiz text cannot normalize to empty.';
      END IF;
      v_normalized_answer := pg_catalog.jsonb_build_object('text', v_text);
      v_is_correct := EXISTS (
        SELECT 1
        FROM pg_catalog.jsonb_array_elements_text(
          v_answer_spec -> 'acceptedAnswers'
        ) AS accepted_answer(value)
        WHERE accepted_answer.value = v_normalized_text
      );

    ELSE
      RAISE EXCEPTION 'Unsupported quiz question type.';
  END CASE;

  RETURN pg_catalog.jsonb_build_object(
    'answer',
    v_normalized_answer,
    'isCorrect',
    v_is_correct,
    'pointsEarned',
    CASE WHEN v_is_correct THEN v_points_possible ELSE 0 END,
    'pointsPossible',
    v_points_possible
  );
END;
$grade_quiz_question_answer$;

CREATE FUNCTION private.recalculate_chapter_progress(
  p_user_id uuid,
  p_chapter_id uuid
)
RETURNS public.chapter_progress
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $recalculate_chapter_progress$
DECLARE
  v_theory_total integer;
  v_theory_complete integer;
  v_exercise_total integer;
  v_exercise_complete integer;
  v_quiz_total integer;
  v_quiz_complete integer;
  v_theory_percent numeric(5,2);
  v_exercise_percent numeric(5,2);
  v_quiz_percent numeric(5,2);
  v_overall_percent numeric(5,2);
  v_has_sources boolean;
  v_is_complete boolean;
  v_result public.chapter_progress%ROWTYPE;
BEGIN
  PERFORM private.lock_chapter_progress(p_user_id, p_chapter_id);

  SELECT
    pg_catalog.count(*)::integer,
    pg_catalog.count(completion_entry.user_id)::integer
  INTO v_theory_total, v_theory_complete
  FROM public.theory_sections AS theory_section
  JOIN public.chapters AS chapter
    ON chapter.id = theory_section.chapter_id
  JOIN public.modules AS module_entry
    ON module_entry.id = chapter.module_id
  LEFT JOIN public.theory_section_completions AS completion_entry
    ON completion_entry.theory_section_id = theory_section.id
    AND completion_entry.user_id = p_user_id
  WHERE theory_section.chapter_id = p_chapter_id
    AND theory_section.status = 'published'::public.content_status
    AND chapter.status = 'published'::public.content_status
    AND module_entry.status = 'published'::public.content_status;

  SELECT
    pg_catalog.count(*)::integer,
    pg_catalog.count(*) FILTER (
      WHERE EXISTS (
        SELECT 1
        FROM public.exercise_attempts AS attempt
        WHERE attempt.user_id = p_user_id
          AND attempt.exercise_id = exercise.id
          AND attempt.is_correct
      )
    )::integer
  INTO v_exercise_total, v_exercise_complete
  FROM public.exercises AS exercise
  JOIN public.chapters AS chapter
    ON chapter.id = exercise.chapter_id
  JOIN public.modules AS module_entry
    ON module_entry.id = chapter.module_id
  WHERE exercise.chapter_id = p_chapter_id
    AND exercise.is_required
    AND exercise.status = 'published'::public.content_status
    AND chapter.status = 'published'::public.content_status
    AND module_entry.status = 'published'::public.content_status;

  SELECT
    pg_catalog.count(*)::integer,
    pg_catalog.count(*) FILTER (
      WHERE EXISTS (
        SELECT 1
        FROM public.quiz_attempts AS attempt
        WHERE attempt.user_id = p_user_id
          AND attempt.quiz_id = quiz.id
          AND attempt.passed
      )
    )::integer
  INTO v_quiz_total, v_quiz_complete
  FROM public.quizzes AS quiz
  JOIN public.chapters AS chapter
    ON chapter.id = quiz.chapter_id
  JOIN public.modules AS module_entry
    ON module_entry.id = chapter.module_id
  WHERE quiz.chapter_id = p_chapter_id
    AND quiz.is_required
    AND quiz.status = 'published'::public.content_status
    AND chapter.status = 'published'::public.content_status
    AND module_entry.status = 'published'::public.content_status;

  v_has_sources := (v_theory_total + v_exercise_total + v_quiz_total) > 0;
  v_theory_percent := CASE
    WHEN v_theory_total = 0 THEN 100
    ELSE pg_catalog.floor(
      (v_theory_complete::numeric * 10000) / v_theory_total
    ) / 100
  END;
  v_exercise_percent := CASE
    WHEN v_exercise_total = 0 THEN 100
    ELSE pg_catalog.floor(
      (v_exercise_complete::numeric * 10000) / v_exercise_total
    ) / 100
  END;
  v_quiz_percent := CASE
    WHEN v_quiz_total = 0 THEN 100
    ELSE pg_catalog.floor(
      (v_quiz_complete::numeric * 10000) / v_quiz_total
    ) / 100
  END;
  v_overall_percent := pg_catalog.floor(
    (v_theory_percent + v_exercise_percent + v_quiz_percent) / 3
  );
  v_is_complete := v_has_sources
    AND v_theory_percent = 100
    AND v_exercise_percent = 100
    AND v_quiz_percent = 100;

  PERFORM 1
  FROM public.chapter_progress AS progress
  WHERE progress.user_id = p_user_id
    AND progress.chapter_id = p_chapter_id
  FOR UPDATE;

  IF NOT v_has_sources AND NOT FOUND THEN
    RETURN NULL;
  END IF;

  PERFORM pg_catalog.set_config(
    'coditza.learning_write',
    'progress:' || p_user_id::text || ':' || p_chapter_id::text,
    true
  );

  INSERT INTO public.chapter_progress (
    user_id,
    chapter_id,
    theory_percent,
    exercise_percent,
    quiz_percent,
    overall_percent,
    first_completed_at,
    completed_at
  )
  VALUES (
    p_user_id,
    p_chapter_id,
    v_theory_percent,
    v_exercise_percent,
    v_quiz_percent,
    v_overall_percent,
    CASE WHEN v_is_complete THEN pg_catalog.clock_timestamp() ELSE NULL END,
    CASE WHEN v_is_complete THEN pg_catalog.clock_timestamp() ELSE NULL END
  )
  ON CONFLICT (user_id, chapter_id) DO UPDATE
  SET theory_percent = EXCLUDED.theory_percent,
      exercise_percent = EXCLUDED.exercise_percent,
      quiz_percent = EXCLUDED.quiz_percent,
      overall_percent = EXCLUDED.overall_percent,
      first_completed_at = COALESCE(
        public.chapter_progress.first_completed_at,
        CASE WHEN v_is_complete THEN pg_catalog.clock_timestamp() ELSE NULL END
      ),
      completed_at = CASE
        WHEN v_is_complete THEN COALESCE(
          public.chapter_progress.completed_at,
          pg_catalog.clock_timestamp()
        )
        ELSE NULL
      END
  RETURNING * INTO v_result;

  PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
  RETURN v_result;
END;
$recalculate_chapter_progress$;

CREATE FUNCTION private.lock_idempotency_key(
  p_user_id uuid,
  p_operation text,
  p_idempotency_key uuid
)
RETURNS void
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $lock_idempotency_key$
  SELECT pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(
      'coditza:idempotency:' || p_user_id::text || ':' || p_operation || ':' ||
      p_idempotency_key::text,
      0
    )
  );
$lock_idempotency_key$;

CREATE FUNCTION private.assert_idempotency_request(
  p_operation text,
  p_canonicalization_version integer,
  p_request_hash bytea
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_idempotency_request$
BEGIN
  IF p_operation NOT IN (
    'exercise_submit',
    'quiz_start',
    'python_grading_reserve',
    'admin_create_module',
    'admin_create_chapter',
    'admin_create_theory_section',
    'admin_create_exercise',
    'admin_create_quiz',
    'admin_clone_exercise',
    'admin_clone_quiz'
  ) THEN
    RAISE EXCEPTION 'The idempotency operation is not approved.';
  END IF;
  IF p_canonicalization_version IS NULL
    OR p_canonicalization_version <= 0
    OR p_request_hash IS NULL
    OR pg_catalog.octet_length(p_request_hash) <> 32 THEN
    RAISE EXCEPTION 'The idempotency request is malformed.';
  END IF;
END;
$assert_idempotency_request$;

CREATE FUNCTION private.assert_safe_idempotency_response(
  p_operation text,
  p_result_resource_id uuid,
  p_response_body jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_safe_idempotency_response$
DECLARE
  v_key text;
BEGIN
  IF pg_catalog.jsonb_typeof(p_response_body) <> 'object' THEN
    RAISE EXCEPTION 'The idempotency response must be an object.';
  END IF;

  FOR v_key IN
    SELECT object_key.key
    FROM pg_catalog.jsonb_object_keys(p_response_body) AS object_key(key)
  LOOP
    IF v_key OPERATOR(pg_catalog.~*)
      '(answer|accepted|correctoption|key|token|password|secret|totp|otp|qr|otpauth|markdown|source|test|body)' THEN
      RAISE EXCEPTION 'The idempotency response contains a prohibited field.';
    END IF;
  END LOOP;

  CASE p_operation
    WHEN 'exercise_submit' THEN
      PERFORM private.assert_exact_jsonb_object_keys(
        p_response_body,
        ARRAY[
          'id',
          'exerciseId',
          'exerciseDefinitionVersion',
          'submittedAt',
          'isCorrect',
          'pointsEarned',
          'pointsPossible'
        ]::text[],
        'Exercise idempotency response'
      );
    WHEN 'quiz_start' THEN
      PERFORM private.assert_exact_jsonb_object_keys(
        p_response_body,
        ARRAY[
          'id',
          'quizId',
          'quizDefinitionVersion',
          'attemptNumber',
          'startedAt',
          'expiresAt'
        ]::text[],
        'Quiz-start idempotency response'
      );
    ELSE
      PERFORM private.assert_exact_jsonb_object_keys(
        p_response_body,
        ARRAY['id']::text[],
        'Future workflow idempotency response'
      );
  END CASE;

  IF private.assert_canonical_uuid_text(
    private.assert_jsonb_string(
      p_response_body -> 'id',
      'Idempotency response id'
    ),
    'Idempotency response id'
  ) IS DISTINCT FROM p_result_resource_id THEN
    RAISE EXCEPTION 'The idempotency response ID does not match its result resource.';
  END IF;
END;
$assert_safe_idempotency_response$;

CREATE FUNCTION private.begin_idempotency(
  p_user_id uuid,
  p_operation text,
  p_idempotency_key uuid,
  p_canonicalization_version integer,
  p_request_hash bytea
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $begin_idempotency$
DECLARE
  v_record private.idempotency_records%ROWTYPE;
BEGIN
  PERFORM private.assert_idempotency_request(
    p_operation,
    p_canonicalization_version,
    p_request_hash
  );
  PERFORM private.lock_idempotency_key(
    p_user_id,
    p_operation,
    p_idempotency_key
  );

  SELECT *
  INTO v_record
  FROM private.idempotency_records AS record_entry
  WHERE record_entry.user_id = p_user_id
    AND record_entry.operation = p_operation
    AND record_entry.idempotency_key = p_idempotency_key
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF pg_catalog.now() >= v_record.expires_at THEN
    PERFORM pg_catalog.set_config('coditza.learning_write', 'idempotency', true);
    DELETE FROM private.idempotency_records AS record_entry
    WHERE record_entry.user_id = p_user_id
      AND record_entry.operation = p_operation
      AND record_entry.idempotency_key = p_idempotency_key;
    PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
    RETURN NULL;
  END IF;

  IF v_record.canonicalization_version <> p_canonicalization_version
    OR v_record.request_hash IS DISTINCT FROM p_request_hash THEN
    RAISE EXCEPTION 'The idempotency key is already bound to a different request.';
  END IF;

  RETURN v_record.response_body;
END;
$begin_idempotency$;

CREATE FUNCTION private.complete_idempotency(
  p_user_id uuid,
  p_operation text,
  p_idempotency_key uuid,
  p_canonicalization_version integer,
  p_request_hash bytea,
  p_result_resource_id uuid,
  p_response_status integer,
  p_response_location text,
  p_response_body jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $complete_idempotency$
BEGIN
  PERFORM private.assert_idempotency_request(
    p_operation,
    p_canonicalization_version,
    p_request_hash
  );
  PERFORM private.assert_safe_idempotency_response(
    p_operation,
    p_result_resource_id,
    p_response_body
  );
  PERFORM private.lock_idempotency_key(
    p_user_id,
    p_operation,
    p_idempotency_key
  );
  PERFORM pg_catalog.set_config('coditza.learning_write', 'idempotency', true);

  INSERT INTO private.idempotency_records (
    user_id,
    operation,
    idempotency_key,
    canonicalization_version,
    request_hash,
    result_resource_id,
    response_status,
    response_location,
    response_body
  )
  VALUES (
    p_user_id,
    p_operation,
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash,
    p_result_resource_id,
    p_response_status,
    p_response_location,
    p_response_body
  );

  PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
END;
$complete_idempotency$;

CREATE FUNCTION private.purge_expired_idempotency(p_limit integer)
RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $purge_expired_idempotency$
DECLARE
  v_candidate record;
  v_deleted integer := 0;
BEGIN
  IF p_limit NOT BETWEEN 1 AND 1000 THEN
    RAISE EXCEPTION 'The idempotency purge limit is outside its approved range.';
  END IF;

  FOR v_candidate IN
    SELECT record_entry.user_id, record_entry.operation, record_entry.idempotency_key
    FROM private.idempotency_records AS record_entry
    WHERE record_entry.expires_at <= pg_catalog.now()
    ORDER BY record_entry.expires_at, record_entry.idempotency_key
    LIMIT p_limit
  LOOP
    PERFORM private.lock_idempotency_key(
      v_candidate.user_id,
      v_candidate.operation,
      v_candidate.idempotency_key
    );
    PERFORM pg_catalog.set_config('coditza.learning_write', 'idempotency', true);
    DELETE FROM private.idempotency_records AS record_entry
    WHERE record_entry.user_id = v_candidate.user_id
      AND record_entry.operation = v_candidate.operation
      AND record_entry.idempotency_key = v_candidate.idempotency_key
      AND record_entry.expires_at <= pg_catalog.now();
    v_deleted := v_deleted + CASE WHEN FOUND THEN 1 ELSE 0 END;
    PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
  END LOOP;

  RETURN v_deleted;
END;
$purge_expired_idempotency$;

CREATE FUNCTION private.assert_safe_audit_fields(
  p_changed_fields text[],
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_safe_audit_fields$
DECLARE
  v_field text;
BEGIN
  IF p_changed_fields IS NULL OR pg_catalog.cardinality(p_changed_fields) > 32 THEN
    RAISE EXCEPTION 'Audit changed fields are outside the approved bounds.';
  END IF;

  FOREACH v_field IN ARRAY p_changed_fields LOOP
    IF v_field IS NULL
      OR NOT (v_field OPERATOR(pg_catalog.~) '^[a-z][a-z0-9_]{0,63}$')
      OR v_field OPERATOR(pg_catalog.~*)
        '(answer|accepted|correctoption|key|token|password|secret|totp|otp|qr|otpauth|markdown|body|source|test|email)' THEN
      RAISE EXCEPTION 'Audit changed fields may not contain sensitive or content-bearing names.';
    END IF;
  END LOOP;

  IF p_reason IS NOT NULL
    AND (
      pg_catalog.char_length(p_reason) NOT BETWEEN 1 AND 1000
      OR NOT (p_reason OPERATOR(pg_catalog.~) '[^[:space:]]')
      OR p_reason OPERATOR(pg_catalog.~*)
        '(token|password|secret|totp|otpauth|refresh|answer|key|markdown)'
    ) THEN
    RAISE EXCEPTION 'Audit reasons must be short, non-secret, and non-content-bearing.';
  END IF;
END;
$assert_safe_audit_fields$;

CREATE FUNCTION private.append_audit_event(
  p_actor_kind text,
  p_actor_user_id uuid,
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_changed_fields text[],
  p_reason text,
  p_request_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $append_audit_event$
DECLARE
  v_id uuid;
BEGIN
  IF p_actor_kind NOT IN ('user', 'system') THEN
    RAISE EXCEPTION 'Audit actor kind is invalid.';
  END IF;
  IF (p_actor_kind = 'user' AND p_actor_user_id IS NULL)
    OR (p_actor_kind = 'system' AND p_actor_user_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Audit actor kind and actor user are inconsistent.';
  END IF;
  PERFORM private.assert_safe_audit_fields(p_changed_fields, p_reason);
  PERFORM pg_catalog.set_config('coditza.learning_write', 'audit', true);

  INSERT INTO private.audit_events (
    actor_kind,
    actor_user_id,
    action,
    entity_type,
    entity_id,
    changed_fields,
    reason,
    request_id
  )
  VALUES (
    p_actor_kind,
    p_actor_user_id,
    p_action,
    p_entity_type,
    p_entity_id,
    p_changed_fields,
    p_reason,
    p_request_id
  )
  RETURNING id INTO v_id;

  PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
  RETURN v_id;
END;
$append_audit_event$;

CREATE FUNCTION private.set_theory_completion(
  p_user_id uuid,
  p_theory_section_id uuid,
  p_completed boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $set_theory_completion$
DECLARE
  v_chapter_id uuid;
  v_first_completed_at timestamptz;
  v_changed boolean := false;
BEGIN
  PERFORM private.assert_active_learning_actor(p_user_id);

  IF p_completed THEN
    v_chapter_id := private.assert_effectively_published_theory_section(
      p_theory_section_id
    );
    PERFORM private.lock_chapter_progress(p_user_id, v_chapter_id);
    PERFORM pg_catalog.set_config(
      'coditza.learning_write',
      'theory:' || p_user_id::text || ':' || p_theory_section_id::text,
      true
    );
    INSERT INTO public.theory_section_completions (user_id, theory_section_id)
    VALUES (p_user_id, p_theory_section_id)
    ON CONFLICT (user_id, theory_section_id) DO NOTHING;
    v_changed := FOUND;
    PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
  ELSE
    SELECT theory_section.chapter_id
    INTO v_chapter_id
    FROM public.theory_sections AS theory_section
    WHERE theory_section.id = p_theory_section_id
    FOR UPDATE;
    IF NOT FOUND THEN
      RAISE EXCEPTION 'The theory section does not exist.';
    END IF;
    PERFORM private.lock_chapter_progress(p_user_id, v_chapter_id);
    SELECT progress.first_completed_at
    INTO v_first_completed_at
    FROM public.chapter_progress AS progress
    WHERE progress.user_id = p_user_id
      AND progress.chapter_id = v_chapter_id
    FOR UPDATE;
    IF v_first_completed_at IS NOT NULL THEN
      RAISE EXCEPTION 'Theory completion cannot be removed after the chapter has completed.';
    END IF;
    PERFORM pg_catalog.set_config(
      'coditza.learning_write',
      'theory:' || p_user_id::text || ':' || p_theory_section_id::text,
      true
    );
    DELETE FROM public.theory_section_completions AS completion_entry
    WHERE completion_entry.user_id = p_user_id
      AND completion_entry.theory_section_id = p_theory_section_id;
    v_changed := FOUND;
    PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
  END IF;

  PERFORM private.recalculate_chapter_progress(p_user_id, v_chapter_id);
  RETURN v_changed;
END;
$set_theory_completion$;

CREATE FUNCTION private.submit_scalar_exercise_attempt(
  p_user_id uuid,
  p_exercise_id uuid,
  p_answer jsonb,
  p_idempotency_key uuid,
  p_canonicalization_version integer,
  p_request_hash bytea
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $submit_scalar_exercise_attempt$
DECLARE
  v_replay jsonb;
  v_chapter_id uuid;
  v_grade jsonb;
  v_attempt_id uuid;
  v_definition_version integer;
  v_submitted_at timestamptz;
  v_result jsonb;
BEGIN
  v_replay := private.begin_idempotency(
    p_user_id,
    'exercise_submit',
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash
  );
  IF v_replay IS NOT NULL THEN
    RETURN v_replay;
  END IF;
  PERFORM private.assert_active_learning_actor(p_user_id);

  v_chapter_id := private.assert_effectively_published_exercise(p_exercise_id);
  PERFORM private.lock_chapter_progress(p_user_id, v_chapter_id);
  v_grade := private.grade_scalar_exercise_answer(p_exercise_id, p_answer);

  SELECT exercise.definition_version
  INTO v_definition_version
  FROM public.exercises AS exercise
  WHERE exercise.id = p_exercise_id
  FOR UPDATE;

  PERFORM pg_catalog.set_config('coditza.learning_write', 'exercise', true);
  INSERT INTO public.exercise_attempts (
    user_id,
    exercise_id,
    exercise_definition_version,
    answer,
    is_correct,
    points_earned,
    points_possible
  )
  VALUES (
    p_user_id,
    p_exercise_id,
    v_definition_version,
    v_grade -> 'answer',
    (v_grade ->> 'isCorrect')::boolean,
    (v_grade ->> 'pointsEarned')::integer,
    (v_grade ->> 'pointsPossible')::integer
  )
  RETURNING id, submitted_at INTO v_attempt_id, v_submitted_at;
  PERFORM pg_catalog.set_config('coditza.learning_write', '', true);

  PERFORM private.recalculate_chapter_progress(p_user_id, v_chapter_id);

  v_result := pg_catalog.jsonb_build_object(
    'id',
    v_attempt_id::text,
    'exerciseId',
    p_exercise_id::text,
    'exerciseDefinitionVersion',
    v_definition_version,
    'submittedAt',
    v_submitted_at::text,
    'isCorrect',
    (v_grade -> 'isCorrect'),
    'pointsEarned',
    (v_grade -> 'pointsEarned'),
    'pointsPossible',
    (v_grade -> 'pointsPossible')
  );
  PERFORM private.complete_idempotency(
    p_user_id,
    'exercise_submit',
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash,
    v_attempt_id,
    201,
    '/api/v1/me/exercise-attempts/' || v_attempt_id::text,
    v_result
  );
  RETURN v_result;
END;
$submit_scalar_exercise_attempt$;

CREATE FUNCTION private.finalize_quiz_attempt(
  p_attempt_id uuid,
  p_forced_expiry boolean DEFAULT false,
  p_expected_user_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $finalize_quiz_attempt$
DECLARE
  v_attempt public.quiz_attempts%ROWTYPE;
  v_quiz public.quizzes%ROWTYPE;
  v_chapter_id uuid;
  v_question record;
  v_grade jsonb;
  v_points_earned integer := 0;
  v_points_possible integer := 0;
  v_score_percent numeric(5,2);
  v_passed boolean;
  v_terminal_status public.quiz_attempt_status;
  v_result jsonb;
BEGIN
  SELECT *
  INTO v_attempt
  FROM public.quiz_attempts AS attempt
  WHERE attempt.id = p_attempt_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz attempt does not exist.';
  END IF;
  IF p_expected_user_id IS NOT NULL
    AND v_attempt.user_id IS DISTINCT FROM p_expected_user_id THEN
    RAISE EXCEPTION 'The quiz attempt is absent or belongs to another learner.';
  END IF;

  SELECT quiz.*
  INTO v_quiz
  FROM public.quizzes AS quiz
  WHERE quiz.id = v_attempt.quiz_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz definition no longer exists.';
  END IF;

  IF v_attempt.status <> 'in_progress'::public.quiz_attempt_status THEN
    RETURN pg_catalog.jsonb_build_object(
      'id',
      v_attempt.id::text,
      'quizId',
      v_attempt.quiz_id::text,
      'quizDefinitionVersion',
      v_attempt.quiz_definition_version,
      'status',
      v_attempt.status::text,
      'submittedAt',
      v_attempt.submitted_at::text,
      'pointsEarned',
      v_attempt.points_earned,
      'pointsPossible',
      v_attempt.points_possible,
      'scorePercent',
      v_attempt.score_percent,
      'passed',
      v_attempt.passed
    );
  END IF;

  IF p_forced_expiry
    OR (
      v_attempt.expires_at IS NOT NULL
      AND pg_catalog.now() >= v_attempt.expires_at
    ) THEN
    IF v_attempt.expires_at IS NULL THEN
      RAISE EXCEPTION 'Untimed quiz attempts cannot expire.';
    END IF;
    v_terminal_status := 'expired'::public.quiz_attempt_status;
  ELSE
    v_terminal_status := 'submitted'::public.quiz_attempt_status;
  END IF;

  v_chapter_id := v_quiz.chapter_id;

  FOR v_question IN
    SELECT question.id, question.points
    FROM public.quiz_questions AS question
    WHERE question.quiz_id = v_attempt.quiz_id
    ORDER BY question.position, question.id
  LOOP
    v_points_possible := v_points_possible + v_question.points;
    SELECT answer_entry.answer
    INTO v_grade
    FROM public.quiz_attempt_answers AS answer_entry
    WHERE answer_entry.attempt_id = v_attempt.id
      AND answer_entry.question_id = v_question.id
    FOR UPDATE;

    IF FOUND THEN
      v_grade := private.grade_quiz_question_answer(v_question.id, v_grade);
      PERFORM pg_catalog.set_config(
        'coditza.learning_write',
        'quiz-finalize:' || v_attempt.id::text,
        true
      );
      UPDATE public.quiz_attempt_answers AS answer_entry
      SET is_correct = (v_grade ->> 'isCorrect')::boolean,
          points_earned = (v_grade ->> 'pointsEarned')::integer
      WHERE answer_entry.attempt_id = v_attempt.id
        AND answer_entry.question_id = v_question.id;
      PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
      v_points_earned := v_points_earned + (v_grade ->> 'pointsEarned')::integer;
    END IF;
  END LOOP;

  IF v_points_possible <= 0 THEN
    RAISE EXCEPTION 'A quiz attempt cannot finalize without a frozen question set.';
  END IF;
  v_score_percent := pg_catalog.floor(
    (v_points_earned::numeric * 10000) / v_points_possible
  ) / 100;
  v_passed := v_score_percent >= v_quiz.passing_percent;

  PERFORM pg_catalog.set_config(
    'coditza.learning_write',
    'quiz-finalize:' || v_attempt.id::text,
    true
  );
  UPDATE public.quiz_attempts AS attempt
  SET status = v_terminal_status,
      submitted_at = pg_catalog.clock_timestamp(),
      points_earned = v_points_earned,
      points_possible = v_points_possible,
      score_percent = v_score_percent,
      passed = v_passed
  WHERE attempt.id = v_attempt.id
  RETURNING * INTO v_attempt;
  PERFORM pg_catalog.set_config('coditza.learning_write', '', true);

  PERFORM private.recalculate_chapter_progress(v_attempt.user_id, v_chapter_id);
  v_result := pg_catalog.jsonb_build_object(
    'id',
    v_attempt.id::text,
    'quizId',
    v_attempt.quiz_id::text,
    'quizDefinitionVersion',
    v_attempt.quiz_definition_version,
    'status',
    v_attempt.status::text,
    'submittedAt',
    v_attempt.submitted_at::text,
    'pointsEarned',
    v_attempt.points_earned,
    'pointsPossible',
    v_attempt.points_possible,
    'scorePercent',
    v_attempt.score_percent,
    'passed',
    v_attempt.passed
  );
  RETURN v_result;
END;
$finalize_quiz_attempt$;

CREATE FUNCTION private.start_quiz_attempt(
  p_user_id uuid,
  p_quiz_id uuid,
  p_idempotency_key uuid,
  p_canonicalization_version integer,
  p_request_hash bytea
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $start_quiz_attempt$
DECLARE
  v_replay jsonb;
  v_quiz public.quizzes%ROWTYPE;
  v_active_attempt_id uuid;
  v_attempt_count integer;
  v_attempt_id uuid;
  v_started_at timestamptz;
  v_expires_at timestamptz;
  v_attempt_number integer;
  v_result jsonb;
BEGIN
  v_replay := private.begin_idempotency(
    p_user_id,
    'quiz_start',
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash
  );
  IF v_replay IS NOT NULL THEN
    RETURN v_replay;
  END IF;
  PERFORM private.assert_active_learning_actor(p_user_id);

  PERFORM private.assert_effectively_published_quiz(p_quiz_id);
  SELECT *
  INTO v_quiz
  FROM public.quizzes AS quiz
  WHERE quiz.id = p_quiz_id
  FOR UPDATE;

  SELECT attempt.id
  INTO v_active_attempt_id
  FROM public.quiz_attempts AS attempt
  WHERE attempt.user_id = p_user_id
    AND attempt.quiz_id = p_quiz_id
    AND attempt.status = 'in_progress'::public.quiz_attempt_status
  FOR UPDATE;

  IF FOUND THEN
    IF (
      SELECT attempt.expires_at IS NOT NULL
        AND pg_catalog.now() >= attempt.expires_at
      FROM public.quiz_attempts AS attempt
      WHERE attempt.id = v_active_attempt_id
    ) THEN
      PERFORM private.finalize_quiz_attempt(v_active_attempt_id, true, p_user_id);
    ELSE
      RAISE EXCEPTION 'The learner already has an active quiz attempt.';
    END IF;
  END IF;

  SELECT pg_catalog.count(*)::integer
  INTO v_attempt_count
  FROM public.quiz_attempts AS attempt
  WHERE attempt.user_id = p_user_id
    AND attempt.quiz_id = p_quiz_id;

  IF v_quiz.max_attempts IS NOT NULL
    AND v_attempt_count >= v_quiz.max_attempts THEN
    RETURN pg_catalog.jsonb_build_object('outcome', 'attempt_limit_reached');
  END IF;

  v_attempt_number := v_attempt_count + 1;
  v_expires_at := CASE
    WHEN v_quiz.time_limit_seconds IS NULL THEN NULL
    ELSE pg_catalog.clock_timestamp()
      + pg_catalog.make_interval(secs => v_quiz.time_limit_seconds)
  END;

  PERFORM pg_catalog.set_config('coditza.learning_write', 'quiz-start', true);
  INSERT INTO public.quiz_attempts (
    user_id,
    quiz_id,
    quiz_definition_version,
    attempt_number,
    expires_at
  )
  VALUES (
    p_user_id,
    p_quiz_id,
    v_quiz.definition_version,
    v_attempt_number,
    v_expires_at
  )
  RETURNING id, started_at, expires_at
  INTO v_attempt_id, v_started_at, v_expires_at;
  PERFORM pg_catalog.set_config('coditza.learning_write', '', true);

  v_result := pg_catalog.jsonb_build_object(
    'id',
    v_attempt_id::text,
    'quizId',
    p_quiz_id::text,
    'quizDefinitionVersion',
    v_quiz.definition_version,
    'attemptNumber',
    v_attempt_number,
    'startedAt',
    v_started_at::text,
    'expiresAt',
    CASE
      WHEN v_expires_at IS NULL THEN NULL
      ELSE pg_catalog.to_jsonb(v_expires_at::text)
    END
  );
  PERFORM private.complete_idempotency(
    p_user_id,
    'quiz_start',
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash,
    v_attempt_id,
    201,
    '/api/v1/me/quiz-attempts/' || v_attempt_id::text,
    v_result
  );
  RETURN v_result;
END;
$start_quiz_attempt$;

CREATE FUNCTION private.assert_mutable_quiz_attempt(
  p_user_id uuid,
  p_attempt_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_mutable_quiz_attempt$
DECLARE
  v_quiz_id uuid;
  v_expires_at timestamptz;
  v_status public.quiz_attempt_status;
BEGIN
  SELECT attempt.quiz_id, attempt.expires_at, attempt.status
  INTO v_quiz_id, v_expires_at, v_status
  FROM public.quiz_attempts AS attempt
  WHERE attempt.id = p_attempt_id
    AND attempt.user_id = p_user_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz attempt is absent or belongs to another learner.';
  END IF;
  IF v_status <> 'in_progress'::public.quiz_attempt_status THEN
    RAISE EXCEPTION 'Only active quiz attempts may change answers.';
  END IF;
  IF v_expires_at IS NOT NULL AND pg_catalog.now() >= v_expires_at THEN
    RAISE EXCEPTION 'The quiz attempt has expired.';
  END IF;
  RETURN v_quiz_id;
END;
$assert_mutable_quiz_attempt$;

CREATE FUNCTION private.save_quiz_answer(
  p_user_id uuid,
  p_attempt_id uuid,
  p_question_id uuid,
  p_answer jsonb
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $save_quiz_answer$
DECLARE
  v_quiz_id uuid;
  v_grade jsonb;
  v_existing_answer jsonb;
BEGIN
  PERFORM private.assert_active_learning_actor(p_user_id);
  v_quiz_id := private.assert_mutable_quiz_attempt(p_user_id, p_attempt_id);
  IF NOT EXISTS (
    SELECT 1
    FROM public.quiz_questions AS question
    WHERE question.id = p_question_id
      AND question.quiz_id = v_quiz_id
  ) THEN
    RAISE EXCEPTION 'The answer question does not belong to the quiz attempt.';
  END IF;

  v_grade := private.grade_quiz_question_answer(p_question_id, p_answer);
  v_existing_answer := v_grade -> 'answer';
  PERFORM pg_catalog.set_config(
    'coditza.learning_write',
    'quiz-answer:' || p_attempt_id::text,
    true
  );
  INSERT INTO public.quiz_attempt_answers (
    attempt_id,
    question_id,
    answer
  )
  VALUES (
    p_attempt_id,
    p_question_id,
    v_existing_answer
  )
  ON CONFLICT (attempt_id, question_id) DO UPDATE
  SET answer = EXCLUDED.answer,
      answered_at = CASE
        WHEN public.quiz_attempt_answers.answer = EXCLUDED.answer
          THEN public.quiz_attempt_answers.answered_at
        ELSE pg_catalog.clock_timestamp()
      END
  WHERE public.quiz_attempt_answers.is_correct IS NULL
    AND public.quiz_attempt_answers.points_earned IS NULL;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz answer is already finalized.';
  END IF;
  PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
  RETURN true;
END;
$save_quiz_answer$;

CREATE FUNCTION private.remove_quiz_answer(
  p_user_id uuid,
  p_attempt_id uuid,
  p_question_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $remove_quiz_answer$
DECLARE
  v_quiz_id uuid;
BEGIN
  PERFORM private.assert_active_learning_actor(p_user_id);
  v_quiz_id := private.assert_mutable_quiz_attempt(p_user_id, p_attempt_id);
  IF NOT EXISTS (
    SELECT 1
    FROM public.quiz_questions AS question
    WHERE question.id = p_question_id
      AND question.quiz_id = v_quiz_id
  ) THEN
    RAISE EXCEPTION 'The answer question does not belong to the quiz attempt.';
  END IF;
  PERFORM pg_catalog.set_config(
    'coditza.learning_write',
    'quiz-answer:' || p_attempt_id::text,
    true
  );
  DELETE FROM public.quiz_attempt_answers AS answer_entry
  WHERE answer_entry.attempt_id = p_attempt_id
    AND answer_entry.question_id = p_question_id;
  PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
  RETURN FOUND;
END;
$remove_quiz_answer$;

CREATE FUNCTION private.submit_quiz_attempt(
  p_user_id uuid,
  p_attempt_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $submit_quiz_attempt$
BEGIN
  PERFORM private.assert_active_learning_actor(p_user_id);
  RETURN private.finalize_quiz_attempt(p_attempt_id, false, p_user_id);
END;
$submit_quiz_attempt$;

CREATE FUNCTION private.enforce_theory_completion_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_theory_completion_write$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM private.assert_learning_write_marker(
      'theory:' || NEW.user_id::text || ':' || NEW.theory_section_id::text
    );
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' THEN
    IF pg_catalog.current_setting('coditza.learning_write', true)
      = 'theory:' || OLD.user_id::text || ':' || OLD.theory_section_id::text
      OR pg_catalog.pg_trigger_depth() > 1 THEN
      RETURN OLD;
    END IF;
  END IF;
  RAISE EXCEPTION 'Theory completion rows are workflow-controlled and immutable.';
END;
$enforce_theory_completion_write$;

CREATE FUNCTION private.enforce_exercise_attempt_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_exercise_attempt_write$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM private.assert_learning_write_marker('exercise');
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' AND pg_catalog.pg_trigger_depth() > 1 THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'Exercise attempts are immutable after insertion.';
END;
$enforce_exercise_attempt_write$;

CREATE FUNCTION private.enforce_quiz_attempt_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_quiz_attempt_write$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM private.assert_learning_write_marker('quiz-start');
    RETURN NEW;
  END IF;
  IF TG_OP = 'UPDATE' THEN
    PERFORM private.assert_learning_write_marker(
      'quiz-finalize:' || OLD.id::text
    );
    IF OLD.status <> 'in_progress'::public.quiz_attempt_status
      OR NEW.status NOT IN (
        'submitted'::public.quiz_attempt_status,
        'expired'::public.quiz_attempt_status
      )
      OR NEW.user_id IS DISTINCT FROM OLD.user_id
      OR NEW.quiz_id IS DISTINCT FROM OLD.quiz_id
      OR NEW.quiz_definition_version IS DISTINCT FROM OLD.quiz_definition_version
      OR NEW.attempt_number IS DISTINCT FROM OLD.attempt_number
      OR NEW.started_at IS DISTINCT FROM OLD.started_at
      OR NEW.expires_at IS DISTINCT FROM OLD.expires_at THEN
      RAISE EXCEPTION 'Quiz attempts may finalize only once without changing frozen state.';
    END IF;
    IF NEW.status = 'expired'::public.quiz_attempt_status
      AND OLD.expires_at IS NULL THEN
      RAISE EXCEPTION 'Untimed quiz attempts cannot expire.';
    END IF;
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE' AND pg_catalog.pg_trigger_depth() > 1 THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'Quiz attempts are workflow-controlled.';
END;
$enforce_quiz_attempt_write$;

CREATE FUNCTION private.enforce_quiz_attempt_answer_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_quiz_attempt_answer_write$
DECLARE
  v_attempt_id uuid;
  v_marker text;
BEGIN
  v_attempt_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.attempt_id ELSE NEW.attempt_id END;
  v_marker := pg_catalog.current_setting('coditza.learning_write', true);

  IF TG_OP = 'INSERT' THEN
    IF v_marker = 'quiz-answer:' || v_attempt_id::text
      AND NEW.is_correct IS NULL
      AND NEW.points_earned IS NULL THEN
      RETURN NEW;
    END IF;
  ELSIF TG_OP = 'UPDATE' THEN
    IF v_marker = 'quiz-answer:' || OLD.attempt_id::text
      AND NEW.attempt_id = OLD.attempt_id
      AND NEW.question_id = OLD.question_id
      AND NEW.is_correct IS NULL
      AND NEW.points_earned IS NULL THEN
      RETURN NEW;
    END IF;
    IF v_marker = 'quiz-finalize:' || OLD.attempt_id::text
      AND NEW.attempt_id = OLD.attempt_id
      AND NEW.question_id = OLD.question_id
      AND NEW.answer = OLD.answer
      AND NEW.answered_at = OLD.answered_at
      AND OLD.is_correct IS NULL
      AND OLD.points_earned IS NULL
      AND NEW.is_correct IS NOT NULL
      AND NEW.points_earned IS NOT NULL THEN
      RETURN NEW;
    END IF;
  ELSIF TG_OP = 'DELETE' THEN
    IF v_marker = 'quiz-answer:' || v_attempt_id::text
      OR pg_catalog.pg_trigger_depth() > 1 THEN
      RETURN OLD;
    END IF;
  END IF;

  RAISE EXCEPTION 'Quiz answers may change only through their active-attempt workflow.';
END;
$enforce_quiz_attempt_answer_write$;

CREATE FUNCTION private.enforce_chapter_progress_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_chapter_progress_write$
DECLARE
  v_marker text;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF pg_catalog.pg_trigger_depth() > 1 THEN
      RETURN OLD;
    END IF;
    RAISE EXCEPTION 'Chapter progress may be removed only by account deletion.';
  END IF;

  v_marker := 'progress:' ||
    NEW.user_id::text || ':' || NEW.chapter_id::text;
  PERFORM private.assert_learning_write_marker(v_marker);

  IF TG_OP = 'UPDATE'
    AND OLD.first_completed_at IS NOT NULL
    AND NEW.first_completed_at IS DISTINCT FROM OLD.first_completed_at THEN
    RAISE EXCEPTION 'The first chapter completion timestamp is immutable.';
  END IF;
  RETURN NEW;
END;
$enforce_chapter_progress_write$;

CREATE FUNCTION private.enforce_idempotency_record_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_idempotency_record_write$
BEGIN
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    PERFORM private.assert_learning_write_marker('idempotency');
    NEW.expires_at := NEW.created_at + pg_catalog.interval '24 hours';
    PERFORM private.assert_safe_idempotency_response(
      NEW.operation,
      NEW.result_resource_id,
      NEW.response_body
    );
    RETURN NEW;
  END IF;
  IF TG_OP = 'DELETE'
    AND (
      pg_catalog.current_setting('coditza.learning_write', true) = 'idempotency'
      OR pg_catalog.pg_trigger_depth() > 1
    ) THEN
    RETURN OLD;
  END IF;
  RAISE EXCEPTION 'Idempotency records may change only through their private operation primitive.';
END;
$enforce_idempotency_record_write$;

CREATE FUNCTION private.enforce_audit_event_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_audit_event_write$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM private.assert_learning_write_marker('audit');
    IF NEW.actor_kind = 'user' AND NEW.actor_user_id IS NULL THEN
      RAISE EXCEPTION 'User audit events require an actor at insertion.';
    END IF;
    IF NEW.actor_kind = 'system' AND NEW.actor_user_id IS NOT NULL THEN
      RAISE EXCEPTION 'System audit events cannot name a user actor.';
    END IF;
    PERFORM private.assert_safe_audit_fields(NEW.changed_fields, NEW.reason);
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
    AND OLD.actor_kind = 'user'
    AND OLD.actor_user_id IS NOT NULL
    AND NEW.actor_user_id IS NULL
    AND NEW.actor_kind = OLD.actor_kind
    AND NEW.action = OLD.action
    AND NEW.entity_type = OLD.entity_type
    AND NEW.entity_id = OLD.entity_id
    AND NEW.changed_fields = OLD.changed_fields
    AND NEW.reason IS NOT DISTINCT FROM OLD.reason
    AND NEW.request_id = OLD.request_id
    AND NEW.created_at = OLD.created_at THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Audit events are append-only except for approved account-deletion anonymization.';
END;
$enforce_audit_event_write$;

CREATE TRIGGER theory_section_completions_enforce_workflow_write
BEFORE INSERT OR UPDATE OR DELETE ON public.theory_section_completions
FOR EACH ROW
EXECUTE FUNCTION private.enforce_theory_completion_write();

CREATE TRIGGER exercise_attempts_enforce_workflow_write
BEFORE INSERT OR UPDATE OR DELETE ON public.exercise_attempts
FOR EACH ROW
EXECUTE FUNCTION private.enforce_exercise_attempt_write();

CREATE TRIGGER quiz_attempts_enforce_workflow_write
BEFORE INSERT OR UPDATE OR DELETE ON public.quiz_attempts
FOR EACH ROW
EXECUTE FUNCTION private.enforce_quiz_attempt_write();

CREATE TRIGGER quiz_attempts_set_updated_at
BEFORE UPDATE ON public.quiz_attempts
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER quiz_attempt_answers_enforce_workflow_write
BEFORE INSERT OR UPDATE OR DELETE ON public.quiz_attempt_answers
FOR EACH ROW
EXECUTE FUNCTION private.enforce_quiz_attempt_answer_write();

CREATE TRIGGER chapter_progress_enforce_workflow_write
BEFORE INSERT OR UPDATE OR DELETE ON public.chapter_progress
FOR EACH ROW
EXECUTE FUNCTION private.enforce_chapter_progress_write();

CREATE TRIGGER chapter_progress_set_updated_at
BEFORE UPDATE ON public.chapter_progress
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER idempotency_records_enforce_workflow_write
BEFORE INSERT OR UPDATE OR DELETE ON private.idempotency_records
FOR EACH ROW
EXECUTE FUNCTION private.enforce_idempotency_record_write();

CREATE TRIGGER audit_events_enforce_append_only
BEFORE INSERT OR UPDATE OR DELETE ON private.audit_events
FOR EACH ROW
EXECUTE FUNCTION private.enforce_audit_event_write();

REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA private
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON TABLE public.theory_section_completions,
  public.exercise_attempts,
  public.quiz_attempts,
  public.quiz_attempt_answers,
  public.chapter_progress,
  private.idempotency_records,
  private.audit_events
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

RESET ROLE;

COMMIT;
