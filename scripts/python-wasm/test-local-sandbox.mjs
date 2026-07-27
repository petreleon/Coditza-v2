import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { existsSync } from "node:fs";
import { copyFile, mkdir, mkdtemp, readFile, rm } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

import {
  inspectPinnedLocalImage,
  runLocalSandbox,
} from "./local-launch-broker.mjs";
import {
  LIMITS,
  PROTOCOL_VERSION,
  assertDigestMapMatches,
  canonicalDigest,
  createSafeRunnerResult,
  deriveLocalProofInputDigests,
  parseStrictJson,
  validateRunnerRequest,
  validateRunnerResult,
} from "./runtime-policy.mjs";

const SCRIPT_DIRECTORY = dirname(fileURLToPath(import.meta.url));
const REPOSITORY_ROOT = resolve(SCRIPT_DIRECTORY, "../..");
const RUNTIME_LOCK_PATH = resolve(
  REPOSITORY_ROOT,
  "python-wasm-runtime.lock.json",
);
const PYODIDE_DIRECTORY = resolve(REPOSITORY_ROOT, "node_modules/pyodide");
const TMPFS_SPEC = `/work:rw,noexec,nosuid,nodev,size=${LIMITS.scratchBytes},nr_inodes=${LIMITS.scratchRegularFiles},mode=0700,uid=65532,gid=65532`;
const DOCKER_CANDIDATES = [
  "/opt/homebrew/bin/docker",
  "/usr/local/bin/docker",
  "/usr/bin/docker",
];

let runtimeLockBytes;
let runtimeLock;

function sha256(bytes) {
  return `sha256:${createHash("sha256").update(bytes).digest("hex")}`;
}

async function fileHash(path) {
  return sha256(await readFile(path));
}

function approvedLimits() {
  return Object.fromEntries(
    Object.entries(LIMITS).filter(([name]) => name !== "requestBytes"),
  );
}

function harnessDigest() {
  return canonicalDigest({
    protocolVersion: runtimeLock.protocol.version,
    profile: runtimeLock.protocol.profile,
    runner: runtimeLock.sandbox.runner,
    policy: runtimeLock.sandbox.policy,
    nativeGateBinary: runtimeLock.sandbox.nativeGateBinary,
    bootstrapSeccompPolicy: runtimeLock.sandbox.bootstrapSeccompPolicy,
  });
}

function requestFor(source, publicCase = { input: 41, expected: 42 }) {
  const request = {
    protocolVersion: PROTOCOL_VERSION,
    jobId: "job-local-proof-001",
    files: [{ path: "main.py", content: source }],
    entryPoint: { module: "main", function: "solve" },
    publicCasePlan: [{ id: "public-1", ...publicCase }],
    limits: approvedLimits(),
    digests: Object.create(null),
  };
  Object.assign(request.digests, deriveLocalProofInputDigests(request), {
    harness: harnessDigest(),
    runtimeManifest: sha256(runtimeLockBytes),
  });
  return request;
}

function assertInspection(inspection) {
  assert.ok(
    inspection,
    "broker must inspect the exact live container before learner execution",
  );
  assert.equal(inspection.user, "65532:65532");
  assert.equal(inspection.networkMode, "none");
  assert.equal(inspection.ipcMode, "none");
  assert.notEqual(inspection.pidMode, "host");
  assert.notEqual(inspection.utsMode, "host");
  assert.notEqual(inspection.usernsMode, "host");
  assert.equal(inspection.privileged, false);
  assert.equal(inspection.readOnlyRootfs, true);
  assert.deepEqual(inspection.capDrop, ["ALL"]);
  assert.ok(inspection.securityOpt.includes("no-new-privileges:true"));
  assert.ok(
    inspection.securityOpt.some((option) => option.startsWith("seccomp=")),
  );
  assert.equal(inspection.pidsLimit, LIMITS.pids);
  assert.equal(inspection.memory, LIMITS.memoryBytes);
  assert.equal(inspection.memorySwap, LIMITS.memoryBytes);
  assert.equal(inspection.nanoCpus, 1_000_000_000);
  assert.equal(inspection.nonTmpfsMountCount, 0);
  assert.equal(inspection.bindCount, 0);
  assert.equal(inspection.volumeCount, 0);
  assert.equal(inspection.volumesFromCount, 0);
  assert.equal(inspection.deviceCount, 0);
  assert.equal(inspection.deviceRequestCount, 0);
  assert.equal(inspection.portBindingCount, 0);
  assert.equal(inspection.publishAllPorts, false);
  assert.equal(inspection.dnsCount, 0);
  assert.equal(inspection.dnsOptionCount, 0);
  assert.equal(inspection.dnsSearchCount, 0);
  assert.equal(inspection.extraHostCount, 0);
  assert.ok(["", "no"].includes(inspection.restartPolicy));
  assert.equal(inspection.logDriver, "none");
  assert.equal(inspection.autoRemove, true);
  assert.deepEqual(inspection.tmpfsMounts, [TMPFS_SPEC]);
  assert.equal(inspection.hostCanaryPresent, false);
}

async function assertRuntimeLock() {
  runtimeLockBytes = await readFile(RUNTIME_LOCK_PATH);
  runtimeLock = JSON.parse(runtimeLockBytes);
  assert.equal(runtimeLock.status, "local-proof-only");
  assert.equal(runtimeLock.runtime.pyodide.npmPackage, "pyodide@314.0.3");
  assert.equal(runtimeLock.runtime.pyodide.runtimePython, "3.14.2");
  assert.equal(runtimeLock.runtime.pyodide.abiPython, "3.14.0");
  assert.equal(runtimeLock.runtime.pyodide.runtimeFetchAllowed, false);
  assert.deepEqual(runtimeLock.runtime.pyodide.allowedExternalPackages, []);
  for (const [asset, expectedHash] of Object.entries(
    runtimeLock.runtime.pyodide.assets,
  )) {
    assert.equal(
      await fileHash(resolve(PYODIDE_DIRECTORY, asset)),
      expectedHash,
      `host asset drift: ${asset}`,
    );
  }
  assert.equal(
    await fileHash(resolve(SCRIPT_DIRECTORY, "runner.mjs")),
    runtimeLock.sandbox.runner,
  );
  assert.equal(
    await fileHash(resolve(SCRIPT_DIRECTORY, "runtime-policy.mjs")),
    runtimeLock.sandbox.policy,
  );
  assert.equal(
    await fileHash(resolve(SCRIPT_DIRECTORY, "local-launch-broker.mjs")),
    runtimeLock.sandbox.localLaunchBroker,
  );
  assert.equal(
    await fileHash(resolve(SCRIPT_DIRECTORY, "native/seccomp-gate.c")),
    runtimeLock.sandbox.nativeGateSource,
  );
  assert.equal(
    await fileHash(resolve(SCRIPT_DIRECTORY, "seccomp-bootstrap.json")),
    runtimeLock.sandbox.bootstrapSeccompPolicy,
  );
  assert.equal(
    await fileHash(resolve(REPOSITORY_ROOT, "Dockerfile.python-wasm-sandbox")),
    runtimeLock.sandbox.dockerfile,
  );
  const image = await inspectPinnedLocalImage();
  assert.equal(image.id, runtimeLock.sandbox.localImage.id);
  assert.deepEqual(image.imageFiles, runtimeLock.sandbox.imageFiles);
}

function spawnChecked(command, argumentsList, options) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn(command, argumentsList, options);
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.once("error", reject);
    child.once("close", (code) => {
      if (code === 0) {
        resolvePromise({ stdout, stderr });
      } else {
        reject(
          new Error(
            `offline-cache proof child failed with exit code ${code ?? "unknown"}`,
          ),
        );
      }
    });
  });
}

function localDockerExecutable() {
  const executable = DOCKER_CANDIDATES.find((candidate) =>
    existsSync(candidate),
  );
  assert.ok(
    executable,
    "local Docker executable must be available for the proof",
  );
  return executable;
}

function proofRunArguments(name) {
  return [
    "run",
    "--interactive",
    "--rm",
    "--name",
    name,
    "--network",
    "none",
    "--ipc",
    "none",
    "--read-only",
    "--log-driver",
    "none",
    "--user",
    "65532:65532",
    "--cap-drop",
    "ALL",
    "--security-opt",
    "no-new-privileges:true",
    "--security-opt",
    `seccomp=${resolve(SCRIPT_DIRECTORY, "seccomp-bootstrap.json")}`,
    "--pids-limit",
    String(LIMITS.pids),
    "--memory",
    String(LIMITS.memoryBytes),
    "--memory-swap",
    String(LIMITS.memoryBytes),
    "--cpus",
    "1",
    "--ulimit",
    "nofile=64:64",
    "--tmpfs",
    TMPFS_SPEC,
    "--workdir",
    "/work",
    "--label",
    "coditza.local-proof=true",
    "--pull=never",
    runtimeLock.sandbox.localImage.id,
  ];
}

function containerExists(name) {
  return new Promise((resolvePromise) => {
    const child = spawn(localDockerExecutable(), ["inspect", name], {
      cwd: REPOSITORY_ROOT,
      env: {
        HOME: process.env.HOME ?? "",
        PATH: "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
      },
      stdio: "ignore",
    });
    child.once("error", () => resolvePromise(false));
    child.once("close", (code) => resolvePromise(code === 0));
  });
}

async function removeExactContainer(name) {
  try {
    await spawnChecked(localDockerExecutable(), ["rm", "--force", name], {
      cwd: REPOSITORY_ROOT,
      env: {
        HOME: process.env.HOME ?? "",
        PATH: "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
      },
    });
  } catch {
    // The expected --rm path usually removes it before this recovery cleanup.
  }
}

async function assertInContainerWatchdogSurvivesClientLoss() {
  const name = `coditza-wasm-watchdog-${randomUUID().replaceAll("-", "")}`;
  const request = requestFor(
    "def solve(value):\n    while True:\n        pass\n",
  );
  const child = spawn(localDockerExecutable(), proofRunArguments(name), {
    cwd: REPOSITORY_ROOT,
    env: {
      HOME: process.env.HOME ?? "",
      PATH: "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
    },
    stdio: ["pipe", "ignore", "pipe"],
  });
  let ready = false;
  let readyResolve;
  const readyPromise = new Promise((resolvePromise, reject) => {
    readyResolve = resolvePromise;
    child.once("error", reject);
  });
  child.stderr.setEncoding("utf8");
  child.stderr.on("data", (chunk) => {
    if (chunk.includes('"stage":"ready"') && !ready) {
      ready = true;
      readyResolve();
    }
  });
  try {
    child.stdin.write(`${JSON.stringify(request)}\n`);
    await readyPromise;
    child.stdin.write("CODITZA_RUN\n");
    child.kill("SIGKILL");
    const deadline = Date.now() + LIMITS.learnerWallMs + 2_000;
    while (Date.now() < deadline && (await containerExists(name))) {
      await new Promise((resolvePromise) => setTimeout(resolvePromise, 100));
    }
    assert.equal(
      await containerExists(name),
      false,
      "in-container watchdog must end a detached learner run",
    );
  } finally {
    await removeExactContainer(name);
  }
}

async function assertOfflineCacheLoad() {
  const npmCli = process.env.npm_execpath;
  assert.ok(npmCli, "npm must expose its exact CLI path to the local proof");
  const temporaryRoot = await mkdtemp(join(tmpdir(), "coditza-wasm-offline-"));
  try {
    await mkdir(join(temporaryRoot, "apps/api"), { recursive: true });
    await Promise.all([
      copyFile(
        resolve(REPOSITORY_ROOT, "package.json"),
        join(temporaryRoot, "package.json"),
      ),
      copyFile(
        resolve(REPOSITORY_ROOT, "package-lock.json"),
        join(temporaryRoot, "package-lock.json"),
      ),
      copyFile(
        resolve(REPOSITORY_ROOT, "apps/api/package.json"),
        join(temporaryRoot, "apps/api/package.json"),
      ),
    ]);
    await spawnChecked(
      process.execPath,
      [npmCli, "ci", "--offline", "--ignore-scripts", "--omit=dev"],
      {
        cwd: temporaryRoot,
        env: { ...process.env, npm_config_update_notifier: "false" },
      },
    );
    const { stdout } = await spawnChecked(
      process.execPath,
      [
        "--input-type=module",
        "-e",
        "import { loadPyodide } from 'pyodide'; globalThis.fetch = () => { throw new Error('network fetch denied'); }; const p = await loadPyodide({ indexURL: process.cwd() + '/node_modules/pyodide/', jsglobals: Object.create(null), env: { HOME: '/nonexistent', LANG: 'C', LC_ALL: 'C', TZ: 'UTC', PYTHONHASHSEED: '1729', PYTHONINSPECT: '0' } }); process.stdout.write(JSON.stringify([p.runPython('40 + 2'), p.runPython(\"import sys; sys.version.split()[0]\")]));",
      ],
      { cwd: temporaryRoot, env: { ...process.env } },
    );
    assert.deepEqual(JSON.parse(stdout), [
      42,
      runtimeLock.runtime.pyodide.runtimePython,
    ]);
  } finally {
    await rm(temporaryRoot, { recursive: true, force: true });
  }
}

async function assertCompletedRun(source, publicCase) {
  const run = await runLocalSandbox(requestFor(source, publicCase));
  assert.equal(
    run.outcome,
    "completed",
    JSON.stringify({ outcome: run.outcome, inspection: run.inspection }),
  );
  assert.equal(run.cleanupConfirmed, true);
  assert.equal(run.localEngine, "unix");
  assertInspection(run.inspection);
  assert.ok(run.result, "completed run must have a closed proof result");
  assert.equal(run.result.protocolVersion, PROTOCOL_VERSION);
  assert.equal(run.result.resultKind, "local_public_proof");
  assert.equal("jobId" in run.result, false);
  assert.equal("files" in run.result, false);
  assert.equal(run.result.publicOutput, "");
  return run;
}

async function assertStrictValidation() {
  assert.throws(
    () => parseStrictJson('{"a":1,"a":2}'),
    /duplicate JSON object member/,
  );
  assert.throws(
    () => parseStrictJson(`${"[".repeat(33)}0${"]".repeat(33)}`),
    /nesting limit/,
  );

  const caseCollision = requestFor("def solve(value):\n    return value\n");
  caseCollision.files = [
    { path: "MAIN.py", content: "def solve(value):\n    return value\n" },
    { path: "main.py", content: "def solve(value):\n    return value\n" },
  ];
  assert.throws(() => validateRunnerRequest(caseCollision), /duplicate path/);

  const nulSource = requestFor("def solve(value):\n    return value\u0000\n");
  assert.throws(() => validateRunnerRequest(nulSource), /NUL/);

  const unknown = requestFor("def solve(value):\n    return value + 1\n");
  unknown.extra = true;
  assert.throws(() => validateRunnerRequest(unknown), /unknown fields/);

  const valid = requestFor("def solve(value):\n    return value + 1\n");
  const inconsistent = structuredClone(createSafeRunnerResult(valid, "passed"));
  inconsistent.limitFlags.time = true;
  assert.throws(
    () => validateRunnerResult(inconsistent),
    /non-limit runner verdict/,
  );
  const forgedEcho = structuredClone(createSafeRunnerResult(valid, "passed"));
  forgedEcho.digests.harness = `sha256:${"0".repeat(64)}`;
  assert.throws(
    () =>
      assertDigestMapMatches(
        forgedEcho.digests,
        valid.digests,
        "runner result",
      ),
    /harness/,
  );

  const forgedRequest = requestFor("def solve(value):\n    return value + 1\n");
  forgedRequest.digests.runtimeManifest = `sha256:${"0".repeat(64)}`;
  await assert.rejects(
    () => runLocalSandbox(forgedRequest),
    /runtime manifest digest/,
  );
}

async function main() {
  await assertRuntimeLock();
  await assertOfflineCacheLoad();
  await assertStrictValidation();

  // This source is correct only for the declared public test. A successful
  // proof must not imply a hidden/private-plan implementation.
  const normal = await assertCompletedRun(
    "def solve(value):\n    return value + 1 if value == 41 else 'not-public'\n",
  );
  assert.equal(normal.result.verdict, "passed");
  const repeated = await assertCompletedRun(
    "def solve(value):\n    return value + 1 if value == 41 else 'not-public'\n",
  );
  assert.equal(repeated.result.verdict, "passed");
  assert.equal(
    canonicalDigest(normal.result),
    canonicalDigest(repeated.result),
  );

  const deterministicSource = `
def solve(value):
    import datetime
    import os
    import random
    import time
    return {
        'hash': hash('coditza'),
        'random': random.random(),
        'random_instance': random.Random().random(),
        'time': time.time(),
        'datetime': datetime.datetime.now().isoformat(),
        'home': os.environ.get('HOME'),
        'tz': os.environ.get('TZ'),
    }
`;
  const deterministicExpected = {
    hash: 1_038_294_855,
    random: 0.9963723767827669,
    random_instance: 0.9963723767827669,
    time: 946_684_800,
    datetime: "2000-01-01T00:00:00",
    home: "/nonexistent",
    tz: "UTC",
  };
  const deterministic = await assertCompletedRun(deterministicSource, {
    input: 41,
    expected: deterministicExpected,
  });
  assert.equal(deterministic.result.verdict, "passed");
  const deterministicRepeated = await assertCompletedRun(deterministicSource, {
    input: 41,
    expected: deterministicExpected,
  });
  assert.equal(deterministicRepeated.result.verdict, "passed");
  assert.equal(
    canonicalDigest(deterministic.result),
    canonicalDigest(deterministicRepeated.result),
  );

  process.env.CODITZA_SANDBOX_CANARY = "not-a-secret-coditza-canary";
  const canary = await assertCompletedRun(
    "def solve(value):\n    import os\n    return os.environ.get('CODITZA_SANDBOX_CANARY', 'missing')\n",
    { input: 41, expected: "missing" },
  );
  assert.equal(canary.result.verdict, "passed");

  const jsBridge = await assertCompletedRun(
    "def solve(value):\n    import js\n    return 'escaped' if hasattr(js, 'process') else 'blocked'\n",
    { input: 41, expected: "blocked" },
  );
  assert.equal(jsBridge.result.verdict, "passed");

  const filesystem = await assertCompletedRun(
    "def solve(value):\n    try:\n        open('/sandbox/escape.txt', 'w').write('x')\n    except Exception:\n        return 'blocked'\n    return 'escaped'\n",
    { input: 41, expected: "blocked" },
  );
  assert.equal(filesystem.result.verdict, "passed");

  const entropy = await assertCompletedRun(
    "def solve(value):\n    import os\n    try:\n        os.urandom(1)\n    except Exception:\n        return 'blocked'\n    return 'escaped'\n",
    { input: 41, expected: "blocked" },
  );
  assert.equal(entropy.result.verdict, "passed");

  const network = await assertCompletedRun(
    "def solve(value):\n    try:\n        import socket\n        socket.create_connection(('198.51.100.1', 80), timeout=0.1)\n    except Exception:\n        return 'blocked'\n    return 'escaped'\n",
    { input: 41, expected: "blocked" },
  );
  assert.equal(network.result.verdict, "passed");

  const syntax = await assertCompletedRun("def solve(:\n    pass\n");
  assert.equal(syntax.result.verdict, "syntax_error");

  const outputFlood = await assertCompletedRun(
    "def solve(value):\n    for _ in range(80):\n        print('x' * 1024)\n    return value + 1\n",
  );
  assert.equal(outputFlood.result.verdict, "output_limit_exceeded");
  assert.equal(outputFlood.result.limitFlags.output, true);

  const timeout = await runLocalSandbox(
    requestFor("def solve(value):\n    while True:\n        pass\n"),
  );
  assert.equal(timeout.outcome, "completed");
  assert.equal(timeout.result?.verdict, "time_limit_exceeded");
  assert.equal(timeout.result?.limitFlags.time, true);
  assert.equal(timeout.cleanupConfirmed, true);
  assertInspection(timeout.inspection);

  await assertInContainerWatchdogSurvivesClientLoss();

  process.stdout.write("ARC-WASM local public-proof sandbox checks passed.\n");
}

main().catch((error) => {
  process.stderr.write(`${error.stack ?? error.message}\n`);
  process.exitCode = 1;
});
