-- SUP-FUNCTIONS-001 (curriculum lifecycle slice): publish one validated draft
-- theory section. The named facade owns its exact lifecycle transition and
-- never accepts a generic resource kind, content input, or replay key. Its
-- outer-to-inner hierarchy locks serialize publication with all authoring and
-- learner source writes; affected chapter-progress locks are acquired only
-- afterward, in UUID order.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE FUNCTION public.curriculum_publish_theory_section(
  p_actor_user_id uuid,
  p_theory_section_id uuid,
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
AS $curriculum_publish_theory_section$
DECLARE
  v_chapter_id uuid;
  v_module_id uuid;
  v_locked_module_id uuid;
  v_locked_chapter_id uuid;
  v_module_status public.content_status;
  v_chapter_status public.content_status;
  v_theory_section_status public.content_status;
  v_actual_row_version integer;
  v_title text;
  v_body_markdown text;
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
    RAISE EXCEPTION 'A staff actor is required to publish a theory section.';
  END IF;
  IF p_theory_section_id IS NULL THEN
    RAISE EXCEPTION 'A draft theory section is required to publish.';
  END IF;
  IF p_expected_row_version IS NULL OR p_expected_row_version <= 0 THEN
    RAISE EXCEPTION 'A positive expected draft theory section version is required.';
  END IF;

  -- A held or demoted actor must be rejected before hierarchy, authored
  -- content, lifecycle, version, or progress-source state is read.
  PERFORM private.assert_active_staff_actor(p_actor_user_id);

  -- Discover the current hierarchy once, acquire the canonical
  -- module -> chapter -> theory-section locks, and prove both edges remained
  -- stable while their outer locks were taken.
  SELECT theory_section_entry.chapter_id
  INTO v_chapter_id
  FROM public.theory_sections AS theory_section_entry
  WHERE theory_section_entry.id = p_theory_section_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The theory section does not exist.';
  END IF;

  SELECT chapter_entry.module_id
  INTO v_module_id
  FROM public.chapters AS chapter_entry
  WHERE chapter_entry.id = v_chapter_id;

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

  SELECT chapter_entry.module_id, chapter_entry.status
  INTO v_locked_module_id, v_chapter_status
  FROM public.chapters AS chapter_entry
  WHERE chapter_entry.id = v_chapter_id
    AND chapter_entry.module_id = v_module_id
  FOR UPDATE;

  IF NOT FOUND OR v_locked_module_id IS DISTINCT FROM v_module_id THEN
    RAISE EXCEPTION 'The parent chapter hierarchy changed concurrently; retry.';
  END IF;

  SELECT
    theory_section_entry.chapter_id,
    theory_section_entry.status,
    theory_section_entry.row_version,
    theory_section_entry.title,
    theory_section_entry.body_markdown,
    theory_section_entry.position,
    theory_section_entry.estimated_minutes,
    theory_section_entry.published_at
  INTO
    v_locked_chapter_id,
    v_theory_section_status,
    v_actual_row_version,
    v_title,
    v_body_markdown,
    v_position,
    v_estimated_minutes,
    v_published_at
  FROM public.theory_sections AS theory_section_entry
  WHERE theory_section_entry.id = p_theory_section_id
    AND theory_section_entry.chapter_id = v_chapter_id
  FOR UPDATE;

  IF NOT FOUND OR v_locked_chapter_id IS DISTINCT FROM v_chapter_id THEN
    RAISE EXCEPTION 'The theory section hierarchy changed concurrently; retry.';
  END IF;
  IF v_module_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A theory section cannot publish under an archived module.';
  END IF;
  IF v_chapter_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'A theory section cannot publish under an archived chapter.';
  END IF;
  IF v_theory_section_status = 'archived'::public.content_status THEN
    RAISE EXCEPTION 'An archived theory section cannot be published.';
  END IF;

  -- Lifecycle idempotency is state based. It deliberately precedes the
  -- expected-version comparison so a server retry carrying its original draft
  -- version observes the current published result without a second write,
  -- audit event, or denominator recalculation.
  IF v_theory_section_status = 'published'::public.content_status THEN
    v_response_body := pg_catalog.jsonb_build_object(
      'id', p_theory_section_id::text,
      'rowVersion', v_actual_row_version
    );
    RETURN QUERY SELECT 200, v_response_body;
    RETURN;
  END IF;
  IF v_theory_section_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft theory sections can be published.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The draft theory section version is stale.';
  END IF;

  -- Validate the fully locked draft rather than relying only on table
  -- constraints. This keeps lifecycle readiness explicit and protects a later
  -- migration from silently publishing malformed legacy content.
  IF v_title IS NULL
    OR v_title IS DISTINCT FROM pg_catalog.btrim(v_title)
    OR pg_catalog.char_length(v_title) NOT BETWEEN 1 AND 160 THEN
    RAISE EXCEPTION 'Draft theory section title must be trimmed and between 1 and 160 characters to publish.';
  END IF;
  PERFORM private.assert_markdown_input(
    v_body_markdown,
    100000,
    'Draft theory section bodyMarkdown'
  );
  IF v_position IS NULL OR v_position < 0 THEN
    RAISE EXCEPTION 'Draft theory section position must be valid to publish.';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM public.theory_sections AS sibling_entry
    WHERE sibling_entry.chapter_id = v_chapter_id
      AND sibling_entry.position = v_position
      AND sibling_entry.id <> p_theory_section_id
  ) THEN
    RAISE EXCEPTION 'Draft theory section position is not unique within its chapter.';
  END IF;
  IF v_estimated_minutes IS NULL
    OR v_estimated_minutes NOT BETWEEN 1 AND 1440 THEN
    RAISE EXCEPTION 'Draft theory section estimatedMinutes must be between 1 and 1440 to publish.';
  END IF;
  IF v_published_at IS NOT NULL THEN
    RAISE EXCEPTION 'A draft theory section cannot already have a publication timestamp.';
  END IF;

  UPDATE public.theory_sections AS theory_section_entry
  SET
    status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp(),
    updated_by = p_actor_user_id
  WHERE theory_section_entry.id = p_theory_section_id
    AND theory_section_entry.chapter_id = v_chapter_id
    AND theory_section_entry.status = 'draft'::public.content_status
    AND theory_section_entry.row_version = p_expected_row_version
  RETURNING theory_section_entry.row_version
  INTO v_next_row_version;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The draft theory section version changed concurrently; retry.';
  END IF;

  -- A child under a draft ancestor remains outside the effective published
  -- denominator. Do not fabricate progress snapshots until both ancestors
  -- are published.
  IF v_module_status = 'published'::public.content_status
    AND v_chapter_status = 'published'::public.content_status THEN
    SELECT COALESCE(
      pg_catalog.array_agg(affected_user.user_id ORDER BY affected_user.user_id),
      ARRAY[]::uuid[]
    )
    INTO v_affected_user_ids
    FROM (
      SELECT progress_entry.user_id
      FROM public.chapter_progress AS progress_entry
      WHERE progress_entry.chapter_id = v_chapter_id

      UNION

      SELECT completion_entry.user_id
      FROM public.theory_section_completions AS completion_entry
      JOIN public.theory_sections AS theory_entry
        ON theory_entry.id = completion_entry.theory_section_id
      WHERE theory_entry.chapter_id = v_chapter_id

      UNION

      SELECT attempt_entry.user_id
      FROM public.exercise_attempts AS attempt_entry
      JOIN public.exercises AS exercise_entry
        ON exercise_entry.id = attempt_entry.exercise_id
      WHERE exercise_entry.chapter_id = v_chapter_id

      UNION

      SELECT attempt_entry.user_id
      FROM public.quiz_attempts AS attempt_entry
      JOIN public.quizzes AS quiz_entry
        ON quiz_entry.id = attempt_entry.quiz_id
      WHERE quiz_entry.chapter_id = v_chapter_id
    ) AS affected_user;

    -- Pre-acquire every distinct advisory key in the globally documented
    -- UUID order. The shared recalculator re-enters its own key safely and
    -- then performs the owner-guarded snapshot write.
    FOREACH v_affected_user_id IN ARRAY v_affected_user_ids LOOP
      PERFORM private.lock_chapter_progress(
        v_affected_user_id,
        v_chapter_id
      );
    END LOOP;
    FOREACH v_affected_user_id IN ARRAY v_affected_user_ids LOOP
      PERFORM private.recalculate_chapter_progress(
        v_affected_user_id,
        v_chapter_id
      );
    END LOOP;
  END IF;

  PERFORM private.append_audit_event(
    'user',
    p_actor_user_id,
    'theory_section_published',
    'theory_section',
    p_theory_section_id,
    ARRAY['status']::text[],
    '{"status":{"before":"draft","after":"published"}}'::jsonb,
    NULL,
    p_request_id
  );

  v_response_body := pg_catalog.jsonb_build_object(
    'id', p_theory_section_id::text,
    'rowVersion', v_next_row_version
  );
  RETURN QUERY SELECT 200, v_response_body;
END;
$curriculum_publish_theory_section$;

REVOKE ALL ON FUNCTION public.curriculum_publish_theory_section(
  uuid, uuid, integer, uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
GRANT EXECUTE ON FUNCTION public.curriculum_publish_theory_section(
  uuid, uuid, integer, uuid
)
  TO service_role;

RESET ROLE;

COMMIT;
