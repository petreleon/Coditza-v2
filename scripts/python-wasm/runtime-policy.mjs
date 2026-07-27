import { createHash } from "node:crypto";

export const PROTOCOL_VERSION = "coditza-python-runner-v1";
export const RUNTIME_PROFILE = "python-basic-v1";
export const FIXTURE_VERSION = "coditza-python-fixture-v1";
export const LOCAL_PROOF_DEFINITION_VERSION =
  "coditza-local-proof-definition-v1";
export const MAX_JSON_DEPTH = 32;

export const LIMITS = Object.freeze({
  initializationWallMs: 15_000,
  learnerWallMs: 5_000,
  learnerCpuSeconds: 3,
  memoryBytes: 256 * 1024 * 1024,
  scratchBytes: 8 * 1024 * 1024,
  scratchRegularFiles: 128,
  sourceFiles: 16,
  sourceFileBytes: 64 * 1024,
  sourceTotalBytes: 256 * 1024,
  outputBytes: 64 * 1024,
  resultBytes: 128 * 1024,
  pids: 16,
  requestBytes: 384 * 1024,
});

export const DIGEST_NAMES = Object.freeze([
  "submission",
  "definition",
  "fixture",
  "harness",
  "runtimeManifest",
]);

export const LEARNER_VERDICTS = new Set([
  "passed",
  "tests_failed",
  "syntax_error",
  "runtime_error",
  "time_limit_exceeded",
  "memory_limit_exceeded",
  "output_limit_exceeded",
]);

export const LIMIT_FLAG_NAMES = Object.freeze(["memory", "output", "time"]);

const JSON_WHITESPACE = new Set([" ", "\n", "\r", "\t"]);

class StrictJsonParser {
  #index = 0;
  #depth = 0;

  constructor(source) {
    this.source = source;
  }

  parse() {
    this.#skipWhitespace();
    const value = this.#value();
    this.#skipWhitespace();
    if (this.#index !== this.source.length) {
      throw new Error("invalid JSON trailing data");
    }
    return value;
  }

  #value() {
    this.#depth += 1;
    if (this.#depth > MAX_JSON_DEPTH) {
      throw new Error("JSON exceeds the fixed nesting limit");
    }
    try {
      return this.#valueAtCurrentDepth();
    } finally {
      this.#depth -= 1;
    }
  }

  #valueAtCurrentDepth() {
    this.#skipWhitespace();
    const current = this.source[this.#index];

    if (current === "{") return this.#object();
    if (current === "[") return this.#array();
    if (current === '"') return this.#string();
    if (this.source.startsWith("true", this.#index)) {
      this.#index += 4;
      return true;
    }
    if (this.source.startsWith("false", this.#index)) {
      this.#index += 5;
      return false;
    }
    if (this.source.startsWith("null", this.#index)) {
      this.#index += 4;
      return null;
    }
    return this.#number();
  }

  #object() {
    const result = Object.create(null);
    const keys = new Set();
    this.#expect("{");
    this.#skipWhitespace();
    if (this.source[this.#index] === "}") {
      this.#index += 1;
      return result;
    }

    while (true) {
      this.#skipWhitespace();
      if (this.source[this.#index] !== '"') {
        throw new Error("object key must be a JSON string");
      }
      const key = this.#string();
      if (keys.has(key)) {
        throw new Error("duplicate JSON object member");
      }
      keys.add(key);
      this.#skipWhitespace();
      this.#expect(":");
      result[key] = this.#value();
      this.#skipWhitespace();
      const separator = this.source[this.#index];
      if (separator === "}") {
        this.#index += 1;
        return result;
      }
      this.#expect(",");
    }
  }

  #array() {
    const result = [];
    this.#expect("[");
    this.#skipWhitespace();
    if (this.source[this.#index] === "]") {
      this.#index += 1;
      return result;
    }

    while (true) {
      result.push(this.#value());
      this.#skipWhitespace();
      const separator = this.source[this.#index];
      if (separator === "]") {
        this.#index += 1;
        return result;
      }
      this.#expect(",");
    }
  }

  #string() {
    const start = this.#index;
    this.#expect('"');
    let escaped = false;

    while (this.#index < this.source.length) {
      const character = this.source[this.#index];
      this.#index += 1;
      if (escaped) {
        escaped = false;
        continue;
      }
      if (character === "\\") {
        escaped = true;
        continue;
      }
      if (character === '"') {
        const token = this.source.slice(start, this.#index);
        try {
          return JSON.parse(token);
        } catch {
          throw new Error("invalid JSON string");
        }
      }
      if (character.codePointAt(0) < 0x20) {
        throw new Error("unescaped JSON control character");
      }
    }
    throw new Error("unterminated JSON string");
  }

  #number() {
    const match = /-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?/y;
    match.lastIndex = this.#index;
    const numberMatch = match.exec(this.source);
    if (numberMatch === null) {
      throw new Error("invalid JSON value");
    }
    this.#index += numberMatch[0].length;
    const value = Number(numberMatch[0]);
    if (!Number.isFinite(value)) {
      throw new Error("non-finite JSON number");
    }
    return value;
  }

  #expect(expected) {
    if (this.source[this.#index] !== expected) {
      throw new Error(`expected JSON token ${expected}`);
    }
    this.#index += 1;
  }

  #skipWhitespace() {
    while (JSON_WHITESPACE.has(this.source[this.#index])) {
      this.#index += 1;
    }
  }
}

export function parseStrictJson(source, maximumBytes = LIMITS.requestBytes) {
  if (typeof source !== "string") {
    throw new Error("runner input must be UTF-8 text");
  }
  if (Buffer.byteLength(source, "utf8") > maximumBytes) {
    throw new Error("runner JSON exceeds its byte limit");
  }
  return new StrictJsonParser(source).parse();
}

export function assertExactKeys(value, expectedKeys, name) {
  if (value === null || Array.isArray(value) || typeof value !== "object") {
    throw new Error(`${name} must be an object`);
  }
  const actual = Object.keys(value).sort();
  const expected = [...expectedKeys].sort();
  if (
    actual.length !== expected.length ||
    actual.some((key, index) => key !== expected[index])
  ) {
    throw new Error(`${name} has missing or unknown fields`);
  }
}

export function assertUnicodeScalars(value, name, depth = 0) {
  if (depth > MAX_JSON_DEPTH) {
    throw new Error(`${name} exceeds the fixed nesting limit`);
  }
  if (typeof value === "string") {
    for (let index = 0; index < value.length; index += 1) {
      const code = value.charCodeAt(index);
      if (code >= 0xd800 && code <= 0xdbff) {
        const next = value.charCodeAt(index + 1);
        if (next < 0xdc00 || next > 0xdfff) {
          throw new Error(`${name} contains an unpaired high surrogate`);
        }
        index += 1;
      } else if (code >= 0xdc00 && code <= 0xdfff) {
        throw new Error(`${name} contains an unpaired low surrogate`);
      }
    }
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((entry, index) =>
      assertUnicodeScalars(entry, `${name}[${index}]`, depth + 1),
    );
    return;
  }
  if (value !== null && typeof value === "object") {
    for (const [key, entry] of Object.entries(value)) {
      assertUnicodeScalars(key, `${name} key`);
      assertUnicodeScalars(entry, `${name}.${key}`, depth + 1);
    }
  }
}

function assertDigest(value, name) {
  if (typeof value !== "string" || !/^sha256:[a-f0-9]{64}$/.test(value)) {
    throw new Error(`${name} must be a sha256 digest`);
  }
}

function assertJsonValue(value, name, depth = 0) {
  if (depth > MAX_JSON_DEPTH) {
    throw new Error(`${name} exceeds the fixed nesting limit`);
  }
  if (
    value === null ||
    typeof value === "string" ||
    typeof value === "boolean" ||
    (typeof value === "number" && Number.isFinite(value))
  ) {
    return;
  }
  if (Array.isArray(value)) {
    value.forEach((entry, index) =>
      assertJsonValue(entry, `${name}[${index}]`, depth + 1),
    );
    return;
  }
  if (typeof value === "object") {
    for (const [key, entry] of Object.entries(value)) {
      assertJsonValue(entry, `${name}.${key}`, depth + 1);
    }
    return;
  }
  throw new Error(`${name} is not a JSON value`);
}

export function validateRunnerRequest(request) {
  assertExactKeys(
    request,
    [
      "protocolVersion",
      "jobId",
      "files",
      "entryPoint",
      "publicCasePlan",
      "limits",
      "digests",
    ],
    "runner request",
  );
  assertUnicodeScalars(request, "runner request");
  if (request.protocolVersion !== PROTOCOL_VERSION) {
    throw new Error("unsupported runner protocol version");
  }
  if (
    typeof request.jobId !== "string" ||
    !/^job-[a-z0-9-]{8,80}$/.test(request.jobId)
  ) {
    throw new Error("runner jobId is not an opaque bounded identifier");
  }

  if (
    !Array.isArray(request.files) ||
    request.files.length < 1 ||
    request.files.length > LIMITS.sourceFiles
  ) {
    throw new Error("runner files exceed the fixed source-file limit");
  }
  let sourceBytes = 0;
  const paths = new Set();
  const caseFoldedPaths = new Set();
  let previousPath = "";
  for (const file of request.files) {
    assertExactKeys(file, ["path", "content"], "runner file");
    const pathSegments =
      typeof file.path === "string" ? file.path.split("/") : [];
    if (
      typeof file.path !== "string" ||
      !/^[A-Za-z0-9_.-]+(?:\/[A-Za-z0-9_.-]+)*\.py$/.test(file.path) ||
      Buffer.byteLength(file.path, "utf8") > 160 ||
      pathSegments.some((segment) => segment === "." || segment === "..")
    ) {
      throw new Error("runner file path is not canonical");
    }
    const caseFoldedPath = file.path.toLowerCase();
    if (
      paths.has(file.path) ||
      caseFoldedPaths.has(caseFoldedPath) ||
      (previousPath !== "" && file.path <= previousPath)
    ) {
      throw new Error("runner files contain a duplicate path");
    }
    paths.add(file.path);
    caseFoldedPaths.add(caseFoldedPath);
    previousPath = file.path;
    if (typeof file.content !== "string") {
      throw new Error("runner file content is not text");
    }
    if (file.content.includes("\u0000")) {
      throw new Error("runner file content contains a NUL character");
    }
    const fileBytes = Buffer.byteLength(file.content, "utf8");
    if (fileBytes > LIMITS.sourceFileBytes) {
      throw new Error("runner file exceeds the fixed per-file byte limit");
    }
    sourceBytes += fileBytes;
  }
  if (sourceBytes > LIMITS.sourceTotalBytes) {
    throw new Error("runner package exceeds the fixed aggregate byte limit");
  }

  assertExactKeys(
    request.entryPoint,
    ["module", "function"],
    "runner entryPoint",
  );
  if (
    request.entryPoint.module !== "main" ||
    request.entryPoint.function !== "solve"
  ) {
    throw new Error("runner entryPoint is outside python-basic-v1");
  }
  if (!paths.has("main.py")) {
    throw new Error("runner package must contain main.py");
  }

  if (
    !Array.isArray(request.publicCasePlan) ||
    request.publicCasePlan.length > 16
  ) {
    throw new Error("runner publicCasePlan is outside its fixed limit");
  }
  const publicCaseIds = new Set();
  for (const testCase of request.publicCasePlan) {
    assertExactKeys(testCase, ["id", "input", "expected"], "public test case");
    if (
      typeof testCase.id !== "string" ||
      !/^[a-z0-9-]{1,80}$/.test(testCase.id)
    ) {
      throw new Error("public test case id is invalid");
    }
    if (publicCaseIds.has(testCase.id)) {
      throw new Error("public test case ids must be unique");
    }
    publicCaseIds.add(testCase.id);
    assertJsonValue(testCase.input, "public test input");
    assertJsonValue(testCase.expected, "public test expected value");
  }

  assertExactKeys(
    request.limits,
    Object.keys(LIMITS).filter((key) => key !== "requestBytes"),
    "runner limits",
  );
  for (const [name, expected] of Object.entries(LIMITS)) {
    if (name === "requestBytes") continue;
    if (request.limits[name] !== expected) {
      throw new Error(`runner limit ${name} differs from the approved profile`);
    }
  }

  assertExactKeys(request.digests, DIGEST_NAMES, "runner digests");
  for (const digestName of DIGEST_NAMES) {
    assertDigest(request.digests[digestName], `runner digest ${digestName}`);
  }

  return Object.freeze(request);
}

export function deriveLocalProofInputDigests(request) {
  return Object.freeze({
    submission: canonicalDigest({
      files: request.files,
      entryPoint: request.entryPoint,
    }),
    definition: canonicalDigest({
      definitionVersion: LOCAL_PROOF_DEFINITION_VERSION,
      entryPoint: request.entryPoint,
      publicCasePlan: request.publicCasePlan,
    }),
    fixture: canonicalDigest({
      fixtureVersion: FIXTURE_VERSION,
      publicCasePlan: request.publicCasePlan,
    }),
  });
}

export function assertDigestMapMatches(actualDigests, expectedDigests, name) {
  assertExactKeys(actualDigests, DIGEST_NAMES, `${name} digests`);
  for (const digestName of DIGEST_NAMES) {
    if (actualDigests[digestName] !== expectedDigests[digestName]) {
      throw new Error(
        `${name} digest ${digestName} does not match the trusted binding`,
      );
    }
  }
}

export function assertLocalProofInputDigests(request) {
  const expected = deriveLocalProofInputDigests(request);
  for (const digestName of ["submission", "definition", "fixture"]) {
    if (request.digests[digestName] !== expected[digestName]) {
      throw new Error(
        `runner request ${digestName} digest does not match its canonical input`,
      );
    }
  }
  return expected;
}

export function validateRunnerResult(result) {
  assertExactKeys(
    result,
    [
      "protocolVersion",
      "resultKind",
      "digests",
      "verdict",
      "publicFeedback",
      "publicOutput",
      "limitFlags",
    ],
    "runner result",
  );
  assertUnicodeScalars(result, "runner result");
  if (
    result.protocolVersion !== PROTOCOL_VERSION ||
    result.resultKind !== "local_public_proof"
  ) {
    throw new Error("runner result has an unsupported protocol shape");
  }
  assertExactKeys(result.digests, DIGEST_NAMES, "runner result digests");
  for (const digestName of DIGEST_NAMES) {
    assertDigest(
      result.digests[digestName],
      `runner result digest ${digestName}`,
    );
  }
  if (!LEARNER_VERDICTS.has(result.verdict)) {
    throw new Error("runner result has an unknown learner verdict");
  }
  if (
    typeof result.publicFeedback !== "string" ||
    typeof result.publicOutput !== "string"
  ) {
    throw new Error("runner result feedback fields are not text");
  }
  if (
    Buffer.byteLength(result.publicFeedback, "utf8") > 2048 ||
    Buffer.byteLength(result.publicOutput, "utf8") > LIMITS.outputBytes
  ) {
    throw new Error("runner result feedback exceeds its safe bound");
  }
  assertExactKeys(
    result.limitFlags,
    LIMIT_FLAG_NAMES,
    "runner result limitFlags",
  );
  for (const value of Object.values(result.limitFlags)) {
    if (typeof value !== "boolean") {
      throw new Error("runner result limit flag is not boolean");
    }
  }
  if (!boundedResultBytes(result)) {
    throw new Error("runner result exceeds the fixed result byte limit");
  }
  const activeLimitFlags = LIMIT_FLAG_NAMES.filter(
    (name) => result.limitFlags[name],
  );
  const expectedLimitVerdict =
    result.verdict === "memory_limit_exceeded"
      ? "memory"
      : result.verdict === "output_limit_exceeded"
        ? "output"
        : result.verdict === "time_limit_exceeded"
          ? "time"
          : null;
  if (expectedLimitVerdict === null && activeLimitFlags.length !== 0) {
    throw new Error("non-limit runner verdict cannot set a limit flag");
  }
  if (
    expectedLimitVerdict !== null &&
    (activeLimitFlags.length !== 1 ||
      activeLimitFlags[0] !== expectedLimitVerdict)
  ) {
    throw new Error("runner limit verdict does not match its sole limit flag");
  }
  return Object.freeze(result);
}

export function createSafeRunnerResult(request, verdict) {
  if (!LEARNER_VERDICTS.has(verdict)) {
    throw new Error("runner attempted to emit an unknown learner verdict");
  }
  const result = {
    protocolVersion: PROTOCOL_VERSION,
    resultKind: "local_public_proof",
    digests: request.digests,
    verdict,
    publicFeedback:
      verdict === "passed"
        ? "Testele publice de probă au trecut."
        : "Rularea publică de probă a fost evaluată fără date private de verificare.",
    publicOutput: "",
    limitFlags: {
      memory: verdict === "memory_limit_exceeded",
      output: verdict === "output_limit_exceeded",
      time: verdict === "time_limit_exceeded",
    },
  };
  return validateRunnerResult(result);
}

export function canonicalJson(value, depth = 0) {
  if (depth > MAX_JSON_DEPTH) {
    throw new Error("cannot canonicalize data above the fixed nesting limit");
  }
  if (value === null) return "null";
  if (typeof value === "boolean") return value ? "true" : "false";
  if (typeof value === "number") {
    if (!Number.isFinite(value))
      throw new Error("cannot canonicalize non-finite number");
    return JSON.stringify(value);
  }
  if (typeof value === "string") return JSON.stringify(value);
  if (Array.isArray(value))
    return `[${value.map((entry) => canonicalJson(entry, depth + 1)).join(",")}]`;
  if (typeof value === "object") {
    return `{${Object.keys(value)
      .sort()
      .map(
        (key) =>
          `${JSON.stringify(key)}:${canonicalJson(value[key], depth + 1)}`,
      )
      .join(",")}}`;
  }
  throw new Error("cannot canonicalize non-JSON value");
}

export function canonicalDigest(value) {
  return `sha256:${createHash("sha256").update(canonicalJson(value), "utf8").digest("hex")}`;
}

export function boundedResultBytes(result) {
  return Buffer.byteLength(canonicalJson(result), "utf8") <= LIMITS.resultBytes;
}
