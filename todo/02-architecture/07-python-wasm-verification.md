# Python-on-WebAssembly verification architecture

## Selected execution model

Use one exact, self-hosted Pyodide distribution for Python-on-WebAssembly.
ARC-WASM-001 selects a currently supported exact Pyodide/Python pair and writes
an immutable runtime manifest; no task may use `latest`, a semver range, or a
third-party CDN. Browser and server adapters consume the same manifest and
asset digests.

ADR 0006 records the completed **developer-local public-proof** implementation:
it locks the server-side bundle and proves a disposable Docker boundary against
synthetic public cases. It does not select a hosted launcher, create a controller
or private test channel, or make `local_public_proof` an authoritative learner
verdict. Those remaining capabilities retain the future constraints below.

Browser execution is a future client contract only. When a client is later
approved, it may run public tests in a module-type Web Worker so provisional
feedback cannot block the UI. This plan does not select or implement a
frontend. Browser output is untrusted and is never sent as grading evidence.

Authoritative grading is server-side:

```text
future client
  |-- optional public tests --> browser Web Worker (provisional only)
  `-- source files + Idempotency-Key --> Fastify (AAL2 + schema)
                                          |
                                          `-- reserve job RPC --> Supabase

grader controller (private, no public HTTP)
  |-- claim leased job RPC --> Supabase
  |-- definition + source --> disposable hardened sandbox
  |                          `-- pinned Pyodide worker
  `-- verdict + digests --> finalize job RPC --> attempt + progress
```

The Fastify modular monolith remains the only public/domain HTTP service. The
grader controller is a second process from the same reviewed release solely
because untrusted code requires an execution boundary. It has no public
listener, owns no business data, and exposes no cross-module API. The
`assessment` module owns the queue/finalization use cases and their ports.

## Security boundary

WebAssembly and Node's WASI APIs are not treated as a security sandbox. The
Pyodide worker must run inside a disposable hardened outer sandbox selected by
the ARC-WASM-001 ADR. A Node worker thread alone is forbidden.

Each authoritative run must have all of these controls:

- fresh process/container/microVM and fresh virtual filesystem;
- no network namespace/routes and no DNS; denial is enforced outside Python;
- empty explicit environment allowlist with no Supabase, Auth, TOTP, cloud,
  registry, CI, host, or user secrets;
- non-root UID, no privilege escalation, all capabilities dropped, bounded
  syscall profile, and no host/container-engine socket;
- read-only runtime image/assets verified by digest;
- one bounded writable tmpfs/work directory, destroyed after the run;
- no host path, database, service-account, socket, device, home directory, or
  parent process filesystem mount;
- only sealed control/stdin/stdout pipes carrying the versioned learner-facing
  runner protocol and isolated trusted-harness initialization; no such handoff
  is exposed to learner Python;
- hard wall-clock and CPU time, address-space/memory, file-count/bytes,
  process/thread, stdout/stderr/result-size limits;
- parent-side termination of the entire sandbox on a limit or protocol breach;
- package installation, dynamic asset fetching, sockets, subprocesses, native
  host modules, and imports outside the approved runtime bundle denied;
- a bounded controller queue, concurrency ceiling, lease expiry, retry ceiling,
  and circuit breaker so submissions cannot exhaust the API or database.

Private tests use a versioned closed declarative harness DSL, not arbitrary
Python test files. The trusted bootstrap keeps the case plan/expected values in
a host-side lexical closure, never in the learner virtual filesystem, Python
globals, environment, or JavaScript global object. It invokes only allowlisted
module/function/class operations and compares canonicalized results outside the
learner namespace. Learner code necessarily observes its own inputs, so hidden
fixtures contain no platform/user secret. Hidden-phase stdout/stderr is hashed
for diagnostics and discarded; it is never returned. Public-test execution is
separate and may return only its bounded safe output.

The initial `python-basic-v1` hard-cap profile is explicit:

| Resource | Maximum |
| --- | ---: |
| sandbox launch + verified runtime initialization | 15 seconds wall time; failure is infrastructure-only |
| learner code + tests | 5 seconds wall and 3 seconds CPU |
| total sandbox memory | 256 MiB |
| writable scratch | 8 MiB and 128 regular files, including generated test files |
| learner source | 16 files, 64 KiB each, 256 KiB aggregate |
| stdout + stderr retained | 64 KiB combined, then terminate with `output_limit_exceeded` |
| runner result protocol | 128 KiB |
| sandbox PIDs/threads | 16 for runtime bootstrap; learner process/subprocess creation remains denied |

An exercise may choose a lower learner wall/output bound but never a higher one.
ARC-WASM-001 benchmarks the pinned runtime against these caps. If the exact
runtime cannot boot reliably, the task stops for an ADR/change to this profile;
an implementation must not silently raise a cap or disable isolation.

The Pyodide `js` bridge and any Python escape attempt are still assumed hostile.
Even if learner code reaches JavaScript or exploits the interpreter, the outer
sandbox must leave it with no network, secrets, useful host filesystem, or
privilege.

The API and grader controller must never receive a general Docker socket. A
hosting or local launcher is acceptable only when it offers a narrow
create/run/terminate capability for the exact pinned sandbox image and cannot
inspect or control unrelated workloads. If no compliant launcher exists, the
Python verifier and its deployment gate remain blocked.

## Runtime and protocol pinning

The repository contains a reviewed `python-wasm-runtime.lock.json` containing:

- exact Pyodide and embedded CPython versions;
- SHA-256 for the loader, WebAssembly binary, standard-library archive, package
  index, harness, worker bootstrap, and every allowed wheel/package asset;
- exact Node package integrity and runner/sandbox image digest;
- verifier protocol and deterministic-fixture versions;
- allowed package/import inventory and license metadata;
- resource-limit profile and compatibility date.

Every job carries the expected manifest, definition, fixture, submission, and
harness digests. The worker echoes them; the controller rejects any mismatch
before finalization. Runtime assets are loaded only from the verified local
bundle. A build or deployment with an unexplained manifest/SBOM drift fails.

## Trust and data minimization

The learner-facing sandbox request contains only a random job ID, canonical
learner files, frozen entry-point/public-case data, the five expected digests,
and non-secret limits. It contains no user ID, email, role, JWT, request
authorization header, TOTP material, Supabase URL/key, idempotency key,
database row, private case plan, private expected value, or authored content
unneeded by public execution.

A separate protected controller-to-trusted-harness initialization handoff
supplies the frozen declarative private case plan only after digest agreement.
It is not a field in the learner-facing request/result and never becomes a
learner virtual file, Python/JavaScript global, environment value, standard
input/output value, log, report, artifact, or public feedback. ARC-WASM-001 and
SUP-WASM-001 must choose and prove the exact sealed handoff without creating a
generic database or network capability in the sandbox.

The controller accepts only a bounded JSON result with an allowlisted verdict,
safe public feedback, output excerpts, resource-limit flags, and echoed
digests. It discards extra fields and never accepts a score: points are derived
from the frozen pass rule after protocol validation. Logs contain IDs/digests
and aggregate timings, never source, fixtures, stdout/stderr, hidden tests, or
Auth material.

## Failure and shutdown behavior

- A claimed job has a short renewable database lease and attempt count.
- Process death lets the lease expire; another controller may re-run the
  deterministic job.
- Only the finalization RPC may create the immutable attempt and progress
  change; it is idempotent for the job.
- A learner verdict finalizes once. Infrastructure failure retries to the
  bounded ceiling without creating an attempt.
- Shutdown stops claiming work, terminates or drains within the fixed deadline,
  releases/lets leases expire, and never commits a partial result.
- Queue backlog, sandbox launch failures, limit verdict rates, manifest
  mismatches, deterministic mismatches, and orphan leases emit safe metrics.

## Authentication boundary

Fastify verifies the Supabase token, exact `aal2`, live security hold, and role
before it reserves a job. The grader controller and sandbox perform no
authentication. Supabase Auth continues to own registration, password login,
TOTP enrollment/challenge/verification, sessions, and factor state. No Auth
operation is implemented, proxied, or verified with Python/WASM.

## ARC-WASM-001 — Approve and pin the execution boundary

Prerequisites: PRD-WASM-001, ARC-DESIGN-001, FOUND-001, G1, and
OPS-VERCEL-001's reviewed public-API/private-grader topology.

- [x] Write ADR 0006 selecting the exact Pyodide/Python server bundle and
      developer-local outer proof launcher. Hosted launcher selection remains
      explicitly deferred to OPS-HOST-001 and user approval.
- [x] Commit the immutable local runtime lock manifest and prove a warm-cache
      offline local install/load. Full clean-cache provenance/SBOM/promotion is
      deliberately deferred to OPS-WASM-001.
- [x] Add the future grader-controller and the completed local proof harness to
      the ownership, composition, deployment, data-flow, and threat-model
      inventories without creating a public service or generic job framework.
- [x] Prove the local public-proof launcher enforces the reviewed network,
      secret, privilege, filesystem, process, resource, IPC, and teardown
      controls; worker-thread-only isolation remains rejected.
- [x] Specify and test the closed versioned public-proof request/result schema,
      including strict unknown-field and forged-digest rejection. The future
      authoritative schema remains governed by the protected contract above.
- [x] Specify future lease, retry, shutdown, overload, and
      deterministic-mismatch behavior; no job or finalization implementation is
      implied by this local proof.
- [x] Prove the local runner protocol contains no Auth/TOTP or database
      capability.

No Python code exercise may be published, accepted, or finalized from the local
proof. G-WASM remains closed until the later database, controller, API, QA, and
hosted-equivalence tasks pass.
