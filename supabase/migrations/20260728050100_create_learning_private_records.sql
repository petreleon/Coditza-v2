-- SUP-DATA-003: private operations records. The closed response and audit
-- validators/append helpers are added in the following forward migration.
BEGIN;

-- private tables still reference auth.users. The trusted migration operator
-- receives only temporary private-schema create/use so it can create those FK
-- tables, then ownership and privileges return to the closed owner boundary.
SET LOCAL ROLE coditza_owner;
GRANT USAGE, CREATE ON SCHEMA private TO postgres;
RESET ROLE;

CREATE TABLE private.idempotency_records (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  operation text NOT NULL,
  idempotency_key uuid NOT NULL,
  canonicalization_version integer NOT NULL,
  request_hash bytea NOT NULL,
  result_resource_id uuid NOT NULL,
  response_status integer NOT NULL,
  response_location text,
  response_body jsonb NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  expires_at timestamptz NOT NULL DEFAULT (
    pg_catalog.now() + pg_catalog.interval '24 hours'
  ),
  CONSTRAINT idempotency_records_pkey
    PRIMARY KEY (user_id, operation, idempotency_key),
  CONSTRAINT idempotency_records_operation_check
    CHECK (
      operation IN (
        'exercise_submit',
        'quiz_start',
        'python_grading_reserve',
        'admin_create_module',
        'admin_create_chapter',
        'admin_create_theory_section',
        'admin_create_exercise',
        'admin_create_quiz',
        'admin_clone_exercise',
        'admin_clone_quiz'
      )
    ),
  CONSTRAINT idempotency_records_canonicalization_version_check
    CHECK (canonicalization_version > 0),
  CONSTRAINT idempotency_records_request_hash_check
    CHECK (pg_catalog.octet_length(request_hash) = 32),
  CONSTRAINT idempotency_records_response_status_check
    CHECK (response_status BETWEEN 200 AND 299),
  CONSTRAINT idempotency_records_response_location_check
    CHECK (
      response_location IS NULL
      OR (
        pg_catalog.char_length(response_location) BETWEEN 1 AND 1000
        AND response_location OPERATOR(pg_catalog.~) '^/api/'
        AND response_location !~ E'[\\r\\n]'
      )
    ),
  CONSTRAINT idempotency_records_response_body_object_check
    CHECK (pg_catalog.jsonb_typeof(response_body) = 'object'),
  CONSTRAINT idempotency_records_expiry_after_creation_check
    CHECK (expires_at = created_at + pg_catalog.interval '24 hours')
);

ALTER TABLE private.idempotency_records ENABLE ROW LEVEL SECURITY;

CREATE TABLE private.audit_events (
  id uuid PRIMARY KEY DEFAULT pg_catalog.gen_random_uuid(),
  actor_kind text NOT NULL,
  actor_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  action text NOT NULL,
  entity_type text NOT NULL,
  entity_id uuid NOT NULL,
  changed_fields text[] NOT NULL DEFAULT ARRAY[]::text[],
  reason text,
  request_id uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT pg_catalog.now(),
  CONSTRAINT audit_events_actor_kind_check
    CHECK (actor_kind IN ('user', 'system')),
  CONSTRAINT audit_events_system_actor_check
    CHECK (actor_kind <> 'system' OR actor_user_id IS NULL),
  CONSTRAINT audit_events_action_check
    CHECK (
      action OPERATOR(pg_catalog.~) '^[a-z][a-z0-9_]{0,99}$'
    ),
  CONSTRAINT audit_events_entity_type_check
    CHECK (
      entity_type OPERATOR(pg_catalog.~) '^[a-z][a-z0-9_]{0,99}$'
    ),
  CONSTRAINT audit_events_changed_fields_count_check
    CHECK (pg_catalog.cardinality(changed_fields) <= 32),
  CONSTRAINT audit_events_reason_check
    CHECK (
      reason IS NULL
      OR (
        pg_catalog.char_length(reason) BETWEEN 1 AND 1000
        AND reason OPERATOR(pg_catalog.~) '[^[:space:]]'
      )
    )
);

ALTER TABLE private.audit_events ENABLE ROW LEVEL SECURITY;

ALTER TABLE private.idempotency_records OWNER TO coditza_owner;
ALTER TABLE private.audit_events OWNER TO coditza_owner;

SET LOCAL ROLE coditza_owner;

CREATE INDEX idempotency_records_expires_at_id_idx
  ON private.idempotency_records (expires_at, idempotency_key);
CREATE INDEX audit_events_created_at_id_idx
  ON private.audit_events (created_at DESC, id DESC);
CREATE INDEX audit_events_actor_created_id_idx
  ON private.audit_events (actor_user_id, created_at DESC, id DESC)
  WHERE actor_user_id IS NOT NULL;
CREATE INDEX audit_events_entity_created_id_idx
  ON private.audit_events (entity_type, entity_id, created_at DESC, id DESC);

REVOKE ALL ON TABLE private.idempotency_records, private.audit_events
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE USAGE, CREATE ON SCHEMA private FROM postgres;

RESET ROLE;

COMMIT;
