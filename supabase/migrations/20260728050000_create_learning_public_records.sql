-- SUP-DATA-003: durable learner-owned completions, attempts, answers, and
-- recalculable chapter snapshots. Private workflow guards arrive in a following
-- forward migration; direct runtime access remains deny-by-default throughout.
BEGIN;

-- The trusted migration operator alone can reference auth.users. Give it the
-- minimum temporary references/type rights needed to create these FK-bearing
-- tables, transfer ownership immediately, and revoke every temporary grant
-- before commit. coditza_owner never receives auth-schema access.
SET LOCAL ROLE coditza_owner;
GRANT REFERENCES ON TABLE public.theory_sections,
  public.exercises,
  public.quizzes,
  public.quiz_questions,
  public.chapters
  TO postgres;
GRANT USAGE ON TYPE public.quiz_attempt_status TO postgres;
RESET ROLE;

CREATE TABLE public.theory_section_completions (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  theory_section_id uuid NOT NULL
    REFERENCES public.theory_sections(id) ON DELETE RESTRICT,
  completed_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT theory_section_completions_pkey
    PRIMARY KEY (user_id, theory_section_id)
);

ALTER TABLE public.theory_section_completions ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.exercise_attempts (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  exercise_id uuid NOT NULL REFERENCES public.exercises(id) ON DELETE RESTRICT,
  exercise_definition_version integer NOT NULL,
  answer jsonb NOT NULL,
  is_correct boolean NOT NULL,
  points_earned integer NOT NULL,
  points_possible integer NOT NULL,
  submitted_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT exercise_attempts_definition_version_check
    CHECK (exercise_definition_version > 0),
  CONSTRAINT exercise_attempts_answer_object_check
    CHECK (pg_catalog.jsonb_typeof(answer) = 'object'),
  CONSTRAINT exercise_attempts_points_possible_check
    CHECK (points_possible BETWEEN 1 AND 1000),
  CONSTRAINT exercise_attempts_points_earned_check
    CHECK (points_earned IN (0, points_possible)),
  CONSTRAINT exercise_attempts_correctness_points_check
    CHECK (
      (is_correct AND points_earned = points_possible)
      OR (NOT is_correct AND points_earned = 0)
    )
);

ALTER TABLE public.exercise_attempts ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.quiz_attempts (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  quiz_id uuid NOT NULL REFERENCES public.quizzes(id) ON DELETE RESTRICT,
  quiz_definition_version integer NOT NULL,
  attempt_number integer NOT NULL,
  status public.quiz_attempt_status NOT NULL
    DEFAULT 'in_progress'::public.quiz_attempt_status,
  started_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  expires_at timestamptz,
  submitted_at timestamptz,
  points_earned integer,
  points_possible integer,
  score_percent numeric(5,2),
  passed boolean,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT quiz_attempts_definition_version_check
    CHECK (quiz_definition_version > 0),
  CONSTRAINT quiz_attempts_attempt_number_check
    CHECK (attempt_number > 0),
  CONSTRAINT quiz_attempts_deadline_check
    CHECK (expires_at IS NULL OR expires_at > started_at),
  CONSTRAINT quiz_attempts_score_percent_check
    CHECK (score_percent IS NULL OR score_percent BETWEEN 0 AND 100),
  CONSTRAINT quiz_attempts_points_check
    CHECK (
      (points_earned IS NULL AND points_possible IS NULL)
      OR (
        points_possible BETWEEN 1 AND 100000
        AND points_earned BETWEEN 0 AND points_possible
      )
    ),
  CONSTRAINT quiz_attempts_terminal_state_check
    CHECK (
      (
        status = 'in_progress'::public.quiz_attempt_status
        AND submitted_at IS NULL
        AND points_earned IS NULL
        AND points_possible IS NULL
        AND score_percent IS NULL
        AND passed IS NULL
      )
      OR (
        status = 'submitted'::public.quiz_attempt_status
        AND submitted_at IS NOT NULL
        AND points_earned IS NOT NULL
        AND points_possible IS NOT NULL
        AND score_percent IS NOT NULL
        AND passed IS NOT NULL
      )
      OR (
        status = 'expired'::public.quiz_attempt_status
        AND expires_at IS NOT NULL
        AND submitted_at IS NOT NULL
        AND points_earned IS NOT NULL
        AND points_possible IS NOT NULL
        AND score_percent IS NOT NULL
        AND passed IS NOT NULL
      )
    ),
  CONSTRAINT quiz_attempts_user_quiz_attempt_number_key
    UNIQUE (user_id, quiz_id, attempt_number)
);

ALTER TABLE public.quiz_attempts ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.quiz_attempt_answers (
  attempt_id uuid NOT NULL REFERENCES public.quiz_attempts(id) ON DELETE CASCADE,
  question_id uuid NOT NULL
    REFERENCES public.quiz_questions(id) ON DELETE RESTRICT,
  answer jsonb NOT NULL,
  answered_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  is_correct boolean,
  points_earned integer,
  CONSTRAINT quiz_attempt_answers_pkey PRIMARY KEY (attempt_id, question_id),
  CONSTRAINT quiz_attempt_answers_answer_object_check
    CHECK (pg_catalog.jsonb_typeof(answer) = 'object'),
  CONSTRAINT quiz_attempt_answers_result_pair_check
    CHECK (
      (is_correct IS NULL AND points_earned IS NULL)
      OR (is_correct IS NOT NULL AND points_earned >= 0)
    )
);

ALTER TABLE public.quiz_attempt_answers ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.chapter_progress (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  chapter_id uuid NOT NULL REFERENCES public.chapters(id) ON DELETE RESTRICT,
  theory_percent numeric(5,2) NOT NULL DEFAULT 0,
  exercise_percent numeric(5,2) NOT NULL DEFAULT 0,
  quiz_percent numeric(5,2) NOT NULL DEFAULT 0,
  overall_percent numeric(5,2) NOT NULL DEFAULT 0,
  first_completed_at timestamptz,
  completed_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT chapter_progress_pkey PRIMARY KEY (user_id, chapter_id),
  CONSTRAINT chapter_progress_theory_percent_check
    CHECK (theory_percent BETWEEN 0 AND 100),
  CONSTRAINT chapter_progress_exercise_percent_check
    CHECK (exercise_percent BETWEEN 0 AND 100),
  CONSTRAINT chapter_progress_quiz_percent_check
    CHECK (quiz_percent BETWEEN 0 AND 100),
  CONSTRAINT chapter_progress_overall_percent_check
    CHECK (overall_percent BETWEEN 0 AND 100),
  CONSTRAINT chapter_progress_completion_order_check
    CHECK (
      first_completed_at IS NULL
      OR completed_at IS NULL
      OR first_completed_at <= completed_at
    )
);

ALTER TABLE public.chapter_progress ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.theory_section_completions OWNER TO coditza_owner;
ALTER TABLE public.exercise_attempts OWNER TO coditza_owner;
ALTER TABLE public.quiz_attempts OWNER TO coditza_owner;
ALTER TABLE public.quiz_attempt_answers OWNER TO coditza_owner;
ALTER TABLE public.chapter_progress OWNER TO coditza_owner;

SET LOCAL ROLE coditza_owner;

CREATE INDEX theory_section_completions_section_user_idx
  ON public.theory_section_completions (theory_section_id, user_id);
CREATE INDEX theory_section_completions_user_completed_id_idx
  ON public.theory_section_completions (user_id, completed_at DESC, theory_section_id);
CREATE INDEX exercise_attempts_exercise_id_idx
  ON public.exercise_attempts (exercise_id);
CREATE INDEX exercise_attempts_user_exercise_submitted_id_idx
  ON public.exercise_attempts (user_id, exercise_id, submitted_at DESC, id);
CREATE INDEX quiz_attempts_quiz_id_idx ON public.quiz_attempts (quiz_id);
CREATE UNIQUE INDEX quiz_attempts_one_active_per_user_quiz_idx
  ON public.quiz_attempts (user_id, quiz_id)
  WHERE status = 'in_progress'::public.quiz_attempt_status;
CREATE INDEX quiz_attempts_user_history_idx
  ON public.quiz_attempts (
    user_id,
    (COALESCE(submitted_at, started_at)) DESC,
    id DESC
  );
CREATE INDEX quiz_attempts_expiry_worker_idx
  ON public.quiz_attempts (expires_at, id)
  WHERE status = 'in_progress'::public.quiz_attempt_status
    AND expires_at IS NOT NULL;
CREATE INDEX quiz_attempt_answers_question_id_idx
  ON public.quiz_attempt_answers (question_id);
CREATE INDEX chapter_progress_chapter_user_idx
  ON public.chapter_progress (chapter_id, user_id);

REVOKE ALL ON TABLE public.theory_section_completions,
  public.exercise_attempts,
  public.quiz_attempts,
  public.quiz_attempt_answers,
  public.chapter_progress
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE REFERENCES ON TABLE public.theory_sections,
  public.exercises,
  public.quizzes,
  public.quiz_questions,
  public.chapters
  FROM postgres;
REVOKE USAGE ON TYPE public.quiz_attempt_status FROM postgres;

RESET ROLE;

COMMIT;
