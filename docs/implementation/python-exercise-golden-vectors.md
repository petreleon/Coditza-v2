# Python exercise canonical golden vectors

Status: accepted by PRD-WASM-001 on 2026-07-27.

These vectors contain only synthetic source text and synthetic digest inputs.
They are normative for future HTTP validation, application/domain validation,
database reservation, controller protocol validation, and test suites. They do
not require a Python runtime to execute.

## Shared constants

All SHA-256 values are lowercase hexadecimal. The following synthetic frozen
definition inputs are used only for verdict-digest vectors:

| Name | SHA-256 |
| --- | --- |
| definitionDigest | 659b0e0d686da8afc311ae289f6ea3f46760bc5350fcec902a48ead1d850fd2a |
| fixtureDigest | fc1c0e0c7ae8690bf702ade724d2543f81603a03b3956338f76ddef54ad713b9 |
| harnessDigest | 224dc4b45477c7504b8db52a2fd8d810212637232ee7a96d37c5113095927319 |
| runtimeManifestDigest | 602c2f7e2c8d9a937c613dac0c0bb2d056e1d04b363234073378cc8bf3be8b0e |
| exercise resourceId | 11111111-1111-4111-8111-111111111111 |
| operation | python_grading_reserve |

These are test values, not runtime selection or evidence of an installed
asset.

## Valid canonical source vectors

### SRC-001 — one file and reservation hash

Input object:

~~~json
{"files":[{"path":"main.py","content":"def solve(value):\n    return value\n"}]}
~~~

Expected canonical package JSON:

~~~json
{"files":[{"content":"def solve(value):\n    return value\n","path":"main.py"}],"v":1}
~~~

| Assertion | Expected value |
| --- | --- |
| source package digest | 647eb4dfb4c5e44d5a22b989e5e7cb8231c4375fd604260c6847c463c837c214 |
| canonical idempotency envelope | {"input":{"files":[{"content":"def solve(value):\n    return value\n","path":"main.py"}]},"operation":"python_grading_reserve","resourceId":"11111111-1111-4111-8111-111111111111"} |
| canonical idempotency request hash | 520834f5b90c9f21b866c627d5e221a57364d9149bfc9bba9501b69d7747588b |
| result before server run | valid reservation input only; no score, verdict, attempt, or progress value |

### SRC-002 — input order normalizes by path bytes

Input object is intentionally unsorted:

~~~json
{
  "files": [
    {"path":"z.py","content":"Z = 1\n"},
    {"path":"lib/helper.py","content":"def plus(a, b):\n    return a + b\n"},
    {"path":"main.py","content":"from lib.helper import plus\n"}
  ]
}
~~~

Expected canonical package JSON:

~~~json
{"files":[{"content":"def plus(a, b):\n    return a + b\n","path":"lib/helper.py"},{"content":"from lib.helper import plus\n","path":"main.py"},{"content":"Z = 1\n","path":"z.py"}],"v":1}
~~~

Expected source package digest:

~~~text
67aa2a65b1334b97dc30a102a08370afb333cc5d3ab7f8a622fd63eca000b68b
~~~

The same three files supplied in the canonical order have exactly this same
package digest and same normalized idempotency input. Original array order is
not grading evidence.

### SRC-003 — Unicode source is preserved, ASCII path remains required

Input object:

~~~json
{"files":[{"path":"main.py","content":"mesaj = \"șir\"\n"}]}
~~~

Expected canonical package JSON:

~~~json
{"files":[{"content":"mesaj = \"șir\"\n","path":"main.py"}],"v":1}
~~~

| Assertion | Expected value |
| --- | --- |
| source package digest | fc7e8127a8c3f7f462cc2d3ef6ffe4498e00d70ea7eaa6163488c8a17c167bc1 |
| source encoding rule | The UTF-8 text is preserved exactly; no NFC/NFKC, case, whitespace, or newline normalization occurs. |

### Boundary-valid generators

The following exact generated inputs are valid and must be accepted:

| Vector | Exact generator | Expected result |
| --- | --- | --- |
| SRC-004 | SRC-001 with CRLF in place of each LF. | Valid and distinct source digest db43360e4c4931fd83a86dcded74f8b75b073ae76e6aff4d96dc1472da2401ef. |
| SRC-005 | One descriptor main.py, content equal to label = "é" followed by LF. | Valid source digest f6e2af475cd5a8aab97fe49cf30d4cf3787d6854cff13184204007ef5b18c543. |
| SRC-006 | One descriptor main.py, content equal to label = "é" followed by LF, using e plus U+0301. | Valid and distinct source digest 67cdb78ad1252a403d68c81cffc9834adc55d315aa47b75c8888eb1027253a18. |
| SRC-007 | Empty main.py content. | Valid source digest 10cbc3fd510a3127c2b43eaa1c100cc6d04caf92ab504bba3d88a1fd029cd3e2. |
| SRC-008 | One descriptor path main.py, content equal to 65,536 ASCII A characters. | Valid; per-file byte ceiling is inclusive. |
| SRC-009 | Four descriptors a.py through d.py, each content equal to 65,536 ASCII A characters. | Valid; aggregate 262,144-byte ceiling is inclusive. |
| SRC-010 | Sixteen descriptors with paths f01.py through f16.py, each with empty content. | Valid; file-count ceiling is inclusive. |
| SRC-011 | One empty descriptor with path equal to 156 ASCII `a` characters followed by `.py` (160 bytes total). | Valid; path-byte ceiling is inclusive. |

The generator description is exact test data: ASCII A means U+0041, and empty
content means the zero-length UTF-8 string.

## Rejection vectors

All vectors below fail before queue reservation, runner invocation, attempt
creation, or progress calculation. The rejection reason is an internal stable
validator category; HTTP/API tasks map it to the approved public validation
response without exposing implementation detail.

| Vector | Input or exact generator | Expected rejection reason |
| --- | --- | --- |
| VLD-001 | A valid SRC-001 body plus top-level property passed with boolean true. | unknown_top_level_field |
| VLD-002 | A valid descriptor plus descriptor property score with integer 100. | unknown_file_field |
| VLD-003 | One path ../main.py. | path_dot_dot_segment |
| VLD-004 | One path /main.py. | path_absolute |
| VLD-005 | Raw transport body with path string `"lib\\main.py"` (one decoded reverse-solidus), for example `{"files":[{"path":"lib\\main.py","content":""}]}`. | path_backslash |
| VLD-006 | One path lib//main.py. | path_empty_segment |
| VLD-007 | One path ./main.py. | path_dot_segment |
| VLD-008 | One path Main.PY. | path_not_python_suffix |
| VLD-009 | One path main.txt. | path_not_python_suffix |
| VLD-010 | One path maîn.py. | path_not_ascii |
| VLD-011 | One path main\u0000.py. | path_contains_nul |
| VLD-012 | One path main.py and content containing U+0000. | content_contains_nul |
| VLD-013 | Two descriptors with exact same path main.py. | duplicate_path |
| VLD-014 | Two descriptors with paths Main.py and main.py. | duplicate_path_ascii_case_fold |
| VLD-015 | Seventeen descriptors f01.py through f17.py, each with empty content. | file_count_exceeded |
| VLD-016 | One descriptor main.py with content equal to 65,537 ASCII A characters. | file_size_exceeded |
| VLD-017 | Four descriptors a.py through d.py with 65,536 ASCII A characters plus e.py with one ASCII A character. | total_size_exceeded |
| VLD-018 | One path equal to 157 ASCII `a` characters followed by `.py` (161 bytes total). | path_length_exceeded |
| VLD-019 | Zero file descriptors. | file_count_exceeded |
| VLD-020 | One descriptor with non-string content, such as numeric 1. | content_not_string |
| VLD-021 | JSON input containing malformed UTF-8 before parsing. | malformed_utf8_json |
| VLD-022 | An otherwise-valid descriptor plus `kind:"archive"`, `symlink:true`, or another link/device/archive-like extra property. | unknown_file_field |
| VLD-023 | Raw transport body exactly `{"files":[],"files":[]}`. | duplicate_json_member |
| VLD-024 | Raw transport body with an escaped unpaired high or low surrogate in path or content, for example `{"files":[{"path":"\uD800.py","content":""}]}`. | invalid_unicode_scalar |
| VLD-025 | A JSON array or scalar at the root rather than an object. | top_level_not_object |
| VLD-026 | Object `{}` with no `files` member. | missing_files |
| VLD-027 | Object `{"files":{}}` where files is not an array. | files_not_array |
| VLD-028 | A file descriptor object missing `path` or `content`. | missing_file_field |
| VLD-029 | A `files` array element that is not an object. | file_not_object |
| VLD-030 | One descriptor with a non-string path, such as numeric 1. | path_not_string |
| VLD-031 | Raw transport body with invalid JSON grammar, for example `{"files":[}`. | malformed_json |
| VLD-032 | One descriptor main.py with content equal to 32,769 copies of `é` (65,538 UTF-8 bytes). | file_size_exceeded |
| VLD-033 | Raw transport body exactly `{"files":[{"path":"main.py","path":"main.py","content":""}]}`. | duplicate_json_member |
| VLD-034 | One path main!.py. | path_not_allowed_character |

VLD-005 uses a JSON-escaped reverse-solidus that decodes to one path character.
VLD-011 and VLD-012 use an escaped U+0000 JSON representation. No vector is
interpreted by extracting an archive or creating a host filesystem entry.

## Canonical learner-verdict vectors

For every learner verdict below, use the SRC-001 submission digest and the four
shared synthetic digests. Form the canonical verdict object defined by the
verification contract, apply RFC 8785, prefix it with
coditza-python-verdict-v1., then SHA-256 the resulting UTF-8 bytes.

| Vector | Verdict | Attempt / points | Progress | Expected canonical verdict digest |
| --- | --- | --- | --- | --- |
| VRD-001 | passed | Create exactly one immutable attempt with full frozen points. | Recalculate exactly once. | 6edbe59f028f1524fa342ec01fc15d274196a54d01324e2ea3c8b51e1b11fb79 |
| VRD-002 | tests_failed | Create exactly one immutable attempt with zero points. | Recalculate exactly once. | f81d6b4d66040b7e0a3d211e3dd5dcf5d889f1c3f84257588f8dbcd5101c85fb |
| VRD-003 | syntax_error | Create exactly one immutable attempt with zero points. | Recalculate exactly once. | 38b9f0e597e52bb03380297053df67687d43edef6817e5abec730302c3d4e9a1 |
| VRD-004 | runtime_error | Create exactly one immutable attempt with zero points. | Recalculate exactly once. | 916a074aee59c18c0b56afdf3086671fccc712285130b610ac1014fda205deed |
| VRD-005 | time_limit_exceeded | Create exactly one immutable attempt with zero points. | Recalculate exactly once. | 1e6edb8ade415044767d34bda0a0055b69bd31946465eb4705b75b9cba4c3cf9 |
| VRD-006 | memory_limit_exceeded | Create exactly one immutable attempt with zero points. | Recalculate exactly once. | 334a18dcd1b11205d8525ddc820e54c44bd5f67c6dc7a3af1925a873ba36040f |
| VRD-007 | output_limit_exceeded | Create exactly one immutable attempt with zero points. | Recalculate exactly once. | 98fe6ad9e5fecfbd90d1eddf3694fe39c6ed5aebacbe5457e1bd1efa3b0ff6b1 |

The canonical result object for VRD-001 is:

~~~json
{"definitionDigest":"659b0e0d686da8afc311ae289f6ea3f46760bc5350fcec902a48ead1d850fd2a","fixtureDigest":"fc1c0e0c7ae8690bf702ade724d2543f81603a03b3956338f76ddef54ad713b9","harnessDigest":"224dc4b45477c7504b8db52a2fd8d810212637232ee7a96d37c5113095927319","runtimeManifestDigest":"602c2f7e2c8d9a937c613dac0c0bb2d056e1d04b363234073378cc8bf3be8b0e","submissionDigest":"647eb4dfb4c5e44d5a22b989e5e7cb8231c4375fd604260c6847c463c837c214","v":1,"verdict":"passed"}
~~~

Safe feedback, safe output, resource measurements, timestamps, job ID, lease,
and retry count are deliberately absent from every canonical verdict digest.

## Infrastructure and protocol vectors

These are never learner verdicts and must never create an attempt, award zero
points, or change progress.

| Vector | Synthetic event | Required outcome |
| --- | --- | --- |
| INF-001 | Sandbox launch or initialization fails. | Retryable infrastructure failure; generic safe availability outcome. |
| INF-002 | Runner emits malformed JSON or an unknown field. | Protocol failure; retry/dead handling only. |
| INF-003 | One echoed digest differs from the claimed frozen digest. | Digest-mismatch incident; no finalization attempt. |
| INF-004 | Runner includes points, score, passed flag, or a client-shaped result. | Reject as protocol/security failure; no learner result. |
| INF-005 | Harness internal assertion fails. | Retryable internal harness failure; no learner attempt. |
| INF-006 | Required pinned dependency/runtime asset is unavailable or mismatched. | Retryable dependency/runtime failure; no learner attempt. |
| INF-007 | Lease is stale, stolen, or controller dies before finalization. | Lease/retry handling only; repeated job remains deterministic. |
| INF-008 | Two fresh workers produce different canonical verdict digests for equal five input digests. | Determinism incident; no learner attempt from the inconsistent run. |
| INF-009 | Retry ceiling is exhausted. | Mark job dead with generic support outcome; no learner attempt. |
| INF-010 | Valid runner result reports both memory and output flags. | Learner verdict is memory_limit_exceeded by fixed precedence. |
| INF-011 | Valid runner result reports output and time flags but no memory flag. | Learner verdict is output_limit_exceeded by fixed precedence. |
| INF-012 | Valid runner result reports one time-limit flag and a syntax observation. | Learner verdict is time_limit_exceeded; any canonical resource flag wins. |

## Forged-client and sensitive-boundary vectors

| Vector | Attempted input/surface | Expected result |
| --- | --- | --- |
| SEC-001 | Reservation body adds passed, score, verdict, testResults, runtimeVersion, userId, definition, or progress. | HTTP schema rejects before queue reservation. |
| SEC-002 | Browser preview sends a public-test pass report. | No authoritative endpoint accepts it; no queue/finalizer path exists. |
| SEC-003 | A runner request includes actor, email, role, session ID, JWT, Authorization, password, refresh token, TOTP material, Supabase URL/key, raw database row, or idempotency key. | Closed protocol rejects it before sandbox launch. |
| SEC-004 | A runner result includes hidden test/count/timing/body, private traceback, any raw-source/package echo, score, points, or an unknown field. | Closed protocol rejects it; no attempt/progress change. |
| SEC-005 | A controller import tries to reach Fastify, API root, identity/Auth/TOTP module, or raw client. | Future BND-008 negative import fixture fails. |
| SEC-006 | Platform-generated log/report/fixture/artifact contains Auth/TOTP/server credential marker or hidden-test material. | Future scan fails. Learner source is not inspected merely for ordinary words. |
| SEC-007 | An AAL1/missing/forged token reaches a future reservation route. | Future Fastify/API boundary rejects before assessment reservation. |

These are specification vectors, not claims that the later runtime, API, or
sandbox evidence has already passed.
