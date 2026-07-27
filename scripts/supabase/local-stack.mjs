import { spawn } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import { promises as fs } from "node:fs";
import { createServer } from "node:net";
import path from "node:path";
import { fileURLToPath } from "node:url";

const repositoryRoot = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "../..",
);
const supabaseDirectory = path.join(repositoryRoot, "supabase");
const configPath = path.join(supabaseDirectory, "config.toml");
const migrationsDirectory = path.join(supabaseDirectory, "migrations");
const seedPath = path.join(supabaseDirectory, "seed.sql");
const localEnvironmentPath = path.join(repositoryRoot, ".env.supabase.local");
const localCliStateRoot = path.join(repositoryRoot, ".supabase", "local-cli");
const cliEntrypoint = path.join(
  repositoryRoot,
  "node_modules",
  "supabase",
  "dist",
  "supabase.js",
);
const dockerCandidates = [
  "/opt/homebrew/bin/docker",
  "/usr/local/bin/docker",
  "/usr/bin/docker",
];
const projectId = "coditza-local";
const networkName = "coditza-supabase-local";
const maxCapturedOutputBytes = 8 * 1024 * 1024;
const actions = new Set([
  "start",
  "status",
  "capture-env",
  "verify-resets",
  "stop",
]);
const dangerousDockerEnvironmentNames = [
  "CONTAINER_HOST",
  "DOCKER_CERT_PATH",
  "DOCKER_CONFIG",
  "DOCKER_CONTEXT",
  "DOCKER_HOST",
  "DOCKER_TLS",
  "DOCKER_TLS_VERIFY",
];
const localStateDirectoryNames = new Set([".branches", ".temp", "backups"]);
const migrationFilenamePattern = /^(\d{14})_[a-z0-9][a-z0-9_-]*\.sql$/u;
const seedExecutionMarker = "CODITZA_LOCAL_SEED_V1";

class LocalStackError extends Error {
  constructor(message) {
    super(message);
    this.name = "LocalStackError";
  }
}

function fail(message) {
  throw new LocalStackError(message);
}

function writeLine(message) {
  process.stdout.write(`${message}\n`);
}

function assertInvocation() {
  const [, , action, ...extraArguments] = process.argv;

  if (!actions.has(action) || extraArguments.length > 0) {
    fail(
      "Use one fixed local action: start, status, capture-env, verify-resets, or stop.",
    );
  }

  return action;
}

function assertSafeProcessEnvironment() {
  if (Object.keys(process.env).some((name) => name.startsWith("SUPABASE_"))) {
    fail("The local Supabase launcher refuses inherited Supabase overrides.");
  }

  for (const name of dangerousDockerEnvironmentNames) {
    if (process.env[name]?.trim()) {
      fail("The local Supabase launcher refuses Docker target overrides.");
    }
  }
}

function dockerEnvironment() {
  const environment = { ...process.env };

  for (const name of Object.keys(environment)) {
    if (name.startsWith("SUPABASE_")) {
      delete environment[name];
    }
  }

  for (const name of dangerousDockerEnvironmentNames) {
    delete environment[name];
  }

  return environment;
}

function cliEnvironment(cliHome) {
  return {
    PATH: "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin",
    SUPABASE_HOME: cliHome,
    SUPABASE_NO_KEYRING: "1",
    SUPABASE_TELEMETRY_DISABLED: "1",
  };
}

function failureMessageFor(failure, stdout = "", stderr = "") {
  return typeof failure === "function" ? failure({ stdout, stderr }) : failure;
}

function runCaptured(command, argumentsList, failureMessage, options) {
  return new Promise((resolve, reject) => {
    let stdout = "";
    let stderr = "";
    let capturedBytes = 0;
    let outputTruncated = false;

    let child;

    try {
      child = spawn(command, argumentsList, {
        cwd: options.cwd,
        env: options.environment,
        stdio: ["ignore", "pipe", "pipe"],
        windowsHide: true,
      });
    } catch {
      reject(new LocalStackError(failureMessageFor(failureMessage)));
      return;
    }

    const capture = (stream) => (chunk) => {
      if (capturedBytes + chunk.length > maxCapturedOutputBytes) {
        outputTruncated = true;
        return;
      }

      capturedBytes += chunk.length;

      if (stream === "stdout") {
        stdout += chunk;
      } else {
        stderr += chunk;
      }
    };

    child.stdout.on("data", capture("stdout"));
    child.stderr.on("data", capture("stderr"));
    child.once("error", () =>
      reject(new LocalStackError(failureMessageFor(failureMessage))),
    );
    child.once("close", (code) => {
      if (code !== 0) {
        reject(
          new LocalStackError(
            failureMessageFor(failureMessage, stdout, stderr),
          ),
        );
        return;
      }

      // CLI output can contain local keys. It remains only in private process
      // memory and is discarded after a bounded amount during noisy image pulls.
      void outputTruncated;
      if (options.returnResult === true) {
        resolve(Object.freeze({ stderr, stdout }));
        return;
      }

      void stderr;
      resolve(stdout);
    });
  });
}

function localCliFailure({ stdout, stderr }) {
  const output = `${stdout}\n${stderr}`.toLowerCase();

  if (/address already in use|port is already allocated/u.test(output)) {
    return "The local Supabase stack could not start because an approved local port is already in use.";
  }

  if (/no space left on device|disk quota exceeded/u.test(output)) {
    return "The local Supabase stack could not start because the local Docker storage is full.";
  }

  if (
    /cannot connect to the docker daemon|docker daemon is not running/u.test(
      output,
    )
  ) {
    return "The local Supabase stack could not start because the local Docker daemon is unavailable.";
  }

  if (/pull access denied|failed to pull|manifest unknown/u.test(output)) {
    return "The local Supabase stack could not retrieve a required local image.";
  }

  if (/config\.toml|invalid.*config|configuration.*invalid/u.test(output)) {
    return "The local Supabase stack rejected the reviewed local configuration.";
  }

  return "The local Supabase stack did not start successfully.";
}

async function readRegularFile(filePath, failureMessage) {
  let metadata;

  try {
    metadata = await fs.lstat(filePath);
  } catch {
    fail(failureMessage);
  }

  if (!metadata.isFile() || metadata.isSymbolicLink()) {
    fail(failureMessage);
  }

  try {
    return await fs.readFile(filePath, "utf8");
  } catch {
    fail(failureMessage);
  }
}

async function assertNoRepositoryLinkState() {
  const linkedProjectPath = path.join(
    repositoryRoot,
    ".supabase",
    "project.json",
  );

  try {
    await fs.lstat(linkedProjectPath);
  } catch (error) {
    if (error && typeof error === "object" && error.code === "ENOENT") {
      return;
    }

    fail("The repository Supabase link state cannot be verified.");
  }

  fail("The repository contains Supabase linked-project state.");
}

function hasActiveEnvironmentInterpolation(config) {
  return config.split(/\r?\n/u).some((line) => {
    const commentStart = line.indexOf("#");
    const activeLine = commentStart === -1 ? line : line.slice(0, commentStart);
    return /\benv\s*\(/iu.test(activeLine);
  });
}

function readSection(config, sectionName) {
  const lines = config.split(/\r?\n/u);
  let inRequestedSection = false;
  const sectionLines = [];

  for (const line of lines) {
    const section = line.match(/^\[([^\]]+)\]\s*$/u)?.[1];

    if (section !== undefined) {
      if (inRequestedSection) {
        break;
      }

      inRequestedSection = section === sectionName;
      continue;
    }

    if (inRequestedSection) {
      sectionLines.push(line);
    }
  }

  if (!inRequestedSection || sectionLines.length === 0) {
    fail("The local Supabase configuration is incomplete.");
  }

  return sectionLines.join("\n");
}

function hasExactBoolean(section, key, expectedValue) {
  return new RegExp(`^${key}\\s*=\\s*${expectedValue}\\s*$`, "mu").test(
    section,
  );
}

function hasExactInteger(section, key, expectedValue) {
  return new RegExp(`^${key}\\s*=\\s*${expectedValue}\\s*$`, "mu").test(
    section,
  );
}

function assertApprovedConfiguration(config) {
  if (
    !new RegExp(`^project_id\\s*=\\s*"${projectId}"\\s*$`, "mu").test(config)
  ) {
    fail(
      "The local Supabase configuration does not identify the approved local project.",
    );
  }

  if (hasActiveEnvironmentInterpolation(config)) {
    fail(
      "The local Supabase configuration contains unsafe environment interpolation.",
    );
  }

  if (/^\[remotes\./mu.test(config)) {
    fail("The local Supabase configuration contains a remote target.");
  }

  const api = readSection(config, "api");
  const database = readSection(config, "db");
  const dbMigrations = readSection(config, "db.migrations");
  const dbSeed = readSection(config, "db.seed");
  const studio = readSection(config, "studio");
  const localSmtp = readSection(config, "local_smtp");
  const mfa = readSection(config, "auth.mfa");
  const totp = readSection(config, "auth.mfa.totp");
  const phone = readSection(config, "auth.mfa.phone");

  if (
    !hasExactBoolean(api, "enabled", "true") ||
    !hasExactInteger(api, "port", 54321) ||
    !hasExactInteger(database, "port", 54322) ||
    !hasExactInteger(database, "shadow_port", 54320) ||
    !hasExactBoolean(studio, "enabled", "true") ||
    !hasExactInteger(studio, "port", 54323) ||
    !hasExactBoolean(localSmtp, "enabled", "true") ||
    !hasExactInteger(localSmtp, "port", 54324)
  ) {
    fail(
      "The local Supabase URL/port configuration is not the approved loopback mapping.",
    );
  }

  if (
    !hasExactBoolean(dbMigrations, "enabled", "true") ||
    !/^schema_paths\s*=\s*\[\]\s*$/mu.test(dbMigrations) ||
    !hasExactBoolean(dbSeed, "enabled", "true") ||
    !/^sql_paths\s*=\s*\["\.\/seed\.sql"\]\s*$/mu.test(dbSeed)
  ) {
    fail(
      "The local Supabase migration or seed configuration is not deterministic.",
    );
  }

  if (
    !hasExactInteger(mfa, "max_enrolled_factors", 2) ||
    !hasExactBoolean(totp, "enroll_enabled", "false") ||
    !hasExactBoolean(totp, "verify_enabled", "false") ||
    !hasExactBoolean(phone, "enroll_enabled", "false") ||
    !hasExactBoolean(phone, "verify_enabled", "false")
  ) {
    fail(
      "The local MFA configuration does not preserve the approved deferred policy.",
    );
  }
}

async function readApprovedConfiguration() {
  const config = await readRegularFile(
    configPath,
    "The local Supabase configuration is missing or unsafe.",
  );
  assertApprovedConfiguration(config);
}

function sha256(value) {
  return createHash("sha256").update(value, "utf8").digest("hex");
}

async function readApprovedResetInputs() {
  let directoryMetadata;

  try {
    directoryMetadata = await fs.lstat(migrationsDirectory);
  } catch {
    fail("The reviewed local migration directory is missing.");
  }

  if (!directoryMetadata.isDirectory() || directoryMetadata.isSymbolicLink()) {
    fail("The reviewed local migration directory is unsafe.");
  }

  let entries;

  try {
    entries = await fs.readdir(migrationsDirectory, { withFileTypes: true });
  } catch {
    fail("The reviewed local migration directory cannot be read.");
  }

  const migrations = [];

  for (const entry of entries) {
    const match = entry.name.match(migrationFilenamePattern);

    if (
      !match ||
      !entry.isFile() ||
      entry.isSymbolicLink() ||
      entry.isDirectory()
    ) {
      fail("The reviewed local migration directory contains an unsafe file.");
    }

    const content = await readRegularFile(
      path.join(migrationsDirectory, entry.name),
      "A reviewed local migration is missing or unsafe.",
    );
    migrations.push(
      Object.freeze({
        digest: sha256(content),
        version: match[1],
      }),
    );
  }

  migrations.sort((left, right) => left.version.localeCompare(right.version));

  if (migrations.length === 0) {
    fail("The local reset workflow requires at least one reviewed migration.");
  }

  for (let index = 1; index < migrations.length; index += 1) {
    if (migrations[index - 1].version === migrations[index].version) {
      fail("The reviewed local migration versions are not unique.");
    }
  }

  const seed = await readRegularFile(
    seedPath,
    "The reviewed deterministic local seed is missing or unsafe.",
  );
  const manifestLines = [
    "coditza-local-reset-v1",
    ...migrations.map(
      (migration) => "migration=" + migration.version + ":" + migration.digest,
    ),
    "seed=" + sha256(seed),
  ];

  return Object.freeze({
    manifest: sha256(manifestLines.join("\n")),
    migrationCount: migrations.length,
    migrationVersions: Object.freeze(
      migrations.map((migration) => migration.version),
    ),
  });
}

async function assertCliEntrypoint() {
  await readRegularFile(
    cliEntrypoint,
    "The pinned project-local Supabase CLI is unavailable.",
  );
}

async function dockerExecutable() {
  for (const candidate of dockerCandidates) {
    try {
      await fs.access(candidate);
      return candidate;
    } catch {
      // Try the next reviewed local Docker path.
    }
  }

  fail("The fixed local Docker executable is unavailable.");
}

function runDocker(docker, argumentsList, failureMessage) {
  return runCaptured(docker, argumentsList, failureMessage, {
    cwd: repositoryRoot,
    environment: dockerEnvironment(),
  });
}

async function assertLocalDockerContext(docker) {
  const contextName = (
    await runDocker(
      docker,
      ["context", "show"],
      "The selected Docker context cannot be verified as local.",
    )
  ).trim();

  if (!/^[A-Za-z0-9_.-]{1,128}$/u.test(contextName)) {
    fail("The selected Docker context cannot be verified as local.");
  }

  const endpoint = (
    await runDocker(
      docker,
      [
        "context",
        "inspect",
        contextName,
        "--format",
        '{{(index .Endpoints "docker").Host}}',
      ],
      "The selected Docker context cannot be verified as local.",
    )
  ).trim();

  if (!endpoint.startsWith("unix://")) {
    fail(
      "The local Supabase launcher requires a local Unix-socket Docker context.",
    );
  }

  const socketPath = endpoint.slice("unix://".length);

  try {
    if (
      !socketPath.startsWith("/") ||
      !(await fs.stat(socketPath)).isSocket()
    ) {
      fail(
        "The local Supabase launcher requires an available local Docker socket.",
      );
    }
  } catch (error) {
    if (error instanceof LocalStackError) {
      throw error;
    }

    fail(
      "The local Supabase launcher requires an available local Docker socket.",
    );
  }
}

async function inspectNetwork(docker) {
  const output = await runDocker(
    docker,
    ["network", "inspect", networkName],
    "The dedicated local Supabase network cannot be inspected.",
  );

  let network;

  try {
    [network] = JSON.parse(output);
  } catch {
    fail("The dedicated local Supabase network cannot be verified.");
  }

  if (
    !network ||
    network.Name !== networkName ||
    network.Driver !== "bridge" ||
    network.Options?.["com.docker.network.bridge.host_binding_ipv4"] !==
      "127.0.0.1"
  ) {
    fail(
      "The dedicated local Supabase network does not enforce loopback publication.",
    );
  }
}

async function ensureLoopbackNetwork(docker) {
  const names = (
    await runDocker(
      docker,
      [
        "network",
        "ls",
        "--filter",
        `name=^${networkName}$`,
        "--format",
        "{{.Name}}",
      ],
      "The dedicated local Supabase network cannot be inspected.",
    )
  )
    .split(/\r?\n/u)
    .map((line) => line.trim())
    .filter(Boolean);

  if (names.length === 0) {
    await runDocker(
      docker,
      [
        "network",
        "create",
        "--driver",
        "bridge",
        "--opt",
        "com.docker.network.bridge.host_binding_ipv4=127.0.0.1",
        networkName,
      ],
      "The dedicated local Supabase network could not be created.",
    );
  } else if (names.length !== 1 || names[0] !== networkName) {
    fail("The dedicated local Supabase network cannot be verified.");
  }

  await inspectNetwork(docker);
}

async function runningProjectContainerIds(docker) {
  const output = await runDocker(
    docker,
    [
      "ps",
      "--filter",
      `label=com.supabase.cli.project=${projectId}`,
      "--format",
      "{{.ID}}",
    ],
    "The local Supabase container bindings cannot be inspected.",
  );
  const ids = output
    .split(/\r?\n/u)
    .map((line) => line.trim())
    .filter(Boolean);

  if (!ids.every((id) => /^[a-f0-9]{12,64}$/u.test(id))) {
    fail("The local Supabase container bindings cannot be verified.");
  }

  return ids;
}

function isLoopbackBinding(hostIp) {
  return hostIp === "127.0.0.1" || hostIp === "::1";
}

async function assertNoPublicBindings(docker) {
  const containerIds = await runningProjectContainerIds(docker);

  if (containerIds.length === 0) {
    fail("The expected local Supabase containers are not running.");
  }

  const output = await runDocker(
    docker,
    ["inspect", "--format", "{{json .NetworkSettings.Ports}}", ...containerIds],
    "The local Supabase container bindings cannot be inspected.",
  );
  const portMaps = output
    .split(/\r?\n/u)
    .filter(Boolean)
    .map((line) => {
      try {
        return JSON.parse(line);
      } catch {
        fail("The local Supabase container bindings cannot be verified.");
      }
    });

  for (const portMap of portMaps) {
    if (portMap === null || typeof portMap !== "object") {
      fail("The local Supabase container bindings cannot be verified.");
    }

    for (const bindings of Object.values(portMap)) {
      if (bindings === null) {
        continue;
      }

      if (!Array.isArray(bindings)) {
        fail("The local Supabase container bindings cannot be verified.");
      }

      for (const binding of bindings) {
        if (
          !binding ||
          typeof binding !== "object" ||
          !isLoopbackBinding(binding.HostIp) ||
          typeof binding.HostPort !== "string" ||
          binding.HostPort.length === 0
        ) {
          fail("A local Supabase service is not bound only to loopback.");
        }
      }
    }
  }
}

async function assertProjectStopped(docker) {
  if ((await runningProjectContainerIds(docker)).length !== 0) {
    fail("The local Supabase stack did not stop cleanly.");
  }
}

async function assertLocalShadowPortAvailable() {
  await new Promise((resolve, reject) => {
    const server = createServer();
    let settled = false;

    function rejectUnavailable() {
      if (settled) {
        return;
      }

      settled = true;
      server.close(() => {
        reject(
          new LocalStackError(
            "The reviewed local database shadow port is unavailable.",
          ),
        );
      });
    }

    server.once("error", rejectUnavailable);
    server.listen(
      {
        exclusive: true,
        host: "127.0.0.1",
        port: 54320,
      },
      () => {
        if (settled) {
          return;
        }

        settled = true;
        server.close((error) => {
          if (error) {
            reject(
              new LocalStackError(
                "The reviewed local database shadow port cannot be released.",
              ),
            );
            return;
          }

          resolve();
        });
      },
    );
  });
}

async function assertLocalAuthHealth() {
  let response;

  try {
    response = await fetch("http://127.0.0.1:54321/auth/v1/health", {
      signal: AbortSignal.timeout(5_000),
    });
  } catch {
    fail("The local Supabase Auth service is not healthy.");
  }

  if (!response.ok) {
    fail("The local Supabase Auth service is not healthy.");
  }

  await response.body?.cancel();
}

function localUrls() {
  return Object.freeze({
    api: "http://127.0.0.1:54321",
    database: "127.0.0.1:54322",
    studio: "http://127.0.0.1:54323",
    mailpit: "http://127.0.0.1:54324",
    analytics: "127.0.0.1:54327",
  });
}

function printSafeMapping() {
  const urls = localUrls();
  writeLine("Local Supabase stack is healthy and loopback-only.");
  writeLine(`API: ${urls.api}`);
  writeLine(`Auth issuer: ${urls.api}/auth/v1`);
  writeLine(`PostgreSQL TCP: ${urls.database}`);
  writeLine(`Studio: ${urls.studio}`);
  writeLine(`Mailpit: ${urls.mailpit}`);
  writeLine(`Analytics TCP: ${urls.analytics}`);
}

function isEnvironmentFile(name) {
  return name === ".env" || name.startsWith(".env.");
}

async function copyReviewedSupabaseTree(sourceDirectory, destinationDirectory) {
  try {
    await fs.mkdir(destinationDirectory, { mode: 0o700 });
    await fs.chmod(destinationDirectory, 0o700);
  } catch {
    fail("The isolated local Supabase configuration directory is unsafe.");
  }

  const entries = await fs.readdir(sourceDirectory, { withFileTypes: true });

  for (const entry of entries) {
    if (localStateDirectoryNames.has(entry.name)) {
      continue;
    }

    if (isEnvironmentFile(entry.name) || entry.name === ".supabase") {
      fail("The reviewed Supabase directory contains unsafe local state.");
    }

    const sourcePath = path.join(sourceDirectory, entry.name);
    const destinationPath = path.join(destinationDirectory, entry.name);

    if (entry.isSymbolicLink()) {
      fail("The reviewed Supabase directory contains an unsafe symbolic link.");
    }

    if (entry.isDirectory()) {
      await copyReviewedSupabaseTree(sourcePath, destinationPath);
      continue;
    }

    if (!entry.isFile()) {
      fail(
        "The reviewed Supabase directory contains an unsupported file type.",
      );
    }

    await fs.copyFile(sourcePath, destinationPath);
  }
}

async function ensurePrivateDirectory(directory) {
  try {
    const metadata = await fs.lstat(directory);

    if (!metadata.isDirectory() || metadata.isSymbolicLink()) {
      fail("The isolated local Supabase state directory is unsafe.");
    }
  } catch (error) {
    if (error instanceof LocalStackError) {
      throw error;
    }

    try {
      await fs.mkdir(directory, { mode: 0o700, recursive: true });
    } catch {
      fail("The isolated local Supabase state directory could not be created.");
    }
  }

  try {
    await fs.chmod(directory, 0o700);
  } catch {
    fail("The isolated local Supabase state directory could not be secured.");
  }
}

async function createPrivateWorkspace() {
  let workspace;

  try {
    workspace = await fs.mkdtemp(path.join(localCliStateRoot, "workspace-"));
    await fs.chmod(workspace, 0o700);
  } catch {
    fail("The isolated local Supabase workspace could not be created.");
  }

  return workspace;
}

async function removePrivateWorkspace(workspace) {
  if (
    path.dirname(workspace) !== localCliStateRoot ||
    !path.basename(workspace).startsWith("workspace-")
  ) {
    fail("The isolated local Supabase workspace cannot be cleaned safely.");
  }

  try {
    const metadata = await fs.lstat(workspace);

    if (!metadata.isDirectory() || metadata.isSymbolicLink()) {
      fail("The isolated local Supabase workspace cannot be cleaned safely.");
    }

    await fs.rm(workspace, { force: false, maxRetries: 3, recursive: true });
  } catch (error) {
    if (error instanceof LocalStackError) {
      throw error;
    }

    fail("The isolated local Supabase workspace could not be cleaned safely.");
  }
}

async function assertNoIsolatedDotenvFiles(workspace) {
  const directories = [workspace, path.join(workspace, "supabase")];

  for (const directory of directories) {
    let entries;

    try {
      entries = await fs.readdir(directory, { withFileTypes: true });
    } catch (error) {
      if (error && typeof error === "object" && error.code === "ENOENT") {
        continue;
      }

      fail("The isolated local Supabase workspace cannot be verified.");
    }

    if (entries.some((entry) => isEnvironmentFile(entry.name))) {
      fail(
        "The isolated local Supabase workspace contains an environment file.",
      );
    }
  }
}

async function assertNoIsolatedLinkState(workspace) {
  const stateDirectories = [
    path.join(workspace, ".supabase"),
    path.join(workspace, "supabase", ".supabase"),
  ];

  for (const stateDirectory of stateDirectories) {
    try {
      await fs.lstat(stateDirectory);
    } catch (error) {
      if (error && typeof error === "object" && error.code === "ENOENT") {
        continue;
      }

      fail("The isolated local Supabase link state cannot be verified.");
    }

    fail(
      "The isolated local Supabase workspace contains linked-project state.",
    );
  }
}

async function withIsolatedCliWorkspace(includeConfiguration, action) {
  const isolatedRoot = path.dirname(localCliStateRoot);

  await ensurePrivateDirectory(isolatedRoot);
  await ensurePrivateDirectory(localCliStateRoot);
  const workspace = await createPrivateWorkspace();

  try {
    const cliHome = path.join(workspace, "cli-home");
    await ensurePrivateDirectory(cliHome);

    if (includeConfiguration) {
      const isolatedSupabaseDirectory = path.join(workspace, "supabase");
      await copyReviewedSupabaseTree(
        supabaseDirectory,
        isolatedSupabaseDirectory,
      );
      assertApprovedConfiguration(
        await readRegularFile(
          path.join(isolatedSupabaseDirectory, "config.toml"),
          "The isolated local Supabase configuration is missing or unsafe.",
        ),
      );
    }

    await assertNoIsolatedDotenvFiles(workspace);
    await assertNoIsolatedLinkState(workspace);

    return await action(
      Object.freeze({
        cliHome,
        workspace,
      }),
    );
  } finally {
    await removePrivateWorkspace(workspace);
  }
}

function runSupabase(workspace, argumentsList, failureMessage) {
  return runCaptured(
    process.execPath,
    [cliEntrypoint, "--workdir", workspace.workspace, ...argumentsList],
    failureMessage,
    {
      cwd: workspace.workspace,
      environment: cliEnvironment(workspace.cliHome),
    },
  );
}

function runSupabaseResult(workspace, argumentsList, failureMessage) {
  return runCaptured(
    process.execPath,
    [cliEntrypoint, "--workdir", workspace.workspace, ...argumentsList],
    failureMessage,
    {
      cwd: workspace.workspace,
      environment: cliEnvironment(workspace.cliHome),
      returnResult: true,
    },
  );
}

function localResetFailure({ stdout, stderr }) {
  const output = (stdout + "\n" + stderr).toLowerCase();

  if (/not running|cannot connect|connection refused/u.test(output)) {
    return "The reviewed local Supabase stack must be running before reset.";
  }

  if (/migration.*(failed|error)|seed.*(failed|error)/u.test(output)) {
    return "The reviewed local migration or seed baseline could not be reset.";
  }

  return "The reviewed local database reset did not complete.";
}

function localSchemaDiffFailure({ stdout, stderr }) {
  const output = (stdout + "\n" + stderr).toLowerCase();

  if (/permission denied|operation not permitted/u.test(output)) {
    return "The local migration schema diff could not access the local Docker engine.";
  }

  if (/pull access denied|failed to pull|manifest unknown/u.test(output)) {
    return "The local migration schema diff could not retrieve its local diff image.";
  }

  if (/shadow|migra|pg-schema|pg-delta/u.test(output)) {
    return "The local migration schema diff engine did not initialize.";
  }

  if (
    /connection refused|database system is starting|cannot connect/u.test(
      output,
    )
  ) {
    return "The local migration schema diff could not reach the local database.";
  }

  return "The local migration schema diff could not be verified.";
}

function parseJsonOutput(output, failureMessage) {
  try {
    return JSON.parse(output);
  } catch {
    fail(failureMessage);
  }
}

function assertExpectedMigrationHistory(output, expectedVersions) {
  const migrationHistory = parseJsonOutput(
    output,
    "The local migration history format is unsupported.",
  );
  const reviewedVersions = [...expectedVersions].sort();

  if (
    !migrationHistory ||
    typeof migrationHistory !== "object" ||
    Array.isArray(migrationHistory) ||
    !Array.isArray(migrationHistory.migrations) ||
    migrationHistory.migrations.length !== reviewedVersions.length
  ) {
    fail(
      "The local database migration history does not match the reviewed baseline.",
    );
  }

  for (const [index, migration] of migrationHistory.migrations.entries()) {
    const expectedVersion = reviewedVersions[index];

    if (
      !migration ||
      typeof migration !== "object" ||
      Array.isArray(migration) ||
      migration.local !== expectedVersion ||
      migration.remote !== expectedVersion
    ) {
      fail(
        "The local database migration history does not match the reviewed baseline.",
      );
    }
  }

  return reviewedVersions;
}

function assertSeedExecution({ stdout, stderr }) {
  if (
    !stdout.includes(seedExecutionMarker) &&
    !stderr.includes(seedExecutionMarker)
  ) {
    fail("The reviewed deterministic local seed did not execute.");
  }
}

function assertEmptySchemaDiff(output) {
  const schemaDiff = parseJsonOutput(
    output,
    "The local migration schema diff format is unsupported.",
  );

  if (
    !schemaDiff ||
    typeof schemaDiff !== "object" ||
    typeof schemaDiff.diff !== "string" ||
    !Array.isArray(schemaDiff.dropStatements) ||
    schemaDiff.diff.trim().length > 0 ||
    schemaDiff.dropStatements.length > 0
  ) {
    fail(
      "The local database has public-schema drift outside reviewed migrations.",
    );
  }

  return sha256(schemaDiff.diff);
}

function assertEmptyLintResult(output) {
  const lint = parseJsonOutput(
    output,
    "The local public-schema lint format is unsupported.",
  );

  if (
    !lint ||
    typeof lint !== "object" ||
    !Array.isArray(lint.results) ||
    lint.results.length > 0
  ) {
    fail("The local public-schema lint did not pass.");
  }

  return lint.results.length;
}

async function resetAndVerifyLocalDatabase(workspace, resetInputs) {
  const resetOutput = await runSupabaseResult(
    workspace,
    ["--network-id", networkName, "--yes", "db", "reset", "--local"],
    localResetFailure,
  );
  assertSeedExecution(resetOutput);
  const migrationHistory = await runSupabase(
    workspace,
    [
      "--network-id",
      networkName,
      "--output-format",
      "json",
      "migration",
      "list",
      "--local",
    ],
    "The local migration history could not be verified.",
  );
  const appliedVersions = assertExpectedMigrationHistory(
    migrationHistory,
    resetInputs.migrationVersions,
  );
  await assertLocalShadowPortAvailable();
  const schemaDiff = await runSupabase(
    workspace,
    [
      "--network-id",
      networkName,
      "--output-format",
      "json",
      "db",
      "diff",
      "--local",
      "--use-migra",
      "--schema",
      "public",
    ],
    localSchemaDiffFailure,
  );
  const schemaDiffDigest = assertEmptySchemaDiff(schemaDiff);
  await assertLocalShadowPortAvailable();
  const lintOutput = await runSupabase(
    workspace,
    [
      "--network-id",
      networkName,
      "--output-format",
      "json",
      "db",
      "lint",
      "--local",
      "--schema",
      "public",
      "--fail-on",
      "warning",
    ],
    "The local public-schema lint did not pass.",
  );
  const lintIssueCount = assertEmptyLintResult(lintOutput);

  return sha256(
    JSON.stringify({
      appliedVersions,
      lintIssueCount,
      manifest: resetInputs.manifest,
      schemaDiffDigest,
      seedExecuted: true,
    }),
  );
}

function printResetVerification(resetInputs, fingerprint) {
  writeLine("Two clean local database resets and migration discipline passed.");
  writeLine("Reviewed migration count: " + resetInputs.migrationCount);
  writeLine(
    "Deterministic migration-and-seed manifest SHA-256: " +
      resetInputs.manifest,
  );
  writeLine("Verified reset fingerprint SHA-256: " + fingerprint);
  writeLine("Applied local migration history matches the reviewed baseline.");
  writeLine("Public schema diff is empty; local public-schema lint passed.");
}

function parseEnvironmentOutput(output) {
  const entries = new Map();

  for (const rawLine of output.split(/\r?\n/u)) {
    if (rawLine.length === 0) {
      continue;
    }

    const separator = rawLine.indexOf("=");

    if (separator <= 0) {
      fail("The local Supabase credential capture format is unsupported.");
    }

    const name = rawLine.slice(0, separator);
    let value = rawLine.slice(separator + 1);

    if (!/^[A-Z0-9_]+$/u.test(name) || entries.has(name)) {
      fail("The local Supabase credential capture format is unsupported.");
    }

    if (value.startsWith('"') && value.endsWith('"')) {
      try {
        value = JSON.parse(value);
      } catch {
        fail("The local Supabase credential capture format is unsupported.");
      }
    }

    if (
      typeof value !== "string" ||
      value.includes("\n") ||
      value.includes("\r")
    ) {
      fail("The local Supabase credential capture format is unsupported.");
    }

    entries.set(name, value);
  }

  return entries;
}

function parseLoopbackApiUrl(value) {
  let url;

  try {
    url = new URL(value);
  } catch {
    fail("The local Supabase API URL is not approved.");
  }

  if (
    url.protocol !== "http:" ||
    url.hostname !== "127.0.0.1" ||
    url.port !== "54321" ||
    url.pathname !== "/" ||
    url.search ||
    url.hash ||
    url.username ||
    url.password
  ) {
    fail("The local Supabase API URL is not approved.");
  }

  return url;
}

function hasExpectedKeyPrefix(value, prefix) {
  return (
    typeof value === "string" &&
    new RegExp(`^${prefix}[A-Za-z0-9_-]+$`).test(value)
  );
}

async function readPublishedIssuer(apiUrl) {
  let response;

  try {
    response = await fetch(
      `${apiUrl.toString()}auth/v1/.well-known/openid-configuration`,
      {
        signal: AbortSignal.timeout(5_000),
      },
    );
  } catch {
    fail("The local Supabase Auth issuer could not be verified.");
  }

  if (!response.ok) {
    fail("The local Supabase Auth issuer could not be verified.");
  }

  let metadata;

  try {
    metadata = await response.json();
  } catch {
    fail("The local Supabase Auth issuer could not be verified.");
  }

  if (
    !metadata ||
    typeof metadata !== "object" ||
    typeof metadata.issuer !== "string"
  ) {
    fail("The local Supabase Auth issuer could not be verified.");
  }

  let issuer;

  try {
    issuer = new URL(metadata.issuer);
  } catch {
    fail("The local Supabase Auth issuer could not be verified.");
  }

  if (
    issuer.protocol !== "http:" ||
    issuer.hostname !== "127.0.0.1" ||
    issuer.port !== "54321" ||
    issuer.pathname !== "/auth/v1" ||
    issuer.search ||
    issuer.hash ||
    issuer.username ||
    issuer.password
  ) {
    fail("The local Supabase Auth issuer could not be verified.");
  }

  return issuer.toString();
}

async function writeCapturedEnvironment(values) {
  try {
    const existing = await fs.lstat(localEnvironmentPath);

    if (existing.isSymbolicLink() || !existing.isFile()) {
      fail("The ignored local environment target is unsafe.");
    }
  } catch (error) {
    if (error instanceof LocalStackError) {
      throw error;
    }
  }

  const apiUrl = parseLoopbackApiUrl(values.get("API_URL") ?? "");
  const publishableKey = values.get("PUBLISHABLE_KEY");
  const secretKey = values.get("SECRET_KEY");

  if (!hasExpectedKeyPrefix(publishableKey, "sb_publishable_")) {
    fail("The local stack did not provide a current publishable key.");
  }

  if (!hasExpectedKeyPrefix(secretKey, "sb_secret_")) {
    fail("The local stack did not provide a current secret key.");
  }

  const issuer = await readPublishedIssuer(apiUrl);
  const content = [
    "# Generated locally by npm run supabase:capture-env:local. Do not commit.",
    `SUPABASE_URL=${apiUrl.toString()}`,
    "SUPABASE_PROJECT_REF=local",
    `SUPABASE_PUBLISHABLE_KEY=${publishableKey}`,
    `SUPABASE_SECRET_KEY=${secretKey}`,
    `SUPABASE_JWT_ISSUER=${issuer}`,
    "SUPABASE_JWT_AUDIENCE=authenticated",
    "",
  ].join("\n");
  const temporaryPath = path.join(
    repositoryRoot,
    `.env.supabase.local.${randomUUID()}.tmp`,
  );

  try {
    await fs.writeFile(temporaryPath, content, {
      encoding: "utf8",
      flag: "wx",
      mode: 0o600,
    });
    await fs.chmod(temporaryPath, 0o600);
    await fs.rename(temporaryPath, localEnvironmentPath);
    await fs.chmod(localEnvironmentPath, 0o600);
  } catch {
    try {
      await fs.unlink(temporaryPath);
    } catch {
      // The temporary path either was never created or was atomically renamed.
    }

    fail("The ignored local Supabase environment file could not be written.");
  }
}

async function prepareConfiguredLifecycle() {
  assertSafeProcessEnvironment();
  await assertCliEntrypoint();
  await assertNoRepositoryLinkState();
  await readApprovedConfiguration();
  const docker = await dockerExecutable();
  await assertLocalDockerContext(docker);
  return docker;
}

async function prepareStop() {
  assertSafeProcessEnvironment();
  await assertCliEntrypoint();
  const docker = await dockerExecutable();
  await assertLocalDockerContext(docker);
  return docker;
}

async function main() {
  const action = assertInvocation();

  if (action === "stop") {
    const docker = await prepareStop();
    await withIsolatedCliWorkspace(false, (workspace) =>
      runSupabase(
        workspace,
        ["stop", "--project-id", projectId],
        "The local Supabase stack did not stop successfully.",
      ),
    );
    await assertProjectStopped(docker);
    writeLine(
      "Local Supabase stack stopped; named local volumes and the loopback network were preserved.",
    );
    return;
  }

  const docker = await prepareConfiguredLifecycle();

  if (action === "start") {
    await ensureLoopbackNetwork(docker);
    await withIsolatedCliWorkspace(true, (workspace) =>
      runSupabase(
        workspace,
        ["start", "--network-id", networkName],
        localCliFailure,
      ),
    );
    await inspectNetwork(docker);
    await assertNoPublicBindings(docker);
    await assertLocalAuthHealth();
    printSafeMapping();
    return;
  }

  if (action === "verify-resets") {
    await inspectNetwork(docker);
    const resetInputs = await readApprovedResetInputs();
    const firstFingerprint = await withIsolatedCliWorkspace(true, (workspace) =>
      resetAndVerifyLocalDatabase(workspace, resetInputs),
    );
    const secondFingerprint = await withIsolatedCliWorkspace(
      true,
      (workspace) => resetAndVerifyLocalDatabase(workspace, resetInputs),
    );

    if (firstFingerprint !== secondFingerprint) {
      fail("The two clean local database resets were not identical.");
    }

    await assertNoPublicBindings(docker);
    await assertLocalAuthHealth();
    printResetVerification(resetInputs, firstFingerprint);
    return;
  }

  if (action === "status") {
    await inspectNetwork(docker);
    await withIsolatedCliWorkspace(true, (workspace) =>
      runSupabase(
        workspace,
        ["status", "--network-id", networkName, "--output", "json"],
        "The local Supabase stack is not healthy.",
      ),
    );
    await assertNoPublicBindings(docker);
    await assertLocalAuthHealth();
    printSafeMapping();
    return;
  }

  await inspectNetwork(docker);
  const output = await withIsolatedCliWorkspace(true, (workspace) =>
    runSupabase(
      workspace,
      ["status", "--network-id", networkName, "--output", "env"],
      "The local Supabase credentials could not be captured.",
    ),
  );
  await assertNoPublicBindings(docker);
  await assertLocalAuthHealth();
  await writeCapturedEnvironment(parseEnvironmentOutput(output));
  writeLine(
    "Local Supabase credentials were stored in ignored mode-0600 local storage.",
  );
}

main().catch((error) => {
  const message =
    error instanceof LocalStackError
      ? error.message
      : "The local Supabase launcher failed without exposing command output.";
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
});
