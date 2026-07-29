-- SUP-FUNCTIONS-001 (curriculum lifecycle slice): publish one validated draft
-- module. The named facade owns only the module root transition and activation
-- of progress for its already-published direct chapters; chapter/leaf
-- publication, reordering, archival, and hierarchy changes remain separate
-- workflows with their own bounded contracts.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.curriculum_publish_module(
  p_actor_user_id uuid,
  p_module_id uuid,
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
AS $curriculum_publish_module$
DECLARE
  v_module_status public.content_status;
  v_actual_row_version integer;
  v_slug text;
  v_title text;
  v_description_markdown text;
  v_position integer;
  v_published_at timestamptz;
  v_next_row_version integer;
  v_affected_pair record;
  v_response_body jsonb;
BEGIN
  PERFORM private.assert_server_request_id(p_request_id);

  IF p_actor_user_id IS NULL THEN
    RAISE EXCEPTION 'A staff actor is required to publish a module.';
  END IF;
  IF p_module_id IS NULL THEN
    RAISE EXCEPTION 'A draft module is required to publish.';
  END IF;
  IF p_expected_row_version IS NULL OR p_expected_row_version <= 0 THEN
    RAISE EXCEPTION 'A positive expected draft module version is required.';
  END IF;

  -- A held or demoted actor must fail before module-root, chapter-readiness,
  -- lifecycle, version, or learner-progress access.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  SELECT
    module_entry.status,
    module_entry.row_version,
    module_entry.slug,
    module_entry.title,
    module_entry.description_markdown,
    module_entry.position,
    module_entry.published_at
  INTO
    v_module_status,
    v_actual_row_version,
    v_slug,
    v_title,
    v_description_markdown,
    v_position,
    v_published_at
  FROM public.modules AS module_entry
  WHERE module_entry.id = p_module_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The module does not exist.';
  END IF;
  IF v_module_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'An archived module cannot be published.';
  END IF;

  -- State-based retry deliberately precedes the expected-version comparison:
  -- a caller can repeat its original draft request without causing a second
  -- root write, audit row, chapter scan, progress recalculation, or replay
  -- record.
  IF v_module_status = 'published'::public.content_status THEN
    v_response_body := pg_catalog.jsonb_build_object(
      'id', p_module_id::text,
      'rowVersion', v_actual_row_version
    );
    RETURN QUERY SELECT 200, v_response_body;
    RETURN;
  END IF;
  IF v_module_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft modules can be published.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The draft module version is stale.';
  END IF;

  -- Revalidate the fully locked root rather than relying only on table
  -- constraints. This keeps lifecycle readiness explicit and protects a later
  -- migration from silently publishing malformed legacy content.
  IF v_slug IS NULL OR NOT private.is_valid_slug(v_slug) THEN
    RAISE EXCEPTION 'Draft module slug is invalid to publish.';
  END IF;
  IF v_title IS NULL
    OR v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
    OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
    RAISE EXCEPTION 'Draft module title must be trimmed and between 1 and 160 characters to publish.';
  END IF;
  PERFORM private.assert_markdown_input(
    v_description_markdown,
    10000,
    'Draft module descriptionMarkdown'
  );
  IF v_position IS NULL OR v_position < 0 THEN
    RAISE EXCEPTION 'Draft module position must be valid to publish.';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.modules AS sibling_entry
    WHERE sibling_entry.position = v_position
      AND sibling_entry.id <> p_module_id
  ) THEN
    RAISE EXCEPTION 'Draft module position is not unique.';
  END IF;
  IF v_published_at IS NOT NULL THEN
    RAISE EXCEPTION 'A draft module cannot already have a publication timestamp.';
  END IF;

  -- The module lock is acquired first by all current chapter/leaf lifecycle
  -- and authoring facades. It serializes this direct-child readiness scan with
  -- those writers without requiring every child to be independently locked or
  -- revalidated here.
  IF NOT EXISTS (
    SELECT 1
    FROM public.chapters AS chapter_entry
    WHERE chapter_entry.module_id = p_module_id
      AND chapter_entry.status = 'published'::public.content_status
  ) THEN
    RAISE EXCEPTION 'A publishable module needs at least one published chapter.';
  END IF;

  -- The lifecycle and timestamp triggers own the exact row-version and
  -- updated-at changes. Do not rewrite chapters, descendants, position, or
  -- immutable creation fields in this lifecycle facade.
  UPDATE public.modules AS module_entry
  SET
    status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp(),
    updated_by = p_actor_user_id
  WHERE module_entry.id = p_module_id
    AND module_entry.status = 'draft'::public.content_status
    AND module_entry.row_version = p_expected_row_version
  RETURNING module_entry.row_version
  INTO v_next_row_version;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The draft module version changed concurrently; retry.';
  END IF;

  -- Module publication activates every already-published direct chapter. Use
  -- the full four-source union for each such chapter, without filtering
  -- historical source rows by current leaf status. Acquire every affected
  -- advisory progress key in deterministic order before writing any snapshot.
  FOR v_affected_pair IN
    SELECT affected_user.chapter_id, affected_user.user_id
    FROM (
      SELECT progress_entry.chapter_id, progress_entry.user_id
      FROM public.chapter_progress AS progress_entry
      JOIN public.chapters AS chapter_entry
        ON chapter_entry.id = progress_entry.chapter_id
      WHERE chapter_entry.module_id = p_module_id
        AND chapter_entry.status = 'published'::public.content_status

      UNION

      SELECT theory_entry.chapter_id, completion_entry.user_id
      FROM public.theory_section_completions AS completion_entry
      JOIN public.theory_sections AS theory_entry
        ON theory_entry.id = completion_entry.theory_section_id
      JOIN public.chapters AS chapter_entry
        ON chapter_entry.id = theory_entry.chapter_id
      WHERE chapter_entry.module_id = p_module_id
        AND chapter_entry.status = 'published'::public.content_status

      UNION

      SELECT exercise_entry.chapter_id, attempt_entry.user_id
      FROM public.exercise_attempts AS attempt_entry
      JOIN public.exercises AS exercise_entry
        ON exercise_entry.id = attempt_entry.exercise_id
      JOIN public.chapters AS chapter_entry
        ON chapter_entry.id = exercise_entry.chapter_id
      WHERE chapter_entry.module_id = p_module_id
        AND chapter_entry.status = 'published'::public.content_status

      UNION

      SELECT quiz_entry.chapter_id, attempt_entry.user_id
      FROM public.quiz_attempts AS attempt_entry
      JOIN public.quizzes AS quiz_entry
        ON quiz_entry.id = attempt_entry.quiz_id
      JOIN public.chapters AS chapter_entry
        ON chapter_entry.id = quiz_entry.chapter_id
      WHERE chapter_entry.module_id = p_module_id
        AND chapter_entry.status = 'published'::public.content_status
    ) AS affected_user
    ORDER BY affected_user.user_id, affected_user.chapter_id
  LOOP
    PERFORM private.lock_chapter_progress(
      v_affected_pair.user_id,
      v_affected_pair.chapter_id
    );
  END LOOP;

  FOR v_affected_pair IN
    SELECT affected_user.chapter_id, affected_user.user_id
    FROM (
      SELECT progress_entry.chapter_id, progress_entry.user_id
      FROM public.chapter_progress AS progress_entry
      JOIN public.chapters AS chapter_entry
        ON chapter_entry.id = progress_entry.chapter_id
      WHERE chapter_entry.module_id = p_module_id
        AND chapter_entry.status = 'published'::public.content_status

      UNION

      SELECT theory_entry.chapter_id, completion_entry.user_id
      FROM public.theory_section_completions AS completion_entry
      JOIN public.theory_sections AS theory_entry
        ON theory_entry.id = completion_entry.theory_section_id
      JOIN public.chapters AS chapter_entry
        ON chapter_entry.id = theory_entry.chapter_id
      WHERE chapter_entry.module_id = p_module_id
        AND chapter_entry.status = 'published'::public.content_status

      UNION

      SELECT exercise_entry.chapter_id, attempt_entry.user_id
      FROM public.exercise_attempts AS attempt_entry
      JOIN public.exercises AS exercise_entry
        ON exercise_entry.id = attempt_entry.exercise_id
      JOIN public.chapters AS chapter_entry
        ON chapter_entry.id = exercise_entry.chapter_id
      WHERE chapter_entry.module_id = p_module_id
        AND chapter_entry.status = 'published'::public.content_status

      UNION

      SELECT quiz_entry.chapter_id, attempt_entry.user_id
      FROM public.quiz_attempts AS attempt_entry
      JOIN public.quizzes AS quiz_entry
        ON quiz_entry.id = attempt_entry.quiz_id
      JOIN public.chapters AS chapter_entry
        ON chapter_entry.id = quiz_entry.chapter_id
      WHERE chapter_entry.module_id = p_module_id
        AND chapter_entry.status = 'published'::public.content_status
    ) AS affected_user
    ORDER BY affected_user.user_id, affected_user.chapter_id
  LOOP
    PERFORM private.recalculate_chapter_progress(
      v_affected_pair.user_id,
      v_affected_pair.chapter_id
    );
  END LOOP;

  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'module_published',
    'module',
    p_module_id,
    ARRAY['status']::text[],
    '{"status":{"before":"draft","after":"published"}}'::jsonb,
    NULL,
    p_request_id
  );

  v_response_body := pg_catalog.jsonb_build_object(
    'id', p_module_id::text,
    'rowVersion', v_next_row_version
  );
  RETURN QUERY SELECT 200, v_response_body;
END;
$curriculum_publish_module$;

REVOKE ALL ON FUNCTION public.curriculum_publish_module(
  uuid, uuid, integer, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.curriculum_publish_module(
  uuid, uuid, integer, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
