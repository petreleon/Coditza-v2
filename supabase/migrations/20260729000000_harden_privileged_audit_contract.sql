-- ARC-SEC-003: replace free-form audit reasons and opaque summaries with a
-- closed, non-content-bearing privileged-action audit contract.
BEGIN;

SET LOCAL ROLE coditza_owner;

ALTER TABLE private.audit_events
  ADD COLUMN change_summary jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD CONSTRAINT audit_events_change_summary_object_check
    CHECK (pg_catalog.jsonb_typeof(change_summary) = 'object'),
  ADD CONSTRAINT audit_events_reason_code_check
    CHECK (
      reason IS NULL
      OR reason IN (
        'administrative_correction',
        'content_archive',
        'content_correction',
        'content_replacement',
        'identity_recovery',
        'maintenance',
        'other_approved',
        'policy_enforcement',
        'progress_reconciliation',
        'role_change',
        'security_hold'
      )
    );

CREATE OR REPLACE FUNCTION private.assert_safe_audit_fields(
  p_changed_fields text[],
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_safe_audit_fields$
DECLARE
  v_field text;
BEGIN
  IF p_changed_fields IS NULL OR pg_catalog.cardinality(p_changed_fields) > 32 THEN
    RAISE EXCEPTION 'Audit changed fields are outside the approved bounds.';
  END IF;

  FOREACH v_field IN ARRAY p_changed_fields LOOP
    IF v_field IS NULL
      OR NOT (v_field OPERATOR(pg_catalog.~) '^[a-z][a-z0-9_]{0,63}$')
      OR v_field OPERATOR(pg_catalog.~*)
        '(answer|accepted|correctoption|key|token|password|secret|totp|otp|qr|otpauth|markdown|body|source|test|email)' THEN
      RAISE EXCEPTION 'Audit changed fields may not contain sensitive or content-bearing names.';
    END IF;
  END LOOP;

  IF p_reason IS NOT NULL
    AND p_reason NOT IN (
      'administrative_correction',
      'content_archive',
      'content_correction',
      'content_replacement',
      'identity_recovery',
      'maintenance',
      'other_approved',
      'policy_enforcement',
      'progress_reconciliation',
      'role_change',
      'security_hold'
    ) THEN
    RAISE EXCEPTION 'Audit reasons must be approved non-content reason codes.';
  END IF;
END;
$assert_safe_audit_fields$;

CREATE FUNCTION private.assert_safe_audit_change_summary(
  p_changed_fields text[],
  p_change_summary jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $assert_safe_audit_change_summary$
DECLARE
  v_field text;
  v_change jsonb;
  v_before text;
  v_after text;
  v_key_count integer;
BEGIN
  IF p_changed_fields IS NULL
    OR pg_catalog.jsonb_typeof(p_change_summary) <> 'object' THEN
    RAISE EXCEPTION 'Audit change summaries must be object-shaped.';
  END IF;

  SELECT pg_catalog.count(*)
  INTO v_key_count
  FROM pg_catalog.jsonb_object_keys(p_change_summary);

  IF v_key_count <> pg_catalog.cardinality(p_changed_fields) THEN
    RAISE EXCEPTION 'Audit change summaries must name exactly the changed fields.';
  END IF;

  FOREACH v_field IN ARRAY p_changed_fields LOOP
    v_change := p_change_summary OPERATOR(pg_catalog.->) v_field;

    IF v_change IS NULL
      OR pg_catalog.jsonb_typeof(v_change) <> 'object' THEN
      RAISE EXCEPTION 'Audit change summaries must contain before and after codes.';
    END IF;

    SELECT pg_catalog.count(*)
    INTO v_key_count
    FROM pg_catalog.jsonb_object_keys(v_change);

    IF v_key_count <> 2
      OR NOT (v_change OPERATOR(pg_catalog.?) 'before')
      OR NOT (v_change OPERATOR(pg_catalog.?) 'after')
      OR pg_catalog.jsonb_typeof(v_change OPERATOR(pg_catalog.->) 'before') <> 'string'
      OR pg_catalog.jsonb_typeof(v_change OPERATOR(pg_catalog.->) 'after') <> 'string' THEN
      RAISE EXCEPTION 'Audit change summary entries must contain only string before and after codes.';
    END IF;

    v_before := v_change OPERATOR(pg_catalog.->>) 'before';
    v_after := v_change OPERATOR(pg_catalog.->>) 'after';

    IF v_before NOT IN (
      'admin',
      'archived',
      'clear',
      'completed',
      'created',
      'deleted',
      'disabled',
      'draft',
      'editor',
      'enabled',
      'expired',
      'failed',
      'in_progress',
      'learner',
      'none',
      'not_started',
      'passed',
      'pending',
      'published',
      'reconciled',
      'redacted',
      'running',
      'set',
      'started',
      'submitted',
      'true',
      'false',
      'unchanged',
      'updated'
    )
      OR v_after NOT IN (
        'admin',
        'archived',
        'clear',
        'completed',
        'created',
        'deleted',
        'disabled',
        'draft',
        'editor',
        'enabled',
        'expired',
        'failed',
        'in_progress',
        'learner',
        'none',
        'not_started',
        'passed',
        'pending',
        'published',
        'reconciled',
        'redacted',
        'running',
        'set',
        'started',
        'submitted',
        'true',
        'false',
        'unchanged',
        'updated'
      ) THEN
      RAISE EXCEPTION 'Audit before and after values must be approved safe codes.';
    END IF;
  END LOOP;
END;
$assert_safe_audit_change_summary$;

CREATE FUNCTION private.append_audit_event(
  p_actor_kind text,
  p_actor_user_id uuid,
  p_action text,
  p_entity_type text,
  p_entity_id uuid,
  p_changed_fields text[],
  p_change_summary jsonb,
  p_reason text,
  p_request_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $append_audit_event$
DECLARE
  v_id uuid;
BEGIN
  IF p_actor_kind NOT IN ('user', 'system') THEN
    RAISE EXCEPTION 'Audit actor kind is invalid.';
  END IF;
  IF (p_actor_kind = 'user' AND p_actor_user_id IS NULL)
    OR (p_actor_kind = 'system' AND p_actor_user_id IS NOT NULL) THEN
    RAISE EXCEPTION 'Audit actor kind and actor user are inconsistent.';
  END IF;

  PERFORM private.assert_safe_audit_fields(p_changed_fields, p_reason);
  PERFORM private.assert_safe_audit_change_summary(
    p_changed_fields,
    p_change_summary
  );
  PERFORM pg_catalog.set_config('coditza.learning_write', 'audit', true);

  INSERT INTO private.audit_events (
    actor_kind,
    actor_user_id,
    action,
    entity_type,
    entity_id,
    changed_fields,
    change_summary,
    reason,
    request_id
  )
  VALUES (
    p_actor_kind,
    p_actor_user_id,
    p_action,
    p_entity_type,
    p_entity_id,
    p_changed_fields,
    p_change_summary,
    p_reason,
    p_request_id
  )
  RETURNING id INTO v_id;

  PERFORM pg_catalog.set_config('coditza.learning_write', '', true);
  RETURN v_id;
END;
$append_audit_event$;

CREATE OR REPLACE FUNCTION private.enforce_audit_event_write()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = ''
AS $enforce_audit_event_write$
BEGIN
  IF TG_OP = 'INSERT' THEN
    PERFORM private.assert_learning_write_marker('audit');
    IF NEW.actor_kind = 'user' AND NEW.actor_user_id IS NULL THEN
      RAISE EXCEPTION 'User audit events require an actor at insertion.';
    END IF;
    IF NEW.actor_kind = 'system' AND NEW.actor_user_id IS NOT NULL THEN
      RAISE EXCEPTION 'System audit events cannot name a user actor.';
    END IF;
    PERFORM private.assert_safe_audit_fields(NEW.changed_fields, NEW.reason);
    PERFORM private.assert_safe_audit_change_summary(
      NEW.changed_fields,
      NEW.change_summary
    );
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
    AND OLD.actor_kind = 'user'
    AND OLD.actor_user_id IS NOT NULL
    AND NEW.actor_user_id IS NULL
    AND NEW.actor_kind = OLD.actor_kind
    AND NEW.action = OLD.action
    AND NEW.entity_type = OLD.entity_type
    AND NEW.entity_id = OLD.entity_id
    AND NEW.changed_fields = OLD.changed_fields
    AND NEW.change_summary = OLD.change_summary
    AND NEW.reason IS NOT DISTINCT FROM OLD.reason
    AND NEW.request_id = OLD.request_id
    AND NEW.created_at = OLD.created_at THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Audit events are append-only except for approved account-deletion anonymization.';
END;
$enforce_audit_event_write$;

DROP FUNCTION private.append_audit_event(
  text,
  uuid,
  text,
  text,
  uuid,
  text[],
  text,
  uuid
);

REVOKE ALL ON FUNCTION private.assert_safe_audit_change_summary(text[], jsonb)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;
REVOKE ALL ON FUNCTION private.append_audit_event(
  text,
  uuid,
  text,
  text,
  uuid,
  text[],
  jsonb,
  text,
  uuid
)
  FROM postgres, PUBLIC, anon, authenticated, service_role, authenticator;

RESET ROLE;

COMMIT;
