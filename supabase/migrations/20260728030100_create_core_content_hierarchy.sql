-- SUP-DATA-001: core module, chapter, and theory-section hierarchy only.
-- No assessment, workflow, policy, generated-type, or API surface belongs here.
BEGIN;

SET LOCAL ROLE coditza_owner;

CREATE TABLE public.modules (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  slug text NOT NULL,
  title text NOT NULL,
  description_markdown text NOT NULL,
  position integer NOT NULL,
  status public.content_status NOT NULL DEFAULT 'draft'::public.content_status,
  row_version integer NOT NULL DEFAULT 1,
  published_at timestamptz,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT modules_slug_check CHECK (private.is_valid_slug(slug)),
  CONSTRAINT modules_title_check CHECK (
    title = pg_catalog.btrim(title)
    AND pg_catalog.char_length(title) BETWEEN 1 AND 160
  ),
  CONSTRAINT modules_description_markdown_check CHECK (
    pg_catalog.char_length(description_markdown) BETWEEN 1 AND 10000
    AND description_markdown OPERATOR(pg_catalog.~) '[^[:space:]]'
  ),
  CONSTRAINT modules_position_check CHECK (position >= 0),
  CONSTRAINT modules_row_version_check CHECK (row_version > 0),
  CONSTRAINT modules_lifecycle_timestamp_check CHECK (
    (status <> 'draft'::public.content_status OR published_at IS NULL)
    AND (status <> 'published'::public.content_status OR published_at IS NOT NULL)
  ),
  CONSTRAINT modules_slug_key UNIQUE (slug),
  CONSTRAINT modules_position_key UNIQUE (position) DEFERRABLE INITIALLY IMMEDIATE
);

ALTER TABLE public.modules ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.chapters (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  module_id uuid NOT NULL REFERENCES public.modules(id) ON DELETE RESTRICT,
  slug text NOT NULL,
  title text NOT NULL,
  summary_markdown text NOT NULL,
  position integer NOT NULL,
  estimated_minutes integer NOT NULL,
  status public.content_status NOT NULL DEFAULT 'draft'::public.content_status,
  row_version integer NOT NULL DEFAULT 1,
  published_at timestamptz,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT chapters_slug_check CHECK (private.is_valid_slug(slug)),
  CONSTRAINT chapters_title_check CHECK (
    title = pg_catalog.btrim(title)
    AND pg_catalog.char_length(title) BETWEEN 1 AND 160
  ),
  CONSTRAINT chapters_summary_markdown_check CHECK (
    pg_catalog.char_length(summary_markdown) BETWEEN 1 AND 5000
    AND summary_markdown OPERATOR(pg_catalog.~) '[^[:space:]]'
  ),
  CONSTRAINT chapters_position_check CHECK (position >= 0),
  CONSTRAINT chapters_estimated_minutes_check CHECK (
    estimated_minutes BETWEEN 1 AND 1440
  ),
  CONSTRAINT chapters_row_version_check CHECK (row_version > 0),
  CONSTRAINT chapters_lifecycle_timestamp_check CHECK (
    (status <> 'draft'::public.content_status OR published_at IS NULL)
    AND (status <> 'published'::public.content_status OR published_at IS NOT NULL)
  ),
  CONSTRAINT chapters_module_slug_key UNIQUE (module_id, slug),
  CONSTRAINT chapters_module_position_key
    UNIQUE (module_id, position) DEFERRABLE INITIALLY IMMEDIATE
);

ALTER TABLE public.chapters ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.theory_sections (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  chapter_id uuid NOT NULL REFERENCES public.chapters(id) ON DELETE RESTRICT,
  title text NOT NULL,
  body_markdown text NOT NULL,
  position integer NOT NULL,
  estimated_minutes integer NOT NULL,
  status public.content_status NOT NULL DEFAULT 'draft'::public.content_status,
  row_version integer NOT NULL DEFAULT 1,
  published_at timestamptz,
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  updated_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT theory_sections_title_check CHECK (
    title = pg_catalog.btrim(title)
    AND pg_catalog.char_length(title) BETWEEN 1 AND 160
  ),
  CONSTRAINT theory_sections_body_markdown_check CHECK (
    pg_catalog.char_length(body_markdown) BETWEEN 1 AND 100000
    AND body_markdown OPERATOR(pg_catalog.~) '[^[:space:]]'
  ),
  CONSTRAINT theory_sections_position_check CHECK (position >= 0),
  CONSTRAINT theory_sections_estimated_minutes_check CHECK (
    estimated_minutes BETWEEN 1 AND 1440
  ),
  CONSTRAINT theory_sections_row_version_check CHECK (row_version > 0),
  CONSTRAINT theory_sections_lifecycle_timestamp_check CHECK (
    (status <> 'draft'::public.content_status OR published_at IS NULL)
    AND (status <> 'published'::public.content_status OR published_at IS NOT NULL)
  ),
  CONSTRAINT theory_sections_chapter_position_key
    UNIQUE (chapter_id, position) DEFERRABLE INITIALLY IMMEDIATE
);

ALTER TABLE public.theory_sections ENABLE ROW LEVEL SECURITY;

CREATE INDEX modules_status_position_id_idx
  ON public.modules (status, position, id);
CREATE INDEX modules_created_by_idx ON public.modules (created_by);
CREATE INDEX modules_updated_by_idx ON public.modules (updated_by);

CREATE INDEX chapters_module_status_position_id_idx
  ON public.chapters (module_id, status, position, id);
CREATE INDEX chapters_created_by_idx ON public.chapters (created_by);
CREATE INDEX chapters_updated_by_idx ON public.chapters (updated_by);

CREATE INDEX theory_sections_chapter_status_position_id_idx
  ON public.theory_sections (chapter_id, status, position, id);
CREATE INDEX theory_sections_created_by_idx ON public.theory_sections (created_by);
CREATE INDEX theory_sections_updated_by_idx ON public.theory_sections (updated_by);

CREATE TRIGGER modules_enforce_authored_lifecycle
BEFORE INSERT OR UPDATE ON public.modules
FOR EACH ROW
EXECUTE FUNCTION private.enforce_authored_row_lifecycle();

CREATE TRIGGER modules_set_updated_at
BEFORE UPDATE ON public.modules
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER chapters_enforce_authored_lifecycle
BEFORE INSERT OR UPDATE ON public.chapters
FOR EACH ROW
EXECUTE FUNCTION private.enforce_authored_row_lifecycle();

CREATE TRIGGER chapters_set_updated_at
BEFORE UPDATE ON public.chapters
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

CREATE TRIGGER theory_sections_enforce_authored_lifecycle
BEFORE INSERT OR UPDATE ON public.theory_sections
FOR EACH ROW
EXECUTE FUNCTION private.enforce_authored_row_lifecycle();

CREATE TRIGGER theory_sections_set_updated_at
BEFORE UPDATE ON public.theory_sections
FOR EACH ROW
EXECUTE FUNCTION private.set_updated_at();

REVOKE ALL ON TABLE public.modules, public.chapters, public.theory_sections
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

RESET ROLE;

COMMIT;
