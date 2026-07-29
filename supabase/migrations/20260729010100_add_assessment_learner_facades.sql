-- SUP-FUNCTIONS-001 (assessment learner slice): named server-only facades
-- over the existing owner-only learning primitives. The functions accept a
-- Fastify-verified actor and server-generated request ID; neither is inferred
-- from a secret-key database session.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION private.assert_server_request_id(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_server_request_id$
BEGIN
  IF p_request_id IS NULL THEN
    RAISE EXCEPTION 'A server-generated request ID is required.';
  END IF;
END;
$assert_server_request_id$;

CREATE FUNCTION private.project_saved_quiz_answer(
  p_attempt_id uuid,
  p_question_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $project_saved_quiz_answer$
DECLARE
  v_result jsonb;
BEGIN
  SELECT pg_catalog.jsonb_build_object(
    'questionId',
    answer_entry.question_id::text,
    'answer',
    answer_entry.answer,
    'answeredAt',
    answer_entry.answered_at::text
  )
  INTO v_result
  FROM public.quiz_attempt_answers AS answer_entry
  WHERE answer_entry.attempt_id = p_attempt_id
    AND answer_entry.question_id = p_question_id;

  IF v_result IS NULL THEN
    RAISE EXCEPTION 'The quiz answer was not retained.';
  END IF;
  RETURN v_result;
END;
$project_saved_quiz_answer$;

CREATE FUNCTION private.project_terminal_quiz_attempt(p_attempt_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $project_terminal_quiz_attempt$
DECLARE
  v_attempt public.quiz_attempts%ROWTYPE;
  v_answers jsonb;
BEGIN
  SELECT *
  INTO v_attempt
  FROM public.quiz_attempts AS attempt
  WHERE attempt.id = p_attempt_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz attempt does not exist.';
  END IF;
  IF v_attempt.status = 'in_progress'::public.quiz_attempt_status THEN
    RAISE EXCEPTION 'The quiz attempt has not reached a terminal state.';
  END IF;

  SELECT pg_catalog.jsonb_agg(
    pg_catalog.jsonb_build_object(
      'questionId',
      question.id::text,
      'submittedAnswer',
      answer_entry.answer,
      'isCorrect',
      COALESCE(answer_entry.is_correct, false),
      'pointsEarned',
      COALESCE(answer_entry.points_earned, 0),
      'feedbackMarkdown',
      CASE
        WHEN COALESCE(answer_entry.is_correct, false)
          THEN answer_key.feedback_correct_markdown
        ELSE answer_key.feedback_incorrect_markdown
      END
    )
    ORDER BY question.position, question.id
  )
  INTO v_answers
  FROM public.quiz_questions AS question
  JOIN private.quiz_question_answer_keys AS answer_key
    ON answer_key.question_id = question.id
  LEFT JOIN public.quiz_attempt_answers AS answer_entry
    ON answer_entry.attempt_id = v_attempt.id
    AND answer_entry.question_id = question.id
  WHERE question.quiz_id = v_attempt.quiz_id;

  RETURN pg_catalog.jsonb_build_object(
    'id',
    v_attempt.id::text,
    'quizId',
    v_attempt.quiz_id::text,
    'quizDefinitionVersion',
    v_attempt.quiz_definition_version,
    'attemptNumber',
    v_attempt.attempt_number,
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
    v_attempt.passed,
    'answers',
    COALESCE(v_answers, '[]'::jsonb)
  );
END;
$project_terminal_quiz_attempt$;

CREATE FUNCTION public.assessment_submit_exercise_attempt(
  p_actor_user_id uuid,
  p_exercise_id uuid,
  p_answer jsonb,
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
AS $assessment_submit_exercise_attempt$
DECLARE
  v_replay record;
  v_result jsonb;
  v_attempt_id uuid;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);
  PERFORM private.assert_active_learning_actor(p_actor_user_id);

  SELECT *
  INTO v_replay
  FROM private.acquire_idempotency_replay(
    p_actor_user_id,
    'exercise_submit',
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

  v_result := private.submit_scalar_exercise_attempt(
    p_actor_user_id,
    p_exercise_id,
    p_answer,
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash
  );
  v_attempt_id := private.assert_canonical_uuid_text(
    private.assert_jsonb_string(
      v_result -> 'id',
      'Exercise attempt result id'
    ),
    'Exercise attempt result id'
  );

  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'exercise_attempt_submitted',
    'exercise_attempt',
    v_attempt_id,
    ARRAY['status']::text[],
    '{"status":{"before":"none","after":"submitted"}}'::jsonb,
    NULL,
    p_request_id
  );

  RETURN QUERY SELECT
    201,
    '/api/v1/me/exercise-attempts/' || v_attempt_id::text,
    false,
    v_result;
END;
$assessment_submit_exercise_attempt$;

CREATE FUNCTION public.assessment_start_quiz_attempt(
  p_actor_user_id uuid,
  p_quiz_id uuid,
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
AS $assessment_start_quiz_attempt$
DECLARE
  v_replay record;
  v_result jsonb;
  v_attempt_id uuid;
  v_stale_attempt_id_text text;
  v_stale_attempt_id uuid;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);
  PERFORM private.assert_active_learning_actor(p_actor_user_id);

  SELECT *
  INTO v_replay
  FROM private.acquire_idempotency_replay(
    p_actor_user_id,
    'quiz_start',
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

  v_result := private.start_quiz_attempt(
    p_actor_user_id,
    p_quiz_id,
    p_idempotency_key,
    p_canonicalization_version,
    p_request_hash
  );
  v_stale_attempt_id_text := pg_catalog.current_setting(
    'coditza.quiz_start_finalized_attempt_id',
    true
  );
  IF v_stale_attempt_id_text IS NOT NULL
    AND v_stale_attempt_id_text <> '' THEN
    v_stale_attempt_id := private.assert_canonical_uuid_text(
      v_stale_attempt_id_text,
      'Expired quiz-start attempt id'
    );
    PERFORM private.append_audit_event(
      'user',
      p_actor_user_id,
      'quiz_attempt_finalized',
      'quiz_attempt',
      v_stale_attempt_id,
      ARRAY['status']::text[],
      '{"status":{"before":"in_progress","after":"expired"}}'::jsonb,
      NULL,
      p_request_id
    );
  END IF;
  IF v_result ? 'outcome' THEN
    RETURN QUERY SELECT 422, NULL::text, false, v_result;
    RETURN;
  END IF;

  v_attempt_id := private.assert_canonical_uuid_text(
    private.assert_jsonb_string(
      v_result -> 'id',
      'Quiz attempt result id'
    ),
    'Quiz attempt result id'
  );
  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'quiz_attempt_started',
    'quiz_attempt',
    v_attempt_id,
    ARRAY['status']::text[],
    '{"status":{"before":"none","after":"in_progress"}}'::jsonb,
    NULL,
    p_request_id
  );

  RETURN QUERY SELECT
    201,
    '/api/v1/me/quiz-attempts/' || v_attempt_id::text,
    false,
    v_result;
END;
$assessment_start_quiz_attempt$;

CREATE FUNCTION public.assessment_save_quiz_answer(
  p_actor_user_id uuid,
  p_attempt_id uuid,
  p_question_id uuid,
  p_answer jsonb,
  p_request_id uuid
)
RETURNS TABLE (
  response_status integer,
  response_body jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $assessment_save_quiz_answer$
DECLARE
  v_result jsonb;
  v_previous_answer jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);
  PERFORM private.assert_active_learning_actor(p_actor_user_id);
  PERFORM private.assert_mutable_quiz_attempt(
    p_actor_user_id,
    p_attempt_id
  );
  SELECT answer_entry.answer
  INTO v_previous_answer
  FROM public.quiz_attempt_answers AS answer_entry
  WHERE answer_entry.attempt_id = p_attempt_id
    AND answer_entry.question_id = p_question_id;
  PERFORM private.save_quiz_answer(
    p_actor_user_id,
    p_attempt_id,
    p_question_id,
    p_answer
  );
  v_result := private.project_saved_quiz_answer(p_attempt_id, p_question_id);

  IF v_previous_answer IS DISTINCT FROM v_result -> 'answer' THEN
    -- Answer material is deliberately excluded from the audit contract. The
    -- event records only a real protected attempt transition.
    PERFORM private.append_audit_event(
      'user',
      p_actor_user_id,
      'quiz_answer_saved',
      'quiz_attempt',
      p_attempt_id,
      ARRAY[]::text[],
      '{}'::jsonb,
      NULL,
      p_request_id
    );
  END IF;

  RETURN QUERY SELECT 200, v_result;
END;
$assessment_save_quiz_answer$;

CREATE FUNCTION public.assessment_remove_quiz_answer(
  p_actor_user_id uuid,
  p_attempt_id uuid,
  p_question_id uuid,
  p_request_id uuid
)
RETURNS TABLE (
  response_status integer,
  response_body jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $assessment_remove_quiz_answer$
DECLARE
  v_removed boolean;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);
  v_removed := private.remove_quiz_answer(
    p_actor_user_id,
    p_attempt_id,
    p_question_id
  );

  IF v_removed THEN
    PERFORM private.append_audit_event(
      'user',
      p_actor_user_id,
      'quiz_answer_removed',
      'quiz_attempt',
      p_attempt_id,
      ARRAY[]::text[],
      '{}'::jsonb,
      NULL,
      p_request_id
    );
  END IF;

  RETURN QUERY SELECT 204, NULL::jsonb;
END;
$assessment_remove_quiz_answer$;

CREATE FUNCTION public.assessment_submit_quiz_attempt(
  p_actor_user_id uuid,
  p_attempt_id uuid,
  p_request_id uuid
)
RETURNS TABLE (
  response_status integer,
  response_body jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $assessment_submit_quiz_attempt$
DECLARE
  v_before_status public.quiz_attempt_status;
  v_result jsonb;
  v_terminal_status text;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);
  PERFORM private.assert_active_learning_actor(p_actor_user_id);

  SELECT attempt.status
  INTO v_before_status
  FROM public.quiz_attempts AS attempt
  WHERE attempt.id = p_attempt_id
    AND attempt.user_id = p_actor_user_id
  FOR UPDATE;

  PERFORM private.submit_quiz_attempt(p_actor_user_id, p_attempt_id);
  v_result := private.project_terminal_quiz_attempt(p_attempt_id);
  v_terminal_status := private.assert_jsonb_string(
    v_result -> 'status',
    'Quiz terminal response status'
  );

  IF v_before_status = 'in_progress'::public.quiz_attempt_status THEN
    PERFORM private.append_audit_event(
      'user',
      p_actor_user_id,
      'quiz_attempt_finalized',
      'quiz_attempt',
      p_attempt_id,
      ARRAY['status']::text[],
      pg_catalog.jsonb_build_object(
        'status',
        pg_catalog.jsonb_build_object(
          'before',
          'in_progress',
          'after',
          v_terminal_status
        )
      ),
      NULL,
      p_request_id
    );
  END IF;

  RETURN QUERY SELECT 200, v_result;
END;
$assessment_submit_quiz_attempt$;

REVOKE ALL ON FUNCTION private.assert_server_request_id(uuid)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.project_saved_quiz_answer(uuid, uuid)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.project_terminal_quiz_attempt(uuid)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

REVOKE ALL ON FUNCTION public.assessment_submit_exercise_attempt(
  uuid, uuid, jsonb, uuid, integer, bytea, uuid
) FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION public.assessment_start_quiz_attempt(
  uuid, uuid, uuid, integer, bytea, uuid
) FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION public.assessment_save_quiz_answer(
  uuid, uuid, uuid, jsonb, uuid
) FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION public.assessment_remove_quiz_answer(
  uuid, uuid, uuid, uuid
) FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION public.assessment_submit_quiz_attempt(
  uuid, uuid, uuid
) FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

GRANT EXECUTE ON FUNCTION public.assessment_submit_exercise_attempt(
  uuid, uuid, jsonb, uuid, integer, bytea, uuid
) TO service_role;
GRANT EXECUTE ON FUNCTION public.assessment_start_quiz_attempt(
  uuid, uuid, uuid, integer, bytea, uuid
) TO service_role;
GRANT EXECUTE ON FUNCTION public.assessment_save_quiz_answer(
  uuid, uuid, uuid, jsonb, uuid
) TO service_role;
GRANT EXECUTE ON FUNCTION public.assessment_remove_quiz_answer(
  uuid, uuid, uuid, uuid
) TO service_role;
GRANT EXECUTE ON FUNCTION public.assessment_submit_quiz_attempt(
  uuid, uuid, uuid
) TO service_role;

RESET ROLE;

COMMIT;
