BEGIN;

GRANT USAGE ON SCHEMA extensions TO coditza_owner;

SELECT extensions.plan(38);

SELECT extensions.ok(
  pg_catalog.to_regclass('public.exercises') IS NOT NULL
    AND pg_catalog.to_regclass('public.exercise_options') IS NOT NULL
    AND pg_catalog.to_regclass('public.quizzes') IS NOT NULL
    AND pg_catalog.to_regclass('public.quiz_questions') IS NOT NULL
    AND pg_catalog.to_regclass('public.quiz_question_options') IS NOT NULL
    AND pg_catalog.to_regclass('private.exercise_answer_keys') IS NOT NULL
    AND pg_catalog.to_regclass('private.quiz_question_answer_keys') IS NOT NULL,
  'the approved public assessment trees and private answer-key tables exist'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 7
      AND pg_catalog.bool_and(
        relation_entry.relowner = 'coditza_owner'::pg_catalog.regrole
      )
    FROM pg_catalog.pg_class AS relation_entry
    WHERE relation_entry.oid IN (
      'public.exercises'::pg_catalog.regclass,
      'public.exercise_options'::pg_catalog.regclass,
      'public.quizzes'::pg_catalog.regclass,
      'public.quiz_questions'::pg_catalog.regclass,
      'public.quiz_question_options'::pg_catalog.regclass,
      'private.exercise_answer_keys'::pg_catalog.regclass,
      'private.quiz_question_answer_keys'::pg_catalog.regclass
    )
  ),
  'all assessment tables are owned by coditza_owner'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 5
      AND pg_catalog.bool_and(relation_entry.relrowsecurity)
      AND NOT pg_catalog.bool_or(relation_entry.relforcerowsecurity)
    FROM pg_catalog.pg_class AS relation_entry
    WHERE relation_entry.oid IN (
      'public.exercises'::pg_catalog.regclass,
      'public.exercise_options'::pg_catalog.regclass,
      'public.quizzes'::pg_catalog.regclass,
      'public.quiz_questions'::pg_catalog.regclass,
      'public.quiz_question_options'::pg_catalog.regclass
    )
  )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_policy AS policy_entry
      WHERE policy_entry.polrelid IN (
        'public.exercises'::pg_catalog.regclass,
        'public.exercise_options'::pg_catalog.regclass,
        'public.quizzes'::pg_catalog.regclass,
        'public.quiz_questions'::pg_catalog.regclass,
        'public.quiz_question_options'::pg_catalog.regclass
      )
    ),
  'public assessment tables have RLS enabled without force or direct policies'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 2
      AND pg_catalog.bool_and(relation_entry.relrowsecurity)
      AND NOT pg_catalog.bool_or(relation_entry.relforcerowsecurity)
    FROM pg_catalog.pg_class AS relation_entry
    WHERE relation_entry.oid IN (
      'private.exercise_answer_keys'::pg_catalog.regclass,
      'private.quiz_question_answer_keys'::pg_catalog.regclass
    )
  )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_policy AS policy_entry
      WHERE policy_entry.polrelid IN (
        'private.exercise_answer_keys'::pg_catalog.regclass,
        'private.quiz_question_answer_keys'::pg_catalog.regclass
      )
    ),
  'private answer-key tables have defense-in-depth RLS without policies'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
      = ARRAY[
        'id',
        'chapter_id',
        'title',
        'prompt_markdown',
        'exercise_type',
        'position',
        'points',
        'is_required',
        'status',
        'row_version',
        'published_at',
        'definition_version',
        'created_by',
        'updated_by',
        'created_at',
        'updated_at'
      ]::text[]
    FROM pg_catalog.pg_attribute AS attribute_entry
    WHERE attribute_entry.attrelid = 'public.exercises'::pg_catalog.regclass
      AND attribute_entry.attnum > 0
      AND NOT attribute_entry.attisdropped
  )
    AND (
      SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
        = ARRAY[
          'id',
          'chapter_id',
          'slug',
          'title',
          'instructions_markdown',
          'position',
          'passing_percent',
          'max_attempts',
          'time_limit_seconds',
          'is_required',
          'status',
          'row_version',
          'published_at',
          'definition_version',
          'created_by',
          'updated_by',
          'created_at',
          'updated_at'
        ]::text[]
      FROM pg_catalog.pg_attribute AS attribute_entry
      WHERE attribute_entry.attrelid = 'public.quizzes'::pg_catalog.regclass
        AND attribute_entry.attnum > 0
        AND NOT attribute_entry.attisdropped
    ),
  'assessment roots have exactly the approved columns'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
      = ARRAY['id', 'exercise_id', 'label_markdown', 'position', 'created_at', 'updated_at']::text[]
    FROM pg_catalog.pg_attribute AS attribute_entry
    WHERE attribute_entry.attrelid = 'public.exercise_options'::pg_catalog.regclass
      AND attribute_entry.attnum > 0
      AND NOT attribute_entry.attisdropped
  )
    AND (
      SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
        = ARRAY['id', 'quiz_id', 'prompt_markdown', 'question_type', 'position', 'points', 'created_at', 'updated_at']::text[]
      FROM pg_catalog.pg_attribute AS attribute_entry
      WHERE attribute_entry.attrelid = 'public.quiz_questions'::pg_catalog.regclass
        AND attribute_entry.attnum > 0
        AND NOT attribute_entry.attisdropped
    )
    AND (
      SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
        = ARRAY['id', 'question_id', 'label_markdown', 'position', 'created_at', 'updated_at']::text[]
      FROM pg_catalog.pg_attribute AS attribute_entry
      WHERE attribute_entry.attrelid = 'public.quiz_question_options'::pg_catalog.regclass
        AND attribute_entry.attnum > 0
        AND NOT attribute_entry.attisdropped
    ),
  'assessment child tables have exactly the approved columns'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
      = ARRAY[
        'exercise_id',
        'answer_spec',
        'feedback_correct_markdown',
        'feedback_incorrect_markdown',
        'created_by',
        'updated_by',
        'created_at',
        'updated_at'
      ]::text[]
    FROM pg_catalog.pg_attribute AS attribute_entry
    WHERE attribute_entry.attrelid = 'private.exercise_answer_keys'::pg_catalog.regclass
      AND attribute_entry.attnum > 0
      AND NOT attribute_entry.attisdropped
  )
    AND (
      SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
        = ARRAY[
          'question_id',
          'answer_spec',
          'feedback_correct_markdown',
          'feedback_incorrect_markdown',
          'created_by',
          'updated_by',
          'created_at',
          'updated_at'
        ]::text[]
      FROM pg_catalog.pg_attribute AS attribute_entry
      WHERE attribute_entry.attrelid = 'private.quiz_question_answer_keys'::pg_catalog.regclass
        AND attribute_entry.attnum > 0
        AND NOT attribute_entry.attisdropped
    ),
  'private answer-key tables have exactly the approved columns'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 7
      AND pg_catalog.bool_and(constraint_entry.confdeltype = 'r')
    FROM pg_catalog.pg_constraint AS constraint_entry
    WHERE constraint_entry.contype = 'f'
      AND constraint_entry.conrelid IN (
        'public.exercises'::pg_catalog.regclass,
        'public.exercise_options'::pg_catalog.regclass,
        'public.quizzes'::pg_catalog.regclass,
        'public.quiz_questions'::pg_catalog.regclass,
        'public.quiz_question_options'::pg_catalog.regclass,
        'private.exercise_answer_keys'::pg_catalog.regclass,
        'private.quiz_question_answer_keys'::pg_catalog.regclass
      )
      AND constraint_entry.confrelid IN (
        'public.chapters'::pg_catalog.regclass,
        'public.exercises'::pg_catalog.regclass,
        'public.quizzes'::pg_catalog.regclass,
        'public.quiz_questions'::pg_catalog.regclass
      )
  )
    AND (
      SELECT pg_catalog.count(*) = 5
        AND pg_catalog.bool_and(constraint_entry.condeferrable)
        AND NOT pg_catalog.bool_or(constraint_entry.condeferred)
      FROM pg_catalog.pg_constraint AS constraint_entry
      WHERE constraint_entry.conname IN (
        'exercises_chapter_position_key',
        'exercise_options_exercise_position_key',
        'quizzes_chapter_position_key',
        'quiz_questions_quiz_position_key',
        'quiz_question_options_question_position_key'
      )
        AND constraint_entry.contype = 'u'
    )
    AND EXISTS (
      SELECT 1
      FROM pg_catalog.pg_constraint AS constraint_entry
      WHERE constraint_entry.conname = 'exercise_options_exercise_id_id_key'
        AND constraint_entry.conrelid = 'public.exercise_options'::pg_catalog.regclass
    )
    AND EXISTS (
      SELECT 1
      FROM pg_catalog.pg_constraint AS constraint_entry
      WHERE constraint_entry.conname = 'quiz_question_options_question_id_id_key'
        AND constraint_entry.conrelid = 'public.quiz_question_options'::pg_catalog.regclass
    ),
  'assessment parent references restrict deletion and child positions/ownership keys are scoped correctly'
);

SELECT extensions.ok(
  pg_catalog.to_regclass('public.exercises_chapter_status_position_id_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.exercises_created_by_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.exercises_updated_by_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.quizzes_chapter_status_position_id_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.quizzes_created_by_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.quizzes_updated_by_idx') IS NOT NULL
    AND pg_catalog.to_regclass('private.exercise_answer_keys_created_by_idx') IS NOT NULL
    AND pg_catalog.to_regclass('private.exercise_answer_keys_updated_by_idx') IS NOT NULL
    AND pg_catalog.to_regclass('private.quiz_question_answer_keys_created_by_idx') IS NOT NULL
    AND pg_catalog.to_regclass('private.quiz_question_answer_keys_updated_by_idx') IS NOT NULL,
  'required root list and audit-actor indexes exist'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    CROSS JOIN (
      VALUES
        ('public.exercises'::pg_catalog.regclass),
        ('public.exercise_options'::pg_catalog.regclass),
        ('public.quizzes'::pg_catalog.regclass),
        ('public.quiz_questions'::pg_catalog.regclass),
        ('public.quiz_question_options'::pg_catalog.regclass),
        ('private.exercise_answer_keys'::pg_catalog.regclass),
        ('private.quiz_question_answer_keys'::pg_catalog.regclass)
    ) AS assessment_table(table_oid)
    WHERE pg_catalog.has_table_privilege(runtime_role.rolname, assessment_table.table_oid, 'SELECT')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, assessment_table.table_oid, 'INSERT')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, assessment_table.table_oid, 'UPDATE')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, assessment_table.table_oid, 'DELETE')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, assessment_table.table_oid, 'TRUNCATE')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, assessment_table.table_oid, 'REFERENCES')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, assessment_table.table_oid, 'TRIGGER')
  )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_class AS relation_entry
      CROSS JOIN LATERAL pg_catalog.unnest(relation_entry.relacl) AS acl_entry(item)
      WHERE relation_entry.oid IN (
        'public.exercises'::pg_catalog.regclass,
        'public.exercise_options'::pg_catalog.regclass,
        'public.quizzes'::pg_catalog.regclass,
        'public.quiz_questions'::pg_catalog.regclass,
        'public.quiz_question_options'::pg_catalog.regclass,
        'private.exercise_answer_keys'::pg_catalog.regclass,
        'private.quiz_question_answer_keys'::pg_catalog.regclass
      )
        AND acl_entry.item::text OPERATOR(pg_catalog.~)
          '^(postgres|anon|authenticated|service_role|authenticator)='
    ),
  'runtime roles have no direct assessment or answer-key table privileges'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_schema_privilege(runtime_role.rolname, 'private', 'USAGE')
      OR pg_catalog.has_function_privilege(
        runtime_role.rolname,
        'private.replace_draft_exercise_definition(uuid,integer,jsonb)'::pg_catalog.regprocedure,
        'EXECUTE'
      )
      OR pg_catalog.has_function_privilege(
        runtime_role.rolname,
        'private.replace_draft_quiz_definition(uuid,integer,jsonb)'::pg_catalog.regprocedure,
        'EXECUTE'
      )
      OR pg_catalog.has_function_privilege(
        runtime_role.rolname,
        'private.validate_exercise_definition(uuid)'::pg_catalog.regprocedure,
        'EXECUTE'
      )
      OR pg_catalog.has_function_privilege(
        runtime_role.rolname,
        'private.validate_quiz_definition(uuid)'::pg_catalog.regprocedure,
        'EXECUTE'
      )
  ),
  'runtime roles cannot use private assessment schemas or helpers'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 4
      AND pg_catalog.bool_and(
        procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
      )
      AND NOT pg_catalog.bool_or(procedure_entry.prosecdef)
      AND pg_catalog.bool_and(
        procedure_entry.proconfig = ARRAY['search_path=""']::text[]
      )
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid IN (
      'private.replace_draft_exercise_definition(uuid,integer,jsonb)'::pg_catalog.regprocedure,
      'private.replace_draft_quiz_definition(uuid,integer,jsonb)'::pg_catalog.regprocedure,
      'private.validate_exercise_definition(uuid)'::pg_catalog.regprocedure,
      'private.validate_quiz_definition(uuid)'::pg_catalog.regprocedure
    )
  ),
  'critical assessment helpers are owner-controlled SECURITY INVOKER with empty paths'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 9
    FROM pg_catalog.pg_trigger AS trigger_entry
    WHERE NOT trigger_entry.tgisinternal
      AND trigger_entry.tgfoid IN (
        'private.validate_exercise_assessment_root()'::pg_catalog.regprocedure,
        'private.validate_quiz_assessment_root()'::pg_catalog.regprocedure,
        'private.enforce_exercise_option_tree_write()'::pg_catalog.regprocedure,
        'private.enforce_exercise_answer_key_tree_write()'::pg_catalog.regprocedure,
        'private.validate_exercise_answer_key_row()'::pg_catalog.regprocedure,
        'private.enforce_quiz_question_tree_write()'::pg_catalog.regprocedure,
        'private.enforce_quiz_question_option_tree_write()'::pg_catalog.regprocedure,
        'private.enforce_quiz_answer_key_tree_write()'::pg_catalog.regprocedure,
        'private.validate_quiz_question_answer_key_row()'::pg_catalog.regprocedure
      )
  ),
  'assessment root, child-tree, and stored-answer validators are bound as triggers'
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
  'a1000000-0000-0000-0000-000000000000',
  'assessment-module',
  'Assessment module',
  'Synthetic assessment module.',
  600
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
VALUES (
  'b1000000-0000-0000-0000-000000000000',
  'a1000000-0000-0000-0000-000000000000',
  'assessment-chapter',
  'Assessment chapter',
  'Synthetic assessment chapter.',
  0,
  30
);

INSERT INTO public.exercises (
  id, chapter_id, title, prompt_markdown, exercise_type, position, points
)
VALUES
  ('10000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000000', 'Single exercise', 'Choose one.', 'single_choice', 0, 10),
  ('10000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000000', 'Multiple exercise', 'Choose many.', 'multiple_choice', 1, 10),
  ('10000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000000', 'Short exercise', 'Type text.', 'short_text', 2, 10),
  ('10000000-0000-0000-0000-000000000004', 'b1000000-0000-0000-0000-000000000000', 'Python exercise', 'Write Python.', 'python_code', 3, 10),
  ('10000000-0000-0000-0000-000000000005', 'b1000000-0000-0000-0000-000000000000', 'Rollback exercise', 'Keep prior tree.', 'single_choice', 4, 10);

INSERT INTO public.quizzes (
  id, chapter_id, slug, title, instructions_markdown, position
)
VALUES
  ('20000000-0000-0000-0000-000000000001', 'b1000000-0000-0000-0000-000000000000', 'valid-quiz', 'Valid quiz', 'Answer all questions.', 0),
  ('20000000-0000-0000-0000-000000000002', 'b1000000-0000-0000-0000-000000000000', 'invalid-quiz', 'Invalid quiz', 'Invalid draft.', 1),
  ('20000000-0000-0000-0000-000000000003', 'b1000000-0000-0000-0000-000000000000', 'empty-quiz', 'Empty quiz', 'Empty draft.', 2);

CREATE TEMP TABLE pg_temp.assessment_results (
  kind text PRIMARY KEY,
  payload jsonb NOT NULL
) ON COMMIT DROP;

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 5
      AND pg_catalog.bool_and(status = 'draft'::public.content_status)
      AND pg_catalog.bool_and(row_version = 1)
      AND pg_catalog.bool_and(definition_version = 1)
      AND pg_catalog.bool_and(published_at IS NULL)
    FROM public.exercises
    WHERE chapter_id = 'b1000000-0000-0000-0000-000000000000'
  )
    AND (
      SELECT pg_catalog.count(*) = 3
        AND pg_catalog.bool_and(status = 'draft'::public.content_status)
        AND pg_catalog.bool_and(row_version = 1)
        AND pg_catalog.bool_and(definition_version = 1)
      FROM public.quizzes
      WHERE chapter_id = 'b1000000-0000-0000-0000-000000000000'
    ),
  'assessment roots receive draft lifecycle and definition-version defaults'
);

DO $assessment_root_bounds$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    INSERT INTO public.exercises (
      chapter_id,
      title,
      prompt_markdown,
      exercise_type,
      position,
      points
    )
    VALUES (
      'b1000000-0000-0000-0000-000000000000',
      'Invalid points',
      'Invalid points.',
      'single_choice',
      20,
      0
    );
  EXCEPTION WHEN check_violation THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'exercise points below one must fail';
  END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.quizzes (
      chapter_id,
      slug,
      title,
      instructions_markdown,
      position,
      passing_percent
    )
    VALUES (
      'b1000000-0000-0000-0000-000000000000',
      'invalid-passing-percent',
      'Invalid passing percent',
      'Invalid passing percent.',
      20,
      101
    );
  EXCEPTION WHEN check_violation THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'quiz passing percent above one hundred must fail';
  END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.quizzes (
      chapter_id,
      slug,
      title,
      instructions_markdown,
      position,
      max_attempts
    )
    VALUES (
      'b1000000-0000-0000-0000-000000000000',
      'invalid-max-attempts',
      'Invalid max attempts',
      'Invalid max attempts.',
      21,
      0
    );
  EXCEPTION WHEN check_violation THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'quiz max attempts below one must fail';
  END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.quizzes (
      chapter_id,
      slug,
      title,
      instructions_markdown,
      position,
      time_limit_seconds
    )
    VALUES (
      'b1000000-0000-0000-0000-000000000000',
      'invalid-time-limit',
      'Invalid time limit',
      'Invalid time limit.',
      22,
      29
    );
  EXCEPTION WHEN check_violation THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'quiz time limit below thirty seconds must fail';
  END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.quizzes (
      chapter_id,
      slug,
      title,
      instructions_markdown,
      position,
      definition_version
    )
    VALUES (
      'b1000000-0000-0000-0000-000000000000',
      'invalid-definition-version',
      'Invalid definition version',
      'Invalid definition version.',
      20,
      2
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'new quiz definition version two must fail';
  END IF;
END;
$assessment_root_bounds$;

SELECT extensions.ok(TRUE, 'assessment root bounds, quiz limits, and initial definition version are enforced');

DO $stored_answer_key_rejections$
DECLARE
  v_rejected boolean := false;
BEGIN
  INSERT INTO public.exercises (
    id,
    chapter_id,
    title,
    prompt_markdown,
    exercise_type,
    position,
    points
  )
  VALUES
    ('10000000-0000-0000-0000-000000000006', 'b1000000-0000-0000-0000-000000000000', 'Stored single key', 'Validate a stored single key.', 'single_choice', 5, 1),
    ('10000000-0000-0000-0000-000000000007', 'b1000000-0000-0000-0000-000000000000', 'Foreign stored option', 'Own a foreign stored option.', 'single_choice', 6, 1),
    ('10000000-0000-0000-0000-000000000008', 'b1000000-0000-0000-0000-000000000000', 'Stored multiple key', 'Validate a stored multiple key.', 'multiple_choice', 7, 1);

  PERFORM pg_catalog.set_config(
    'coditza.assessment_tree_root',
    'exercise:10000000-0000-0000-0000-000000000006',
    true
  );
  INSERT INTO public.exercise_options (id, exercise_id, label_markdown, position)
  VALUES (
    '31000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000006',
    'Stored single option',
    0
  );

  PERFORM pg_catalog.set_config(
    'coditza.assessment_tree_root',
    'exercise:10000000-0000-0000-0000-000000000007',
    true
  );
  INSERT INTO public.exercise_options (id, exercise_id, label_markdown, position)
  VALUES (
    '32000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000007',
    'Foreign stored option',
    0
  );

  PERFORM pg_catalog.set_config(
    'coditza.assessment_tree_root',
    'exercise:10000000-0000-0000-0000-000000000008',
    true
  );
  INSERT INTO public.exercise_options (id, exercise_id, label_markdown, position)
  VALUES
    ('33000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000008', 'First multiple option', 0),
    ('33000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000008', 'Second multiple option', 1);

  INSERT INTO public.quizzes (
    id,
    chapter_id,
    slug,
    title,
    instructions_markdown,
    position
  )
  VALUES (
    '20000000-0000-0000-0000-000000000004',
    'b1000000-0000-0000-0000-000000000000',
    'stored-key-quiz',
    'Stored key quiz',
    'Validate stored quiz keys.',
    3
  );
  PERFORM pg_catalog.set_config(
    'coditza.assessment_tree_root',
    'quiz:20000000-0000-0000-0000-000000000004',
    true
  );
  INSERT INTO public.quiz_questions (id, quiz_id, prompt_markdown, question_type, position, points)
  VALUES
    ('41000000-0000-0000-0000-000000000001', '20000000-0000-0000-0000-000000000004', 'Stored left question?', 'single_choice', 0, 1),
    ('41000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000004', 'Stored right question?', 'single_choice', 1, 1);
  INSERT INTO public.quiz_question_options (id, question_id, label_markdown, position)
  VALUES
    ('51000000-0000-0000-0000-000000000001', '41000000-0000-0000-0000-000000000001', 'Stored left option', 0),
    ('51000000-0000-0000-0000-000000000002', '41000000-0000-0000-0000-000000000002', 'Stored right option', 0);

  PERFORM pg_catalog.set_config(
    'coditza.assessment_tree_root',
    'exercise:10000000-0000-0000-0000-000000000006',
    true
  );
  BEGIN
    INSERT INTO private.exercise_answer_keys (exercise_id, answer_spec)
    VALUES (
      '10000000-0000-0000-0000-000000000006',
      pg_catalog.jsonb_build_object(
        'correctOptionId',
        '31000000-0000-0000-0000-000000000001',
        'unexpected',
        true
      )
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'stored single-choice answer keys must reject unknown fields';
  END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO private.exercise_answer_keys (exercise_id, answer_spec)
    VALUES (
      '10000000-0000-0000-0000-000000000006',
      pg_catalog.jsonb_build_object(
        'correctOptionId',
        '31000000-0000-0000-0000-00000000000A'
      )
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'stored single-choice answer keys must reject noncanonical UUID text';
  END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO private.exercise_answer_keys (exercise_id, answer_spec)
    VALUES (
      '10000000-0000-0000-0000-000000000006',
      pg_catalog.jsonb_build_object(
        'correctOptionId',
        '32000000-0000-0000-0000-000000000001'
      )
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'stored exercise answer keys must reject options from another exercise';
  END IF;

  PERFORM pg_catalog.set_config(
    'coditza.assessment_tree_root',
    'exercise:10000000-0000-0000-0000-000000000008',
    true
  );
  v_rejected := false;
  BEGIN
    INSERT INTO private.exercise_answer_keys (exercise_id, answer_spec)
    VALUES (
      '10000000-0000-0000-0000-000000000008',
      pg_catalog.jsonb_build_object(
        'correctOptionIds',
        pg_catalog.jsonb_build_array(
          '33000000-0000-0000-0000-000000000001',
          '33000000-0000-0000-0000-000000000001'
        )
      )
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'stored multiple-choice answer keys must reject duplicate UUIDs';
  END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO private.exercise_answer_keys (exercise_id, answer_spec)
    VALUES (
      '10000000-0000-0000-0000-000000000008',
      pg_catalog.jsonb_build_object(
        'correctOptionIds',
        pg_catalog.jsonb_build_array(
          '33000000-0000-0000-0000-000000000002',
          '33000000-0000-0000-0000-000000000001'
        )
      )
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'stored multiple-choice answer keys must reject unsorted UUIDs';
  END IF;

  PERFORM pg_catalog.set_config(
    'coditza.assessment_tree_root',
    'quiz:20000000-0000-0000-0000-000000000004',
    true
  );
  v_rejected := false;
  BEGIN
    INSERT INTO private.quiz_question_answer_keys (question_id, answer_spec)
    VALUES (
      '41000000-0000-0000-0000-000000000001',
      pg_catalog.jsonb_build_object(
        'correctOptionId',
        '51000000-0000-0000-0000-000000000002'
      )
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'stored quiz keys must reject options from another question';
  END IF;

  PERFORM pg_catalog.set_config('coditza.assessment_tree_root', '', true);
END;
$stored_answer_key_rejections$;

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM private.exercise_answer_keys AS answer_key
    WHERE answer_key.exercise_id IN (
      '10000000-0000-0000-0000-000000000006'::uuid,
      '10000000-0000-0000-0000-000000000008'::uuid
    )
  )
    AND NOT EXISTS (
      SELECT 1
      FROM private.quiz_question_answer_keys AS answer_key
      WHERE answer_key.question_id IN (
        '41000000-0000-0000-0000-000000000001'::uuid,
        '41000000-0000-0000-0000-000000000002'::uuid
      )
    ),
  'stored answer-key validators reject malformed, unsorted, and cross-owner UUID specifications'
);

INSERT INTO pg_temp.assessment_results (kind, payload)
SELECT
  'exercise-single',
  private.replace_draft_exercise_definition(
    '10000000-0000-0000-0000-000000000001',
    1,
    pg_catalog.jsonb_build_object(
      'options',
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('clientRef', 'option-a', 'labelMarkdown', 'A'),
        pg_catalog.jsonb_build_object('clientRef', 'option-b', 'labelMarkdown', 'B')
      ),
      'answerSpec',
      pg_catalog.jsonb_build_object('correctOptionRef', 'option-a'),
      'feedbackCorrectMarkdown',
      NULL,
      'feedbackIncorrectMarkdown',
      NULL
    )
  );

SELECT extensions.ok(
  EXISTS (
    SELECT 1
    FROM pg_temp.assessment_results AS result
    CROSS JOIN LATERAL pg_catalog.jsonb_array_elements(
      result.payload -> 'optionIdMappings'
    ) AS mapping(value)
    JOIN public.exercise_options AS option_entry
      ON option_entry.id::text = mapping.value ->> 'id'
      AND option_entry.exercise_id = '10000000-0000-0000-0000-000000000001'::uuid
    JOIN private.exercise_answer_keys AS answer_key
      ON answer_key.exercise_id = option_entry.exercise_id
    WHERE result.kind = 'exercise-single'
      AND mapping.value ->> 'clientRef' = 'option-a'
      AND answer_key.answer_spec = pg_catalog.jsonb_build_object(
        'correctOptionId',
        mapping.value ->> 'id'
      )
      AND NOT (answer_key.answer_spec OPERATOR(pg_catalog.?) 'correctOptionRef')
      AND NOT (answer_key.answer_spec OPERATOR(pg_catalog.?) 'clientRef')
  ),
  'exercise replacement maps client refs to generated option UUIDs and stores only UUID keys'
);

SELECT extensions.ok(
  (
    SELECT row_version = 2 AND definition_version = 2
    FROM public.exercises
    WHERE id = '10000000-0000-0000-0000-000000000001'
  ),
  'one exercise tree replacement advances row and definition versions exactly once'
);

INSERT INTO pg_temp.assessment_results (kind, payload)
SELECT
  'exercise-multiple',
  private.replace_draft_exercise_definition(
    '10000000-0000-0000-0000-000000000002',
    1,
    pg_catalog.jsonb_build_object(
      'options',
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('clientRef', 'first', 'labelMarkdown', 'First'),
        pg_catalog.jsonb_build_object('clientRef', 'second', 'labelMarkdown', 'Second')
      ),
      'answerSpec',
      pg_catalog.jsonb_build_object(
        'correctOptionRefs',
        pg_catalog.jsonb_build_array('second', 'first')
      ),
      'feedbackCorrectMarkdown',
      NULL,
      'feedbackIncorrectMarkdown',
      NULL
    )
  );

SELECT extensions.ok(
  (
    WITH stored_ids AS (
      SELECT item.value, item.ordinality
      FROM private.exercise_answer_keys AS answer_key
      CROSS JOIN LATERAL pg_catalog.jsonb_array_elements_text(
        answer_key.answer_spec -> 'correctOptionIds'
      ) WITH ORDINALITY AS item(value, ordinality)
      WHERE answer_key.exercise_id = '10000000-0000-0000-0000-000000000002'::uuid
    )
    SELECT pg_catalog.array_agg(value ORDER BY ordinality)
      = pg_catalog.array_agg(value ORDER BY value COLLATE "C")
    FROM stored_ids
  ),
  'multiple-choice answer UUIDs are stored in ascending UUID-text order'
);

INSERT INTO pg_temp.assessment_results (kind, payload)
SELECT
  'exercise-short',
  private.replace_draft_exercise_definition(
    '10000000-0000-0000-0000-000000000003',
    1,
    pg_catalog.jsonb_build_object(
      'options',
      '[]'::jsonb,
      'answerSpec',
      pg_catalog.jsonb_build_object(
        'acceptedAnswers',
        pg_catalog.jsonb_build_array(E'  RĂSPUNS\tCORECT  '),
        'normalization',
        'nfkc_ascii_ws_ascii_lower_v1'
      ),
      'feedbackCorrectMarkdown',
      NULL,
      'feedbackIncorrectMarkdown',
      NULL
    )
  );

SELECT extensions.ok(
  (
    SELECT answer_key.answer_spec = pg_catalog.jsonb_build_object(
      'acceptedAnswers',
      pg_catalog.jsonb_build_array('rĂspuns corect'),
      'normalization',
      'nfkc_ascii_ws_ascii_lower_v1'
    )
    FROM private.exercise_answer_keys AS answer_key
    WHERE answer_key.exercise_id = '10000000-0000-0000-0000-000000000003'::uuid
  ),
  'short-text authoring input is normalized before its private answer key is stored'
);

INSERT INTO pg_temp.assessment_results (kind, payload)
SELECT
  'exercise-rollback-base',
  private.replace_draft_exercise_definition(
    '10000000-0000-0000-0000-000000000005',
    1,
    pg_catalog.jsonb_build_object(
      'options',
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('clientRef', 'keep-a', 'labelMarkdown', 'Keep A'),
        pg_catalog.jsonb_build_object('clientRef', 'keep-b', 'labelMarkdown', 'Keep B')
      ),
      'answerSpec',
      pg_catalog.jsonb_build_object('correctOptionRef', 'keep-a'),
      'feedbackCorrectMarkdown',
      NULL,
      'feedbackIncorrectMarkdown',
      NULL
    )
  );

DO $exercise_replacement_rejections$
DECLARE
  v_row_version integer;
  v_definition_version integer;
  v_option_count integer;
  v_answer_spec jsonb;
  v_rejected boolean := false;
BEGIN
  SELECT exercise.row_version, exercise.definition_version, pg_catalog.count(option_entry.*), answer_key.answer_spec
  INTO v_row_version, v_definition_version, v_option_count, v_answer_spec
  FROM public.exercises AS exercise
  LEFT JOIN public.exercise_options AS option_entry
    ON option_entry.exercise_id = exercise.id
  LEFT JOIN private.exercise_answer_keys AS answer_key
    ON answer_key.exercise_id = exercise.id
  WHERE exercise.id = '10000000-0000-0000-0000-000000000005'::uuid
  GROUP BY exercise.row_version, exercise.definition_version, answer_key.answer_spec;

  BEGIN
    PERFORM private.replace_draft_exercise_definition(
      '10000000-0000-0000-0000-000000000005',
      v_row_version,
      pg_catalog.jsonb_build_object(
        'options',
        pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('clientRef', 'only', 'labelMarkdown', 'Only')
        ),
        'answerSpec',
        pg_catalog.jsonb_build_object('correctOptionRef', 'missing'),
        'feedbackCorrectMarkdown',
        NULL,
        'feedbackIncorrectMarkdown',
        NULL
      )
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'foreign client reference must reject replacement';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.exercises AS exercise
    LEFT JOIN public.exercise_options AS option_entry
      ON option_entry.exercise_id = exercise.id
    LEFT JOIN private.exercise_answer_keys AS answer_key
      ON answer_key.exercise_id = exercise.id
    WHERE exercise.id = '10000000-0000-0000-0000-000000000005'::uuid
    GROUP BY exercise.row_version, exercise.definition_version, answer_key.answer_spec
    HAVING exercise.row_version = v_row_version
      AND exercise.definition_version = v_definition_version
      AND pg_catalog.count(option_entry.*) = v_option_count
      AND answer_key.answer_spec IS NOT DISTINCT FROM v_answer_spec
  ) THEN
    RAISE EXCEPTION 'invalid replacement must roll back every tree change';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.replace_draft_exercise_definition(
      '10000000-0000-0000-0000-000000000005',
      v_row_version - 1,
      pg_catalog.jsonb_build_object(
        'options',
        '[]'::jsonb,
        'answerSpec',
        NULL,
        'feedbackCorrectMarkdown',
        NULL,
        'feedbackIncorrectMarkdown',
        NULL
      )
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'stale replacement must reject';
  END IF;
END;
$exercise_replacement_rejections$;

SELECT extensions.ok(TRUE, 'invalid and stale exercise replacements reject atomically without changing the prior tree');

DO $exercise_input_rejections$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM private.replace_draft_exercise_definition(
      '10000000-0000-0000-0000-000000000005',
      2,
      pg_catalog.jsonb_build_object(
        'options',
        pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object('clientRef', 'dup', 'labelMarkdown', 'One'),
          pg_catalog.jsonb_build_object('clientRef', 'dup', 'labelMarkdown', 'Two')
        ),
        'answerSpec',
        NULL,
        'feedbackCorrectMarkdown',
        NULL,
        'feedbackIncorrectMarkdown',
        NULL
      )
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'duplicate client references must reject';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.replace_draft_exercise_definition(
      '10000000-0000-0000-0000-000000000005',
      2,
      pg_catalog.jsonb_build_object(
        'options',
        '[]'::jsonb,
        'answerSpec',
        NULL,
        'feedbackCorrectMarkdown',
        NULL,
        'feedbackIncorrectMarkdown',
        NULL,
        'position',
        0
      )
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'explicit client position must reject';
  END IF;
END;
$exercise_input_rejections$;

SELECT extensions.ok(TRUE, 'duplicate client refs and explicit child positions are rejected before any exercise child mutation');

UPDATE public.exercises
SET status = 'archived'::public.content_status
WHERE id = '10000000-0000-0000-0000-000000000005'::uuid;

DO $archived_timestamp_rejection$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    UPDATE public.exercises
    SET published_at = pg_catalog.now()
    WHERE id = '10000000-0000-0000-0000-000000000005'::uuid;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'archived never-published exercise gained a publication timestamp';
  END IF;
END;
$archived_timestamp_rejection$;

SELECT extensions.ok(
  (
    SELECT status = 'archived'::public.content_status
      AND published_at IS NULL
    FROM public.exercises
    WHERE id = '10000000-0000-0000-0000-000000000005'
  ),
  'never-published archived content cannot gain a false publication timestamp later'
);

INSERT INTO pg_temp.assessment_results (kind, payload)
SELECT
  'quiz-valid',
  private.replace_draft_quiz_definition(
    '20000000-0000-0000-0000-000000000001',
    1,
    pg_catalog.jsonb_build_object(
      'questions',
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'clientRef', 'question-one',
          'promptMarkdown', 'One?',
          'questionType', 'single_choice',
          'points', 5,
          'options', pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('clientRef', 'shared-a', 'labelMarkdown', 'One A'),
            pg_catalog.jsonb_build_object('clientRef', 'shared-b', 'labelMarkdown', 'One B')
          ),
          'answerSpec', pg_catalog.jsonb_build_object('correctOptionRef', 'shared-a'),
          'feedbackCorrectMarkdown', NULL,
          'feedbackIncorrectMarkdown', NULL
        ),
        pg_catalog.jsonb_build_object(
          'clientRef', 'question-two',
          'promptMarkdown', 'Two?',
          'questionType', 'multiple_choice',
          'points', 5,
          'options', pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object('clientRef', 'shared-a', 'labelMarkdown', 'Two A'),
            pg_catalog.jsonb_build_object('clientRef', 'shared-b', 'labelMarkdown', 'Two B')
          ),
          'answerSpec', pg_catalog.jsonb_build_object(
            'correctOptionRefs', pg_catalog.jsonb_build_array('shared-b', 'shared-a')
          ),
          'feedbackCorrectMarkdown', NULL,
          'feedbackIncorrectMarkdown', NULL
        )
      )
    )
  );

SELECT extensions.ok(
  (
    SELECT row_version = 2 AND definition_version = 2
    FROM public.quizzes
    WHERE id = '20000000-0000-0000-0000-000000000001'
  )
    AND (
      SELECT pg_catalog.count(*) = 2
      FROM public.quiz_questions
      WHERE quiz_id = '20000000-0000-0000-0000-000000000001'::uuid
    )
    AND (
      SELECT pg_catalog.count(*) = 4
      FROM public.quiz_question_options AS option_entry
      JOIN public.quiz_questions AS question
        ON question.id = option_entry.question_id
      WHERE question.quiz_id = '20000000-0000-0000-0000-000000000001'::uuid
    ),
  'one quiz tree replacement atomically creates its question and option tree and advances both versions once'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(DISTINCT mapping.value ->> 'id') = 2
    FROM pg_temp.assessment_results AS result
    CROSS JOIN LATERAL pg_catalog.jsonb_array_elements(
      result.payload -> 'optionIdMappings'
    ) AS mapping(value)
    WHERE result.kind = 'quiz-valid'
      AND mapping.value ->> 'clientRef' = 'shared-a'
  )
    AND NOT EXISTS (
      SELECT 1
      FROM private.quiz_question_answer_keys AS answer_key
      WHERE answer_key.answer_spec::text LIKE '%shared-%'
    ),
  'option client references are scoped per question and never persist in quiz keys'
);

DO $direct_draft_tree_write_rejections$
DECLARE
  v_rejected boolean := false;
  v_exercise_row_version integer;
  v_exercise_definition_version integer;
  v_exercise_option_id uuid;
  v_exercise_answer_spec jsonb;
  v_exercise_option_count integer;
  v_exercise_key_count integer;
  v_quiz_row_version integer;
  v_quiz_definition_version integer;
  v_quiz_question_id uuid;
  v_quiz_option_id uuid;
  v_quiz_answer_spec jsonb;
  v_quiz_question_count integer;
  v_quiz_option_count integer;
  v_quiz_key_count integer;
BEGIN
  SELECT exercise.row_version, exercise.definition_version
  INTO v_exercise_row_version, v_exercise_definition_version
  FROM public.exercises AS exercise
  WHERE exercise.id = '10000000-0000-0000-0000-000000000001'::uuid;
  SELECT option_entry.id
  INTO v_exercise_option_id
  FROM public.exercise_options AS option_entry
  WHERE option_entry.exercise_id = '10000000-0000-0000-0000-000000000001'::uuid
  ORDER BY option_entry.position
  LIMIT 1;
  SELECT answer_key.answer_spec
  INTO v_exercise_answer_spec
  FROM private.exercise_answer_keys AS answer_key
  WHERE answer_key.exercise_id = '10000000-0000-0000-0000-000000000001'::uuid;
  SELECT pg_catalog.count(*)
  INTO v_exercise_option_count
  FROM public.exercise_options AS option_entry
  WHERE option_entry.exercise_id = '10000000-0000-0000-0000-000000000001'::uuid;
  SELECT pg_catalog.count(*)
  INTO v_exercise_key_count
  FROM private.exercise_answer_keys AS answer_key
  WHERE answer_key.exercise_id = '10000000-0000-0000-0000-000000000001'::uuid;

  SELECT quiz.row_version, quiz.definition_version
  INTO v_quiz_row_version, v_quiz_definition_version
  FROM public.quizzes AS quiz
  WHERE quiz.id = '20000000-0000-0000-0000-000000000001'::uuid;
  SELECT question.id
  INTO v_quiz_question_id
  FROM public.quiz_questions AS question
  WHERE question.quiz_id = '20000000-0000-0000-0000-000000000001'::uuid
  ORDER BY question.position
  LIMIT 1;
  SELECT option_entry.id
  INTO v_quiz_option_id
  FROM public.quiz_question_options AS option_entry
  WHERE option_entry.question_id = v_quiz_question_id
  ORDER BY option_entry.position
  LIMIT 1;
  SELECT answer_key.answer_spec
  INTO v_quiz_answer_spec
  FROM private.quiz_question_answer_keys AS answer_key
  WHERE answer_key.question_id = v_quiz_question_id;
  SELECT pg_catalog.count(*)
  INTO v_quiz_question_count
  FROM public.quiz_questions AS question
  WHERE question.quiz_id = '20000000-0000-0000-0000-000000000001'::uuid;
  SELECT pg_catalog.count(*)
  INTO v_quiz_option_count
  FROM public.quiz_question_options AS option_entry
  JOIN public.quiz_questions AS question
    ON question.id = option_entry.question_id
  WHERE question.quiz_id = '20000000-0000-0000-0000-000000000001'::uuid;
  SELECT pg_catalog.count(*)
  INTO v_quiz_key_count
  FROM private.quiz_question_answer_keys AS answer_key
  JOIN public.quiz_questions AS question
    ON question.id = answer_key.question_id
  WHERE question.quiz_id = '20000000-0000-0000-0000-000000000001'::uuid;

  BEGIN
    INSERT INTO public.exercise_options (exercise_id, label_markdown, position)
    VALUES ('10000000-0000-0000-0000-000000000001', 'Injected exercise option', 99);
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft exercise option insertion must reject';
  END IF;

  v_rejected := false;
  BEGIN
    UPDATE public.exercise_options
    SET label_markdown = 'Changed directly'
    WHERE id = v_exercise_option_id;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft exercise option update must reject';
  END IF;

  v_rejected := false;
  BEGIN
    DELETE FROM public.exercise_options
    WHERE id = v_exercise_option_id;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft exercise option deletion must reject';
  END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO private.exercise_answer_keys (exercise_id, answer_spec)
    VALUES ('10000000-0000-0000-0000-000000000001', v_exercise_answer_spec);
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft exercise key insertion must reject';
  END IF;

  v_rejected := false;
  BEGIN
    UPDATE private.exercise_answer_keys
    SET feedback_correct_markdown = 'Changed directly'
    WHERE exercise_id = '10000000-0000-0000-0000-000000000001'::uuid;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft exercise key update must reject';
  END IF;

  v_rejected := false;
  BEGIN
    DELETE FROM private.exercise_answer_keys
    WHERE exercise_id = '10000000-0000-0000-0000-000000000001'::uuid;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft exercise key deletion must reject';
  END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.quiz_questions (quiz_id, prompt_markdown, question_type, position, points)
    VALUES ('20000000-0000-0000-0000-000000000001', 'Injected question?', 'single_choice', 99, 1);
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft quiz question insertion must reject';
  END IF;

  v_rejected := false;
  BEGIN
    UPDATE public.quiz_questions
    SET prompt_markdown = 'Changed directly?'
    WHERE id = v_quiz_question_id;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft quiz question update must reject';
  END IF;

  v_rejected := false;
  BEGIN
    DELETE FROM public.quiz_questions
    WHERE id = v_quiz_question_id;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft quiz question deletion must reject';
  END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO public.quiz_question_options (question_id, label_markdown, position)
    VALUES (v_quiz_question_id, 'Injected quiz option', 99);
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft quiz option insertion must reject';
  END IF;

  v_rejected := false;
  BEGIN
    UPDATE public.quiz_question_options
    SET label_markdown = 'Changed directly'
    WHERE id = v_quiz_option_id;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft quiz option update must reject';
  END IF;

  v_rejected := false;
  BEGIN
    DELETE FROM public.quiz_question_options
    WHERE id = v_quiz_option_id;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft quiz option deletion must reject';
  END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO private.quiz_question_answer_keys (question_id, answer_spec)
    VALUES (v_quiz_question_id, v_quiz_answer_spec);
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft quiz key insertion must reject';
  END IF;

  v_rejected := false;
  BEGIN
    UPDATE private.quiz_question_answer_keys
    SET feedback_correct_markdown = 'Changed directly'
    WHERE question_id = v_quiz_question_id;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft quiz key update must reject';
  END IF;

  v_rejected := false;
  BEGIN
    DELETE FROM private.quiz_question_answer_keys
    WHERE question_id = v_quiz_question_id;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct draft quiz key deletion must reject';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.exercises AS exercise
    WHERE exercise.id = '10000000-0000-0000-0000-000000000001'::uuid
      AND exercise.row_version = v_exercise_row_version
      AND exercise.definition_version = v_exercise_definition_version
  )
    OR NOT EXISTS (
      SELECT 1
      FROM public.quizzes AS quiz
      WHERE quiz.id = '20000000-0000-0000-0000-000000000001'::uuid
        AND quiz.row_version = v_quiz_row_version
        AND quiz.definition_version = v_quiz_definition_version
    )
    OR (
      SELECT pg_catalog.count(*)
      FROM public.exercise_options AS option_entry
      WHERE option_entry.exercise_id = '10000000-0000-0000-0000-000000000001'::uuid
    ) <> v_exercise_option_count
    OR (
      SELECT pg_catalog.count(*)
      FROM private.exercise_answer_keys AS answer_key
      WHERE answer_key.exercise_id = '10000000-0000-0000-0000-000000000001'::uuid
    ) <> v_exercise_key_count
    OR (
      SELECT pg_catalog.count(*)
      FROM public.quiz_questions AS question
      WHERE question.quiz_id = '20000000-0000-0000-0000-000000000001'::uuid
    ) <> v_quiz_question_count
    OR (
      SELECT pg_catalog.count(*)
      FROM public.quiz_question_options AS option_entry
      JOIN public.quiz_questions AS question
        ON question.id = option_entry.question_id
      WHERE question.quiz_id = '20000000-0000-0000-0000-000000000001'::uuid
    ) <> v_quiz_option_count
    OR (
      SELECT pg_catalog.count(*)
      FROM private.quiz_question_answer_keys AS answer_key
      JOIN public.quiz_questions AS question
        ON question.id = answer_key.question_id
      WHERE question.quiz_id = '20000000-0000-0000-0000-000000000001'::uuid
    ) <> v_quiz_key_count THEN
    RAISE EXCEPTION 'rejected direct draft writes must leave every assessment tree and version unchanged';
  END IF;
END;
$direct_draft_tree_write_rejections$;

SELECT extensions.ok(
  TRUE,
  'all direct draft child and private-key inserts, updates, and deletes are rejected without changing either tree'
);

DO $cross_question_ref_rejection$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM private.replace_draft_quiz_definition(
      '20000000-0000-0000-0000-000000000002',
      1,
      pg_catalog.jsonb_build_object(
        'questions',
        pg_catalog.jsonb_build_array(
          pg_catalog.jsonb_build_object(
            'clientRef', 'left-question',
            'promptMarkdown', 'Left?',
            'questionType', 'single_choice',
            'points', 1,
            'options', pg_catalog.jsonb_build_array(
              pg_catalog.jsonb_build_object('clientRef', 'left-option', 'labelMarkdown', 'Left')
            ),
            'answerSpec', pg_catalog.jsonb_build_object('correctOptionRef', 'left-option'),
            'feedbackCorrectMarkdown', NULL,
            'feedbackIncorrectMarkdown', NULL
          ),
          pg_catalog.jsonb_build_object(
            'clientRef', 'right-question',
            'promptMarkdown', 'Right?',
            'questionType', 'single_choice',
            'points', 1,
            'options', pg_catalog.jsonb_build_array(
              pg_catalog.jsonb_build_object('clientRef', 'right-option', 'labelMarkdown', 'Right')
            ),
            'answerSpec', pg_catalog.jsonb_build_object('correctOptionRef', 'left-option'),
            'feedbackCorrectMarkdown', NULL,
            'feedbackIncorrectMarkdown', NULL
          )
        )
      )
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'cross-question option reference must reject';
  END IF;
END;
$cross_question_ref_rejection$;

SELECT extensions.ok(TRUE, 'quiz authoring rejects option references from another question');

DO $empty_quiz_publish_rejection$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    UPDATE public.quizzes
    SET status = 'published'::public.content_status,
        published_at = pg_catalog.now()
    WHERE id = '20000000-0000-0000-0000-000000000003'::uuid;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'empty quiz publication must reject';
  END IF;
END;
$empty_quiz_publish_rejection$;

SELECT extensions.ok(
  (
    SELECT status = 'draft'::public.content_status
      AND row_version = 1
      AND definition_version = 1
    FROM public.quizzes
    WHERE id = '20000000-0000-0000-0000-000000000003'
  ),
  'failed empty-quiz publication rolls back lifecycle and version changes'
);

DO $python_publish_rejection$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    UPDATE public.exercises
    SET status = 'published'::public.content_status,
        published_at = pg_catalog.now()
    WHERE id = '10000000-0000-0000-0000-000000000004'::uuid;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'python publication without a WASM definition must reject';
  END IF;
END;
$python_publish_rejection$;

SELECT extensions.ok(
  (
    SELECT status = 'draft'::public.content_status
      AND published_at IS NULL
    FROM public.exercises
    WHERE id = '10000000-0000-0000-0000-000000000004'
  ),
  'python exercises fail closed until SUP-WASM-001 supplies a digest-pinned definition'
);

DO $incomplete_definition_publish_rejections$
DECLARE
  v_rejected boolean := false;
BEGIN
  INSERT INTO public.exercises (
    id,
    chapter_id,
    title,
    prompt_markdown,
    exercise_type,
    position,
    points
  )
  VALUES
    ('10000000-0000-0000-0000-000000000009', 'b1000000-0000-0000-0000-000000000000', 'One-option exercise', 'This choice definition is incomplete.', 'single_choice', 8, 1),
    ('10000000-0000-0000-0000-000000000010', 'b1000000-0000-0000-0000-000000000000', 'Short exercise with option', 'This short-text definition is incomplete.', 'short_text', 9, 1),
    ('10000000-0000-0000-0000-000000000011', 'b1000000-0000-0000-0000-000000000000', 'Exercise without key', 'This definition has no key.', 'single_choice', 10, 1);
  INSERT INTO public.quizzes (
    id,
    chapter_id,
    slug,
    title,
    instructions_markdown,
    position
  )
  VALUES (
    '20000000-0000-0000-0000-000000000005',
    'b1000000-0000-0000-0000-000000000000',
    'one-option-question-quiz',
    'One option question quiz',
    'This quiz has an incomplete choice question.',
    4
  );

  PERFORM private.replace_draft_exercise_definition(
    '10000000-0000-0000-0000-000000000009',
    1,
    pg_catalog.jsonb_build_object(
      'options',
      pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object('clientRef', 'only', 'labelMarkdown', 'Only option')
      ),
      'answerSpec',
      pg_catalog.jsonb_build_object('correctOptionRef', 'only'),
      'feedbackCorrectMarkdown',
      NULL,
      'feedbackIncorrectMarkdown',
      NULL
    )
  );

  PERFORM pg_catalog.set_config(
    'coditza.assessment_tree_root',
    'exercise:10000000-0000-0000-0000-000000000010',
    true
  );
  INSERT INTO public.exercise_options (id, exercise_id, label_markdown, position)
  VALUES (
    '34000000-0000-0000-0000-000000000001',
    '10000000-0000-0000-0000-000000000010',
    'Forbidden short-text option',
    0
  );
  INSERT INTO private.exercise_answer_keys (exercise_id, answer_spec)
  VALUES (
    '10000000-0000-0000-0000-000000000010',
    pg_catalog.jsonb_build_object(
      'acceptedAnswers',
      pg_catalog.jsonb_build_array('valid answer'),
      'normalization',
      'nfkc_ascii_ws_ascii_lower_v1'
    )
  );

  PERFORM pg_catalog.set_config(
    'coditza.assessment_tree_root',
    'quiz:20000000-0000-0000-0000-000000000005',
    true
  );
  INSERT INTO public.quiz_questions (id, quiz_id, prompt_markdown, question_type, position, points)
  VALUES (
    '42000000-0000-0000-0000-000000000001',
    '20000000-0000-0000-0000-000000000005',
    'Only one answer?',
    'single_choice',
    0,
    1
  );
  INSERT INTO public.quiz_question_options (id, question_id, label_markdown, position)
  VALUES (
    '52000000-0000-0000-0000-000000000001',
    '42000000-0000-0000-0000-000000000001',
    'Only quiz option',
    0
  );
  INSERT INTO private.quiz_question_answer_keys (question_id, answer_spec)
  VALUES (
    '42000000-0000-0000-0000-000000000001',
    pg_catalog.jsonb_build_object(
      'correctOptionId',
      '52000000-0000-0000-0000-000000000001'
    )
  );
  PERFORM pg_catalog.set_config('coditza.assessment_tree_root', '', true);

  BEGIN
    UPDATE public.exercises
    SET status = 'published'::public.content_status,
        published_at = pg_catalog.now()
    WHERE id = '10000000-0000-0000-0000-000000000009'::uuid;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'one-option choice exercise publication must reject';
  END IF;

  v_rejected := false;
  BEGIN
    UPDATE public.exercises
    SET status = 'published'::public.content_status,
        published_at = pg_catalog.now()
    WHERE id = '10000000-0000-0000-0000-000000000010'::uuid;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'short-text exercise publication with options must reject';
  END IF;

  v_rejected := false;
  BEGIN
    UPDATE public.exercises
    SET status = 'published'::public.content_status,
        published_at = pg_catalog.now()
    WHERE id = '10000000-0000-0000-0000-000000000011'::uuid;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'exercise publication without an answer key must reject';
  END IF;

  v_rejected := false;
  BEGIN
    UPDATE public.quizzes
    SET status = 'published'::public.content_status,
        published_at = pg_catalog.now()
    WHERE id = '20000000-0000-0000-0000-000000000005'::uuid;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'quiz publication with a one-option choice question must reject';
  END IF;
END;
$incomplete_definition_publish_rejections$;

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(status = 'draft'::public.content_status)
      AND pg_catalog.bool_and(published_at IS NULL)
    FROM public.exercises
    WHERE id IN (
      '10000000-0000-0000-0000-000000000009'::uuid,
      '10000000-0000-0000-0000-000000000010'::uuid,
      '10000000-0000-0000-0000-000000000011'::uuid
    )
  )
    AND (
      SELECT status = 'draft'::public.content_status
        AND published_at IS NULL
      FROM public.quizzes
      WHERE id = '20000000-0000-0000-0000-000000000005'::uuid
    ),
  'exercise and quiz publication reject incomplete choice, short-text, and answer-key definitions atomically'
);

UPDATE public.exercises
SET status = 'published'::public.content_status,
    published_at = pg_catalog.now()
WHERE id = '10000000-0000-0000-0000-000000000001'::uuid;

SELECT extensions.ok(
  (
    SELECT status = 'published'::public.content_status
      AND published_at IS NOT NULL
      AND row_version = 3
      AND definition_version = 2
    FROM public.exercises
    WHERE id = '10000000-0000-0000-0000-000000000001'
  ),
  'a complete scalar exercise publishes without changing its frozen definition version'
);

DO $published_exercise_immutability$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    UPDATE public.exercises
    SET title = 'Changed published title'
    WHERE id = '10000000-0000-0000-0000-000000000001'::uuid;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'published exercise root mutation must reject';
  END IF;

  v_rejected := false;
  BEGIN
    UPDATE public.exercise_options
    SET label_markdown = 'Changed option'
    WHERE exercise_id = '10000000-0000-0000-0000-000000000001'::uuid;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'published option mutation must reject';
  END IF;

  v_rejected := false;
  BEGIN
    DELETE FROM private.exercise_answer_keys
    WHERE exercise_id = '10000000-0000-0000-0000-000000000001'::uuid;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'published answer-key mutation must reject';
  END IF;
END;
$published_exercise_immutability$;

SELECT extensions.ok(TRUE, 'published exercise roots, options, and private keys are immutable');

DO $published_exercise_replacer_rejection$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM private.replace_draft_exercise_definition(
      '10000000-0000-0000-0000-000000000001',
      3,
      pg_catalog.jsonb_build_object(
        'options', '[]'::jsonb,
        'answerSpec', NULL,
        'feedbackCorrectMarkdown', NULL,
        'feedbackIncorrectMarkdown', NULL
      )
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'published replacement must reject';
  END IF;
END;
$published_exercise_replacer_rejection$;

SELECT extensions.ok(TRUE, 'the private exercise replacer rejects published history');

UPDATE public.quizzes
SET status = 'published'::public.content_status,
    published_at = pg_catalog.now()
WHERE id = '20000000-0000-0000-0000-000000000001'::uuid;

SELECT extensions.ok(
  (
    SELECT status = 'published'::public.content_status
      AND row_version = 3
      AND definition_version = 2
    FROM public.quizzes
    WHERE id = '20000000-0000-0000-0000-000000000001'
  ),
  'a complete quiz publishes without changing its frozen definition version'
);

DO $published_quiz_immutability$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    DELETE FROM public.quiz_questions
    WHERE quiz_id = '20000000-0000-0000-0000-000000000001'::uuid;
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'published quiz question mutation must reject';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.replace_draft_quiz_definition(
      '20000000-0000-0000-0000-000000000001',
      3,
      pg_catalog.jsonb_build_object('questions', '[]'::jsonb)
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'published quiz replacement must reject';
  END IF;
END;
$published_quiz_immutability$;

SELECT extensions.ok(TRUE, 'published quiz questions and the private quiz replacer are immutable');

SET CONSTRAINTS exercises_chapter_position_key DEFERRED;
UPDATE public.exercises
SET position = CASE id
  WHEN '10000000-0000-0000-0000-000000000002'::uuid THEN 2
  WHEN '10000000-0000-0000-0000-000000000003'::uuid THEN 1
END
WHERE id IN (
  '10000000-0000-0000-0000-000000000002',
  '10000000-0000-0000-0000-000000000003'
);
SET CONSTRAINTS exercises_chapter_position_key IMMEDIATE;

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(position ORDER BY id) = ARRAY[2, 1]::integer[]
    FROM public.exercises
    WHERE id IN (
      '10000000-0000-0000-0000-000000000002',
      '10000000-0000-0000-0000-000000000003'
    )
  )
    AND (
      SELECT definition_version = 2
      FROM public.exercises
      WHERE id = '10000000-0000-0000-0000-000000000002'
    ),
  'deferrable assessment sibling reorder changes row version without changing definition version'
);

DO $assessment_parent_restrict$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    DELETE FROM public.chapters
    WHERE id = 'b1000000-0000-0000-0000-000000000000'::uuid;
  EXCEPTION WHEN foreign_key_violation THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'chapter with assessment descendants must not delete';
  END IF;
END;
$assessment_parent_restrict$;

SELECT extensions.ok(TRUE, 'assessment parent foreign keys restrict chapter deletion');

RESET ROLE;

SET LOCAL ROLE service_role;

DO $private_key_read_denial$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM 1 FROM private.exercise_answer_keys LIMIT 1;
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'service_role unexpectedly selected private exercise keys';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM 1 FROM private.quiz_question_answer_keys LIMIT 1;
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'service_role unexpectedly selected private quiz keys';
  END IF;
END;
$private_key_read_denial$;

RESET ROLE;

SELECT extensions.ok(TRUE, 'service-role direct selects of both private answer-key tables fail with privilege denial');

SELECT * FROM extensions.finish();

ROLLBACK;
