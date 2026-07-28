-- SUP-DATA-002: public assessment-definition trees only. Private answer keys,
-- cross-table validators, and authoring helpers arrive in later forward
-- migrations. Markdown source is preserved (including meaningful indentation)
-- while every authored text field remains bounded and non-blank.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE TABLE public.exercises (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  chapter_id uuid NOT NULL REFERENCES public.chapters(id) ON DELETE RESTRICT,
  title text NOT NULL,
  prompt_markdown text NOT NULL,
  exercise_type public.exercise_type NOT NULL,
  position integer NOT NULL,
  points integer NOT NULL,
  is_required boolean NOT NULL DEFAULT true,
  status public.content_status NOT NULL DEFAULT 'draft'::public.content_status,
  row_version integer NOT NULL DEFAULT 1,
  published_at timestamptz,
  definition_version integer NOT NULL DEFAULT 1,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT exercises_title_check CHECK (
    title = pg_catalog.btrim(title)
    AND pg_catalog.char_length(title) BETWEEN 1 AND 160
  ),
  CONSTRAINT exercises_prompt_markdown_check CHECK (
    pg_catalog.char_length(prompt_markdown) BETWEEN 1 AND 50000
    AND prompt_markdown OPERATOR(pg_catalog.~) '[^[:space:]]'
  ),
  CONSTRAINT exercises_position_check CHECK (position >= 0),
  CONSTRAINT exercises_points_check CHECK (points BETWEEN 1 AND 1000),
  CONSTRAINT exercises_row_version_check CHECK (row_version > 0),
  CONSTRAINT exercises_definition_version_check CHECK (definition_version > 0),
  CONSTRAINT exercises_lifecycle_timestamp_check CHECK (
    (status <> 'draft'::public.content_status OR published_at IS NULL)
    AND (status <> 'published'::public.content_status OR published_at IS NOT NULL)
  ),
  CONSTRAINT exercises_chapter_position_key
    UNIQUE (chapter_id, position) DEFERRABLE INITIALLY IMMEDIATE
);

ALTER TABLE public.exercises ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.exercise_options (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  exercise_id uuid NOT NULL REFERENCES public.exercises(id) ON DELETE RESTRICT,
  label_markdown text NOT NULL,
  position integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT exercise_options_label_markdown_check CHECK (
    pg_catalog.char_length(label_markdown) BETWEEN 1 AND 10000
    AND label_markdown OPERATOR(pg_catalog.~) '[^[:space:]]'
  ),
  CONSTRAINT exercise_options_position_check CHECK (position >= 0),
  CONSTRAINT exercise_options_exercise_position_key
    UNIQUE (exercise_id, position) DEFERRABLE INITIALLY IMMEDIATE,
  CONSTRAINT exercise_options_exercise_id_id_key UNIQUE (exercise_id, id)
);

ALTER TABLE public.exercise_options ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.quizzes (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  chapter_id uuid NOT NULL REFERENCES public.chapters(id) ON DELETE RESTRICT,
  slug text NOT NULL,
  title text NOT NULL,
  instructions_markdown text NOT NULL,
  position integer NOT NULL,
  passing_percent integer NOT NULL DEFAULT 70,
  max_attempts integer,
  time_limit_seconds integer,
  is_required boolean NOT NULL DEFAULT true,
  status public.content_status NOT NULL DEFAULT 'draft'::public.content_status,
  row_version integer NOT NULL DEFAULT 1,
  published_at timestamptz,
  definition_version integer NOT NULL DEFAULT 1,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT quizzes_slug_check CHECK (private.is_valid_slug(slug)),
  CONSTRAINT quizzes_title_check CHECK (
    title = pg_catalog.btrim(title)
    AND pg_catalog.char_length(title) BETWEEN 1 AND 160
  ),
  CONSTRAINT quizzes_instructions_markdown_check CHECK (
    pg_catalog.char_length(instructions_markdown) BETWEEN 1 AND 20000
    AND instructions_markdown OPERATOR(pg_catalog.~) '[^[:space:]]'
  ),
  CONSTRAINT quizzes_position_check CHECK (position >= 0),
  CONSTRAINT quizzes_passing_percent_check CHECK (passing_percent BETWEEN 0 AND 100),
  CONSTRAINT quizzes_max_attempts_check CHECK (
    max_attempts IS NULL OR max_attempts BETWEEN 1 AND 100
  ),
  CONSTRAINT quizzes_time_limit_seconds_check CHECK (
    time_limit_seconds IS NULL OR time_limit_seconds BETWEEN 30 AND 86400
  ),
  CONSTRAINT quizzes_row_version_check CHECK (row_version > 0),
  CONSTRAINT quizzes_definition_version_check CHECK (definition_version > 0),
  CONSTRAINT quizzes_lifecycle_timestamp_check CHECK (
    (status <> 'draft'::public.content_status OR published_at IS NULL)
    AND (status <> 'published'::public.content_status OR published_at IS NOT NULL)
  ),
  CONSTRAINT quizzes_chapter_slug_key UNIQUE (chapter_id, slug),
  CONSTRAINT quizzes_chapter_position_key
    UNIQUE (chapter_id, position) DEFERRABLE INITIALLY IMMEDIATE
);

ALTER TABLE public.quizzes ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.quiz_questions (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  quiz_id uuid NOT NULL REFERENCES public.quizzes(id) ON DELETE RESTRICT,
  prompt_markdown text NOT NULL,
  question_type public.question_type NOT NULL,
  position integer NOT NULL,
  points integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT quiz_questions_prompt_markdown_check CHECK (
    pg_catalog.char_length(prompt_markdown) BETWEEN 1 AND 50000
    AND prompt_markdown OPERATOR(pg_catalog.~) '[^[:space:]]'
  ),
  CONSTRAINT quiz_questions_position_check CHECK (position >= 0),
  CONSTRAINT quiz_questions_points_check CHECK (points BETWEEN 1 AND 1000),
  CONSTRAINT quiz_questions_quiz_position_key
    UNIQUE (quiz_id, position) DEFERRABLE INITIALLY IMMEDIATE
);

ALTER TABLE public.quiz_questions ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.quiz_question_options (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  question_id uuid NOT NULL REFERENCES public.quiz_questions(id) ON DELETE RESTRICT,
  label_markdown text NOT NULL,
  position integer NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT quiz_question_options_label_markdown_check CHECK (
    pg_catalog.char_length(label_markdown) BETWEEN 1 AND 10000
    AND label_markdown OPERATOR(pg_catalog.~) '[^[:space:]]'
  ),
  CONSTRAINT quiz_question_options_position_check CHECK (position >= 0),
  CONSTRAINT quiz_question_options_question_position_key
    UNIQUE (question_id, position) DEFERRABLE INITIALLY IMMEDIATE,
  CONSTRAINT quiz_question_options_question_id_id_key UNIQUE (question_id, id)
);

ALTER TABLE public.quiz_question_options ENABLE ROW LEVEL SECURITY;

CREATE INDEX exercises_chapter_status_position_id_idx
  ON public.exercises (chapter_id, status, position, id);
CREATE INDEX exercises_created_by_idx ON public.exercises (created_by);
CREATE INDEX exercises_updated_by_idx ON public.exercises (updated_by);
CREATE INDEX quizzes_chapter_status_position_id_idx
  ON public.quizzes (chapter_id, status, position, id);
CREATE INDEX quizzes_created_by_idx ON public.quizzes (created_by);
CREATE INDEX quizzes_updated_by_idx ON public.quizzes (updated_by);

CREATE TRIGGER exercises_enforce_authored_lifecycle
BEFORE INSERT OR UPDATE ON public.exercises
FOR EACH ROW
EXECUTE FUNCTION private.enforce_authored_row_lifecycle();

CREATE TRIGGER exercises_set_updated_at
BEFORE UPDATE ON public.exercises
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER exercise_options_set_updated_at
BEFORE UPDATE ON public.exercise_options
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER quizzes_enforce_authored_lifecycle
BEFORE INSERT OR UPDATE ON public.quizzes
FOR EACH ROW
EXECUTE FUNCTION private.enforce_authored_row_lifecycle();

CREATE TRIGGER quizzes_set_updated_at
BEFORE UPDATE ON public.quizzes
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER quiz_questions_set_updated_at
BEFORE UPDATE ON public.quiz_questions
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER quiz_question_options_set_updated_at
BEFORE UPDATE ON public.quiz_question_options
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

REVOKE ALL ON TABLE public.exercises, public.exercise_options, public.quizzes,
  public.quiz_questions, public.quiz_question_options
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

RESET ROLE;

COMMIT;
