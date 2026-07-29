-- SUP-FUNCTIONS-001 (curriculum lifecycle slice): publish one validated draft
-- chapter. The named facade owns only the chapter root transition. The locked
-- chapter is the outer serialization point for its leaf lifecycle writers;
-- module publication, leaf mutation, reordering, and archival remain separate
-- workflows with their own bounded contracts.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.curriculum_publish_chapter(
  p_actor_user_id uuid,
  p_chapter_id uuid,
  p_expected_row_version integer,
  p_request_id uuid
)
RETURNS TABLE (
  response_status integer,
  response_body jsonb
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $curriculum_publish_chapter$
DECLARE
  v_module_id uuid;
  v_locked_module_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_actual_row_version integer;
  v_slug text;
  v_title text;
  v_summary_markdown text;
  v_position integer;
  v_estimated_minutes integer;
  v_published_at timestamptz;
  v_next_row_version integer;
  v_affected_user_ids uuid[];
  v_affected_user_id uuid;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to publish a chapter.';
  END IF;
  IF p_chapter_id IS NULL THEN
    RAISE EXCEPTION 'A draft chapter is required to publish.';
  END IF;
  IF p_expected_row_version IS NULL OR p_expected_row_version <= 0 THEN
    RAISE EXCEPTION 'A positive expected draft chapter version is required.';
  END IF;

  -- A held or demoted actor must fail before hierarchy, authored content,
  -- lifecycle, descendant-readiness, version, or learner-progress access.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  -- Discover the parent once, then take the canonical module -> chapter locks
  -- and prove the child still belongs to that locked module.
  SELECT chapter_entry.module_id
  INTO v_module_id
  FROM public.chapters AS chapter_entry
  WHERE chapter_entry.id = p_chapter_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The chapter does not exist.';
  END IF;

  SELECT module_entry.status
  INTO v_module_status
  FROM public.modules AS module_entry
  WHERE module_entry.id = v_module_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The parent module no longer exists.';
  END IF;

  SELECT
    chapter_entry.module_id,
    chapter_entry.status,
    chapter_entry.row_version,
    chapter_entry.slug,
    chapter_entry.title,
    chapter_entry.summary_markdown,
    chapter_entry.position,
    chapter_entry.estimated_minutes,
    chapter_entry.published_at
  INTO
    v_locked_module_id,
    v_chapter_status,
    v_actual_row_version,
    v_slug,
    v_title,
    v_summary_markdown,
    v_position,
    v_estimated_minutes,
    v_published_at
  FROM public.chapters AS chapter_entry
  WHERE chapter_entry.id = p_chapter_id
    AND chapter_entry.module_id = v_module_id
  FOR UPDATE;

  IF NOT FOUND OR v_locked_module_id IS DISTINCT FROM v_module_id THEN
    RAISE EXCEPTION 'The chapter hierarchy changed concurrently; retry.';
  END IF;
  IF v_module_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A chapter cannot publish under an archived module.';
  END IF;
  IF v_chapter_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'An archived chapter cannot be published.';
  END IF;

  -- State-based retry deliberately precedes the expected-version comparison:
  -- a caller can repeat its original draft request without causing a second
  -- root write, audit row, descendant scan, progress recalculation, or replay
  -- record.
  IF v_chapter_status = 'published'::public.content_status THEN
    v_response_body := pg_catalog.jsonb_build_object(
      'id', p_chapter_id::text,
      'rowVersion', v_actual_row_version
    );
    RETURN QUERY SELECT 200, v_response_body;
    RETURN;
  END IF;
  IF v_chapter_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft chapters can be published.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The draft chapter version is stale.';
  END IF;

  -- Revalidate the fully locked root rather than relying only on table
  -- constraints. This keeps lifecycle readiness explicit and protects a later
  -- migration from silently publishing malformed legacy content.
  IF v_slug IS NULL OR NOT private.is_valid_slug(v_slug) THEN
    RAISE EXCEPTION 'Draft chapter slug is invalid to publish.';
  END IF;
  IF v_title IS NULL
    OR v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
    OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
    RAISE EXCEPTION 'Draft chapter title must be trimmed and between 1 and 160 characters to publish.';
  END IF;
  PERFORM private.assert_markdown_input(
    v_summary_markdown,
    5000,
    'Draft chapter summaryMarkdown'
  );
  IF v_position IS NULL OR v_position < 0 THEN
    RAISE EXCEPTION 'Draft chapter position must be valid to publish.';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.chapters AS sibling_entry
    WHERE sibling_entry.module_id = v_module_id
      AND sibling_entry.position = v_position
      AND sibling_entry.id <> p_chapter_id
  ) THEN
    RAISE EXCEPTION 'Draft chapter position is not unique within its module.';
  END IF;
  IF v_estimated_minutes IS NULL
    OR v_estimated_minutes NOT BETWEEN 1 AND 1440 THEN
    RAISE EXCEPTION 'Draft chapter estimatedMinutes must be between 1 and 1440 to publish.';
  END IF;
  IF v_published_at IS NOT NULL THEN
    RAISE EXCEPTION 'A draft chapter cannot already have a publication timestamp.';
  END IF;

  -- The chapter lock is acquired by every existing leaf authoring/lifecycle
  -- facade before it locks a theory/exercise/quiz root. It therefore
  -- serializes this readiness scan with those child writers without inventing
  -- a second child-lock protocol or revalidating immutable published trees.
  IF NOT EXISTS (
    SELECT 1
    FROM public.theory_sections AS theory_entry
    WHERE theory_entry.chapter_id = p_chapter_id
      AND theory_entry.status = 'published'::public.content_status
  ) THEN
    RAISE EXCEPTION 'A publishable chapter needs at least one published theory section.';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.exercises AS exercise_entry
    WHERE exercise_entry.chapter_id = p_chapter_id
      AND exercise_entry.status = 'published'::public.content_status
  ) THEN
    RAISE EXCEPTION 'A publishable chapter needs at least one published exercise.';
  END IF;
  IF NOT EXISTS (
    SELECT 1
    FROM public.quizzes AS quiz_entry
    WHERE quiz_entry.chapter_id = p_chapter_id
      AND quiz_entry.status = 'published'::public.content_status
  ) THEN
    RAISE EXCEPTION 'A publishable chapter needs at least one published quiz.';
  END IF;

  -- The lifecycle and timestamp triggers own the exact row-version and
  -- updated-at changes. Do not rewrite children, hierarchy, position, or
  -- immutable creation fields in this lifecycle facade.
  UPDATE public.chapters AS chapter_entry
  SET
    status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp(),
    updated_by = p_actor_user_id
  WHERE chapter_entry.id = p_chapter_id
    AND chapter_entry.module_id = v_module_id
    AND chapter_entry.status = 'draft'::public.content_status
    AND chapter_entry.row_version = p_expected_row_version
  RETURNING chapter_entry.row_version
  INTO v_next_row_version;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The draft chapter version changed concurrently; retry.';
  END IF;

  -- A published chapter under a draft module is not learner-visible. Avoid
  -- reading any progress source or creating/changing a snapshot until the
  -- locked module is published.
  IF v_module_status = 'published'::public.content_status THEN
    SELECT COALESCE(
      pg_catalog.array_agg(affected_user.user_id ORDER BY affected_user.user_id),
      ARRAY[]::uuid[]
    )
    INTO v_affected_user_ids
    FROM (
      SELECT progress_entry.user_id
      FROM public.chapter_progress AS progress_entry
      WHERE progress_entry.chapter_id = p_chapter_id

      UNION

      SELECT completion_entry.user_id
      FROM public.theory_section_completions AS completion_entry
      JOIN public.theory_sections AS theory_entry
        ON theory_entry.id = completion_entry.theory_section_id
      WHERE theory_entry.chapter_id = p_chapter_id

      UNION

      SELECT attempt_entry.user_id
      FROM public.exercise_attempts AS attempt_entry
      JOIN public.exercises AS exercise_entry
        ON exercise_entry.id = attempt_entry.exercise_id
      WHERE exercise_entry.chapter_id = p_chapter_id

      UNION

      SELECT attempt_entry.user_id
      FROM public.quiz_attempts AS attempt_entry
      JOIN public.quizzes AS quiz_entry
        ON quiz_entry.id = attempt_entry.quiz_id
      WHERE quiz_entry.chapter_id = p_chapter_id
    ) AS affected_user;

    -- Acquire every shared advisory key in the documented UUID order before
    -- the recalculator takes its per-user snapshot lock and write.
    FOREACH v_affected_user_id IN ARRAY v_affected_user_ids LOOP
      PERFORM private.lock_chapter_progress(
        v_affected_user_id,
        p_chapter_id
      );
    END LOOP;
    FOREACH v_affected_user_id IN ARRAY v_affected_user_ids LOOP
      PERFORM private.recalculate_chapter_progress(
        v_affected_user_id,
        p_chapter_id
      );
    END LOOP;
  END IF;

  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'chapter_published',
    'chapter',
    p_chapter_id,
    ARRAY['status']::text[],
    '{"status":{"before":"draft","after":"published"}}'::jsonb,
    NULL,
    p_request_id
  );

  v_response_body := pg_catalog.jsonb_build_object(
    'id', p_chapter_id::text,
    'rowVersion', v_next_row_version
  );
  RETURN QUERY SELECT 200, v_response_body;
END;
$curriculum_publish_chapter$;

REVOKE ALL ON FUNCTION public.curriculum_publish_chapter(
  uuid, uuid, integer, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.curriculum_publish_chapter(
  uuid, uuid, integer, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
