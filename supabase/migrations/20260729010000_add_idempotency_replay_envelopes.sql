-- SUP-FUNCTIONS-001 (shared foundation): retain the complete, explicitly
-- safe HTTP replay envelope inside private idempotency records. This is a
-- forward-only replacement for the body-only helper installed by
-- SUP-DATA-003; no runtime role receives private helper access.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION private.assert_safe_idempotency_feedback_markdown(
  p_value jsonb,
  p_context text
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_safe_idempotency_feedback_markdown$
DECLARE
  v_markdown text;
BEGIN
  IF pg_catalog.jsonb_typeof(p_value) = 'null' THEN
    RETURN;
  END IF;

  v_markdown := private.assert_jsonb_string(p_value, p_context);
  PERFORM private.assert_markdown_input(v_markdown, 20000, p_context);
END;
$assert_safe_idempotency_feedback_markdown$;

CREATE FUNCTION private.assert_safe_quiz_start_idempotency_response(
  p_response_body jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_safe_quiz_start_idempotency_response$
DECLARE
  v_question jsonb;
  v_option jsonb;
  v_timestamp text;
BEGIN
  PERFORM private.assert_exact_jsonb_object_keys(
    p_response_body,
    ARRAY[
      'id',
      'quizId',
      'quizDefinitionVersion',
      'attemptNumber',
      'status',
      'startedAt',
      'expiresAt',
      'questions',
      'savedAnswers'
    ]::text[],
    'Quiz-start idempotency response'
  );

  PERFORM private.assert_canonical_uuid_text(
    private.assert_jsonb_string(
      p_response_body -> 'id',
      'Quiz-start response id'
    ),
    'Quiz-start response id'
  );
  PERFORM private.assert_canonical_uuid_text(
    private.assert_jsonb_string(
      p_response_body -> 'quizId',
      'Quiz-start response quizId'
    ),
    'Quiz-start response quizId'
  );
  PERFORM private.assert_jsonb_bounded_integer(
    p_response_body -> 'quizDefinitionVersion',
    1,
    2147483647,
    'Quiz-start response quizDefinitionVersion'
  );
  PERFORM private.assert_jsonb_bounded_integer(
    p_response_body -> 'attemptNumber',
    1,
    1000000,
    'Quiz-start response attemptNumber'
  );
  IF p_response_body ->> 'status' IS DISTINCT FROM 'in_progress' THEN
    RAISE EXCEPTION 'Quiz-start response status must be in_progress.';
  END IF;

  v_timestamp := private.assert_jsonb_string(
    p_response_body -> 'startedAt',
    'Quiz-start response startedAt'
  );
  BEGIN
    PERFORM v_timestamp::timestamptz;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RAISE EXCEPTION 'Quiz-start response startedAt must be a timestamp.';
  END;

  IF pg_catalog.jsonb_typeof(p_response_body -> 'expiresAt') <> 'null' THEN
    v_timestamp := private.assert_jsonb_string(
      p_response_body -> 'expiresAt',
      'Quiz-start response expiresAt'
    );
    BEGIN
      PERFORM v_timestamp::timestamptz;
    EXCEPTION
      WHEN invalid_text_representation THEN
        RAISE EXCEPTION 'Quiz-start response expiresAt must be a timestamp.';
    END;
  END IF;

  IF pg_catalog.jsonb_typeof(p_response_body -> 'questions') <> 'array'
    OR pg_catalog.jsonb_array_length(p_response_body -> 'questions')
      NOT BETWEEN 1 AND 200 THEN
    RAISE EXCEPTION 'Quiz-start response questions are outside approved bounds.';
  END IF;
  IF pg_catalog.jsonb_typeof(p_response_body -> 'savedAnswers') <> 'array'
    OR pg_catalog.jsonb_array_length(p_response_body -> 'savedAnswers') <> 0 THEN
    RAISE EXCEPTION 'A new quiz-start response must not contain saved answers.';
  END IF;

  FOR v_question IN
    SELECT question_entry.value
    FROM pg_catalog.jsonb_array_elements(p_response_body -> 'questions')
      AS question_entry(value)
  LOOP
    PERFORM private.assert_exact_jsonb_object_keys(
      v_question,
      ARRAY[
        'id',
        'promptMarkdown',
        'questionType',
        'position',
        'points',
        'options'
      ]::text[],
      'Quiz-start response question'
    );
    PERFORM private.assert_canonical_uuid_text(
      private.assert_jsonb_string(
        v_question -> 'id',
        'Quiz-start response question id'
      ),
      'Quiz-start response question id'
    );
    PERFORM private.assert_markdown_input(
      private.assert_jsonb_string(
        v_question -> 'promptMarkdown',
        'Quiz-start response question promptMarkdown'
      ),
      50000,
      'Quiz-start response question promptMarkdown'
    );
    IF (v_question ->> 'questionType') IS DISTINCT FROM 'single_choice'
      AND (v_question ->> 'questionType') IS DISTINCT FROM 'multiple_choice'
      AND (v_question ->> 'questionType') IS DISTINCT FROM 'short_text' THEN
      RAISE EXCEPTION 'Quiz-start response questionType is invalid.';
    END IF;
    PERFORM private.assert_jsonb_bounded_integer(
      v_question -> 'position',
      0,
      10000,
      'Quiz-start response question position'
    );
    PERFORM private.assert_jsonb_bounded_integer(
      v_question -> 'points',
      1,
      1000,
      'Quiz-start response question points'
    );
    IF pg_catalog.jsonb_typeof(v_question -> 'options') <> 'array'
      OR pg_catalog.jsonb_array_length(v_question -> 'options') > 200 THEN
      RAISE EXCEPTION 'Quiz-start response question options are outside approved bounds.';
    END IF;

    FOR v_option IN
      SELECT option_entry.value
      FROM pg_catalog.jsonb_array_elements(v_question -> 'options')
        AS option_entry(value)
    LOOP
      PERFORM private.assert_exact_jsonb_object_keys(
        v_option,
        ARRAY['id', 'labelMarkdown', 'position']::text[],
        'Quiz-start response option'
      );
      PERFORM private.assert_canonical_uuid_text(
        private.assert_jsonb_string(
          v_option -> 'id',
          'Quiz-start response option id'
        ),
        'Quiz-start response option id'
      );
      PERFORM private.assert_markdown_input(
        private.assert_jsonb_string(
          v_option -> 'labelMarkdown',
          'Quiz-start response option labelMarkdown'
        ),
        10000,
        'Quiz-start response option labelMarkdown'
      );
      PERFORM private.assert_jsonb_bounded_integer(
        v_option -> 'position',
        0,
        10000,
        'Quiz-start response option position'
      );
    END LOOP;
  END LOOP;
END;
$assert_safe_quiz_start_idempotency_response$;

CREATE OR REPLACE FUNCTION private.assert_safe_idempotency_response(
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
  v_id uuid;
  v_timestamp text;
BEGIN
  IF pg_catalog.jsonb_typeof(p_response_body) <> 'object' THEN
    RAISE EXCEPTION 'The idempotency response must be an object.';
  END IF;

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
          'pointsPossible',
          'feedbackMarkdown'
        ]::text[],
        'Exercise idempotency response'
      );
      v_id := private.assert_canonical_uuid_text(
        private.assert_jsonb_string(
          p_response_body -> 'id',
          'Exercise idempotency response id'
        ),
        'Exercise idempotency response id'
      );
      PERFORM private.assert_canonical_uuid_text(
        private.assert_jsonb_string(
          p_response_body -> 'exerciseId',
          'Exercise idempotency response exerciseId'
        ),
        'Exercise idempotency response exerciseId'
      );
      PERFORM private.assert_jsonb_bounded_integer(
        p_response_body -> 'exerciseDefinitionVersion',
        1,
        2147483647,
        'Exercise idempotency response exerciseDefinitionVersion'
      );
      v_timestamp := private.assert_jsonb_string(
        p_response_body -> 'submittedAt',
        'Exercise idempotency response submittedAt'
      );
      BEGIN
        PERFORM v_timestamp::timestamptz;
      EXCEPTION
        WHEN invalid_text_representation THEN
          RAISE EXCEPTION 'Exercise idempotency response submittedAt must be a timestamp.';
      END;
      IF pg_catalog.jsonb_typeof(p_response_body -> 'isCorrect') <> 'boolean' THEN
        RAISE EXCEPTION 'Exercise idempotency response isCorrect must be boolean.';
      END IF;
      PERFORM private.assert_jsonb_bounded_integer(
        p_response_body -> 'pointsEarned',
        0,
        1000,
        'Exercise idempotency response pointsEarned'
      );
      PERFORM private.assert_jsonb_bounded_integer(
        p_response_body -> 'pointsPossible',
        1,
        1000,
        'Exercise idempotency response pointsPossible'
      );
      PERFORM private.assert_safe_idempotency_feedback_markdown(
        p_response_body -> 'feedbackMarkdown',
        'Exercise idempotency response feedbackMarkdown'
      );

    WHEN 'quiz_start' THEN
      PERFORM private.assert_safe_quiz_start_idempotency_response(
        p_response_body
      );
      v_id := private.assert_canonical_uuid_text(
        private.assert_jsonb_string(
          p_response_body -> 'id',
          'Quiz-start idempotency response id'
        ),
        'Quiz-start idempotency response id'
      );

    ELSE
      PERFORM private.assert_exact_jsonb_object_keys(
        p_response_body,
        ARRAY['id']::text[],
        'Future workflow idempotency response'
      );
      v_id := private.assert_canonical_uuid_text(
        private.assert_jsonb_string(
          p_response_body -> 'id',
          'Future workflow idempotency response id'
        ),
        'Future workflow idempotency response id'
      );
  END CASE;

  IF v_id IS DISTINCT FROM p_result_resource_id THEN
    RAISE EXCEPTION 'The idempotency response ID does not match its result resource.';
  END IF;
END;
$assert_safe_idempotency_response$;

CREATE FUNCTION private.acquire_idempotency_replay(
  p_user_id uuid,
  p_operation text,
  p_idempotency_key uuid,
  p_canonicalization_version integer,
  p_request_hash bytea
)
RETURNS TABLE (
  replayed boolean,
  result_resource_id uuid,
  response_status integer,
  response_location text,
  response_body jsonb
)
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $acquire_idempotency_replay$
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
    RETURN QUERY SELECT
      false,
      NULL::uuid,
      NULL::integer,
      NULL::text,
      NULL::jsonb;
    RETURN;
  END IF;

  IF pg_catalog.now() >= v_record.expires_at THEN
    PERFORM pg_catalog.set_config('coditza.learning_write', 'idempotency', true);
    DELETE FROM private.idempotency_records AS record_entry
    WHERE record_entry.user_id = p_user_id
      AND record_entry.operation = p_operation
      AND record_entry.idempotency_key = p_idempotency_key;
    PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
    RETURN QUERY SELECT
      false,
      NULL::uuid,
      NULL::integer,
      NULL::text,
      NULL::jsonb;
    RETURN;
  END IF;

  IF v_record.canonicalization_version <> p_canonicalization_version
    OR v_record.request_hash IS DISTINCT FROM p_request_hash THEN
    RAISE EXCEPTION 'The idempotency key is already bound to a different request.';
  END IF;

  RETURN QUERY SELECT
    true,
    v_record.result_resource_id,
    v_record.response_status,
    v_record.response_location,
    v_record.response_body;
END;
$acquire_idempotency_replay$;

CREATE OR REPLACE FUNCTION private.begin_idempotency(
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
  v_replay record;
BEGIN
  SELECT *
  INTO v_replay
  FROM private.acquire_idempotency_replay(
    p_user_id,
    p_operation,
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash
  );

  IF v_replay.replayed THEN
    RETURN v_replay.response_body;
  END IF;
  RETURN NULL;
END;
$begin_idempotency$;

CREATE OR REPLACE FUNCTION private.submit_scalar_exercise_attempt(
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
  v_feedback_markdown text;
  v_result jsonb;
BEGIN
  -- A held profile must not receive a replayed response. Curriculum state is
  -- intentionally checked only after a replay decision, so a valid active
  -- actor can still recover a lost original response after later archival.
  PERFORM private.assert_active_learning_actor(p_user_id);
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

  v_chapter_id := private.assert_effectively_published_exercise(p_exercise_id);
  PERFORM private.lock_chapter_progress(p_user_id, v_chapter_id);
  v_grade := private.grade_scalar_exercise_answer(p_exercise_id, p_answer);

  SELECT exercise.definition_version,
      CASE
        WHEN (v_grade ->> 'isCorrect')::boolean
          THEN answer_key.feedback_correct_markdown
        ELSE answer_key.feedback_incorrect_markdown
      END
  INTO v_definition_version, v_feedback_markdown
  FROM public.exercises AS exercise
  JOIN private.exercise_answer_keys AS answer_key
    ON answer_key.exercise_id = exercise.id
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
    (v_grade -> 'pointsPossible'),
    'feedbackMarkdown',
    v_feedback_markdown
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

CREATE OR REPLACE FUNCTION private.start_quiz_attempt(
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
  v_questions jsonb;
  v_result jsonb;
BEGIN
  PERFORM private.assert_active_learning_actor(p_user_id);
  PERFORM pg_catalog.set_config(
    'coditza.quiz_start_finalized_attempt_id',
    '',
    true
  );
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
      PERFORM pg_catalog.set_config(
        'coditza.quiz_start_finalized_attempt_id',
        v_active_attempt_id::text,
        true
      );
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

  SELECT pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'id',
      question.id::text,
      'promptMarkdown',
      question.prompt_markdown,
      'questionType',
      question.question_type::text,
      'position',
      question.position,
      'points',
      question.points,
      'options',
      COALESCE(
        (
          SELECT pg_catalog.jsonb_agg(
            pg_catalog.jsonb_build_object(
              'id',
              option_entry.id::text,
              'labelMarkdown',
              option_entry.label_markdown,
              'position',
              option_entry.position
            )
            ORDER BY option_entry.position, option_entry.id
          )
          FROM public.quiz_question_options AS option_entry
          WHERE option_entry.question_id = question.id
        ),
        '[]'::jsonb
      )
    )
    ORDER BY question.position, question.id
  )
  INTO v_questions
  FROM public.quiz_questions AS question
  WHERE question.quiz_id = p_quiz_id;

  v_result := pg_catalog.jsonb_build_object(
    'id',
    v_attempt_id::text,
    'quizId',
    p_quiz_id::text,
    'quizDefinitionVersion',
    v_quiz.definition_version,
    'attemptNumber',
    v_attempt_number,
    'status',
    'in_progress',
    'startedAt',
    v_started_at::text,
    'expiresAt',
    CASE
      WHEN v_expires_at IS NULL THEN NULL
      ELSE pg_catalog.to_jsonb(v_expires_at::text)
    END,
    'questions',
    COALESCE(v_questions, '[]'::jsonb),
    'savedAnswers',
    '[]'::jsonb
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

REVOKE ALL ON FUNCTION private.assert_safe_idempotency_feedback_markdown(jsonb, text)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.assert_safe_quiz_start_idempotency_response(jsonb)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.acquire_idempotency_replay(uuid, text, uuid, integer, bytea)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.begin_idempotency(uuid, text, uuid, integer, bytea)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.assert_safe_idempotency_response(text, uuid, jsonb)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.submit_scalar_exercise_attempt(uuid, uuid, jsonb, uuid, integer, bytea)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.start_quiz_attempt(uuid, uuid, uuid, integer, bytea)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

RESET ROLE;

COMMIT;
