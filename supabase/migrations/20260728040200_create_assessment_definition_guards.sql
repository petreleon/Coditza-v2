-- SUP-DATA-002: owner-only assessment validators and complete draft-tree
-- primitives. These are deliberately private helpers, not public RPCs.
BEGIN;

SET LOCAL ROLE coditza_owner;

-- Tighten the shared forward lifecycle guard before attaching it to assessment
-- roots. A first publication timestamp may be introduced only by the actual
-- draft-to-published transition; archived never-published content cannot gain
-- a false publication history later.
CREATE OR REPLACE FUNCTION private.enforce_authored_row_lifecycle()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_authored_row_lifecycle$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status IS DISTINCT FROM 'draft'::public.content_status
      OR NEW.published_at IS NOT NULL
      OR NEW.row_version IS DISTINCT FROM 1 THEN
      RAISE EXCEPTION
        'New authored content must begin as draft with no publication timestamp and row version 1.';
    END IF;

    RETURN NEW;
  END IF;

  IF TG_OP <> 'UPDATE' THEN
    RAISE EXCEPTION
      'private.enforce_authored_row_lifecycle may run only for INSERT or UPDATE triggers.';
  END IF;

  IF OLD.status = 'published'::public.content_status
    AND NEW.status = 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Published authored content cannot return to draft.';
  END IF;

  IF OLD.status = 'archived'::public.content_status
    AND NEW.status <> 'archived'::public.content_status THEN
    RAISE EXCEPTION 'Archived authored content cannot be reopened.';
  END IF;

  IF OLD.published_at IS NOT NULL
    AND NEW.published_at IS DISTINCT FROM OLD.published_at THEN
    RAISE EXCEPTION 'The first publication timestamp is immutable.';
  END IF;

  IF OLD.published_at IS NULL
    AND NEW.published_at IS NOT NULL
    AND NOT (
      OLD.status = 'draft'::public.content_status
      AND NEW.status = 'published'::public.content_status
    ) THEN
    RAISE EXCEPTION
      'A first publication timestamp may be set only by draft-to-published.';
  END IF;

  IF OLD.status = 'draft'::public.content_status
    AND NEW.status = 'archived'::public.content_status
    AND NEW.published_at IS NOT NULL THEN
    RAISE EXCEPTION 'Never-published content cannot invent a publication timestamp.';
  END IF;

  NEW.row_version := OLD.row_version + 1;
  RETURN NEW;
END;
$enforce_authored_row_lifecycle$;

CREATE FUNCTION private.assert_jsonb_object_keys(
  p_value jsonb,
  p_required_keys text[],
  p_allowed_keys text[],
  p_context text
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_jsonb_object_keys$
DECLARE
  v_key text;
BEGIN
  IF pg_catalog.jsonb_typeof(p_value) <> 'object' THEN
    RAISE EXCEPTION '% must be a JSON object.', p_context;
  END IF;

  FOREACH v_key IN ARRAY p_required_keys LOOP
    IF NOT (p_value OPERATOR(pg_catalog.?) v_key) THEN
      RAISE EXCEPTION '% is missing a required field.', p_context;
    END IF;
  END LOOP;

  FOR v_key IN
    SELECT object_key.key
    FROM pg_catalog.jsonb_object_keys(p_value) AS object_key(key)
  LOOP
    IF NOT (v_key = ANY (p_allowed_keys)) THEN
      RAISE EXCEPTION '% contains an unsupported field.', p_context;
    END IF;
  END LOOP;
END;
$assert_jsonb_object_keys$;

CREATE FUNCTION private.assert_jsonb_string(p_value jsonb, p_context text)
RETURNS text
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_jsonb_string$
BEGIN
  IF pg_catalog.jsonb_typeof(p_value) <> 'string' THEN
    RAISE EXCEPTION '% must be a JSON string.', p_context;
  END IF;

  RETURN p_value #>> '{}';
END;
$assert_jsonb_string$;

CREATE FUNCTION private.assert_canonical_uuid_text(p_value text, p_context text)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_canonical_uuid_text$
DECLARE
  v_uuid uuid;
BEGIN
  IF p_value IS NULL
    OR NOT (p_value OPERATOR(pg_catalog.~)
      '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') THEN
    RAISE EXCEPTION '% must be a canonical lowercase UUID.', p_context;
  END IF;

  BEGIN
    v_uuid := p_value::uuid;
  EXCEPTION
    WHEN invalid_text_representation THEN
      RAISE EXCEPTION '% must be a canonical lowercase UUID.', p_context;
  END;

  IF v_uuid::text <> p_value THEN
    RAISE EXCEPTION '% must be a canonical lowercase UUID.', p_context;
  END IF;

  RETURN v_uuid;
END;
$assert_canonical_uuid_text$;

CREATE FUNCTION private.assert_client_ref(p_value text, p_context text)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_client_ref$
BEGIN
  IF p_value IS NULL
    OR pg_catalog.char_length(p_value) NOT BETWEEN 1 AND 64
    OR NOT (p_value OPERATOR(pg_catalog.~) '^[A-Za-z][A-Za-z0-9_-]{0,63}$') THEN
    RAISE EXCEPTION '% must be a valid client reference.', p_context;
  END IF;
END;
$assert_client_ref$;

CREATE FUNCTION private.assert_markdown_input(
  p_value text,
  p_maximum_length integer,
  p_context text
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_markdown_input$
BEGIN
  IF p_value IS NULL
    OR pg_catalog.char_length(p_value) NOT BETWEEN 1 AND p_maximum_length
    OR NOT (p_value OPERATOR(pg_catalog.~) '[^[:space:]]') THEN
    RAISE EXCEPTION '% must be bounded non-blank Markdown.', p_context;
  END IF;
END;
$assert_markdown_input$;

CREATE FUNCTION private.assert_jsonb_bounded_integer(
  p_value jsonb,
  p_minimum integer,
  p_maximum integer,
  p_context text
)
RETURNS integer
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_jsonb_bounded_integer$
DECLARE
  v_text text;
  v_integer integer;
BEGIN
  IF pg_catalog.jsonb_typeof(p_value) <> 'number' THEN
    RAISE EXCEPTION '% must be a JSON integer.', p_context;
  END IF;

  v_text := p_value #>> '{}';
  IF NOT (v_text OPERATOR(pg_catalog.~) '^(?:0|[1-9][0-9]*)$') THEN
    RAISE EXCEPTION '% must be a JSON integer.', p_context;
  END IF;

  BEGIN
    v_integer := v_text::integer;
  EXCEPTION
    WHEN numeric_value_out_of_range THEN
      RAISE EXCEPTION '% must be a JSON integer.', p_context;
  END;

  IF v_integer NOT BETWEEN p_minimum AND p_maximum THEN
    RAISE EXCEPTION '% is outside its approved range.', p_context;
  END IF;

  RETURN v_integer;
END;
$assert_jsonb_bounded_integer$;

CREATE FUNCTION private.optional_authoring_markdown(
  p_object jsonb,
  p_key text,
  p_context text
)
RETURNS text
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $optional_authoring_markdown$
DECLARE
  v_value jsonb;
  v_markdown text;
BEGIN
  IF NOT (p_object OPERATOR(pg_catalog.?) p_key) THEN
    RETURN NULL;
  END IF;

  v_value := p_object -> p_key;
  IF pg_catalog.jsonb_typeof(v_value) = 'null' THEN
    RETURN NULL;
  END IF;

  v_markdown := private.assert_jsonb_string(v_value, p_context);
  PERFORM private.assert_markdown_input(v_markdown, 20000, p_context);
  RETURN v_markdown;
END;
$optional_authoring_markdown$;

CREATE FUNCTION private.assert_definition_size(p_definition jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_definition_size$
BEGIN
  IF p_definition IS NULL
    OR pg_catalog.octet_length(p_definition::text) > 1000000 THEN
    RAISE EXCEPTION 'The canonical assessment definition exceeds the approved size.';
  END IF;
END;
$assert_definition_size$;

CREATE FUNCTION private.validate_exercise_answer_spec(
  p_exercise_id uuid,
  p_answer_spec jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $validate_exercise_answer_spec$
DECLARE
  v_exercise_type public.exercise_type;
  v_value jsonb;
  v_text text;
  v_uuid uuid;
  v_previous_uuid_text text;
  v_option_ids uuid[] := ARRAY[]::uuid[];
  v_answers text[] := ARRAY[]::text[];
  v_normalized text;
BEGIN
  SELECT exercise.exercise_type
  INTO v_exercise_type
  FROM public.exercises AS exercise
  WHERE exercise.id = p_exercise_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The exercise answer key has no owning exercise.';
  END IF;

  IF v_exercise_type = 'python_code'::public.exercise_type THEN
    RAISE EXCEPTION 'Python exercises cannot have scalar answer keys.';
  END IF;

  CASE v_exercise_type
    WHEN 'single_choice'::public.exercise_type THEN
      PERFORM private.assert_jsonb_object_keys(
        p_answer_spec,
        ARRAY['correctOptionId']::text[],
        ARRAY['correctOptionId']::text[],
        'Single-choice answer spec'
      );
      v_text := private.assert_jsonb_string(
        p_answer_spec -> 'correctOptionId',
        'Single-choice correctOptionId'
      );
      v_uuid := private.assert_canonical_uuid_text(
        v_text,
        'Single-choice correctOptionId'
      );
      PERFORM 1
      FROM public.exercise_options AS option_entry
      WHERE option_entry.exercise_id = p_exercise_id
        AND option_entry.id = v_uuid;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'The single-choice answer key references a foreign option.';
      END IF;

    WHEN 'multiple_choice'::public.exercise_type THEN
      PERFORM private.assert_jsonb_object_keys(
        p_answer_spec,
        ARRAY['correctOptionIds']::text[],
        ARRAY['correctOptionIds']::text[],
        'Multiple-choice answer spec'
      );
      v_value := p_answer_spec -> 'correctOptionIds';
      IF pg_catalog.jsonb_typeof(v_value) <> 'array' THEN
        RAISE EXCEPTION 'Multiple-choice correctOptionIds must be an array.';
      END IF;

      FOR v_value IN
        SELECT array_entry.value
        FROM pg_catalog.jsonb_array_elements(
          p_answer_spec -> 'correctOptionIds'
        ) AS array_entry(value)
      LOOP
        v_text := private.assert_jsonb_string(
          v_value,
          'Multiple-choice correctOptionIds entry'
        );
        v_uuid := private.assert_canonical_uuid_text(
          v_text,
          'Multiple-choice correctOptionIds entry'
        );
        IF v_uuid = ANY (v_option_ids)
          OR (
            v_previous_uuid_text IS NOT NULL
            AND v_text COLLATE "C" <= v_previous_uuid_text COLLATE "C"
          ) THEN
          RAISE EXCEPTION
            'Multiple-choice correctOptionIds must be unique and ascending.';
        END IF;
        PERFORM 1
        FROM public.exercise_options AS option_entry
        WHERE option_entry.exercise_id = p_exercise_id
          AND option_entry.id = v_uuid;
        IF NOT FOUND THEN
          RAISE EXCEPTION
            'The multiple-choice answer key references a foreign option.';
        END IF;
        v_option_ids := pg_catalog.array_append(v_option_ids, v_uuid);
        v_previous_uuid_text := v_text;
      END LOOP;

      IF COALESCE(pg_catalog.array_length(v_option_ids, 1), 0) = 0 THEN
        RAISE EXCEPTION 'Multiple-choice answer keys need at least one correct option.';
      END IF;

    WHEN 'short_text'::public.exercise_type THEN
      PERFORM private.assert_jsonb_object_keys(
        p_answer_spec,
        ARRAY['acceptedAnswers', 'normalization']::text[],
        ARRAY['acceptedAnswers', 'normalization']::text[],
        'Short-text answer spec'
      );
      v_text := private.assert_jsonb_string(
        p_answer_spec -> 'normalization',
        'Short-text normalization'
      );
      IF v_text <> 'nfkc_ascii_ws_ascii_lower_v1' THEN
        RAISE EXCEPTION 'Short-text answer specs must use the approved normalizer.';
      END IF;
      v_value := p_answer_spec -> 'acceptedAnswers';
      IF pg_catalog.jsonb_typeof(v_value) <> 'array' THEN
        RAISE EXCEPTION 'Short-text acceptedAnswers must be an array.';
      END IF;

      FOR v_value IN
        SELECT array_entry.value
        FROM pg_catalog.jsonb_array_elements(
          p_answer_spec -> 'acceptedAnswers'
        ) AS array_entry(value)
      LOOP
        v_text := private.assert_jsonb_string(
          v_value,
          'Short-text acceptedAnswers entry'
        );
        v_normalized := private.normalize_short_text(v_text);
        IF v_text <> v_normalized
          OR pg_catalog.char_length(v_text) NOT BETWEEN 1 AND 4000
          OR v_text = ANY (v_answers) THEN
          RAISE EXCEPTION
            'Short-text acceptedAnswers must be unique approved normalized values.';
        END IF;
        v_answers := pg_catalog.array_append(v_answers, v_text);
      END LOOP;
  END CASE;
END;
$validate_exercise_answer_spec$;

CREATE FUNCTION private.validate_quiz_question_answer_spec(
  p_question_id uuid,
  p_answer_spec jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $validate_quiz_question_answer_spec$
DECLARE
  v_question_type public.question_type;
  v_value jsonb;
  v_text text;
  v_uuid uuid;
  v_previous_uuid_text text;
  v_option_ids uuid[] := ARRAY[]::uuid[];
  v_answers text[] := ARRAY[]::text[];
  v_normalized text;
BEGIN
  SELECT question.question_type
  INTO v_question_type
  FROM public.quiz_questions AS question
  WHERE question.id = p_question_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz answer key has no owning question.';
  END IF;

  CASE v_question_type
    WHEN 'single_choice'::public.question_type THEN
      PERFORM private.assert_jsonb_object_keys(
        p_answer_spec,
        ARRAY['correctOptionId']::text[],
        ARRAY['correctOptionId']::text[],
        'Single-choice answer spec'
      );
      v_text := private.assert_jsonb_string(
        p_answer_spec -> 'correctOptionId',
        'Single-choice correctOptionId'
      );
      v_uuid := private.assert_canonical_uuid_text(
        v_text,
        'Single-choice correctOptionId'
      );
      PERFORM 1
      FROM public.quiz_question_options AS option_entry
      WHERE option_entry.question_id = p_question_id
        AND option_entry.id = v_uuid;
      IF NOT FOUND THEN
        RAISE EXCEPTION 'The single-choice answer key references a foreign option.';
      END IF;

    WHEN 'multiple_choice'::public.question_type THEN
      PERFORM private.assert_jsonb_object_keys(
        p_answer_spec,
        ARRAY['correctOptionIds']::text[],
        ARRAY['correctOptionIds']::text[],
        'Multiple-choice answer spec'
      );
      v_value := p_answer_spec -> 'correctOptionIds';
      IF pg_catalog.jsonb_typeof(v_value) <> 'array' THEN
        RAISE EXCEPTION 'Multiple-choice correctOptionIds must be an array.';
      END IF;

      FOR v_value IN
        SELECT array_entry.value
        FROM pg_catalog.jsonb_array_elements(
          p_answer_spec -> 'correctOptionIds'
        ) AS array_entry(value)
      LOOP
        v_text := private.assert_jsonb_string(
          v_value,
          'Multiple-choice correctOptionIds entry'
        );
        v_uuid := private.assert_canonical_uuid_text(
          v_text,
          'Multiple-choice correctOptionIds entry'
        );
        IF v_uuid = ANY (v_option_ids)
          OR (
            v_previous_uuid_text IS NOT NULL
            AND v_text COLLATE "C" <= v_previous_uuid_text COLLATE "C"
          ) THEN
          RAISE EXCEPTION
            'Multiple-choice correctOptionIds must be unique and ascending.';
        END IF;
        PERFORM 1
        FROM public.quiz_question_options AS option_entry
        WHERE option_entry.question_id = p_question_id
          AND option_entry.id = v_uuid;
        IF NOT FOUND THEN
          RAISE EXCEPTION
            'The multiple-choice answer key references a foreign option.';
        END IF;
        v_option_ids := pg_catalog.array_append(v_option_ids, v_uuid);
        v_previous_uuid_text := v_text;
      END LOOP;

      IF COALESCE(pg_catalog.array_length(v_option_ids, 1), 0) = 0 THEN
        RAISE EXCEPTION 'Multiple-choice answer keys need at least one correct option.';
      END IF;

    WHEN 'short_text'::public.question_type THEN
      PERFORM private.assert_jsonb_object_keys(
        p_answer_spec,
        ARRAY['acceptedAnswers', 'normalization']::text[],
        ARRAY['acceptedAnswers', 'normalization']::text[],
        'Short-text answer spec'
      );
      v_text := private.assert_jsonb_string(
        p_answer_spec -> 'normalization',
        'Short-text normalization'
      );
      IF v_text <> 'nfkc_ascii_ws_ascii_lower_v1' THEN
        RAISE EXCEPTION 'Short-text answer specs must use the approved normalizer.';
      END IF;
      v_value := p_answer_spec -> 'acceptedAnswers';
      IF pg_catalog.jsonb_typeof(v_value) <> 'array' THEN
        RAISE EXCEPTION 'Short-text acceptedAnswers must be an array.';
      END IF;

      FOR v_value IN
        SELECT array_entry.value
        FROM pg_catalog.jsonb_array_elements(
          p_answer_spec -> 'acceptedAnswers'
        ) AS array_entry(value)
      LOOP
        v_text := private.assert_jsonb_string(
          v_value,
          'Short-text acceptedAnswers entry'
        );
        v_normalized := private.normalize_short_text(v_text);
        IF v_text <> v_normalized
          OR pg_catalog.char_length(v_text) NOT BETWEEN 1 AND 4000
          OR v_text = ANY (v_answers) THEN
          RAISE EXCEPTION
            'Short-text acceptedAnswers must be unique approved normalized values.';
        END IF;
        v_answers := pg_catalog.array_append(v_answers, v_text);
      END LOOP;
  END CASE;
END;
$validate_quiz_question_answer_spec$;

CREATE FUNCTION private.validate_exercise_answer_key_row()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $validate_exercise_answer_key_row$
BEGIN
  IF TG_OP <> 'INSERT' AND TG_OP <> 'UPDATE' THEN
    RAISE EXCEPTION
      'private.validate_exercise_answer_key_row may run only for insert or update triggers.';
  END IF;

  PERFORM private.validate_exercise_answer_spec(NEW.exercise_id, NEW.answer_spec);
  RETURN NEW;
END;
$validate_exercise_answer_key_row$;

CREATE FUNCTION private.validate_quiz_question_answer_key_row()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $validate_quiz_question_answer_key_row$
BEGIN
  IF TG_OP <> 'INSERT' AND TG_OP <> 'UPDATE' THEN
    RAISE EXCEPTION
      'private.validate_quiz_question_answer_key_row may run only for insert or update triggers.';
  END IF;

  PERFORM private.validate_quiz_question_answer_spec(NEW.question_id, NEW.answer_spec);
  RETURN NEW;
END;
$validate_quiz_question_answer_key_row$;

CREATE FUNCTION private.validate_exercise_definition(p_exercise_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $validate_exercise_definition$
DECLARE
  v_exercise_type public.exercise_type;
  v_answer_spec jsonb;
  v_option_count bigint;
  v_answer_count integer;
BEGIN
  SELECT exercise.exercise_type
  INTO v_exercise_type
  FROM public.exercises AS exercise
  WHERE exercise.id = p_exercise_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The exercise definition has no owning exercise.';
  END IF;

  SELECT pg_catalog.count(*)
  INTO v_option_count
  FROM public.exercise_options AS option_entry
  WHERE option_entry.exercise_id = p_exercise_id;

  IF v_exercise_type = 'python_code'::public.exercise_type THEN
    IF v_option_count <> 0
      OR EXISTS (
        SELECT 1
        FROM private.exercise_answer_keys AS answer_key
        WHERE answer_key.exercise_id = p_exercise_id
      ) THEN
      RAISE EXCEPTION 'Python exercises cannot use scalar options or answer keys.';
    END IF;

    RAISE EXCEPTION
      'Python exercise publication is unavailable until its digest-pinned definition exists.';
  END IF;

  SELECT answer_key.answer_spec
  INTO v_answer_spec
  FROM private.exercise_answer_keys AS answer_key
  WHERE answer_key.exercise_id = p_exercise_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'A publishable exercise needs one answer key.';
  END IF;

  PERFORM private.validate_exercise_answer_spec(p_exercise_id, v_answer_spec);

  IF v_exercise_type IN (
    'single_choice'::public.exercise_type,
    'multiple_choice'::public.exercise_type
  ) THEN
    IF v_option_count NOT BETWEEN 2 AND 20 THEN
      RAISE EXCEPTION 'Publishable choice exercises need between two and twenty options.';
    END IF;
    RETURN;
  END IF;

  IF v_option_count <> 0 THEN
    RAISE EXCEPTION 'Publishable short-text exercises cannot have options.';
  END IF;

  v_answer_count := pg_catalog.jsonb_array_length(
    v_answer_spec -> 'acceptedAnswers'
  );
  IF v_answer_count NOT BETWEEN 1 AND 20 THEN
    RAISE EXCEPTION
      'Publishable short-text exercises need between one and twenty accepted answers.';
  END IF;
END;
$validate_exercise_definition$;

CREATE FUNCTION private.validate_quiz_definition(p_quiz_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $validate_quiz_definition$
DECLARE
  v_question_count bigint;
  v_total_points bigint;
  v_question record;
  v_option_count bigint;
  v_answer_spec jsonb;
  v_answer_count integer;
BEGIN
  PERFORM 1
  FROM public.quizzes AS quiz
  WHERE quiz.id = p_quiz_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz definition has no owning quiz.';
  END IF;

  SELECT pg_catalog.count(*), COALESCE(pg_catalog.sum(question.points), 0)
  INTO v_question_count, v_total_points
  FROM public.quiz_questions AS question
  WHERE question.quiz_id = p_quiz_id;

  IF v_question_count NOT BETWEEN 1 AND 100 OR v_total_points <= 0 THEN
    RAISE EXCEPTION 'A publishable quiz needs one to one hundred positive-point questions.';
  END IF;

  FOR v_question IN
    SELECT question.id, question.question_type
    FROM public.quiz_questions AS question
    WHERE question.quiz_id = p_quiz_id
    ORDER BY question.position, question.id
  LOOP
    SELECT pg_catalog.count(*)
    INTO v_option_count
    FROM public.quiz_question_options AS option_entry
    WHERE option_entry.question_id = v_question.id;

    SELECT answer_key.answer_spec
    INTO v_answer_spec
    FROM private.quiz_question_answer_keys AS answer_key
    WHERE answer_key.question_id = v_question.id;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'A publishable quiz question needs one answer key.';
    END IF;

    PERFORM private.validate_quiz_question_answer_spec(
      v_question.id,
      v_answer_spec
    );

    IF v_question.question_type IN (
      'single_choice'::public.question_type,
      'multiple_choice'::public.question_type
    ) THEN
      IF v_option_count NOT BETWEEN 2 AND 20 THEN
        RAISE EXCEPTION
          'Publishable choice questions need between two and twenty options.';
      END IF;
    ELSE
      IF v_option_count <> 0 THEN
        RAISE EXCEPTION 'Publishable short-text questions cannot have options.';
      END IF;
      v_answer_count := pg_catalog.jsonb_array_length(
        v_answer_spec -> 'acceptedAnswers'
      );
      IF v_answer_count NOT BETWEEN 1 AND 20 THEN
        RAISE EXCEPTION
          'Publishable short-text questions need between one and twenty accepted answers.';
      END IF;
    END IF;
  END LOOP;
END;
$validate_quiz_definition$;

CREATE FUNCTION private.validate_authoring_answer_spec(
  p_answer_kind text,
  p_answer_spec jsonb,
  p_option_refs text[],
  p_context text
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $validate_authoring_answer_spec$
DECLARE
  v_value jsonb;
  v_text text;
  v_normalized text;
  v_references text[] := ARRAY[]::text[];
  v_answers text[] := ARRAY[]::text[];
BEGIN
  CASE p_answer_kind
    WHEN 'single_choice' THEN
      PERFORM private.assert_jsonb_object_keys(
        p_answer_spec,
        ARRAY['correctOptionRef']::text[],
        ARRAY['correctOptionRef']::text[],
        p_context
      );
      v_text := private.assert_jsonb_string(
        p_answer_spec -> 'correctOptionRef',
        p_context
      );
      PERFORM private.assert_client_ref(v_text, p_context);
      IF NOT (v_text = ANY (p_option_refs)) THEN
        RAISE EXCEPTION '% references an option outside its exact definition.', p_context;
      END IF;

    WHEN 'multiple_choice' THEN
      PERFORM private.assert_jsonb_object_keys(
        p_answer_spec,
        ARRAY['correctOptionRefs']::text[],
        ARRAY['correctOptionRefs']::text[],
        p_context
      );
      v_value := p_answer_spec -> 'correctOptionRefs';
      IF pg_catalog.jsonb_typeof(v_value) <> 'array' THEN
        RAISE EXCEPTION '% must contain an array of correct option references.', p_context;
      END IF;

      FOR v_value IN
        SELECT array_entry.value
        FROM pg_catalog.jsonb_array_elements(
          p_answer_spec -> 'correctOptionRefs'
        ) AS array_entry(value)
      LOOP
        v_text := private.assert_jsonb_string(v_value, p_context);
        PERFORM private.assert_client_ref(v_text, p_context);
        IF v_text = ANY (v_references)
          OR NOT (v_text = ANY (p_option_refs)) THEN
          RAISE EXCEPTION '% contains duplicate or foreign option references.', p_context;
        END IF;
        v_references := pg_catalog.array_append(v_references, v_text);
      END LOOP;

      IF COALESCE(pg_catalog.array_length(v_references, 1), 0) = 0 THEN
        RAISE EXCEPTION '% needs at least one correct option reference.', p_context;
      END IF;

    WHEN 'short_text' THEN
      PERFORM private.assert_jsonb_object_keys(
        p_answer_spec,
        ARRAY['acceptedAnswers', 'normalization']::text[],
        ARRAY['acceptedAnswers', 'normalization']::text[],
        p_context
      );
      v_text := private.assert_jsonb_string(
        p_answer_spec -> 'normalization',
        p_context
      );
      IF v_text <> 'nfkc_ascii_ws_ascii_lower_v1' THEN
        RAISE EXCEPTION '% uses an unsupported normalizer.', p_context;
      END IF;
      v_value := p_answer_spec -> 'acceptedAnswers';
      IF pg_catalog.jsonb_typeof(v_value) <> 'array' THEN
        RAISE EXCEPTION '% must contain an accepted-answer array.', p_context;
      END IF;
      IF pg_catalog.jsonb_array_length(v_value) NOT BETWEEN 1 AND 20 THEN
        RAISE EXCEPTION '% needs between one and twenty accepted answers.', p_context;
      END IF;

      FOR v_value IN
        SELECT array_entry.value
        FROM pg_catalog.jsonb_array_elements(
          p_answer_spec -> 'acceptedAnswers'
        ) AS array_entry(value)
      LOOP
        v_text := private.assert_jsonb_string(v_value, p_context);
        v_normalized := private.normalize_short_text(v_text);
        IF pg_catalog.char_length(v_normalized) NOT BETWEEN 1 AND 4000
          OR v_normalized = ANY (v_answers) THEN
          RAISE EXCEPTION
            '% contains duplicate or invalid normalized accepted answers.',
            p_context;
        END IF;
        v_answers := pg_catalog.array_append(v_answers, v_normalized);
      END LOOP;

    ELSE
      RAISE EXCEPTION 'The authoring answer kind is unsupported.';
  END CASE;
END;
$validate_authoring_answer_spec$;

CREATE FUNCTION private.validate_exercise_authoring_input(
  p_exercise_type public.exercise_type,
  p_definition jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $validate_exercise_authoring_input$
DECLARE
  v_options jsonb;
  v_option jsonb;
  v_answer_spec jsonb;
  v_client_ref text;
  v_option_refs text[] := ARRAY[]::text[];
BEGIN
  PERFORM private.assert_definition_size(p_definition);
  PERFORM private.assert_jsonb_object_keys(
    p_definition,
    ARRAY['options', 'answerSpec']::text[],
    ARRAY[
      'options',
      'answerSpec',
      'feedbackCorrectMarkdown',
      'feedbackIncorrectMarkdown'
    ]::text[],
    'Exercise definition input'
  );

  v_options := p_definition -> 'options';
  IF pg_catalog.jsonb_typeof(v_options) <> 'array' THEN
    RAISE EXCEPTION 'Exercise definition options must be an array.';
  END IF;

  IF p_exercise_type IN (
    'short_text'::public.exercise_type,
    'python_code'::public.exercise_type
  ) AND pg_catalog.jsonb_array_length(v_options) <> 0 THEN
    RAISE EXCEPTION 'This exercise type cannot have options.';
  END IF;

  IF pg_catalog.jsonb_array_length(v_options) > 20 THEN
    RAISE EXCEPTION 'An exercise definition cannot have more than twenty options.';
  END IF;

  FOR v_option IN
    SELECT array_entry.value
    FROM pg_catalog.jsonb_array_elements(v_options) AS array_entry(value)
  LOOP
    PERFORM private.assert_jsonb_object_keys(
      v_option,
      ARRAY['clientRef', 'labelMarkdown']::text[],
      ARRAY['clientRef', 'labelMarkdown']::text[],
      'Exercise option input'
    );
    v_client_ref := private.assert_jsonb_string(
      v_option -> 'clientRef',
      'Exercise option clientRef'
    );
    PERFORM private.assert_client_ref(v_client_ref, 'Exercise option clientRef');
    IF v_client_ref = ANY (v_option_refs) THEN
      RAISE EXCEPTION 'Exercise option client references must be unique.';
    END IF;
    PERFORM private.assert_markdown_input(
      private.assert_jsonb_string(
        v_option -> 'labelMarkdown',
        'Exercise option labelMarkdown'
      ),
      10000,
      'Exercise option labelMarkdown'
    );
    v_option_refs := pg_catalog.array_append(v_option_refs, v_client_ref);
  END LOOP;

  v_answer_spec := p_definition -> 'answerSpec';
  IF pg_catalog.jsonb_typeof(v_answer_spec) = 'null' THEN
    IF pg_catalog.jsonb_typeof(
      p_definition -> 'feedbackCorrectMarkdown'
    ) <> 'null'
      OR pg_catalog.jsonb_typeof(
        p_definition -> 'feedbackIncorrectMarkdown'
      ) <> 'null' THEN
      RAISE EXCEPTION 'Incomplete exercise drafts cannot carry answer feedback.';
    END IF;
    RETURN;
  END IF;

  IF p_exercise_type = 'python_code'::public.exercise_type THEN
    RAISE EXCEPTION 'Python exercises cannot have scalar answer keys.';
  END IF;

  PERFORM private.optional_authoring_markdown(
    p_definition,
    'feedbackCorrectMarkdown',
    'Exercise feedbackCorrectMarkdown'
  );
  PERFORM private.optional_authoring_markdown(
    p_definition,
    'feedbackIncorrectMarkdown',
    'Exercise feedbackIncorrectMarkdown'
  );
  PERFORM private.validate_authoring_answer_spec(
    p_exercise_type::text,
    v_answer_spec,
    v_option_refs,
    'Exercise answerSpec'
  );
END;
$validate_exercise_authoring_input$;

CREATE FUNCTION private.validate_quiz_authoring_input(p_definition jsonb)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $validate_quiz_authoring_input$
DECLARE
  v_questions jsonb;
  v_question jsonb;
  v_options jsonb;
  v_option jsonb;
  v_answer_spec jsonb;
  v_question_ref text;
  v_option_ref text;
  v_question_type text;
  v_question_refs text[] := ARRAY[]::text[];
  v_option_refs text[];
BEGIN
  PERFORM private.assert_definition_size(p_definition);
  PERFORM private.assert_jsonb_object_keys(
    p_definition,
    ARRAY['questions']::text[],
    ARRAY['questions']::text[],
    'Quiz definition input'
  );

  v_questions := p_definition -> 'questions';
  IF pg_catalog.jsonb_typeof(v_questions) <> 'array' THEN
    RAISE EXCEPTION 'Quiz definition questions must be an array.';
  END IF;
  IF pg_catalog.jsonb_array_length(v_questions) > 100 THEN
    RAISE EXCEPTION 'A quiz definition cannot have more than one hundred questions.';
  END IF;

  FOR v_question IN
    SELECT array_entry.value
    FROM pg_catalog.jsonb_array_elements(v_questions) AS array_entry(value)
  LOOP
    PERFORM private.assert_jsonb_object_keys(
      v_question,
      ARRAY[
        'clientRef',
        'promptMarkdown',
        'questionType',
        'points',
        'options',
        'answerSpec'
      ]::text[],
      ARRAY[
        'clientRef',
        'promptMarkdown',
        'questionType',
        'points',
        'options',
        'answerSpec',
        'feedbackCorrectMarkdown',
        'feedbackIncorrectMarkdown'
      ]::text[],
      'Quiz question input'
    );
    v_question_ref := private.assert_jsonb_string(
      v_question -> 'clientRef',
      'Quiz question clientRef'
    );
    PERFORM private.assert_client_ref(v_question_ref, 'Quiz question clientRef');
    IF v_question_ref = ANY (v_question_refs) THEN
      RAISE EXCEPTION 'Quiz question client references must be unique.';
    END IF;
    v_question_refs := pg_catalog.array_append(v_question_refs, v_question_ref);

    PERFORM private.assert_markdown_input(
      private.assert_jsonb_string(
        v_question -> 'promptMarkdown',
        'Quiz question promptMarkdown'
      ),
      50000,
      'Quiz question promptMarkdown'
    );
    v_question_type := private.assert_jsonb_string(
      v_question -> 'questionType',
      'Quiz question questionType'
    );
    IF v_question_type NOT IN ('single_choice', 'multiple_choice', 'short_text') THEN
      RAISE EXCEPTION 'Quiz question type is unsupported.';
    END IF;
    PERFORM private.assert_jsonb_bounded_integer(
      v_question -> 'points',
      1,
      1000,
      'Quiz question points'
    );

    v_options := v_question -> 'options';
    IF pg_catalog.jsonb_typeof(v_options) <> 'array' THEN
      RAISE EXCEPTION 'Quiz question options must be an array.';
    END IF;
    IF pg_catalog.jsonb_array_length(v_options) > 20 THEN
      RAISE EXCEPTION 'A quiz question cannot have more than twenty options.';
    END IF;
    IF v_question_type = 'short_text'
      AND pg_catalog.jsonb_array_length(v_options) <> 0 THEN
      RAISE EXCEPTION 'Short-text quiz questions cannot have options.';
    END IF;

    v_option_refs := ARRAY[]::text[];
    FOR v_option IN
      SELECT array_entry.value
      FROM pg_catalog.jsonb_array_elements(v_options) AS array_entry(value)
    LOOP
      PERFORM private.assert_jsonb_object_keys(
        v_option,
        ARRAY['clientRef', 'labelMarkdown']::text[],
        ARRAY['clientRef', 'labelMarkdown']::text[],
        'Quiz option input'
      );
      v_option_ref := private.assert_jsonb_string(
        v_option -> 'clientRef',
        'Quiz option clientRef'
      );
      PERFORM private.assert_client_ref(v_option_ref, 'Quiz option clientRef');
      IF v_option_ref = ANY (v_option_refs) THEN
        RAISE EXCEPTION
          'Quiz option client references must be unique within one question.';
      END IF;
      PERFORM private.assert_markdown_input(
        private.assert_jsonb_string(
          v_option -> 'labelMarkdown',
          'Quiz option labelMarkdown'
        ),
        10000,
        'Quiz option labelMarkdown'
      );
      v_option_refs := pg_catalog.array_append(v_option_refs, v_option_ref);
    END LOOP;

    v_answer_spec := v_question -> 'answerSpec';
    IF pg_catalog.jsonb_typeof(v_answer_spec) = 'null' THEN
      IF pg_catalog.jsonb_typeof(
        v_question -> 'feedbackCorrectMarkdown'
      ) <> 'null'
        OR pg_catalog.jsonb_typeof(
          v_question -> 'feedbackIncorrectMarkdown'
        ) <> 'null' THEN
        RAISE EXCEPTION 'Incomplete quiz questions cannot carry answer feedback.';
      END IF;
    ELSE
      PERFORM private.optional_authoring_markdown(
        v_question,
        'feedbackCorrectMarkdown',
        'Quiz feedbackCorrectMarkdown'
      );
      PERFORM private.optional_authoring_markdown(
        v_question,
        'feedbackIncorrectMarkdown',
        'Quiz feedbackIncorrectMarkdown'
      );
      PERFORM private.validate_authoring_answer_spec(
        v_question_type,
        v_answer_spec,
        v_option_refs,
        'Quiz answerSpec'
      );
    END IF;
  END LOOP;
END;
$validate_quiz_authoring_input$;

CREATE FUNCTION private.validate_exercise_assessment_root()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $validate_exercise_assessment_root$
DECLARE
  v_definition_changed boolean;
  v_tree_marker text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.definition_version <> 1 THEN
      RAISE EXCEPTION 'New exercises must begin at definition version 1.';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
    OR NEW.created_by IS DISTINCT FROM OLD.created_by
    OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Exercise identity and creation audit fields are immutable.';
  END IF;

  v_definition_changed :=
    NEW.chapter_id IS DISTINCT FROM OLD.chapter_id
    OR NEW.title IS DISTINCT FROM OLD.title
    OR NEW.prompt_markdown IS DISTINCT FROM OLD.prompt_markdown
    OR NEW.exercise_type IS DISTINCT FROM OLD.exercise_type
    OR NEW.points IS DISTINCT FROM OLD.points
    OR NEW.is_required IS DISTINCT FROM OLD.is_required;

  IF NEW.exercise_type IS DISTINCT FROM OLD.exercise_type
    AND (
      EXISTS (
        SELECT 1
        FROM public.exercise_options AS option_entry
        WHERE option_entry.exercise_id = OLD.id
      )
      OR EXISTS (
        SELECT 1
        FROM private.exercise_answer_keys AS answer_key
        WHERE answer_key.exercise_id = OLD.id
      )
    ) THEN
    RAISE EXCEPTION
      'An exercise type can change only after its prior draft tree is removed.';
  END IF;

  IF OLD.status <> 'draft'::public.content_status THEN
    IF v_definition_changed
      OR NEW.definition_version IS DISTINCT FROM OLD.definition_version THEN
      RAISE EXCEPTION 'Published or archived exercise definitions are immutable.';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF v_definition_changed
      OR NEW.definition_version IS DISTINCT FROM OLD.definition_version THEN
      RAISE EXCEPTION 'Exercise lifecycle changes cannot alter its definition.';
    END IF;
    IF NEW.status = 'published'::public.content_status THEN
      PERFORM private.validate_exercise_definition(NEW.id);
    END IF;
    RETURN NEW;
  END IF;

  IF v_definition_changed
    AND NEW.definition_version <> OLD.definition_version + 1 THEN
    RAISE EXCEPTION 'Exercise definition changes must advance definition version once.';
  END IF;

  IF NOT v_definition_changed
    AND NEW.definition_version IS DISTINCT FROM OLD.definition_version THEN
    v_tree_marker := pg_catalog.current_setting(
      'coditza.assessment_tree_root',
      true
    );
    IF NEW.definition_version <> OLD.definition_version + 1
      OR v_tree_marker IS DISTINCT FROM 'exercise:' || OLD.id::text THEN
      RAISE EXCEPTION
        'Only the locked exercise tree replacement may advance definition version.';
    END IF;
  END IF;

  RETURN NEW;
END;
$validate_exercise_assessment_root$;

CREATE FUNCTION private.validate_quiz_assessment_root()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $validate_quiz_assessment_root$
DECLARE
  v_definition_changed boolean;
  v_tree_marker text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.definition_version <> 1 THEN
      RAISE EXCEPTION 'New quizzes must begin at definition version 1.';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.id IS DISTINCT FROM OLD.id
    OR NEW.created_by IS DISTINCT FROM OLD.created_by
    OR NEW.created_at IS DISTINCT FROM OLD.created_at THEN
    RAISE EXCEPTION 'Quiz identity and creation audit fields are immutable.';
  END IF;

  v_definition_changed :=
    NEW.chapter_id IS DISTINCT FROM OLD.chapter_id
    OR NEW.slug IS DISTINCT FROM OLD.slug
    OR NEW.title IS DISTINCT FROM OLD.title
    OR NEW.instructions_markdown IS DISTINCT FROM OLD.instructions_markdown
    OR NEW.passing_percent IS DISTINCT FROM OLD.passing_percent
    OR NEW.max_attempts IS DISTINCT FROM OLD.max_attempts
    OR NEW.time_limit_seconds IS DISTINCT FROM OLD.time_limit_seconds
    OR NEW.is_required IS DISTINCT FROM OLD.is_required;

  IF OLD.status <> 'draft'::public.content_status THEN
    IF v_definition_changed
      OR NEW.definition_version IS DISTINCT FROM OLD.definition_version THEN
      RAISE EXCEPTION 'Published or archived quiz definitions are immutable.';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    IF v_definition_changed
      OR NEW.definition_version IS DISTINCT FROM OLD.definition_version THEN
      RAISE EXCEPTION 'Quiz lifecycle changes cannot alter its definition.';
    END IF;
    IF NEW.status = 'published'::public.content_status THEN
      PERFORM private.validate_quiz_definition(NEW.id);
    END IF;
    RETURN NEW;
  END IF;

  IF v_definition_changed
    AND NEW.definition_version <> OLD.definition_version + 1 THEN
    RAISE EXCEPTION 'Quiz definition changes must advance definition version once.';
  END IF;

  IF NOT v_definition_changed
    AND NEW.definition_version IS DISTINCT FROM OLD.definition_version THEN
    v_tree_marker := pg_catalog.current_setting(
      'coditza.assessment_tree_root',
      true
    );
    IF NEW.definition_version <> OLD.definition_version + 1
      OR v_tree_marker IS DISTINCT FROM 'quiz:' || OLD.id::text THEN
      RAISE EXCEPTION
        'Only the locked quiz tree replacement may advance definition version.';
    END IF;
  END IF;

  RETURN NEW;
END;
$validate_quiz_assessment_root$;

CREATE FUNCTION private.assert_exercise_tree_write(p_exercise_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_exercise_tree_write$
DECLARE
  v_status public.content_status;
BEGIN
  SELECT exercise.status
  INTO v_status
  FROM public.exercises AS exercise
  WHERE exercise.id = p_exercise_id
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The exercise child row has no owning exercise.';
  END IF;

  IF v_status <> 'draft'::public.content_status
    OR pg_catalog.current_setting(
      'coditza.assessment_tree_root',
      true
    ) IS DISTINCT FROM 'exercise:' || p_exercise_id::text THEN
    RAISE EXCEPTION
      'Exercise child rows may change only through their locked draft replacement.';
  END IF;
END;
$assert_exercise_tree_write$;

CREATE FUNCTION private.assert_quiz_tree_write(p_quiz_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_quiz_tree_write$
DECLARE
  v_status public.content_status;
BEGIN
  SELECT quiz.status
  INTO v_status
  FROM public.quizzes AS quiz
  WHERE quiz.id = p_quiz_id
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz child row has no owning quiz.';
  END IF;

  IF v_status <> 'draft'::public.content_status
    OR pg_catalog.current_setting(
      'coditza.assessment_tree_root',
      true
    ) IS DISTINCT FROM 'quiz:' || p_quiz_id::text THEN
    RAISE EXCEPTION
      'Quiz child rows may change only through their locked draft replacement.';
  END IF;
END;
$assert_quiz_tree_write$;

CREATE FUNCTION private.enforce_exercise_option_tree_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_exercise_option_tree_write$
DECLARE
  v_exercise_id uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION
      'Exercise option rows are replaced as a complete draft tree, never updated in place.';
  END IF;

  v_exercise_id := CASE
    WHEN TG_OP = 'DELETE' THEN OLD.exercise_id
    ELSE NEW.exercise_id
  END;
  PERFORM private.assert_exercise_tree_write(v_exercise_id);

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$enforce_exercise_option_tree_write$;

CREATE FUNCTION private.enforce_exercise_answer_key_tree_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_exercise_answer_key_tree_write$
DECLARE
  v_exercise_id uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION
      'Exercise answer-key rows are replaced as a complete draft tree, never updated in place.';
  END IF;

  v_exercise_id := CASE
    WHEN TG_OP = 'DELETE' THEN OLD.exercise_id
    ELSE NEW.exercise_id
  END;
  PERFORM private.assert_exercise_tree_write(v_exercise_id);

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$enforce_exercise_answer_key_tree_write$;

CREATE FUNCTION private.enforce_quiz_question_tree_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_quiz_question_tree_write$
DECLARE
  v_quiz_id uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION
      'Quiz question rows are replaced as a complete draft tree, never updated in place.';
  END IF;

  v_quiz_id := CASE
    WHEN TG_OP = 'DELETE' THEN OLD.quiz_id
    ELSE NEW.quiz_id
  END;
  PERFORM private.assert_quiz_tree_write(v_quiz_id);

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$enforce_quiz_question_tree_write$;

CREATE FUNCTION private.enforce_quiz_question_option_tree_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_quiz_question_option_tree_write$
DECLARE
  v_question_id uuid;
  v_quiz_id uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION
      'Quiz option rows are replaced as a complete draft tree, never updated in place.';
  END IF;

  v_question_id := CASE
    WHEN TG_OP = 'DELETE' THEN OLD.question_id
    ELSE NEW.question_id
  END;
  SELECT question.quiz_id
  INTO v_quiz_id
  FROM public.quiz_questions AS question
  WHERE question.id = v_question_id
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz option has no owning question.';
  END IF;
  PERFORM private.assert_quiz_tree_write(v_quiz_id);

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$enforce_quiz_question_option_tree_write$;

CREATE FUNCTION private.enforce_quiz_answer_key_tree_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_quiz_answer_key_tree_write$
DECLARE
  v_question_id uuid;
  v_quiz_id uuid;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    RAISE EXCEPTION
      'Quiz answer-key rows are replaced as a complete draft tree, never updated in place.';
  END IF;

  v_question_id := CASE
    WHEN TG_OP = 'DELETE' THEN OLD.question_id
    ELSE NEW.question_id
  END;
  SELECT question.quiz_id
  INTO v_quiz_id
  FROM public.quiz_questions AS question
  WHERE question.id = v_question_id
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'The quiz answer key has no owning question.';
  END IF;
  PERFORM private.assert_quiz_tree_write(v_quiz_id);

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$enforce_quiz_answer_key_tree_write$;

CREATE TRIGGER exercises_validate_assessment_root
BEFORE INSERT OR UPDATE ON public.exercises
FOR EACH ROW
EXECUTE FUNCTION private.validate_exercise_assessment_root();

CREATE TRIGGER quizzes_validate_assessment_root
BEFORE INSERT OR UPDATE ON public.quizzes
FOR EACH ROW
EXECUTE FUNCTION private.validate_quiz_assessment_root();

CREATE TRIGGER exercise_options_enforce_draft_tree
BEFORE INSERT OR UPDATE OR DELETE ON public.exercise_options
FOR EACH ROW
EXECUTE FUNCTION private.enforce_exercise_option_tree_write();

CREATE TRIGGER exercise_answer_keys_enforce_draft_tree
BEFORE INSERT OR UPDATE OR DELETE ON private.exercise_answer_keys
FOR EACH ROW
EXECUTE FUNCTION private.enforce_exercise_answer_key_tree_write();

CREATE TRIGGER exercise_answer_keys_validate_answer_spec
BEFORE INSERT OR UPDATE ON private.exercise_answer_keys
FOR EACH ROW
EXECUTE FUNCTION private.validate_exercise_answer_key_row();

CREATE TRIGGER quiz_questions_enforce_draft_tree
BEFORE INSERT OR UPDATE OR DELETE ON public.quiz_questions
FOR EACH ROW
EXECUTE FUNCTION private.enforce_quiz_question_tree_write();

CREATE TRIGGER quiz_question_options_enforce_draft_tree
BEFORE INSERT OR UPDATE OR DELETE ON public.quiz_question_options
FOR EACH ROW
EXECUTE FUNCTION private.enforce_quiz_question_option_tree_write();

CREATE TRIGGER quiz_question_answer_keys_enforce_draft_tree
BEFORE INSERT OR UPDATE OR DELETE ON private.quiz_question_answer_keys
FOR EACH ROW
EXECUTE FUNCTION private.enforce_quiz_answer_key_tree_write();

CREATE TRIGGER quiz_question_answer_keys_validate_answer_spec
BEFORE INSERT OR UPDATE ON private.quiz_question_answer_keys
FOR EACH ROW
EXECUTE FUNCTION private.validate_quiz_question_answer_key_row();

CREATE FUNCTION private.replace_draft_exercise_definition(
  p_exercise_id uuid,
  p_expected_row_version integer,
  p_definition jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $replace_draft_exercise_definition$
DECLARE
  v_exercise_type public.exercise_type;
  v_status public.content_status;
  v_actual_row_version integer;
  v_next_row_version integer;
  v_next_definition_version integer;
  v_options jsonb;
  v_option jsonb;
  v_answer_spec_input jsonb;
  v_stored_answer_spec jsonb;
  v_stored_option_ids jsonb;
  v_option_ref text;
  v_option_id uuid;
  v_option_ref_to_id jsonb := '{}'::jsonb;
  v_option_mappings jsonb := '[]'::jsonb;
  v_feedback_correct text;
  v_feedback_incorrect text;
BEGIN
  SELECT exercise.exercise_type, exercise.status, exercise.row_version
  INTO v_exercise_type, v_status, v_actual_row_version
  FROM public.exercises AS exercise
  WHERE exercise.id = p_exercise_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The draft exercise does not exist.';
  END IF;
  IF v_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft exercises can replace their definition.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The exercise draft version is stale.';
  END IF;

  PERFORM private.validate_exercise_authoring_input(
    v_exercise_type,
    p_definition
  );

  PERFORM pg_catalog.set_config(
    'coditza.assessment_tree_root',
    'exercise:' || p_exercise_id::text,
    true
  );

  DELETE FROM private.exercise_answer_keys AS answer_key
  WHERE answer_key.exercise_id = p_exercise_id;
  DELETE FROM public.exercise_options AS option_entry
  WHERE option_entry.exercise_id = p_exercise_id;

  v_options := p_definition -> 'options';
  IF pg_catalog.jsonb_array_length(v_options) > 0 THEN
    FOR v_option_index IN 0 .. pg_catalog.jsonb_array_length(v_options) - 1 LOOP
      v_option := v_options -> v_option_index;
      v_option_ref := v_option ->> 'clientRef';
      INSERT INTO public.exercise_options (
        exercise_id,
        label_markdown,
        position
      )
      VALUES (
        p_exercise_id,
        v_option ->> 'labelMarkdown',
        v_option_index
      )
      RETURNING id INTO v_option_id;

      v_option_ref_to_id := v_option_ref_to_id
        || pg_catalog.jsonb_build_object(v_option_ref, v_option_id::text);
      v_option_mappings := v_option_mappings || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'clientRef',
          v_option_ref,
          'id',
          v_option_id::text
        )
      );
    END LOOP;
  END IF;

  v_answer_spec_input := p_definition -> 'answerSpec';
  IF pg_catalog.jsonb_typeof(v_answer_spec_input) <> 'null' THEN
    v_feedback_correct := private.optional_authoring_markdown(
      p_definition,
      'feedbackCorrectMarkdown',
      'Exercise feedbackCorrectMarkdown'
    );
    v_feedback_incorrect := private.optional_authoring_markdown(
      p_definition,
      'feedbackIncorrectMarkdown',
      'Exercise feedbackIncorrectMarkdown'
    );

    CASE v_exercise_type
      WHEN 'single_choice'::public.exercise_type THEN
        v_stored_answer_spec := pg_catalog.jsonb_build_object(
          'correctOptionId',
          v_option_ref_to_id ->> (v_answer_spec_input ->> 'correctOptionRef')
        );

      WHEN 'multiple_choice'::public.exercise_type THEN
        SELECT COALESCE(
          pg_catalog.jsonb_agg(
            pg_catalog.to_jsonb(mapped.option_id::text)
            ORDER BY mapped.option_id::text COLLATE "C"
          ),
          '[]'::jsonb
        )
        INTO v_stored_option_ids
        FROM (
          SELECT (
            v_option_ref_to_id ->> (array_entry.value #>> '{}')
          )::uuid AS option_id
          FROM pg_catalog.jsonb_array_elements(
            v_answer_spec_input -> 'correctOptionRefs'
          ) AS array_entry(value)
        ) AS mapped;
        v_stored_answer_spec := pg_catalog.jsonb_build_object(
          'correctOptionIds',
          v_stored_option_ids
        );

      WHEN 'short_text'::public.exercise_type THEN
        SELECT COALESCE(
          pg_catalog.jsonb_agg(
            pg_catalog.to_jsonb(
              private.normalize_short_text(array_entry.value #>> '{}')
            )
            ORDER BY array_entry.ordinality
          ),
          '[]'::jsonb
        )
        INTO v_stored_option_ids
        FROM pg_catalog.jsonb_array_elements(
          v_answer_spec_input -> 'acceptedAnswers'
        ) WITH ORDINALITY AS array_entry(value, ordinality);
        v_stored_answer_spec := pg_catalog.jsonb_build_object(
          'acceptedAnswers',
          v_stored_option_ids,
          'normalization',
          'nfkc_ascii_ws_ascii_lower_v1'
        );

      ELSE
        RAISE EXCEPTION 'Python exercises cannot have scalar answer keys.';
    END CASE;

    INSERT INTO private.exercise_answer_keys (
      exercise_id,
      answer_spec,
      feedback_correct_markdown,
      feedback_incorrect_markdown
    )
    VALUES (
      p_exercise_id,
      v_stored_answer_spec,
      v_feedback_correct,
      v_feedback_incorrect
    );
  END IF;

  UPDATE public.exercises AS exercise
  SET definition_version = exercise.definition_version + 1
  WHERE exercise.id = p_exercise_id
  RETURNING row_version, definition_version
  INTO v_next_row_version, v_next_definition_version;

  PERFORM pg_catalog.set_config('coditza.assessment_tree_root', '', true);

  RETURN pg_catalog.jsonb_build_object(
    'exerciseId',
    p_exercise_id::text,
    'rowVersion',
    v_next_row_version,
    'definitionVersion',
    v_next_definition_version,
    'optionIdMappings',
    v_option_mappings
  );
END;
$replace_draft_exercise_definition$;

CREATE FUNCTION private.replace_draft_quiz_definition(
  p_quiz_id uuid,
  p_expected_row_version integer,
  p_definition jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $replace_draft_quiz_definition$
DECLARE
  v_status public.content_status;
  v_actual_row_version integer;
  v_next_row_version integer;
  v_next_definition_version integer;
  v_questions jsonb;
  v_question jsonb;
  v_options jsonb;
  v_option jsonb;
  v_answer_spec_input jsonb;
  v_stored_answer_spec jsonb;
  v_stored_option_ids jsonb;
  v_question_ref text;
  v_question_id uuid;
  v_question_type text;
  v_option_ref text;
  v_option_id uuid;
  v_option_ref_to_id jsonb;
  v_question_mappings jsonb := '[]'::jsonb;
  v_option_mappings jsonb := '[]'::jsonb;
  v_feedback_correct text;
  v_feedback_incorrect text;
BEGIN
  SELECT quiz.status, quiz.row_version
  INTO v_status, v_actual_row_version
  FROM public.quizzes AS quiz
  WHERE quiz.id = p_quiz_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'The draft quiz does not exist.';
  END IF;
  IF v_status <> 'draft'::public.content_status THEN
    RAISE EXCEPTION 'Only draft quizzes can replace their definition.';
  END IF;
  IF p_expected_row_version IS DISTINCT FROM v_actual_row_version THEN
    RAISE EXCEPTION 'The quiz draft version is stale.';
  END IF;

  PERFORM private.validate_quiz_authoring_input(p_definition);

  PERFORM pg_catalog.set_config(
    'coditza.assessment_tree_root',
    'quiz:' || p_quiz_id::text,
    true
  );

  DELETE FROM private.quiz_question_answer_keys AS answer_key
  WHERE answer_key.question_id IN (
    SELECT question.id
    FROM public.quiz_questions AS question
    WHERE question.quiz_id = p_quiz_id
  );
  DELETE FROM public.quiz_question_options AS option_entry
  WHERE option_entry.question_id IN (
    SELECT question.id
    FROM public.quiz_questions AS question
    WHERE question.quiz_id = p_quiz_id
  );
  DELETE FROM public.quiz_questions AS question
  WHERE question.quiz_id = p_quiz_id;

  v_questions := p_definition -> 'questions';
  IF pg_catalog.jsonb_array_length(v_questions) > 0 THEN
    FOR v_question_index IN 0 .. pg_catalog.jsonb_array_length(v_questions) - 1 LOOP
      v_question := v_questions -> v_question_index;
      v_question_ref := v_question ->> 'clientRef';
      v_question_type := v_question ->> 'questionType';
      INSERT INTO public.quiz_questions (
        quiz_id,
        prompt_markdown,
        question_type,
        position,
        points
      )
      VALUES (
        p_quiz_id,
        v_question ->> 'promptMarkdown',
        v_question_type::public.question_type,
        v_question_index,
        (v_question ->> 'points')::integer
      )
      RETURNING id INTO v_question_id;

      v_question_mappings := v_question_mappings || pg_catalog.jsonb_build_array(
        pg_catalog.jsonb_build_object(
          'clientRef',
          v_question_ref,
          'id',
          v_question_id::text
        )
      );

      v_options := v_question -> 'options';
      v_option_ref_to_id := '{}'::jsonb;
      IF pg_catalog.jsonb_array_length(v_options) > 0 THEN
        FOR v_option_index IN 0 .. pg_catalog.jsonb_array_length(v_options) - 1 LOOP
          v_option := v_options -> v_option_index;
          v_option_ref := v_option ->> 'clientRef';
          INSERT INTO public.quiz_question_options (
            question_id,
            label_markdown,
            position
          )
          VALUES (
            v_question_id,
            v_option ->> 'labelMarkdown',
            v_option_index
          )
          RETURNING id INTO v_option_id;

          v_option_ref_to_id := v_option_ref_to_id
            || pg_catalog.jsonb_build_object(v_option_ref, v_option_id::text);
          v_option_mappings := v_option_mappings || pg_catalog.jsonb_build_array(
            pg_catalog.jsonb_build_object(
              'questionClientRef',
              v_question_ref,
              'clientRef',
              v_option_ref,
              'id',
              v_option_id::text
            )
          );
        END LOOP;
      END IF;

      v_answer_spec_input := v_question -> 'answerSpec';
      IF pg_catalog.jsonb_typeof(v_answer_spec_input) <> 'null' THEN
        v_feedback_correct := private.optional_authoring_markdown(
          v_question,
          'feedbackCorrectMarkdown',
          'Quiz feedbackCorrectMarkdown'
        );
        v_feedback_incorrect := private.optional_authoring_markdown(
          v_question,
          'feedbackIncorrectMarkdown',
          'Quiz feedbackIncorrectMarkdown'
        );

        CASE v_question_type
          WHEN 'single_choice' THEN
            v_stored_answer_spec := pg_catalog.jsonb_build_object(
              'correctOptionId',
              v_option_ref_to_id ->> (v_answer_spec_input ->> 'correctOptionRef')
            );

          WHEN 'multiple_choice' THEN
            SELECT COALESCE(
              pg_catalog.jsonb_agg(
                pg_catalog.to_jsonb(mapped.option_id::text)
                ORDER BY mapped.option_id::text COLLATE "C"
              ),
              '[]'::jsonb
            )
            INTO v_stored_option_ids
            FROM (
              SELECT (
                v_option_ref_to_id ->> (array_entry.value #>> '{}')
              )::uuid AS option_id
              FROM pg_catalog.jsonb_array_elements(
                v_answer_spec_input -> 'correctOptionRefs'
              ) AS array_entry(value)
            ) AS mapped;
            v_stored_answer_spec := pg_catalog.jsonb_build_object(
              'correctOptionIds',
              v_stored_option_ids
            );

          WHEN 'short_text' THEN
            SELECT COALESCE(
              pg_catalog.jsonb_agg(
                pg_catalog.to_jsonb(
                  private.normalize_short_text(array_entry.value #>> '{}')
                )
                ORDER BY array_entry.ordinality
              ),
              '[]'::jsonb
            )
            INTO v_stored_option_ids
            FROM pg_catalog.jsonb_array_elements(
              v_answer_spec_input -> 'acceptedAnswers'
            ) WITH ORDINALITY AS array_entry(value, ordinality);
            v_stored_answer_spec := pg_catalog.jsonb_build_object(
              'acceptedAnswers',
              v_stored_option_ids,
              'normalization',
              'nfkc_ascii_ws_ascii_lower_v1'
            );
        END CASE;

        INSERT INTO private.quiz_question_answer_keys (
          question_id,
          answer_spec,
          feedback_correct_markdown,
          feedback_incorrect_markdown
        )
        VALUES (
          v_question_id,
          v_stored_answer_spec,
          v_feedback_correct,
          v_feedback_incorrect
        );
      END IF;
    END LOOP;
  END IF;

  UPDATE public.quizzes AS quiz
  SET definition_version = quiz.definition_version + 1
  WHERE quiz.id = p_quiz_id
  RETURNING row_version, definition_version
  INTO v_next_row_version, v_next_definition_version;

  PERFORM pg_catalog.set_config('coditza.assessment_tree_root', '', true);

  RETURN pg_catalog.jsonb_build_object(
    'quizId',
    p_quiz_id::text,
    'rowVersion',
    v_next_row_version,
    'definitionVersion',
    v_next_definition_version,
    'questionIdMappings',
    v_question_mappings,
    'optionIdMappings',
    v_option_mappings
  );
END;
$replace_draft_quiz_definition$;

REVOKE ALL ON SCHEMA private
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL PRIVILEGES ON ALL FUNCTIONS IN SCHEMA private
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON TABLE public.exercises, public.exercise_options, public.quizzes,
  public.quiz_questions, public.quiz_question_options,
  private.exercise_answer_keys, private.quiz_question_answer_keys
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

RESET ROLE;

COMMIT;
