BEGIN;

-- SUP-FUNCTIONS-001 learner-facade proof. Fixtures are transaction-local,
-- and the only runtime role used for successful calls is service_role.
GRANT USAGE ON SCHEMA extensions TO coditza_owner;

SELECT extensions.plan(32);

SET LOCAL ROLE coditza_owner;
DO $normalization_golden_vectors$
DECLARE
  v_vector record;
BEGIN
  FOR v_vector IN
    SELECT *
    FROM (
      VALUES
        ('Café'::text, 'café'::text),
        ('Café'::text, 'café'::text),
        (E'A\tB\n C'::text, 'a b c'::text),
        (E' \r\n\t '::text, ''::text),
        ('PyThOn'::text, 'python'::text),
        ('İSTANBUL'::text, 'İstanbul'::text)
    ) AS golden_vector(input, expected_output)
  LOOP
    IF private.normalize_short_text(v_vector.input)
      IS DISTINCT FROM v_vector.expected_output THEN
      RAISE EXCEPTION 'normalization golden vector failed';
    END IF;
  END LOOP;
END;
$normalization_golden_vectors$;
RESET ROLE;
SELECT extensions.ok(
  TRUE,
  'SQL normalization matches the nfkc_ascii_ws_ascii_lower_v1 golden vectors shared with assessment TypeScript'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 5
      AND pg_catalog.bool_and(
        procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
        AND procedure_entry.prosecdef
        AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
      )
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid IN (
      'public.assessment_submit_exercise_attempt(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure,
      'public.assessment_start_quiz_attempt(uuid,uuid,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure,
      'public.assessment_save_quiz_answer(uuid,uuid,uuid,jsonb,uuid)'::pg_catalog.regprocedure,
      'public.assessment_remove_quiz_answer(uuid,uuid,uuid,uuid)'::pg_catalog.regprocedure,
      'public.assessment_submit_quiz_attempt(uuid,uuid,uuid)'::pg_catalog.regprocedure
    )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM (
      VALUES (
        'public.assessment_submit_exercise_attempt(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure
      ), (
        'public.assessment_start_quiz_attempt(uuid,uuid,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure
      ), (
        'public.assessment_save_quiz_answer(uuid,uuid,uuid,jsonb,uuid)'::pg_catalog.regprocedure
      ), (
        'public.assessment_remove_quiz_answer(uuid,uuid,uuid,uuid)'::pg_catalog.regprocedure
      ), (
        'public.assessment_submit_quiz_attempt(uuid,uuid,uuid)'::pg_catalog.regprocedure
      )
    ) AS facade(procedure_oid)
    CROSS JOIN (
      VALUES ('anon'), ('authenticated'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_function_privilege(
      runtime_role.rolname,
      facade.procedure_oid,
      'EXECUTE'
    )
  )
  AND (
    SELECT pg_catalog.count(*) = 5
    FROM (
      VALUES (
        'public.assessment_submit_exercise_attempt(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure
      ), (
        'public.assessment_start_quiz_attempt(uuid,uuid,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure
      ), (
        'public.assessment_save_quiz_answer(uuid,uuid,uuid,jsonb,uuid)'::pg_catalog.regprocedure
      ), (
        'public.assessment_remove_quiz_answer(uuid,uuid,uuid,uuid)'::pg_catalog.regprocedure
      ), (
        'public.assessment_submit_quiz_attempt(uuid,uuid,uuid)'::pg_catalog.regprocedure
      )
    ) AS facade(procedure_oid)
    WHERE pg_catalog.has_function_privilege(
      'service_role',
      facade.procedure_oid,
      'EXECUTE'
    )
  ),
  'assessment learner facades are owner-controlled SECURITY DEFINER entrypoints granted only to service_role'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
        AND procedure_entry.prosecdef
        AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
      )
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid IN (
      'public.progress_set_theory_completion(uuid,uuid,boolean,uuid)'::pg_catalog.regprocedure,
      'public.progress_list_own_modules(uuid,integer,uuid,integer)'::pg_catalog.regprocedure,
      'public.progress_get_own_module(uuid,uuid)'::pg_catalog.regprocedure
    )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM (
      VALUES (
        'public.progress_set_theory_completion(uuid,uuid,boolean,uuid)'::pg_catalog.regprocedure
      ), (
        'public.progress_list_own_modules(uuid,integer,uuid,integer)'::pg_catalog.regprocedure
      ), (
        'public.progress_get_own_module(uuid,uuid)'::pg_catalog.regprocedure
      )
    ) AS facade(procedure_oid)
    CROSS JOIN (
      VALUES ('anon'), ('authenticated'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_function_privilege(
      runtime_role.rolname,
      facade.procedure_oid,
      'EXECUTE'
    )
  )
  AND (
    SELECT pg_catalog.count(*) = 3
    FROM (
      VALUES (
        'public.progress_set_theory_completion(uuid,uuid,boolean,uuid)'::pg_catalog.regprocedure
      ), (
        'public.progress_list_own_modules(uuid,integer,uuid,integer)'::pg_catalog.regprocedure
      ), (
        'public.progress_get_own_module(uuid,uuid)'::pg_catalog.regprocedure
      )
    ) AS facade(procedure_oid)
    WHERE pg_catalog.has_function_privilege(
      'service_role',
      facade.procedure_oid,
      'EXECUTE'
    )
  ),
  'progress learner facades are owner-controlled SECURITY DEFINER entrypoints granted only to service_role'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
        AND NOT procedure_entry.prosecdef
        AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
      )
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid IN (
      'private.has_role(uuid,public.app_role)'::pg_catalog.regprocedure,
      'private.is_staff(uuid)'::pg_catalog.regprocedure,
      'private.assert_active_staff_actor(uuid)'::pg_catalog.regprocedure
    )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM (
      VALUES (
        'private.has_role(uuid,public.app_role)'::pg_catalog.regprocedure
      ), (
        'private.is_staff(uuid)'::pg_catalog.regprocedure
      ), (
        'private.assert_active_staff_actor(uuid)'::pg_catalog.regprocedure
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
  'staff authorization predicates are owner-controlled private helpers with no runtime execute grant'
);

SELECT extensions.ok(
  (
    SELECT procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
      AND procedure_entry.prosecdef
      AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid =
      'public.curriculum_create_draft_module(uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure
  )
  AND NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_function_privilege(
      runtime_role.rolname,
      'public.curriculum_create_draft_module(uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure,
      'EXECUTE'
    )
  )
  AND pg_catalog.has_function_privilege(
    'service_role',
    'public.curriculum_create_draft_module(uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure,
    'EXECUTE'
  )
  AND (
    SELECT procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
      AND NOT procedure_entry.prosecdef
      AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid =
      'private.lock_module_root_scope()'::pg_catalog.regprocedure
  )
  AND NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_function_privilege(
      runtime_role.rolname,
      'private.lock_module_root_scope()'::pg_catalog.regprocedure,
      'EXECUTE'
    )
  ),
  'draft-module facade is owner-controlled and server-only while its root lock remains private'
);

SELECT extensions.ok(
  (
    SELECT procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
      AND procedure_entry.prosecdef
      AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid =
      'public.curriculum_create_draft_chapter(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure
  )
  AND NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_function_privilege(
      runtime_role.rolname,
      'public.curriculum_create_draft_chapter(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure,
      'EXECUTE'
    )
  )
  AND pg_catalog.has_function_privilege(
    'service_role',
    'public.curriculum_create_draft_chapter(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure,
    'EXECUTE'
  ),
  'draft-chapter facade is owner-controlled, fixed-path, and server-only'
);

SELECT extensions.ok(
  (
    SELECT procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
      AND procedure_entry.prosecdef
      AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid =
      'public.curriculum_create_draft_theory_section(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure
  )
  AND NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_function_privilege(
      runtime_role.rolname,
      'public.curriculum_create_draft_theory_section(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure,
      'EXECUTE'
    )
  )
  AND pg_catalog.has_function_privilege(
    'service_role',
    'public.curriculum_create_draft_theory_section(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure,
    'EXECUTE'
  ),
  'draft-theory-section facade is owner-controlled, fixed-path, and server-only'
);

SELECT extensions.ok(
  (
    SELECT procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
      AND procedure_entry.prosecdef
      AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid =
      'public.assessment_create_draft_exercise(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure
  )
  AND NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_function_privilege(
      runtime_role.rolname,
      'public.assessment_create_draft_exercise(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure,
      'EXECUTE'
    )
  )
  AND pg_catalog.has_function_privilege(
    'service_role',
    'public.assessment_create_draft_exercise(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure,
    'EXECUTE'
  ),
  'draft-exercise facade is owner-controlled, fixed-path, and server-only'
);

SELECT extensions.ok(
  (
    SELECT procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
      AND procedure_entry.prosecdef
      AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid =
      'public.assessment_create_draft_quiz(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure
  )
  AND NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_function_privilege(
      runtime_role.rolname,
      'public.assessment_create_draft_quiz(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure,
      'EXECUTE'
    )
  )
  AND pg_catalog.has_function_privilege(
    'service_role',
    'public.assessment_create_draft_quiz(uuid,uuid,jsonb,uuid,integer,bytea,uuid)'::pg_catalog.regprocedure,
    'EXECUTE'
  ),
  'draft-quiz facade is owner-controlled, fixed-path, and server-only'
);

SELECT extensions.ok(
  (
    SELECT procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
      AND procedure_entry.prosecdef
      AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid =
      'public.assessment_update_draft_exercise(uuid,uuid,integer,jsonb,uuid)'::pg_catalog.regprocedure
  )
  AND NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_function_privilege(
      runtime_role.rolname,
      'public.assessment_update_draft_exercise(uuid,uuid,integer,jsonb,uuid)'::pg_catalog.regprocedure,
      'EXECUTE'
    )
  )
  AND pg_catalog.has_function_privilege(
    'service_role',
    'public.assessment_update_draft_exercise(uuid,uuid,integer,jsonb,uuid)'::pg_catalog.regprocedure,
    'EXECUTE'
  )
  AND (
    SELECT procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
      AND NOT procedure_entry.prosecdef
      AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid =
      'private.apply_draft_exercise_patch(uuid,integer,text,text,public.exercise_type,integer,boolean,boolean,jsonb,uuid)'::pg_catalog.regprocedure
  )
  AND NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_function_privilege(
      runtime_role.rolname,
      'private.apply_draft_exercise_patch(uuid,integer,text,text,public.exercise_type,integer,boolean,boolean,jsonb,uuid)'::pg_catalog.regprocedure,
      'EXECUTE'
    )
  ),
  'draft-exercise PATCH facade is server-only while its root-and-tree helper remains private'
);

SET LOCAL ROLE authenticated;
DO $authenticated_facade_denial$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM *
    FROM public.assessment_submit_exercise_attempt(
      'c3000000-0000-0000-0000-000000000001',
      'c3400000-0000-0000-0000-000000000001',
      '{"text":"yes"}'::jsonb,
      'c3700000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('01', 32), 'hex'),
      'c3a00000-0000-0000-0000-000000000001'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'authenticated role unexpectedly executed a server-only facade';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM public.progress_list_own_modules(
      'c3000000-0000-0000-0000-000000000001',
      NULL,
      NULL,
      1
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'authenticated role unexpectedly executed a progress facade';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM public.assessment_list_own_exercise_attempts(
      'c3000000-0000-0000-0000-000000000001',
      NULL,
      NULL,
      NULL,
      1
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'authenticated role unexpectedly executed a history facade';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_module(
      'c3000000-0000-0000-0000-000000000005',
      '{"slug":"denied-module","title":"Denied module","descriptionMarkdown":"Denied."}'::jsonb,
      'c3e00000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('aa', 32), 'hex'),
      'c3f00000-0000-0000-0000-000000000001'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'authenticated role unexpectedly executed a curriculum authoring facade';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_chapter(
      'c3000000-0000-0000-0000-000000000005',
      'c3120000-0000-0000-0000-000000000001',
      '{"slug":"denied-chapter","title":"Denied chapter","summaryMarkdown":"Denied.","estimatedMinutes":1}'::jsonb,
      'c3e10000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('a1', 32), 'hex'),
      'c3f10000-0000-0000-0000-000000000001'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'authenticated role unexpectedly executed a chapter authoring facade';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_theory_section(
      'c3000000-0000-0000-0000-000000000005',
      'c3230000-0000-0000-0000-000000000001',
      '{"title":"Denied theory section","bodyMarkdown":"Denied.","estimatedMinutes":1}'::jsonb,
      'c3e20000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('a3', 32), 'hex'),
      'c3f20000-0000-0000-0000-000000000001'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'authenticated role unexpectedly executed a theory-section authoring facade';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3250000-0000-0000-0000-000000000001',
      '{"title":"Denied exercise","promptMarkdown":"Denied.","exerciseType":"short_text","points":1,"isRequired":true,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}'::jsonb,
      'c3e30000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('a5', 32), 'hex'),
      'c3f30000-0000-0000-0000-000000000001'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'authenticated role unexpectedly executed an exercise authoring facade';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_quiz(
      'c3000000-0000-0000-0000-000000000005',
      'c3270000-0000-0000-0000-000000000001',
      '{"slug":"denied-quiz","title":"Denied quiz","instructionsMarkdown":"Denied.","passingPercent":70,"maxAttempts":null,"timeLimitSeconds":null,"isRequired":true,"questions":[{"clientRef":"denied-question","promptMarkdown":"Denied.","questionType":"short_text","points":1,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}]}'::jsonb,
      'c3e40000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('a4', 32), 'hex'),
      'c3f40000-0000-0000-0000-000000000001'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'authenticated role unexpectedly executed a quiz authoring facade';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM *
    FROM public.assessment_update_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3430000-0000-0000-0000-000000000001',
      1,
      '{"title":"Denied draft exercise update"}'::jsonb,
      'c3f50000-0000-0000-0000-000000000001'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'authenticated role unexpectedly executed a draft exercise PATCH facade';
  END IF;
END;
$authenticated_facade_denial$;
RESET ROLE;

SET LOCAL ROLE service_role;
DO $private_runtime_denial$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM *
    FROM private.acquire_idempotency_replay(
      'c3000000-0000-0000-0000-000000000001',
      'exercise_submit',
      'c3700000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('01', 32), 'hex')
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'service role unexpectedly executed a private helper';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM *
    FROM private.list_learner_published_chapters(
      'c3000000-0000-0000-0000-000000000001'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'service role unexpectedly executed a private progress helper';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.assert_active_staff_actor(
      'c3000000-0000-0000-0000-000000000001'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'service role unexpectedly executed a private staff helper';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.lock_module_root_scope();
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'service role unexpectedly executed a private curriculum lock helper';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.apply_draft_exercise_patch(
      'c3430000-0000-0000-0000-000000000001',
      1,
      'Denied private patch',
      'Denied private patch.',
      'short_text'::public.exercise_type,
      1,
      true,
      false,
      NULL,
      'c3000000-0000-0000-0000-000000000005'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'service role unexpectedly executed a private draft exercise patch helper';
  END IF;
END;
$private_runtime_denial$;
RESET ROLE;
SELECT extensions.ok(TRUE, 'browser roles cannot execute public facades and service_role cannot execute private helpers');

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
    'c3000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'functions-learner@coditza.invalid',
    '{}'::jsonb,
    '{"displayName":"Functions Learner"}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  ),
  (
    'c3000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'functions-other@coditza.invalid',
    '{}'::jsonb,
    '{"displayName":"Functions Other"}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  ),
  (
    'c3000000-0000-0000-0000-000000000003',
    'authenticated',
    'authenticated',
    'functions-fallback@coditza.invalid',
    '{}'::jsonb,
    '{"displayName":"Functions Fallback"}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  ),
  (
    'c3000000-0000-0000-0000-000000000004',
    'authenticated',
    'authenticated',
    'functions-editor@coditza.invalid',
    '{}'::jsonb,
    '{"displayName":"Functions Editor"}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  ),
  (
    'c3000000-0000-0000-0000-000000000005',
    'authenticated',
    'authenticated',
    'functions-admin@coditza.invalid',
    '{}'::jsonb,
    '{"displayName":"Functions Admin"}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  ),
  (
    'c3000000-0000-0000-0000-000000000006',
    'authenticated',
    'authenticated',
    'functions-held-editor@coditza.invalid',
    '{}'::jsonb,
    '{"displayName":"Functions Held Editor"}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  );

SET LOCAL ROLE coditza_owner;

UPDATE public.profiles
SET role = 'editor'::public.app_role
WHERE id = 'c3000000-0000-0000-0000-000000000004';
UPDATE public.profiles
SET role = 'admin'::public.app_role
WHERE id = 'c3000000-0000-0000-0000-000000000005';
UPDATE public.profiles
SET role = 'editor'::public.app_role,
    security_hold_at = pg_catalog.clock_timestamp()
WHERE id = 'c3000000-0000-0000-0000-000000000006';

DO $staff_authorization_predicates$
DECLARE
  v_learner_rejected boolean := false;
  v_missing_rejected boolean := false;
  v_held_rejected boolean := false;
  v_live_role_rejected boolean := false;
BEGIN
  PERFORM private.assert_active_staff_actor(
    'c3000000-0000-0000-0000-000000000004'
  );
  PERFORM private.assert_active_staff_actor(
    'c3000000-0000-0000-0000-000000000005'
  );

  IF NOT private.has_role(
      'c3000000-0000-0000-0000-000000000004',
      'editor'::public.app_role
    )
    OR private.has_role(
      'c3000000-0000-0000-0000-000000000004',
      'admin'::public.app_role
    )
    OR NOT private.is_staff('c3000000-0000-0000-0000-000000000004')
    OR NOT private.is_staff('c3000000-0000-0000-0000-000000000005')
    OR private.is_staff('c3000000-0000-0000-0000-000000000001') THEN
    RAISE EXCEPTION 'staff role predicates did not read the current profile role';
  END IF;

  BEGIN
    PERFORM private.assert_active_staff_actor(
      'c3000000-0000-0000-0000-000000000001'
    );
  EXCEPTION WHEN raise_exception THEN
    v_learner_rejected := true;
  END;
  BEGIN
    PERFORM private.assert_active_staff_actor(
      'c3000000-0000-0000-0000-000000000999'
    );
  EXCEPTION WHEN raise_exception THEN
    v_missing_rejected := true;
  END;
  BEGIN
    PERFORM private.assert_active_staff_actor(
      'c3000000-0000-0000-0000-000000000006'
    );
  EXCEPTION WHEN raise_exception THEN
    v_held_rejected := true;
  END;

  UPDATE public.profiles
  SET role = 'learner'::public.app_role
  WHERE id = 'c3000000-0000-0000-0000-000000000004';
  BEGIN
    PERFORM private.assert_active_staff_actor(
      'c3000000-0000-0000-0000-000000000004'
    );
  EXCEPTION WHEN raise_exception THEN
    v_live_role_rejected := true;
  END;

  IF NOT v_learner_rejected
    OR NOT v_missing_rejected
    OR NOT v_held_rejected
    OR NOT v_live_role_rejected THEN
    RAISE EXCEPTION
      'staff authorization did not deny learner, absent, held, or live-demoted actors';
  END IF;
END;
$staff_authorization_predicates$;
SELECT extensions.ok(
  TRUE,
  'staff predicates accept active editor/admin profiles and fail closed for learner, absent, held, and live-demoted actors'
);

-- Restore the editor only after the live-demotion proof above, then exercise
-- the first authoring facade with two distinct active staff actors.
SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET role = 'editor'::public.app_role,
    security_hold_at = NULL
WHERE id = 'c3000000-0000-0000-0000-000000000004';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $curriculum_create_draft_module$
DECLARE
  v_editor_first record;
  v_editor_replay record;
  v_admin_first record;
  v_different_hash_rejected boolean := false;
  v_invalid_input_rejected boolean := false;
  v_learner_rejected boolean := false;
  v_missing_key_rejected boolean := false;
BEGIN
  SELECT * INTO v_editor_first
  FROM public.curriculum_create_draft_module(
    'c3000000-0000-0000-0000-000000000004',
    '{"slug":"authoring-editor-module","title":"Authoring editor module","descriptionMarkdown":"Draft content created by an editor."}'::jsonb,
    'c3e00000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('aa', 32), 'hex'),
    'c3f00000-0000-0000-0000-000000000010'
  );
  SELECT * INTO v_editor_replay
  FROM public.curriculum_create_draft_module(
    'c3000000-0000-0000-0000-000000000004',
    '{"slug":"authoring-editor-module","title":"Authoring editor module","descriptionMarkdown":"Draft content created by an editor."}'::jsonb,
    'c3e00000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('aa', 32), 'hex'),
    'c3f00000-0000-0000-0000-000000000011'
  );
  SELECT * INTO v_admin_first
  FROM public.curriculum_create_draft_module(
    'c3000000-0000-0000-0000-000000000005',
    '{"slug":"authoring-admin-module","title":"Authoring admin module","descriptionMarkdown":"Draft content created by an administrator."}'::jsonb,
    'c3e00000-0000-0000-0000-000000000002',
    1,
    pg_catalog.decode(pg_catalog.repeat('bb', 32), 'hex'),
    'c3f00000-0000-0000-0000-000000000012'
  );

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_module(
      'c3000000-0000-0000-0000-000000000004',
      '{"slug":"authoring-editor-module","title":"Authoring editor module","descriptionMarkdown":"Draft content created by an editor."}'::jsonb,
      'c3e00000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('cc', 32), 'hex'),
      'c3f00000-0000-0000-0000-000000000013'
    );
  EXCEPTION WHEN raise_exception THEN
    v_different_hash_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_module(
      'c3000000-0000-0000-0000-000000000005',
      '{"slug":"invalid-module","title":"Invalid module","descriptionMarkdown":"Draft.","status":"published"}'::jsonb,
      'c3e00000-0000-0000-0000-000000000003',
      1,
      pg_catalog.decode(pg_catalog.repeat('dd', 32), 'hex'),
      'c3f00000-0000-0000-0000-000000000014'
    );
  EXCEPTION WHEN raise_exception THEN
    v_invalid_input_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_module(
      'c3000000-0000-0000-0000-000000000001',
      '{"slug":"learner-module","title":"Learner module","descriptionMarkdown":"Learners cannot author."}'::jsonb,
      'c3e00000-0000-0000-0000-000000000004',
      1,
      pg_catalog.decode(pg_catalog.repeat('ee', 32), 'hex'),
      'c3f00000-0000-0000-0000-000000000015'
    );
  EXCEPTION WHEN raise_exception THEN
    v_learner_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_module(
      'c3000000-0000-0000-0000-000000000005',
      '{"slug":"missing-key-module","title":"Missing key module","descriptionMarkdown":"A key is required."}'::jsonb,
      NULL,
      1,
      pg_catalog.decode(pg_catalog.repeat('ff', 32), 'hex'),
      'c3f00000-0000-0000-0000-000000000016'
    );
  EXCEPTION WHEN raise_exception THEN
    v_missing_key_rejected := true;
  END;

  IF v_editor_first.response_status <> 201
    OR v_editor_first.idempotency_replayed
    OR v_editor_first.response_body ->> 'id' IS NULL
    OR v_editor_first.response_location IS DISTINCT FROM
      '/api/v1/admin/modules/' || (v_editor_first.response_body ->> 'id')
    OR v_editor_first.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_editor_first.response_body ->> 'id'
    )
    OR NOT v_editor_replay.idempotency_replayed
    OR v_editor_replay.response_status IS DISTINCT FROM v_editor_first.response_status
    OR v_editor_replay.response_location IS DISTINCT FROM v_editor_first.response_location
    OR v_editor_replay.response_body IS DISTINCT FROM v_editor_first.response_body
    OR v_admin_first.response_status <> 201
    OR v_admin_first.idempotency_replayed
    OR v_admin_first.response_body ->> 'id' IS NULL
    OR v_admin_first.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_admin_first.response_body ->> 'id'
    )
    OR NOT v_different_hash_rejected
    OR NOT v_invalid_input_rejected
    OR NOT v_learner_rejected
    OR NOT v_missing_key_rejected THEN
    RAISE EXCEPTION 'draft-module authoring facade did not preserve its secure creation and replay contract';
  END IF;
END;
$curriculum_create_draft_module$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = pg_catalog.clock_timestamp()
WHERE id = 'c3000000-0000-0000-0000-000000000004';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $held_staff_authoring_replay_denial$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_module(
      'c3000000-0000-0000-0000-000000000004',
      '{"slug":"authoring-editor-module","title":"Authoring editor module","descriptionMarkdown":"Draft content created by an editor."}'::jsonb,
      'c3e00000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('aa', 32), 'hex'),
      'c3f00000-0000-0000-0000-000000000017'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;

  IF NOT v_rejected THEN
    RAISE EXCEPTION 'held staff actor unexpectedly received a module-create replay';
  END IF;
END;
$held_staff_authoring_replay_denial$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = NULL
WHERE id = 'c3000000-0000-0000-0000-000000000004';

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 2
      AND pg_catalog.bool_and(
        module_entry.status = 'draft'::public.content_status
        AND module_entry.published_at IS NULL
        AND module_entry.row_version = 1
      )
    FROM public.modules AS module_entry
    WHERE module_entry.slug IN (
      'authoring-editor-module',
      'authoring-admin-module'
    )
  )
  AND EXISTS (
    SELECT 1
    FROM public.modules AS module_entry
    WHERE module_entry.slug = 'authoring-editor-module'
      AND module_entry.position = 0
      AND module_entry.created_by = 'c3000000-0000-0000-0000-000000000004'
      AND module_entry.updated_by = 'c3000000-0000-0000-0000-000000000004'
  )
  AND EXISTS (
    SELECT 1
    FROM public.modules AS module_entry
    WHERE module_entry.slug = 'authoring-admin-module'
      AND module_entry.position = 1
      AND module_entry.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND module_entry.updated_by = 'c3000000-0000-0000-0000-000000000005'
  )
  AND (
    SELECT pg_catalog.count(*) = 2
      AND pg_catalog.bool_and(
        record_entry.response_status = 201
        AND record_entry.response_location =
          '/api/v1/admin/modules/' || record_entry.result_resource_id::text
        AND record_entry.response_body = pg_catalog.jsonb_build_object(
          'id',
          record_entry.result_resource_id::text
        )
      )
    FROM private.idempotency_records AS record_entry
    WHERE record_entry.operation = 'admin_create_module'
      AND record_entry.idempotency_key IN (
        'c3e00000-0000-0000-0000-000000000001',
        'c3e00000-0000-0000-0000-000000000002'
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM private.idempotency_records AS record_entry
    WHERE record_entry.operation = 'admin_create_module'
      AND record_entry.idempotency_key =
        'c3e00000-0000-0000-0000-000000000003'
  )
  AND (
    SELECT pg_catalog.count(*) = 2
      AND pg_catalog.bool_and(
        audit_entry.changed_fields = ARRAY['status']::text[]
        AND audit_entry.change_summary =
          '{"status":{"before":"none","after":"draft"}}'::jsonb
        AND audit_entry.reason IS NULL
      )
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action = 'module_created'
      AND audit_entry.entity_type = 'module'
      AND audit_entry.entity_id IN (
        SELECT module_entry.id
        FROM public.modules AS module_entry
        WHERE module_entry.slug IN (
          'authoring-editor-module',
          'authoring-admin-module'
        )
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.request_id = 'c3f00000-0000-0000-0000-000000000011'
  ),
  'editor/admin draft creation serializes root positions, stores ID-only replay, audits safely, and denies held replay'
);

-- This fixed draft parent and archived child prove that chapter placement locks
-- the parent scope and appends after every sibling status without granting the
-- runtime role direct table reads.
SET LOCAL ROLE coditza_owner;
INSERT INTO public.modules (
  id,
  slug,
  title,
  description_markdown,
  position
)
VALUES (
  'c3120000-0000-0000-0000-000000000001',
  'authoring-chapter-parent',
  'Authoring chapter parent',
  'Draft parent for chapter-function verification.',
  2
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
  'c3220000-0000-0000-0000-000000000001',
  'c3120000-0000-0000-0000-000000000001',
  'archived-sibling-chapter',
  'Archived sibling chapter',
  'Archived sibling for position verification.',
  0,
  15
);
UPDATE public.chapters
SET status = 'archived'::public.content_status
WHERE id = 'c3220000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $curriculum_create_draft_chapter$
DECLARE
  v_editor_first record;
  v_editor_replay record;
  v_admin_first record;
  v_different_hash_rejected boolean := false;
  v_invalid_input_rejected boolean := false;
  v_learner_rejected boolean := false;
  v_missing_key_rejected boolean := false;
  v_missing_parent_rejected boolean := false;
BEGIN
  SELECT * INTO v_editor_first
  FROM public.curriculum_create_draft_chapter(
    'c3000000-0000-0000-0000-000000000004',
    'c3120000-0000-0000-0000-000000000001',
    '{"slug":"authoring-editor-chapter","title":"Authoring editor chapter","summaryMarkdown":"Draft chapter created by an editor.","estimatedMinutes":25}'::jsonb,
    'c3e10000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a1', 32), 'hex'),
    'c3f10000-0000-0000-0000-000000000010'
  );
  SELECT * INTO v_editor_replay
  FROM public.curriculum_create_draft_chapter(
    'c3000000-0000-0000-0000-000000000004',
    'c3120000-0000-0000-0000-000000000001',
    '{"slug":"authoring-editor-chapter","title":"Authoring editor chapter","summaryMarkdown":"Draft chapter created by an editor.","estimatedMinutes":25}'::jsonb,
    'c3e10000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a1', 32), 'hex'),
    'c3f10000-0000-0000-0000-000000000011'
  );
  SELECT * INTO v_admin_first
  FROM public.curriculum_create_draft_chapter(
    'c3000000-0000-0000-0000-000000000005',
    'c3120000-0000-0000-0000-000000000001',
    '{"slug":"authoring-admin-chapter","title":"Authoring admin chapter","summaryMarkdown":"Draft chapter created by an administrator.","estimatedMinutes":30}'::jsonb,
    'c3e10000-0000-0000-0000-000000000002',
    1,
    pg_catalog.decode(pg_catalog.repeat('b2', 32), 'hex'),
    'c3f10000-0000-0000-0000-000000000012'
  );

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_chapter(
      'c3000000-0000-0000-0000-000000000004',
      'c3120000-0000-0000-0000-000000000001',
      '{"slug":"authoring-editor-chapter","title":"Authoring editor chapter","summaryMarkdown":"Draft chapter created by an editor.","estimatedMinutes":25}'::jsonb,
      'c3e10000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('c3', 32), 'hex'),
      'c3f10000-0000-0000-0000-000000000013'
    );
  EXCEPTION WHEN raise_exception THEN
    v_different_hash_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_chapter(
      'c3000000-0000-0000-0000-000000000005',
      'c3120000-0000-0000-0000-000000000001',
      '{"slug":"invalid-chapter","title":"Invalid chapter","summaryMarkdown":"Draft.","estimatedMinutes":10,"moduleId":"c3120000-0000-0000-0000-000000000001"}'::jsonb,
      'c3e10000-0000-0000-0000-000000000003',
      1,
      pg_catalog.decode(pg_catalog.repeat('d4', 32), 'hex'),
      'c3f10000-0000-0000-0000-000000000014'
    );
  EXCEPTION WHEN raise_exception THEN
    v_invalid_input_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_chapter(
      'c3000000-0000-0000-0000-000000000001',
      'c3120000-0000-0000-0000-000000000001',
      '{"slug":"learner-chapter","title":"Learner chapter","summaryMarkdown":"Learners cannot author.","estimatedMinutes":10}'::jsonb,
      'c3e10000-0000-0000-0000-000000000004',
      1,
      pg_catalog.decode(pg_catalog.repeat('e5', 32), 'hex'),
      'c3f10000-0000-0000-0000-000000000015'
    );
  EXCEPTION WHEN raise_exception THEN
    v_learner_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_chapter(
      'c3000000-0000-0000-0000-000000000005',
      'c3120000-0000-0000-0000-000000000001',
      '{"slug":"missing-key-chapter","title":"Missing key chapter","summaryMarkdown":"A key is required.","estimatedMinutes":10}'::jsonb,
      NULL,
      1,
      pg_catalog.decode(pg_catalog.repeat('f6', 32), 'hex'),
      'c3f10000-0000-0000-0000-000000000016'
    );
  EXCEPTION WHEN raise_exception THEN
    v_missing_key_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_chapter(
      'c3000000-0000-0000-0000-000000000005',
      'c3120000-0000-0000-0000-000000000999',
      '{"slug":"missing-parent-chapter","title":"Missing parent chapter","summaryMarkdown":"A parent is required.","estimatedMinutes":10}'::jsonb,
      'c3e10000-0000-0000-0000-000000000005',
      1,
      pg_catalog.decode(pg_catalog.repeat('a2', 32), 'hex'),
      'c3f10000-0000-0000-0000-000000000017'
    );
  EXCEPTION WHEN raise_exception THEN
    v_missing_parent_rejected := true;
  END;

  IF v_editor_first.response_status <> 201
    OR v_editor_first.idempotency_replayed
    OR v_editor_first.response_body ->> 'id' IS NULL
    OR v_editor_first.response_location IS DISTINCT FROM
      '/api/v1/admin/chapters/' || (v_editor_first.response_body ->> 'id')
    OR v_editor_first.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_editor_first.response_body ->> 'id'
    )
    OR NOT v_editor_replay.idempotency_replayed
    OR v_editor_replay.response_status IS DISTINCT FROM v_editor_first.response_status
    OR v_editor_replay.response_location IS DISTINCT FROM v_editor_first.response_location
    OR v_editor_replay.response_body IS DISTINCT FROM v_editor_first.response_body
    OR v_admin_first.response_status <> 201
    OR v_admin_first.idempotency_replayed
    OR v_admin_first.response_body ->> 'id' IS NULL
    OR v_admin_first.response_location IS DISTINCT FROM
      '/api/v1/admin/chapters/' || (v_admin_first.response_body ->> 'id')
    OR v_admin_first.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_admin_first.response_body ->> 'id'
    )
    OR NOT v_different_hash_rejected
    OR NOT v_invalid_input_rejected
    OR NOT v_learner_rejected
    OR NOT v_missing_key_rejected
    OR NOT v_missing_parent_rejected THEN
    RAISE EXCEPTION 'draft-chapter authoring facade did not preserve its secure creation and replay contract';
  END IF;
END;
$curriculum_create_draft_chapter$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.modules
SET
  status = 'published'::public.content_status,
  published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3120000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $published_parent_chapter_creation$
DECLARE
  v_created record;
BEGIN
  SELECT * INTO v_created
  FROM public.curriculum_create_draft_chapter(
    'c3000000-0000-0000-0000-000000000005',
    'c3120000-0000-0000-0000-000000000001',
    '{"slug":"published-parent-chapter","title":"Published parent chapter","summaryMarkdown":"A published parent accepts new draft chapters.","estimatedMinutes":20}'::jsonb,
    'c3e10000-0000-0000-0000-000000000007',
    1,
    pg_catalog.decode(pg_catalog.repeat('c4', 32), 'hex'),
    'c3f10000-0000-0000-0000-000000000021'
  );

  IF v_created.response_status <> 201
    OR v_created.idempotency_replayed
    OR v_created.response_body ->> 'id' IS NULL
    OR v_created.response_location IS DISTINCT FROM
      '/api/v1/admin/chapters/' || (v_created.response_body ->> 'id')
    OR v_created.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_created.response_body ->> 'id'
    ) THEN
    RAISE EXCEPTION 'a published module unexpectedly rejected a draft chapter';
  END IF;
END;
$published_parent_chapter_creation$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.modules
SET status = 'archived'::public.content_status
WHERE id = 'c3120000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $archived_parent_chapter_replay$
DECLARE
  v_replay record;
  v_archived_parent_rejected boolean := false;
BEGIN
  SELECT * INTO v_replay
  FROM public.curriculum_create_draft_chapter(
    'c3000000-0000-0000-0000-000000000004',
    'c3120000-0000-0000-0000-000000000001',
    '{"slug":"authoring-editor-chapter","title":"Authoring editor chapter","summaryMarkdown":"Draft chapter created by an editor.","estimatedMinutes":25}'::jsonb,
    'c3e10000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a1', 32), 'hex'),
    'c3f10000-0000-0000-0000-000000000018'
  );

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_chapter(
      'c3000000-0000-0000-0000-000000000005',
      'c3120000-0000-0000-0000-000000000001',
      '{"slug":"archived-parent-chapter","title":"Archived parent chapter","summaryMarkdown":"An archived parent rejects new chapters.","estimatedMinutes":10}'::jsonb,
      'c3e10000-0000-0000-0000-000000000006',
      1,
      pg_catalog.decode(pg_catalog.repeat('b3', 32), 'hex'),
      'c3f10000-0000-0000-0000-000000000019'
    );
  EXCEPTION WHEN raise_exception THEN
    v_archived_parent_rejected := true;
  END;

  IF NOT v_replay.idempotency_replayed
    OR v_replay.response_status <> 201
    OR v_replay.response_body ->> 'id' IS NULL
    OR NOT v_archived_parent_rejected THEN
    RAISE EXCEPTION 'chapter replay did not remain stable across a later parent archive';
  END IF;
END;
$archived_parent_chapter_replay$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = pg_catalog.clock_timestamp()
WHERE id = 'c3000000-0000-0000-0000-000000000004';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $held_staff_chapter_replay_denial$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_chapter(
      'c3000000-0000-0000-0000-000000000004',
      'c3120000-0000-0000-0000-000000000001',
      '{"slug":"authoring-editor-chapter","title":"Authoring editor chapter","summaryMarkdown":"Draft chapter created by an editor.","estimatedMinutes":25}'::jsonb,
      'c3e10000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('a1', 32), 'hex'),
      'c3f10000-0000-0000-0000-000000000020'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;

  IF NOT v_rejected THEN
    RAISE EXCEPTION 'held staff actor unexpectedly received a chapter-create replay';
  END IF;
END;
$held_staff_chapter_replay_denial$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = NULL
WHERE id = 'c3000000-0000-0000-0000-000000000004';

SELECT extensions.ok(
  EXISTS (
    SELECT 1
    FROM public.chapters AS chapter_entry
    WHERE chapter_entry.id = 'c3220000-0000-0000-0000-000000000001'
      AND chapter_entry.status = 'archived'::public.content_status
      AND chapter_entry.position = 0
  )
  AND (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        chapter_entry.module_id = 'c3120000-0000-0000-0000-000000000001'
        AND chapter_entry.status = 'draft'::public.content_status
        AND chapter_entry.published_at IS NULL
        AND chapter_entry.row_version = 1
      )
    FROM public.chapters AS chapter_entry
    WHERE chapter_entry.slug IN (
      'authoring-editor-chapter',
      'authoring-admin-chapter',
      'published-parent-chapter'
    )
  )
  AND EXISTS (
    SELECT 1
    FROM public.chapters AS chapter_entry
    WHERE chapter_entry.slug = 'authoring-editor-chapter'
      AND chapter_entry.position = 1
      AND chapter_entry.created_by = 'c3000000-0000-0000-0000-000000000004'
      AND chapter_entry.updated_by = 'c3000000-0000-0000-0000-000000000004'
  )
  AND EXISTS (
    SELECT 1
    FROM public.chapters AS chapter_entry
    WHERE chapter_entry.slug = 'authoring-admin-chapter'
      AND chapter_entry.position = 2
      AND chapter_entry.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND chapter_entry.updated_by = 'c3000000-0000-0000-0000-000000000005'
  )
  AND EXISTS (
    SELECT 1
    FROM public.chapters AS chapter_entry
    WHERE chapter_entry.slug = 'published-parent-chapter'
      AND chapter_entry.position = 3
      AND chapter_entry.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND chapter_entry.updated_by = 'c3000000-0000-0000-0000-000000000005'
  )
  AND EXISTS (
    SELECT 1
    FROM public.modules AS module_entry
    WHERE module_entry.id = 'c3120000-0000-0000-0000-000000000001'
      AND module_entry.status = 'archived'::public.content_status
      AND module_entry.published_at IS NOT NULL
  )
  AND (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        record_entry.response_status = 201
        AND record_entry.response_location =
          '/api/v1/admin/chapters/' || record_entry.result_resource_id::text
        AND record_entry.response_body = pg_catalog.jsonb_build_object(
          'id',
          record_entry.result_resource_id::text
        )
      )
    FROM private.idempotency_records AS record_entry
    WHERE record_entry.operation = 'admin_create_chapter'
      AND record_entry.idempotency_key IN (
        'c3e10000-0000-0000-0000-000000000001',
        'c3e10000-0000-0000-0000-000000000002',
        'c3e10000-0000-0000-0000-000000000007'
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM private.idempotency_records AS record_entry
    WHERE record_entry.operation = 'admin_create_chapter'
      AND record_entry.idempotency_key IN (
        'c3e10000-0000-0000-0000-000000000003',
        'c3e10000-0000-0000-0000-000000000004',
        'c3e10000-0000-0000-0000-000000000005',
        'c3e10000-0000-0000-0000-000000000006'
      )
  )
  AND (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        audit_entry.changed_fields = ARRAY['status']::text[]
        AND audit_entry.change_summary =
          '{"status":{"before":"none","after":"draft"}}'::jsonb
        AND audit_entry.reason IS NULL
      )
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action = 'chapter_created'
      AND audit_entry.entity_type = 'chapter'
      AND audit_entry.entity_id IN (
        SELECT chapter_entry.id
        FROM public.chapters AS chapter_entry
        WHERE chapter_entry.slug IN (
          'authoring-editor-chapter',
          'authoring-admin-chapter',
          'published-parent-chapter'
        )
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.request_id IN (
      'c3f10000-0000-0000-0000-000000000011',
      'c3f10000-0000-0000-0000-000000000018'
    )
  ),
  'chapter creation locks a parent scope, accepts draft/published parents, includes archived siblings, preserves safe replay, and denies archived/held writes'
);

-- The primary draft hierarchy has an archived theory sibling; the independent
-- secondary hierarchy isolates the archived-module rejection without granting
-- the runtime role direct table reads.
INSERT INTO public.modules (
  id,
  slug,
  title,
  description_markdown,
  position
)
VALUES (
  'c3130000-0000-0000-0000-000000000001',
  'authoring-theory-parent-module',
  'Authoring theory parent module',
  'Draft module for theory-section function verification.',
  3
), (
  'c3140000-0000-0000-0000-000000000001',
  'authoring-theory-archived-module',
  'Authoring theory archived module',
  'Secondary module for archived-parent verification.',
  4
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
  'c3230000-0000-0000-0000-000000000001',
  'c3130000-0000-0000-0000-000000000001',
  'authoring-theory-parent-chapter',
  'Authoring theory parent chapter',
  'Draft chapter for theory-section function verification.',
  0,
  15
), (
  'c3240000-0000-0000-0000-000000000001',
  'c3140000-0000-0000-0000-000000000001',
  'authoring-theory-secondary-chapter',
  'Authoring theory secondary chapter',
  'Draft chapter for archived-module verification.',
  0,
  15
);
INSERT INTO public.theory_sections (
  id,
  chapter_id,
  title,
  body_markdown,
  position,
  estimated_minutes
)
VALUES (
  'c3330000-0000-0000-0000-000000000001',
  'c3230000-0000-0000-0000-000000000001',
  'Archived sibling theory section',
  'Archived sibling for position verification.',
  0,
  15
);
UPDATE public.theory_sections
SET status = 'archived'::public.content_status
WHERE id = 'c3330000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $curriculum_create_draft_theory_section$
DECLARE
  v_editor_first record;
  v_editor_replay record;
  v_admin_first record;
  v_different_hash_rejected boolean := false;
  v_invalid_input_rejected boolean := false;
  v_learner_rejected boolean := false;
  v_missing_key_rejected boolean := false;
  v_missing_parent_rejected boolean := false;
BEGIN
  SELECT * INTO v_editor_first
  FROM public.curriculum_create_draft_theory_section(
    'c3000000-0000-0000-0000-000000000004',
    'c3230000-0000-0000-0000-000000000001',
    '{"title":"Authoring editor theory section","bodyMarkdown":"Draft theory section created by an editor.","estimatedMinutes":25}'::jsonb,
    'c3e20000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a3', 32), 'hex'),
    'c3f20000-0000-0000-0000-000000000010'
  );
  SELECT * INTO v_editor_replay
  FROM public.curriculum_create_draft_theory_section(
    'c3000000-0000-0000-0000-000000000004',
    'c3230000-0000-0000-0000-000000000001',
    '{"title":"Authoring editor theory section","bodyMarkdown":"Draft theory section created by an editor.","estimatedMinutes":25}'::jsonb,
    'c3e20000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a3', 32), 'hex'),
    'c3f20000-0000-0000-0000-000000000011'
  );
  SELECT * INTO v_admin_first
  FROM public.curriculum_create_draft_theory_section(
    'c3000000-0000-0000-0000-000000000005',
    'c3230000-0000-0000-0000-000000000001',
    '{"title":"Authoring admin theory section","bodyMarkdown":"Draft theory section created by an administrator.","estimatedMinutes":30}'::jsonb,
    'c3e20000-0000-0000-0000-000000000002',
    1,
    pg_catalog.decode(pg_catalog.repeat('b4', 32), 'hex'),
    'c3f20000-0000-0000-0000-000000000012'
  );

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_theory_section(
      'c3000000-0000-0000-0000-000000000004',
      'c3230000-0000-0000-0000-000000000001',
      '{"title":"Authoring editor theory section","bodyMarkdown":"Draft theory section created by an editor.","estimatedMinutes":25}'::jsonb,
      'c3e20000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('c5', 32), 'hex'),
      'c3f20000-0000-0000-0000-000000000013'
    );
  EXCEPTION WHEN raise_exception THEN
    v_different_hash_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_theory_section(
      'c3000000-0000-0000-0000-000000000005',
      'c3230000-0000-0000-0000-000000000001',
      '{"title":"Invalid theory section","bodyMarkdown":"Draft.","estimatedMinutes":10,"chapterId":"c3230000-0000-0000-0000-000000000001"}'::jsonb,
      'c3e20000-0000-0000-0000-000000000003',
      1,
      pg_catalog.decode(pg_catalog.repeat('d6', 32), 'hex'),
      'c3f20000-0000-0000-0000-000000000014'
    );
  EXCEPTION WHEN raise_exception THEN
    v_invalid_input_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_theory_section(
      'c3000000-0000-0000-0000-000000000001',
      'c3230000-0000-0000-0000-000000000001',
      '{"title":"Learner theory section","bodyMarkdown":"Learners cannot author.","estimatedMinutes":10}'::jsonb,
      'c3e20000-0000-0000-0000-000000000004',
      1,
      pg_catalog.decode(pg_catalog.repeat('e7', 32), 'hex'),
      'c3f20000-0000-0000-0000-000000000015'
    );
  EXCEPTION WHEN raise_exception THEN
    v_learner_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_theory_section(
      'c3000000-0000-0000-0000-000000000005',
      'c3230000-0000-0000-0000-000000000001',
      '{"title":"Missing key theory section","bodyMarkdown":"A key is required.","estimatedMinutes":10}'::jsonb,
      NULL,
      1,
      pg_catalog.decode(pg_catalog.repeat('f8', 32), 'hex'),
      'c3f20000-0000-0000-0000-000000000016'
    );
  EXCEPTION WHEN raise_exception THEN
    v_missing_key_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_theory_section(
      'c3000000-0000-0000-0000-000000000005',
      'c3230000-0000-0000-0000-000000000999',
      '{"title":"Missing parent theory section","bodyMarkdown":"A parent is required.","estimatedMinutes":10}'::jsonb,
      'c3e20000-0000-0000-0000-000000000005',
      1,
      pg_catalog.decode(pg_catalog.repeat('a4', 32), 'hex'),
      'c3f20000-0000-0000-0000-000000000017'
    );
  EXCEPTION WHEN raise_exception THEN
    v_missing_parent_rejected := true;
  END;

  IF v_editor_first.response_status <> 201
    OR v_editor_first.idempotency_replayed
    OR v_editor_first.response_body ->> 'id' IS NULL
    OR v_editor_first.response_location IS DISTINCT FROM
      '/api/v1/admin/theory-sections/' || (v_editor_first.response_body ->> 'id')
    OR v_editor_first.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_editor_first.response_body ->> 'id'
    )
    OR NOT v_editor_replay.idempotency_replayed
    OR v_editor_replay.response_status IS DISTINCT FROM v_editor_first.response_status
    OR v_editor_replay.response_location IS DISTINCT FROM v_editor_first.response_location
    OR v_editor_replay.response_body IS DISTINCT FROM v_editor_first.response_body
    OR v_admin_first.response_status <> 201
    OR v_admin_first.idempotency_replayed
    OR v_admin_first.response_body ->> 'id' IS NULL
    OR v_admin_first.response_location IS DISTINCT FROM
      '/api/v1/admin/theory-sections/' || (v_admin_first.response_body ->> 'id')
    OR v_admin_first.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_admin_first.response_body ->> 'id'
    )
    OR NOT v_different_hash_rejected
    OR NOT v_invalid_input_rejected
    OR NOT v_learner_rejected
    OR NOT v_missing_key_rejected
    OR NOT v_missing_parent_rejected THEN
    RAISE EXCEPTION 'draft-theory-section authoring facade did not preserve its secure creation and replay contract';
  END IF;
END;
$curriculum_create_draft_theory_section$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.modules
SET
  status = 'published'::public.content_status,
  published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3130000-0000-0000-0000-000000000001';
UPDATE public.chapters
SET
  status = 'published'::public.content_status,
  published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3230000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $published_hierarchy_theory_section_creation$
DECLARE
  v_created record;
BEGIN
  SELECT * INTO v_created
  FROM public.curriculum_create_draft_theory_section(
    'c3000000-0000-0000-0000-000000000005',
    'c3230000-0000-0000-0000-000000000001',
    '{"title":"Published hierarchy theory section","bodyMarkdown":"Published ancestors accept new draft theory sections.","estimatedMinutes":20}'::jsonb,
    'c3e20000-0000-0000-0000-000000000007',
    1,
    pg_catalog.decode(pg_catalog.repeat('c5', 32), 'hex'),
    'c3f20000-0000-0000-0000-000000000021'
  );

  IF v_created.response_status <> 201
    OR v_created.idempotency_replayed
    OR v_created.response_body ->> 'id' IS NULL
    OR v_created.response_location IS DISTINCT FROM
      '/api/v1/admin/theory-sections/' || (v_created.response_body ->> 'id')
    OR v_created.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_created.response_body ->> 'id'
    ) THEN
    RAISE EXCEPTION 'a published hierarchy unexpectedly rejected a draft theory section';
  END IF;
END;
$published_hierarchy_theory_section_creation$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.modules
SET status = 'archived'::public.content_status
WHERE id = 'c3130000-0000-0000-0000-000000000001';
UPDATE public.chapters
SET status = 'archived'::public.content_status
WHERE id = 'c3230000-0000-0000-0000-000000000001';
UPDATE public.modules
SET status = 'archived'::public.content_status
WHERE id = 'c3140000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $archived_theory_parent_replay$
DECLARE
  v_replay record;
  v_archived_chapter_rejected boolean := false;
  v_archived_module_rejected boolean := false;
BEGIN
  SELECT * INTO v_replay
  FROM public.curriculum_create_draft_theory_section(
    'c3000000-0000-0000-0000-000000000004',
    'c3230000-0000-0000-0000-000000000001',
    '{"title":"Authoring editor theory section","bodyMarkdown":"Draft theory section created by an editor.","estimatedMinutes":25}'::jsonb,
    'c3e20000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a3', 32), 'hex'),
    'c3f20000-0000-0000-0000-000000000018'
  );

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_theory_section(
      'c3000000-0000-0000-0000-000000000005',
      'c3230000-0000-0000-0000-000000000001',
      '{"title":"Archived chapter theory section","bodyMarkdown":"An archived chapter rejects new theory sections.","estimatedMinutes":10}'::jsonb,
      'c3e20000-0000-0000-0000-000000000006',
      1,
      pg_catalog.decode(pg_catalog.repeat('b5', 32), 'hex'),
      'c3f20000-0000-0000-0000-000000000019'
    );
  EXCEPTION WHEN raise_exception THEN
    v_archived_chapter_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_theory_section(
      'c3000000-0000-0000-0000-000000000005',
      'c3240000-0000-0000-0000-000000000001',
      '{"title":"Archived module theory section","bodyMarkdown":"An archived module rejects new theory sections.","estimatedMinutes":10}'::jsonb,
      'c3e20000-0000-0000-0000-000000000008',
      1,
      pg_catalog.decode(pg_catalog.repeat('c6', 32), 'hex'),
      'c3f20000-0000-0000-0000-000000000022'
    );
  EXCEPTION WHEN raise_exception THEN
    v_archived_module_rejected := true;
  END;

  IF NOT v_replay.idempotency_replayed
    OR v_replay.response_status <> 201
    OR v_replay.response_body ->> 'id' IS NULL
    OR NOT v_archived_chapter_rejected
    OR NOT v_archived_module_rejected THEN
    RAISE EXCEPTION 'theory-section replay did not remain stable across later ancestor archive';
  END IF;
END;
$archived_theory_parent_replay$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = pg_catalog.clock_timestamp()
WHERE id = 'c3000000-0000-0000-0000-000000000004';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $held_staff_theory_replay_denial$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM *
    FROM public.curriculum_create_draft_theory_section(
      'c3000000-0000-0000-0000-000000000004',
      'c3230000-0000-0000-0000-000000000001',
      '{"title":"Authoring editor theory section","bodyMarkdown":"Draft theory section created by an editor.","estimatedMinutes":25}'::jsonb,
      'c3e20000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('a3', 32), 'hex'),
      'c3f20000-0000-0000-0000-000000000020'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;

  IF NOT v_rejected THEN
    RAISE EXCEPTION 'held staff actor unexpectedly received a theory-section-create replay';
  END IF;
END;
$held_staff_theory_replay_denial$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = NULL
WHERE id = 'c3000000-0000-0000-0000-000000000004';

SELECT extensions.ok(
  EXISTS (
    SELECT 1
    FROM public.theory_sections AS theory_section
    WHERE theory_section.id = 'c3330000-0000-0000-0000-000000000001'
      AND theory_section.status = 'archived'::public.content_status
      AND theory_section.position = 0
  )
  AND (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        theory_section.chapter_id = 'c3230000-0000-0000-0000-000000000001'
        AND theory_section.status = 'draft'::public.content_status
        AND theory_section.published_at IS NULL
        AND theory_section.row_version = 1
      )
    FROM public.theory_sections AS theory_section
    WHERE theory_section.title IN (
      'Authoring editor theory section',
      'Authoring admin theory section',
      'Published hierarchy theory section'
    )
  )
  AND EXISTS (
    SELECT 1
    FROM public.theory_sections AS theory_section
    WHERE theory_section.title = 'Authoring editor theory section'
      AND theory_section.position = 1
      AND theory_section.estimated_minutes = 25
      AND theory_section.created_by = 'c3000000-0000-0000-0000-000000000004'
      AND theory_section.updated_by = 'c3000000-0000-0000-0000-000000000004'
  )
  AND EXISTS (
    SELECT 1
    FROM public.theory_sections AS theory_section
    WHERE theory_section.title = 'Authoring admin theory section'
      AND theory_section.position = 2
      AND theory_section.estimated_minutes = 30
      AND theory_section.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND theory_section.updated_by = 'c3000000-0000-0000-0000-000000000005'
  )
  AND EXISTS (
    SELECT 1
    FROM public.theory_sections AS theory_section
    WHERE theory_section.title = 'Published hierarchy theory section'
      AND theory_section.position = 3
      AND theory_section.estimated_minutes = 20
      AND theory_section.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND theory_section.updated_by = 'c3000000-0000-0000-0000-000000000005'
  )
  AND EXISTS (
    SELECT 1
    FROM public.modules AS module_entry
    WHERE module_entry.id = 'c3130000-0000-0000-0000-000000000001'
      AND module_entry.status = 'archived'::public.content_status
      AND module_entry.published_at IS NOT NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.chapters AS chapter_entry
    WHERE chapter_entry.id = 'c3230000-0000-0000-0000-000000000001'
      AND chapter_entry.status = 'archived'::public.content_status
      AND chapter_entry.published_at IS NOT NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.modules AS module_entry
    WHERE module_entry.id = 'c3140000-0000-0000-0000-000000000001'
      AND module_entry.status = 'archived'::public.content_status
  )
  AND (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        record_entry.response_status = 201
        AND record_entry.response_location =
          '/api/v1/admin/theory-sections/' || record_entry.result_resource_id::text
        AND record_entry.response_body = pg_catalog.jsonb_build_object(
          'id',
          record_entry.result_resource_id::text
        )
      )
    FROM private.idempotency_records AS record_entry
    WHERE record_entry.operation = 'admin_create_theory_section'
      AND record_entry.idempotency_key IN (
        'c3e20000-0000-0000-0000-000000000001',
        'c3e20000-0000-0000-0000-000000000002',
        'c3e20000-0000-0000-0000-000000000007'
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM private.idempotency_records AS record_entry
    WHERE record_entry.operation = 'admin_create_theory_section'
      AND record_entry.idempotency_key IN (
        'c3e20000-0000-0000-0000-000000000003',
        'c3e20000-0000-0000-0000-000000000004',
        'c3e20000-0000-0000-0000-000000000005',
        'c3e20000-0000-0000-0000-000000000006',
        'c3e20000-0000-0000-0000-000000000008'
      )
  )
  AND (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        audit_entry.changed_fields = ARRAY['status']::text[]
        AND audit_entry.change_summary =
          '{"status":{"before":"none","after":"draft"}}'::jsonb
        AND audit_entry.reason IS NULL
      )
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action = 'theory_section_created'
      AND audit_entry.entity_type = 'theory_section'
      AND audit_entry.entity_id IN (
        SELECT theory_section.id
        FROM public.theory_sections AS theory_section
        WHERE theory_section.title IN (
          'Authoring editor theory section',
          'Authoring admin theory section',
          'Published hierarchy theory section'
        )
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.request_id IN (
      'c3f20000-0000-0000-0000-000000000011',
      'c3f20000-0000-0000-0000-000000000018'
    )
  ),
  'theory-section creation locks module and chapter scopes, accepts draft/published ancestors, preserves safe replay, and denies archived/held writes'
);

-- The primary draft hierarchy has an archived exercise sibling; the independent
-- secondary hierarchy isolates archived-module rejection without granting the
-- runtime role direct public/private table reads.
INSERT INTO public.modules (
  id,
  slug,
  title,
  description_markdown,
  position
)
VALUES (
  'c3150000-0000-0000-0000-000000000001',
  'authoring-exercise-parent-module',
  'Authoring exercise parent module',
  'Draft module for scalar exercise function verification.',
  5
), (
  'c3160000-0000-0000-0000-000000000001',
  'authoring-exercise-archived-module',
  'Authoring exercise archived module',
  'Secondary module for archived-parent verification.',
  6
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
  'c3250000-0000-0000-0000-000000000001',
  'c3150000-0000-0000-0000-000000000001',
  'authoring-exercise-parent-chapter',
  'Authoring exercise parent chapter',
  'Draft chapter for scalar exercise function verification.',
  0,
  15
), (
  'c3260000-0000-0000-0000-000000000001',
  'c3160000-0000-0000-0000-000000000001',
  'authoring-exercise-secondary-chapter',
  'Authoring exercise secondary chapter',
  'Draft chapter for archived-module verification.',
  0,
  15
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
VALUES (
  'c3420000-0000-0000-0000-000000000001',
  'c3250000-0000-0000-0000-000000000001',
  'Archived sibling exercise',
  'Archived sibling for position verification.',
  'short_text'::public.exercise_type,
  0,
  1,
  true
);
UPDATE public.exercises
SET status = 'archived'::public.content_status
WHERE id = 'c3420000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $assessment_create_draft_exercise$
DECLARE
  v_editor_first record;
  v_editor_replay record;
  v_admin_first record;
  v_different_hash_rejected boolean := false;
  v_invalid_input_rejected boolean := false;
  v_learner_rejected boolean := false;
  v_missing_key_rejected boolean := false;
  v_missing_parent_rejected boolean := false;
  v_incomplete_rejected boolean := false;
  v_python_rejected boolean := false;
  v_foreign_option_rejected boolean := false;
BEGIN
  SELECT * INTO v_editor_first
  FROM public.assessment_create_draft_exercise(
    'c3000000-0000-0000-0000-000000000004',
    'c3250000-0000-0000-0000-000000000001',
    '{"title":"Authoring editor single exercise","promptMarkdown":"Select the correct scalar answer.","exerciseType":"single_choice","points":5,"isRequired":true,"options":[{"clientRef":"single-a","labelMarkdown":"Incorrect option."},{"clientRef":"single-b","labelMarkdown":"Correct option."}],"answerSpec":{"correctOptionRef":"single-b"},"feedbackCorrectMarkdown":"Correct.","feedbackIncorrectMarkdown":"Try again."}'::jsonb,
    'c3e30000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a5', 32), 'hex'),
    'c3f30000-0000-0000-0000-000000000010'
  );
  SELECT * INTO v_editor_replay
  FROM public.assessment_create_draft_exercise(
    'c3000000-0000-0000-0000-000000000004',
    'c3250000-0000-0000-0000-000000000001',
    '{"title":"Authoring editor single exercise","promptMarkdown":"Select the correct scalar answer.","exerciseType":"single_choice","points":5,"isRequired":true,"options":[{"clientRef":"single-a","labelMarkdown":"Incorrect option."},{"clientRef":"single-b","labelMarkdown":"Correct option."}],"answerSpec":{"correctOptionRef":"single-b"},"feedbackCorrectMarkdown":"Correct.","feedbackIncorrectMarkdown":"Try again."}'::jsonb,
    'c3e30000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a5', 32), 'hex'),
    'c3f30000-0000-0000-0000-000000000011'
  );
  SELECT * INTO v_admin_first
  FROM public.assessment_create_draft_exercise(
    'c3000000-0000-0000-0000-000000000005',
    'c3250000-0000-0000-0000-000000000001',
    '{"title":"Authoring admin multiple exercise","promptMarkdown":"Select both correct options.","exerciseType":"multiple_choice","points":10,"isRequired":false,"options":[{"clientRef":"multiple-a","labelMarkdown":"First correct option."},{"clientRef":"multiple-b","labelMarkdown":"Incorrect option."},{"clientRef":"multiple-c","labelMarkdown":"Second correct option."}],"answerSpec":{"correctOptionRefs":["multiple-c","multiple-a"]},"feedbackCorrectMarkdown":"Correct choices.","feedbackIncorrectMarkdown":"Review the options."}'::jsonb,
    'c3e30000-0000-0000-0000-000000000002',
    1,
    pg_catalog.decode(pg_catalog.repeat('b6', 32), 'hex'),
    'c3f30000-0000-0000-0000-000000000012'
  );

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_exercise(
      'c3000000-0000-0000-0000-000000000004',
      'c3250000-0000-0000-0000-000000000001',
      '{"title":"Authoring editor single exercise","promptMarkdown":"Select the correct scalar answer.","exerciseType":"single_choice","points":5,"isRequired":true,"options":[{"clientRef":"single-a","labelMarkdown":"Incorrect option."},{"clientRef":"single-b","labelMarkdown":"Correct option."}],"answerSpec":{"correctOptionRef":"single-b"},"feedbackCorrectMarkdown":"Correct.","feedbackIncorrectMarkdown":"Try again."}'::jsonb,
      'c3e30000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('c7', 32), 'hex'),
      'c3f30000-0000-0000-0000-000000000013'
    );
  EXCEPTION WHEN raise_exception THEN
    v_different_hash_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3250000-0000-0000-0000-000000000001',
      '{"title":"Invalid exercise","promptMarkdown":"Draft.","exerciseType":"short_text","points":1,"isRequired":true,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"},"chapterId":"c3250000-0000-0000-0000-000000000001"}'::jsonb,
      'c3e30000-0000-0000-0000-000000000003',
      1,
      pg_catalog.decode(pg_catalog.repeat('d8', 32), 'hex'),
      'c3f30000-0000-0000-0000-000000000014'
    );
  EXCEPTION WHEN raise_exception THEN
    v_invalid_input_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_exercise(
      'c3000000-0000-0000-0000-000000000001',
      'c3250000-0000-0000-0000-000000000001',
      '{"title":"Learner exercise","promptMarkdown":"Learners cannot author.","exerciseType":"short_text","points":1,"isRequired":true,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}'::jsonb,
      'c3e30000-0000-0000-0000-000000000004',
      1,
      pg_catalog.decode(pg_catalog.repeat('e9', 32), 'hex'),
      'c3f30000-0000-0000-0000-000000000015'
    );
  EXCEPTION WHEN raise_exception THEN
    v_learner_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3250000-0000-0000-0000-000000000001',
      '{"title":"Missing key exercise","promptMarkdown":"A key is required.","exerciseType":"short_text","points":1,"isRequired":true,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}'::jsonb,
      NULL,
      1,
      pg_catalog.decode(pg_catalog.repeat('fa', 32), 'hex'),
      'c3f30000-0000-0000-0000-000000000016'
    );
  EXCEPTION WHEN raise_exception THEN
    v_missing_key_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3250000-0000-0000-0000-000000000999',
      '{"title":"Missing parent exercise","promptMarkdown":"A parent is required.","exerciseType":"short_text","points":1,"isRequired":true,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}'::jsonb,
      'c3e30000-0000-0000-0000-000000000005',
      1,
      pg_catalog.decode(pg_catalog.repeat('a6', 32), 'hex'),
      'c3f30000-0000-0000-0000-000000000017'
    );
  EXCEPTION WHEN raise_exception THEN
    v_missing_parent_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3250000-0000-0000-0000-000000000001',
      '{"title":"Incomplete scalar exercise","promptMarkdown":"Incomplete definitions are rejected.","exerciseType":"short_text","points":1,"isRequired":true,"options":[],"answerSpec":null}'::jsonb,
      'c3e30000-0000-0000-0000-000000000009',
      1,
      pg_catalog.decode(pg_catalog.repeat('b7', 32), 'hex'),
      'c3f30000-0000-0000-0000-000000000023'
    );
  EXCEPTION WHEN raise_exception THEN
    v_incomplete_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3250000-0000-0000-0000-000000000001',
      '{"title":"Python exercise","promptMarkdown":"Python belongs to the separate WASM task.","exerciseType":"python_code","points":1,"isRequired":true,"options":[],"answerSpec":null}'::jsonb,
      'c3e30000-0000-0000-0000-000000000010',
      1,
      pg_catalog.decode(pg_catalog.repeat('c8', 32), 'hex'),
      'c3f30000-0000-0000-0000-000000000024'
    );
  EXCEPTION WHEN raise_exception THEN
    v_python_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3250000-0000-0000-0000-000000000001',
      '{"title":"Foreign option exercise","promptMarkdown":"Foreign option references are rejected.","exerciseType":"single_choice","points":1,"isRequired":true,"options":[{"clientRef":"foreign-a","labelMarkdown":"First option."},{"clientRef":"foreign-b","labelMarkdown":"Second option."}],"answerSpec":{"correctOptionRef":"missing-option"}}'::jsonb,
      'c3e30000-0000-0000-0000-000000000012',
      1,
      pg_catalog.decode(pg_catalog.repeat('d9', 32), 'hex'),
      'c3f30000-0000-0000-0000-000000000025'
    );
  EXCEPTION WHEN raise_exception THEN
    v_foreign_option_rejected := true;
  END;

  IF v_editor_first.response_status <> 201
    OR v_editor_first.idempotency_replayed
    OR v_editor_first.response_body ->> 'id' IS NULL
    OR v_editor_first.response_location IS DISTINCT FROM
      '/api/v1/admin/exercises/' || (v_editor_first.response_body ->> 'id')
    OR v_editor_first.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_editor_first.response_body ->> 'id'
    )
    OR NOT v_editor_replay.idempotency_replayed
    OR v_editor_replay.response_status IS DISTINCT FROM v_editor_first.response_status
    OR v_editor_replay.response_location IS DISTINCT FROM v_editor_first.response_location
    OR v_editor_replay.response_body IS DISTINCT FROM v_editor_first.response_body
    OR v_admin_first.response_status <> 201
    OR v_admin_first.idempotency_replayed
    OR v_admin_first.response_body ->> 'id' IS NULL
    OR v_admin_first.response_location IS DISTINCT FROM
      '/api/v1/admin/exercises/' || (v_admin_first.response_body ->> 'id')
    OR v_admin_first.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_admin_first.response_body ->> 'id'
    )
    OR NOT v_different_hash_rejected
    OR NOT v_invalid_input_rejected
    OR NOT v_learner_rejected
    OR NOT v_missing_key_rejected
    OR NOT v_missing_parent_rejected
    OR NOT v_incomplete_rejected
    OR NOT v_python_rejected
    OR NOT v_foreign_option_rejected THEN
    RAISE EXCEPTION 'draft-exercise authoring facade did not preserve its secure scalar creation and replay contract';
  END IF;
END;
$assessment_create_draft_exercise$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.modules
SET
  status = 'published'::public.content_status,
  published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3150000-0000-0000-0000-000000000001';
UPDATE public.chapters
SET
  status = 'published'::public.content_status,
  published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3250000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $published_hierarchy_exercise_creation$
DECLARE
  v_created record;
BEGIN
  SELECT * INTO v_created
  FROM public.assessment_create_draft_exercise(
    'c3000000-0000-0000-0000-000000000005',
    'c3250000-0000-0000-0000-000000000001',
    '{"title":"Published hierarchy short exercise","promptMarkdown":"Normalize the accepted short-text answers.","exerciseType":"short_text","points":3,"isRequired":true,"options":[],"answerSpec":{"acceptedAnswers":["  Da\t","NU"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}'::jsonb,
    'c3e30000-0000-0000-0000-000000000007',
    1,
    pg_catalog.decode(pg_catalog.repeat('c9', 32), 'hex'),
    'c3f30000-0000-0000-0000-000000000021'
  );

  IF v_created.response_status <> 201
    OR v_created.idempotency_replayed
    OR v_created.response_body ->> 'id' IS NULL
    OR v_created.response_location IS DISTINCT FROM
      '/api/v1/admin/exercises/' || (v_created.response_body ->> 'id')
    OR v_created.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_created.response_body ->> 'id'
    ) THEN
    RAISE EXCEPTION 'a published hierarchy unexpectedly rejected a scalar draft exercise';
  END IF;
END;
$published_hierarchy_exercise_creation$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.chapters
SET status = 'archived'::public.content_status
WHERE id = 'c3250000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $archived_exercise_chapter_replay$
DECLARE
  v_replay record;
  v_archived_chapter_rejected boolean := false;
BEGIN
  SELECT * INTO v_replay
  FROM public.assessment_create_draft_exercise(
    'c3000000-0000-0000-0000-000000000004',
    'c3250000-0000-0000-0000-000000000001',
    '{"title":"Authoring editor single exercise","promptMarkdown":"Select the correct scalar answer.","exerciseType":"single_choice","points":5,"isRequired":true,"options":[{"clientRef":"single-a","labelMarkdown":"Incorrect option."},{"clientRef":"single-b","labelMarkdown":"Correct option."}],"answerSpec":{"correctOptionRef":"single-b"},"feedbackCorrectMarkdown":"Correct.","feedbackIncorrectMarkdown":"Try again."}'::jsonb,
    'c3e30000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a5', 32), 'hex'),
    'c3f30000-0000-0000-0000-000000000018'
  );

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3250000-0000-0000-0000-000000000001',
      '{"title":"Archived chapter exercise","promptMarkdown":"An archived chapter rejects new exercises.","exerciseType":"short_text","points":1,"isRequired":true,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}'::jsonb,
      'c3e30000-0000-0000-0000-000000000006',
      1,
      pg_catalog.decode(pg_catalog.repeat('b5', 32), 'hex'),
      'c3f30000-0000-0000-0000-000000000019'
    );
  EXCEPTION WHEN raise_exception THEN
    v_archived_chapter_rejected := true;
  END;

  IF NOT v_replay.idempotency_replayed
    OR v_replay.response_status <> 201
    OR v_replay.response_body ->> 'id' IS NULL
    OR NOT v_archived_chapter_rejected THEN
    RAISE EXCEPTION 'exercise replay did not remain stable across a later chapter archive';
  END IF;
END;
$archived_exercise_chapter_replay$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.modules
SET status = 'archived'::public.content_status
WHERE id = 'c3150000-0000-0000-0000-000000000001';
UPDATE public.modules
SET status = 'archived'::public.content_status
WHERE id = 'c3160000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $archived_exercise_module_replay$
DECLARE
  v_replay record;
  v_archived_module_rejected boolean := false;
BEGIN
  SELECT * INTO v_replay
  FROM public.assessment_create_draft_exercise(
    'c3000000-0000-0000-0000-000000000004',
    'c3250000-0000-0000-0000-000000000001',
    '{"title":"Authoring editor single exercise","promptMarkdown":"Select the correct scalar answer.","exerciseType":"single_choice","points":5,"isRequired":true,"options":[{"clientRef":"single-a","labelMarkdown":"Incorrect option."},{"clientRef":"single-b","labelMarkdown":"Correct option."}],"answerSpec":{"correctOptionRef":"single-b"},"feedbackCorrectMarkdown":"Correct.","feedbackIncorrectMarkdown":"Try again."}'::jsonb,
    'c3e30000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a5', 32), 'hex'),
    'c3f30000-0000-0000-0000-000000000026'
  );

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3260000-0000-0000-0000-000000000001',
      '{"title":"Archived module exercise","promptMarkdown":"An archived module rejects new exercises.","exerciseType":"short_text","points":1,"isRequired":true,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}'::jsonb,
      'c3e30000-0000-0000-0000-000000000008',
      1,
      pg_catalog.decode(pg_catalog.repeat('c6', 32), 'hex'),
      'c3f30000-0000-0000-0000-000000000022'
    );
  EXCEPTION WHEN raise_exception THEN
    v_archived_module_rejected := true;
  END;

  IF NOT v_replay.idempotency_replayed
    OR v_replay.response_status <> 201
    OR v_replay.response_body ->> 'id' IS NULL
    OR NOT v_archived_module_rejected THEN
    RAISE EXCEPTION 'exercise replay did not remain stable across a later module archive';
  END IF;
END;
$archived_exercise_module_replay$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = pg_catalog.clock_timestamp()
WHERE id = 'c3000000-0000-0000-0000-000000000004';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $held_staff_exercise_replay_denial$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_exercise(
      'c3000000-0000-0000-0000-000000000004',
      'c3250000-0000-0000-0000-000000000001',
      '{"title":"Authoring editor single exercise","promptMarkdown":"Select the correct scalar answer.","exerciseType":"single_choice","points":5,"isRequired":true,"options":[{"clientRef":"single-a","labelMarkdown":"Incorrect option."},{"clientRef":"single-b","labelMarkdown":"Correct option."}],"answerSpec":{"correctOptionRef":"single-b"},"feedbackCorrectMarkdown":"Correct.","feedbackIncorrectMarkdown":"Try again."}'::jsonb,
      'c3e30000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('a5', 32), 'hex'),
      'c3f30000-0000-0000-0000-000000000020'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;

  IF NOT v_rejected THEN
    RAISE EXCEPTION 'held staff actor unexpectedly received an exercise-create replay';
  END IF;
END;
$held_staff_exercise_replay_denial$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = NULL
WHERE id = 'c3000000-0000-0000-0000-000000000004';

SELECT extensions.ok(
  EXISTS (
    SELECT 1
    FROM public.exercises AS exercise
    WHERE exercise.id = 'c3420000-0000-0000-0000-000000000001'
      AND exercise.status = 'archived'::public.content_status
      AND exercise.position = 0
  )
  AND (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        exercise.chapter_id = 'c3250000-0000-0000-0000-000000000001'
        AND exercise.status = 'draft'::public.content_status
        AND exercise.published_at IS NULL
        AND exercise.row_version = 1
        AND exercise.definition_version = 1
      )
    FROM public.exercises AS exercise
    WHERE exercise.title IN (
      'Authoring editor single exercise',
      'Authoring admin multiple exercise',
      'Published hierarchy short exercise'
    )
  )
  AND EXISTS (
    SELECT 1
    FROM public.exercises AS exercise
    JOIN private.exercise_answer_keys AS answer_key
      ON answer_key.exercise_id = exercise.id
    WHERE exercise.title = 'Authoring editor single exercise'
      AND exercise.position = 1
      AND exercise.exercise_type = 'single_choice'::public.exercise_type
      AND exercise.points = 5
      AND exercise.is_required
      AND exercise.created_by = 'c3000000-0000-0000-0000-000000000004'
      AND exercise.updated_by = 'c3000000-0000-0000-0000-000000000004'
      AND answer_key.answer_spec = pg_catalog.jsonb_build_object(
        'correctOptionId',
        (
          SELECT option_entry.id::text
          FROM public.exercise_options AS option_entry
          WHERE option_entry.exercise_id = exercise.id
            AND option_entry.position = 1
        )
      )
      AND NOT (answer_key.answer_spec OPERATOR(pg_catalog.?) 'correctOptionRef')
      AND answer_key.feedback_correct_markdown = 'Correct.'
      AND answer_key.feedback_incorrect_markdown = 'Try again.'
      AND answer_key.created_by = 'c3000000-0000-0000-0000-000000000004'
      AND answer_key.updated_by = 'c3000000-0000-0000-0000-000000000004'
      AND (
        SELECT pg_catalog.count(*) = 2
          AND pg_catalog.array_agg(option_entry.position ORDER BY option_entry.position)
            = ARRAY[0, 1]::integer[]
        FROM public.exercise_options AS option_entry
        WHERE option_entry.exercise_id = exercise.id
      )
  )
  AND EXISTS (
    SELECT 1
    FROM public.exercises AS exercise
    JOIN private.exercise_answer_keys AS answer_key
      ON answer_key.exercise_id = exercise.id
    WHERE exercise.title = 'Authoring admin multiple exercise'
      AND exercise.position = 2
      AND exercise.exercise_type = 'multiple_choice'::public.exercise_type
      AND exercise.points = 10
      AND NOT exercise.is_required
      AND exercise.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND exercise.updated_by = 'c3000000-0000-0000-0000-000000000005'
      AND answer_key.answer_spec = pg_catalog.jsonb_build_object(
        'correctOptionIds',
        (
          SELECT pg_catalog.jsonb_agg(
            pg_catalog.to_jsonb(option_entry.id::text)
            ORDER BY option_entry.id::text COLLATE "C"
          )
          FROM public.exercise_options AS option_entry
          WHERE option_entry.exercise_id = exercise.id
            AND option_entry.position IN (0, 2)
        )
      )
      AND NOT (answer_key.answer_spec OPERATOR(pg_catalog.?) 'correctOptionRefs')
      AND answer_key.feedback_correct_markdown = 'Correct choices.'
      AND answer_key.feedback_incorrect_markdown = 'Review the options.'
      AND answer_key.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND answer_key.updated_by = 'c3000000-0000-0000-0000-000000000005'
      AND (
        SELECT pg_catalog.count(*) = 3
          AND pg_catalog.array_agg(option_entry.position ORDER BY option_entry.position)
            = ARRAY[0, 1, 2]::integer[]
        FROM public.exercise_options AS option_entry
        WHERE option_entry.exercise_id = exercise.id
      )
  )
  AND EXISTS (
    SELECT 1
    FROM public.exercises AS exercise
    JOIN private.exercise_answer_keys AS answer_key
      ON answer_key.exercise_id = exercise.id
    WHERE exercise.title = 'Published hierarchy short exercise'
      AND exercise.position = 3
      AND exercise.exercise_type = 'short_text'::public.exercise_type
      AND exercise.points = 3
      AND exercise.is_required
      AND exercise.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND exercise.updated_by = 'c3000000-0000-0000-0000-000000000005'
      AND answer_key.answer_spec =
        '{"acceptedAnswers":["da","nu"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}'::jsonb
      AND answer_key.feedback_correct_markdown IS NULL
      AND answer_key.feedback_incorrect_markdown IS NULL
      AND answer_key.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND answer_key.updated_by = 'c3000000-0000-0000-0000-000000000005'
      AND NOT EXISTS (
        SELECT 1
        FROM public.exercise_options AS option_entry
        WHERE option_entry.exercise_id = exercise.id
      )
  )
  AND EXISTS (
    SELECT 1
    FROM public.modules AS module_entry
    WHERE module_entry.id = 'c3150000-0000-0000-0000-000000000001'
      AND module_entry.status = 'archived'::public.content_status
      AND module_entry.published_at IS NOT NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.chapters AS chapter_entry
    WHERE chapter_entry.id = 'c3250000-0000-0000-0000-000000000001'
      AND chapter_entry.status = 'archived'::public.content_status
      AND chapter_entry.published_at IS NOT NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.modules AS module_entry
    WHERE module_entry.id = 'c3160000-0000-0000-0000-000000000001'
      AND module_entry.status = 'archived'::public.content_status
  )
  AND (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        record_entry.response_status = 201
        AND record_entry.response_location =
          '/api/v1/admin/exercises/' || record_entry.result_resource_id::text
        AND record_entry.response_body = pg_catalog.jsonb_build_object(
          'id',
          record_entry.result_resource_id::text
        )
      )
    FROM private.idempotency_records AS record_entry
    WHERE record_entry.operation = 'admin_create_exercise'
      AND record_entry.idempotency_key IN (
        'c3e30000-0000-0000-0000-000000000001',
        'c3e30000-0000-0000-0000-000000000002',
        'c3e30000-0000-0000-0000-000000000007'
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM private.idempotency_records AS record_entry
    WHERE record_entry.operation = 'admin_create_exercise'
      AND record_entry.idempotency_key IN (
        'c3e30000-0000-0000-0000-000000000003',
        'c3e30000-0000-0000-0000-000000000004',
        'c3e30000-0000-0000-0000-000000000005',
        'c3e30000-0000-0000-0000-000000000006',
        'c3e30000-0000-0000-0000-000000000008',
        'c3e30000-0000-0000-0000-000000000009',
        'c3e30000-0000-0000-0000-000000000010',
        'c3e30000-0000-0000-0000-000000000012'
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.exercises AS exercise
    WHERE exercise.title IN (
      'Incomplete scalar exercise',
      'Python exercise',
      'Foreign option exercise',
      'Archived chapter exercise',
      'Archived module exercise'
    )
  )
  AND (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        audit_entry.changed_fields = ARRAY['status']::text[]
        AND audit_entry.change_summary =
          '{"status":{"before":"none","after":"draft"}}'::jsonb
        AND audit_entry.reason IS NULL
      )
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action = 'exercise_created'
      AND audit_entry.entity_type = 'exercise'
      AND audit_entry.entity_id IN (
        SELECT exercise.id
        FROM public.exercises AS exercise
        WHERE exercise.title IN (
          'Authoring editor single exercise',
          'Authoring admin multiple exercise',
          'Published hierarchy short exercise'
        )
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.request_id IN (
      'c3f30000-0000-0000-0000-000000000011',
      'c3f30000-0000-0000-0000-000000000018',
      'c3f30000-0000-0000-0000-000000000026',
      'c3f30000-0000-0000-0000-000000000020'
    )
  )
  AND COALESCE(
    pg_catalog.current_setting('coditza.assessment_tree_root', true),
    ''
  ) = '',
  'scalar exercise creation locks the module and chapter scope, materializes private definitions, preserves safe replay, and denies archived or held writes'
);

-- The primary draft hierarchy has an archived quiz sibling; the independent
-- secondary hierarchy isolates archived-module rejection without granting the
-- runtime role direct public/private table reads.
INSERT INTO public.modules (
  id,
  slug,
  title,
  description_markdown,
  position
)
VALUES (
  'c3170000-0000-0000-0000-000000000001',
  'authoring-quiz-parent-module',
  'Authoring quiz parent module',
  'Draft module for complete quiz function verification.',
  7
), (
  'c3180000-0000-0000-0000-000000000001',
  'authoring-quiz-archived-module',
  'Authoring quiz archived module',
  'Secondary module for archived-parent verification.',
  8
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
  'c3270000-0000-0000-0000-000000000001',
  'c3170000-0000-0000-0000-000000000001',
  'authoring-quiz-parent-chapter',
  'Authoring quiz parent chapter',
  'Draft chapter for complete quiz function verification.',
  0,
  15
), (
  'c3280000-0000-0000-0000-000000000001',
  'c3180000-0000-0000-0000-000000000001',
  'authoring-quiz-secondary-chapter',
  'Authoring quiz secondary chapter',
  'Draft chapter for archived-module verification.',
  0,
  15
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
VALUES (
  'c3520000-0000-0000-0000-000000000001',
  'c3270000-0000-0000-0000-000000000001',
  'archived-quiz-sibling',
  'Archived sibling quiz',
  'Archived sibling for position verification.',
  0,
  70,
  NULL,
  NULL,
  true
);
UPDATE public.quizzes
SET status = 'archived'::public.content_status
WHERE id = 'c3520000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $assessment_create_draft_quiz$
DECLARE
  v_editor_input jsonb :=
    '{"slug":"authoring-editor-complete-quiz","title":"Authoring editor complete quiz","instructionsMarkdown":"Answer every scalar question.","passingPercent":70,"maxAttempts":3,"timeLimitSeconds":600,"isRequired":true,"questions":[{"clientRef":"editor-single","promptMarkdown":"Select the correct option.","questionType":"single_choice","points":5,"options":[{"clientRef":"single-a","labelMarkdown":"Incorrect option."},{"clientRef":"single-b","labelMarkdown":"Correct option."}],"answerSpec":{"correctOptionRef":"single-b"},"feedbackCorrectMarkdown":"Correct.","feedbackIncorrectMarkdown":"Try again."},{"clientRef":"editor-multiple","promptMarkdown":"Select both correct options.","questionType":"multiple_choice","points":10,"options":[{"clientRef":"multiple-a","labelMarkdown":"First correct option."},{"clientRef":"multiple-b","labelMarkdown":"Incorrect option."},{"clientRef":"multiple-c","labelMarkdown":"Second correct option."}],"answerSpec":{"correctOptionRefs":["multiple-c","multiple-a"]},"feedbackCorrectMarkdown":"Correct choices.","feedbackIncorrectMarkdown":"Review the options."},{"clientRef":"editor-short","promptMarkdown":"Type the normalized answer.","questionType":"short_text","points":3,"options":[],"answerSpec":{"acceptedAnswers":["  Da\t","NU"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}]}'::jsonb;
  v_admin_input jsonb :=
    '{"slug":"authoring-admin-complete-quiz","title":"Authoring admin complete quiz","instructionsMarkdown":"Answer the short question.","passingPercent":80,"maxAttempts":null,"timeLimitSeconds":null,"isRequired":false,"questions":[{"clientRef":"admin-short","promptMarkdown":"Type yes.","questionType":"short_text","points":4,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"},"feedbackCorrectMarkdown":"Correct.","feedbackIncorrectMarkdown":"Try again."}]}'::jsonb;
  v_editor_first record;
  v_editor_replay record;
  v_admin_first record;
  v_different_hash_rejected boolean := false;
  v_invalid_input_rejected boolean := false;
  v_learner_rejected boolean := false;
  v_missing_key_rejected boolean := false;
  v_missing_parent_rejected boolean := false;
  v_empty_definition_rejected boolean := false;
  v_incomplete_rejected boolean := false;
  v_one_option_rejected boolean := false;
  v_cross_question_rejected boolean := false;
BEGIN
  SELECT * INTO v_editor_first
  FROM public.assessment_create_draft_quiz(
    'c3000000-0000-0000-0000-000000000004',
    'c3270000-0000-0000-0000-000000000001',
    v_editor_input,
    'c3e40000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a4', 32), 'hex'),
    'c3f40000-0000-0000-0000-000000000010'
  );
  SELECT * INTO v_editor_replay
  FROM public.assessment_create_draft_quiz(
    'c3000000-0000-0000-0000-000000000004',
    'c3270000-0000-0000-0000-000000000001',
    v_editor_input,
    'c3e40000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a4', 32), 'hex'),
    'c3f40000-0000-0000-0000-000000000011'
  );
  SELECT * INTO v_admin_first
  FROM public.assessment_create_draft_quiz(
    'c3000000-0000-0000-0000-000000000005',
    'c3270000-0000-0000-0000-000000000001',
    v_admin_input,
    'c3e40000-0000-0000-0000-000000000002',
    1,
    pg_catalog.decode(pg_catalog.repeat('b5', 32), 'hex'),
    'c3f40000-0000-0000-0000-000000000012'
  );

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_quiz(
      'c3000000-0000-0000-0000-000000000004',
      'c3270000-0000-0000-0000-000000000001',
      v_editor_input,
      'c3e40000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('c6', 32), 'hex'),
      'c3f40000-0000-0000-0000-000000000013'
    );
  EXCEPTION WHEN raise_exception THEN
    v_different_hash_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_quiz(
      'c3000000-0000-0000-0000-000000000005',
      'c3270000-0000-0000-0000-000000000001',
      '{"slug":"invalid-quiz","title":"Invalid quiz","instructionsMarkdown":"Draft.","passingPercent":70,"maxAttempts":null,"timeLimitSeconds":null,"isRequired":true,"questions":[{"clientRef":"question","promptMarkdown":"Type yes.","questionType":"short_text","points":1,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}],"chapterId":"c3270000-0000-0000-0000-000000000001"}'::jsonb,
      'c3e40000-0000-0000-0000-000000000003',
      1,
      pg_catalog.decode(pg_catalog.repeat('d7', 32), 'hex'),
      'c3f40000-0000-0000-0000-000000000014'
    );
  EXCEPTION WHEN raise_exception THEN
    v_invalid_input_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_quiz(
      'c3000000-0000-0000-0000-000000000001',
      'c3270000-0000-0000-0000-000000000001',
      '{"slug":"learner-quiz","title":"Learner quiz","instructionsMarkdown":"Learners cannot author.","passingPercent":70,"maxAttempts":null,"timeLimitSeconds":null,"isRequired":true,"questions":[{"clientRef":"question","promptMarkdown":"Type yes.","questionType":"short_text","points":1,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}]}'::jsonb,
      'c3e40000-0000-0000-0000-000000000004',
      1,
      pg_catalog.decode(pg_catalog.repeat('e8', 32), 'hex'),
      'c3f40000-0000-0000-0000-000000000015'
    );
  EXCEPTION WHEN raise_exception THEN
    v_learner_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_quiz(
      'c3000000-0000-0000-0000-000000000005',
      'c3270000-0000-0000-0000-000000000001',
      '{"slug":"missing-key-quiz","title":"Missing key quiz","instructionsMarkdown":"A key is required.","passingPercent":70,"maxAttempts":null,"timeLimitSeconds":null,"isRequired":true,"questions":[{"clientRef":"question","promptMarkdown":"Type yes.","questionType":"short_text","points":1,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}]}'::jsonb,
      NULL,
      1,
      pg_catalog.decode(pg_catalog.repeat('f9', 32), 'hex'),
      'c3f40000-0000-0000-0000-000000000016'
    );
  EXCEPTION WHEN raise_exception THEN
    v_missing_key_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_quiz(
      'c3000000-0000-0000-0000-000000000005',
      'c3270000-0000-0000-0000-000000000999',
      '{"slug":"missing-parent-quiz","title":"Missing parent quiz","instructionsMarkdown":"A parent is required.","passingPercent":70,"maxAttempts":null,"timeLimitSeconds":null,"isRequired":true,"questions":[{"clientRef":"question","promptMarkdown":"Type yes.","questionType":"short_text","points":1,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}]}'::jsonb,
      'c3e40000-0000-0000-0000-000000000005',
      1,
      pg_catalog.decode(pg_catalog.repeat('a6', 32), 'hex'),
      'c3f40000-0000-0000-0000-000000000017'
    );
  EXCEPTION WHEN raise_exception THEN
    v_missing_parent_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_quiz(
      'c3000000-0000-0000-0000-000000000005',
      'c3270000-0000-0000-0000-000000000001',
      '{"slug":"empty-quiz","title":"Empty quiz","instructionsMarkdown":"Empty definitions are rejected.","passingPercent":70,"maxAttempts":null,"timeLimitSeconds":null,"isRequired":true,"questions":[]}'::jsonb,
      'c3e40000-0000-0000-0000-000000000009',
      1,
      pg_catalog.decode(pg_catalog.repeat('b7', 32), 'hex'),
      'c3f40000-0000-0000-0000-000000000023'
    );
  EXCEPTION WHEN raise_exception THEN
    v_empty_definition_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_quiz(
      'c3000000-0000-0000-0000-000000000005',
      'c3270000-0000-0000-0000-000000000001',
      '{"slug":"incomplete-quiz","title":"Incomplete quiz","instructionsMarkdown":"Incomplete definitions are rejected.","passingPercent":70,"maxAttempts":null,"timeLimitSeconds":null,"isRequired":true,"questions":[{"clientRef":"question","promptMarkdown":"Type yes.","questionType":"short_text","points":1,"options":[],"answerSpec":null}]}'::jsonb,
      'c3e40000-0000-0000-0000-000000000010',
      1,
      pg_catalog.decode(pg_catalog.repeat('c8', 32), 'hex'),
      'c3f40000-0000-0000-0000-000000000024'
    );
  EXCEPTION WHEN raise_exception THEN
    v_incomplete_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_quiz(
      'c3000000-0000-0000-0000-000000000005',
      'c3270000-0000-0000-0000-000000000001',
      '{"slug":"one-option-quiz","title":"One option quiz","instructionsMarkdown":"Choice questions need two options.","passingPercent":70,"maxAttempts":null,"timeLimitSeconds":null,"isRequired":true,"questions":[{"clientRef":"question","promptMarkdown":"Choose.","questionType":"single_choice","points":1,"options":[{"clientRef":"only","labelMarkdown":"Only option."}],"answerSpec":{"correctOptionRef":"only"}}]}'::jsonb,
      'c3e40000-0000-0000-0000-000000000011',
      1,
      pg_catalog.decode(pg_catalog.repeat('d9', 32), 'hex'),
      'c3f40000-0000-0000-0000-000000000025'
    );
  EXCEPTION WHEN raise_exception THEN
    v_one_option_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_quiz(
      'c3000000-0000-0000-0000-000000000005',
      'c3270000-0000-0000-0000-000000000001',
      '{"slug":"cross-question-quiz","title":"Cross question quiz","instructionsMarkdown":"Cross-question references are rejected.","passingPercent":70,"maxAttempts":null,"timeLimitSeconds":null,"isRequired":true,"questions":[{"clientRef":"first","promptMarkdown":"Choose first.","questionType":"single_choice","points":1,"options":[{"clientRef":"first-a","labelMarkdown":"First option."},{"clientRef":"first-b","labelMarkdown":"Second option."}],"answerSpec":{"correctOptionRef":"second-a"}},{"clientRef":"second","promptMarkdown":"Choose second.","questionType":"single_choice","points":1,"options":[{"clientRef":"second-a","labelMarkdown":"First option."},{"clientRef":"second-b","labelMarkdown":"Second option."}],"answerSpec":{"correctOptionRef":"second-a"}}]}'::jsonb,
      'c3e40000-0000-0000-0000-000000000012',
      1,
      pg_catalog.decode(pg_catalog.repeat('ea', 32), 'hex'),
      'c3f40000-0000-0000-0000-000000000026'
    );
  EXCEPTION WHEN raise_exception THEN
    v_cross_question_rejected := true;
  END;

  IF v_editor_first.response_status <> 201
    OR v_editor_first.idempotency_replayed
    OR v_editor_first.response_body ->> 'id' IS NULL
    OR v_editor_first.response_location IS DISTINCT FROM
      '/api/v1/admin/quizzes/' || (v_editor_first.response_body ->> 'id')
    OR v_editor_first.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_editor_first.response_body ->> 'id'
    )
    OR NOT v_editor_replay.idempotency_replayed
    OR v_editor_replay.response_status IS DISTINCT FROM v_editor_first.response_status
    OR v_editor_replay.response_location IS DISTINCT FROM v_editor_first.response_location
    OR v_editor_replay.response_body IS DISTINCT FROM v_editor_first.response_body
    OR v_admin_first.response_status <> 201
    OR v_admin_first.idempotency_replayed
    OR v_admin_first.response_body ->> 'id' IS NULL
    OR v_admin_first.response_location IS DISTINCT FROM
      '/api/v1/admin/quizzes/' || (v_admin_first.response_body ->> 'id')
    OR v_admin_first.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_admin_first.response_body ->> 'id'
    )
    OR NOT v_different_hash_rejected
    OR NOT v_invalid_input_rejected
    OR NOT v_learner_rejected
    OR NOT v_missing_key_rejected
    OR NOT v_missing_parent_rejected
    OR NOT v_empty_definition_rejected
    OR NOT v_incomplete_rejected
    OR NOT v_one_option_rejected
    OR NOT v_cross_question_rejected THEN
    RAISE EXCEPTION 'draft-quiz authoring facade did not preserve its secure complete-tree creation and replay contract';
  END IF;
END;
$assessment_create_draft_quiz$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.modules
SET
  status = 'published'::public.content_status,
  published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3170000-0000-0000-0000-000000000001';
UPDATE public.chapters
SET
  status = 'published'::public.content_status,
  published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3270000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $published_hierarchy_quiz_creation$
DECLARE
  v_created record;
BEGIN
  SELECT * INTO v_created
  FROM public.assessment_create_draft_quiz(
    'c3000000-0000-0000-0000-000000000005',
    'c3270000-0000-0000-0000-000000000001',
    '{"slug":"published-hierarchy-complete-quiz","title":"Published hierarchy complete quiz","instructionsMarkdown":"Published ancestors accept complete draft quizzes.","passingPercent":60,"maxAttempts":1,"timeLimitSeconds":300,"isRequired":true,"questions":[{"clientRef":"published-short","promptMarkdown":"Type yes.","questionType":"short_text","points":2,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}]}'::jsonb,
    'c3e40000-0000-0000-0000-000000000007',
    1,
    pg_catalog.decode(pg_catalog.repeat('c7', 32), 'hex'),
    'c3f40000-0000-0000-0000-000000000021'
  );

  IF v_created.response_status <> 201
    OR v_created.idempotency_replayed
    OR v_created.response_body ->> 'id' IS NULL
    OR v_created.response_location IS DISTINCT FROM
      '/api/v1/admin/quizzes/' || (v_created.response_body ->> 'id')
    OR v_created.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id',
      v_created.response_body ->> 'id'
    ) THEN
    RAISE EXCEPTION 'a published hierarchy unexpectedly rejected a complete draft quiz';
  END IF;
END;
$published_hierarchy_quiz_creation$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.chapters
SET status = 'archived'::public.content_status
WHERE id = 'c3270000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $archived_quiz_chapter_replay$
DECLARE
  v_editor_input jsonb :=
    '{"slug":"authoring-editor-complete-quiz","title":"Authoring editor complete quiz","instructionsMarkdown":"Answer every scalar question.","passingPercent":70,"maxAttempts":3,"timeLimitSeconds":600,"isRequired":true,"questions":[{"clientRef":"editor-single","promptMarkdown":"Select the correct option.","questionType":"single_choice","points":5,"options":[{"clientRef":"single-a","labelMarkdown":"Incorrect option."},{"clientRef":"single-b","labelMarkdown":"Correct option."}],"answerSpec":{"correctOptionRef":"single-b"},"feedbackCorrectMarkdown":"Correct.","feedbackIncorrectMarkdown":"Try again."},{"clientRef":"editor-multiple","promptMarkdown":"Select both correct options.","questionType":"multiple_choice","points":10,"options":[{"clientRef":"multiple-a","labelMarkdown":"First correct option."},{"clientRef":"multiple-b","labelMarkdown":"Incorrect option."},{"clientRef":"multiple-c","labelMarkdown":"Second correct option."}],"answerSpec":{"correctOptionRefs":["multiple-c","multiple-a"]},"feedbackCorrectMarkdown":"Correct choices.","feedbackIncorrectMarkdown":"Review the options."},{"clientRef":"editor-short","promptMarkdown":"Type the normalized answer.","questionType":"short_text","points":3,"options":[],"answerSpec":{"acceptedAnswers":["  Da\t","NU"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}]}'::jsonb;
  v_replay record;
  v_archived_chapter_rejected boolean := false;
BEGIN
  SELECT * INTO v_replay
  FROM public.assessment_create_draft_quiz(
    'c3000000-0000-0000-0000-000000000004',
    'c3270000-0000-0000-0000-000000000001',
    v_editor_input,
    'c3e40000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a4', 32), 'hex'),
    'c3f40000-0000-0000-0000-000000000018'
  );

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_quiz(
      'c3000000-0000-0000-0000-000000000005',
      'c3270000-0000-0000-0000-000000000001',
      '{"slug":"archived-chapter-quiz","title":"Archived chapter quiz","instructionsMarkdown":"An archived chapter rejects new quizzes.","passingPercent":70,"maxAttempts":null,"timeLimitSeconds":null,"isRequired":true,"questions":[{"clientRef":"question","promptMarkdown":"Type yes.","questionType":"short_text","points":1,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}]}'::jsonb,
      'c3e40000-0000-0000-0000-000000000006',
      1,
      pg_catalog.decode(pg_catalog.repeat('b6', 32), 'hex'),
      'c3f40000-0000-0000-0000-000000000019'
    );
  EXCEPTION WHEN raise_exception THEN
    v_archived_chapter_rejected := true;
  END;

  IF NOT v_replay.idempotency_replayed
    OR v_replay.response_status <> 201
    OR v_replay.response_body ->> 'id' IS NULL
    OR NOT v_archived_chapter_rejected THEN
    RAISE EXCEPTION 'quiz replay did not remain stable across a later chapter archive';
  END IF;
END;
$archived_quiz_chapter_replay$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.modules
SET status = 'archived'::public.content_status
WHERE id = 'c3170000-0000-0000-0000-000000000001';
UPDATE public.modules
SET status = 'archived'::public.content_status
WHERE id = 'c3180000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $archived_quiz_module_replay$
DECLARE
  v_editor_input jsonb :=
    '{"slug":"authoring-editor-complete-quiz","title":"Authoring editor complete quiz","instructionsMarkdown":"Answer every scalar question.","passingPercent":70,"maxAttempts":3,"timeLimitSeconds":600,"isRequired":true,"questions":[{"clientRef":"editor-single","promptMarkdown":"Select the correct option.","questionType":"single_choice","points":5,"options":[{"clientRef":"single-a","labelMarkdown":"Incorrect option."},{"clientRef":"single-b","labelMarkdown":"Correct option."}],"answerSpec":{"correctOptionRef":"single-b"},"feedbackCorrectMarkdown":"Correct.","feedbackIncorrectMarkdown":"Try again."},{"clientRef":"editor-multiple","promptMarkdown":"Select both correct options.","questionType":"multiple_choice","points":10,"options":[{"clientRef":"multiple-a","labelMarkdown":"First correct option."},{"clientRef":"multiple-b","labelMarkdown":"Incorrect option."},{"clientRef":"multiple-c","labelMarkdown":"Second correct option."}],"answerSpec":{"correctOptionRefs":["multiple-c","multiple-a"]},"feedbackCorrectMarkdown":"Correct choices.","feedbackIncorrectMarkdown":"Review the options."},{"clientRef":"editor-short","promptMarkdown":"Type the normalized answer.","questionType":"short_text","points":3,"options":[],"answerSpec":{"acceptedAnswers":["  Da\t","NU"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}]}'::jsonb;
  v_replay record;
  v_archived_module_rejected boolean := false;
BEGIN
  SELECT * INTO v_replay
  FROM public.assessment_create_draft_quiz(
    'c3000000-0000-0000-0000-000000000004',
    'c3270000-0000-0000-0000-000000000001',
    v_editor_input,
    'c3e40000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('a4', 32), 'hex'),
    'c3f40000-0000-0000-0000-000000000027'
  );

  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_quiz(
      'c3000000-0000-0000-0000-000000000005',
      'c3280000-0000-0000-0000-000000000001',
      '{"slug":"archived-module-quiz","title":"Archived module quiz","instructionsMarkdown":"An archived module rejects new quizzes.","passingPercent":70,"maxAttempts":null,"timeLimitSeconds":null,"isRequired":true,"questions":[{"clientRef":"question","promptMarkdown":"Type yes.","questionType":"short_text","points":1,"options":[],"answerSpec":{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}]}'::jsonb,
      'c3e40000-0000-0000-0000-000000000008',
      1,
      pg_catalog.decode(pg_catalog.repeat('c8', 32), 'hex'),
      'c3f40000-0000-0000-0000-000000000022'
    );
  EXCEPTION WHEN raise_exception THEN
    v_archived_module_rejected := true;
  END;

  IF NOT v_replay.idempotency_replayed
    OR v_replay.response_status <> 201
    OR v_replay.response_body ->> 'id' IS NULL
    OR NOT v_archived_module_rejected THEN
    RAISE EXCEPTION 'quiz replay did not remain stable across a later module archive';
  END IF;
END;
$archived_quiz_module_replay$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = pg_catalog.clock_timestamp()
WHERE id = 'c3000000-0000-0000-0000-000000000004';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $held_staff_quiz_replay_denial$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM *
    FROM public.assessment_create_draft_quiz(
      'c3000000-0000-0000-0000-000000000004',
      'c3270000-0000-0000-0000-000000000001',
      '{"slug":"authoring-editor-complete-quiz","title":"Authoring editor complete quiz","instructionsMarkdown":"Answer every scalar question.","passingPercent":70,"maxAttempts":3,"timeLimitSeconds":600,"isRequired":true,"questions":[{"clientRef":"editor-single","promptMarkdown":"Select the correct option.","questionType":"single_choice","points":5,"options":[{"clientRef":"single-a","labelMarkdown":"Incorrect option."},{"clientRef":"single-b","labelMarkdown":"Correct option."}],"answerSpec":{"correctOptionRef":"single-b"},"feedbackCorrectMarkdown":"Correct.","feedbackIncorrectMarkdown":"Try again."},{"clientRef":"editor-multiple","promptMarkdown":"Select both correct options.","questionType":"multiple_choice","points":10,"options":[{"clientRef":"multiple-a","labelMarkdown":"First correct option."},{"clientRef":"multiple-b","labelMarkdown":"Incorrect option."},{"clientRef":"multiple-c","labelMarkdown":"Second correct option."}],"answerSpec":{"correctOptionRefs":["multiple-c","multiple-a"]},"feedbackCorrectMarkdown":"Correct choices.","feedbackIncorrectMarkdown":"Review the options."},{"clientRef":"editor-short","promptMarkdown":"Type the normalized answer.","questionType":"short_text","points":3,"options":[],"answerSpec":{"acceptedAnswers":["  Da\t","NU"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}]}'::jsonb,
      'c3e40000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('a4', 32), 'hex'),
      'c3f40000-0000-0000-0000-000000000020'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;

  IF NOT v_rejected THEN
    RAISE EXCEPTION 'held staff actor unexpectedly received a quiz-create replay';
  END IF;
END;
$held_staff_quiz_replay_denial$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = NULL
WHERE id = 'c3000000-0000-0000-0000-000000000004';

SELECT extensions.ok(
  EXISTS (
    SELECT 1
    FROM public.quizzes AS quiz
    WHERE quiz.id = 'c3520000-0000-0000-0000-000000000001'
      AND quiz.status = 'archived'::public.content_status
      AND quiz.position = 0
  )
  AND (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        quiz.chapter_id = 'c3270000-0000-0000-0000-000000000001'
        AND quiz.status = 'draft'::public.content_status
        AND quiz.published_at IS NULL
        AND quiz.row_version = 1
        AND quiz.definition_version = 1
      )
    FROM public.quizzes AS quiz
    WHERE quiz.title IN (
      'Authoring editor complete quiz',
      'Authoring admin complete quiz',
      'Published hierarchy complete quiz'
    )
  )
  AND EXISTS (
    SELECT 1
    FROM public.quizzes AS quiz
    WHERE quiz.title = 'Authoring editor complete quiz'
      AND quiz.slug = 'authoring-editor-complete-quiz'
      AND quiz.position = 1
      AND quiz.passing_percent = 70
      AND quiz.max_attempts = 3
      AND quiz.time_limit_seconds = 600
      AND quiz.is_required
      AND quiz.created_by = 'c3000000-0000-0000-0000-000000000004'
      AND quiz.updated_by = 'c3000000-0000-0000-0000-000000000004'
      AND (
        SELECT pg_catalog.count(*) = 3
          AND pg_catalog.array_agg(question.position ORDER BY question.position)
            = ARRAY[0, 1, 2]::integer[]
        FROM public.quiz_questions AS question
        WHERE question.quiz_id = quiz.id
      )
  )
  AND EXISTS (
    SELECT 1
    FROM public.quizzes AS quiz
    JOIN public.quiz_questions AS question
      ON question.quiz_id = quiz.id
    JOIN private.quiz_question_answer_keys AS answer_key
      ON answer_key.question_id = question.id
    WHERE quiz.title = 'Authoring editor complete quiz'
      AND question.position = 0
      AND question.question_type = 'single_choice'::public.question_type
      AND question.points = 5
      AND answer_key.answer_spec = pg_catalog.jsonb_build_object(
        'correctOptionId',
        (
          SELECT option_entry.id::text
          FROM public.quiz_question_options AS option_entry
          WHERE option_entry.question_id = question.id
            AND option_entry.position = 1
        )
      )
      AND NOT (answer_key.answer_spec OPERATOR(pg_catalog.?) 'correctOptionRef')
      AND answer_key.feedback_correct_markdown = 'Correct.'
      AND answer_key.feedback_incorrect_markdown = 'Try again.'
      AND answer_key.created_by = 'c3000000-0000-0000-0000-000000000004'
      AND answer_key.updated_by = 'c3000000-0000-0000-0000-000000000004'
      AND (
        SELECT pg_catalog.count(*) = 2
          AND pg_catalog.array_agg(option_entry.position ORDER BY option_entry.position)
            = ARRAY[0, 1]::integer[]
        FROM public.quiz_question_options AS option_entry
        WHERE option_entry.question_id = question.id
      )
  )
  AND EXISTS (
    SELECT 1
    FROM public.quizzes AS quiz
    JOIN public.quiz_questions AS question
      ON question.quiz_id = quiz.id
    JOIN private.quiz_question_answer_keys AS answer_key
      ON answer_key.question_id = question.id
    WHERE quiz.title = 'Authoring editor complete quiz'
      AND question.position = 1
      AND question.question_type = 'multiple_choice'::public.question_type
      AND question.points = 10
      AND answer_key.answer_spec = pg_catalog.jsonb_build_object(
        'correctOptionIds',
        (
          SELECT pg_catalog.jsonb_agg(
            pg_catalog.to_jsonb(option_entry.id::text)
            ORDER BY option_entry.id::text COLLATE "C"
          )
          FROM public.quiz_question_options AS option_entry
          WHERE option_entry.question_id = question.id
            AND option_entry.position IN (0, 2)
        )
      )
      AND NOT (answer_key.answer_spec OPERATOR(pg_catalog.?) 'correctOptionRefs')
      AND answer_key.feedback_correct_markdown = 'Correct choices.'
      AND answer_key.feedback_incorrect_markdown = 'Review the options.'
      AND answer_key.created_by = 'c3000000-0000-0000-0000-000000000004'
      AND answer_key.updated_by = 'c3000000-0000-0000-0000-000000000004'
      AND (
        SELECT pg_catalog.count(*) = 3
          AND pg_catalog.array_agg(option_entry.position ORDER BY option_entry.position)
            = ARRAY[0, 1, 2]::integer[]
        FROM public.quiz_question_options AS option_entry
        WHERE option_entry.question_id = question.id
      )
  )
  AND EXISTS (
    SELECT 1
    FROM public.quizzes AS quiz
    JOIN public.quiz_questions AS question
      ON question.quiz_id = quiz.id
    JOIN private.quiz_question_answer_keys AS answer_key
      ON answer_key.question_id = question.id
    WHERE quiz.title = 'Authoring editor complete quiz'
      AND question.position = 2
      AND question.question_type = 'short_text'::public.question_type
      AND question.points = 3
      AND answer_key.answer_spec =
        '{"acceptedAnswers":["da","nu"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}'::jsonb
      AND answer_key.feedback_correct_markdown IS NULL
      AND answer_key.feedback_incorrect_markdown IS NULL
      AND answer_key.created_by = 'c3000000-0000-0000-0000-000000000004'
      AND answer_key.updated_by = 'c3000000-0000-0000-0000-000000000004'
      AND NOT EXISTS (
        SELECT 1
        FROM public.quiz_question_options AS option_entry
        WHERE option_entry.question_id = question.id
      )
  )
  AND EXISTS (
    SELECT 1
    FROM public.quizzes AS quiz
    JOIN public.quiz_questions AS question
      ON question.quiz_id = quiz.id
    JOIN private.quiz_question_answer_keys AS answer_key
      ON answer_key.question_id = question.id
    WHERE quiz.title = 'Authoring admin complete quiz'
      AND quiz.slug = 'authoring-admin-complete-quiz'
      AND quiz.position = 2
      AND quiz.passing_percent = 80
      AND quiz.max_attempts IS NULL
      AND quiz.time_limit_seconds IS NULL
      AND NOT quiz.is_required
      AND quiz.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND quiz.updated_by = 'c3000000-0000-0000-0000-000000000005'
      AND question.position = 0
      AND question.question_type = 'short_text'::public.question_type
      AND answer_key.answer_spec =
        '{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}'::jsonb
      AND answer_key.feedback_correct_markdown = 'Correct.'
      AND answer_key.feedback_incorrect_markdown = 'Try again.'
      AND answer_key.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND answer_key.updated_by = 'c3000000-0000-0000-0000-000000000005'
  )
  AND EXISTS (
    SELECT 1
    FROM public.quizzes AS quiz
    JOIN public.quiz_questions AS question
      ON question.quiz_id = quiz.id
    JOIN private.quiz_question_answer_keys AS answer_key
      ON answer_key.question_id = question.id
    WHERE quiz.title = 'Published hierarchy complete quiz'
      AND quiz.slug = 'published-hierarchy-complete-quiz'
      AND quiz.position = 3
      AND quiz.passing_percent = 60
      AND quiz.max_attempts = 1
      AND quiz.time_limit_seconds = 300
      AND quiz.is_required
      AND quiz.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND quiz.updated_by = 'c3000000-0000-0000-0000-000000000005'
      AND question.position = 0
      AND question.question_type = 'short_text'::public.question_type
      AND answer_key.answer_spec =
        '{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}'::jsonb
      AND answer_key.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND answer_key.updated_by = 'c3000000-0000-0000-0000-000000000005'
  )
  AND EXISTS (
    SELECT 1
    FROM public.modules AS module_entry
    WHERE module_entry.id = 'c3170000-0000-0000-0000-000000000001'
      AND module_entry.status = 'archived'::public.content_status
      AND module_entry.published_at IS NOT NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.chapters AS chapter_entry
    WHERE chapter_entry.id = 'c3270000-0000-0000-0000-000000000001'
      AND chapter_entry.status = 'archived'::public.content_status
      AND chapter_entry.published_at IS NOT NULL
  )
  AND EXISTS (
    SELECT 1
    FROM public.modules AS module_entry
    WHERE module_entry.id = 'c3180000-0000-0000-0000-000000000001'
      AND module_entry.status = 'archived'::public.content_status
  )
  AND (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        record_entry.response_status = 201
        AND record_entry.response_location =
          '/api/v1/admin/quizzes/' || record_entry.result_resource_id::text
        AND record_entry.response_body = pg_catalog.jsonb_build_object(
          'id',
          record_entry.result_resource_id::text
        )
      )
    FROM private.idempotency_records AS record_entry
    WHERE record_entry.operation = 'admin_create_quiz'
      AND record_entry.idempotency_key IN (
        'c3e40000-0000-0000-0000-000000000001',
        'c3e40000-0000-0000-0000-000000000002',
        'c3e40000-0000-0000-0000-000000000007'
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM private.idempotency_records AS record_entry
    WHERE record_entry.operation = 'admin_create_quiz'
      AND record_entry.idempotency_key IN (
        'c3e40000-0000-0000-0000-000000000003',
        'c3e40000-0000-0000-0000-000000000004',
        'c3e40000-0000-0000-0000-000000000005',
        'c3e40000-0000-0000-0000-000000000006',
        'c3e40000-0000-0000-0000-000000000008',
        'c3e40000-0000-0000-0000-000000000009',
        'c3e40000-0000-0000-0000-000000000010',
        'c3e40000-0000-0000-0000-000000000011',
        'c3e40000-0000-0000-0000-000000000012'
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.quizzes AS quiz
    WHERE quiz.title IN (
      'Invalid quiz',
      'Learner quiz',
      'Missing key quiz',
      'Missing parent quiz',
      'Empty quiz',
      'Incomplete quiz',
      'One option quiz',
      'Cross question quiz',
      'Archived chapter quiz',
      'Archived module quiz'
    )
  )
  AND (
    SELECT pg_catalog.count(*) = 3
      AND pg_catalog.bool_and(
        audit_entry.changed_fields = ARRAY['status']::text[]
        AND audit_entry.change_summary =
          '{"status":{"before":"none","after":"draft"}}'::jsonb
        AND audit_entry.reason IS NULL
      )
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action = 'quiz_created'
      AND audit_entry.entity_type = 'quiz'
      AND audit_entry.entity_id IN (
        SELECT quiz.id
        FROM public.quizzes AS quiz
        WHERE quiz.title IN (
          'Authoring editor complete quiz',
          'Authoring admin complete quiz',
          'Published hierarchy complete quiz'
        )
      )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.request_id IN (
      'c3f40000-0000-0000-0000-000000000011',
      'c3f40000-0000-0000-0000-000000000018',
      'c3f40000-0000-0000-0000-000000000027',
      'c3f40000-0000-0000-0000-000000000020'
    )
  )
  AND COALESCE(
    pg_catalog.current_setting('coditza.assessment_tree_root', true),
    ''
  ) = '',
  'complete quiz creation locks the module and chapter scope, materializes private question trees, preserves safe replay, and denies archived or held writes'
);

INSERT INTO public.modules (
  id, slug, title, description_markdown, position
)
VALUES (
  'c3100000-0000-0000-0000-000000000001',
  'functions-module',
  'Functions module',
  'Synthetic module for public function verification.',
  810
);

INSERT INTO public.chapters (
  id, module_id, slug, title, summary_markdown, position, estimated_minutes
)
VALUES (
  'c3200000-0000-0000-0000-000000000001',
  'c3100000-0000-0000-0000-000000000001',
  'functions-chapter',
  'Functions chapter',
  'Synthetic chapter for public function verification.',
  0,
  25
);

INSERT INTO public.theory_sections (
  id, chapter_id, title, body_markdown, position, estimated_minutes
)
VALUES (
  'c3300000-0000-0000-0000-000000000001',
  'c3200000-0000-0000-0000-000000000001',
  'Functions theory',
  'Theory fixture for progress-function verification.',
  0,
  10
);

INSERT INTO public.exercises (
  id, chapter_id, title, prompt_markdown, exercise_type, position, points, is_required
)
VALUES (
  'c3400000-0000-0000-0000-000000000001',
  'c3200000-0000-0000-0000-000000000001',
  'Public scalar exercise',
  'Type yes.',
  'short_text',
  0,
  5,
  true
);
SELECT pg_catalog.set_config(
  'coditza.assessment_tree_root',
  'exercise:c3400000-0000-0000-0000-000000000001',
  true
);
INSERT INTO private.exercise_answer_keys (
  exercise_id,
  answer_spec,
  feedback_correct_markdown,
  feedback_incorrect_markdown
)
VALUES (
  'c3400000-0000-0000-0000-000000000001',
  '{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}'::jsonb,
  'Corect.',
  'Încearcă din nou.'
);
SELECT pg_catalog.set_config('coditza.assessment_tree_root', '', true);

INSERT INTO public.quizzes (
  id, chapter_id, slug, title, instructions_markdown, position, passing_percent, max_attempts, time_limit_seconds, is_required
)
VALUES (
  'c3500000-0000-0000-0000-000000000001',
  'c3200000-0000-0000-0000-000000000001',
  'functions-quiz',
  'Functions quiz',
  'Answer the public question.',
  0,
  50,
  2,
  NULL,
  true
);
SELECT pg_catalog.set_config(
  'coditza.assessment_tree_root',
  'quiz:c3500000-0000-0000-0000-000000000001',
  true
);
INSERT INTO public.quiz_questions (
  id, quiz_id, prompt_markdown, question_type, position, points
)
VALUES (
  'c3600000-0000-0000-0000-000000000001',
  'c3500000-0000-0000-0000-000000000001',
  'Type yes.',
  'short_text',
  0,
  10
);
INSERT INTO private.quiz_question_answer_keys (
  question_id,
  answer_spec,
  feedback_correct_markdown,
  feedback_incorrect_markdown
)
VALUES (
  'c3600000-0000-0000-0000-000000000001',
  '{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}'::jsonb,
  'Răspuns corect.',
  'Răspuns incorect.'
);
SELECT pg_catalog.set_config('coditza.assessment_tree_root', '', true);

UPDATE public.modules
SET status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3100000-0000-0000-0000-000000000001';
UPDATE public.chapters
SET status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3200000-0000-0000-0000-000000000001';
UPDATE public.theory_sections
SET status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3300000-0000-0000-0000-000000000001';
UPDATE public.exercises
SET status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3400000-0000-0000-0000-000000000001';
UPDATE public.quizzes
SET status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3500000-0000-0000-0000-000000000001';

RESET ROLE;
SET LOCAL ROLE service_role;
DO $theory_completion_replay_and_remove$
DECLARE
  v_first record;
  v_replay record;
  v_remove record;
  v_final_set record;
  v_rejected boolean := false;
BEGIN
  SELECT * INTO v_first
  FROM public.progress_set_theory_completion(
    'c3000000-0000-0000-0000-000000000001',
    'c3300000-0000-0000-0000-000000000001',
    true,
    'c3a00000-0000-0000-0000-000000000014'
  );
  SELECT * INTO v_replay
  FROM public.progress_set_theory_completion(
    'c3000000-0000-0000-0000-000000000001',
    'c3300000-0000-0000-0000-000000000001',
    true,
    'c3a00000-0000-0000-0000-000000000015'
  );
  SELECT * INTO v_remove
  FROM public.progress_set_theory_completion(
    'c3000000-0000-0000-0000-000000000001',
    'c3300000-0000-0000-0000-000000000001',
    false,
    'c3a00000-0000-0000-0000-000000000016'
  );
  SELECT * INTO v_final_set
  FROM public.progress_set_theory_completion(
    'c3000000-0000-0000-0000-000000000001',
    'c3300000-0000-0000-0000-000000000001',
    true,
    'c3a00000-0000-0000-0000-000000000017'
  );

  BEGIN
    PERFORM *
    FROM public.progress_set_theory_completion(
      'c3000000-0000-0000-0000-000000000001',
      'c3300000-0000-0000-0000-000000000001',
      NULL,
      'c3a00000-0000-0000-0000-000000000018'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;

  IF v_first.response_status <> 200
    OR v_first.response_body ->> 'sectionId'
      <> 'c3300000-0000-0000-0000-000000000001'
    OR v_first.response_body ->> 'completedAt' IS NULL
    OR (v_first.response_body -> 'chapterProgress' ->> 'theoryPercent')::numeric <> 100
    OR v_replay.response_body IS DISTINCT FROM v_first.response_body
    OR v_remove.response_status <> 204
    OR v_remove.response_body IS NOT NULL
    OR v_final_set.response_status <> 200
    OR NOT v_rejected THEN
    RAISE EXCEPTION 'theory completion facade did not preserve its safe idempotent mutation contract';
  END IF;
END;
$theory_completion_replay_and_remove$;
RESET ROLE;
SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 2
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action = 'theory_completion_set'
      AND audit_entry.entity_id = 'c3300000-0000-0000-0000-000000000001'
  )
  AND (
    SELECT pg_catalog.count(*) = 1
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action = 'theory_completion_removed'
      AND audit_entry.entity_id = 'c3300000-0000-0000-0000-000000000001'
  ),
  'theory completion records only actual set/remove transitions and rejects a null mutation flag'
);

RESET ROLE;
SET LOCAL ROLE service_role;
DO $exercise_replay$
DECLARE
  v_first record;
  v_replay record;
BEGIN
  SELECT * INTO v_first
  FROM public.assessment_submit_exercise_attempt(
    'c3000000-0000-0000-0000-000000000001',
    'c3400000-0000-0000-0000-000000000001',
    '{"text":" YES "}'::jsonb,
    'c3700000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('11', 32), 'hex'),
    'c3a00000-0000-0000-0000-000000000001'
  );
  SELECT * INTO v_replay
  FROM public.assessment_submit_exercise_attempt(
    'c3000000-0000-0000-0000-000000000001',
    'c3400000-0000-0000-0000-000000000001',
    '{"text":" YES "}'::jsonb,
    'c3700000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('11', 32), 'hex'),
    'c3a00000-0000-0000-0000-000000000002'
  );
  IF v_first.response_status <> 201
    OR v_first.response_location !~ '^/api/v1/me/exercise-attempts/'
    OR v_first.idempotency_replayed
    OR NOT (v_first.response_body ->> 'isCorrect')::boolean
    OR v_first.response_body ->> 'feedbackMarkdown' <> 'Corect.'
    OR v_first.response_body ? 'answer'
    OR v_first.response_body::text ~ 'acceptedAnswers'
    OR NOT v_replay.idempotency_replayed
    OR v_replay.response_status <> 201
    OR v_replay.response_location IS DISTINCT FROM v_first.response_location
    OR v_replay.response_body IS DISTINCT FROM v_first.response_body THEN
    RAISE EXCEPTION 'exercise facade did not preserve the safe original replay envelope';
  END IF;
END;
$exercise_replay$;
RESET ROLE;
SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 1
    FROM public.exercise_attempts AS attempt
    WHERE attempt.user_id = 'c3000000-0000-0000-0000-000000000001'
  )
  AND (
    SELECT pg_catalog.count(*) = 1
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action = 'exercise_attempt_submitted'
      AND audit_entry.request_id = 'c3a00000-0000-0000-0000-000000000001'
      AND audit_entry.changed_fields = ARRAY['status']::text[]
      AND audit_entry.change_summary = '{"status":{"before":"none","after":"submitted"}}'::jsonb
  ),
  'exercise facade stores and replays the complete safe result without duplicate attempts or audit events'
);

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = pg_catalog.clock_timestamp()
WHERE id = 'c3000000-0000-0000-0000-000000000001';
RESET ROLE;
SET LOCAL ROLE service_role;
DO $held_replay_denial$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM *
    FROM public.assessment_submit_exercise_attempt(
      'c3000000-0000-0000-0000-000000000001',
      'c3400000-0000-0000-0000-000000000001',
      '{"text":" YES "}'::jsonb,
      'c3700000-0000-0000-0000-000000000001',
      1,
      pg_catalog.decode(pg_catalog.repeat('11', 32), 'hex'),
      'c3a00000-0000-0000-0000-000000000003'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'held actor unexpectedly received an idempotency replay';
  END IF;
END;
$held_replay_denial$;
RESET ROLE;
SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = NULL
WHERE id = 'c3000000-0000-0000-0000-000000000001';
RESET ROLE;
SELECT extensions.ok(TRUE, 'a current security hold denies even a previously stored replay');

SET LOCAL ROLE service_role;
DO $quiz_start_replay$
DECLARE
  v_first record;
  v_replay record;
BEGIN
  SELECT * INTO v_first
  FROM public.assessment_start_quiz_attempt(
    'c3000000-0000-0000-0000-000000000001',
    'c3500000-0000-0000-0000-000000000001',
    'c3800000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('22', 32), 'hex'),
    'c3a00000-0000-0000-0000-000000000004'
  );
  SELECT * INTO v_replay
  FROM public.assessment_start_quiz_attempt(
    'c3000000-0000-0000-0000-000000000001',
    'c3500000-0000-0000-0000-000000000001',
    'c3800000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('22', 32), 'hex'),
    'c3a00000-0000-0000-0000-000000000005'
  );
  IF v_first.response_status <> 201
    OR v_first.idempotency_replayed
    OR v_first.response_body ->> 'status' <> 'in_progress'
    OR pg_catalog.jsonb_array_length(v_first.response_body -> 'questions') <> 1
    OR pg_catalog.jsonb_array_length(v_first.response_body -> 'savedAnswers') <> 0
    OR v_first.response_body::text ~ '(acceptedAnswers|answerSpec|feedback)'
    OR NOT v_replay.idempotency_replayed
    OR v_replay.response_body IS DISTINCT FROM v_first.response_body THEN
    RAISE EXCEPTION 'quiz-start facade did not retain the exact safe start envelope';
  END IF;
END;
$quiz_start_replay$;
RESET ROLE;
SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 1
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action = 'quiz_attempt_started'
      AND audit_entry.request_id = 'c3a00000-0000-0000-0000-000000000004'
  ),
  'quiz start records one safe audit event only for the new attempt'
);

SET LOCAL ROLE service_role;
DO $quiz_save_remove_submit$
DECLARE
  v_attempt_id uuid;
  v_save record;
  v_remove record;
  v_submit record;
  v_terminal_replay record;
BEGIN
  SELECT (start_replay.response_body ->> 'id')::uuid
  INTO v_attempt_id
  FROM public.assessment_start_quiz_attempt(
    'c3000000-0000-0000-0000-000000000001',
    'c3500000-0000-0000-0000-000000000001',
    'c3800000-0000-0000-0000-000000000001',
    1,
    pg_catalog.decode(pg_catalog.repeat('22', 32), 'hex'),
    'c3a00000-0000-0000-0000-000000000011'
  ) AS start_replay;

  SELECT * INTO v_save
  FROM public.assessment_save_quiz_answer(
    'c3000000-0000-0000-0000-000000000001',
    v_attempt_id,
    'c3600000-0000-0000-0000-000000000001',
    '{"text":"yes"}'::jsonb,
    'c3a00000-0000-0000-0000-000000000006'
  );
  SELECT * INTO v_remove
  FROM public.assessment_remove_quiz_answer(
    'c3000000-0000-0000-0000-000000000001',
    v_attempt_id,
    'c3600000-0000-0000-0000-000000000001',
    'c3a00000-0000-0000-0000-000000000007'
  );
  PERFORM *
  FROM public.assessment_save_quiz_answer(
    'c3000000-0000-0000-0000-000000000001',
    v_attempt_id,
    'c3600000-0000-0000-0000-000000000001',
    '{"text":"yes"}'::jsonb,
    'c3a00000-0000-0000-0000-000000000008'
  );
  -- A transport retry with an unchanged answer must not create an audit
  -- transition. It remains a normal 200 response because this endpoint does
  -- not use an idempotency envelope.
  PERFORM *
  FROM public.assessment_save_quiz_answer(
    'c3000000-0000-0000-0000-000000000001',
    v_attempt_id,
    'c3600000-0000-0000-0000-000000000001',
    '{"text":"yes"}'::jsonb,
    'c3a00000-0000-0000-0000-000000000012'
  );
  SELECT * INTO v_submit
  FROM public.assessment_submit_quiz_attempt(
    'c3000000-0000-0000-0000-000000000001',
    v_attempt_id,
    'c3a00000-0000-0000-0000-000000000009'
  );
  SELECT * INTO v_terminal_replay
  FROM public.assessment_submit_quiz_attempt(
    'c3000000-0000-0000-0000-000000000001',
    v_attempt_id,
    'c3a00000-0000-0000-0000-000000000010'
  );

  IF v_save.response_status <> 200
    OR v_save.response_body ? 'isCorrect'
    OR v_save.response_body -> 'answer' IS DISTINCT FROM '{"text":"yes"}'::jsonb
    OR v_remove.response_status <> 204
    OR v_submit.response_status <> 200
    OR v_submit.response_body ->> 'status' <> 'submitted'
    OR pg_catalog.jsonb_array_length(v_submit.response_body -> 'answers') <> 1
    OR (v_submit.response_body -> 'answers' -> 0 ->> 'isCorrect') <> 'true'
    OR v_submit.response_body -> 'answers' -> 0 ->> 'feedbackMarkdown' <> 'Răspuns corect.'
    OR v_submit.response_body::text ~ '(acceptedAnswers|answerSpec|correctOption)'
    OR v_terminal_replay.response_body IS DISTINCT FROM v_submit.response_body THEN
    RAISE EXCEPTION 'quiz save/remove/submit facades did not retain the safe owner projection';
  END IF;
END;
$quiz_save_remove_submit$;
RESET ROLE;
SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 1
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action = 'quiz_attempt_finalized'
      AND audit_entry.request_id = 'c3a00000-0000-0000-0000-000000000009'
      AND audit_entry.change_summary = '{"status":{"before":"in_progress","after":"submitted"}}'::jsonb
  )
  AND (
    SELECT pg_catalog.count(*) = 3
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action IN ('quiz_answer_saved', 'quiz_answer_removed')
      AND audit_entry.changed_fields = ARRAY[]::text[]
      AND audit_entry.change_summary = '{}'::jsonb
  ),
  'quiz mutation and terminal replay preserve protected answer audit boundaries without duplicate finalization'
);

-- Build a structurally valid, already-expired active attempt as a fixture.
-- The test then proves that the public start facade, rather than this setup,
-- performs the terminal transition and records the protected audit event.
SET LOCAL ROLE coditza_owner;
SELECT pg_catalog.set_config('coditza.learning_write', 'quiz-start', true);
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
  'c3900000-0000-0000-0000-000000000001',
  'c3000000-0000-0000-0000-000000000001',
  'c3500000-0000-0000-0000-000000000001',
  1,
  2,
  pg_catalog.now() - pg_catalog.interval '2 minutes',
  pg_catalog.now() - pg_catalog.interval '1 minute'
);
SELECT pg_catalog.set_config('coditza.learning_write', '', true);
RESET ROLE;

SET LOCAL ROLE service_role;
DO $expired_quiz_start$
DECLARE
  v_result record;
BEGIN
  SELECT * INTO v_result
  FROM public.assessment_start_quiz_attempt(
    'c3000000-0000-0000-0000-000000000001',
    'c3500000-0000-0000-0000-000000000001',
    'c3800000-0000-0000-0000-000000000002',
    1,
    pg_catalog.decode(pg_catalog.repeat('33', 32), 'hex'),
    'c3a00000-0000-0000-0000-000000000013'
  );
  IF v_result.response_status <> 422
    OR v_result.idempotency_replayed
    OR v_result.response_body
      IS DISTINCT FROM '{"outcome":"attempt_limit_reached"}'::jsonb THEN
    RAISE EXCEPTION 'expired quiz start did not return the safe attempt-limit outcome';
  END IF;
END;
$expired_quiz_start$;
RESET ROLE;
SELECT extensions.ok(
  (
    SELECT attempt.status = 'expired'::public.quiz_attempt_status
    FROM public.quiz_attempts AS attempt
    WHERE attempt.id = 'c3900000-0000-0000-0000-000000000001'
  )
  AND (
    SELECT pg_catalog.count(*) = 1
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action = 'quiz_attempt_finalized'
      AND audit_entry.entity_id = 'c3900000-0000-0000-0000-000000000001'
      AND audit_entry.request_id = 'c3a00000-0000-0000-0000-000000000013'
      AND audit_entry.change_summary
        = '{"status":{"before":"in_progress","after":"expired"}}'::jsonb
  ),
  'quiz start finalizes a stale attempt before returning the limit outcome and records its safe audit transition'
);

-- Build source activity without its derived snapshot. This is a controlled
-- fixture for the GET-only fallback: reads must derive current completion
-- without fabricating an irreversible completed timestamp.
SET LOCAL ROLE coditza_owner;
SELECT pg_catalog.set_config(
  'coditza.learning_write',
  'theory:c3000000-0000-0000-0000-000000000003:c3300000-0000-0000-0000-000000000001',
  true
);
INSERT INTO public.theory_section_completions (user_id, theory_section_id)
VALUES (
  'c3000000-0000-0000-0000-000000000003',
  'c3300000-0000-0000-0000-000000000001'
);
SELECT pg_catalog.set_config('coditza.learning_write', '', true);
SELECT pg_catalog.set_config('coditza.learning_write', 'exercise', true);
INSERT INTO public.exercise_attempts (
  id,
  user_id,
  exercise_id,
  exercise_definition_version,
  answer,
  is_correct,
  points_earned,
  points_possible
)
VALUES (
  'c3b00000-0000-0000-0000-000000000001',
  'c3000000-0000-0000-0000-000000000003',
  'c3400000-0000-0000-0000-000000000001',
  1,
  '{"text":"yes"}'::jsonb,
  true,
  5,
  5
);
SELECT pg_catalog.set_config('coditza.learning_write', '', true);
SELECT pg_catalog.set_config('coditza.learning_write', 'quiz-start', true);
INSERT INTO public.quiz_attempts (
  id,
  user_id,
  quiz_id,
  quiz_definition_version,
  attempt_number,
  status,
  submitted_at,
  points_earned,
  points_possible,
  score_percent,
  passed
)
VALUES (
  'c3c00000-0000-0000-0000-000000000001',
  'c3000000-0000-0000-0000-000000000003',
  'c3500000-0000-0000-0000-000000000001',
  1,
  1,
  'submitted'::public.quiz_attempt_status,
  pg_catalog.now(),
  10,
  10,
  100,
  true
);
SELECT pg_catalog.set_config('coditza.learning_write', '', true);
RESET ROLE;

SET LOCAL ROLE service_role;
DO $progress_reads_and_completed_removal_guard$
DECLARE
  v_owner_list jsonb;
  v_owner_detail jsonb;
  v_fresh_list jsonb;
  v_fresh_detail jsonb;
  v_fallback_list jsonb;
  v_fallback_detail jsonb;
  v_rejected boolean := false;
  v_invalid_cursor_rejected boolean := false;
  v_invalid_limit_rejected boolean := false;
BEGIN
  v_owner_list := public.progress_list_own_modules(
    'c3000000-0000-0000-0000-000000000001',
    NULL,
    NULL,
    1
  );
  v_owner_detail := public.progress_get_own_module(
    'c3000000-0000-0000-0000-000000000001',
    'c3100000-0000-0000-0000-000000000001'
  );
  v_fresh_list := public.progress_list_own_modules(
    'c3000000-0000-0000-0000-000000000002',
    NULL,
    NULL,
    1
  );
  v_fresh_detail := public.progress_get_own_module(
    'c3000000-0000-0000-0000-000000000002',
    'c3100000-0000-0000-0000-000000000001'
  );
  v_fallback_list := public.progress_list_own_modules(
    'c3000000-0000-0000-0000-000000000003',
    NULL,
    NULL,
    100
  );
  v_fallback_detail := public.progress_get_own_module(
    'c3000000-0000-0000-0000-000000000003',
    'c3100000-0000-0000-0000-000000000001'
  );

  BEGIN
    PERFORM *
    FROM public.progress_set_theory_completion(
      'c3000000-0000-0000-0000-000000000001',
      'c3300000-0000-0000-0000-000000000001',
      false,
      'c3a00000-0000-0000-0000-000000000019'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;

  BEGIN
    PERFORM public.progress_list_own_modules(
      'c3000000-0000-0000-0000-000000000001',
      810,
      NULL,
      1
    );
  EXCEPTION WHEN raise_exception THEN
    v_invalid_cursor_rejected := true;
  END;
  BEGIN
    PERFORM public.progress_list_own_modules(
      'c3000000-0000-0000-0000-000000000001',
      NULL,
      NULL,
      0
    );
  EXCEPTION WHEN raise_exception THEN
    v_invalid_limit_rejected := true;
  END;

  IF pg_catalog.jsonb_array_length(v_owner_list -> 'items') <> 1
    OR v_owner_list -> 'items' -> 0 ->> 'moduleId'
      <> 'c3100000-0000-0000-0000-000000000001'
    OR v_owner_list -> 'items' -> 0 ->> 'completedPublishedChapters' <> '1'
    OR v_owner_list -> 'items' -> 0 ->> 'totalPublishedChapters' <> '1'
    OR (v_owner_list -> 'items' -> 0 ->> 'percent')::numeric <> 100
    OR v_owner_list -> 'items' -> 0 ->> 'completedAt' IS NULL
    OR v_owner_detail -> 'chapters' -> 0 -> 'theory' ->> 'completed' <> '1'
    OR v_owner_detail -> 'chapters' -> 0 -> 'exercises' ->> 'completed' <> '1'
    OR v_owner_detail -> 'chapters' -> 0 -> 'quizzes' ->> 'completed' <> '1'
    OR (v_owner_detail -> 'chapters' -> 0 ->> 'overallPercent')::numeric <> 100
    OR v_owner_detail::text ~ '(answer|accepted|correctoption|key|token|password|secret)'
    OR pg_catalog.jsonb_array_length(v_fresh_list -> 'items') <> 1
    OR v_fresh_list -> 'items' -> 0 ->> 'completedPublishedChapters' <> '0'
    OR (v_fresh_list -> 'items' -> 0 ->> 'percent')::numeric <> 0
    OR v_fresh_detail -> 'chapters' -> 0 -> 'theory' ->> 'completed' <> '0'
    OR (v_fresh_detail -> 'chapters' -> 0 ->> 'overallPercent')::numeric <> 0
    OR v_fresh_detail -> 'chapters' -> 0 ->> 'completedAt' IS NOT NULL
    OR v_fallback_list -> 'items' -> 0 ->> 'completedPublishedChapters' <> '1'
    OR (v_fallback_list -> 'items' -> 0 ->> 'percent')::numeric <> 100
    OR v_fallback_list -> 'items' -> 0 ->> 'completedAt' IS NOT NULL
    OR (v_fallback_detail -> 'chapters' -> 0 ->> 'overallPercent')::numeric <> 100
    OR v_fallback_detail -> 'chapters' -> 0 ->> 'completedAt' IS NOT NULL
    OR NOT v_rejected
    OR NOT v_invalid_cursor_rejected
    OR NOT v_invalid_limit_rejected THEN
    RAISE EXCEPTION 'progress read facades did not preserve current-curriculum aggregates and completion guards';
  END IF;
END;
$progress_reads_and_completed_removal_guard$;
RESET ROLE;
SELECT extensions.ok(
  EXISTS (
    SELECT 1
    FROM public.theory_section_completions AS completion_entry
    WHERE completion_entry.user_id = 'c3000000-0000-0000-0000-000000000001'
      AND completion_entry.theory_section_id = 'c3300000-0000-0000-0000-000000000001'
  )
  AND (
    SELECT pg_catalog.count(*) = 3
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action IN (
      'theory_completion_set',
      'theory_completion_removed'
    )
      AND audit_entry.entity_id = 'c3300000-0000-0000-0000-000000000001'
  ),
  'progress reads retain fresh-learner defaults and completed chapters retain their theory-completion history'
);

-- Dedicated immutable history fixtures use a separate assessment tree so the
-- historical ordering, archive behavior, and selected-feedback projections do
-- not depend on mutation-test state above.
SET LOCAL ROLE coditza_owner;

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
VALUES (
  'c3410000-0000-0000-0000-000000000001',
  'c3200000-0000-0000-0000-000000000001',
  'History exercise',
  'Answer with yes or no for the history fixture.',
  'short_text',
  1,
  7,
  true
);
SELECT pg_catalog.set_config(
  'coditza.assessment_tree_root',
  'exercise:c3410000-0000-0000-0000-000000000001',
  true
);
INSERT INTO private.exercise_answer_keys (
  exercise_id,
  answer_spec,
  feedback_correct_markdown,
  feedback_incorrect_markdown
)
VALUES (
  'c3410000-0000-0000-0000-000000000001',
  '{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}'::jsonb,
  'CORECT_EXCLUSIV',
  'INCORECT_EXCLUSIV'
);
SELECT pg_catalog.set_config('coditza.assessment_tree_root', '', true);

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
VALUES (
  'c3510000-0000-0000-0000-000000000001',
  'c3200000-0000-0000-0000-000000000001',
  'history-quiz',
  'History quiz',
  'Answer both retained questions.',
  1,
  50,
  NULL,
  NULL,
  true
);
SELECT pg_catalog.set_config(
  'coditza.assessment_tree_root',
  'quiz:c3510000-0000-0000-0000-000000000001',
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
VALUES
  (
    'c3610000-0000-0000-0000-000000000001',
    'c3510000-0000-0000-0000-000000000001',
    'Choose the retained first answer.',
    'single_choice',
    0,
    5
  ),
  (
    'c3610000-0000-0000-0000-000000000002',
    'c3510000-0000-0000-0000-000000000001',
    'Type yes for the retained second answer.',
    'short_text',
    1,
    3
  );
INSERT INTO public.quiz_question_options (
  id,
  question_id,
  label_markdown,
  position
)
VALUES
  (
    'c3620000-0000-0000-0000-000000000001',
    'c3610000-0000-0000-0000-000000000001',
    'Retained correct option',
    0
  ),
  (
    'c3620000-0000-0000-0000-000000000002',
    'c3610000-0000-0000-0000-000000000001',
    'Retained incorrect option',
    1
  );
INSERT INTO private.quiz_question_answer_keys (
  question_id,
  answer_spec,
  feedback_correct_markdown,
  feedback_incorrect_markdown
)
VALUES
  (
    'c3610000-0000-0000-0000-000000000001',
    '{"correctOptionId":"c3620000-0000-0000-0000-000000000001"}'::jsonb,
    'HISTORY_Q1_CORECT',
    'HISTORY_Q1_INCORECT'
  ),
  (
    'c3610000-0000-0000-0000-000000000002',
    '{"acceptedAnswers":["yes"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}'::jsonb,
    'HISTORY_Q2_CORECT',
    'HISTORY_Q2_INCORECT'
  );
SELECT pg_catalog.set_config('coditza.assessment_tree_root', '', true);

UPDATE public.exercises
SET status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3410000-0000-0000-0000-000000000001';
UPDATE public.quizzes
SET status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3510000-0000-0000-0000-000000000001';

SELECT pg_catalog.set_config('coditza.learning_write', 'exercise', true);
INSERT INTO public.exercise_attempts (
  id,
  user_id,
  exercise_id,
  exercise_definition_version,
  answer,
  is_correct,
  points_earned,
  points_possible,
  submitted_at
)
VALUES
  (
    'c3d10000-0000-0000-0000-000000000001',
    'c3000000-0000-0000-0000-000000000001',
    'c3410000-0000-0000-0000-000000000001',
    1,
    '{"text":"yes"}'::jsonb,
    true,
    7,
    7,
    timestamptz '2026-07-29 10:00:00+00'
  ),
  (
    'c3d10000-0000-0000-0000-000000000002',
    'c3000000-0000-0000-0000-000000000001',
    'c3410000-0000-0000-0000-000000000001',
    1,
    '{"text":"no"}'::jsonb,
    false,
    0,
    7,
    timestamptz '2026-07-29 10:00:00+00'
  ),
  (
    'c3d10000-0000-0000-0000-000000000003',
    'c3000000-0000-0000-0000-000000000002',
    'c3410000-0000-0000-0000-000000000001',
    1,
    '{"text":"yes"}'::jsonb,
    true,
    7,
    7,
    timestamptz '2026-07-29 10:00:00+00'
  );
SELECT pg_catalog.set_config('coditza.learning_write', '', true);

SELECT pg_catalog.set_config('coditza.learning_write', 'quiz-start', true);
INSERT INTO public.quiz_attempts (
  id,
  user_id,
  quiz_id,
  quiz_definition_version,
  attempt_number,
  started_at
)
VALUES (
  'c3d20000-0000-0000-0000-000000000002',
  'c3000000-0000-0000-0000-000000000001',
  'c3510000-0000-0000-0000-000000000001',
  1,
  1,
  timestamptz '2026-07-29 11:00:00+00'
);
SELECT pg_catalog.set_config(
  'coditza.learning_write',
  'quiz-answer:c3d20000-0000-0000-0000-000000000002',
  true
);
INSERT INTO public.quiz_attempt_answers (attempt_id, question_id, answer)
VALUES (
  'c3d20000-0000-0000-0000-000000000002',
  'c3610000-0000-0000-0000-000000000001',
  '{"optionId":"c3620000-0000-0000-0000-000000000001"}'::jsonb
);
SELECT pg_catalog.set_config(
  'coditza.learning_write',
  'quiz-finalize:c3d20000-0000-0000-0000-000000000002',
  true
);
UPDATE public.quiz_attempt_answers
SET is_correct = true,
    points_earned = 5
WHERE attempt_id = 'c3d20000-0000-0000-0000-000000000002'
  AND question_id = 'c3610000-0000-0000-0000-000000000001';
UPDATE public.quiz_attempts
SET status = 'submitted'::public.quiz_attempt_status,
    submitted_at = timestamptz '2026-07-29 12:00:00+00',
    points_earned = 5,
    points_possible = 8,
    score_percent = 62.50,
    passed = true
WHERE id = 'c3d20000-0000-0000-0000-000000000002';
SELECT pg_catalog.set_config('coditza.learning_write', '', true);

SELECT pg_catalog.set_config('coditza.learning_write', 'quiz-start', true);
INSERT INTO public.quiz_attempts (
  id,
  user_id,
  quiz_id,
  quiz_definition_version,
  attempt_number,
  started_at
)
VALUES (
  'c3d20000-0000-0000-0000-000000000001',
  'c3000000-0000-0000-0000-000000000001',
  'c3510000-0000-0000-0000-000000000001',
  1,
  2,
  timestamptz '2026-07-29 12:00:00+00'
);
SELECT pg_catalog.set_config(
  'coditza.learning_write',
  'quiz-answer:c3d20000-0000-0000-0000-000000000001',
  true
);
INSERT INTO public.quiz_attempt_answers (attempt_id, question_id, answer)
VALUES (
  'c3d20000-0000-0000-0000-000000000001',
  'c3610000-0000-0000-0000-000000000001',
  '{"optionId":"c3620000-0000-0000-0000-000000000002"}'::jsonb
);
SELECT pg_catalog.set_config('coditza.learning_write', '', true);

SELECT pg_catalog.set_config('coditza.learning_write', 'quiz-start', true);
INSERT INTO public.quiz_attempts (
  id,
  user_id,
  quiz_id,
  quiz_definition_version,
  attempt_number,
  started_at
)
VALUES (
  'c3d20000-0000-0000-0000-000000000003',
  'c3000000-0000-0000-0000-000000000002',
  'c3510000-0000-0000-0000-000000000001',
  1,
  1,
  timestamptz '2026-07-29 12:00:00+00'
);
SELECT pg_catalog.set_config('coditza.learning_write', '', true);

UPDATE public.exercises
SET status = 'archived'::public.content_status
WHERE id = 'c3410000-0000-0000-0000-000000000001';
UPDATE public.quizzes
SET status = 'archived'::public.content_status
WHERE id = 'c3510000-0000-0000-0000-000000000001';
RESET ROLE;

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 4
      AND pg_catalog.bool_and(
        procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
        AND procedure_entry.prosecdef
        AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
      )
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid IN (
      'public.assessment_list_own_exercise_attempts(uuid,uuid,timestamp with time zone,uuid,integer)'::pg_catalog.regprocedure,
      'public.assessment_get_own_exercise_attempt(uuid,uuid)'::pg_catalog.regprocedure,
      'public.assessment_list_own_quiz_attempts(uuid,uuid,text,timestamp with time zone,uuid,integer)'::pg_catalog.regprocedure,
      'public.assessment_get_own_quiz_attempt(uuid,uuid)'::pg_catalog.regprocedure
    )
  )
  AND NOT EXISTS (
    SELECT 1
    FROM (
      VALUES (
        'public.assessment_list_own_exercise_attempts(uuid,uuid,timestamp with time zone,uuid,integer)'::pg_catalog.regprocedure
      ), (
        'public.assessment_get_own_exercise_attempt(uuid,uuid)'::pg_catalog.regprocedure
      ), (
        'public.assessment_list_own_quiz_attempts(uuid,uuid,text,timestamp with time zone,uuid,integer)'::pg_catalog.regprocedure
      ), (
        'public.assessment_get_own_quiz_attempt(uuid,uuid)'::pg_catalog.regprocedure
      )
    ) AS facade(procedure_oid)
    CROSS JOIN (
      VALUES ('anon'), ('authenticated'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_function_privilege(
      runtime_role.rolname,
      facade.procedure_oid,
      'EXECUTE'
    )
  )
  AND (
    SELECT pg_catalog.count(*) = 4
    FROM (
      VALUES (
        'public.assessment_list_own_exercise_attempts(uuid,uuid,timestamp with time zone,uuid,integer)'::pg_catalog.regprocedure
      ), (
        'public.assessment_get_own_exercise_attempt(uuid,uuid)'::pg_catalog.regprocedure
      ), (
        'public.assessment_list_own_quiz_attempts(uuid,uuid,text,timestamp with time zone,uuid,integer)'::pg_catalog.regprocedure
      ), (
        'public.assessment_get_own_quiz_attempt(uuid,uuid)'::pg_catalog.regprocedure
      )
    ) AS facade(procedure_oid)
    WHERE pg_catalog.has_function_privilege(
      'service_role',
      facade.procedure_oid,
      'EXECUTE'
    )
  ),
  'assessment history facades are owner-controlled SECURITY DEFINER entrypoints granted only to service_role'
);

SET LOCAL ROLE service_role;
DO $exercise_history_projection$
DECLARE
  v_page_one jsonb;
  v_page_two jsonb;
  v_correct jsonb;
  v_incorrect jsonb;
  v_foreign_rejected boolean := false;
  v_cursor_rejected boolean := false;
  v_limit_rejected boolean := false;
BEGIN
  v_page_one := public.assessment_list_own_exercise_attempts(
    'c3000000-0000-0000-0000-000000000001',
    'c3410000-0000-0000-0000-000000000001',
    NULL,
    NULL,
    1
  );
  v_page_two := public.assessment_list_own_exercise_attempts(
    'c3000000-0000-0000-0000-000000000001',
    'c3410000-0000-0000-0000-000000000001',
    (v_page_one -> 'nextCursor' ->> 'submittedAt')::timestamptz,
    (v_page_one -> 'nextCursor' ->> 'attemptId')::uuid,
    1
  );
  v_correct := public.assessment_get_own_exercise_attempt(
    'c3000000-0000-0000-0000-000000000001',
    'c3d10000-0000-0000-0000-000000000001'
  );
  v_incorrect := public.assessment_get_own_exercise_attempt(
    'c3000000-0000-0000-0000-000000000001',
    'c3d10000-0000-0000-0000-000000000002'
  );

  BEGIN
    PERFORM public.assessment_get_own_exercise_attempt(
      'c3000000-0000-0000-0000-000000000001',
      'c3d10000-0000-0000-0000-000000000003'
    );
  EXCEPTION WHEN raise_exception THEN
    v_foreign_rejected := true;
  END;
  BEGIN
    PERFORM public.assessment_list_own_exercise_attempts(
      'c3000000-0000-0000-0000-000000000001',
      'c3410000-0000-0000-0000-000000000001',
      timestamptz '2026-07-29 10:00:00+00',
      NULL,
      1
    );
  EXCEPTION WHEN raise_exception THEN
    v_cursor_rejected := true;
  END;
  BEGIN
    PERFORM public.assessment_list_own_exercise_attempts(
      'c3000000-0000-0000-0000-000000000001',
      'c3410000-0000-0000-0000-000000000001',
      NULL,
      NULL,
      0
    );
  EXCEPTION WHEN raise_exception THEN
    v_limit_rejected := true;
  END;

  IF pg_catalog.jsonb_array_length(v_page_one -> 'items') <> 1
    OR v_page_one -> 'items' -> 0 ->> 'id'
      <> 'c3d10000-0000-0000-0000-000000000002'
    OR v_page_one -> 'nextCursor' ->> 'attemptId'
      <> 'c3d10000-0000-0000-0000-000000000002'
    OR pg_catalog.jsonb_array_length(v_page_two -> 'items') <> 1
    OR v_page_two -> 'items' -> 0 ->> 'id'
      <> 'c3d10000-0000-0000-0000-000000000001'
    OR v_page_two -> 'nextCursor' IS DISTINCT FROM 'null'::jsonb
    OR v_correct ->> 'feedbackMarkdown' <> 'CORECT_EXCLUSIV'
    OR v_incorrect ->> 'feedbackMarkdown' <> 'INCORECT_EXCLUSIV'
    OR v_correct -> 'answer' IS DISTINCT FROM '{"text":"yes"}'::jsonb
    OR v_incorrect -> 'answer' IS DISTINCT FROM '{"text":"no"}'::jsonb
    OR v_correct::text ~ '(INCORECT_EXCLUSIV|answerSpec|acceptedAnswers|correctOption|userId)'
    OR v_incorrect::text ~ '("feedbackMarkdown": "CORECT_EXCLUSIV"|answerSpec|acceptedAnswers|correctOption|userId)'
    OR NOT v_foreign_rejected
    OR NOT v_cursor_rejected
    OR NOT v_limit_rejected THEN
    RAISE EXCEPTION 'exercise history did not retain owner-only archived keyset projections';
  END IF;
END;
$exercise_history_projection$;
RESET ROLE;
SELECT extensions.ok(
  TRUE,
  'exercise history keeps archived owner attempts paginated and selects only the applicable feedback branch'
);

SET LOCAL ROLE service_role;
DO $quiz_history_projection$
DECLARE
  v_page_one jsonb;
  v_page_two jsonb;
  v_submitted_only jsonb;
  v_active_detail jsonb;
  v_terminal_detail jsonb;
  v_foreign_rejected boolean := false;
  v_cursor_rejected boolean := false;
  v_limit_rejected boolean := false;
  v_status_rejected boolean := false;
BEGIN
  v_page_one := public.assessment_list_own_quiz_attempts(
    'c3000000-0000-0000-0000-000000000001',
    'c3510000-0000-0000-0000-000000000001',
    NULL,
    NULL,
    NULL,
    1
  );
  v_page_two := public.assessment_list_own_quiz_attempts(
    'c3000000-0000-0000-0000-000000000001',
    'c3510000-0000-0000-0000-000000000001',
    NULL,
    (v_page_one -> 'nextCursor' ->> 'occurredAt')::timestamptz,
    (v_page_one -> 'nextCursor' ->> 'attemptId')::uuid,
    1
  );
  v_submitted_only := public.assessment_list_own_quiz_attempts(
    'c3000000-0000-0000-0000-000000000001',
    'c3510000-0000-0000-0000-000000000001',
    'submitted',
    NULL,
    NULL,
    100
  );
  v_active_detail := public.assessment_get_own_quiz_attempt(
    'c3000000-0000-0000-0000-000000000001',
    'c3d20000-0000-0000-0000-000000000001'
  );
  v_terminal_detail := public.assessment_get_own_quiz_attempt(
    'c3000000-0000-0000-0000-000000000001',
    'c3d20000-0000-0000-0000-000000000002'
  );

  BEGIN
    PERFORM public.assessment_get_own_quiz_attempt(
      'c3000000-0000-0000-0000-000000000001',
      'c3d20000-0000-0000-0000-000000000003'
    );
  EXCEPTION WHEN raise_exception THEN
    v_foreign_rejected := true;
  END;
  BEGIN
    PERFORM public.assessment_list_own_quiz_attempts(
      'c3000000-0000-0000-0000-000000000001',
      'c3510000-0000-0000-0000-000000000001',
      NULL,
      timestamptz '2026-07-29 12:00:00+00',
      NULL,
      1
    );
  EXCEPTION WHEN raise_exception THEN
    v_cursor_rejected := true;
  END;
  BEGIN
    PERFORM public.assessment_list_own_quiz_attempts(
      'c3000000-0000-0000-0000-000000000001',
      'c3510000-0000-0000-0000-000000000001',
      NULL,
      NULL,
      NULL,
      101
    );
  EXCEPTION WHEN raise_exception THEN
    v_limit_rejected := true;
  END;
  BEGIN
    PERFORM public.assessment_list_own_quiz_attempts(
      'c3000000-0000-0000-0000-000000000001',
      'c3510000-0000-0000-0000-000000000001',
      'not-a-status',
      NULL,
      NULL,
      1
    );
  EXCEPTION WHEN raise_exception THEN
    v_status_rejected := true;
  END;

  IF pg_catalog.jsonb_array_length(v_page_one -> 'items') <> 1
    OR v_page_one -> 'items' -> 0 ->> 'id'
      <> 'c3d20000-0000-0000-0000-000000000002'
    OR v_page_one -> 'items' -> 0 ->> 'status' <> 'submitted'
    OR v_page_one -> 'nextCursor' ->> 'attemptId'
      <> 'c3d20000-0000-0000-0000-000000000002'
    OR pg_catalog.jsonb_array_length(v_page_two -> 'items') <> 1
    OR v_page_two -> 'items' -> 0 ->> 'id'
      <> 'c3d20000-0000-0000-0000-000000000001'
    OR v_page_two -> 'items' -> 0 ->> 'status' <> 'in_progress'
    OR v_page_two -> 'items' -> 0 -> 'pointsEarned' IS DISTINCT FROM 'null'::jsonb
    OR v_page_two -> 'nextCursor' IS DISTINCT FROM 'null'::jsonb
    OR pg_catalog.jsonb_array_length(v_submitted_only -> 'items') <> 1
    OR v_submitted_only -> 'items' -> 0 ->> 'id'
      <> 'c3d20000-0000-0000-0000-000000000002'
    OR v_page_one::text ~ '(questions|options|answers|savedAnswers|answerSpec|acceptedAnswers|correctOption|feedbackMarkdown)'
    OR v_active_detail ->> 'status' <> 'in_progress'
    OR pg_catalog.jsonb_array_length(v_active_detail -> 'questions') <> 2
    OR pg_catalog.jsonb_array_length(
      v_active_detail -> 'questions' -> 0 -> 'options'
    ) <> 2
    OR v_active_detail -> 'savedAnswers' -> 0 -> 'answer'
      IS DISTINCT FROM '{"optionId":"c3620000-0000-0000-0000-000000000002"}'::jsonb
    OR v_active_detail -> 'answers' IS DISTINCT FROM '[]'::jsonb
    OR v_active_detail ? 'pointsEarned'
    OR v_active_detail::text ~ '(isCorrect|feedbackMarkdown|answerSpec|acceptedAnswers|correctOption)'
    OR v_terminal_detail ->> 'status' <> 'submitted'
    OR pg_catalog.jsonb_array_length(v_terminal_detail -> 'answers') <> 2
    OR v_terminal_detail -> 'answers' -> 0 ->> 'questionId'
      <> 'c3610000-0000-0000-0000-000000000001'
    OR v_terminal_detail -> 'answers' -> 0 ->> 'isCorrect' <> 'true'
    OR v_terminal_detail -> 'answers' -> 0 ->> 'pointsEarned' <> '5'
    OR v_terminal_detail -> 'answers' -> 0 ->> 'feedbackMarkdown'
      <> 'HISTORY_Q1_CORECT'
    OR v_terminal_detail -> 'answers' -> 1 ->> 'questionId'
      <> 'c3610000-0000-0000-0000-000000000002'
    OR v_terminal_detail -> 'answers' -> 1 -> 'submittedAnswer'
      IS DISTINCT FROM 'null'::jsonb
    OR v_terminal_detail -> 'answers' -> 1 ->> 'isCorrect' <> 'false'
    OR v_terminal_detail -> 'answers' -> 1 ->> 'pointsEarned' <> '0'
    OR v_terminal_detail -> 'answers' -> 1 ->> 'feedbackMarkdown'
      <> 'HISTORY_Q2_INCORECT'
    OR v_terminal_detail::text ~ '("feedbackMarkdown": "HISTORY_Q1_INCORECT"|"feedbackMarkdown": "HISTORY_Q2_CORECT"|answerSpec|acceptedAnswers|correctOption)'
    OR NOT v_foreign_rejected
    OR NOT v_cursor_rejected
    OR NOT v_limit_rejected
    OR NOT v_status_rejected THEN
    RAISE EXCEPTION 'quiz history did not preserve archived owner-safe list and detail projections';
  END IF;
END;
$quiz_history_projection$;
RESET ROLE;
SELECT extensions.ok(
  TRUE,
  'quiz history retains archived definitions, keeps active attempts start-safe, and projects terminal omissions safely'
);

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = pg_catalog.clock_timestamp()
WHERE id = 'c3000000-0000-0000-0000-000000000001';
RESET ROLE;
SET LOCAL ROLE service_role;
DO $history_held_actor_denial$
DECLARE
  v_list_rejected boolean := false;
  v_detail_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM public.assessment_list_own_exercise_attempts(
      'c3000000-0000-0000-0000-000000000001',
      'c3410000-0000-0000-0000-000000000001',
      NULL,
      NULL,
      1
    );
  EXCEPTION WHEN raise_exception THEN
    v_list_rejected := true;
  END;
  BEGIN
    PERFORM public.assessment_get_own_quiz_attempt(
      'c3000000-0000-0000-0000-000000000001',
      'c3d20000-0000-0000-0000-000000000002'
    );
  EXCEPTION WHEN raise_exception THEN
    v_detail_rejected := true;
  END;
  IF NOT v_list_rejected OR NOT v_detail_rejected THEN
    RAISE EXCEPTION 'held actor unexpectedly read assessment history';
  END IF;
END;
$history_held_actor_denial$;
RESET ROLE;
SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = NULL
WHERE id = 'c3000000-0000-0000-0000-000000000001';
RESET ROLE;
SELECT extensions.ok(
  TRUE,
  'assessment history reloads the actor and denies both list and detail while held'
);

SET LOCAL ROLE coditza_owner;
SELECT pg_catalog.set_config('coditza.learning_write', 'exercise', true);
INSERT INTO public.exercise_attempts (
  id,
  user_id,
  exercise_id,
  exercise_definition_version,
  answer,
  is_correct,
  points_earned,
  points_possible,
  submitted_at
)
VALUES (
  'c3d10000-0000-0000-0000-000000000004',
  'c3000000-0000-0000-0000-000000000001',
  'c3410000-0000-0000-0000-000000000001',
  2,
  '{"text":"corrupt"}'::jsonb,
  false,
  0,
  7,
  timestamptz '2026-07-29 09:00:00+00'
);
SELECT pg_catalog.set_config('coditza.learning_write', 'quiz-start', true);
INSERT INTO public.quiz_attempts (
  id,
  user_id,
  quiz_id,
  quiz_definition_version,
  attempt_number,
  status,
  started_at,
  submitted_at,
  points_earned,
  points_possible,
  score_percent,
  passed
)
VALUES (
  'c3d20000-0000-0000-0000-000000000004',
  'c3000000-0000-0000-0000-000000000001',
  'c3510000-0000-0000-0000-000000000001',
  2,
  3,
  'submitted'::public.quiz_attempt_status,
  timestamptz '2026-07-29 09:00:00+00',
  timestamptz '2026-07-29 09:01:00+00',
  0,
  8,
  0,
  false
);
SELECT pg_catalog.set_config('coditza.learning_write', '', true);
RESET ROLE;

SET LOCAL ROLE service_role;
DO $history_definition_version_consistency$
DECLARE
  v_exercise_list_rejected boolean := false;
  v_exercise_detail_rejected boolean := false;
  v_quiz_list_rejected boolean := false;
  v_quiz_detail_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM public.assessment_list_own_exercise_attempts(
      'c3000000-0000-0000-0000-000000000001',
      'c3410000-0000-0000-0000-000000000001',
      NULL,
      NULL,
      100
    );
  EXCEPTION WHEN raise_exception THEN
    v_exercise_list_rejected := true;
  END;
  BEGIN
    PERFORM public.assessment_get_own_exercise_attempt(
      'c3000000-0000-0000-0000-000000000001',
      'c3d10000-0000-0000-0000-000000000004'
    );
  EXCEPTION WHEN raise_exception THEN
    v_exercise_detail_rejected := true;
  END;
  BEGIN
    PERFORM public.assessment_list_own_quiz_attempts(
      'c3000000-0000-0000-0000-000000000001',
      'c3510000-0000-0000-0000-000000000001',
      NULL,
      NULL,
      NULL,
      100
    );
  EXCEPTION WHEN raise_exception THEN
    v_quiz_list_rejected := true;
  END;
  BEGIN
    PERFORM public.assessment_get_own_quiz_attempt(
      'c3000000-0000-0000-0000-000000000001',
      'c3d20000-0000-0000-0000-000000000004'
    );
  EXCEPTION WHEN raise_exception THEN
    v_quiz_detail_rejected := true;
  END;
  IF NOT v_exercise_list_rejected
    OR NOT v_exercise_detail_rejected
    OR NOT v_quiz_list_rejected
    OR NOT v_quiz_detail_rejected THEN
    RAISE EXCEPTION
      'history facade projected a definition that did not match its frozen version';
  END IF;
END;
$history_definition_version_consistency$;
RESET ROLE;
SELECT extensions.ok(
  TRUE,
  'assessment history fails closed when an attempt version differs from its retained definition'
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
  'c3110000-0000-0000-0000-000000000001',
  'functions-module-page-two',
  'Functions module page two',
  'Synthetic second page module for progress cursor verification.',
  811
);
UPDATE public.modules
SET status = 'published'::public.content_status,
    published_at = pg_catalog.clock_timestamp()
WHERE id = 'c3110000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $progress_cursor_second_page$
DECLARE
  v_page_one jsonb;
  v_page_two jsonb;
BEGIN
  v_page_one := public.progress_list_own_modules(
    'c3000000-0000-0000-0000-000000000001',
    NULL,
    NULL,
    1
  );
  v_page_two := public.progress_list_own_modules(
    'c3000000-0000-0000-0000-000000000001',
    (v_page_one -> 'nextCursor' ->> 'position')::integer,
    (v_page_one -> 'nextCursor' ->> 'moduleId')::uuid,
    1
  );
  IF v_page_one -> 'items' -> 0 ->> 'moduleId'
      <> 'c3100000-0000-0000-0000-000000000001'
    OR v_page_one -> 'nextCursor' ->> 'moduleId'
      <> 'c3100000-0000-0000-0000-000000000001'
    OR v_page_two -> 'items' -> 0 ->> 'moduleId'
      <> 'c3110000-0000-0000-0000-000000000001'
    OR v_page_two -> 'nextCursor' IS DISTINCT FROM 'null'::jsonb THEN
    RAISE EXCEPTION 'progress list did not return a stable second page cursor';
  END IF;
END;
$progress_cursor_second_page$;
RESET ROLE;
SELECT extensions.ok(
  TRUE,
  'progress module pagination produces a usable next cursor and a stable second page'
);

-- Keep the draft-exercise PATCH fixture independent from the creation slices:
-- those hierarchies are deliberately archived later in their own replay proof.
SET LOCAL ROLE coditza_owner;
INSERT INTO public.modules (
  id,
  slug,
  title,
  description_markdown,
  position,
  created_by,
  updated_by
)
VALUES (
  'c3190000-0000-0000-0000-000000000001',
  'draft-exercise-patch-module',
  'Draft exercise PATCH module',
  'Isolated hierarchy for scalar draft-exercise PATCH verification.',
  901,
  'c3000000-0000-0000-0000-000000000004',
  'c3000000-0000-0000-0000-000000000004'
);
INSERT INTO public.chapters (
  id,
  module_id,
  slug,
  title,
  summary_markdown,
  position,
  estimated_minutes,
  created_by,
  updated_by
)
VALUES (
  'c3290000-0000-0000-0000-000000000001',
  'c3190000-0000-0000-0000-000000000001',
  'draft-exercise-patch-chapter',
  'Draft exercise PATCH chapter',
  'Isolated hierarchy for scalar draft-exercise PATCH verification.',
  0,
  10,
  'c3000000-0000-0000-0000-000000000004',
  'c3000000-0000-0000-0000-000000000004'
);
INSERT INTO public.exercises (
  id,
  chapter_id,
  title,
  prompt_markdown,
  exercise_type,
  position,
  points,
  is_required,
  created_by,
  updated_by
)
VALUES (
  'c3430000-0000-0000-0000-000000000001',
  'c3290000-0000-0000-0000-000000000001',
  'Original scalar draft exercise',
  'Choose the original correct option.',
  'single_choice',
  0,
  5,
  true,
  'c3000000-0000-0000-0000-000000000004',
  'c3000000-0000-0000-0000-000000000004'
);
SELECT pg_catalog.set_config(
  'coditza.assessment_tree_root',
  'exercise:c3430000-0000-0000-0000-000000000001',
  true
);
INSERT INTO public.exercise_options (
  id,
  exercise_id,
  label_markdown,
  position
)
VALUES
  (
    'c3440000-0000-0000-0000-000000000001',
    'c3430000-0000-0000-0000-000000000001',
    'Original incorrect option.',
    0
  ),
  (
    'c3440000-0000-0000-0000-000000000002',
    'c3430000-0000-0000-0000-000000000001',
    'Original correct option.',
    1
  );
INSERT INTO private.exercise_answer_keys (
  exercise_id,
  answer_spec,
  feedback_correct_markdown,
  feedback_incorrect_markdown,
  created_by,
  updated_by
)
VALUES (
  'c3430000-0000-0000-0000-000000000001',
  '{"correctOptionId":"c3440000-0000-0000-0000-000000000002"}'::jsonb,
  'Original correct feedback.',
  'Original incorrect feedback.',
  'c3000000-0000-0000-0000-000000000004',
  'c3000000-0000-0000-0000-000000000004'
);
SELECT pg_catalog.set_config('coditza.assessment_tree_root', '', true);
RESET ROLE;

SET LOCAL ROLE service_role;
DO $assessment_update_draft_exercise$
DECLARE
  v_tree_update record;
  v_root_update record;
  v_noop record;
  v_empty_rejected boolean := false;
  v_unknown_field_rejected boolean := false;
  v_partial_tree_rejected boolean := false;
  v_feedback_only_rejected boolean := false;
  v_python_rejected boolean := false;
  v_stale_rejected boolean := false;
  v_learner_rejected boolean := false;
  v_missing_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM *
    FROM public.assessment_update_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3430000-0000-0000-0000-000000000001',
      1,
      '{}'::jsonb,
      'c3f50000-0000-0000-0000-000000000001'
    );
  EXCEPTION WHEN raise_exception THEN
    v_empty_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_update_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3430000-0000-0000-0000-000000000001',
      1,
      '{"position":9}'::jsonb,
      'c3f50000-0000-0000-0000-000000000002'
    );
  EXCEPTION WHEN raise_exception THEN
    v_unknown_field_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_update_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3430000-0000-0000-0000-000000000001',
      1,
      '{"options":[]}'::jsonb,
      'c3f50000-0000-0000-0000-000000000003'
    );
  EXCEPTION WHEN raise_exception THEN
    v_partial_tree_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_update_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3430000-0000-0000-0000-000000000001',
      1,
      '{"feedbackCorrectMarkdown":"Feedback without a tree."}'::jsonb,
      'c3f50000-0000-0000-0000-000000000004'
    );
  EXCEPTION WHEN raise_exception THEN
    v_feedback_only_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_update_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3430000-0000-0000-0000-000000000001',
      1,
      '{"exerciseType":"python_code","options":[],"answerSpec":null}'::jsonb,
      'c3f50000-0000-0000-0000-000000000005'
    );
  EXCEPTION WHEN raise_exception THEN
    v_python_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_update_draft_exercise(
      'c3000000-0000-0000-0000-000000000001',
      'c3430000-0000-0000-0000-000000000001',
      1,
      '{"title":"Learners cannot patch draft exercises"}'::jsonb,
      'c3f50000-0000-0000-0000-000000000006'
    );
  EXCEPTION WHEN raise_exception THEN
    v_learner_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_update_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3430000-0000-0000-0000-000000000999',
      1,
      '{"title":"Missing draft exercise"}'::jsonb,
      'c3f50000-0000-0000-0000-000000000007'
    );
  EXCEPTION WHEN raise_exception THEN
    v_missing_rejected := true;
  END;

  SELECT * INTO v_tree_update
  FROM public.assessment_update_draft_exercise(
    'c3000000-0000-0000-0000-000000000005',
    'c3430000-0000-0000-0000-000000000001',
    1,
    '{"title":"Updated short draft exercise","promptMarkdown":"Type the normalized answer.","exerciseType":"short_text","points":7,"isRequired":false,"options":[],"answerSpec":{"acceptedAnswers":["  Da\t","NU"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"},"feedbackCorrectMarkdown":"Corect actualizat.","feedbackIncorrectMarkdown":"Încearcă din nou actualizat."}'::jsonb,
    'c3f50000-0000-0000-0000-000000000010'
  );

  SELECT * INTO v_root_update
  FROM public.assessment_update_draft_exercise(
    'c3000000-0000-0000-0000-000000000005',
    'c3430000-0000-0000-0000-000000000001',
    2,
    '{"title":"Updated short draft exercise root only"}'::jsonb,
    'c3f50000-0000-0000-0000-000000000011'
  );

  SELECT * INTO v_noop
  FROM public.assessment_update_draft_exercise(
    'c3000000-0000-0000-0000-000000000005',
    'c3430000-0000-0000-0000-000000000001',
    3,
    '{"title":"Updated short draft exercise root only"}'::jsonb,
    'c3f50000-0000-0000-0000-000000000012'
  );

  BEGIN
    PERFORM *
    FROM public.assessment_update_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3430000-0000-0000-0000-000000000001',
      1,
      '{"title":"Stale update must not apply"}'::jsonb,
      'c3f50000-0000-0000-0000-000000000013'
    );
  EXCEPTION WHEN raise_exception THEN
    v_stale_rejected := true;
  END;

  IF v_tree_update.response_status <> 200
    OR v_tree_update.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id', 'c3430000-0000-0000-0000-000000000001',
      'rowVersion', 2,
      'definitionVersion', 2
    )
    OR v_tree_update.response_body OPERATOR(pg_catalog.?) 'optionIdMappings'
    OR v_tree_update.response_body OPERATOR(pg_catalog.?) 'answerSpec'
    OR v_tree_update.response_body OPERATOR(pg_catalog.?) 'feedbackCorrectMarkdown'
    OR v_tree_update.response_body OPERATOR(pg_catalog.?) 'promptMarkdown'
    OR v_root_update.response_status <> 200
    OR v_root_update.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id', 'c3430000-0000-0000-0000-000000000001',
      'rowVersion', 3,
      'definitionVersion', 3
    )
    OR v_noop.response_status <> 200
    OR v_noop.response_body IS DISTINCT FROM pg_catalog.jsonb_build_object(
      'id', 'c3430000-0000-0000-0000-000000000001',
      'rowVersion', 3,
      'definitionVersion', 3
    )
    OR NOT v_empty_rejected
    OR NOT v_unknown_field_rejected
    OR NOT v_partial_tree_rejected
    OR NOT v_feedback_only_rejected
    OR NOT v_python_rejected
    OR NOT v_learner_rejected
    OR NOT v_missing_rejected
    OR NOT v_stale_rejected THEN
    RAISE EXCEPTION 'draft-exercise PATCH facade did not preserve its exact scalar update contract';
  END IF;
END;
$assessment_update_draft_exercise$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = pg_catalog.clock_timestamp()
WHERE id = 'c3000000-0000-0000-0000-000000000005';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $held_staff_draft_exercise_update$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM *
    FROM public.assessment_update_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3430000-0000-0000-0000-000000000001',
      3,
      '{"title":"Held staff must not patch"}'::jsonb,
      'c3f50000-0000-0000-0000-000000000014'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'held staff actor unexpectedly patched a draft exercise';
  END IF;
END;
$held_staff_draft_exercise_update$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.profiles
SET security_hold_at = NULL
WHERE id = 'c3000000-0000-0000-0000-000000000005';
SELECT pg_catalog.set_config('coditza.learning_write', 'exercise', true);
INSERT INTO public.exercise_attempts (
  id,
  user_id,
  exercise_id,
  exercise_definition_version,
  answer,
  is_correct,
  points_earned,
  points_possible
)
VALUES (
  'c3450000-0000-0000-0000-000000000001',
  'c3000000-0000-0000-0000-000000000001',
  'c3430000-0000-0000-0000-000000000001',
  3,
  '{"text":"da"}'::jsonb,
  true,
  7,
  7
);
SELECT pg_catalog.set_config('coditza.learning_write', '', true);
RESET ROLE;

SET LOCAL ROLE service_role;
DO $draft_exercise_history_update_denial$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM *
    FROM public.assessment_update_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3430000-0000-0000-0000-000000000001',
      3,
      '{"options":[],"answerSpec":{"acceptedAnswers":["nu"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}}'::jsonb,
      'c3f50000-0000-0000-0000-000000000015'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'draft exercise history unexpectedly allowed a tree replacement';
  END IF;
END;
$draft_exercise_history_update_denial$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
UPDATE public.modules
SET status = 'archived'::public.content_status
WHERE id = 'c3190000-0000-0000-0000-000000000001';
RESET ROLE;

SET LOCAL ROLE service_role;
DO $archived_parent_draft_exercise_update_denial$
DECLARE
  v_parent_rejected boolean := false;
  v_published_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM *
    FROM public.assessment_update_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3430000-0000-0000-0000-000000000001',
      3,
      '{"title":"Archived parent must reject updates"}'::jsonb,
      'c3f50000-0000-0000-0000-000000000016'
    );
  EXCEPTION WHEN raise_exception THEN
    v_parent_rejected := true;
  END;

  BEGIN
    PERFORM *
    FROM public.assessment_update_draft_exercise(
      'c3000000-0000-0000-0000-000000000005',
      'c3400000-0000-0000-0000-000000000001',
      2,
      '{"title":"Published exercises are immutable"}'::jsonb,
      'c3f50000-0000-0000-0000-000000000017'
    );
  EXCEPTION WHEN raise_exception THEN
    v_published_rejected := true;
  END;

  IF NOT v_parent_rejected OR NOT v_published_rejected THEN
    RAISE EXCEPTION 'archived parents or published exercise roots unexpectedly allowed PATCH';
  END IF;
END;
$archived_parent_draft_exercise_update_denial$;
RESET ROLE;

SET LOCAL ROLE coditza_owner;
SELECT extensions.ok(
  EXISTS (
    SELECT 1
    FROM public.exercises AS exercise
    JOIN private.exercise_answer_keys AS answer_key
      ON answer_key.exercise_id = exercise.id
    WHERE exercise.id = 'c3430000-0000-0000-0000-000000000001'
      AND exercise.chapter_id = 'c3290000-0000-0000-0000-000000000001'
      AND exercise.title = 'Updated short draft exercise root only'
      AND exercise.prompt_markdown = 'Type the normalized answer.'
      AND exercise.exercise_type = 'short_text'::public.exercise_type
      AND exercise.position = 0
      AND exercise.points = 7
      AND NOT exercise.is_required
      AND exercise.status = 'draft'::public.content_status
      AND exercise.row_version = 3
      AND exercise.definition_version = 3
      AND exercise.created_by = 'c3000000-0000-0000-0000-000000000004'
      AND exercise.updated_by = 'c3000000-0000-0000-0000-000000000005'
      AND answer_key.answer_spec =
        '{"acceptedAnswers":["da","nu"],"normalization":"nfkc_ascii_ws_ascii_lower_v1"}'::jsonb
      AND answer_key.feedback_correct_markdown = 'Corect actualizat.'
      AND answer_key.feedback_incorrect_markdown = 'Încearcă din nou actualizat.'
      AND answer_key.created_by = 'c3000000-0000-0000-0000-000000000005'
      AND answer_key.updated_by = 'c3000000-0000-0000-0000-000000000005'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM public.exercise_options AS option_entry
    WHERE option_entry.exercise_id = 'c3430000-0000-0000-0000-000000000001'
  )
  AND EXISTS (
    SELECT 1
    FROM public.exercise_attempts AS attempt
    WHERE attempt.id = 'c3450000-0000-0000-0000-000000000001'
      AND attempt.exercise_id = 'c3430000-0000-0000-0000-000000000001'
      AND attempt.exercise_definition_version = 3
  )
  AND EXISTS (
    SELECT 1
    FROM public.modules AS module_entry
    WHERE module_entry.id = 'c3190000-0000-0000-0000-000000000001'
      AND module_entry.status = 'archived'::public.content_status
  )
  AND (
    SELECT pg_catalog.count(*) = 2
      AND pg_catalog.bool_and(
        audit_entry.actor_kind = 'user'
        AND audit_entry.actor_user_id = 'c3000000-0000-0000-0000-000000000005'
        AND audit_entry.changed_fields = ARRAY['definition']::text[]
        AND audit_entry.change_summary =
          '{"definition":{"before":"draft","after":"updated"}}'::jsonb
        AND audit_entry.reason IS NULL
        AND audit_entry.request_id IN (
          'c3f50000-0000-0000-0000-000000000010',
          'c3f50000-0000-0000-0000-000000000011'
        )
      )
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.action = 'exercise_updated'
      AND audit_entry.entity_type = 'exercise'
      AND audit_entry.entity_id = 'c3430000-0000-0000-0000-000000000001'
  )
  AND NOT EXISTS (
    SELECT 1
    FROM private.idempotency_records AS record_entry
    WHERE record_entry.result_resource_id = 'c3430000-0000-0000-0000-000000000001'
  )
  AND COALESCE(
    pg_catalog.current_setting('coditza.assessment_tree_root', true),
    ''
  ) = '',
  'draft-exercise PATCH keeps partial/root and complete-tree changes atomic, scalar-only, versioned once, audited safely, and outside idempotency'
);
RESET ROLE;

SET LOCAL ROLE coditza_owner;
DO $unsafe_idempotency_response$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM private.assert_safe_idempotency_response(
      'exercise_submit',
      'c3400000-0000-0000-0000-000000000001',
      '{
        "id":"c3400000-0000-0000-0000-000000000001",
        "exerciseId":"c3400000-0000-0000-0000-000000000001",
        "exerciseDefinitionVersion":1,
        "submittedAt":"2026-07-29T00:00:00+00",
        "isCorrect":true,
        "pointsEarned":5,
        "pointsPossible":5,
        "feedbackMarkdown":"safe",
        "acceptedAnswers":["no"]
      }'::jsonb
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'unsafe idempotency replay body unexpectedly passed validation';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.assert_safe_idempotency_response(
      'quiz_start',
      'c3900000-0000-0000-0000-000000000002',
      '{
        "id":"c3900000-0000-0000-0000-000000000002",
        "quizId":"c3500000-0000-0000-0000-000000000001",
        "quizDefinitionVersion":1,
        "attemptNumber":1,
        "status":null,
        "startedAt":"2026-07-29T00:00:00+00",
        "expiresAt":null,
        "questions":[{
          "id":"c3600000-0000-0000-0000-000000000001",
          "promptMarkdown":"Prompt",
          "questionType":"short_text",
          "position":0,
          "points":1,
          "options":[]
        }],
        "savedAnswers":[]
      }'::jsonb
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'null quiz-start status unexpectedly passed validation';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.assert_safe_idempotency_response(
      'quiz_start',
      'c3900000-0000-0000-0000-000000000003',
      '{
        "id":"c3900000-0000-0000-0000-000000000003",
        "quizId":"c3500000-0000-0000-0000-000000000001",
        "quizDefinitionVersion":1,
        "attemptNumber":1,
        "status":"in_progress",
        "startedAt":"2026-07-29T00:00:00+00",
        "expiresAt":null,
        "questions":[{
          "id":"c3600000-0000-0000-0000-000000000001",
          "promptMarkdown":"Prompt",
          "questionType":null,
          "position":0,
          "points":1,
          "options":[]
        }],
        "savedAnswers":[]
      }'::jsonb
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'null quiz-start question type unexpectedly passed validation';
  END IF;
END;
$unsafe_idempotency_response$;
RESET ROLE;
SELECT extensions.ok(
  TRUE,
  'operation-specific idempotency validators reject hidden answer material and null enum values'
);

SELECT * FROM extensions.finish();

ROLLBACK;
