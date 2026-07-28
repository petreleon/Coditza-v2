BEGIN;

-- This suite owns no persistent fixture. Every synthetic Auth user, curriculum
-- row, attempt, operation record, and audit event is rolled back at the end.
GRANT USAGE ON SCHEMA extensions TO coditza_owner;

SELECT extensions.plan(28);

SELECT extensions.ok(
  pg_catalog.to_regclass('public.theory_section_completions') IS NOT NULL
    AND pg_catalog.to_regclass('public.exercise_attempts') IS NOT NULL
    AND pg_catalog.to_regclass('public.quiz_attempts') IS NOT NULL
    AND pg_catalog.to_regclass('public.quiz_attempt_answers') IS NOT NULL
    AND pg_catalog.to_regclass('public.chapter_progress') IS NOT NULL
    AND pg_catalog.to_regclass('private.idempotency_records') IS NOT NULL
    AND pg_catalog.to_regclass('private.audit_events') IS NOT NULL,
  'all approved learning, operation, and audit relations exist'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
      = ARRAY['user_id', 'theory_section_id', 'completed_at']::text[]
    FROM pg_catalog.pg_attribute AS attribute_entry
    WHERE attribute_entry.attrelid = 'public.theory_section_completions'::pg_catalog.regclass
      AND attribute_entry.attnum > 0
      AND NOT attribute_entry.attisdropped
  )
    AND (
      SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
        = ARRAY[
          'id',
          'user_id',
          'exercise_id',
          'exercise_definition_version',
          'answer',
          'is_correct',
          'points_earned',
          'points_possible',
          'submitted_at',
          'created_at'
        ]::text[]
      FROM pg_catalog.pg_attribute AS attribute_entry
      WHERE attribute_entry.attrelid = 'public.exercise_attempts'::pg_catalog.regclass
        AND attribute_entry.attnum > 0
        AND NOT attribute_entry.attisdropped
    )
    AND (
      SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
        = ARRAY[
          'id',
          'user_id',
          'quiz_id',
          'quiz_definition_version',
          'attempt_number',
          'status',
          'started_at',
          'expires_at',
          'submitted_at',
          'points_earned',
          'points_possible',
          'score_percent',
          'passed',
          'created_at',
          'updated_at'
        ]::text[]
      FROM pg_catalog.pg_attribute AS attribute_entry
      WHERE attribute_entry.attrelid = 'public.quiz_attempts'::pg_catalog.regclass
        AND attribute_entry.attnum > 0
        AND NOT attribute_entry.attisdropped
    )
    AND (
      SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
        = ARRAY[
          'attempt_id',
          'question_id',
          'answer',
          'answered_at',
          'is_correct',
          'points_earned'
        ]::text[]
      FROM pg_catalog.pg_attribute AS attribute_entry
      WHERE attribute_entry.attrelid = 'public.quiz_attempt_answers'::pg_catalog.regclass
        AND attribute_entry.attnum > 0
        AND NOT attribute_entry.attisdropped
    ),
  'learner completion and attempt relations use only their approved columns'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
      = ARRAY[
        'user_id',
        'chapter_id',
        'theory_percent',
        'exercise_percent',
        'quiz_percent',
        'overall_percent',
        'first_completed_at',
        'completed_at',
        'updated_at'
      ]::text[]
    FROM pg_catalog.pg_attribute AS attribute_entry
    WHERE attribute_entry.attrelid = 'public.chapter_progress'::pg_catalog.regclass
      AND attribute_entry.attnum > 0
      AND NOT attribute_entry.attisdropped
  )
    AND (
      SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
        = ARRAY[
          'user_id',
          'operation',
          'idempotency_key',
          'canonicalization_version',
          'request_hash',
          'result_resource_id',
          'response_status',
          'response_location',
          'response_body',
          'created_at',
          'expires_at'
        ]::text[]
      FROM pg_catalog.pg_attribute AS attribute_entry
      WHERE attribute_entry.attrelid = 'private.idempotency_records'::pg_catalog.regclass
        AND attribute_entry.attnum > 0
        AND NOT attribute_entry.attisdropped
    )
    AND (
      SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
        = ARRAY[
          'id',
          'actor_kind',
          'actor_user_id',
          'action',
          'entity_type',
          'entity_id',
          'changed_fields',
          'reason',
          'request_id',
          'created_at',
          'change_summary'
        ]::text[]
      FROM pg_catalog.pg_attribute AS attribute_entry
      WHERE attribute_entry.attrelid = 'private.audit_events'::pg_catalog.regclass
        AND attribute_entry.attnum > 0
        AND NOT attribute_entry.attisdropped
    ),
  'progress, idempotency, and audit relations use only their approved columns'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 7
      AND pg_catalog.bool_and(
        relation_entry.relowner = 'coditza_owner'::pg_catalog.regrole
      )
    FROM pg_catalog.pg_class AS relation_entry
    WHERE relation_entry.oid IN (
      'public.theory_section_completions'::pg_catalog.regclass,
      'public.exercise_attempts'::pg_catalog.regclass,
      'public.quiz_attempts'::pg_catalog.regclass,
      'public.quiz_attempt_answers'::pg_catalog.regclass,
      'public.chapter_progress'::pg_catalog.regclass,
      'private.idempotency_records'::pg_catalog.regclass,
      'private.audit_events'::pg_catalog.regclass
    )
  ),
  'all learning and operations relations are owned by coditza_owner'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 5
      AND pg_catalog.bool_and(relation_entry.relrowsecurity)
      AND NOT pg_catalog.bool_or(relation_entry.relforcerowsecurity)
    FROM pg_catalog.pg_class AS relation_entry
    WHERE relation_entry.oid IN (
      'public.theory_section_completions'::pg_catalog.regclass,
      'public.exercise_attempts'::pg_catalog.regclass,
      'public.quiz_attempts'::pg_catalog.regclass,
      'public.quiz_attempt_answers'::pg_catalog.regclass,
      'public.chapter_progress'::pg_catalog.regclass
    )
  )
    AND (
      SELECT pg_catalog.count(*) = 2
        AND pg_catalog.bool_and(relation_entry.relrowsecurity)
        AND NOT pg_catalog.bool_or(relation_entry.relforcerowsecurity)
      FROM pg_catalog.pg_class AS relation_entry
      WHERE relation_entry.oid IN (
        'private.idempotency_records'::pg_catalog.regclass,
        'private.audit_events'::pg_catalog.regclass
      )
    )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_policy AS policy_entry
      WHERE policy_entry.polrelid IN (
        'public.theory_section_completions'::pg_catalog.regclass,
        'public.exercise_attempts'::pg_catalog.regclass,
        'public.quiz_attempts'::pg_catalog.regclass,
        'public.quiz_attempt_answers'::pg_catalog.regclass,
        'public.chapter_progress'::pg_catalog.regclass,
        'private.idempotency_records'::pg_catalog.regclass,
        'private.audit_events'::pg_catalog.regclass
      )
    ),
  'learning and operations tables use RLS defense in depth without policies'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 12
      AND pg_catalog.count(*) FILTER (
        WHERE constraint_entry.confdeltype IN ('c', 'r')
      ) = 11
      AND pg_catalog.count(*) FILTER (
        WHERE constraint_entry.confdeltype = 'n'
      ) = 1
    FROM pg_catalog.pg_constraint AS constraint_entry
    WHERE constraint_entry.contype = 'f'
      AND constraint_entry.conrelid IN (
        'public.theory_section_completions'::pg_catalog.regclass,
        'public.exercise_attempts'::pg_catalog.regclass,
        'public.quiz_attempts'::pg_catalog.regclass,
        'public.quiz_attempt_answers'::pg_catalog.regclass,
        'public.chapter_progress'::pg_catalog.regclass,
        'private.idempotency_records'::pg_catalog.regclass,
        'private.audit_events'::pg_catalog.regclass
      )
  )
    AND EXISTS (
      SELECT 1
      FROM pg_catalog.pg_constraint AS constraint_entry
      WHERE constraint_entry.conname = 'quiz_attempts_user_quiz_attempt_number_key'
        AND constraint_entry.conrelid = 'public.quiz_attempts'::pg_catalog.regclass
    ),
  'approved cascade/restrict foreign keys and unique quiz attempt numbers exist'
);

SELECT extensions.ok(
  pg_catalog.to_regclass('public.quiz_attempts_one_active_per_user_quiz_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.quiz_attempts_expiry_worker_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.exercise_attempts_user_exercise_submitted_id_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.chapter_progress_chapter_user_idx') IS NOT NULL
    AND pg_catalog.to_regclass('private.idempotency_records_expires_at_id_idx') IS NOT NULL
    AND pg_catalog.to_regclass('private.audit_events_created_at_id_idx') IS NOT NULL,
  'approved attempt, progress, idempotency, and audit indexes exist'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    CROSS JOIN (
      VALUES
        ('public.theory_section_completions'::pg_catalog.regclass),
        ('public.exercise_attempts'::pg_catalog.regclass),
        ('public.quiz_attempts'::pg_catalog.regclass),
        ('public.quiz_attempt_answers'::pg_catalog.regclass),
        ('public.chapter_progress'::pg_catalog.regclass),
        ('private.idempotency_records'::pg_catalog.regclass),
        ('private.audit_events'::pg_catalog.regclass)
    ) AS learning_table(table_oid)
    WHERE pg_catalog.has_table_privilege(runtime_role.rolname, learning_table.table_oid, 'SELECT')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, learning_table.table_oid, 'INSERT')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, learning_table.table_oid, 'UPDATE')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, learning_table.table_oid, 'DELETE')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, learning_table.table_oid, 'TRUNCATE')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, learning_table.table_oid, 'REFERENCES')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, learning_table.table_oid, 'TRIGGER')
  )
    AND NOT EXISTS (
      SELECT 1
      FROM (
        VALUES (
          'private.set_theory_completion(uuid,uuid,boolean)'::pg_catalog.regprocedure
        ), (
          'private.submit_scalar_exercise_attempt(uuid,uuid,jsonb,uuid,integer,bytea)'::pg_catalog.regprocedure
        ), (
          'private.start_quiz_attempt(uuid,uuid,uuid,integer,bytea)'::pg_catalog.regprocedure
        ), (
          'private.save_quiz_answer(uuid,uuid,uuid,jsonb)'::pg_catalog.regprocedure
        ), (
          'private.submit_quiz_attempt(uuid,uuid)'::pg_catalog.regprocedure
        ), (
          'private.recalculate_chapter_progress(uuid,uuid)'::pg_catalog.regprocedure
        ), (
          'private.append_audit_event(text,uuid,text,text,uuid,text[],jsonb,text,uuid)'::pg_catalog.regprocedure
        )
      ) AS helper(procedure_oid)
      CROSS JOIN (
        VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
      ) AS runtime_role(rolname)
      WHERE pg_catalog.has_function_privilege(
        runtime_role.rolname,
        helper.procedure_oid,
        'EXECUTE'
      )
    ),
  'runtime roles have no direct table or private helper access'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 7
      AND pg_catalog.bool_and(
        procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
        AND NOT procedure_entry.prosecdef
        AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
      )
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid IN (
      'private.set_theory_completion(uuid,uuid,boolean)'::pg_catalog.regprocedure,
      'private.submit_scalar_exercise_attempt(uuid,uuid,jsonb,uuid,integer,bytea)'::pg_catalog.regprocedure,
      'private.start_quiz_attempt(uuid,uuid,uuid,integer,bytea)'::pg_catalog.regprocedure,
      'private.save_quiz_answer(uuid,uuid,uuid,jsonb)'::pg_catalog.regprocedure,
      'private.submit_quiz_attempt(uuid,uuid)'::pg_catalog.regprocedure,
      'private.recalculate_chapter_progress(uuid,uuid)'::pg_catalog.regprocedure,
      'private.append_audit_event(text,uuid,text,text,uuid,text[],jsonb,text,uuid)'::pg_catalog.regprocedure
    )
  ),
  'workflow helpers are owner-controlled SECURITY INVOKER functions with empty paths'
);

INSERT INTO auth.users (
  id,
  aud,
  role,
  email,
  raw_app_meta_data,
  raw_user_meta_data,
  created_at,
  updated_at
)
VALUES
  (
    'a3000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'learning-a@coditza.invalid',
    '{}'::jsonb,
    '{"displayName":"Learner A"}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  ),
  (
    'a3000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'learning-b@coditza.invalid',
    '{}'::jsonb,
    '{"displayName":"Learner B"}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  ),
  (
    'a3000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'learning-delete@coditza.invalid',
    '{}'::jsonb,
    '{"displayName":"Delete Learner"}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  ),
  (
    'a3000000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'learning-hold@coditza.invalid',
    '{}'::jsonb,
    '{"displayName":"Held Learner"}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  );

SET LOCAL ROLE coditza_owner;

INSERT INTO public.modules (
  id,
  slug,
  title,
  description_markdown,
  position
)
VALUES (
  'a3100000-0000-0000-0000-000000000001',
  'learning-records-module',
  'Learning records module',
  'Synthetic learning records module.',
  700
);

INSERT INTO public.chapters (
  id,
  module_id,
  slug,
  title,
  summary_markdown,
  position,
  estimated_minutes
)
VALUES
  (
    'a3200000-0000-0000-0000-000000000001',
    'a3100000-0000-0000-0000-000000000001',
    'learning-records-chapter',
    'Learning records chapter',
    'Synthetic learning records chapter.',
    0,
    30
  ),
  (
    'a3200000-0000-0000-0000-000000000002',
    'a3100000-0000-0000-0000-000000000001',
    'empty-learning-chapter',
    'Empty learning chapter',
    'Synthetic empty chapter.',
    1,
    30
  );

INSERT INTO public.theory_sections (
  id,
  chapter_id,
  title,
  body_markdown,
  position,
  estimated_minutes
)
VALUES
  (
    'a3300000-0000-0000-0000-000000000001',
    'a3200000-0000-0000-0000-000000000001',
    'Published theory',
    'Synthetic published theory.',
    0,
    5
  ),
  (
    'a3300000-0000-0000-0000-000000000002',
    'a3200000-0000-0000-0000-000000000001',
    'Draft theory',
    'Synthetic draft theory.',
    1,
    5
  ),
  (
    'a3300000-0000-0000-0000-000000000003',
    'a3200000-0000-0000-0000-000000000001',
    'Later theory',
    'Synthetic later theory.',
    2,
    5
  );

INSERT INTO public.exercises (
  id,
  chapter_id,
  title,
  prompt_markdown,
  exercise_type,
  position,
  points,
  is_required
)
VALUES
  (
    'a3400000-0000-0000-0000-000000000001',
    'a3200000-0000-0000-0000-000000000001',
    'Short-text exercise',
    'Type the approved answer.',
    'short_text',
    0,
    7,
    true
  ),
  (
    'a3400000-0000-0000-0000-000000000002',
    'a3200000-0000-0000-0000-000000000001',
    'Python exercise',
    'Python remains unavailable.',
    'python_code',
    1,
    7,
    false
  );

SELECT pg_catalog.set_config(
  'coditza.assessment_tree_root',
  'exercise:a3400000-0000-0000-0000-000000000001',
  true
);

INSERT INTO private.exercise_answer_keys (
  exercise_id,
  answer_spec
)
VALUES (
  'a3400000-0000-0000-0000-000000000001',
  '{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}'::jsonb
);

INSERT INTO public.quizzes (
  id,
  chapter_id,
  slug,
  title,
  instructions_markdown,
  position,
  passing_percent,
  max_attempts,
  time_limit_seconds,
  is_required
)
VALUES
  (
    'a3500000-0000-0000-0000-000000000001',
    'a3200000-0000-0000-0000-000000000001',
    'main-learning-quiz',
    'Main learning quiz',
    'Answer the synthetic question.',
    0,
    50,
    2,
    NULL,
    true
  ),
  (
    'a3500000-0000-0000-0000-000000000002',
    'a3200000-0000-0000-0000-000000000001',
    'timed-learning-quiz',
    'Timed learning quiz',
    'A synthetic timed quiz.',
    1,
    50,
    NULL,
    60,
    false
  );

SELECT pg_catalog.set_config(
  'coditza.assessment_tree_root',
  'quiz:a3500000-0000-0000-0000-000000000001',
  true
);
INSERT INTO public.quiz_questions (
  id,
  quiz_id,
  prompt_markdown,
  question_type,
  position,
  points
)
VALUES (
  'a3600000-0000-0000-0000-000000000001',
  'a3500000-0000-0000-0000-000000000001',
  'Main short-text question.',
  'short_text',
  0,
  10
);
INSERT INTO private.quiz_question_answer_keys (
  question_id,
  answer_spec
)
VALUES (
  'a3600000-0000-0000-0000-000000000001',
  '{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}'::jsonb
);

SELECT pg_catalog.set_config(
  'coditza.assessment_tree_root',
  'quiz:a3500000-0000-0000-0000-000000000002',
  true
);
INSERT INTO public.quiz_questions (
  id,
  quiz_id,
  prompt_markdown,
  question_type,
  position,
  points
)
VALUES (
  'a3600000-0000-0000-0000-000000000002',
  'a3500000-0000-0000-0000-000000000002',
  'Timed short-text question.',
  'short_text',
  0,
  10
);
INSERT INTO private.quiz_question_answer_keys (
  question_id,
  answer_spec
)
VALUES (
  'a3600000-0000-0000-0000-000000000002',
  '{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}'::jsonb
);

SELECT pg_catalog.set_config('coditza.assessment_tree_root', '', true);

UPDATE public.modules
SET status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp()
WHERE id = 'a3100000-0000-0000-0000-000000000001';

UPDATE public.chapters
SET status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp()
WHERE module_id = 'a3100000-0000-0000-0000-000000000001';

UPDATE public.theory_sections
SET status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp()
WHERE id = 'a3300000-0000-0000-0000-000000000001';

UPDATE public.exercises
SET status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp()
WHERE id = 'a3400000-0000-0000-0000-000000000001';

UPDATE public.quizzes
SET status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp()
WHERE id IN (
  'a3500000-0000-0000-0000-000000000001',
  'a3500000-0000-0000-0000-000000000002'
);

DO $draft_theory_rejection$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM private.set_theory_completion(
      'a3000000-0000-0000-0000-000000000001',
      'a3300000-0000-0000-0000-000000000002',
      true
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'draft theory completion unexpectedly succeeded';
  END IF;
END;
$draft_theory_rejection$;
SELECT extensions.ok(TRUE, 'only effectively published theory sections may be completed');

DO $theory_completion_state$
DECLARE
  v_first timestamptz;
BEGIN
  IF NOT private.set_theory_completion(
    'a3000000-0000-0000-0000-000000000001',
    'a3300000-0000-0000-0000-000000000001',
    true
  ) THEN
    RAISE EXCEPTION 'first theory completion did not change state';
  END IF;
  SELECT completion_entry.completed_at
  INTO v_first
  FROM public.theory_section_completions AS completion_entry
  WHERE completion_entry.user_id = 'a3000000-0000-0000-0000-000000000001'
    AND completion_entry.theory_section_id = 'a3300000-0000-0000-0000-000000000001';
  IF private.set_theory_completion(
    'a3000000-0000-0000-0000-000000000001',
    'a3300000-0000-0000-0000-000000000001',
    true
  ) THEN
    RAISE EXCEPTION 'idempotent theory completion changed state';
  END IF;
  IF (
    SELECT completion_entry.completed_at
    FROM public.theory_section_completions AS completion_entry
    WHERE completion_entry.user_id = 'a3000000-0000-0000-0000-000000000001'
      AND completion_entry.theory_section_id = 'a3300000-0000-0000-0000-000000000001'
  ) IS DISTINCT FROM v_first THEN
    RAISE EXCEPTION 'idempotent completion changed the first completion timestamp';
  END IF;
  IF NOT private.set_theory_completion(
    'a3000000-0000-0000-0000-000000000001',
    'a3300000-0000-0000-0000-000000000001',
    false
  ) THEN
    RAISE EXCEPTION 'completion removal before first chapter completion failed';
  END IF;
  PERFORM private.set_theory_completion(
    'a3000000-0000-0000-0000-000000000001',
    'a3300000-0000-0000-0000-000000000001',
    true
  );
END;
$theory_completion_state$;
SELECT extensions.ok(TRUE, 'theory completion is idempotent and removable before first chapter completion');

DO $scalar_attempts$
DECLARE
  v_first jsonb;
  v_replay jsonb;
  v_correct jsonb;
BEGIN
  v_first := private.submit_scalar_exercise_attempt(
    'a3000000-0000-0000-0000-000000000001',
    'a3400000-0000-0000-0000-000000000001',
    '{"text":"no"}'::jsonb,
    'a3700000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('01', 32), 'hex')
  );
  v_replay := private.submit_scalar_exercise_attempt(
    'a3000000-0000-0000-0000-000000000001',
    'a3400000-0000-0000-0000-000000000001',
    '{"text":"no"}'::jsonb,
    'a3700000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('01', 32), 'hex')
  );
  v_correct := private.submit_scalar_exercise_attempt(
    'a3000000-0000-0000-0000-000000000001',
    'a3400000-0000-0000-0000-000000000001',
    '{"text":" YES "}'::jsonb,
    'a3700000-0000-0000-0000-000000000002',
    1,
    pg_catalog.decode(pg_catalog.repeat('02', 32), 'hex')
  );
  IF (v_first ->> 'isCorrect')::boolean
    OR (v_first ->> 'pointsEarned')::integer <> 0
    OR (v_replay ->> 'id') IS DISTINCT FROM (v_first ->> 'id')
    OR NOT (v_correct ->> 'isCorrect')::boolean
    OR (v_correct ->> 'pointsEarned')::integer <> 7
    OR (
      SELECT attempt.exercise_definition_version = 1
        AND attempt.points_possible = 7
      FROM public.exercise_attempts AS attempt
      WHERE attempt.id = (v_correct ->> 'id')::uuid
    ) IS NOT TRUE THEN
    RAISE EXCEPTION 'scalar attempts did not preserve grading, replay, or frozen definition facts';
  END IF;
END;
$scalar_attempts$;
SELECT extensions.ok(TRUE, 'scalar attempts grade server-side, replay safely, and freeze definition facts');

DO $scalar_rejections$
DECLARE
  v_rejected boolean;
BEGIN
  v_rejected := false;
  BEGIN
    PERFORM private.submit_scalar_exercise_attempt(
      'a3000000-0000-0000-0000-000000000001',
      'a3400000-0000-0000-0000-000000000001',
      '{"text":"yes","score":100}'::jsonb,
      'a3700000-0000-0000-0000-000000000003',
      1,
      pg_catalog.decode(pg_catalog.repeat('03', 32), 'hex')
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'unknown answer fields unexpectedly succeeded';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.grade_scalar_exercise_answer(
      'a3400000-0000-0000-0000-000000000002',
      '{"files":[]}'::jsonb
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'python scalar grading did not fail closed';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.submit_scalar_exercise_attempt(
      'a3000000-0000-0000-0000-000000000001',
      'a3400000-0000-0000-0000-000000000001',
      '{"text":"no"}'::jsonb,
      'a3700000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('ff', 32), 'hex')
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'different idempotency request hash unexpectedly replayed';
  END IF;
END;
$scalar_rejections$;
SELECT extensions.ok(TRUE, 'scalar input, Python grading, and changed idempotency hashes fail closed');

DO $exercise_immutability$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    UPDATE public.exercise_attempts
    SET points_earned = 7
    WHERE user_id = 'a3000000-0000-0000-0000-000000000001'
      AND points_earned = 0;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'immutable exercise attempt unexpectedly updated';
  END IF;
END;
$exercise_immutability$;
SELECT extensions.ok(TRUE, 'exercise attempts are immutable after insertion');

DO $main_quiz_start$
DECLARE
  v_start jsonb;
  v_rejected boolean := false;
BEGIN
  v_start := private.start_quiz_attempt(
    'a3000000-0000-0000-0000-000000000001',
    'a3500000-0000-0000-0000-000000000001',
    'a3800000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('11', 32), 'hex')
  );
  IF (v_start ->> 'attemptNumber')::integer <> 1
    OR (v_start ->> 'expiresAt') <> 'null' THEN
    RAISE EXCEPTION 'untimed quiz did not start with its approved first-attempt result';
  END IF;
  BEGIN
    PERFORM private.start_quiz_attempt(
      'a3000000-0000-0000-0000-000000000001',
      'a3500000-0000-0000-0000-000000000001',
      'a3800000-0000-0000-0000-000000000002',
      1,
      pg_catalog.decode(pg_catalog.repeat('12', 32), 'hex')
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'a duplicate active quiz attempt unexpectedly started';
  END IF;
END;
$main_quiz_start$;
SELECT extensions.ok(TRUE, 'quiz start creates one active attempt and rejects a duplicate active start');

DO $quiz_answer_save$
DECLARE
  v_attempt_id uuid;
  v_answered_at timestamptz;
  v_rejected boolean := false;
BEGIN
  SELECT attempt.id
  INTO v_attempt_id
  FROM public.quiz_attempts AS attempt
  WHERE attempt.user_id = 'a3000000-0000-0000-0000-000000000001'
    AND attempt.quiz_id = 'a3500000-0000-0000-0000-000000000001'
    AND attempt.attempt_number = 1;

  IF NOT private.save_quiz_answer(
    'a3000000-0000-0000-0000-000000000001',
    v_attempt_id,
    'a3600000-0000-0000-0000-000000000001',
    '{"text":"yes"}'::jsonb
  ) THEN
    RAISE EXCEPTION 'first quiz answer save did not report success';
  END IF;
  SELECT answer_entry.answered_at
  INTO v_answered_at
  FROM public.quiz_attempt_answers AS answer_entry
  WHERE answer_entry.attempt_id = v_attempt_id
    AND answer_entry.question_id = 'a3600000-0000-0000-0000-000000000001';
  PERFORM private.save_quiz_answer(
    'a3000000-0000-0000-0000-000000000001',
    v_attempt_id,
    'a3600000-0000-0000-0000-000000000001',
    '{"text":"yes"}'::jsonb
  );
  IF (
    SELECT answer_entry.answered_at
    FROM public.quiz_attempt_answers AS answer_entry
    WHERE answer_entry.attempt_id = v_attempt_id
      AND answer_entry.question_id = 'a3600000-0000-0000-0000-000000000001'
  ) IS DISTINCT FROM v_answered_at THEN
    RAISE EXCEPTION 'identical quiz save changed its answered timestamp';
  END IF;
  BEGIN
    PERFORM private.save_quiz_answer(
      'a3000000-0000-0000-0000-000000000002',
      v_attempt_id,
      'a3600000-0000-0000-0000-000000000001',
      '{"text":"yes"}'::jsonb
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'cross-user quiz answer save unexpectedly succeeded';
  END IF;
END;
$quiz_answer_save$;
SELECT extensions.ok(TRUE, 'quiz answer saves preserve identical timestamps and enforce ownership');

DO $main_quiz_submit$
DECLARE
  v_attempt_id uuid;
  v_first jsonb;
  v_replay jsonb;
  v_rejected boolean := false;
BEGIN
  SELECT attempt.id
  INTO v_attempt_id
  FROM public.quiz_attempts AS attempt
  WHERE attempt.user_id = 'a3000000-0000-0000-0000-000000000001'
    AND attempt.quiz_id = 'a3500000-0000-0000-0000-000000000001'
    AND attempt.attempt_number = 1;
  v_first := private.submit_quiz_attempt(
    'a3000000-0000-0000-0000-000000000001',
    v_attempt_id
  );
  v_replay := private.submit_quiz_attempt(
    'a3000000-0000-0000-0000-000000000001',
    v_attempt_id
  );
  IF (v_first ->> 'status') <> 'submitted'
    OR NOT (v_first ->> 'passed')::boolean
    OR (v_first ->> 'pointsEarned')::integer <> 10
    OR v_replay IS DISTINCT FROM v_first THEN
    RAISE EXCEPTION 'terminal quiz submit did not grade once and replay its stored result';
  END IF;
  BEGIN
    PERFORM private.save_quiz_answer(
      'a3000000-0000-0000-0000-000000000001',
      v_attempt_id,
      'a3600000-0000-0000-0000-000000000001',
      '{"text":"no"}'::jsonb
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'terminal quiz answer unexpectedly changed';
  END IF;
END;
$main_quiz_submit$;
SELECT extensions.ok(TRUE, 'quiz terminal submission grades once, replays, and freezes answers');

DO $quiz_limit$
DECLARE
  v_second jsonb;
  v_second_attempt uuid;
  v_limited jsonb;
BEGIN
  v_second := private.start_quiz_attempt(
    'a3000000-0000-0000-0000-000000000001',
    'a3500000-0000-0000-0000-000000000001',
    'a3800000-0000-0000-0000-000000000003',
    1,
    pg_catalog.decode(pg_catalog.repeat('13', 32), 'hex')
  );
  IF (v_second ->> 'attemptNumber')::integer <> 2 THEN
    RAISE EXCEPTION 'second quiz attempt did not receive its monotonic number';
  END IF;
  SELECT attempt.id
  INTO v_second_attempt
  FROM public.quiz_attempts AS attempt
  WHERE attempt.user_id = 'a3000000-0000-0000-0000-000000000001'
    AND attempt.quiz_id = 'a3500000-0000-0000-0000-000000000001'
    AND attempt.attempt_number = 2;
  PERFORM private.submit_quiz_attempt(
    'a3000000-0000-0000-0000-000000000001',
    v_second_attempt
  );
  v_limited := private.start_quiz_attempt(
    'a3000000-0000-0000-0000-000000000001',
    'a3500000-0000-0000-0000-000000000001',
    'a3800000-0000-0000-0000-000000000004',
    1,
    pg_catalog.decode(pg_catalog.repeat('14', 32), 'hex')
  );
  IF v_limited IS DISTINCT FROM '{"outcome":"attempt_limit_reached"}'::jsonb THEN
    RAISE EXCEPTION 'maximum quiz attempt outcome was not returned';
  END IF;
END;
$quiz_limit$;
SELECT extensions.ok(TRUE, 'quiz attempts consume unique numbers and honor the maximum-attempt outcome');

DO $timed_quiz_expiry$
DECLARE
  v_result jsonb;
  v_rejected boolean := false;
BEGIN
  PERFORM pg_catalog.set_config('coditza.learning_write', 'quiz-start', true);
  INSERT INTO public.quiz_attempts (
    id,
    user_id,
    quiz_id,
    quiz_definition_version,
    attempt_number,
    started_at,
    expires_at
  )
  VALUES (
    'a3900000-0000-0000-0000-000000000001',
    'a3000000-0000-0000-0000-000000000001',
    'a3500000-0000-0000-0000-000000000002',
    1,
    1,
    pg_catalog.now() - pg_catalog.interval '60 seconds',
    pg_catalog.now()
  );
  PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
  v_result := private.submit_quiz_attempt(
    'a3000000-0000-0000-0000-000000000001',
    'a3900000-0000-0000-0000-000000000001'
  );
  IF (v_result ->> 'status') <> 'expired' THEN
    RAISE EXCEPTION 'attempt at the database deadline did not expire';
  END IF;
  BEGIN
    PERFORM private.save_quiz_answer(
      'a3000000-0000-0000-0000-000000000001',
      'a3900000-0000-0000-0000-000000000001',
      'a3600000-0000-0000-0000-000000000002',
      '{"text":"yes"}'::jsonb
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'expired quiz unexpectedly accepted a saved answer';
  END IF;
END;
$timed_quiz_expiry$;
SELECT extensions.ok(TRUE, 'a timed attempt expires exactly at its database deadline and becomes immutable');

SELECT extensions.ok(
  (
    SELECT progress.theory_percent = 100
      AND progress.exercise_percent = 100
      AND progress.quiz_percent = 100
      AND progress.overall_percent = 100
      AND progress.first_completed_at IS NOT NULL
      AND progress.completed_at IS NOT NULL
    FROM public.chapter_progress AS progress
    WHERE progress.user_id = 'a3000000-0000-0000-0000-000000000001'
      AND progress.chapter_id = 'a3200000-0000-0000-0000-000000000001'
  ),
  'stored chapter progress equals the current published source aggregate after completion'
);

DO $progress_reopen$
DECLARE
  v_first_completed_at timestamptz;
BEGIN
  SELECT progress.first_completed_at
  INTO v_first_completed_at
  FROM public.chapter_progress AS progress
  WHERE progress.user_id = 'a3000000-0000-0000-0000-000000000001'
    AND progress.chapter_id = 'a3200000-0000-0000-0000-000000000001';
  UPDATE public.theory_sections
  SET status = 'published'::public.content_status,
      published_at = pg_catalog.clock_timestamp()
  WHERE id = 'a3300000-0000-0000-0000-000000000003';
  PERFORM private.recalculate_chapter_progress(
    'a3000000-0000-0000-0000-000000000001',
    'a3200000-0000-0000-0000-000000000001'
  );
  IF (
    SELECT progress.theory_percent = 50
      AND progress.completed_at IS NULL
      AND progress.first_completed_at = v_first_completed_at
    FROM public.chapter_progress AS progress
    WHERE progress.user_id = 'a3000000-0000-0000-0000-000000000001'
      AND progress.chapter_id = 'a3200000-0000-0000-0000-000000000001'
  ) IS NOT TRUE THEN
    RAISE EXCEPTION 'new required content did not reopen progress while preserving first completion';
  END IF;
END;
$progress_reopen$;
SELECT extensions.ok(TRUE, 'recalculation clears current completion on reopen without changing first completion');

DO $empty_progress$
BEGIN
  PERFORM private.recalculate_chapter_progress(
    'a3000000-0000-0000-0000-000000000002',
    'a3200000-0000-0000-0000-000000000002'
  );
  IF EXISTS (
    SELECT 1
    FROM public.chapter_progress AS progress
    WHERE progress.user_id = 'a3000000-0000-0000-0000-000000000002'
      AND progress.chapter_id = 'a3200000-0000-0000-0000-000000000002'
  ) THEN
    RAISE EXCEPTION 'a missing empty-source progress snapshot was silently inserted';
  END IF;
END;
$empty_progress$;
SELECT extensions.ok(TRUE, 'recalculation preserves a missing snapshot for a chapter with no learning sources');

DO $idempotency_expiry$
DECLARE
  v_result jsonb;
BEGIN
  PERFORM pg_catalog.set_config('coditza.learning_write', 'idempotency', true);
  UPDATE private.idempotency_records
  SET created_at = pg_catalog.now() - pg_catalog.interval '24 hours'
  WHERE user_id = 'a3000000-0000-0000-0000-000000000001'
    AND operation = 'exercise_submit'
    AND idempotency_key = 'a3700000-0000-0000-0000-000000000001';
  PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
  v_result := private.submit_scalar_exercise_attempt(
    'a3000000-0000-0000-0000-000000000001',
    'a3400000-0000-0000-0000-000000000001',
    '{"text":"no"}'::jsonb,
    'a3700000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('01', 32), 'hex')
  );
  IF (
    SELECT pg_catalog.count(*) = 3
    FROM public.exercise_attempts AS attempt
    WHERE attempt.user_id = 'a3000000-0000-0000-0000-000000000001'
      AND attempt.exercise_id = 'a3400000-0000-0000-0000-000000000001'
  ) IS NOT TRUE
    OR (v_result ->> 'isCorrect')::boolean THEN
    RAISE EXCEPTION 'an idempotency key at its 24-hour boundary did not begin a fresh operation';
  END IF;
END;
$idempotency_expiry$;
SELECT extensions.ok(TRUE, 'idempotency expires at the strict 24-hour database boundary and permits a fresh request');

DO $unsafe_idempotency_response$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM private.complete_idempotency(
      'a3000000-0000-0000-0000-000000000001',
      'admin_create_module',
      'a3700000-0000-0000-0000-000000000004',
      1,
      pg_catalog.decode(pg_catalog.repeat('04', 32), 'hex'),
      'a3100000-0000-0000-0000-000000000001',
      201,
      '/api/v1/modules/a3100000-0000-0000-0000-000000000001',
      '{"id":"a3100000-0000-0000-0000-000000000001","answer":"leak"}'::jsonb
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'unsafe idempotency response unexpectedly persisted';
  END IF;
END;
$unsafe_idempotency_response$;
SELECT extensions.ok(TRUE, 'idempotency records reject operation responses that could disclose answers');

DO $audit_safety$
DECLARE
  v_audit_id uuid;
  v_rejected boolean := false;
BEGIN
  v_audit_id := private.append_audit_event(
    'user',
    'a3000000-0000-0000-0000-000000000001',
    'learning_started',
    'chapter',
    'a3200000-0000-0000-0000-000000000001',
    ARRAY['status']::text[],
    '{"status":{"before":"none","after":"started"}}'::jsonb,
    NULL,
    'a3a00000-0000-0000-0000-000000000001'
  );
  BEGIN
    UPDATE private.audit_events
    SET action = 'tampered'
    WHERE id = v_audit_id;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'audit update unexpectedly succeeded';
  END IF;
  v_rejected := false;
  BEGIN
    PERFORM private.append_audit_event(
      'user',
      'a3000000-0000-0000-0000-000000000001',
      'learning_started',
      'chapter',
      'a3200000-0000-0000-0000-000000000001',
      ARRAY['answer']::text[],
      '{}'::jsonb,
      NULL,
      'a3a00000-0000-0000-0000-000000000002'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'sensitive audit changed field unexpectedly succeeded';
  END IF;
END;
$audit_safety$;
SELECT extensions.ok(TRUE, 'audit events are append-only and reject sensitive summaries');

SELECT private.set_theory_completion(
  'a3000000-0000-0000-0000-000000000003',
  'a3300000-0000-0000-0000-000000000001',
  true
);
SELECT private.append_audit_event(
  'user',
  'a3000000-0000-0000-0000-000000000003',
  'learning_started',
  'chapter',
  'a3200000-0000-0000-0000-000000000001',
  ARRAY['status']::text[],
  '{"status":{"before":"none","after":"started"}}'::jsonb,
  NULL,
  'a3a00000-0000-0000-0000-000000000003'
);

RESET ROLE;
DELETE FROM auth.users
WHERE id = 'a3000000-0000-0000-0000-000000000003';
SET LOCAL ROLE coditza_owner;

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM public.theory_section_completions AS completion_entry
    WHERE completion_entry.user_id = 'a3000000-0000-0000-0000-000000000003'
  )
    AND EXISTS (
      SELECT 1
      FROM private.audit_events AS audit_entry
      WHERE audit_entry.request_id = 'a3a00000-0000-0000-0000-000000000003'
        AND audit_entry.actor_kind = 'user'
        AND audit_entry.actor_user_id IS NULL
    ),
  'account deletion cascades learner records and anonymizes retained user audit actors'
);

DO $held_profile_rejection$
DECLARE
  v_rejected boolean := false;
BEGIN
  UPDATE public.profiles
  SET security_hold_at = pg_catalog.clock_timestamp()
  WHERE id = 'a3000000-0000-0000-0000-000000000004';
  BEGIN
    PERFORM private.set_theory_completion(
      'a3000000-0000-0000-0000-000000000004',
      'a3300000-0000-0000-0000-000000000001',
      true
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'held learner profile unexpectedly changed learning state';
  END IF;
END;
$held_profile_rejection$;
SELECT extensions.ok(TRUE, 'learning workflow primitives recheck and reject a held actor profile');

RESET ROLE;
SET LOCAL ROLE service_role;

DO $runtime_direct_denial$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM 1 FROM private.idempotency_records LIMIT 1;
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'service role unexpectedly read private idempotency records';
  END IF;
  v_rejected := false;
  BEGIN
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
      'a3000000-0000-0000-0000-000000000001',
      'a3400000-0000-0000-0000-000000000001',
      1,
      '{"text":"yes"}'::jsonb,
      true,
      7,
      7
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'service role unexpectedly inserted a direct exercise attempt';
  END IF;
END;
$runtime_direct_denial$;

RESET ROLE;
SELECT extensions.ok(TRUE, 'service-role private reads and direct learning writes fail with privilege denial');

SELECT * FROM extensions.finish();

ROLLBACK;
