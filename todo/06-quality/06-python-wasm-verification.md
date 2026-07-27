# Python WASM verifier quality plan

## Deterministic fixtures

Commit small versioned golden bundles covering successful multi-file imports,
public/hidden failures, Unicode/source encoding, syntax/runtime errors, seeded
randomness, fixed logical time, hash-sensitive collections, and every resource
limit. Each fixture records source, definition, harness, runtime, test, and
expected canonical-result digests.

Run every golden input twice in fresh authoritative sandboxes. Verdict digests
must match exactly; timestamps and measured resource usage are compared only to
bounds. The future browser adapter must match server results for public tests
under the same manifest, but a parity match never makes browser grading
authoritative.

ADR 0006 contributes a narrow local public-proof regression suite: locked
asset/image checks, strict framing/digest rejection, deterministic public runs,
selected escape attempts, resource-result mapping, configuration inspection,
and detached-client cleanup. It contains no private test plan, controller,
database job, learner attempt, or finalization. It is evidence for the outer
boundary design, not a substitute for QA-WASM-001's authoritative suite.

## Adversarial matrix

Test at least:

- forged client `passed`, score, test report, runtime, user, and definition
  fields;
- absolute/traversal/backslash/dot/duplicate/case-collision/long/NUL/binary/
  archive/symlink-shaped packages;
- infinite loops, recursion, huge allocation, decompression bomb, file flood,
  stdout/stderr flood, thread/process flood, and deliberate worker crash;
- `js` bridge, `fetch`, WebSocket, socket, DNS, subprocess, shell, native host
  module, dynamic package install/import, environment, home/host filesystem,
  device, procfs, container socket, and metadata-service escape attempts;
- hidden-test introspection, traceback leakage, timing/output oracle, and result
  protocol smuggling;
- attempts to find the declarative hidden plan/expected values through Python
  globals, virtual files, `sys.modules`, frames/tracing, the `js` global object,
  exception text, or hidden-phase stdout/stderr;
- concurrent same/different idempotency keys, double claims, expired/stolen
  leases, controller death at each step, late result, repeated finalization,
  queue overload, retry exhaustion, and shutdown;
- a canary secret/token outside the sandbox plus a network sink proving the
  run cannot read or transmit it;
- scans proving TOTP seeds/codes/QR/`otpauth`, Auth tokens/responses, Supabase
  keys, learner source, and hidden tests are absent from logs/reports/artifacts.

Tests must prove denial by the outer sandbox even if Pyodide/JavaScript policy
checks are bypassed. A Node worker-thread-only test does not satisfy this gate.

## QA-WASM-001 — Prove authoritative, isolated, deterministic grading

Prerequisites: PRD-WASM-001, ARC-WASM-001, SUP-WASM-001, FAST-WASM-001, and
API-WASM-001.

- [ ] Pass all canonicalization, golden fixture, deterministic repeat, and
      future-browser/public-test parity cases.
- [ ] Pass the adversarial matrix with documented CPU/wall/memory/file/process/
      output ceilings and complete sandbox teardown.
- [ ] Prove only server finalization creates attempts/points/progress and every
      forged/provisional client result is ignored or rejected.
- [ ] Prove learner verdicts are stable and infrastructure failures never count
      against the learner.
- [ ] Prove hidden fixtures and all Auth/TOTP/server secrets remain
      inaccessible and absent from every observable surface.
- [ ] Run the suite from a clean checkout with network disabled after the
      pinned runtime assets are present.

Any sandbox escape, secret/network access, digest mismatch, nondeterministic
verdict, hidden-test leak, or client-authoritative result closes G-WASM and
cannot be waived for production.
