-- SUP-FUNCTIONS-001 (assessment history learner slice): safe server-only
-- projections for a learner's immutable exercise and quiz attempts. The
-- progress list replacement repairs its next-cursor scope before an HTTP
-- adapter starts consuming the cursor contract.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE INDEX exercise_attempts_user_submitted_id_idx
  ON public.exercise_attempts (user_id, submitted_at DESC, id DESC);
CREATE INDEX quiz_attempts_user_quiz_history_idx
  ON public.quiz_attempts (
    user_id,
    quiz_id,
    (COALESCE(submitted_at, started_at)) DESC,
    id DESC
  );

CREATE OR REPLACE FUNCTION public.progress_list_own_modules(
  p_actor_user_id uuid,
  p_cursor_position integer,
  p_cursor_module_id uuid,
  p_limit integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $progress_list_own_modules$
DECLARE
  v_items jsonb;
  v_next_cursor jsonb;
  v_snapshot_missing boolean;
BEGIN
  PERFORM private.assert_active_learning_actor(p_actor_user_id);
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'Progress page limit is outside approved bounds.';
  END IF;
  IF (p_cursor_position IS NULL) <> (p_cursor_module_id IS NULL) THEN
    RAISE EXCEPTION 'Progress cursor fields must be both present or both absent.';
  END IF;
  IF p_cursor_position IS NOT NULL AND p_cursor_position < 0 THEN
    RAISE EXCEPTION 'Progress cursor position is invalid.';
  END IF;

  WITH module_summaries AS (
    SELECT
      module_entry.id AS module_id,
      module_entry.title AS title,
      module_entry.position AS position,
      pg_catalog.count(chapter_entry.chapter_id)::integer
        AS total_published_chapters,
      pg_catalog.count(chapter_entry.chapter_id) FILTER (
        WHERE chapter_entry.currently_completed
      )::integer AS completed_published_chapters,
      CASE
        WHEN pg_catalog.count(chapter_entry.chapter_id) = 0 THEN 0::numeric
        ELSE pg_catalog.floor(
          (
            pg_catalog.count(chapter_entry.chapter_id) FILTER (
              WHERE chapter_entry.currently_completed
            )::numeric * 10000
          ) / pg_catalog.count(chapter_entry.chapter_id)
        ) / 100
      END AS percent,
      CASE
        WHEN pg_catalog.count(chapter_entry.chapter_id) > 0
          AND pg_catalog.count(chapter_entry.chapter_id) FILTER (
            WHERE chapter_entry.currently_completed
          ) = pg_catalog.count(chapter_entry.chapter_id)
          AND pg_catalog.count(chapter_entry.chapter_id) FILTER (
            WHERE chapter_entry.completed_at IS NOT NULL
          ) = pg_catalog.count(chapter_entry.chapter_id)
          THEN pg_catalog.max(chapter_entry.completed_at)
        ELSE NULL::timestamptz
      END AS completed_at,
      COALESCE(
        pg_catalog.bool_or(chapter_entry.snapshot_missing),
        false
      ) AS snapshot_missing
    FROM public.modules AS module_entry
    LEFT JOIN private.list_learner_published_chapters(p_actor_user_id)
      AS chapter_entry
      ON chapter_entry.module_id = module_entry.id
    WHERE module_entry.status = 'published'::public.content_status
    GROUP BY module_entry.id, module_entry.title, module_entry.position
  ),
  eligible AS (
    SELECT *
    FROM module_summaries
    WHERE p_cursor_position IS NULL
      OR (position, module_id) > (p_cursor_position, p_cursor_module_id)
  ),
  page_plus AS (
    SELECT *
    FROM eligible
    ORDER BY position, module_id
    LIMIT p_limit + 1
  ),
  page AS (
    SELECT *
    FROM page_plus
    ORDER BY position, module_id
    LIMIT p_limit
  )
  SELECT
    COALESCE(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'moduleId', page.module_id::text,
          'title', page.title,
          'completedPublishedChapters', page.completed_published_chapters,
          'totalPublishedChapters', page.total_published_chapters,
          'percent', page.percent,
          'completedAt', page.completed_at
        )
        ORDER BY page.position, page.module_id
      ),
      '[]'::jsonb
    ),
    CASE
      WHEN EXISTS (SELECT 1 FROM page_plus OFFSET p_limit) THEN (
        SELECT pg_catalog.jsonb_build_object(
          'position', last_page.position,
          'moduleId', last_page.module_id::text
        )
        FROM page AS last_page
        ORDER BY last_page.position DESC, last_page.module_id DESC
        LIMIT 1
      )
      ELSE NULL::jsonb
    END,
    COALESCE(pg_catalog.bool_or(page.snapshot_missing), false)
  INTO v_items, v_next_cursor, v_snapshot_missing
  FROM page;

  IF v_snapshot_missing THEN
    RAISE LOG 'coditza_progress_snapshot_missing';
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'items', v_items,
    'nextCursor', v_next_cursor
  );
END;
$progress_list_own_modules$;

CREATE FUNCTION public.assessment_list_own_exercise_attempts(
  p_actor_user_id uuid,
  p_exercise_id uuid,
  p_cursor_submitted_at timestamptz,
  p_cursor_attempt_id uuid,
  p_limit integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $assessment_list_own_exercise_attempts$
DECLARE
  v_items jsonb;
  v_next_cursor jsonb;
BEGIN
  PERFORM private.assert_active_learning_actor(p_actor_user_id);
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'Exercise history page limit is outside approved bounds.';
  END IF;
  IF (p_cursor_submitted_at IS NULL) <> (p_cursor_attempt_id IS NULL) THEN
    RAISE EXCEPTION
      'Exercise history cursor fields must be both present or both absent.';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.exercise_attempts AS attempt
    LEFT JOIN public.exercises AS exercise
      ON exercise.id = attempt.exercise_id
    WHERE attempt.user_id = p_actor_user_id
      AND (p_exercise_id IS NULL OR attempt.exercise_id = p_exercise_id)
      AND (
        p_cursor_submitted_at IS NULL
        OR (attempt.submitted_at, attempt.id)
          < (p_cursor_submitted_at, p_cursor_attempt_id)
      )
      AND (
        exercise.id IS NULL
        OR exercise.definition_version
          IS DISTINCT FROM attempt.exercise_definition_version
      )
  ) THEN
    RAISE EXCEPTION 'The exercise attempt history is internally inconsistent.';
  END IF;

  WITH eligible AS (
    SELECT attempt.id, attempt.submitted_at
    FROM public.exercise_attempts AS attempt
    WHERE attempt.user_id = p_actor_user_id
      AND (p_exercise_id IS NULL OR attempt.exercise_id = p_exercise_id)
      AND (
        p_cursor_submitted_at IS NULL
        OR (attempt.submitted_at, attempt.id)
          < (p_cursor_submitted_at, p_cursor_attempt_id)
      )
  ),
  page_plus AS (
    SELECT *
    FROM eligible
    ORDER BY submitted_at DESC, id DESC
    LIMIT p_limit + 1
  ),
  page AS (
    SELECT *
    FROM page_plus
    ORDER BY submitted_at DESC, id DESC
    LIMIT p_limit
  ),
  projected AS (
    SELECT
      page.submitted_at AS page_submitted_at,
      page.id AS page_attempt_id,
      attempt.id,
      attempt.exercise_id,
      attempt.exercise_definition_version,
      attempt.answer,
      attempt.is_correct,
      attempt.points_earned,
      attempt.points_possible,
      attempt.submitted_at,
      exercise.exercise_type,
      answer_key.feedback_correct_markdown,
      answer_key.feedback_incorrect_markdown
    FROM page
    JOIN public.exercise_attempts AS attempt ON attempt.id = page.id
    JOIN public.exercises AS exercise
      ON exercise.id = attempt.exercise_id
      AND exercise.definition_version = attempt.exercise_definition_version
    LEFT JOIN private.exercise_answer_keys AS answer_key
      ON answer_key.exercise_id = attempt.exercise_id
  )
  SELECT
    COALESCE(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', projected.id::text,
          'exerciseId', projected.exercise_id::text,
          'exerciseDefinitionVersion', projected.exercise_definition_version,
          'submittedAt', projected.submitted_at::text,
          'answer', projected.answer,
          'isCorrect', projected.is_correct,
          'pointsEarned', projected.points_earned,
          'pointsPossible', projected.points_possible,
          'feedbackMarkdown',
            CASE
              WHEN projected.exercise_type = 'python_code'::public.exercise_type
                THEN NULL::text
              WHEN projected.is_correct
                THEN projected.feedback_correct_markdown
              ELSE projected.feedback_incorrect_markdown
            END
        )
        ORDER BY projected.page_submitted_at DESC, projected.page_attempt_id DESC
      ),
      '[]'::jsonb
    ),
    CASE
      WHEN EXISTS (SELECT 1 FROM page_plus OFFSET p_limit) THEN (
        SELECT pg_catalog.jsonb_build_object(
          'submittedAt', last_page.submitted_at::text,
          'attemptId', last_page.id::text
        )
        FROM page AS last_page
        ORDER BY last_page.submitted_at ASC, last_page.id ASC
        LIMIT 1
      )
      ELSE NULL::jsonb
    END
  INTO v_items, v_next_cursor
  FROM projected;

  RETURN pg_catalog.jsonb_build_object(
    'items', v_items,
    'nextCursor', v_next_cursor
  );
END;
$assessment_list_own_exercise_attempts$;

CREATE FUNCTION public.assessment_get_own_exercise_attempt(
  p_actor_user_id uuid,
  p_attempt_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $assessment_get_own_exercise_attempt$
DECLARE
  v_result jsonb;
BEGIN
  PERFORM private.assert_active_learning_actor(p_actor_user_id);

  SELECT pg_catalog.jsonb_build_object(
    'id', attempt.id::text,
    'exerciseId', attempt.exercise_id::text,
    'exerciseDefinitionVersion', attempt.exercise_definition_version,
    'submittedAt', attempt.submitted_at::text,
    'answer', attempt.answer,
    'isCorrect', attempt.is_correct,
    'pointsEarned', attempt.points_earned,
    'pointsPossible', attempt.points_possible,
    'feedbackMarkdown',
      CASE
        WHEN exercise.exercise_type = 'python_code'::public.exercise_type
          THEN NULL::text
        WHEN attempt.is_correct THEN answer_key.feedback_correct_markdown
        ELSE answer_key.feedback_incorrect_markdown
      END
  )
  INTO v_result
  FROM public.exercise_attempts AS attempt
  JOIN public.exercises AS exercise
    ON exercise.id = attempt.exercise_id
    AND exercise.definition_version = attempt.exercise_definition_version
  LEFT JOIN private.exercise_answer_keys AS answer_key
    ON answer_key.exercise_id = attempt.exercise_id
  WHERE attempt.id = p_attempt_id
    AND attempt.user_id = p_actor_user_id;

  IF v_result IS NULL THEN
    RAISE EXCEPTION 'The exercise attempt is absent.';
  END IF;
  RETURN v_result;
END;
$assessment_get_own_exercise_attempt$;

CREATE FUNCTION public.assessment_list_own_quiz_attempts(
  p_actor_user_id uuid,
  p_quiz_id uuid,
  p_status_filter text,
  p_cursor_occurred_at timestamptz,
  p_cursor_attempt_id uuid,
  p_limit integer
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $assessment_list_own_quiz_attempts$
DECLARE
  v_items jsonb;
  v_next_cursor jsonb;
BEGIN
  PERFORM private.assert_active_learning_actor(p_actor_user_id);
  IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION 'Quiz history page limit is outside approved bounds.';
  END IF;
  IF (p_cursor_occurred_at IS NULL) <> (p_cursor_attempt_id IS NULL) THEN
    RAISE EXCEPTION
      'Quiz history cursor fields must be both present or both absent.';
  END IF;
  IF p_status_filter IS NOT NULL
    AND p_status_filter NOT IN ('in_progress', 'submitted', 'expired') THEN
    RAISE EXCEPTION 'Quiz history status filter is invalid.';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.quiz_attempts AS attempt
    LEFT JOIN public.quizzes AS quiz ON quiz.id = attempt.quiz_id
    WHERE attempt.user_id = p_actor_user_id
      AND (p_quiz_id IS NULL OR attempt.quiz_id = p_quiz_id)
      AND (
        p_status_filter IS NULL
        OR attempt.status::text = p_status_filter
      )
      AND (
        p_cursor_occurred_at IS NULL
        OR (
          COALESCE(attempt.submitted_at, attempt.started_at),
          attempt.id
        ) < (p_cursor_occurred_at, p_cursor_attempt_id)
      )
      AND (
        quiz.id IS NULL
        OR quiz.definition_version IS DISTINCT FROM attempt.quiz_definition_version
      )
  ) THEN
    RAISE EXCEPTION 'The quiz attempt history is internally inconsistent.';
  END IF;

  WITH eligible AS (
    SELECT
      attempt.id,
      COALESCE(attempt.submitted_at, attempt.started_at) AS occurred_at
    FROM public.quiz_attempts AS attempt
    WHERE attempt.user_id = p_actor_user_id
      AND (p_quiz_id IS NULL OR attempt.quiz_id = p_quiz_id)
      AND (
        p_status_filter IS NULL
        OR attempt.status::text = p_status_filter
      )
      AND (
        p_cursor_occurred_at IS NULL
        OR (
          COALESCE(attempt.submitted_at, attempt.started_at),
          attempt.id
        ) < (p_cursor_occurred_at, p_cursor_attempt_id)
      )
  ),
  page_plus AS (
    SELECT *
    FROM eligible
    ORDER BY occurred_at DESC, id DESC
    LIMIT p_limit + 1
  ),
  page AS (
    SELECT *
    FROM page_plus
    ORDER BY occurred_at DESC, id DESC
    LIMIT p_limit
  ),
  projected AS (
    SELECT
      page.occurred_at,
      page.id AS page_attempt_id,
      attempt.id,
      attempt.quiz_id,
      attempt.quiz_definition_version,
      attempt.attempt_number,
      attempt.status,
      attempt.started_at,
      attempt.expires_at,
      attempt.submitted_at,
      attempt.points_earned,
      attempt.points_possible,
      attempt.score_percent,
      attempt.passed
    FROM page
    JOIN public.quiz_attempts AS attempt ON attempt.id = page.id
    JOIN public.quizzes AS quiz
      ON quiz.id = attempt.quiz_id
      AND quiz.definition_version = attempt.quiz_definition_version
  )
  SELECT
    COALESCE(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', projected.id::text,
          'quizId', projected.quiz_id::text,
          'quizDefinitionVersion', projected.quiz_definition_version,
          'attemptNumber', projected.attempt_number,
          'status', projected.status::text,
          'startedAt', projected.started_at::text,
          'expiresAt', projected.expires_at::text,
          'submittedAt', projected.submitted_at::text,
          'pointsEarned', projected.points_earned,
          'pointsPossible', projected.points_possible,
          'scorePercent', projected.score_percent,
          'passed', projected.passed
        )
        ORDER BY projected.occurred_at DESC, projected.page_attempt_id DESC
      ),
      '[]'::jsonb
    ),
    CASE
      WHEN EXISTS (SELECT 1 FROM page_plus OFFSET p_limit) THEN (
        SELECT pg_catalog.jsonb_build_object(
          'occurredAt', last_page.occurred_at::text,
          'attemptId', last_page.id::text
        )
        FROM page AS last_page
        ORDER BY last_page.occurred_at ASC, last_page.id ASC
        LIMIT 1
      )
      ELSE NULL::jsonb
    END
  INTO v_items, v_next_cursor
  FROM projected;

  RETURN pg_catalog.jsonb_build_object(
    'items', v_items,
    'nextCursor', v_next_cursor
  );
END;
$assessment_list_own_quiz_attempts$;

CREATE FUNCTION public.assessment_get_own_quiz_attempt(
  p_actor_user_id uuid,
  p_attempt_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $assessment_get_own_quiz_attempt$
DECLARE
  v_quiz_id uuid;
  v_quiz_definition_version integer;
  v_attempt_number integer;
  v_status text;
  v_started_at timestamptz;
  v_expires_at timestamptz;
  v_submitted_at timestamptz;
  v_points_earned integer;
  v_points_possible integer;
  v_score_percent numeric(5,2);
  v_passed boolean;
  v_terminal boolean;
  v_question_count integer;
  v_question_points integer;
  v_questions jsonb;
  v_saved_answers jsonb;
  v_answers jsonb := '[]'::jsonb;
  v_result jsonb;
BEGIN
  PERFORM private.assert_active_learning_actor(p_actor_user_id);

  SELECT
    attempt.quiz_id,
    attempt.quiz_definition_version,
    attempt.attempt_number,
    attempt.status::text,
    attempt.started_at,
    attempt.expires_at,
    attempt.submitted_at,
    attempt.points_earned,
    attempt.points_possible,
    attempt.score_percent,
    attempt.passed
  INTO
    v_quiz_id,
    v_quiz_definition_version,
    v_attempt_number,
    v_status,
    v_started_at,
    v_expires_at,
    v_submitted_at,
    v_points_earned,
    v_points_possible,
    v_score_percent,
    v_passed
  FROM public.quiz_attempts AS attempt
  WHERE attempt.id = p_attempt_id
    AND attempt.user_id = p_actor_user_id
  FOR KEY SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz attempt is absent.';
  END IF;

  PERFORM 1
  FROM public.quizzes AS quiz
  WHERE quiz.id = v_quiz_id
    AND quiz.definition_version = v_quiz_definition_version
  FOR KEY SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz attempt is absent.';
  END IF;

  v_terminal := v_status IN ('submitted', 'expired');
  IF v_terminal THEN
    SELECT
      pg_catalog.count(*)::integer,
      COALESCE(pg_catalog.sum(question.points), 0)::integer
    INTO v_question_count, v_question_points
    FROM public.quiz_questions AS question
    WHERE question.quiz_id = v_quiz_id;

    IF v_question_count = 0
      OR v_question_points IS DISTINCT FROM v_points_possible
      OR EXISTS (
        SELECT 1
        FROM public.quiz_attempt_answers AS answer_entry
        LEFT JOIN public.quiz_questions AS question
          ON question.id = answer_entry.question_id
          AND question.quiz_id = v_quiz_id
        WHERE answer_entry.attempt_id = p_attempt_id
          AND (
            question.id IS NULL
            OR answer_entry.is_correct IS NULL
            OR answer_entry.points_earned IS NULL
          )
      )
      OR EXISTS (
        SELECT 1
        FROM public.quiz_questions AS question
        LEFT JOIN private.quiz_question_answer_keys AS answer_key
          ON answer_key.question_id = question.id
        WHERE question.quiz_id = v_quiz_id
          AND answer_key.question_id IS NULL
      ) THEN
      RAISE EXCEPTION 'The quiz attempt history is internally inconsistent.';
    END IF;
  END IF;

  WITH frozen_questions AS MATERIALIZED (
    SELECT
      question.id,
      question.prompt_markdown,
      question.question_type,
      question.position,
      question.points
    FROM public.quiz_questions AS question
    WHERE question.quiz_id = v_quiz_id
  ),
  options_by_question AS (
    SELECT
      option_entry.question_id,
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', option_entry.id::text,
          'labelMarkdown', option_entry.label_markdown,
          'position', option_entry.position
        )
        ORDER BY option_entry.position, option_entry.id
      ) AS options
    FROM public.quiz_question_options AS option_entry
    JOIN frozen_questions AS question
      ON question.id = option_entry.question_id
    GROUP BY option_entry.question_id
  ),
  questions_json AS (
    SELECT COALESCE(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'id', question.id::text,
          'promptMarkdown', question.prompt_markdown,
          'questionType', question.question_type::text,
          'position', question.position,
          'points', question.points,
          'options', COALESCE(option_set.options, '[]'::jsonb)
        )
        ORDER BY question.position, question.id
      ),
      '[]'::jsonb
    ) AS value
    FROM frozen_questions AS question
    LEFT JOIN options_by_question AS option_set
      ON option_set.question_id = question.id
  ),
  saved_answers_json AS (
    SELECT COALESCE(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'questionId', question.id::text,
          'answer', answer_entry.answer,
          'answeredAt', answer_entry.answered_at::text
        )
        ORDER BY question.position, question.id
      ),
      '[]'::jsonb
    ) AS value
    FROM frozen_questions AS question
    JOIN public.quiz_attempt_answers AS answer_entry
      ON answer_entry.attempt_id = p_attempt_id
      AND answer_entry.question_id = question.id
  )
  SELECT questions_json.value, saved_answers_json.value
  INTO v_questions, v_saved_answers
  FROM questions_json
  CROSS JOIN saved_answers_json;

  IF v_terminal THEN
    WITH frozen_questions AS MATERIALIZED (
      SELECT question.id, question.position
      FROM public.quiz_questions AS question
      WHERE question.quiz_id = v_quiz_id
    )
    SELECT COALESCE(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'questionId', question.id::text,
          'submittedAnswer', answer_entry.answer,
          'isCorrect', COALESCE(answer_entry.is_correct, false),
          'pointsEarned', COALESCE(answer_entry.points_earned, 0),
          'feedbackMarkdown',
            CASE
              WHEN COALESCE(answer_entry.is_correct, false)
                THEN answer_key.feedback_correct_markdown
              ELSE answer_key.feedback_incorrect_markdown
            END
        )
        ORDER BY question.position, question.id
      ),
      '[]'::jsonb
    )
    INTO v_answers
    FROM frozen_questions AS question
    LEFT JOIN public.quiz_attempt_answers AS answer_entry
      ON answer_entry.attempt_id = p_attempt_id
      AND answer_entry.question_id = question.id
    JOIN private.quiz_question_answer_keys AS answer_key
      ON answer_key.question_id = question.id;
  END IF;

  v_result := pg_catalog.jsonb_build_object(
    'id', p_attempt_id::text,
    'quizId', v_quiz_id::text,
    'quizDefinitionVersion', v_quiz_definition_version,
    'attemptNumber', v_attempt_number,
    'status', v_status,
    'startedAt', v_started_at::text,
    'expiresAt', v_expires_at::text,
    'questions', v_questions,
    'savedAnswers', v_saved_answers,
    'answers', v_answers
  );
  IF v_terminal THEN
    v_result := v_result || pg_catalog.jsonb_build_object(
      'submittedAt', v_submitted_at::text,
      'pointsEarned', v_points_earned,
      'pointsPossible', v_points_possible,
      'scorePercent', v_score_percent,
      'passed', v_passed
    );
  END IF;
  RETURN v_result;
END;
$assessment_get_own_quiz_attempt$;

REVOKE ALL ON FUNCTION public.progress_list_own_modules(
  uuid, integer, uuid, integer
) FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION public.assessment_list_own_exercise_attempts(
  uuid, uuid, timestamptz, uuid, integer
) FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION public.assessment_get_own_exercise_attempt(uuid, uuid)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION public.assessment_list_own_quiz_attempts(
  uuid, uuid, text, timestamptz, uuid, integer
) FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION public.assessment_get_own_quiz_attempt(uuid, uuid)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

GRANT EXECUTE ON FUNCTION public.progress_list_own_modules(
  uuid, integer, uuid, integer
) TO service_role;
GRANT EXECUTE ON FUNCTION public.assessment_list_own_exercise_attempts(
  uuid, uuid, timestamptz, uuid, integer
) TO service_role;
GRANT EXECUTE ON FUNCTION public.assessment_get_own_exercise_attempt(uuid, uuid)
  TO service_role;
GRANT EXECUTE ON FUNCTION public.assessment_list_own_quiz_attempts(
  uuid, uuid, text, timestamptz, uuid, integer
) TO service_role;
GRANT EXECUTE ON FUNCTION public.assessment_get_own_quiz_attempt(uuid, uuid)
  TO service_role;

RESET ROLE;

COMMIT;
