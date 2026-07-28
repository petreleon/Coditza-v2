BEGIN;

-- This suite owns no persistent fixture. It verifies the privileged-action
-- audit boundary in isolation and rolls back every synthetic Auth/audit row.
GRANT USAGE ON SCHEMA extensions TO coditza_owner;

SELECT extensions.plan(11);

SELECT extensions.ok(
  (
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
  )
  AND (
    SELECT relation_entry.relowner = 'coditza_owner'::pg_catalog.regrole
      AND relation_entry.relrowsecurity
      AND NOT relation_entry.relforcerowsecurity
    FROM pg_catalog.pg_class AS relation_entry
    WHERE relation_entry.oid = 'private.audit_events'::pg_catalog.regclass
  )
  AND NOT EXISTS (
    SELECT 1
    FROM pg_catalog.pg_policy AS policy_entry
    WHERE policy_entry.polrelid = 'private.audit_events'::pg_catalog.regclass
  )
  AND (
    SELECT pg_catalog.count(*) = 1
      AND pg_catalog.bool_and(
        constraint_entry.confrelid = 'auth.users'::pg_catalog.regclass
        AND constraint_entry.confdeltype = 'n'
      )
    FROM pg_catalog.pg_constraint AS constraint_entry
    WHERE constraint_entry.conrelid = 'private.audit_events'::pg_catalog.regclass
      AND constraint_entry.contype = 'f'
  )
  AND (
    SELECT pg_catalog.count(*) = 3
    FROM pg_catalog.pg_class AS index_entry
    WHERE index_entry.relname IN (
      'audit_events_created_at_id_idx',
      'audit_events_actor_created_id_idx',
      'audit_events_entity_created_id_idx'
    )
  )
  AND EXISTS (
    SELECT 1
    FROM pg_catalog.pg_trigger AS trigger_entry
    WHERE trigger_entry.tgrelid = 'private.audit_events'::pg_catalog.regclass
      AND trigger_entry.tgname = 'audit_events_enforce_append_only'
      AND NOT trigger_entry.tgisinternal
  ),
  'audit storage has the approved private, owned, RLS, retention, index, and append-only shape'
);

SELECT extensions.ok(
  NOT EXISTS (
    SELECT 1
    FROM (
      VALUES ('anon'), ('authenticated'), ('service_role'), ('authenticator')
    ) AS runtime_role(rolname)
    WHERE pg_catalog.has_schema_privilege(runtime_role.rolname, 'private', 'USAGE')
      OR pg_catalog.has_table_privilege(
        runtime_role.rolname,
        'private.audit_events'::pg_catalog.regclass,
        'SELECT'
      )
      OR pg_catalog.has_table_privilege(
        runtime_role.rolname,
        'private.audit_events'::pg_catalog.regclass,
        'INSERT'
      )
      OR pg_catalog.has_table_privilege(
        runtime_role.rolname,
        'private.audit_events'::pg_catalog.regclass,
        'UPDATE'
      )
      OR pg_catalog.has_table_privilege(
        runtime_role.rolname,
        'private.audit_events'::pg_catalog.regclass,
        'DELETE'
      )
      OR pg_catalog.has_function_privilege(
        runtime_role.rolname,
        'private.append_audit_event(text,uuid,text,text,uuid,text[],jsonb,text,uuid)'::pg_catalog.regprocedure,
        'EXECUTE'
      )
  ),
  'normal runtime roles cannot access the private audit table or append helper'
);

SELECT extensions.ok(
  (
    SELECT pg_catalog.count(*) = 2
      AND pg_catalog.bool_and(
        procedure_entry.proowner = 'coditza_owner'::pg_catalog.regrole
        AND NOT procedure_entry.prosecdef
        AND procedure_entry.proconfig = ARRAY['search_path=""']::text[]
      )
    FROM pg_catalog.pg_proc AS procedure_entry
    WHERE procedure_entry.oid IN (
      'private.assert_safe_audit_change_summary(text[],jsonb)'::pg_catalog.regprocedure,
      'private.append_audit_event(text,uuid,text,text,uuid,text[],jsonb,text,uuid)'::pg_catalog.regprocedure
    )
  )
  AND pg_catalog.to_regprocedure(
    'private.append_audit_event(text,uuid,text,text,uuid,text[],text,uuid)'
  ) IS NULL,
  'audit helpers use the closed safe-summary contract and the legacy append signature is absent'
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
    'b3000000-0000-0000-0000-000000000001',
    'authenticated',
    'authenticated',
    'audit-user@coditza.invalid',
    '{}'::jsonb,
    '{"displayName":"Audit User"}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  ),
  (
    'b3000000-0000-0000-0000-000000000002',
    'authenticated',
    'authenticated',
    'audit-delete@coditza.invalid',
    '{}'::jsonb,
    '{"displayName":"Audit Delete"}'::jsonb,
    pg_catalog.now(),
    pg_catalog.now()
  );

SET LOCAL ROLE coditza_owner;

DO $valid_audit_events$
DECLARE
  v_user_event_id uuid;
  v_system_event_id uuid;
BEGIN
  v_user_event_id := private.append_audit_event(
    'user',
    'b3000000-0000-0000-0000-000000000001',
    'profile_updated',
    'profile',
    'b3200000-0000-0000-0000-000000000001',
    ARRAY['display_name']::text[],
    '{"display_name":{"before":"redacted","after":"redacted"}}'::jsonb,
    'policy_enforcement',
    'b3a00000-0000-0000-0000-000000000001'
  );
  v_system_event_id := private.append_audit_event(
    'system',
    NULL,
    'maintenance_completed',
    'maintenance_job',
    'b3200000-0000-0000-0000-000000000002',
    ARRAY['status']::text[],
    '{"status":{"before":"running","after":"completed"}}'::jsonb,
    NULL,
    'b3a00000-0000-0000-0000-000000000002'
  );

  IF NOT EXISTS (
    SELECT 1
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.id = v_user_event_id
      AND audit_entry.actor_kind = 'user'
      AND audit_entry.actor_user_id = 'b3000000-0000-0000-0000-000000000001'
      AND audit_entry.action = 'profile_updated'
      AND audit_entry.entity_type = 'profile'
      AND audit_entry.entity_id = 'b3200000-0000-0000-0000-000000000001'
      AND audit_entry.changed_fields = ARRAY['display_name']::text[]
      AND audit_entry.change_summary
        = '{"display_name":{"before":"redacted","after":"redacted"}}'::jsonb
      AND audit_entry.reason = 'policy_enforcement'
      AND audit_entry.request_id = 'b3a00000-0000-0000-0000-000000000001'
      AND audit_entry.created_at IS NOT NULL
  ) OR NOT EXISTS (
    SELECT 1
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.id = v_system_event_id
      AND audit_entry.actor_kind = 'system'
      AND audit_entry.actor_user_id IS NULL
      AND audit_entry.action = 'maintenance_completed'
      AND audit_entry.entity_type = 'maintenance_job'
      AND audit_entry.entity_id = 'b3200000-0000-0000-0000-000000000002'
      AND audit_entry.changed_fields = ARRAY['status']::text[]
      AND audit_entry.change_summary
        = '{"status":{"before":"running","after":"completed"}}'::jsonb
      AND audit_entry.reason IS NULL
      AND audit_entry.request_id = 'b3a00000-0000-0000-0000-000000000002'
      AND audit_entry.created_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'valid audit event shape was not retained';
  END IF;
END;
$valid_audit_events$;
SELECT extensions.ok(TRUE, 'user and system audit events retain the approved safe metadata and deltas');

DO $actor_and_identifier_rejection$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM private.append_audit_event(
      'user',
      NULL,
      'profile_updated',
      'profile',
      'b3200000-0000-0000-0000-000000000001',
      ARRAY['display_name']::text[],
      '{"display_name":{"before":"redacted","after":"redacted"}}'::jsonb,
      NULL,
      'b3a00000-0000-0000-0000-000000000003'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'user audit event unexpectedly accepted a null actor';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.append_audit_event(
      'system',
      'b3000000-0000-0000-0000-000000000001',
      'maintenance_completed',
      'maintenance_job',
      'b3200000-0000-0000-0000-000000000002',
      ARRAY['status']::text[],
      '{"status":{"before":"running","after":"completed"}}'::jsonb,
      NULL,
      'b3a00000-0000-0000-0000-000000000004'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'system audit event unexpectedly accepted a user actor';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.append_audit_event(
      'user',
      'b3000000-0000-0000-0000-000000000001',
      'InvalidAction',
      'profile',
      'b3200000-0000-0000-0000-000000000001',
      ARRAY['display_name']::text[],
      '{"display_name":{"before":"redacted","after":"redacted"}}'::jsonb,
      NULL,
      'b3a00000-0000-0000-0000-000000000005'
    );
  EXCEPTION WHEN check_violation THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'invalid audit action unexpectedly persisted';
  END IF;
END;
$actor_and_identifier_rejection$;
SELECT extensions.ok(TRUE, 'audit actor combinations and identifier formats fail closed');

DO $unsafe_change_summary_rejection$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    PERFORM private.append_audit_event(
      'user',
      'b3000000-0000-0000-0000-000000000001',
      'profile_updated',
      'profile',
      'b3200000-0000-0000-0000-000000000001',
      ARRAY['role']::text[],
      '{"role":{"before":"opaque_value","after":"editor"}}'::jsonb,
      NULL,
      'b3a00000-0000-0000-0000-000000000006'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'opaque audit before value unexpectedly persisted';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.append_audit_event(
      'user',
      'b3000000-0000-0000-0000-000000000001',
      'profile_updated',
      'profile',
      'b3200000-0000-0000-0000-000000000001',
      ARRAY[]::text[],
      '{"role":{"before":"learner","after":"editor"}}'::jsonb,
      NULL,
      'b3a00000-0000-0000-0000-000000000007'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'extra audit summary field unexpectedly persisted';
  END IF;
END;
$unsafe_change_summary_rejection$;
SELECT extensions.ok(TRUE, 'audit deltas require exact changed fields and approved non-content before/after codes');

DO $sensitive_changed_field_rejection$
DECLARE
  v_field text;
  v_rejected boolean;
BEGIN
  FOREACH v_field IN ARRAY ARRAY[
    'password',
    'access_token',
    'refresh_token',
    'totp_secret',
    'otp_code',
    'qr_code',
    'otpauth_uri',
    'answer_payload',
    'answer_key',
    'markdown_body',
    'source_code',
    'test_case'
  ]::text[] LOOP
    v_rejected := false;
    BEGIN
      PERFORM private.append_audit_event(
        'user',
        'b3000000-0000-0000-0000-000000000001',
        'profile_updated',
        'profile',
        'b3200000-0000-0000-0000-000000000001',
        ARRAY[v_field],
        '{}'::jsonb,
        NULL,
        pg_catalog.gen_random_uuid()
      );
    EXCEPTION WHEN raise_exception THEN
      v_rejected := true;
    END;
    IF NOT v_rejected THEN
      RAISE EXCEPTION 'sensitive audit changed field unexpectedly persisted';
    END IF;
  END LOOP;
END;
$sensitive_changed_field_rejection$;
SELECT extensions.ok(TRUE, 'audit summaries reject password, Auth, TOTP, answer, and content-bearing field names');

DO $reason_code_rejection$
DECLARE
  v_reason text;
  v_rejected boolean;
BEGIN
  FOREACH v_reason IN ARRAY ARRAY[
    'password_material',
    'access_token_material',
    'refresh_material',
    'totp_material',
    'otp_material',
    'qr_material',
    'otpauth_material',
    'answer_material',
    'key_material',
    'markdown_material',
    'body_material',
    'source_material',
    'test_material',
    'opaque_free_text'
  ]::text[] LOOP
    v_rejected := false;
    BEGIN
      PERFORM private.append_audit_event(
        'user',
        'b3000000-0000-0000-0000-000000000001',
        'profile_updated',
        'profile',
        'b3200000-0000-0000-0000-000000000001',
        ARRAY[]::text[],
        '{}'::jsonb,
        v_reason,
        pg_catalog.gen_random_uuid()
      );
    EXCEPTION WHEN raise_exception THEN
      v_rejected := true;
    END;
    IF NOT v_rejected THEN
      RAISE EXCEPTION 'unsafe audit reason unexpectedly persisted';
    END IF;
  END LOOP;
END;
$reason_code_rejection$;
SELECT extensions.ok(TRUE, 'audit reasons are closed non-content codes rather than free text');

DO $owner_append_only_guard$
DECLARE
  v_rejected boolean := false;
BEGIN
  BEGIN
    INSERT INTO private.audit_events (
      actor_kind,
      actor_user_id,
      action,
      entity_type,
      entity_id,
      changed_fields,
      change_summary,
      request_id
    )
    VALUES (
      'user',
      'b3000000-0000-0000-0000-000000000001',
      'profile_updated',
      'profile',
      'b3200000-0000-0000-0000-000000000001',
      ARRAY['status']::text[],
      '{"status":{"before":"pending","after":"completed"}}'::jsonb,
      'b3a00000-0000-0000-0000-000000000008'
    );
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'direct owner audit insert unexpectedly succeeded';
  END IF;

  v_rejected := false;
  BEGIN
    UPDATE private.audit_events
    SET action = 'tampered'
    WHERE request_id = 'b3a00000-0000-0000-0000-000000000001';
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'audit update unexpectedly succeeded';
  END IF;

  v_rejected := false;
  BEGIN
    DELETE FROM private.audit_events
    WHERE request_id = 'b3a00000-0000-0000-0000-000000000001';
  EXCEPTION WHEN raise_exception THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'audit delete unexpectedly succeeded';
  END IF;
END;
$owner_append_only_guard$;
SELECT extensions.ok(TRUE, 'audit writes require the intended helper and ordinary mutations are append-only denied');

RESET ROLE;
SET LOCAL ROLE service_role;

DO $runtime_direct_denial$
DECLARE
  v_rejected boolean;
BEGIN
  v_rejected := false;
  BEGIN
    PERFORM 1 FROM private.audit_events LIMIT 1;
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'runtime audit read unexpectedly succeeded';
  END IF;

  v_rejected := false;
  BEGIN
    INSERT INTO private.audit_events (
      actor_kind,
      actor_user_id,
      action,
      entity_type,
      entity_id,
      changed_fields,
      change_summary,
      request_id
    )
    VALUES (
      'user',
      'b3000000-0000-0000-0000-000000000001',
      'profile_updated',
      'profile',
      'b3200000-0000-0000-0000-000000000001',
      ARRAY['status']::text[],
      '{"status":{"before":"pending","after":"completed"}}'::jsonb,
      'b3a00000-0000-0000-0000-000000000009'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'runtime audit insert unexpectedly succeeded';
  END IF;

  v_rejected := false;
  BEGIN
    UPDATE private.audit_events
    SET action = 'tampered';
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'runtime audit update unexpectedly succeeded';
  END IF;

  v_rejected := false;
  BEGIN
    DELETE FROM private.audit_events;
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'runtime audit delete unexpectedly succeeded';
  END IF;

  v_rejected := false;
  BEGIN
    PERFORM private.append_audit_event(
      'user',
      'b3000000-0000-0000-0000-000000000001',
      'profile_updated',
      'profile',
      'b3200000-0000-0000-0000-000000000001',
      ARRAY['status']::text[],
      '{"status":{"before":"pending","after":"completed"}}'::jsonb,
      NULL,
      'b3a00000-0000-0000-0000-000000000010'
    );
  EXCEPTION WHEN insufficient_privilege THEN
    v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'runtime audit helper execution unexpectedly succeeded';
  END IF;
END;
$runtime_direct_denial$;

RESET ROLE;
SELECT extensions.ok(TRUE, 'runtime role direct audit reads, mutations, and helper execution fail with privilege denial');

SET LOCAL ROLE coditza_owner;
SELECT private.append_audit_event(
  'user',
  'b3000000-0000-0000-0000-000000000002',
  'account_removed',
  'profile',
  'b3200000-0000-0000-0000-000000000003',
  ARRAY['status']::text[],
  '{"status":{"before":"enabled","after":"deleted"}}'::jsonb,
  NULL,
  'b3a00000-0000-0000-0000-000000000011'
);

RESET ROLE;
DELETE FROM auth.users
WHERE id = 'b3000000-0000-0000-0000-000000000002';
SET LOCAL ROLE coditza_owner;

SELECT extensions.ok(
  EXISTS (
    SELECT 1
    FROM private.audit_events AS audit_entry
    WHERE audit_entry.request_id = 'b3a00000-0000-0000-0000-000000000011'
      AND audit_entry.actor_kind = 'user'
      AND audit_entry.actor_user_id IS NULL
      AND audit_entry.action = 'account_removed'
      AND audit_entry.entity_type = 'profile'
      AND audit_entry.entity_id = 'b3200000-0000-0000-0000-000000000003'
      AND audit_entry.changed_fields = ARRAY['status']::text[]
      AND audit_entry.change_summary
        = '{"status":{"before":"enabled","after":"deleted"}}'::jsonb
      AND audit_entry.reason IS NULL
      AND audit_entry.created_at IS NOT NULL
  ),
  'account deletion retains the audit event while anonymizing only the former user actor'
);

RESET ROLE;
SELECT * FROM extensions.finish();

ROLLBACK;
