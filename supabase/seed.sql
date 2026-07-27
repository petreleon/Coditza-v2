-- SUP-LOCAL-002 executes this deterministic, non-persistent seed baseline.
-- Real users, curriculum content, and application fixtures remain owned by
-- their named later tasks.
DO $seed$
BEGIN
  RAISE NOTICE 'CODITZA_LOCAL_SEED_V1';
END;
$seed$;
