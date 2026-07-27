import { createRequire } from "node:module";
import {
  Worker,
  isMainThread,
  parentPort,
  workerData,
} from "node:worker_threads";

import { loadPyodide } from "pyodide";

import {
  LEARNER_VERDICTS,
  LIMITS,
  PROTOCOL_VERSION,
  assertDigestMapMatches,
  assertLocalProofInputDigests,
  boundedResultBytes,
  canonicalJson,
  createSafeRunnerResult,
  parseStrictJson,
  validateRunnerRequest,
  validateRunnerResult,
} from "./runtime-policy.mjs";

const require = createRequire(import.meta.url);
const seccompGate = require("./native/seccomp-gate.node");
const RUNTIME_ASSET_DIRECTORY = "/opt/coditza/node_modules/pyodide/";
const SANDBOX_DIRECTORY = "/sandbox";
const FIXED_EPOCH_SECONDS = 946_684_800;
const FIXED_RANDOM_SEED = 1729;
const PYODIDE_ENVIRONMENT = Object.freeze({
  HOME: "/nonexistent",
  LANG: "C",
  LC_ALL: "C",
  TZ: "UTC",
  PYTHONHASHSEED: String(FIXED_RANDOM_SEED),
  PYTHONINSPECT: "0",
});

class OutputLimitError extends Error {
  constructor() {
    super("output limit reached");
    this.name = "OutputLimitError";
  }
}

function ignoreBrokenControlPipe(stream) {
  stream.on("error", () => {
    // A detached local Docker client can close the attach pipe. The in-container
    // watchdog still exits the process and Docker's --rm removes the container.
  });
}

function emitControl(stage, details = Object.create(null)) {
  process.stderr.write(
    `CODITZA_CONTROL ${JSON.stringify({ stage, protocolVersion: PROTOCOL_VERSION, ...details })}\n`,
  );
}

function emitRunnerResult(result) {
  const serialized = canonicalJson(result);
  if (Buffer.byteLength(serialized, "utf8") > LIMITS.resultBytes) {
    throw new Error("runner result exceeds the approved result byte limit");
  }
  process.stdout.write(`${serialized}\n`);
}

function createOutputCollector(onExceeded = () => {}) {
  const state = {
    bytes: 0,
    exceeded: false,
  };
  const capture = (text) => {
    const bytes = Buffer.byteLength(`${text}\n`, "utf8");
    if (state.bytes + bytes > LIMITS.outputBytes) {
      if (!state.exceeded) {
        state.exceeded = true;
        onExceeded();
      }
      return;
    }
    state.bytes += bytes;
  };
  return {
    state,
    stdout: capture,
    stderr: capture,
  };
}

function rejectVirtualFilesystemMutation(pyodide) {
  const denied = () => {
    throw new pyodide.FS.ErrnoError(2);
  };
  const mutationMethods = [
    "chmod",
    "createDataFile",
    "createFile",
    "createLazyFile",
    "createPreloadedFile",
    "link",
    "lchmod",
    "mkdir",
    "mkdirTree",
    "mknod",
    "rename",
    "rmdir",
    "symlink",
    "truncate",
    "unlink",
    "writeFile",
  ];
  for (const method of mutationMethods) {
    if (typeof pyodide.FS[method] === "function") {
      pyodide.FS[method] = denied;
    }
  }

  const originalOpen = pyodide.FS.open.bind(pyodide.FS);
  pyodide.FS.open = (path, flags, ...rest) => {
    const isWrite =
      typeof flags === "number"
        ? (flags & 3) !== 0 || (flags & 64) !== 0 || (flags & 512) !== 0
        : /[wa+]/.test(String(flags));
    if (isWrite) denied();
    return originalOpen(path, flags, ...rest);
  };
}

function writeLearnerFiles(pyodide, files) {
  pyodide.FS.mkdirTree(SANDBOX_DIRECTORY);
  for (const file of files) {
    const target = `${SANDBOX_DIRECTORY}/${file.path}`;
    const separator = target.lastIndexOf("/");
    pyodide.FS.mkdirTree(target.slice(0, separator));
    pyodide.FS.writeFile(target, file.content, { encoding: "utf8" });
  }
  pyodide.runPython("import sys; sys.dont_write_bytecode = True");
  rejectVirtualFilesystemMutation(pyodide);
}

function configureDeterministicRuntime(pyodide) {
  const snapshot = pyodide.runPython(`
import datetime as _coditza_datetime
import os as _coditza_os
import random as _coditza_random
import time as _coditza_time

_CODITZA_FIXED_EPOCH = ${FIXED_EPOCH_SECONDS}.0
_CODITZA_FIXED_SEED = ${FIXED_RANDOM_SEED}

def _coditza_fixed_seconds(*_args, **_kwargs):
    return _CODITZA_FIXED_EPOCH

def _coditza_fixed_nanoseconds(*_args, **_kwargs):
    return int(_CODITZA_FIXED_EPOCH * 1_000_000_000)

def _coditza_denied_sleep(*_args, **_kwargs):
    raise RuntimeError("sleep is unavailable in python-basic-v1")

def _coditza_denied_entropy(*_args, **_kwargs):
    raise RuntimeError("unseeded entropy is unavailable in python-basic-v1")

class _CoditzaRandom(_coditza_random.Random):
    def __init__(self, seed=_CODITZA_FIXED_SEED):
        super().__init__(_CODITZA_FIXED_SEED if seed is None else seed)

class _CoditzaSystemRandom:
    def __init__(self, *_args, **_kwargs):
        _coditza_denied_entropy()

class _CoditzaDateTime(_coditza_datetime.datetime):
    @classmethod
    def now(cls, tz=None):
        return cls.fromtimestamp(_CODITZA_FIXED_EPOCH, tz)

    @classmethod
    def utcnow(cls):
        return cls.utcfromtimestamp(_CODITZA_FIXED_EPOCH)

class _CoditzaDate(_coditza_datetime.date):
    @classmethod
    def today(cls):
        return _CoditzaDateTime.fromtimestamp(_CODITZA_FIXED_EPOCH).date()

_coditza_random.seed(_CODITZA_FIXED_SEED)
_coditza_random.Random = _CoditzaRandom
_coditza_random.SystemRandom = _CoditzaSystemRandom
_coditza_os.urandom = _coditza_denied_entropy
_coditza_time.time = _coditza_fixed_seconds
_coditza_time.time_ns = _coditza_fixed_nanoseconds
_coditza_time.monotonic = _coditza_fixed_seconds
_coditza_time.monotonic_ns = _coditza_fixed_nanoseconds
_coditza_time.perf_counter = _coditza_fixed_seconds
_coditza_time.perf_counter_ns = _coditza_fixed_nanoseconds
_coditza_time.process_time = _coditza_fixed_seconds
_coditza_time.process_time_ns = _coditza_fixed_nanoseconds
_coditza_time.sleep = _coditza_denied_sleep
if hasattr(_coditza_time, "clock_gettime"):
    _coditza_time.clock_gettime = _coditza_fixed_seconds
if hasattr(_coditza_time, "clock_gettime_ns"):
    _coditza_time.clock_gettime_ns = _coditza_fixed_nanoseconds
_coditza_datetime.datetime = _CoditzaDateTime
_coditza_datetime.date = _CoditzaDate

assert _coditza_os.environ.get("HOME") == "/nonexistent"
assert _coditza_os.environ.get("TZ") == "UTC"
assert _coditza_os.environ.get("PYTHONHASHSEED") == str(_CODITZA_FIXED_SEED)
assert _coditza_time.time() == _CODITZA_FIXED_EPOCH
_coditza_random.seed(_CODITZA_FIXED_SEED)
_coditza_probe_random = _coditza_random.random()
_coditza_random.seed(_CODITZA_FIXED_SEED)
(_coditza_probe_random, hash("coditza"), _coditza_time.time())
`);
  const values = Array.isArray(snapshot) ? snapshot : snapshot.toJs();
  if (
    !Array.isArray(values) ||
    values.length !== 3 ||
    typeof values[0] !== "number" ||
    typeof values[1] !== "number" ||
    values[2] !== FIXED_EPOCH_SECONDS
  ) {
    throw new Error("trusted deterministic Pyodide bootstrap failed");
  }
  return Object.freeze({ randomProbe: values[0], hashProbe: values[1] });
}

function resetDeterministicLearnerState(pyodide) {
  pyodide.runPython(`
import random as _coditza_random
_coditza_random.seed(${FIXED_RANDOM_SEED})
`);
}

function compileLearnerFiles(pyodide, files) {
  const filePaths = files.map((file) => `${SANDBOX_DIRECTORY}/${file.path}`);
  const compiled = pyodide.runPython(`
_coditza_paths = ${JSON.stringify(filePaths)}
_coditza_compile_failed = False
for _coditza_path in _coditza_paths:
    try:
        with open(_coditza_path, "r", encoding="utf-8") as _coditza_file:
            compile(_coditza_file.read(), _coditza_path, "exec")
    except (SyntaxError, UnicodeError):
        _coditza_compile_failed = True
        break
_coditza_compile_failed
`);
  return compiled === true;
}

function normalizePythonValue(value) {
  let converted = value;
  try {
    if (
      value !== null &&
      (typeof value === "object" || typeof value === "function") &&
      typeof value.toJs === "function"
    ) {
      converted = value.toJs({
        create_proxies: false,
        dict_converter: Object.fromEntries,
      });
    }
    const serialized = JSON.stringify(converted);
    if (serialized === undefined) {
      throw new Error("learner entry point returned a non-JSON value");
    }
    return JSON.parse(serialized);
  } finally {
    if (
      value !== null &&
      (typeof value === "object" || typeof value === "function") &&
      typeof value.destroy === "function"
    ) {
      value.destroy();
    }
  }
}

function invokeSolve(pyodide, solve, input) {
  const pythonInput = pyodide.toPy(input);
  try {
    return normalizePythonValue(solve(pythonInput));
  } finally {
    if (
      pythonInput !== null &&
      (typeof pythonInput === "object" || typeof pythonInput === "function") &&
      typeof pythonInput.destroy === "function"
    ) {
      pythonInput.destroy();
    }
  }
}

function equalsCanonicalJson(left, right) {
  return canonicalJson(left) === canonicalJson(right);
}

function classifyExecutionError(error, outputState) {
  if (outputState.exceeded || error instanceof OutputLimitError) {
    return "output_limit_exceeded";
  }
  return "runtime_error";
}

function loadFreshLearnerSolve(pyodide) {
  pyodide.runPython(`
import importlib
import sys
sys.modules.pop("main", None)
sys.path.insert(0, "${SANDBOX_DIRECTORY}")
_coditza_module = importlib.import_module("main")
_coditza_solve = getattr(_coditza_module, "solve")
`);
  return pyodide.globals.get("_coditza_solve");
}

async function executePublicProof(pyodide, request, outputState) {
  try {
    writeLearnerFiles(pyodide, request.files);
    if (compileLearnerFiles(pyodide, request.files)) {
      return createSafeRunnerResult(request, "syntax_error");
    }
    for (const publicCase of request.publicCasePlan) {
      resetDeterministicLearnerState(pyodide);
      const solve = loadFreshLearnerSolve(pyodide);
      try {
        const actual = invokeSolve(pyodide, solve, publicCase.input);
        if (outputState.exceeded) {
          return createSafeRunnerResult(request, "output_limit_exceeded");
        }
        if (!equalsCanonicalJson(actual, publicCase.expected)) {
          return createSafeRunnerResult(request, "tests_failed");
        }
      } finally {
        if (
          solve !== null &&
          (typeof solve === "object" || typeof solve === "function") &&
          typeof solve.destroy === "function"
        ) {
          solve.destroy();
        }
      }
    }
    return createSafeRunnerResult(request, "passed");
  } catch (error) {
    return createSafeRunnerResult(
      request,
      classifyExecutionError(error, outputState),
    );
  }
}

function postWorkerMessage(message) {
  if (parentPort !== null) parentPort.postMessage(message);
}

async function runTrustedWorker() {
  const output = createOutputCollector(() =>
    postWorkerMessage({ type: "output_limit" }),
  );
  const pyodide = await loadPyodide({
    indexURL: RUNTIME_ASSET_DIRECTORY,
    jsglobals: Object.create(null),
    env: PYODIDE_ENVIRONMENT,
    stdout: output.stdout,
    stderr: output.stderr,
  });
  if (pyodide.runPython("sum(range(10))") !== 45) {
    throw new Error("trusted Pyodide bootstrap smoke failed");
  }
  configureDeterministicRuntime(pyodide);
  postWorkerMessage({ type: "booted" });

  parentPort.on("message", async (message) => {
    try {
      if (message?.type === "verify_gate") {
        seccompGate.verify();
        postWorkerMessage({ type: "gate_verified" });
        return;
      }
      if (message?.type === "execute") {
        const request = validateRunnerRequest(message.request);
        assertLocalProofInputDigests(request);
        const result = await executePublicProof(pyodide, request, output.state);
        postWorkerMessage({ type: "result", result });
        return;
      }
      postWorkerMessage({ type: "failed" });
    } catch {
      postWorkerMessage({ type: "failed" });
    }
  });
}

function createWorkerMailbox(worker) {
  const messages = [];
  const waiters = [];
  let failure = false;
  const deliver = (message) => {
    const waiter = waiters.shift();
    if (waiter === undefined) {
      messages.push(message);
    } else {
      waiter.resolve(message);
    }
  };
  worker.on("message", deliver);
  worker.on("error", () => {
    failure = true;
    while (waiters.length > 0)
      waiters.shift().reject(new Error("trusted worker failed"));
  });
  worker.on("exit", (code) => {
    if (code !== 0) {
      failure = true;
      while (waiters.length > 0)
        waiters.shift().reject(new Error("trusted worker exited early"));
    }
  });
  return {
    async next() {
      if (messages.length > 0) return messages.shift();
      if (failure) throw new Error("trusted worker is unavailable");
      return new Promise((resolve, reject) =>
        waiters.push({ resolve, reject }),
      );
    },
  };
}

async function expectWorkerMessage(mailbox, expectedType) {
  while (true) {
    const message = await mailbox.next();
    if (message?.type === "failed")
      throw new Error("trusted worker rejected its operation");
    if (message?.type === expectedType) return message;
    throw new Error("trusted worker emitted an unexpected control message");
  }
}

async function expectExecutionMessage(mailbox) {
  const message = await mailbox.next();
  if (message?.type === "output_limit" || message?.type === "result")
    return message;
  if (message?.type === "failed")
    throw new Error("trusted worker rejected learner execution");
  throw new Error("trusted worker emitted an unexpected execution message");
}

async function readClosedRunFrames() {
  return new Promise((resolvePromise, reject) => {
    const frames = [];
    let buffered = Buffer.alloc(0);
    let totalBytes = 0;
    let settled = false;
    const settle = (callback, value) => {
      if (settled) return;
      settled = true;
      process.stdin.pause();
      callback(value);
    };
    const fail = () =>
      settle(reject, new Error("closed runner input framing is invalid"));
    const consume = () => {
      while (true) {
        const lineEnd = buffered.indexOf(0x0a);
        if (lineEnd === -1) return;
        const line = buffered.subarray(0, lineEnd);
        buffered = buffered.subarray(lineEnd + 1);
        if (line.includes(0x0d)) return fail();
        try {
          frames.push(new TextDecoder("utf-8", { fatal: true }).decode(line));
        } catch {
          return fail();
        }
        if (frames.length > 2) return fail();
        if (frames.length === 2) {
          if (buffered.length !== 0 || frames[1] !== "CODITZA_RUN")
            return fail();
          if (Buffer.byteLength(frames[0], "utf8") > LIMITS.requestBytes)
            return fail();
          try {
            settle(
              resolvePromise,
              parseStrictJson(frames[0], LIMITS.requestBytes),
            );
          } catch (error) {
            settle(reject, error);
          }
          return;
        }
      }
    };
    process.stdin.on("data", (chunk) => {
      if (settled) return;
      totalBytes += chunk.length;
      if (totalBytes > LIMITS.requestBytes + 64) return fail();
      buffered = Buffer.concat([buffered, chunk]);
      consume();
    });
    process.stdin.once("error", fail);
    process.stdin.once("end", () => {
      if (!settled) fail();
    });
    process.stdin.resume();
  });
}

function finishProcess(worker, result, exitCode) {
  void worker.terminate();
  if (result !== null) emitRunnerResult(result);
  const fallback = setTimeout(() => process.exit(exitCode), 50);
  fallback.unref();
  process.stdout.write("", () => process.exit(exitCode));
}

async function runMainProcess() {
  ignoreBrokenControlPipe(process.stdout);
  ignoreBrokenControlPipe(process.stderr);
  const worker = new Worker(new URL(import.meta.url), {
    workerData: { role: "trusted-pyodide" },
  });
  const mailbox = createWorkerMailbox(worker);
  let finished = false;
  let request = null;
  const failClosed = () => {
    if (finished) return;
    finished = true;
    emitControl("rejected_or_failed");
    finishProcess(worker, null, 70);
  };
  const initializationTimer = setTimeout(
    failClosed,
    LIMITS.initializationWallMs,
  );

  try {
    await expectWorkerMessage(mailbox, "booted");
    const securityStatus = seccompGate.install();
    worker.postMessage({ type: "verify_gate" });
    await expectWorkerMessage(mailbox, "gate_verified");
    emitControl("ready", {
      architecture: securityStatus.architecture,
      cpuHardLimitSeconds: securityStatus.cpuHardLimitSeconds,
      postBootstrapSeccomp: securityStatus.selfTestPassed === true,
      tsyncWorkerVerified: true,
      deterministicBootstrap: true,
    });

    const rawRequest = await readClosedRunFrames();
    request = validateRunnerRequest(rawRequest);
    assertLocalProofInputDigests(request);
    clearTimeout(initializationTimer);
    const onCpuLimit = () => {
      if (finished) return;
      finished = true;
      finishProcess(
        worker,
        createSafeRunnerResult(request, "time_limit_exceeded"),
        124,
      );
    };
    process.once("SIGXCPU", onCpuLimit);
    const learnerTimer = setTimeout(() => {
      if (finished) return;
      finished = true;
      finishProcess(
        worker,
        createSafeRunnerResult(request, "time_limit_exceeded"),
        124,
      );
    }, LIMITS.learnerWallMs);
    worker.postMessage({ type: "execute", request });
    const message = await expectExecutionMessage(mailbox);
    if (finished) return;
    clearTimeout(learnerTimer);
    process.removeListener("SIGXCPU", onCpuLimit);
    if (message.type === "output_limit") {
      finished = true;
      finishProcess(
        worker,
        createSafeRunnerResult(request, "output_limit_exceeded"),
        0,
      );
      return;
    }
    const result = validateRunnerResult(message.result);
    assertDigestMapMatches(result.digests, request.digests, "runner result");
    finished = true;
    finishProcess(worker, result, 0);
  } catch {
    clearTimeout(initializationTimer);
    failClosed();
  }
}

if (!isMainThread && workerData?.role === "trusted-pyodide") {
  runTrustedWorker().catch(() => postWorkerMessage({ type: "failed" }));
} else if (isMainThread) {
  runMainProcess();
}
