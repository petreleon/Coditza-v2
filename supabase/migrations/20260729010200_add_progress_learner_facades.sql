-- SUP-FUNCTIONS-001 (progress learner slice): server-only completion and
-- progress projections. Reads start from currently published curriculum so a
-- learner with no snapshot still receives the complete visible structure.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION private.list_learner_published_chapters(
  p_user_id uuid,
  p_module_id uuid DEFAULT NULL
)
RETURNS TABLE (
  module_id uuid,
  module_title text,
  module_position integer,
  chapter_id uuid,
  chapter_title text,
  chapter_position integer,
  theory_completed integer,
  theory_total integer,
  theory_percent numeric,
  exercise_completed integer,
  exercise_total integer,
  exercise_percent numeric,
  quiz_completed integer,
  quiz_total integer,
  quiz_percent numeric,
  overall_percent numeric,
  first_completed_at timestamptz,
  completed_at timestamptz,
  currently_completed boolean,
  snapshot_missing boolean
)
LANGUAGE sql
SECURITY INVOKER
SET search_path = ''
AS $list_learner_published_chapters$
  WITH published_chapters AS (
    SELECT
      module_entry.id AS module_id,
      module_entry.title AS module_title,
      module_entry.position AS module_position,
      chapter.id AS chapter_id,
      chapter.title AS chapter_title,
      chapter.position AS chapter_position
    FROM public.modules AS module_entry
    JOIN public.chapters AS chapter
      ON chapter.module_id = module_entry.id
    WHERE module_entry.status = 'published'::public.content_status
      AND chapter.status = 'published'::public.content_status
      AND (p_module_id IS NULL OR module_entry.id = p_module_id)
  ),
  theory_stats AS (
    SELECT
      chapter_entry.chapter_id,
      pg_catalog.count(theory_section.id)::integer AS theory_total,
      pg_catalog.count(completion_entry.user_id)::integer AS theory_completed
    FROM published_chapters AS chapter_entry
    LEFT JOIN public.theory_sections AS theory_section
      ON theory_section.chapter_id = chapter_entry.chapter_id
      AND theory_section.status = 'published'::public.content_status
    LEFT JOIN public.theory_section_completions AS completion_entry
      ON completion_entry.theory_section_id = theory_section.id
      AND completion_entry.user_id = p_user_id
    GROUP BY chapter_entry.chapter_id
  ),
  exercise_stats AS (
    SELECT
      chapter_entry.chapter_id,
      pg_catalog.count(exercise.id)::integer AS exercise_total,
      pg_catalog.count(exercise.id) FILTER (
        WHERE EXISTS (
          SELECT 1
          FROM public.exercise_attempts AS attempt
          WHERE attempt.user_id = p_user_id
            AND attempt.exercise_id = exercise.id
            AND attempt.is_correct
        )
      )::integer AS exercise_completed
    FROM published_chapters AS chapter_entry
    LEFT JOIN public.exercises AS exercise
      ON exercise.chapter_id = chapter_entry.chapter_id
      AND exercise.status = 'published'::public.content_status
      AND exercise.is_required
    GROUP BY chapter_entry.chapter_id
  ),
  quiz_stats AS (
    SELECT
      chapter_entry.chapter_id,
      pg_catalog.count(quiz.id)::integer AS quiz_total,
      pg_catalog.count(quiz.id) FILTER (
        WHERE EXISTS (
          SELECT 1
          FROM public.quiz_attempts AS attempt
          WHERE attempt.user_id = p_user_id
            AND attempt.quiz_id = quiz.id
            AND attempt.passed
        )
      )::integer AS quiz_completed
    FROM published_chapters AS chapter_entry
    LEFT JOIN public.quizzes AS quiz
      ON quiz.chapter_id = chapter_entry.chapter_id
      AND quiz.status = 'published'::public.content_status
      AND quiz.is_required
    GROUP BY chapter_entry.chapter_id
  ),
  calculated AS (
    SELECT
      chapter_entry.chapter_id,
      theory_stats.theory_total,
      theory_stats.theory_completed,
      exercise_stats.exercise_total,
      exercise_stats.exercise_completed,
      quiz_stats.quiz_total,
      quiz_stats.quiz_completed,
      CASE
        WHEN theory_stats.theory_total = 0 THEN 100::numeric
        ELSE pg_catalog.floor(
          (theory_stats.theory_completed::numeric * 10000)
          / theory_stats.theory_total
        ) / 100
      END AS theory_percent,
      CASE
        WHEN exercise_stats.exercise_total = 0 THEN 100::numeric
        ELSE pg_catalog.floor(
          (exercise_stats.exercise_completed::numeric * 10000)
          / exercise_stats.exercise_total
        ) / 100
      END AS exercise_percent,
      CASE
        WHEN quiz_stats.quiz_total = 0 THEN 100::numeric
        ELSE pg_catalog.floor(
          (quiz_stats.quiz_completed::numeric * 10000)
          / quiz_stats.quiz_total
        ) / 100
      END AS quiz_percent
    FROM published_chapters AS chapter_entry
    JOIN theory_stats
      ON theory_stats.chapter_id = chapter_entry.chapter_id
    JOIN exercise_stats
      ON exercise_stats.chapter_id = chapter_entry.chapter_id
    JOIN quiz_stats
      ON quiz_stats.chapter_id = chapter_entry.chapter_id
  ),
  derived AS (
    SELECT
      calculated.*,
      pg_catalog.floor(
        (
          calculated.theory_percent
          + calculated.exercise_percent
          + calculated.quiz_percent
        ) / 3
      ) AS overall_percent
    FROM calculated
  ),
  source_activity AS (
    SELECT
      chapter_entry.chapter_id,
      (
        EXISTS (
          SELECT 1
          FROM public.theory_section_completions AS completion_entry
          JOIN public.theory_sections AS theory_section
            ON theory_section.id = completion_entry.theory_section_id
          WHERE completion_entry.user_id = p_user_id
            AND theory_section.chapter_id = chapter_entry.chapter_id
        )
        OR EXISTS (
          SELECT 1
          FROM public.exercise_attempts AS attempt
          JOIN public.exercises AS exercise
            ON exercise.id = attempt.exercise_id
          WHERE attempt.user_id = p_user_id
            AND exercise.chapter_id = chapter_entry.chapter_id
        )
        OR EXISTS (
          SELECT 1
          FROM public.quiz_attempts AS attempt
          JOIN public.quizzes AS quiz
            ON quiz.id = attempt.quiz_id
          WHERE attempt.user_id = p_user_id
            AND quiz.chapter_id = chapter_entry.chapter_id
        )
      ) AS has_source_activity
    FROM published_chapters AS chapter_entry
  )
  SELECT
    chapter_entry.module_id,
    chapter_entry.module_title,
    chapter_entry.module_position,
    chapter_entry.chapter_id,
    chapter_entry.chapter_title,
    chapter_entry.chapter_position,
    derived.theory_completed,
    derived.theory_total,
    CASE
      WHEN progress.user_id IS NULL THEN derived.theory_percent
      ELSE progress.theory_percent
    END,
    derived.exercise_completed,
    derived.exercise_total,
    CASE
      WHEN progress.user_id IS NULL THEN derived.exercise_percent
      ELSE progress.exercise_percent
    END,
    derived.quiz_completed,
    derived.quiz_total,
    CASE
      WHEN progress.user_id IS NULL THEN derived.quiz_percent
      ELSE progress.quiz_percent
    END,
    CASE
      WHEN progress.user_id IS NULL THEN derived.overall_percent
      ELSE progress.overall_percent
    END,
    progress.first_completed_at,
    progress.completed_at,
    CASE
      WHEN progress.user_id IS NULL THEN
        (
          derived.theory_total + derived.exercise_total + derived.quiz_total
        ) > 0
          AND derived.theory_percent = 100
          AND derived.exercise_percent = 100
          AND derived.quiz_percent = 100
      ELSE progress.completed_at IS NOT NULL
    END,
    progress.user_id IS NULL
      AND source_activity.has_source_activity
  FROM published_chapters AS chapter_entry
  JOIN derived
    ON derived.chapter_id = chapter_entry.chapter_id
  JOIN source_activity
    ON source_activity.chapter_id = chapter_entry.chapter_id
  LEFT JOIN public.chapter_progress AS progress
    ON progress.user_id = p_user_id
    AND progress.chapter_id = chapter_entry.chapter_id
  ORDER BY chapter_entry.module_position, chapter_entry.module_id,
    chapter_entry.chapter_position, chapter_entry.chapter_id;
$list_learner_published_chapters$;

CREATE FUNCTION private.project_learner_chapter_progress(
  p_user_id uuid,
  p_chapter_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $project_learner_chapter_progress$
DECLARE
  v_result jsonb;
BEGIN
  SELECT pg_catalog.jsonb_build_object(
    'chapterId', chapter_entry.chapter_id::text,
    'theoryPercent', chapter_entry.theory_percent,
    'exercisePercent', chapter_entry.exercise_percent,
    'quizPercent', chapter_entry.quiz_percent,
    'overallPercent', chapter_entry.overall_percent,
    'firstCompletedAt', chapter_entry.first_completed_at,
    'completedAt', chapter_entry.completed_at
  )
  INTO v_result
  FROM private.list_learner_published_chapters(p_user_id) AS chapter_entry
  WHERE chapter_entry.chapter_id = p_chapter_id;

  IF v_result IS NULL THEN
    RAISE EXCEPTION 'The chapter is not effectively published.';
  END IF;
  RETURN v_result;
END;
$project_learner_chapter_progress$;

CREATE FUNCTION public.progress_set_theory_completion(
  p_actor_user_id uuid,
  p_theory_section_id uuid,
  p_completed boolean,
  p_request_id uuid
)
RETURNS TABLE (
  response_status integer,
  response_body jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $progress_set_theory_completion$
DECLARE
  v_changed boolean;
  v_chapter_id uuid;
  v_completed_at timestamptz;
  v_chapter_progress jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);
  IF p_completed IS NULL THEN
    RAISE EXCEPTION 'Theory completion must be explicitly true or false.';
  END IF;
  PERFORM private.assert_active_learning_actor(p_actor_user_id);

  v_changed := private.set_theory_completion(
    p_actor_user_id,
    p_theory_section_id,
    p_completed
  );
  SELECT theory_section.chapter_id
  INTO v_chapter_id
  FROM public.theory_sections AS theory_section
  WHERE theory_section.id = p_theory_section_id;

  IF p_completed THEN
    SELECT completion_entry.completed_at
    INTO v_completed_at
    FROM public.theory_section_completions AS completion_entry
    WHERE completion_entry.user_id = p_actor_user_id
      AND completion_entry.theory_section_id = p_theory_section_id;
    v_chapter_progress := private.project_learner_chapter_progress(
      p_actor_user_id,
      v_chapter_id
    );

    IF v_changed THEN
      PERFORM private.append_audit_event(
        'user',
        p_actor_user_id,
        'theory_completion_set',
        'theory_section',
        p_theory_section_id,
        ARRAY['status']::text[],
        '{"status":{"before":"not_started","after":"completed"}}'::jsonb,
        NULL,
        p_request_id
      );
    END IF;

    RETURN QUERY SELECT
      200,
      pg_catalog.jsonb_build_object(
        'sectionId', p_theory_section_id::text,
        'completedAt', v_completed_at,
        'chapterProgress', v_chapter_progress
      );
    RETURN;
  END IF;

  IF v_changed THEN
    PERFORM private.append_audit_event(
      'user',
      p_actor_user_id,
      'theory_completion_removed',
      'theory_section',
      p_theory_section_id,
      ARRAY['status']::text[],
      '{"status":{"before":"completed","after":"not_started"}}'::jsonb,
      NULL,
      p_request_id
    );
  END IF;

  RETURN QUERY SELECT 204, NULL::jsonb;
END;
$progress_set_theory_completion$;

CREATE FUNCTION public.progress_list_own_modules(
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
  v_has_more boolean;
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
    EXISTS (SELECT 1 FROM page_plus OFFSET p_limit),
    COALESCE(pg_catalog.bool_or(page.snapshot_missing), false)
  INTO v_items, v_has_more, v_snapshot_missing
  FROM page;

  IF v_snapshot_missing THEN
    RAISE LOG 'coditza_progress_snapshot_missing';
  END IF;

  IF v_has_more THEN
    SELECT pg_catalog.jsonb_build_object(
      'position', page.position,
      'moduleId', page.module_id::text
    )
    INTO v_next_cursor
    FROM page
    ORDER BY page.position DESC, page.module_id DESC
    LIMIT 1;
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'items', v_items,
    'nextCursor', v_next_cursor
  );
END;
$progress_list_own_modules$;

CREATE FUNCTION public.progress_get_own_module(
  p_actor_user_id uuid,
  p_module_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $progress_get_own_module$
DECLARE
  v_module_title text;
  v_chapters jsonb;
  v_total integer;
  v_completed integer;
  v_percent numeric;
  v_completed_at timestamptz;
  v_snapshot_missing boolean;
BEGIN
  PERFORM private.assert_active_learning_actor(p_actor_user_id);
  SELECT module_entry.title
  INTO v_module_title
  FROM public.modules AS module_entry
  WHERE module_entry.id = p_module_id
    AND module_entry.status = 'published'::public.content_status;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The progress module is absent.';
  END IF;

  SELECT
    COALESCE(
      pg_catalog.jsonb_agg(
        pg_catalog.jsonb_build_object(
          'chapterId', chapter_entry.chapter_id::text,
          'title', chapter_entry.chapter_title,
          'theory', pg_catalog.jsonb_build_object(
            'completed', chapter_entry.theory_completed,
            'total', chapter_entry.theory_total,
            'percent', chapter_entry.theory_percent
          ),
          'exercises', pg_catalog.jsonb_build_object(
            'completed', chapter_entry.exercise_completed,
            'total', chapter_entry.exercise_total,
            'percent', chapter_entry.exercise_percent
          ),
          'quizzes', pg_catalog.jsonb_build_object(
            'completed', chapter_entry.quiz_completed,
            'total', chapter_entry.quiz_total,
            'percent', chapter_entry.quiz_percent
          ),
          'overallPercent', chapter_entry.overall_percent,
          'firstCompletedAt', chapter_entry.first_completed_at,
          'completedAt', chapter_entry.completed_at
        )
        ORDER BY chapter_entry.chapter_position, chapter_entry.chapter_id
      ),
      '[]'::jsonb
    ),
    pg_catalog.count(chapter_entry.chapter_id)::integer,
    pg_catalog.count(chapter_entry.chapter_id) FILTER (
      WHERE chapter_entry.currently_completed
    )::integer,
    CASE
      WHEN pg_catalog.count(chapter_entry.chapter_id) = 0 THEN 0::numeric
      ELSE pg_catalog.floor(
        (
          pg_catalog.count(chapter_entry.chapter_id) FILTER (
            WHERE chapter_entry.currently_completed
          )::numeric * 10000
        ) / pg_catalog.count(chapter_entry.chapter_id)
      ) / 100
    END,
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
    END,
    COALESCE(pg_catalog.bool_or(chapter_entry.snapshot_missing), false)
  INTO v_chapters, v_total, v_completed, v_percent, v_completed_at,
    v_snapshot_missing
  FROM private.list_learner_published_chapters(
    p_actor_user_id,
    p_module_id
  ) AS chapter_entry;

  IF v_snapshot_missing THEN
    RAISE LOG 'coditza_progress_snapshot_missing';
  END IF;

  RETURN pg_catalog.jsonb_build_object(
    'moduleId', p_module_id::text,
    'title', v_module_title,
    'completedPublishedChapters', v_completed,
    'totalPublishedChapters', v_total,
    'percent', v_percent,
    'completedAt', v_completed_at,
    'chapters', v_chapters
  );
END;
$progress_get_own_module$;

REVOKE ALL ON FUNCTION private.list_learner_published_chapters(uuid, uuid)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.project_learner_chapter_progress(uuid, uuid)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

REVOKE ALL ON FUNCTION public.progress_set_theory_completion(
  uuid, uuid, boolean, uuid
) FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION public.progress_list_own_modules(
  uuid, integer, uuid, integer
) FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION public.progress_get_own_module(uuid, uuid)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

GRANT EXECUTE ON FUNCTION public.progress_set_theory_completion(
  uuid, uuid, boolean, uuid
) TO service_role;
GRANT EXECUTE ON FUNCTION public.progress_list_own_modules(
  uuid, integer, uuid, integer
) TO service_role;
GRANT EXECUTE ON FUNCTION public.progress_get_own_module(uuid, uuid)
  TO service_role;

RESET ROLE;

COMMIT;
