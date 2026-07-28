BEGIN;

GRANT USAGE ON SCHEMA extensions TO coditza_owner;

SELECT extensions.plan(34);

SELECT extensions.ok(
  pg_catalog.to_regclass('public.modules') IS NOT NULL
    AND pg_catalog.to_regclass('public.chapters') IS NOT NULL
    AND pg_catalog.to_regclass('public.theory_sections') IS NOT NULL,
  'the approved core hierarchy tables exist'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
      = ARRAY[
        'id',
        'slug',
        'title',
        'description_markdown',
        'position',
        'status',
        'row_version',
        'published_at',
        'created_by',
        'updated_by',
        'created_at',
        'updated_at'
      ]::text[]
    FROM pg_catalog.pg_attribute AS attribute_entry
    WHERE attribute_entry.attrelid = 'public.modules'::pg_catalog.regclass
      AND attribute_entry.attnum > 0
      AND NOT attribute_entry.attisdropped
  ),
  'modules has exactly the approved core columns'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
      = ARRAY[
        'id',
        'module_id',
        'slug',
        'title',
        'summary_markdown',
        'position',
        'estimated_minutes',
        'status',
        'row_version',
        'published_at',
        'created_by',
        'updated_by',
        'created_at',
        'updated_at'
      ]::text[]
    FROM pg_catalog.pg_attribute AS attribute_entry
    WHERE attribute_entry.attrelid = 'public.chapters'::pg_catalog.regclass
      AND attribute_entry.attnum > 0
      AND NOT attribute_entry.attisdropped
  ),
  'chapters has exactly the approved core columns'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(attribute_entry.attname::text ORDER BY attribute_entry.attnum)
      = ARRAY[
        'id',
        'chapter_id',
        'title',
        'body_markdown',
        'position',
        'estimated_minutes',
        'status',
        'row_version',
        'published_at',
        'created_by',
        'updated_by',
        'created_at',
        'updated_at'
      ]::text[]
    FROM pg_catalog.pg_attribute AS attribute_entry
    WHERE attribute_entry.attrelid = 'public.theory_sections'::pg_catalog.regclass
      AND attribute_entry.attnum > 0
      AND NOT attribute_entry.attisdropped
  ),
  'theory_sections has exactly the approved core columns'
);

SELECT extensions.ok(
  (
    SELECT count(*) = 3
      AND pg_catalog.bool_and(relation_entry.relowner = 'coditza_owner'::pg_catalog.regrole)
    FROM pg_catalog.pg_class AS relation_entry
    WHERE relation_entry.oid IN (
      'public.modules'::pg_catalog.regclass,
      'public.chapters'::pg_catalog.regclass,
      'public.theory_sections'::pg_catalog.regclass
    )
  ),
  'all core hierarchy tables are owned by coditza_owner'
);

SELECT extensions.ok(
  (
    SELECT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_attribute AS attribute_entry
      WHERE attribute_entry.attrelid = 'public.modules'::pg_catalog.regclass
        AND attribute_entry.attname = 'id'
        AND attribute_entry.atttypid = 'uuid'::pg_catalog.regtype
        AND attribute_entry.attnotnull
        AND attribute_entry.atthasdef
    )
      AND EXISTS (
        SELECT 1
        FROM pg_catalog.pg_attribute AS attribute_entry
        WHERE attribute_entry.attrelid = 'public.chapters'::pg_catalog.regclass
          AND attribute_entry.attname = 'module_id'
          AND attribute_entry.atttypid = 'uuid'::pg_catalog.regtype
          AND attribute_entry.attnotnull
      )
      AND EXISTS (
        SELECT 1
        FROM pg_catalog.pg_attribute AS attribute_entry
        WHERE attribute_entry.attrelid = 'public.theory_sections'::pg_catalog.regclass
          AND attribute_entry.attname = 'chapter_id'
          AND attribute_entry.atttypid = 'uuid'::pg_catalog.regtype
          AND attribute_entry.attnotnull
      )
      AND (
        SELECT count(*) = 3
          AND pg_catalog.bool_and(attribute_entry.atttypid = 'public.content_status'::pg_catalog.regtype)
          AND pg_catalog.bool_and(attribute_entry.attnotnull)
          AND pg_catalog.bool_and(attribute_entry.atthasdef)
        FROM pg_catalog.pg_attribute AS attribute_entry
        WHERE (attribute_entry.attrelid, attribute_entry.attname) IN (
          ('public.modules'::pg_catalog.regclass, 'status'),
          ('public.chapters'::pg_catalog.regclass, 'status'),
          ('public.theory_sections'::pg_catalog.regclass, 'status')
        )
      )
  ),
  'core IDs, parent IDs, and lifecycle status columns use the approved types and defaults'
);

SELECT extensions.ok(
  (
    SELECT count(*) = 8
      AND pg_catalog.bool_and(
        (
          constraint_entry.conrelid = 'public.chapters'::pg_catalog.regclass
          AND constraint_entry.confrelid = 'public.modules'::pg_catalog.regclass
          AND constraint_entry.confdeltype = 'r'
        )
        OR (
          constraint_entry.conrelid = 'public.theory_sections'::pg_catalog.regclass
          AND constraint_entry.confrelid = 'public.chapters'::pg_catalog.regclass
          AND constraint_entry.confdeltype = 'r'
        )
        OR (
          constraint_entry.conrelid IN (
            'public.modules'::pg_catalog.regclass,
            'public.chapters'::pg_catalog.regclass,
            'public.theory_sections'::pg_catalog.regclass
          )
          AND constraint_entry.confrelid = 'public.profiles'::pg_catalog.regclass
          AND constraint_entry.confdeltype = 'n'
        )
      )
    FROM pg_catalog.pg_constraint AS constraint_entry
    WHERE constraint_entry.contype = 'f'
      AND constraint_entry.conrelid IN (
        'public.modules'::pg_catalog.regclass,
        'public.chapters'::pg_catalog.regclass,
        'public.theory_sections'::pg_catalog.regclass
      )
  ),
  'parent foreign keys restrict deletion and every audit foreign key sets null'
);

SELECT extensions.ok(
  (
    SELECT count(*) = 3
      AND pg_catalog.bool_and(constraint_entry.condeferrable)
      AND NOT pg_catalog.bool_or(constraint_entry.condeferred)
    FROM pg_catalog.pg_constraint AS constraint_entry
    WHERE constraint_entry.conname IN (
      'modules_position_key',
      'chapters_module_position_key',
      'theory_sections_chapter_position_key'
    )
      AND constraint_entry.contype = 'u'
  ),
  'all sibling-position constraints are deferrable and initially immediate'
);

SELECT extensions.ok(
  pg_catalog.to_regclass('public.modules_status_position_id_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.modules_created_by_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.modules_updated_by_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.chapters_module_status_position_id_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.chapters_created_by_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.chapters_updated_by_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.theory_sections_chapter_status_position_id_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.theory_sections_created_by_idx') IS NOT NULL
    AND pg_catalog.to_regclass('public.theory_sections_updated_by_idx') IS NOT NULL,
  'the approved list, parent-leading, and actor indexes exist'
);

SELECT extensions.ok(
  (
    SELECT count(*) = 3
      AND pg_catalog.bool_and(relation_entry.relrowsecurity)
      AND NOT pg_catalog.bool_or(relation_entry.relforcerowsecurity)
    FROM pg_catalog.pg_class AS relation_entry
    WHERE relation_entry.oid IN (
      'public.modules'::pg_catalog.regclass,
      'public.chapters'::pg_catalog.regclass,
      'public.theory_sections'::pg_catalog.regclass
    )
  )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_policy AS policy_entry
      WHERE policy_entry.polrelid IN (
        'public.modules'::pg_catalog.regclass,
        'public.chapters'::pg_catalog.regclass,
        'public.theory_sections'::pg_catalog.regclass
      )
    ),
  'core tables have RLS enabled without force or direct user policies'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    CROSS JOIN (
      VALUES (
        'public.modules'::pg_catalog.regclass
      ), (
        'public.chapters'::pg_catalog.regclass
      ), (
        'public.theory_sections'::pg_catalog.regclass
      )
    ) AS core_table(table_oid)
    WHERE pg_catalog.has_table_privilege(runtime_role.rolname, core_table.table_oid, 'SELECT')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, core_table.table_oid, 'INSERT')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, core_table.table_oid, 'UPDATE')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, core_table.table_oid, 'DELETE')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, core_table.table_oid, 'TRUNCATE')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, core_table.table_oid, 'REFERENCES')
      OR pg_catalog.has_table_privilege(runtime_role.rolname, core_table.table_oid, 'TRIGGER')
  )
    AND NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_class AS relation_entry
    CROSS JOIN LATERAL pg_catalog.unnest(relation_entry.relacl) AS acl_entry(item)
    WHERE relation_entry.oid IN (
      'public.modules'::pg_catalog.regclass,
      'public.chapters'::pg_catalog.regclass,
      'public.theory_sections'::pg_catalog.regclass
    )
      AND acl_entry.item::text OPERATOR(pg_catalog.~)
        '^(postgres|anon|authenticated|service_role|authenticator)='
  ),
  'runtime roles lack direct core-table privileges and no explicit migration/runtime table grants remain'
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
        'private.enforce_authored_row_lifecycle()'::pg_catalog.regprocedure,
        'EXECUTE'
      )
  )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_namespace AS namespace_entry
      CROSS JOIN LATERAL pg_catalog.unnest(namespace_entry.nspacl) AS acl_entry(item)
      WHERE namespace_entry.nspname = 'private'
        AND acl_entry.item::text OPERATOR(pg_catalog.~)
          '^(postgres|anon|authenticated|service_role|authenticator)='
    )
    AND NOT EXISTS (
      SELECT 1
      FROM pg_catalog.pg_proc AS procedure_entry
      CROSS JOIN LATERAL pg_catalog.unnest(procedure_entry.proacl) AS acl_entry(item)
      WHERE procedure_entry.oid = 'private.enforce_authored_row_lifecycle()'::pg_catalog.regprocedure
        AND acl_entry.item::text OPERATOR(pg_catalog.~)
          '^(postgres|anon|authenticated|service_role|authenticator)='
    ),
  'runtime roles cannot use the private helper and no explicit migration/runtime helper grants remain'
);

SELECT extensions.ok(
  (
    SELECT procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
      AND NOT procedure_entry.prosecdef
      AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid = 'private.enforce_authored_row_lifecycle()'::pg_catalog.regprocedure
  ),
  'the core lifecycle helper is owner-controlled SECURITY INVOKER with an empty search path'
);

SELECT extensions.ok(
  (
    SELECT count(*) = 6
      AND pg_catalog.bool_and(trigger_entry.tgfoid IN (
        'private.enforce_authored_row_lifecycle()'::pg_catalog.regprocedure,
        'private.set_updated_at()'::pg_catalog.regprocedure
      ))
      AND pg_catalog.bool_and((trigger_entry.tgtype::integer & 1) = 1)
      AND pg_catalog.bool_and((trigger_entry.tgtype::integer & 2) = 2)
      AND pg_catalog.bool_and((trigger_entry.tgtype::integer & 16) = 16)
      AND count(*) FILTER (
        WHERE trigger_entry.tgfoid =
          'private.enforce_authored_row_lifecycle()'::pg_catalog.regprocedure
          AND (trigger_entry.tgtype::integer & 4) = 4
      ) = 3
      AND count(*) FILTER (
        WHERE trigger_entry.tgfoid = 'private.set_updated_at()'::pg_catalog.regprocedure
          AND (trigger_entry.tgtype::integer & 4) = 0
      ) = 3
    FROM pg_catalog.pg_trigger AS trigger_entry
    WHERE NOT trigger_entry.tgisinternal
      AND trigger_entry.tgrelid IN (
        'public.modules'::pg_catalog.regclass,
        'public.chapters'::pg_catalog.regclass,
        'public.theory_sections'::pg_catalog.regclass
      )
  ),
  'each core table has exact private lifecycle INSERT/UPDATE and timestamp UPDATE triggers'
);

SET LOCAL ROLE coditza_owner;

INSERT INTO public.modules (
  slug,
  title,
  description_markdown,
  position
)
VALUES (
  'defaulted-module',
  'Defaulted module',
  'A valid module description.',
  1
);

INSERT INTO public.modules (
  id,
  slug,
  title,
  description_markdown,
  position
)
VALUES (
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'base-module',
  'Base module',
  'Base module description.',
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
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
  'base-chapter',
  'Base chapter',
  'Base chapter summary.',
  0,
  20
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
  'cccccccc-cccc-cccc-cccc-cccccccccccc',
  'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  'Base theory section',
  'Base theory body.',
  0,
  10
);

RESET ROLE;

SELECT extensions.ok(
  (
    SELECT id IS NOT NULL
      AND status = 'draft'::public.content_status
      AND row_version = 1
      AND published_at IS NULL
      AND created_at = updated_at
    FROM public.modules
    WHERE slug = 'defaulted-module'
  ),
  'a core module receives generated UUID, draft, version, publication, and timestamp defaults without an update'
);

SET LOCAL ROLE coditza_owner;

DO $invalid_module_values$
BEGIN
  BEGIN
    INSERT INTO public.modules (slug, title, description_markdown, position)
    VALUES ('Invalid-slug', 'Valid title', 'Valid description', 3);
    RAISE EXCEPTION 'invalid module slug must fail';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.modules (slug, title, description_markdown, position)
    VALUES ('untrimmed-module', ' Untrimmed title', 'Valid description', 3);
    RAISE EXCEPTION 'untrimmed module title must fail';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.modules (slug, title, description_markdown, position)
    VALUES ('blank-module', 'Valid title', '   ', 3);
    RAISE EXCEPTION 'blank module markdown must fail';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.modules (slug, title, description_markdown, position)
    VALUES ('long-module', 'Valid title', pg_catalog.repeat('x', 10001), 3);
    RAISE EXCEPTION 'oversized module markdown must fail';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.modules (slug, title, description_markdown, position)
    VALUES ('negative-position-module', 'Valid title', 'Valid description', -1);
    RAISE EXCEPTION 'negative module position must fail';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.modules (
      slug,
      title,
      description_markdown,
      position,
      row_version
    )
    VALUES ('invalid-version-module', 'Valid title', 'Valid description', 3, 0);
    RAISE EXCEPTION 'zero module row version must fail';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;
END;
$invalid_module_values$;

DO $invalid_chapter_values$
BEGIN
  BEGIN
    INSERT INTO public.chapters (
      module_id, slug, title, summary_markdown, position, estimated_minutes
    )
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'Invalid-slug',
      'Valid title',
      'Valid summary',
      1,
      20
    );
    RAISE EXCEPTION 'invalid chapter slug must fail';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.chapters (
      module_id, slug, title, summary_markdown, position, estimated_minutes
    )
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'long-chapter',
      pg_catalog.repeat('x', 161),
      'Valid summary',
      1,
      20
    );
    RAISE EXCEPTION 'oversized chapter title must fail';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.chapters (
      module_id, slug, title, summary_markdown, position, estimated_minutes
    )
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'blank-summary-chapter',
      'Valid title',
      ' ',
      1,
      20
    );
    RAISE EXCEPTION 'blank chapter summary must fail';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.chapters (
      module_id, slug, title, summary_markdown, position, estimated_minutes
    )
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'invalid-minutes-chapter',
      'Valid title',
      'Valid summary',
      -1,
      0
    );
    RAISE EXCEPTION 'negative chapter position and zero minutes must fail';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END;
$invalid_chapter_values$;

DO $invalid_theory_values$
BEGIN
  BEGIN
    INSERT INTO public.theory_sections (
      chapter_id, title, body_markdown, position, estimated_minutes
    )
    VALUES (
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      ' ',
      'Valid body',
      1,
      10
    );
    RAISE EXCEPTION 'blank theory title must fail';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.theory_sections (
      chapter_id, title, body_markdown, position, estimated_minutes
    )
    VALUES (
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'Valid title',
      pg_catalog.repeat('x', 100001),
      1,
      10
    );
    RAISE EXCEPTION 'oversized theory body must fail';
  EXCEPTION WHEN check_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.theory_sections (
      chapter_id, title, body_markdown, position, estimated_minutes
    )
    VALUES (
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'Invalid time',
      'Valid body',
      -1,
      1441
    );
    RAISE EXCEPTION 'negative theory position and oversized minutes must fail';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END;
$invalid_theory_values$;

DO $invalid_lifecycle_values$
BEGIN
  BEGIN
    INSERT INTO public.modules (
      slug, title, description_markdown, position, status, published_at
    )
    VALUES (
      'initially-published-module',
      'Valid title',
      'Valid description',
      3,
      'published',
      '2026-01-01 00:00:00+00'::pg_catalog.timestamptz
    );
    RAISE EXCEPTION 'new published module must fail';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;

  BEGIN
    INSERT INTO public.modules (
      slug, title, description_markdown, position, published_at
    )
    VALUES (
      'draft-with-time',
      'Valid title',
      'Valid description',
      3,
      '2026-01-01 00:00:00+00'::pg_catalog.timestamptz
    );
    RAISE EXCEPTION 'new draft module with timestamp must fail';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;

  BEGIN
    INSERT INTO public.modules (
      slug, title, description_markdown, position, status
    )
    VALUES ('initially-archived-module', 'Valid title', 'Valid description', 3, 'archived');
    RAISE EXCEPTION 'new archived module must fail';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;

  BEGIN
    INSERT INTO public.modules (
      slug, title, description_markdown, position, row_version
    )
    VALUES ('initially-versioned-module', 'Valid title', 'Valid description', 3, 2);
    RAISE EXCEPTION 'new non-version-one module must fail';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;
END;
$invalid_lifecycle_values$;

RESET ROLE;

SELECT extensions.ok(TRUE, 'module slug, text, markdown, position, and version bounds reject invalid values');
SELECT extensions.ok(TRUE, 'chapter slug, text, summary, position, and estimated-minute bounds reject invalid values');
SELECT extensions.ok(TRUE, 'theory title, body, position, and estimated-minute bounds reject invalid values');
SELECT extensions.ok(TRUE, 'new authored content must begin as draft with no publication timestamp and row version one');

SET LOCAL ROLE coditza_owner;

DO $slug_uniqueness$
BEGIN
  BEGIN
    INSERT INTO public.modules (slug, title, description_markdown, position)
    VALUES ('base-module', 'Duplicate module', 'Duplicate description', 3);
    RAISE EXCEPTION 'duplicate global module slug must fail';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.chapters (
      module_id, slug, title, summary_markdown, position, estimated_minutes
    )
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'base-chapter',
      'Duplicate chapter',
      'Duplicate summary',
      1,
      20
    );
    RAISE EXCEPTION 'duplicate scoped chapter slug must fail';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
END;
$slug_uniqueness$;

INSERT INTO public.modules (
  id, slug, title, description_markdown, position
)
VALUES (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'second-module',
  'Second module',
  'Second module description.',
  4
);

INSERT INTO public.chapters (
  module_id, slug, title, summary_markdown, position, estimated_minutes
)
VALUES (
  'dddddddd-dddd-dddd-dddd-dddddddddddd',
  'base-chapter',
  'Scoped slug reuse',
  'This slug is valid under another module.',
  0,
  20
);

DO $position_uniqueness$
BEGIN
  BEGIN
    INSERT INTO public.modules (slug, title, description_markdown, position)
    VALUES ('duplicate-module-position', 'Duplicate module position', 'Valid description', 2);
    RAISE EXCEPTION 'duplicate module position must fail';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.chapters (
      module_id, slug, title, summary_markdown, position, estimated_minutes
    )
    VALUES (
      'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
      'duplicate-chapter-position',
      'Duplicate chapter position',
      'Valid summary',
      0,
      20
    );
    RAISE EXCEPTION 'duplicate chapter position must fail';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  BEGIN
    INSERT INTO public.theory_sections (
      chapter_id, title, body_markdown, position, estimated_minutes
    )
    VALUES (
      'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
      'Duplicate theory position',
      'Valid body',
      0,
      10
    );
    RAISE EXCEPTION 'duplicate theory position must fail';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
END;
$position_uniqueness$;

RESET ROLE;

SELECT extensions.ok(TRUE, 'module slugs are global while chapter slugs are unique only within their module');
SELECT extensions.ok(TRUE, 'all three sibling-position scopes reject immediate duplicates');

SET LOCAL ROLE coditza_owner;

DO $published_timestamp_update$
BEGIN
  BEGIN
    UPDATE public.modules
    SET status = 'published'::public.content_status
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    RAISE EXCEPTION 'publishing without a timestamp must fail';
  EXCEPTION WHEN check_violation THEN NULL;
  END;
END;
$published_timestamp_update$;

UPDATE public.modules
SET title = 'Updated base module',
    row_version = 999
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

RESET ROLE;

SELECT extensions.ok(
  (
    SELECT title = 'Updated base module'
      AND row_version = 2
      AND updated_at > created_at
    FROM public.modules
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  ),
  'an update advances updated_at and increments row_version exactly once despite a supplied version'
);

SET LOCAL ROLE coditza_owner;

WITH changed AS (
  UPDATE public.modules
  SET title = 'Compare and swap succeeds'
  WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    AND row_version = 2
  RETURNING id
)
SELECT extensions.ok(
  (SELECT count(*) = 1 FROM changed),
  'the expected row version permits one owner-side compare-and-swap update'
);

WITH stale AS (
  UPDATE public.modules
  SET title = 'Stale write must not apply'
  WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
    AND row_version = 2
  RETURNING id
)
SELECT extensions.ok(
  (SELECT count(*) = 0 FROM stale),
  'a stale expected row version produces no update'
);

UPDATE public.modules
SET status = 'published'::public.content_status,
    published_at = '2026-01-02 00:00:00+00'::pg_catalog.timestamptz
WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

DO $irreversible_lifecycle$
BEGIN
  BEGIN
    UPDATE public.modules
    SET status = 'draft'::public.content_status,
        published_at = NULL
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    RAISE EXCEPTION 'published content must not return to draft';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;

  UPDATE public.modules
  SET status = 'archived'::public.content_status
  WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';

  BEGIN
    UPDATE public.modules
    SET status = 'published'::public.content_status
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    RAISE EXCEPTION 'archived content must not reopen';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;

  BEGIN
    UPDATE public.modules
    SET published_at = '2026-01-03 00:00:00+00'::pg_catalog.timestamptz
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    RAISE EXCEPTION 'first publication timestamp must remain immutable';
  EXCEPTION WHEN raise_exception THEN NULL;
  END;
END;
$irreversible_lifecycle$;

INSERT INTO public.modules (
  id, slug, title, description_markdown, position
)
VALUES (
  'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
  'never-published-module',
  'Never published module',
  'Never published module description.',
  5
);

UPDATE public.modules
SET status = 'archived'::public.content_status
WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';

RESET ROLE;

SELECT extensions.ok(
  (
    SELECT status = 'archived'::public.content_status
      AND published_at = '2026-01-02 00:00:00+00'::pg_catalog.timestamptz
    FROM public.modules
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
  )
    AND (
      SELECT status = 'archived'::public.content_status
        AND published_at IS NULL
      FROM public.modules
      WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'
    ),
  'publication history is retained after archive while never-published archive remains timestamp-null'
);

SELECT extensions.ok(TRUE, 'published-to-draft, archived reopening, and publication-timestamp rewriting are rejected');

SET LOCAL ROLE coditza_owner;

DO $restricted_parent_deletes$
BEGIN
  BEGIN
    DELETE FROM public.modules
    WHERE id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa';
    RAISE EXCEPTION 'module with chapter must not delete';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;

  BEGIN
    DELETE FROM public.chapters
    WHERE id = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb';
    RAISE EXCEPTION 'chapter with theory must not delete';
  EXCEPTION WHEN foreign_key_violation THEN NULL;
  END;
END;
$restricted_parent_deletes$;

RESET ROLE;

SELECT extensions.ok(TRUE, 'module and chapter parent deletion is restricted while authored descendants exist');

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
VALUES (
  'ffffffff-ffff-ffff-ffff-ffffffffffff',
  'authenticated',
  'authenticated',
  'core-audit-profile@profiles.invalid',
  '{}'::jsonb,
  '{"displayName":"Core Audit"}'::jsonb,
  pg_catalog.now(),
  pg_catalog.now()
);

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
  '12121212-1212-1212-1212-121212121212',
  'profile-audit-module',
  'Profile audit module',
  'Profile audit module description.',
  6,
  'ffffffff-ffff-ffff-ffff-ffffffffffff',
  'ffffffff-ffff-ffff-ffff-ffffffffffff'
);

RESET ROLE;

DELETE FROM auth.users
WHERE id = 'ffffffff-ffff-ffff-ffff-ffffffffffff';

SELECT extensions.ok(
  (
    SELECT created_by IS NULL
      AND updated_by IS NULL
    FROM public.modules
    WHERE id = '12121212-1212-1212-1212-121212121212'
  )
    AND NOT EXISTS (
      SELECT 1
      FROM public.profiles
      WHERE id = 'ffffffff-ffff-ffff-ffff-ffffffffffff'
    ),
  'deleting an audit profile preserves content and nulls both audit foreign keys'
);

SET LOCAL ROLE coditza_owner;

INSERT INTO public.modules (id, slug, title, description_markdown, position)
VALUES
  ('13131313-1313-1313-1313-131313131313', 'reorder-module-one', 'Reorder module one', 'First reorder description.', 100),
  ('14141414-1414-1414-1414-141414141414', 'reorder-module-two', 'Reorder module two', 'Second reorder description.', 101),
  ('15151515-1515-1515-1515-151515151515', 'reorder-module-three', 'Reorder module three', 'Third reorder description.', 102);

SET CONSTRAINTS modules_position_key DEFERRED;
UPDATE public.modules
SET position = CASE id
  WHEN '13131313-1313-1313-1313-131313131313'::uuid THEN 101
  WHEN '14141414-1414-1414-1414-141414141414'::uuid THEN 102
  WHEN '15151515-1515-1515-1515-151515151515'::uuid THEN 100
END
WHERE id IN (
  '13131313-1313-1313-1313-131313131313',
  '14141414-1414-1414-1414-141414141414',
  '15151515-1515-1515-1515-151515151515'
);
SET CONSTRAINTS modules_position_key IMMEDIATE;

INSERT INTO public.chapters (
  id, module_id, slug, title, summary_markdown, position, estimated_minutes
)
VALUES
  ('16161616-1616-1616-1616-161616161616', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'reorder-chapter-one', 'Reorder chapter one', 'First chapter reorder summary.', 100, 20),
  ('17171717-1717-1717-1717-171717171717', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'reorder-chapter-two', 'Reorder chapter two', 'Second chapter reorder summary.', 101, 20),
  ('18181818-1818-1818-1818-181818181818', 'dddddddd-dddd-dddd-dddd-dddddddddddd', 'reorder-chapter-three', 'Reorder chapter three', 'Third chapter reorder summary.', 102, 20);

SET CONSTRAINTS chapters_module_position_key DEFERRED;
UPDATE public.chapters
SET position = CASE id
  WHEN '16161616-1616-1616-1616-161616161616'::uuid THEN 101
  WHEN '17171717-1717-1717-1717-171717171717'::uuid THEN 102
  WHEN '18181818-1818-1818-1818-181818181818'::uuid THEN 100
END
WHERE id IN (
  '16161616-1616-1616-1616-161616161616',
  '17171717-1717-1717-1717-171717171717',
  '18181818-1818-1818-1818-181818181818'
);
SET CONSTRAINTS chapters_module_position_key IMMEDIATE;

INSERT INTO public.theory_sections (
  id, chapter_id, title, body_markdown, position, estimated_minutes
)
VALUES
  ('19191919-1919-1919-1919-191919191919', '16161616-1616-1616-1616-161616161616', 'Reorder theory one', 'First theory reorder body.', 100, 10),
  ('20202020-2020-2020-2020-202020202020', '16161616-1616-1616-1616-161616161616', 'Reorder theory two', 'Second theory reorder body.', 101, 10),
  ('21212121-2121-2121-2121-212121212121', '16161616-1616-1616-1616-161616161616', 'Reorder theory three', 'Third theory reorder body.', 102, 10);

SET CONSTRAINTS theory_sections_chapter_position_key DEFERRED;
UPDATE public.theory_sections
SET position = CASE id
  WHEN '19191919-1919-1919-1919-191919191919'::uuid THEN 101
  WHEN '20202020-2020-2020-2020-202020202020'::uuid THEN 102
  WHEN '21212121-2121-2121-2121-212121212121'::uuid THEN 100
END
WHERE id IN (
  '19191919-1919-1919-1919-191919191919',
  '20202020-2020-2020-2020-202020202020',
  '21212121-2121-2121-2121-212121212121'
);
SET CONSTRAINTS theory_sections_chapter_position_key IMMEDIATE;

RESET ROLE;

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(position ORDER BY id) = ARRAY[101, 102, 100]::integer[]
    FROM public.modules
    WHERE id IN (
      '13131313-1313-1313-1313-131313131313',
      '14141414-1414-1414-1414-141414141414',
      '15151515-1515-1515-1515-151515151515'
    )
  ),
  'a complete module sibling reorder succeeds with the deferrable uniqueness constraint'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(position ORDER BY id) = ARRAY[101, 102, 100]::integer[]
    FROM public.chapters
    WHERE id IN (
      '16161616-1616-1616-1616-161616161616',
      '17171717-1717-1717-1717-171717171717',
      '18181818-1818-1818-1818-181818181818'
    )
  ),
  'a complete chapter sibling reorder succeeds with the deferrable uniqueness constraint'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.array_agg(position ORDER BY id) = ARRAY[101, 102, 100]::integer[]
    FROM public.theory_sections
    WHERE id IN (
      '19191919-1919-1919-1919-191919191919',
      '20202020-2020-2020-2020-202020202020',
      '21212121-2121-2121-2121-212121212121'
    )
  ),
  'a complete theory sibling reorder succeeds with the deferrable uniqueness constraint'
);

SET LOCAL ROLE coditza_owner;

INSERT INTO public.modules (
  id, slug, title, description_markdown, position
)
VALUES (
  '22222222-2222-2222-2222-222222222222',
  'visibility-module',
  'Visibility module',
  'Visibility module description.',
  150
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
  '23232323-2323-2323-2323-232323232323',
  '22222222-2222-2222-2222-222222222222',
  'visibility-chapter',
  'Visibility chapter',
  'Visibility chapter summary.',
  0,
  20
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
  '24242424-2424-2424-2424-242424242424',
  '23232323-2323-2323-2323-232323232323',
  'Visibility theory',
  'Visibility theory body.',
  0,
  10
);

UPDATE public.chapters
SET status = 'published'::public.content_status,
    published_at = '2026-01-04 00:00:00+00'::pg_catalog.timestamptz
WHERE id = '23232323-2323-2323-2323-232323232323';

UPDATE public.theory_sections
SET status = 'published'::public.content_status,
    published_at = '2026-01-04 00:00:00+00'::pg_catalog.timestamptz
WHERE id = '24242424-2424-2424-2424-242424242424';

RESET ROLE;

SELECT extensions.ok(
  EXISTS (
    SELECT 1
    FROM public.theory_sections AS theory_section
    JOIN public.chapters AS chapter
      ON chapter.id = theory_section.chapter_id
    JOIN public.modules AS module
      ON module.id = chapter.module_id
    WHERE theory_section.id = '24242424-2424-2424-2424-242424242424'
      AND theory_section.status = 'published'::public.content_status
      AND chapter.status = 'published'::public.content_status
      AND module.status = 'draft'::public.content_status
  )
    AND NOT EXISTS (
      SELECT 1
      FROM public.theory_sections AS theory_section
      JOIN public.chapters AS chapter
        ON chapter.id = theory_section.chapter_id
      JOIN public.modules AS module
        ON module.id = chapter.module_id
      WHERE theory_section.id = '24242424-2424-2424-2424-242424242424'
        AND theory_section.status = 'published'::public.content_status
        AND chapter.status = 'published'::public.content_status
        AND module.status = 'published'::public.content_status
    ),
  'a published child beneath a draft ancestor is representable but excluded by the effective visibility predicate'
);

SET LOCAL ROLE coditza_owner;

UPDATE public.modules
SET status = 'published'::public.content_status,
    published_at = '2026-01-04 00:00:00+00'::pg_catalog.timestamptz
WHERE id = '22222222-2222-2222-2222-222222222222';

RESET ROLE;

SELECT extensions.ok(
  EXISTS (
    SELECT 1
    FROM public.theory_sections AS theory_section
    JOIN public.chapters AS chapter
      ON chapter.id = theory_section.chapter_id
    JOIN public.modules AS module
      ON module.id = chapter.module_id
    WHERE theory_section.id = '24242424-2424-2424-2424-242424242424'
      AND theory_section.status = 'published'::public.content_status
      AND chapter.status = 'published'::public.content_status
      AND module.status = 'published'::public.content_status
  ),
  'an all-published module, chapter, and theory chain matches the effective visibility predicate'
);

SET LOCAL ROLE coditza_owner;

UPDATE public.modules
SET status = 'archived'::public.content_status
WHERE id = '22222222-2222-2222-2222-222222222222';

RESET ROLE;

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM public.theory_sections AS theory_section
    JOIN public.chapters AS chapter
      ON chapter.id = theory_section.chapter_id
    JOIN public.modules AS module
      ON module.id = chapter.module_id
    WHERE theory_section.id = '24242424-2424-2424-2424-242424242424'
      AND theory_section.status = 'published'::public.content_status
      AND chapter.status = 'published'::public.content_status
      AND module.status = 'published'::public.content_status
  ),
  'a published child beneath an archived ancestor is excluded by the effective visibility predicate'
);

SELECT * FROM extensions.finish();

ROLLBACK;
