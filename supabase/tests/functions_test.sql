BEGIN;

-- SUP-FUNCTIONS-001 learner-facade proof. Fixtures are transaction-local,
-- and the only runtime role used for successful calls is service_role.
GRANT USAGE ON SCHEMA extensions TO coditza_owner;

SELECT extensions.plan(9);

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
  );

SET LOCAL ROLE coditza_owner;

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
