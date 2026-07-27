import { createHash } from "node:crypto";
import { existsSync } from "node:fs";
import { readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawn } from "node:child_process";

import { loadPyodide } from "pyodide";

const SCRIPT_DIRECTORY = dirname(fileURLToPath(import.meta.url));
const REPOSITORY_ROOT = resolve(SCRIPT_DIRECTORY, "../..");
const IMAGE_TAG = "coditza/python-wasm-sandbox:arc-wasm-001";
const DOCKER_CANDIDATES = [
  "/opt/homebrew/bin/docker",
  "/usr/local/bin/docker",
  "/usr/bin/docker",
];
const ASSET_PATHS = [
  "package.json",
  "pyodide.asm.mjs",
  "pyodide.asm.wasm",
  "pyodide-lock.json",
  "pyodide.mjs",
  "python_stdlib.zip",
];

function usage() {
  process.stderr.write(
    "Usage: node scripts/python-wasm/build-local-sandbox.mjs --update-lock\n",
  );
  process.exitCode = 64;
}

function dockerExecutable() {
  const executable = DOCKER_CANDIDATES.find((candidate) =>
    existsSync(candidate),
  );
  if (executable === undefined) {
    throw new Error("fixed local Docker executable is unavailable");
  }
  return executable;
}

async function runDocker(argumentsList, stdio = "pipe") {
  const executable = dockerExecutable();
  return new Promise((resolvePromise, reject) => {
    const child = spawn(executable, argumentsList, {
      cwd: REPOSITORY_ROOT,
      env: {
        HOME: process.env.HOME ?? "",
        PATH: "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
      },
      stdio,
    });
    let stdout = "";
    let stderr = "";
    if (child.stdout !== null) {
      child.stdout.setEncoding("utf8");
      child.stdout.on("data", (chunk) => {
        stdout += chunk;
      });
    }
    if (child.stderr !== null) {
      child.stderr.setEncoding("utf8");
      child.stderr.on("data", (chunk) => {
        stderr += chunk;
      });
    }
    child.once("error", reject);
    child.once("close", (code) => {
      if (code === 0) {
        resolvePromise({ stdout, stderr });
      } else {
        reject(
          new Error(
            `fixed Docker build/inspection command failed with exit code ${code ?? "unknown"}`,
          ),
        );
      }
    });
  });
}

async function sha256(path) {
  const bytes = await readFile(path);
  return createHash("sha256").update(bytes).digest("hex");
}

async function imageHashes(imageId) {
  const internalPaths = [
    "/opt/coditza/native/seccomp-gate.node",
    "/opt/coditza/runner.mjs",
    "/opt/coditza/runtime-policy.mjs",
    "/usr/lib/aarch64-linux-gnu/libseccomp.so.2.5.4",
    ...ASSET_PATHS.map(
      (assetPath) => `/opt/coditza/node_modules/pyodide/${assetPath}`,
    ),
  ];
  const { stdout } = await runDocker([
    "run",
    "--rm",
    "--network",
    "none",
    "--entrypoint",
    "/usr/bin/sha256sum",
    imageId,
    ...internalPaths,
  ]);
  const result = Object.create(null);
  for (const line of stdout.trim().split("\n")) {
    const match = /^([a-f0-9]{64})\s+(.+)$/.exec(line);
    if (match === null)
      throw new Error("could not parse an internal image hash");
    result[match[2]] = `sha256:${match[1]}`;
  }
  return result;
}

async function runtimePythonVersion(assetDirectory) {
  const pyodide = await loadPyodide({
    indexURL: `${assetDirectory}/`,
    jsglobals: Object.create(null),
    env: {
      HOME: "/nonexistent",
      LANG: "C",
      LC_ALL: "C",
      TZ: "UTC",
      PYTHONHASHSEED: "1729",
      PYTHONINSPECT: "0",
    },
  });
  const version = pyodide.runPython("import sys; sys.version.split()[0]");
  if (typeof version !== "string" || !/^3\.14\.\d+$/.test(version)) {
    throw new Error(
      "could not derive the exact embedded CPython runtime version",
    );
  }
  return version;
}

async function main() {
  if (process.argv.slice(2).join(" ") !== "--update-lock") {
    usage();
    return;
  }

  await runDocker(
    [
      "build",
      "--platform",
      "linux/arm64",
      "--file",
      "Dockerfile.python-wasm-sandbox",
      "--tag",
      IMAGE_TAG,
      ".",
    ],
    "inherit",
  );
  const image = await runDocker([
    "image",
    "inspect",
    IMAGE_TAG,
    "--format",
    "{{.Id}}",
  ]);
  const imageId = image.stdout.trim();
  if (!/^sha256:[a-f0-9]{64}$/.test(imageId)) {
    throw new Error("local Docker image did not provide a content identifier");
  }

  const assetDirectory = resolve(REPOSITORY_ROOT, "node_modules/pyodide");
  const assets = Object.create(null);
  for (const assetPath of ASSET_PATHS) {
    assets[assetPath] =
      `sha256:${await sha256(resolve(assetDirectory, assetPath))}`;
  }
  const pyodideMetadata = JSON.parse(
    await readFile(resolve(assetDirectory, "pyodide-lock.json"), "utf8"),
  );
  const internal = await imageHashes(imageId);
  const runtimePython = await runtimePythonVersion(assetDirectory);
  const lock = {
    lockVersion: 1,
    reviewedAt: "2026-07-27",
    status: "local-proof-only",
    runtime: {
      pyodide: {
        npmPackage: "pyodide@314.0.3",
        npmTarball: "https://registry.npmjs.org/pyodide/-/pyodide-314.0.3.tgz",
        npmIntegrity:
          "sha512-sK40My6m8tmBUYtYH9au9rXUeh9x0wfahtHdOlGmJxZDsKBGKtP6KznyFB2+u/klbQTdDionR0uaVd176zVQzQ==",
        releaseUrl: "https://github.com/pyodide/pyodide/releases/tag/314.0.3",
        license: "MPL-2.0",
        runtimePython,
        abiPython: pyodideMetadata.info.python,
        abiVersion: pyodideMetadata.info.abi_version,
        platform: pyodideMetadata.info.platform,
        architecture: pyodideMetadata.info.arch,
        assets,
        allowedExternalPackages: [],
        runtimeFetchAllowed: false,
      },
      node: {
        version: "24.18.0",
        baseImage:
          "node:24.18.0-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d",
      },
    },
    protocol: {
      version: "coditza-python-runner-v1",
      fixtureVersion: "coditza-python-fixture-v1",
      profile: "python-basic-v1",
    },
    sandbox: {
      launcher: "local-docker-launch-broker-v1",
      localImage: {
        tag: IMAGE_TAG,
        id: imageId,
        architecture: "linux/arm64",
      },
      fixedUser: "65532:65532",
      bootstrapSeccompPolicy: `sha256:${await sha256(resolve(SCRIPT_DIRECTORY, "seccomp-bootstrap.json"))}`,
      nativeGateSource: `sha256:${await sha256(resolve(SCRIPT_DIRECTORY, "native/seccomp-gate.c"))}`,
      nativeGateBinary: internal["/opt/coditza/native/seccomp-gate.node"],
      libseccomp: {
        version: "2.5.4-1+deb12u1",
        library: internal["/usr/lib/aarch64-linux-gnu/libseccomp.so.2.5.4"],
      },
      runner: `sha256:${await sha256(resolve(SCRIPT_DIRECTORY, "runner.mjs"))}`,
      policy: `sha256:${await sha256(resolve(SCRIPT_DIRECTORY, "runtime-policy.mjs"))}`,
      localLaunchBroker: `sha256:${await sha256(resolve(SCRIPT_DIRECTORY, "local-launch-broker.mjs"))}`,
      dockerfile: `sha256:${await sha256(resolve(REPOSITORY_ROOT, "Dockerfile.python-wasm-sandbox"))}`,
      imageFiles: internal,
      profileLimits: {
        initializationWallMs: 15000,
        learnerWallMs: 5000,
        learnerCpuSeconds: 3,
        memoryBytes: 268435456,
        scratchBytes: 8388608,
        scratchRegularFiles: 128,
        sourceFiles: 16,
        sourceFileBytes: 65536,
        sourceTotalBytes: 262144,
        outputBytes: 65536,
        resultBytes: 131072,
        pids: 16,
      },
    },
    hostedExecution: {
      status: "unselected",
      requiredCapability:
        "A later approved private launcher must enforce equivalent or stronger controls and prove the same runtime lock before deployment.",
    },
  };
  await writeFile(
    resolve(REPOSITORY_ROOT, "python-wasm-runtime.lock.json"),
    `${JSON.stringify(lock, null, 2)}\n`,
  );
  process.stdout.write(`Pinned ${imageId} in python-wasm-runtime.lock.json\n`);
}

main().catch((error) => {
  process.stderr.write(`${error.message}\n`);
  process.exitCode = 1;
});
