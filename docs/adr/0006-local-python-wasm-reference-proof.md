# ADR 0006 — Local Python/WASM reference proof

- Status: Accepted for a developer-local reference proof only
- Date: 2026-07-27
- Decision owners: Coditza architecture
- Related: ARC-WASM-001, DEC-032, ADR 0005, PRD-WASM-001, OPS-HOST-001,
  OPS-WASM-001, SUP-WASM-001, FAST-WASM-001, API-WASM-001, QA-WASM-001

## Context

Pyodide runs CPython in WebAssembly, but Pyodide, JavaScript, Node worker
threads, and Node WASI are not security boundaries for untrusted learner code.
ADR 0005 therefore requires a disposable outer boundary and allows this task to
prove a local reference only. It does not authorize a private hosted provider,
controller, deployment, or credentials.

The first implementation must also avoid a misleading shortcut: repository
source cannot be treated as a private test plan. A local proof may exercise
public synthetic vectors and the outer isolation controls, but cannot claim to
be an authoritative hidden-test/finalization pipeline before the protected
definition/job/controller work exists.

## Decision

### Exact local runtime

The repository locks the runtime in
[`python-wasm-runtime.lock.json`](../../python-wasm-runtime.lock.json):

- `pyodide@314.0.3` (MPL-2.0), embedded CPython runtime `3.14.2`, ABI Python
  `3.14.0`, ABI `2026_0`, and `wasm32` / `emscripten_5_0_3` metadata;
- Node `24.18.0` and one pinned `linux/arm64` base-image digest;
- SHA-256 values for Pyodide loader/WASM/stdlib/metadata assets, the runner,
  policy, static seccomp profile, native source/binary, libseccomp binary, and
  every corresponding file inside the locked image; and
- the fixed `python-basic-v1` limits: 15 s bootstrap, 5 s learner wall, 3 s
  learner CPU, 256 MiB memory/swap, 16 PIDs, 8 MiB/128-inode Docker tmpfs,
  16 source files, 256 KiB source, 64 KiB output, and 128 KiB result.

`runtimeFetchAllowed` is false and allowed external Python packages are empty.
The build command derives the real embedded CPython version from a local
Pyodide load rather than inferring it from ABI metadata. It records both values
because the distribution's ABI metadata is intentionally `3.14.0` while
`sys.version` is `3.14.2`.

This is a reference lock, not a production provenance/SBOM/rollback record.
OPS-WASM-001 owns those later supply-chain obligations.

### Developer-local launcher only

`scripts/python-wasm/local-launch-broker.mjs` is a **developer-local proof
harness**, not a future controller adapter or service. It has Docker CLI
authority only because it is run directly by the local developer to prove the
container controls. It has no listener, database, queue, lease, HTTP route, or
application import. FAST-WASM-001 must not import it or grant a future
controller Docker CLI/socket authority.

Before each run the harness:

1. requires the active Docker context to resolve to an existing local Unix
   socket, rejecting TCP/SSH/remote endpoints;
2. hashes the static seccomp file and verifies the exact pinned image ID plus
   image-side runner/policy/native/Pyodide hashes against the lock;
3. accepts only a closed request with trusted input/runtime/harness digests;
4. creates one uniquely named, auto-removed container with a fixed argument
   vector; and
5. inspects that container before authorizing learner execution, returning only
   a safe configuration projection and confirming removal by exact name.

No caller can provide an image, command, mount, port, device, environment,
Docker context, profile, container name, or host path.

The fixed run has non-root `65532:65532`, `--network none`, `--ipc none`, a
read-only root, `--cap-drop ALL`, `no-new-privileges:true`, a static seccomp
profile, no ports/devices/DNS/hosts/binds/volumes, no restart, Docker log driver
`none`, `--pull=never`, and one `/work` tmpfs. `/work` is a Docker bound for
trusted process scratch; it is not claimed to bound Pyodide's in-memory MEMFS.
The current profile is stricter for learner code: after trusted source placement
it denies every learner virtual-filesystem mutation.

### Bootstrap, gate, and lifecycle

The container starts Node directly through `env -i`; the actual runner process
gets only fixed non-secret locale/home/timezone values. It starts a Pyodide
worker before learner input. The main Node thread stays trusted and owns the
in-container bootstrap and learner-wall timers, so synchronous learner Python
cannot block that watchdog thread.

The Pyodide worker first loads only trusted local assets. It passes an explicit,
secret-free Pyodide environment with `PYTHONHASHSEED=1729`, seeds Python
`random`, denies unseeded entropy, fixes ordinary `time`/`datetime` values to
`2000-01-01T00:00:00Z`, and then loads the native libseccomp Node-API gate.
The gate sets/verifies `no_new_privs`, applies a TSYNC filter, verifies the
filter increment, and runs denial probes. The pre-existing worker repeats a
post-gate native denial probe before `ready` is emitted, proving TSYNC reached
that thread too.

The static Docker profile keeps bootstrap viable while denying ordinary process
creation and sockets. It forces `io_uring_setup` to return `ENOSYS` so libuv
chooses its safe fallback before the permanent post-bootstrap gate denies
io_uring, process, exec, socket/network, filesystem mutation, namespace/mount,
tracing, and related privileged operations. This uses Linux seccomp/libseccomp,
not Node's Permission Model. See [Linux seccomp filter documentation](https://docs.kernel.org/userspace-api/seccomp_filter.html),
[libseccomp TSYNC attributes](https://man7.org/linux/man-pages/man3/seccomp_attr_set.3.html),
[Docker seccomp](https://docs.docker.com/engine/security/seccomp/), and
[Node-API](https://nodejs.org/api/n-api.html).

The internal watchdog is started before Pyodide bootstrap. A second parent-side
timer remains defense in depth. A test kills the attached Docker client after a
learner run begins and confirms the container exits and auto-removes by the
in-container deadline; no broker-liveness assumption is used.

### Closed public-proof protocol

The local protocol version remains `coditza-python-runner-v1`, but its result
kind is deliberately `local_public_proof`, never `learner_verdict`. It cannot
be passed to future finalization. The runner accepts exactly two UTF-8 frames:
a strict JSON request and the fixed `CODITZA_RUN` release frame after the
harness has inspected the container. Duplicate JSON members, unknown/missing
fields, excessive nesting, case-colliding file paths, NUL source, wrong limits,
or malformed control frames fail closed.

The harness binds all five digest names before launch:

- synthetic public source/entry-point, public-definition, and fixture digests
  are re-derived from canonical local proof inputs;
- harness digest is derived from locked runner/policy/native/static-profile
  hashes; and
- runtime-manifest digest is the exact local lock-file byte hash.

The runner must echo every value exactly. The broker validates the closed
result and rejects a forged or inconsistent echo/limit flag. The local digest
format is scoped to this proof and must not be presented as the future
assessment's canonical protected-definition or verdict format.

There is no private case plan in source, runtime input, filesystem, globals, or
result. The current public proof deliberately runs only declared public cases.
SUP-WASM-001 and FAST-WASM-001 must later introduce the protected definition,
sealed private-plan handoff, hidden-output hashing/discard, lease, retry, and
finalization protocol.

## Evidence

`npm run build:wasm-local` rebuilds and relocks the image. `npm run test:wasm`
verifies host and image-side hashes, a warm-cache `npm ci --offline` local load,
strict parsing, digest binding, deterministic fresh public runs, syntax/output/
CPU-wall result mapping, no inherited canary, no `js.process`, denied learner
MEMFS write/entropy/socket attempt, Docker configuration inspection, exact
cleanup, and detached-client watchdog cleanup. The cache proof is deliberately
not an air-gapped clean-cache/supply-chain claim.

## Consequences

- DEC-032 is **partially resolved**: an exact local reference boundary exists,
  while the hosted private launcher/provider remains unselected.
- No Vercel, Supabase, Chrome, SMTP, deployment, account, region, tier, cost,
  hosted environment variable, or credential was created or changed.
- The local harness does not establish a future controller's OS-level authority
  separation. That must be designed with the approved private host and proven
  by FAST-WASM-001/OPS-HOST-001.
- No Python exercise may be published, accepted, or finalized from this proof.
  G-WASM remains closed until the remaining SUP/FAST/API/QA/OPS tasks pass.

## Hosted handoff

OPS-HOST-001 may select a provider only after its named prerequisites and
explicit user approval. It must independently prove equivalent or stronger
fresh isolation, no egress/DNS, no secrets/mounts/sockets, non-root/no
privilege escalation, immutable locked assets, resource/queue bounds, safe
logging, controller authority separation, teardown, and rollback identity. A
local Docker result never transfers automatically to a hosted execution plane.
