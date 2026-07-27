# Python code exercise endpoints

All routes below are Coditza domain routes and require the same verified
Supabase `aal2` principal, live-role load, and identity-security-hold check as
other learning routes. They never accept or proxy passwords, TOTP codes, factor
data, tokens, or Supabase Auth responses.

## Safe exercise projection

For `python_code`, the existing exercise detail adds:

```text
type=python_code
starterFiles[{path,content}]
entryPoint{module,function}
publicTests[{id,title,description,fixture}]
runtime{language=python,pythonVersion,pyodideVersion,profileId}
limits{wallTimeMs,cpuTimeMs,memoryBytes,outputBytes,fileCount,fileBytes,totalBytes}
```

It never includes hidden tests/counts/digests, harness source, expected values,
allowed internal imports, or private tracebacks. Runtime versions are
informational; the server chooses and verifies the authoritative manifest.

## `POST /api/v1/exercises/:exerciseId/python-grading-requests`

Requires a UUID `Idempotency-Key` and the canonical `files` payload from
PRD-WASM-001. Unknown fields—including `passed`, `score`, `verdict`,
`testResults`, `runtimeVersion`, or `userId`—fail schema validation.

For a new valid reservation return `202 Accepted`, a safe `Location` for the
owner-status resource, and:

```text
id, exerciseId, exerciseDefinitionVersion, status=queued, createdAt
```

A same-hash replay returns the same resource and
`Idempotency-Replayed: true`; different input conflicts. Queue saturation uses
`503 grading_capacity_unavailable` plus a bounded `Retry-After` and creates no
attempt. The endpoint does not wait for, invoke, or trust browser execution.

## `GET /api/v1/me/python-grading-requests/:requestId`

Owner only; a foreign ID is concealed as 404. Safe states are:

- `queued` or `running`, with no test information;
- `completed`, with the immutable normal exercise-attempt projection plus
  allowlisted verdict, sanitized bounded output, and public feedback;
- `temporarily_failed`, with a generic retryable service problem and no learner
  score;
- `dead`, with a generic support/request ID and no hidden detail.

Polling uses bounded rate limits and `Retry-After`. A completed job points to
the existing owner-only attempt detail/history resources. Hidden-test identity,
count, timing, body, expected values, and raw tracebacks never appear in any
status, history, OpenAPI example, log, or Problem Details extension.

## Future browser preview contract

A future approved client may use the safe exercise projection and the same
self-hosted runtime-manifest assets to run public tests in a module Web Worker.
That preview has no API endpoint for reporting success and no authority over
attempts/progress. This paragraph does not authorize a frontend or browser
implementation in the current repository phase.

## API-WASM-001 — Implement Python reservation and status routes

Prerequisites: PRD-WASM-001, FAST-WASM-001, SUP-WASM-001, API-CONTENT-001, and
the common API/idempotency contract.

- [ ] Add closed TypeBox request/response schemas and deterministic OpenAPI
      examples for safe projection, reservation, polling, and completed result.
- [ ] Enforce canonical file/path/size limits at HTTP and product layers.
- [ ] Test same-hash replay, different-hash conflict, owner concealment,
      saturation, infrastructure retry/dead state, and archive races.
- [ ] Submit forged browser pass/score/test/runtime reports and prove they fail
      validation and cannot reach queue/finalization ports.
- [ ] Scan all schemas/examples/responses/logs for hidden tests, source,
      secrets, Auth/TOTP material, and private runner fields.
