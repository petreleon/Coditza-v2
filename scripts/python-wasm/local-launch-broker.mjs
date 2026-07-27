import { createHash, randomUUID } from "node:crypto";
import { existsSync, readFileSync, statSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

import {
  LIMITS,
  PROTOCOL_VERSION,
  assertDigestMapMatches,
  assertExactKeys,
  assertLocalProofInputDigests,
  canonicalDigest,
  canonicalJson,
  createSafeRunnerResult,
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
const BOOTSTRAP_SECCOMP_PATH = resolve(
  SCRIPT_DIRECTORY,
  "seccomp-bootstrap.json",
);
const DOCKER_CANDIDATES = [
  "/opt/homebrew/bin/docker",
  "/usr/local/bin/docker",
  "/usr/bin/docker",
];
const MAX_CONTROL_BYTES = 8 * 1024;
const DOCKER_COMMAND_TIMEOUT_MS = 5_000;
const TMPFS_SPEC = `/work:rw,noexec,nosuid,nodev,size=${LIMITS.scratchBytes},nr_inodes=${LIMITS.scratchRegularFiles},mode=0700,uid=65532,gid=65532`;

function sha256(bytes) {
  return `sha256:${createHash("sha256").update(bytes).digest("hex")}`;
}

function hashFile(path) {
  return sha256(readFileSync(path));
}

function dockerExecutable() {
  const executable = DOCKER_CANDIDATES.find((candidate) =>
    existsSync(candidate),
  );
  if (executable === undefined) {
    throw new Error("the fixed local Docker executable was not found");
  }
  return executable;
}

function dockerEnvironment() {
  // Docker needs the operator's existing configuration only to resolve its
  // current context. assertLocalUnixEngine rejects every non-Unix/remote target.
  return {
    HOME: process.env.HOME ?? "",
    PATH: "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
  };
}

function spawnDocker(argumentsList, options = Object.create(null)) {
  return spawn(dockerExecutable(), argumentsList, {
    cwd: REPOSITORY_ROOT,
    env: dockerEnvironment(),
    stdio: options.stdio ?? ["ignore", "pipe", "pipe"],
  });
}

function invokeDocker(argumentsList, timeoutMs = DOCKER_COMMAND_TIMEOUT_MS) {
  return new Promise((resolvePromise, reject) => {
    const child = spawnDocker(argumentsList);
    let stdout = "";
    let stderr = "";
    let timedOut = false;
    const timeout = setTimeout(() => {
      timedOut = true;
      child.kill("SIGKILL");
    }, timeoutMs);
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.once("error", (error) => {
      clearTimeout(timeout);
      reject(error);
    });
    child.once("close", (code) => {
      clearTimeout(timeout);
      if (!timedOut && code === 0) {
        resolvePromise({ stdout, stderr });
        return;
      }
      reject(new Error("fixed local Docker command failed"));
    });
  });
}

async function assertLocalUnixEngine() {
  const { stdout: contextOutput } = await invokeDocker(["context", "show"]);
  const context = contextOutput.trim();
  if (!/^[A-Za-z0-9_.-]{1,128}$/.test(context)) {
    throw new Error("Docker context name is not a safe local identifier");
  }
  const { stdout: endpointOutput } = await invokeDocker([
    "context",
    "inspect",
    context,
    "--format",
    '{{(index .Endpoints "docker").Host}}',
  ]);
  const endpoint = endpointOutput.trim();
  if (!endpoint.startsWith("unix://")) {
    throw new Error(
      "local Python/WASM proof refuses a non-Unix Docker endpoint",
    );
  }
  const socketPath = endpoint.slice("unix://".length);
  if (
    !socketPath.startsWith("/") ||
    !existsSync(socketPath) ||
    !statSync(socketPath).isSocket()
  ) {
    throw new Error(
      "local Python/WASM proof requires an existing local Docker socket",
    );
  }
  return Object.freeze({ context, endpoint: "unix" });
}

function loadRuntimeLock() {
  const bytes = readFileSync(RUNTIME_LOCK_PATH);
  const lock = JSON.parse(bytes);
  const imageId = lock?.sandbox?.localImage?.id;
  const imageFiles = lock?.sandbox?.imageFiles;
  if (typeof imageId !== "string" || !/^sha256:[a-f0-9]{64}$/.test(imageId)) {
    throw new Error(
      "local Python/WASM image is not pinned in the runtime lock",
    );
  }
  if (
    imageFiles === null ||
    typeof imageFiles !== "object" ||
    Array.isArray(imageFiles)
  ) {
    throw new Error("runtime lock lacks image-side hash inventory");
  }
  const requiredHashes = [
    lock?.sandbox?.bootstrapSeccompPolicy,
    lock?.sandbox?.runner,
    lock?.sandbox?.policy,
    lock?.sandbox?.nativeGateBinary,
  ];
  if (
    requiredHashes.some(
      (value) =>
        typeof value !== "string" || !/^sha256:[a-f0-9]{64}$/.test(value),
    )
  ) {
    throw new Error("runtime lock lacks a required trusted hash");
  }
  return Object.freeze({
    lock,
    imageId,
    imageFiles: Object.freeze({ ...imageFiles }),
    runtimeManifestDigest: sha256(bytes),
    harnessDigest: canonicalDigest({
      protocolVersion: lock.protocol?.version,
      profile: lock.protocol?.profile,
      runner: lock.sandbox.runner,
      policy: lock.sandbox.policy,
      nativeGateBinary: lock.sandbox.nativeGateBinary,
      bootstrapSeccompPolicy: lock.sandbox.bootstrapSeccompPolicy,
    }),
  });
}

function assertTrustedRequestBinding(request, runtimeLock) {
  const validatedRequest = validateRunnerRequest(request);
  assertLocalProofInputDigests(validatedRequest);
  if (validatedRequest.digests.harness !== runtimeLock.harnessDigest) {
    throw new Error(
      "runner request harness digest does not match the locked proof harness",
    );
  }
  if (
    validatedRequest.digests.runtimeManifest !==
    runtimeLock.runtimeManifestDigest
  ) {
    throw new Error(
      "runner request runtime manifest digest does not match the locked manifest",
    );
  }
  return validatedRequest;
}

function imageHashArguments(imageId, paths) {
  return [
    "run",
    "--rm",
    "--network",
    "none",
    "--read-only",
    "--user",
    "65532:65532",
    "--cap-drop",
    "ALL",
    "--security-opt",
    "no-new-privileges:true",
    "--entrypoint",
    "/usr/bin/sha256sum",
    "--pull=never",
    imageId,
    ...paths,
  ];
}

async function imageFileHashes(imageId, expectedFiles) {
  const paths = Object.keys(expectedFiles).sort();
  const { stdout } = await invokeDocker(imageHashArguments(imageId, paths));
  const hashes = Object.create(null);
  for (const line of stdout.trim().split("\n")) {
    const match = /^([a-f0-9]{64})\s+(.+)$/.exec(line);
    if (match === null || !(match[2] in expectedFiles)) {
      throw new Error("could not parse a locked image-side hash");
    }
    hashes[match[2]] = `sha256:${match[1]}`;
  }
  assertExactKeys(hashes, paths, "image-side hash inventory");
  for (const path of paths) {
    if (hashes[path] !== expectedFiles[path]) {
      throw new Error("local image content drifted from the runtime lock");
    }
  }
  return Object.freeze(hashes);
}

async function assertRuntimeIntegrity(runtimeLock) {
  if (
    hashFile(BOOTSTRAP_SECCOMP_PATH) !==
    runtimeLock.lock.sandbox.bootstrapSeccompPolicy
  ) {
    throw new Error("bootstrap seccomp profile drifted from the runtime lock");
  }
  const { stdout } = await invokeDocker([
    "image",
    "inspect",
    runtimeLock.imageId,
    "--format",
    "{{.Id}}",
  ]);
  if (stdout.trim() !== runtimeLock.imageId) {
    throw new Error(
      "the pinned local Python/WASM image is unavailable or drifted",
    );
  }
  await imageFileHashes(runtimeLock.imageId, runtimeLock.imageFiles);
}

function sanitizeInspection(rawInspection) {
  const host = rawInspection.HostConfig ?? Object.create(null);
  const config = rawInspection.Config ?? Object.create(null);
  const state = rawInspection.State ?? Object.create(null);
  const mounts = Array.isArray(rawInspection.Mounts)
    ? rawInspection.Mounts
    : [];
  return Object.freeze({
    user: config.User ?? "",
    networkMode: host.NetworkMode ?? "",
    ipcMode: host.IpcMode ?? "",
    pidMode: host.PidMode ?? "",
    utsMode: host.UTSMode ?? "",
    usernsMode: host.UsernsMode ?? "",
    privileged: host.Privileged === true,
    readOnlyRootfs: host.ReadonlyRootfs === true,
    capDrop: [...(host.CapDrop ?? [])].sort(),
    securityOpt: [...(host.SecurityOpt ?? [])].sort(),
    pidsLimit: host.PidsLimit ?? 0,
    memory: host.Memory ?? 0,
    memorySwap: host.MemorySwap ?? 0,
    nanoCpus: host.NanoCpus ?? 0,
    mountCount: mounts.length,
    nonTmpfsMountCount: mounts.filter((mount) => mount.Type !== "tmpfs").length,
    bindCount: Array.isArray(host.Binds) ? host.Binds.length : 0,
    volumeCount: Array.isArray(host.Mounts) ? host.Mounts.length : 0,
    volumesFromCount: Array.isArray(host.VolumesFrom)
      ? host.VolumesFrom.length
      : 0,
    deviceCount: Array.isArray(host.Devices) ? host.Devices.length : 0,
    deviceRequestCount: Array.isArray(host.DeviceRequests)
      ? host.DeviceRequests.length
      : 0,
    portBindingCount: Object.keys(host.PortBindings ?? Object.create(null))
      .length,
    publishAllPorts: host.PublishAllPorts === true,
    dnsCount: Array.isArray(host.Dns) ? host.Dns.length : 0,
    dnsOptionCount: Array.isArray(host.DnsOptions) ? host.DnsOptions.length : 0,
    dnsSearchCount: Array.isArray(host.DnsSearch) ? host.DnsSearch.length : 0,
    extraHostCount: Array.isArray(host.ExtraHosts) ? host.ExtraHosts.length : 0,
    restartPolicy: host.RestartPolicy?.Name ?? "",
    logDriver: host.LogConfig?.Type ?? "",
    autoRemove: host.AutoRemove === true,
    tmpfsMounts: Object.entries(host.Tmpfs ?? Object.create(null))
      .map(([path, options]) => `${path}:${options}`)
      .sort(),
    hostCanaryPresent: (config.Env ?? []).some((entry) =>
      entry.startsWith("CODITZA_SANDBOX_CANARY="),
    ),
    oomKilled: state.OOMKilled === true,
    exitCode: typeof state.ExitCode === "number" ? state.ExitCode : -1,
  });
}

function assertCompliantInspection(inspection) {
  const expectedTmpfs = [`/work:${TMPFS_SPEC.slice("/work:".length)}`];
  if (
    inspection.user !== "65532:65532" ||
    inspection.networkMode !== "none" ||
    inspection.ipcMode !== "none" ||
    inspection.pidMode === "host" ||
    inspection.utsMode === "host" ||
    inspection.usernsMode === "host" ||
    inspection.privileged ||
    !inspection.readOnlyRootfs ||
    JSON.stringify(inspection.capDrop) !== JSON.stringify(["ALL"]) ||
    !inspection.securityOpt.includes("no-new-privileges:true") ||
    !inspection.securityOpt.some((option) => option.startsWith("seccomp=")) ||
    inspection.pidsLimit !== LIMITS.pids ||
    inspection.memory !== LIMITS.memoryBytes ||
    inspection.memorySwap !== LIMITS.memoryBytes ||
    inspection.nanoCpus !== 1_000_000_000 ||
    inspection.nonTmpfsMountCount !== 0 ||
    inspection.bindCount !== 0 ||
    inspection.volumeCount !== 0 ||
    inspection.volumesFromCount !== 0 ||
    inspection.deviceCount !== 0 ||
    inspection.deviceRequestCount !== 0 ||
    inspection.portBindingCount !== 0 ||
    inspection.publishAllPorts ||
    inspection.dnsCount !== 0 ||
    inspection.dnsOptionCount !== 0 ||
    inspection.dnsSearchCount !== 0 ||
    inspection.extraHostCount !== 0 ||
    !["", "no"].includes(inspection.restartPolicy) ||
    inspection.logDriver !== "none" ||
    !inspection.autoRemove ||
    JSON.stringify(inspection.tmpfsMounts) !== JSON.stringify(expectedTmpfs) ||
    inspection.hostCanaryPresent
  ) {
    throw new Error(
      "fixed local Docker inspection is not compliant with python-basic-v1",
    );
  }
}

async function inspectContainer(name) {
  const { stdout } = await invokeDocker(["inspect", name]);
  const inspected = JSON.parse(stdout);
  if (!Array.isArray(inspected) || inspected.length !== 1) {
    throw new Error("fixed Docker inspection did not return one container");
  }
  return sanitizeInspection(inspected[0]);
}

async function containerIsAbsent(name) {
  try {
    await invokeDocker(["inspect", name]);
    return false;
  } catch {
    return true;
  }
}

async function ensureContainerCleanup(name) {
  for (let attempt = 0; attempt < 10; attempt += 1) {
    if (await containerIsAbsent(name)) return true;
    await new Promise((resolvePromise) => setTimeout(resolvePromise, 50));
  }
  try {
    await invokeDocker(["rm", "--force", name]);
  } catch {
    // A daemon failure leaves the result untrusted; the final absence check is
    // the only cleanup success signal.
  }
  return containerIsAbsent(name);
}

async function killContainer(name) {
  try {
    await invokeDocker(["kill", "--signal=KILL", name]);
  } catch {
    // The runner can exit between timeout detection and exact-ID termination.
  }
}

function makeContainerName() {
  return `coditza-wasm-${randomUUID().replaceAll("-", "")}`;
}

function runnerArguments(name, imageId) {
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
    `seccomp=${BOOTSTRAP_SECCOMP_PATH}`,
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
    imageId,
  ];
}

function validateControl(control) {
  if (control?.stage === "ready") {
    assertExactKeys(
      control,
      [
        "stage",
        "protocolVersion",
        "architecture",
        "cpuHardLimitSeconds",
        "postBootstrapSeccomp",
        "tsyncWorkerVerified",
        "deterministicBootstrap",
      ],
      "runner ready control",
    );
    if (
      control.protocolVersion !== PROTOCOL_VERSION ||
      control.architecture !== "aarch64" ||
      typeof control.cpuHardLimitSeconds !== "number" ||
      control.cpuHardLimitSeconds < 1 ||
      control.postBootstrapSeccomp !== true ||
      control.tsyncWorkerVerified !== true ||
      control.deterministicBootstrap !== true
    ) {
      throw new Error(
        "runner ready control is not an attested local proof state",
      );
    }
    return "ready";
  }
  if (control?.stage === "rejected_or_failed") {
    assertExactKeys(
      control,
      ["stage", "protocolVersion"],
      "runner failure control",
    );
    if (control.protocolVersion !== PROTOCOL_VERSION) {
      throw new Error("runner failure control uses an unsupported protocol");
    }
    return "rejected_or_failed";
  }
  throw new Error("runner emitted an unknown control frame");
}

function createControlReader(onControl, onInvalid) {
  let remainder = "";
  let bytes = 0;
  return {
    push(chunk) {
      bytes += Buffer.byteLength(chunk, "utf8");
      if (bytes > MAX_CONTROL_BYTES) {
        onInvalid();
        return;
      }
      remainder += chunk;
      while (true) {
        const end = remainder.indexOf("\n");
        if (end === -1) return;
        const line = remainder.slice(0, end);
        remainder = remainder.slice(end + 1);
        try {
          if (!line.startsWith("CODITZA_CONTROL "))
            throw new Error("non-control stderr");
          onControl(
            validateControl(
              parseStrictJson(
                line.slice("CODITZA_CONTROL ".length),
                MAX_CONTROL_BYTES,
              ),
            ),
          );
        } catch {
          onInvalid();
          return;
        }
      }
    },
    finish() {
      if (remainder !== "") onInvalid();
    },
  };
}

export async function runLocalSandbox(request) {
  await assertLocalUnixEngine();
  const runtimeLock = loadRuntimeLock();
  await assertRuntimeIntegrity(runtimeLock);
  const validatedRequest = assertTrustedRequestBinding(request, runtimeLock);
  const name = makeContainerName();
  const serializedRequest = canonicalJson(validatedRequest);
  const run = spawnDocker(runnerArguments(name, runtimeLock.imageId), {
    stdio: ["pipe", "pipe", "pipe"],
  });
  let stdout = "";
  let inspection = null;
  let termination = null;
  let ready = false;
  let controlInvalid = false;
  let killPromise = Promise.resolve();
  let learnerTimer;
  let resolveReady;
  let rejectReady;
  const readyPromise = new Promise((resolvePromise, reject) => {
    resolveReady = resolvePromise;
    rejectReady = reject;
  });
  const terminate = (reason) => {
    if (termination !== null) return killPromise;
    termination = reason;
    killPromise = killContainer(name);
    return killPromise;
  };
  const initializationTimer = setTimeout(() => {
    void terminate("initialization_timeout");
  }, LIMITS.initializationWallMs);

  const completion = new Promise((resolvePromise, reject) => {
    const controls = createControlReader(
      (kind) => {
        if (kind === "ready") {
          if (ready) {
            controlInvalid = true;
            rejectReady(new Error("runner emitted duplicate ready control"));
            void terminate("control_protocol_failure");
            return;
          }
          ready = true;
          clearTimeout(initializationTimer);
          resolveReady();
          return;
        }
        controlInvalid = true;
        rejectReady(new Error("runner rejected its trusted bootstrap"));
        void terminate("control_protocol_failure");
      },
      () => {
        if (!controlInvalid) {
          controlInvalid = true;
          rejectReady(new Error("runner control pipe is invalid"));
          void terminate("control_protocol_failure");
        }
      },
    );
    run.stdout.setEncoding("utf8");
    run.stderr.setEncoding("utf8");
    run.stdout.on("data", (chunk) => {
      stdout += chunk;
      if (Buffer.byteLength(stdout, "utf8") > LIMITS.resultBytes + 1024) {
        stdout = stdout.slice(0, LIMITS.resultBytes + 1024);
        void terminate("result_pipe_limit");
      }
    });
    run.stderr.on("data", (chunk) => controls.push(chunk));
    run.stderr.on("end", () => controls.finish());
    run.once("error", reject);
    run.once("close", (code, signal) => {
      controls.finish();
      if (!ready && !controlInvalid)
        rejectReady(new Error("runner exited before ready control"));
      resolvePromise({ code, signal });
    });
    run.stdin.write(`${serializedRequest}\n`);
  });

  let completionState;
  let completionFailure = null;
  try {
    await readyPromise;
    inspection = await inspectContainer(name);
    assertCompliantInspection(inspection);
    run.stdin.write("CODITZA_RUN\n");
    learnerTimer = setTimeout(() => {
      void terminate("learner_wall_timeout");
    }, LIMITS.learnerWallMs + 250);
    completionState = await completion;
  } catch (error) {
    completionFailure = error;
    if (termination === null) await terminate("broker_or_control_failure");
    try {
      completionState = await completion;
    } catch (completionError) {
      completionFailure ??= completionError;
    }
  } finally {
    clearTimeout(initializationTimer);
    clearTimeout(learnerTimer);
    run.stdin.end();
  }

  await killPromise;
  let result = null;
  if (ready && !controlInvalid && stdout.trim() !== "") {
    try {
      result = validateRunnerResult(
        parseStrictJson(stdout.trim(), LIMITS.resultBytes),
      );
      assertDigestMapMatches(
        result.digests,
        validatedRequest.digests,
        "runner result",
      );
    } catch {
      termination ??= "runner_protocol_failure";
      result = null;
    }
  }
  if (inspection?.oomKilled === true) {
    result = createSafeRunnerResult(validatedRequest, "memory_limit_exceeded");
    termination = null;
  } else if (
    result === null &&
    ready &&
    ["learner_wall_timeout", "time_limit"].includes(termination ?? "")
  ) {
    result = createSafeRunnerResult(validatedRequest, "time_limit_exceeded");
    termination = null;
  } else if (result !== null) {
    termination = null;
  } else if (!ready && termination === null) {
    termination = "bootstrap_failure";
  } else if (termination === null && completionFailure !== null) {
    termination = "broker_launch_failure";
  } else if (termination === null && completionState?.code !== 0) {
    termination = "runner_failure";
  } else if (termination === null) {
    termination = "runner_failure";
  }
  const cleanupConfirmed = await ensureContainerCleanup(name);
  return Object.freeze({
    result,
    outcome: result === null ? termination : "completed",
    inspection,
    cleanupConfirmed,
    localEngine: "unix",
  });
}

export async function inspectPinnedLocalImage() {
  await assertLocalUnixEngine();
  const runtimeLock = loadRuntimeLock();
  await assertRuntimeIntegrity(runtimeLock);
  return Object.freeze({
    id: runtimeLock.imageId,
    imageFiles: runtimeLock.imageFiles,
  });
}
