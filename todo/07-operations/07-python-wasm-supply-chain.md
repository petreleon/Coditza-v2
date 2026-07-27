# Python WASM runtime supply chain and CI

## OPS-WASM-001 — Pin, scan, and promote one verifier

Prerequisites: ARC-WASM-001 and QA-WASM-001.

- [ ] Verify every Pyodide/Python/standard-library/package/harness/worker/image
      asset against `python-wasm-runtime.lock.json`; forbid CDN and runtime
      downloads.
- [ ] Generate and review an SBOM, licenses, and vulnerability findings for the
      API, grader controller, sandbox image, Pyodide distribution, and every
      bundled Python package.
- [ ] Build the runtime bundle reproducibly and fail on any unexplained asset,
      manifest, generated fixture, or image-digest drift.
- [ ] Run the offline golden/adversarial suite, outer-sandbox policy tests,
      deterministic double-run, queue crash/retry suite, and safe artifact scan
      before the ordinary image smoke gate.
- [ ] Sign/attest the exact runtime-manifest digest with the release provenance
      supported by the selected platform.
- [ ] Record and machine-check the release invariant that later hosted tasks
      must promote the identical API/controller/sandbox image and runtime asset
      digests; never rebuild or fetch packages in a deployment.
- [ ] Record a rollback-compatible previous manifest/image set and exercise a
      verifier rollback without changing historical attempt evidence.
- [ ] Block deployment when the target cannot enforce no-network, secret-free,
      read-only, non-root, resource-limited disposable sandboxes.

CI reports contain fixture IDs and digests only. They must not upload learner
source, hidden test bodies, stdout/stderr, Supabase credentials, JWTs, or
Auth/TOTP artifacts.
