# Python WASM grading orchestration

## Process and module ownership

The `assessment` module owns `ReservePythonGrading`, `ClaimPythonGrading`, and
`FinalizePythonGrading` application use cases. Fastify exposes only reservation
and owner-status HTTP adapters. A private grader-controller entrypoint consumes
the claim/finalize ports and has no Fastify registration or public listener.

ADR 0006's `scripts/python-wasm/local-launch-broker.mjs` is evidence for a
developer-local outer boundary only. It must not implement `PythonSandboxPort`,
be imported by this future controller, or lend Docker CLI/socket authority to
application runtime. A `local_public_proof` result is not a valid controller
result and must fail before any attempt/finalization path.

Required narrow ports:

- `PythonGradingQueuePort` for reserve, owner-status, claim, retry, and finalize
  RPCs;
- `PythonSandboxPort` for one versioned, secret-free run request;
- `RuntimeManifestPort` for read-only verified local assets/digests;
- `GraderMetricsPort` for bounded safe operational signals.

No port exposes a raw Supabase client, generic SQL/job execution, arbitrary
command, filesystem, container engine, or network client.

## Controller algorithm

For each leased job the controller:

1. validates the closed claim record and all sizes/digests;
2. loads the exact local runtime manifest and fails closed on any hash drift;
3. builds the minimal secret-free runner request;
4. asks `PythonSandboxPort` to create one disposable hardened sandbox;
5. applies parent-side wall/output limits and termination;
6. validates the closed result schema, verdict, and echoed digests;
7. derives the allowed zero/full-points outcome;
8. calls the finalization RPC once or records an infrastructure retry;
9. destroys all per-run handles/buffers and emits only safe metrics.

Learner cancellation or an HTTP disconnect does not convert a running job into
a score and does not bypass finalization. Controller shutdown stops claims,
drains or terminates within the configured bound, and lets unfinished leases
expire safely.

## FAST-WASM-001 — Implement the authoritative runner adapter

Prerequisites: ARC-WASM-001, SUP-WASM-001, FAST-LAYER-001, FAST-MFA-001, and
the pinned configuration contract.

- [ ] Implement the four narrow ports and wire them only in the API and
      grader-controller composition roots that need them.
- [ ] Keep the sandbox adapter out of HTTP routes and the raw secret client out
      of the sandbox/controller protocol.
- [ ] Implement exact claim/validate/run/finalize/retry/shutdown behavior with
      bounded concurrency and backpressure.
- [ ] Fail readiness for the controller, but not API liveness, on missing or
      mismatched runtime assets; expose queue saturation safely to reservation.
- [ ] Unit-test every runner verdict, malformed/oversized result, digest
      mismatch, timeout, cancellation, lease loss, crash, retry, and shutdown.
- [ ] Add negative import/protocol fixtures proving identity/Auth/TOTP adapters,
      secrets, Fastify, and arbitrary platform launch APIs cannot enter the
      sandbox worker.
