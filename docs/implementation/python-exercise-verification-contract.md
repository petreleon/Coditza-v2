# Python exercise verification contract

Status: accepted by PRD-WASM-001 on 2026-07-27.

This document freezes product semantics and credential-free vectors for Python
code exercises. It does not choose, download, install, or execute Pyodide or
Python; select an outer-sandbox launcher; create a controller; create a
database object; or prove a runtime boundary. Those actions remain owned by
ARC-WASM-001, SUP-WASM-001, FAST-WASM-001, API-WASM-001, and QA-WASM-001.

## Product scope and authority

Python code is one exercise type named python_code. It is never a quiz-question
type. Scalar exercise and quiz answer types remain single choice, multiple
choice, and short text.

A learner submits only a source-package object. A learner never submits a
score, points, pass flag, verdict, test report, runtime selection, definition,
user identity, progress value, factor data, or Auth result. A future browser
Worker may run safe public tests for educational feedback, but its result is
not an input to reservation, grading, finalization, attempt creation, points,
or progress. Only a fresh server-side authoritative run may produce a learner
verdict.

The authoritative finalizer derives full points for passed and zero points for
every other learner-caused verdict. It never accepts points or a score from the
HTTP client, browser, controller, or sandbox result.

## Canonical source-package version 1

### Accepted request shape

The sole normalized submission input is:

~~~json
{"files":[{"path":"main.py","content":"def solve(value):\n    return value\n"}]}
~~~

The outer object has exactly one property, files. Files is an array whose each
element has exactly path and content. Unknown top-level or file properties,
missing properties, non-string values, duplicate object members after JSON
parsing, or a non-array files value are rejected before reservation.

The client sends no canonicalization version or source hash. The server selects
version 1 and returns only safe reservation/status data.

### Validation algorithm

Apply these rules in this order. A later step is not evaluated after an earlier
rejection.

1. Decode the HTTP JSON body as valid UTF-8 JSON while rejecting duplicate
   member names at every object level and unpaired Unicode surrogate values.
   Malformed JSON, malformed UTF-8, duplicate members, or invalid Unicode
   scalar text is an HTTP validation failure and has no canonical form.
2. Require a root JSON object with exactly one member named files. Reject a
   non-object root as `top_level_not_object`, an absent files member as
   `missing_files`, and any other root member as `unknown_top_level_field`.
3. Require files to be an array of from 1 through 16 descriptors; reject a
   non-array as `files_not_array` and an out-of-range count as
   `file_count_exceeded`.
4. Require every array element to be an object with exactly path and content.
   Reject a non-object as `file_not_object`, a missing required member as
   `missing_file_field`, and any other member as `unknown_file_field`. Require
   both members to be strings; use `path_not_string` or `content_not_string`.
5. For every path, require a string that is ASCII and from 1 through 160 bytes.
   Reject non-ASCII text as `path_not_ascii` and a length outside that range as
   `path_length_exceeded` before evaluating later path rules.
6. For a path that passed step 5, apply these structural checks in this exact
   order: NUL (`path_contains_nul`), reverse solidus (`path_backslash`),
   leading slash (`path_absolute`), an empty slash-delimited segment
   (`path_empty_segment`), dot segment (`path_dot_segment`), dot-dot segment
   (`path_dot_dot_segment`), a character outside letters/digits/underscore/
   hyphen/dot/slash (`path_not_allowed_character`), then a suffix other than
   exact lowercase `.py` (`path_not_python_suffix`).
7. Require content to be a valid Unicode scalar text string with no NUL. Its
   UTF-8 encoding is preserved exactly; BOM code points, encoding-cookie text,
   line endings, spaces, tabs, and Unicode source characters are not
   normalized. An encoding cookie is ordinary source text: it cannot trigger a
   transport/package transcode. If the selected pinned interpreter rejects the
   exact bytes and cookie combination, that later run is `syntax_error`, not a
   package-validation failure. The future harness writes the exact UTF-8 bytes
   and never uses a host-default decoder.
8. Measure content in UTF-8 bytes. Each file is at most 65,536 bytes and the
   aggregate is at most 262,144 bytes. Empty text is valid input and may later
   receive a syntax/test verdict; it is not rejected merely for being empty.
9. Reject duplicate paths both byte-for-byte and after ASCII-only case folding.
   ASCII case folding maps A through Z to a through z; it does not normalize
   Unicode because paths are ASCII only.
10. Sort accepted descriptors by unsigned UTF-8 path bytes ascending. Because
   paths are ASCII, this is also ordinary bytewise ASCII order.
11. Form the canonical package object with exactly the sorted files array and
    v set to integer 1, then serialize it with RFC 8785 JSON canonicalization.
    The exact content string remains byte-for-byte equivalent when UTF-8
    encoded.

The runner creates fresh regular files from this validated canonical package in
a per-run virtual directory. It never extracts an archive, follows a link, or
uses a learner-provided filesystem object. A JSON source package cannot declare
an archive, link, device, or any other filesystem object because the descriptor
shape is closed at step 4.

### Digest rules

Let packageBytes be the UTF-8 RFC-8785 canonical JSON bytes of the normalized
package object that includes v=1. The source package digest is:

~~~text
SHA-256(UTF8("coditza-python-source-package-v1.") || packageBytes)
~~~

For a Python grading reservation, define idempotencyEnvelope exactly as:

~~~json
{
  "input": {"files": []},
  "operation": "python_grading_reserve",
  "resourceId": "<exercise UUID>"
}
~~~

The input member is exactly the normalized sorted files object, without the
internal source-package v member and without the original file order. Let
idempotencyBytes be the UTF-8 RFC-8785 canonical JSON bytes of that envelope.
Canonicalization version 1 computes:

~~~text
SHA-256(UTF8("coditza-idempotency-v1.") || idempotencyBytes)
~~~

At the reservation transaction, the replay key is scoped to the verified
authenticated actor, operation, and Idempotency-Key. Within that actor namespace,
a repeated key with this same exercise UUID and digest replays the stored
reservation; a changed normalized package or resource UUID conflicts. The actor
is a database scoping value, not a member of the digest envelope, source/verdict
canonical bytes, or sandbox request. The idempotency key itself never enters the
sandbox request.

## Frozen authored definition

A published python_code exercise has one complete immutable private definition.
It contains only the following semantic categories:

- entry-point module and function contract;
- safe starter files;
- safe public test descriptions and safe public fixtures;
- a closed declarative private case plan, never arbitrary hidden Python source;
- exact full-points pass rule;
- verifier contract version;
- fixture contract version;
- runtime profile identifier and runtime-manifest digest;
- test-fixture digest;
- allowed package identifiers already present in the future pinned bundle; and
- wall, CPU, memory, file, process, and output limits at or below the approved
  runtime profile.

Choice options and scalar answer keys are forbidden for python_code. Publishing
fails unless this definition is complete and digest-pinned. Learner projections
may contain starter files, public descriptions/fixtures, entry point, safe
limits, and non-secret runtime metadata. They never contain private case plan
content, expected values, hidden test counts/digests, harness source, private
tracebacks, or internal import allowlists.

This contract selects no runtime, package, asset digest, launcher, or limit
implementation. ARC-WASM-001 must select and prove them while preserving these
semantics.

## Closed authoritative runner protocol

The future learner-facing controller-to-sandbox runner request has exactly
these semantic fields:

| Field | Purpose | Must not contain |
| --- | --- | --- |
| protocolVersion | Versioned closed runner protocol. | Runtime/package selection from a learner. |
| jobId | Random opaque job correlation value. | User identity or idempotency key. |
| files | Validated canonical learner package. | Archive, links, hidden data, result assertion. |
| entryPoint | Frozen module/function contract. | Arbitrary import or command capability. |
| publicCasePlan | Safe public test inputs/descriptions. | Private expected values. |
| limits | Frozen non-secret resource profile. | A client override. |
| digests | Submission, definition, fixture, harness, and runtime-manifest digests. | A raw runtime asset or mutable version choice. |

A separate trusted harness-initialization channel supplies the frozen closed
private case plan only after digest agreement. It is not a field in the
learner-facing runner request or result, not a generic database/network channel,
and not a learner capability. The worker bootstrap keeps private cases and
expected values in a trusted host-side lexical closure, never in the learner
virtual filesystem, Python globals, environment, standard input/output,
JavaScript global object, exception text, log, report, artifact, or public
output. A private test source program is not an allowed definition artifact.
ARC-WASM-001 and SUP-WASM-001 must choose and prove the exact protected
handoff; this semantic task selects no mechanism.

The future sandbox-to-controller result is also closed. It has a protocol
version, one result kind, the five echoed digests, an allowlisted learner
verdict or allowlisted infrastructure code, bounded safe public feedback,
bounded sanitized public/compile output, and limit flags. Unknown fields are
rejected. It cannot contain points, score, pass flag supplied separately,
user/role/session identity, raw source or an echo of the submitted package,
hidden test content/count/timing, private traceback, database row, idempotency
key, credential, or Auth response.

Result sanitization strips raw code, source lines and caret/code frames, local
paths, environment values, private expected values, hidden-case identifiers,
and private traceback frames before any bounded safe public/compile output is
accepted. Its exact output limits and sanitizer implementation remain later
runtime/controller work.

The finalizer validates exact status/lease/protocol/digest agreement before it
derives points. A client-shaped result, unknown result kind, unknown verdict,
extra digest, missing digest, mismatched digest, oversized field, or forbidden
field is an infrastructure/protocol failure, never a learner score.

## Learner verdicts and infrastructure outcomes

| Result class | Allowlisted values | Attempt / progress effect | Public treatment |
| --- | --- | --- | --- |
| Learner terminal verdict | passed | One immutable full-points attempt; progress recalculated once. | Safe passed feedback only. |
| Learner terminal verdict | tests_failed, syntax_error, runtime_error, time_limit_exceeded, memory_limit_exceeded, output_limit_exceeded | One immutable zero-points attempt; progress recalculated once. | Allowlisted verdict plus bounded safe public/compile feedback only. |
| Infrastructure outcome | sandbox launch/init failure, runner protocol violation, runtime asset missing/mismatch, internal harness failure, dependency outage, controller crash/lease loss, canonical-result mismatch | Retry under the original reservation or eventually mark dead. Never create an attempt, award zero, or mutate progress. | Generic retryable/unavailable outcome; no hidden detail. |
| Security/protocol rejection | Unknown/malformed/extra field, forged digest, invalid lease, arbitrary score, client-shaped result | Reject or retry/dead according to controller policy. Never create an attempt or progress mutation. | Generic safe error only. |

A dead grading job is an operational incident, not an incorrect learner
attempt. It may be requeued only through an audited operational path. Repeated
finalization of a valid completed job returns its stored safe result and does
not duplicate the attempt or progress mutation.

### Deterministic classification precedence

Infrastructure/protocol failure takes precedence over every learner verdict.
For a valid learner run, any canonical resource-limit flag wins over a
syntax/runtime/test observation. If one or more such flags exist, derive exactly
one verdict in this fixed order: memory_limit_exceeded, then
output_limit_exceeded, then time_limit_exceeded. The later runtime maps either
wall- or CPU-budget exhaustion to `time_limit_exceeded`; it may not introduce a
new learner verdict. Only when no canonical resource-limit flag exists, classify
syntax_error, then runtime_error, then tests_failed or passed from the closed
authoritative case result. The controller records all observed limit flags as
non-canonical diagnostics, but derives one verdict using this order. This
prevents a timing race between parent-side limit signals from changing a
learner's canonical verdict.

## Deterministic fixture profile

The fixture contract version is coditza-python-fixture-v1. Every authoritative
harness must use the following logical values:

| Field | Value |
| --- | --- |
| random seed | 1729 |
| hash seed where the selected runtime supports it | 1729 |
| timezone | UTC |
| locale | C |
| newline policy for harness output | LF |
| logical fixture clock | 2000-01-01T00:00:00Z |

Tests may not depend on wall-clock time, network, host locale, host filesystem
iteration order, external state, unseeded randomness, measured timing, or
platform-specific paths. Resource measurements and timestamps are presentation
or observability data and are excluded from the canonical verdict digest.

If the exact later runtime cannot enforce any required fixture property,
ARC-WASM-001 must stop and record a reviewed change. It may not silently relax
determinism.

## Canonical learner verdict digest

For a learner terminal verdict, form this exact canonical object:

~~~json
{
  "v": 1,
  "definitionDigest": "<64 lowercase hexadecimal SHA-256>",
  "fixtureDigest": "<64 lowercase hexadecimal SHA-256>",
  "harnessDigest": "<64 lowercase hexadecimal SHA-256>",
  "runtimeManifestDigest": "<64 lowercase hexadecimal SHA-256>",
  "submissionDigest": "<64 lowercase hexadecimal SHA-256>",
  "verdict": "passed"
}
~~~

Serialize it with RFC 8785 and calculate:

~~~text
SHA-256(UTF8("coditza-python-verdict-v1.") || canonicalVerdictBytes)
~~~

Only the seven learner terminal values may appear in verdict. Safe feedback,
safe output, resource measurements, timestamps, job ID, lease, retry count,
and public-test presentation are excluded from this digest. Two fresh
authoritative workers with the same five input digests and learner verdict must
produce the same canonical verdict digest. A mismatch is an infrastructure
incident, not a learner verdict.

## Auth, TOTP, and database exclusion

The intended capability flow is:

~~~text
direct Supabase Auth
  -> Fastify verifies token/AAL2/role/security hold
  -> assessment reservation facade
  -> private grading job
  -> narrow assessment queue adapter in private controller
  -> secret-free sandbox protocol
  -> assessment finalization facade
~~~

Fastify may pass a verified actor to the reservation transaction, and the
database job may retain its actor for ownership. Before runner construction, all
actor/Auth/database capability is stripped. The controller may use its narrow
assessment queue/finalization adapter, but it has no Auth/TOTP operation,
Fastify import, API-root import, exposed raw Supabase client, or raw-client
escape.

The untrusted learner-facing sandbox protocol, environment, filesystem,
standard input/output, result, logs, metrics, fixtures, reports, and artifacts
must not contain:

- user ID, email, role, session ID, JWT, Authorization header, password,
  refresh token, or complete Auth response;
- TOTP code, seed, factor, challenge, QR data, manual secret, or otpauth URI;
- Supabase URL/key, database row, database credential, raw client, or
  idempotency key;
- server/cloud/CI/registry secret, host path, socket, package-download
  capability, or network credential; and
- hidden tests, private expected values, private traceback, or hidden-phase
  stdout/stderr.

The future import-boundary fixture BND-008 and protocol schema fixtures must
prove these exclusions. Platform-generated logs/artifacts are scanned; learner
source itself is not rejected merely because it contains ordinary words that
resemble sensitive terms.

## Future browser preview boundary

A future approved browser Worker may run only public tests with the safe
projection. It must never submit a result, test report, runtime selection,
definition, score, points, pass flag, user ID, or progress assertion to an
authoritative endpoint. The browser preview does not establish identity or MFA
and does not receive Auth material in its Python worker.

## Work assigned later

| Task | Owns after this semantic contract |
| --- | --- |
| ARC-WASM-001 | Exact Pyodide/Python assets, runtime manifest, outer sandbox, protocol implementation, and launcher proof. |
| SUP-WASM-001 | Private definition/job/evidence persistence, grants, leases, reserve/claim/finalize functions, retention. |
| FAST-WASM-001 | Controller process, narrow ports/adapters, backpressure, shutdown, and result validation. |
| API-WASM-001 | AAL2 HTTP schemas, reservation/status routes, owner concealment, idempotency, and forged-result rejection. |
| QA-WASM-001 | Actual deterministic double-run, sandbox escape/resource/network/secret, hidden-test, lease/retry, and end-to-end proof. |

This task proves only that the contract is explicit and testable with
credential-free vectors. It does not claim an authoritative run is implemented
or isolated yet.
