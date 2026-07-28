-- SUP-DATA-002: answer keys are stored only in the non-exposed private schema.
-- Shape and ownership validation is installed by the following forward migration.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE TABLE private.exercise_answer_keys (
  exercise_id uuid PRIMARY KEY
    REFERENCES public.exercises(id) ON DELETE RESTRICT,
  answer_spec jsonb NOT NULL,
  feedback_correct_markdown text,
  feedback_incorrect_markdown text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT exercise_answer_keys_answer_spec_object_check CHECK (
    pg_catalog.jsonb_typeof(answer_spec) = 'object'
  ),
  CONSTRAINT exercise_answer_keys_feedback_correct_markdown_check CHECK (
    feedback_correct_markdown IS NULL
    OR (
      pg_catalog.char_length(feedback_correct_markdown) BETWEEN 1 AND 20000
      AND feedback_correct_markdown OPERATOR(pg_catalog.~) '[^[:space:]]'
    )
  ),
  CONSTRAINT exercise_answer_keys_feedback_incorrect_markdown_check CHECK (
    feedback_incorrect_markdown IS NULL
    OR (
      pg_catalog.char_length(feedback_incorrect_markdown) BETWEEN 1 AND 20000
      AND feedback_incorrect_markdown OPERATOR(pg_catalog.~) '[^[:space:]]'
    )
  )
);

ALTER TABLE private.exercise_answer_keys ENABLE ROW LEVEL SECURITY;

CREATE TABLE private.quiz_question_answer_keys (
  question_id uuid PRIMARY KEY
    REFERENCES public.quiz_questions(id) ON DELETE RESTRICT,
  answer_spec jsonb NOT NULL,
  feedback_correct_markdown text,
  feedback_incorrect_markdown text,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT quiz_question_answer_keys_answer_spec_object_check CHECK (
    pg_catalog.jsonb_typeof(answer_spec) = 'object'
  ),
  CONSTRAINT quiz_question_answer_keys_feedback_correct_markdown_check CHECK (
    feedback_correct_markdown IS NULL
    OR (
      pg_catalog.char_length(feedback_correct_markdown) BETWEEN 1 AND 20000
      AND feedback_correct_markdown OPERATOR(pg_catalog.~) '[^[:space:]]'
    )
  ),
  CONSTRAINT quiz_question_answer_keys_feedback_incorrect_markdown_check CHECK (
    feedback_incorrect_markdown IS NULL
    OR (
      pg_catalog.char_length(feedback_incorrect_markdown) BETWEEN 1 AND 20000
      AND feedback_incorrect_markdown OPERATOR(pg_catalog.~) '[^[:space:]]'
    )
  )
);

ALTER TABLE private.quiz_question_answer_keys ENABLE ROW LEVEL SECURITY;

CREATE INDEX exercise_answer_keys_created_by_idx
  ON private.exercise_answer_keys (created_by);
CREATE INDEX exercise_answer_keys_updated_by_idx
  ON private.exercise_answer_keys (updated_by);
CREATE INDEX quiz_question_answer_keys_created_by_idx
  ON private.quiz_question_answer_keys (created_by);
CREATE INDEX quiz_question_answer_keys_updated_by_idx
  ON private.quiz_question_answer_keys (updated_by);

CREATE TRIGGER exercise_answer_keys_set_updated_at
BEFORE UPDATE ON private.exercise_answer_keys
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER quiz_question_answer_keys_set_updated_at
BEFORE UPDATE ON private.quiz_question_answer_keys
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

REVOKE ALL ON SCHEMA private
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON TABLE private.exercise_answer_keys,
  private.quiz_question_answer_keys
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

RESET ROLE;

COMMIT;
