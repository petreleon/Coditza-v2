import { spawnSync } from "node:child_process";
import { readdirSync, readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, join, relative, resolve, sep } from "node:path";
import { fileURLToPath } from "node:url";

import {
  expectedNegativeFixtures,
  expectedPositiveFixtures,
} from "./fixture-manifest.mjs";

const boundaryDirectory = dirname(fileURLToPath(import.meta.url));
const repositoryRoot = resolve(boundaryDirectory, "../../../../");
const fixturesDirectory = join(boundaryDirectory, "fixtures");
const depcruiseBinary = join(
  repositoryRoot,
  "node_modules",
  ".bin",
  process.platform === "win32" ? "depcruise.cmd" : "depcruise",
);
const require = createRequire(import.meta.url);
const boundaryConfiguration = require(
  join(repositoryRoot, ".dependency-cruiser.cjs"),
);

const productionSourcePatterns = [
  /^apps\/api\/src\/(?:app|server)\.ts$/,
  /^apps\/api\/src\/bootstrap\/.+\.ts$/,
  /^apps\/api\/src\/infrastructure\/(?:config|http|observability|supabase)\/.+\.ts$/,
  /^apps\/api\/src\/shared\/kernel\/.+\.ts$/,
  /^apps\/api\/src\/modules\/(?:identity|curriculum|assessment|progress|operations)\/(?:domain|application|adapters)\/.+\.ts$/,
  /^apps\/api\/src\/modules\/(?:identity|curriculum|assessment|progress|operations)\/public\.ts$/,
];

function fail(message) {
  throw new Error(`Boundary verification failed: ${message}`);
}

function toRepositoryPath(absolutePath) {
  return relative(repositoryRoot, absolutePath).split(sep).join("/");
}

function walk(directory) {
  const paths = [];

  for (const entry of readdirSync(directory, { withFileTypes: true }).sort(
    (left, right) => left.name.localeCompare(right.name),
  )) {
    const entryPath = join(directory, entry.name);

    if (entry.isDirectory()) {
      paths.push(...walk(entryPath));
    } else if (entry.isFile()) {
      paths.push(entryPath);
    }
  }

  return paths;
}

function readJson(repositoryPath) {
  return JSON.parse(readFileSync(join(repositoryRoot, repositoryPath), "utf8"));
}

function readJsonFile(absolutePath) {
  try {
    return JSON.parse(readFileSync(absolutePath, "utf8"));
  } catch (error) {
    fail(
      `could not parse ${toRepositoryPath(absolutePath)} as JSON: ${error.message}`,
    );
  }
}

function assertNoTypeScriptAliasInChain(absolutePath, visited = new Set()) {
  const repositoryPath = toRepositoryPath(absolutePath);

  if (repositoryPath.startsWith("../")) {
    fail(`TypeScript config extends outside the repository: ${absolutePath}.`);
  }

  if (visited.has(absolutePath)) {
    fail(`TypeScript config extends cyclically through ${repositoryPath}.`);
  }

  visited.add(absolutePath);

  const compilerOptions = readJsonFile(absolutePath).compilerOptions ?? {};

  if (
    Object.hasOwn(compilerOptions, "baseUrl") ||
    Object.hasOwn(compilerOptions, "paths")
  ) {
    fail(`${repositoryPath} adds a TypeScript resolution alias or base URL.`);
  }

  const extendsValue = readJsonFile(absolutePath).extends;

  if (extendsValue === undefined) {
    return;
  }

  if (
    typeof extendsValue !== "string" ||
    (!extendsValue.startsWith(".") && !extendsValue.startsWith("/"))
  ) {
    fail(
      `${repositoryPath} must use a repository-relative TypeScript extends value so aliases remain auditable.`,
    );
  }

  const extendedPath = resolve(
    dirname(absolutePath),
    extendsValue.endsWith(".json") ? extendsValue : `${extendsValue}.json`,
  );

  assertNoTypeScriptAliasInChain(extendedPath, visited);
}

function assertNoAliasBypass() {
  for (const configPath of ["tsconfig.base.json", "apps/api/tsconfig.json"]) {
    assertNoTypeScriptAliasInChain(join(repositoryRoot, configPath));
  }

  for (const packagePath of ["package.json", "apps/api/package.json"]) {
    if (Object.hasOwn(readJson(packagePath), "imports")) {
      fail(`${packagePath} adds a package import alias.`);
    }
  }
}

function assertProductionSourceCoverage() {
  const productionFiles = walk(join(repositoryRoot, "apps", "api", "src"))
    .filter((filePath) => filePath.endsWith(".ts"))
    .map(toRepositoryPath)
    .sort();

  if (productionFiles.length === 0) {
    fail("apps/api/src has no TypeScript source files to cover.");
  }

  const unknownFiles = productionFiles.filter(
    (filePath) =>
      !productionSourcePatterns.some((pattern) => pattern.test(filePath)),
  );

  if (unknownFiles.length > 0) {
    fail(
      `production source path is outside the configured architecture: ${unknownFiles.join(", ")}`,
    );
  }

  for (const filePath of productionFiles) {
    const source = readFileSync(join(repositoryRoot, filePath), "utf8");

    if (/\b(?:from\s+|import\s+)["']#/.test(source)) {
      fail(`${filePath} uses a package import alias.`);
    }
  }
}

function assertNoBoundaryBypass() {
  const options = boundaryConfiguration.options ?? {};

  for (const option of ["exclude", "includeOnly", "focus"]) {
    if (Object.hasOwn(options, option)) {
      fail(`dependency-cruiser options.${option} can bypass a boundary scan.`);
    }
  }

  if (options.doNotFollow?.path !== "node_modules") {
    fail(
      "dependency-cruiser may ignore only node_modules; source-graph exclusions are forbidden.",
    );
  }

  for (const rule of boundaryConfiguration.forbidden ?? []) {
    if (Object.hasOwn(rule.from ?? {}, "pathNot")) {
      fail(
        `dependency-cruiser rule ${rule.name} excludes source files with from.pathNot.`,
      );
    }
  }
}

function runDependencyCruiser(target) {
  const result = spawnSync(
    depcruiseBinary,
    ["--config", ".dependency-cruiser.cjs", "--", target],
    { cwd: repositoryRoot, encoding: "utf8" },
  );

  if (result.error) {
    fail(
      `dependency-cruiser could not start for ${target}: ${result.error.message}`,
    );
  }

  if (result.status === null) {
    fail(`dependency-cruiser ended by signal for ${target}.`);
  }

  return {
    output: `${result.stdout ?? ""}${result.stderr ?? ""}`,
    status: result.status,
  };
}

function dependencyEdgeCount(source, fixtureName, filePath) {
  if (/\b(?:require|import)\s*\(/.test(source)) {
    fail(
      `${fixtureName} uses a dynamic or CommonJS dependency in ${toRepositoryPath(filePath)}.`,
    );
  }

  const fromEdges =
    source.match(
      /\b(?:import|export)\s+(?:type\s+)?[^\n;]*?\s+from\s+["'][^"']+["']/g,
    ) ?? [];
  const sideEffectEdges = source.match(/^\s*import\s+["'][^"']+["']/gm) ?? [];

  return fromEdges.length + sideEffectEdges.length;
}

function findFixtureEntry(fixtureName) {
  const fixtureDirectory = join(fixturesDirectory, fixtureName);
  const allFixtureFiles = walk(fixtureDirectory);
  const unsupportedFiles = allFixtureFiles.filter(
    (filePath) => !filePath.endsWith(".ts"),
  );

  if (unsupportedFiles.length > 0) {
    fail(
      `${fixtureName} contains a non-TypeScript file: ${unsupportedFiles.map(toRepositoryPath).join(", ")}.`,
    );
  }

  const fixtureFiles = allFixtureFiles;
  const sourceFiles = fixtureFiles.filter(
    (filePath) =>
      dependencyEdgeCount(
        readFileSync(filePath, "utf8"),
        fixtureName,
        filePath,
      ) > 0,
  );
  const totalEdges = fixtureFiles.reduce(
    (count, filePath) =>
      count +
      dependencyEdgeCount(
        readFileSync(filePath, "utf8"),
        fixtureName,
        filePath,
      ),
    0,
  );

  if (sourceFiles.length !== 1 || totalEdges !== 1) {
    fail(
      `${fixtureName} must contain exactly one import/export dependency edge; found ${totalEdges} across ${sourceFiles.length} source files.`,
    );
  }

  return toRepositoryPath(sourceFiles[0]);
}

function assertFixtureManifest() {
  const expectedRuleByFixture = new Map();

  for (const [rule, fixtureNames] of Object.entries(expectedNegativeFixtures)) {
    for (const fixtureName of fixtureNames) {
      if (expectedRuleByFixture.has(fixtureName)) {
        fail(`fixture manifest duplicates ${fixtureName}.`);
      }

      expectedRuleByFixture.set(fixtureName, rule);
    }
  }

  for (const fixtureName of expectedPositiveFixtures) {
    if (expectedRuleByFixture.has(fixtureName)) {
      fail(`fixture manifest duplicates ${fixtureName}.`);
    }

    expectedRuleByFixture.set(fixtureName, null);
  }

  const fixtureEntries = readdirSync(fixturesDirectory, {
    withFileTypes: true,
  });
  const unsupportedEntries = fixtureEntries.filter(
    (entry) => !entry.isDirectory(),
  );

  if (unsupportedEntries.length > 0) {
    fail(
      `fixture root contains a non-directory entry: ${unsupportedEntries.map((entry) => entry.name).join(", ")}.`,
    );
  }

  const actualFixtureNames = fixtureEntries.map((entry) => entry.name).sort();
  const expectedFixtureNames = [...expectedRuleByFixture.keys()].sort();

  if (actualFixtureNames.join("\n") !== expectedFixtureNames.join("\n")) {
    fail(
      `fixture directories differ from the manifest: expected ${expectedFixtureNames.join(", ")}; found ${actualFixtureNames.join(", ")}.`,
    );
  }

  return expectedRuleByFixture;
}

function assertProductionGraph() {
  const result = runDependencyCruiser("apps/api/src");

  if (result.status !== 0 || /\berror BND-\d{3}:/.test(result.output)) {
    fail(`production graph must be clean:\n${result.output}`);
  }
}

function assertFixtureGraph(fixtureName, expectedRule) {
  const entry = findFixtureEntry(fixtureName);
  const result = runDependencyCruiser(entry);
  const reportedRules = [
    ...result.output.matchAll(/\berror (BND-\d{3}):/g),
  ].map((match) => match[1]);

  if (expectedRule === null) {
    if (result.status !== 0 || reportedRules.length !== 0) {
      fail(`${fixtureName} is an allowed edge but failed:\n${result.output}`);
    }

    return;
  }

  if (result.status === 0) {
    fail(`${fixtureName} unexpectedly passed without ${expectedRule}.`);
  }

  if (reportedRules.length !== 1 || reportedRules[0] !== expectedRule) {
    fail(
      `${fixtureName} must fail once with ${expectedRule}; received ${reportedRules.join(", ") || "no BND rule"}.\n${result.output}`,
    );
  }
}

assertNoAliasBypass();
assertProductionSourceCoverage();
assertNoBoundaryBypass();
assertProductionGraph();

const expectedRuleByFixture = assertFixtureManifest();

for (const fixtureName of [...expectedRuleByFixture.keys()].sort()) {
  assertFixtureGraph(fixtureName, expectedRuleByFixture.get(fixtureName));
}

const negativeFixtureCount = Object.values(expectedNegativeFixtures).reduce(
  (count, fixtureNames) => count + fixtureNames.length,
  0,
);

console.log(
  `Boundary verification passed: ${negativeFixtureCount} negative fixtures, ${expectedPositiveFixtures.length} positive fixtures, and the complete API source graph.`,
);
