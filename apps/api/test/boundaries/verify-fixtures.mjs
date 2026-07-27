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
const typescript = require("typescript");
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

function assertAppListenerBoundary() {
  const productionFiles = walk(join(repositoryRoot, "apps", "api", "src"))
    .filter((filePath) => filePath.endsWith(".ts"))
    .sort();
  const sources = productionFiles.map((filePath) => {
    const source = readFileSync(filePath, "utf8");
    const sourceFile = typescript.createSourceFile(
      filePath,
      source,
      typescript.ScriptTarget.Latest,
      true,
      typescript.ScriptKind.TS,
    );

    if (sourceFile.parseDiagnostics.length > 0) {
      fail(
        `${toRepositoryPath(filePath)} cannot be parsed for the app/listener ownership contract.`,
      );
    }

    return { repositoryPath: toRepositoryPath(filePath), sourceFile };
  });
  const appSource = sources.find(
    ({ repositoryPath }) => repositoryPath === "apps/api/src/app.ts",
  );
  const serverSource = sources.find(
    ({ repositoryPath }) => repositoryPath === "apps/api/src/server.ts",
  );
  const compositionSource = sources.find(
    ({ repositoryPath }) =>
      repositoryPath === "apps/api/src/bootstrap/composition-root.ts",
  );

  if (
    appSource === undefined ||
    serverSource === undefined ||
    compositionSource === undefined
  ) {
    fail("the app, server, and composition source files must all exist.");
  }

  const fastifyFactoryImports = [];
  const fastifyCalls = [];
  const buildAppDefinitions = [];
  const memberAccesses = [];
  const callExpressions = [];
  const productionEntryGuards = [];
  const startProductionServerDefinitions = [];
  const serverModuleReferences = [];
  const appBoundaryLeaks = [];

  const getPropertyName = (node) => {
    if (typescript.isPropertyAccessExpression(node)) {
      return node.name.text;
    }

    if (
      typescript.isElementAccessExpression(node) &&
      node.argumentExpression !== undefined &&
      typescript.isStringLiteral(node.argumentExpression)
    ) {
      return node.argumentExpression.text;
    }

    return undefined;
  };

  const getReceiverName = (node) => {
    if (
      (typescript.isPropertyAccessExpression(node) ||
        typescript.isElementAccessExpression(node)) &&
      typescript.isIdentifier(node.expression)
    ) {
      return node.expression.text;
    }

    return undefined;
  };

  const isExported = (node) =>
    node.modifiers?.some(
      (modifier) => modifier.kind === typescript.SyntaxKind.ExportKeyword,
    ) ?? false;

  const isReadonly = (node) =>
    node.modifiers?.some(
      (modifier) => modifier.kind === typescript.SyntaxKind.ReadonlyKeyword,
    ) ?? false;

  const isNamedType = (node, expectedName) =>
    node !== undefined &&
    typescript.isTypeReferenceNode(node) &&
    typescript.isIdentifier(node.typeName) &&
    node.typeName.text === expectedName;

  const isImportMetaMain = (node) =>
    typescript.isPropertyAccessExpression(node) &&
    node.name.text === "main" &&
    typescript.isMetaProperty(node.expression) &&
    node.expression.keywordToken === typescript.SyntaxKind.ImportKeyword &&
    node.expression.name.text === "meta";

  const isNodeInside = (node, container) =>
    node.pos >= container.pos && node.end <= container.end;

  const isServerModuleSpecifier = (moduleSpecifier, source) => {
    if (!moduleSpecifier.startsWith(".")) {
      return false;
    }

    const sourceDirectory = dirname(source.sourceFile.fileName);
    const resolvedCandidates = [
      resolve(sourceDirectory, moduleSpecifier),
      resolve(sourceDirectory, `${moduleSpecifier}.ts`),
    ];

    if (moduleSpecifier.endsWith(".js")) {
      resolvedCandidates.push(
        resolve(sourceDirectory, `${moduleSpecifier.slice(0, -3)}.ts`),
      );
    }

    return resolvedCandidates.includes(serverSource.sourceFile.fileName);
  };

  const isBoundaryHost = (node) =>
    (typescript.isPropertyAccessExpression(node) ||
      typescript.isElementAccessExpression(node)) &&
    typescript.isIdentifier(node.expression) &&
    ["app", "request", "reply"].includes(node.expression.text);

  const containsBoundaryReference = (node) => {
    let found = false;

    const visit = (candidate) => {
      if (
        typescript.isIdentifier(candidate) &&
        ["composition", "dependencies"].includes(candidate.text)
      ) {
        found = true;
        return;
      }

      if (!found) {
        typescript.forEachChild(candidate, visit);
      }
    };

    visit(node);
    return found;
  };

  const describeLocations = (records) =>
    records.map(({ source }) => source.repositoryPath).join(", ") || "none";

  for (const source of sources) {
    const visit = (node) => {
      if (
        typescript.isImportDeclaration(node) &&
        typescript.isStringLiteral(node.moduleSpecifier)
      ) {
        const moduleName = node.moduleSpecifier.text;

        if (moduleName === "fastify" && node.importClause?.name !== undefined) {
          fastifyFactoryImports.push({
            defaultImportName: node.importClause?.name?.text,
            node,
            source,
          });
        }

        if (isServerModuleSpecifier(moduleName, source)) {
          serverModuleReferences.push({ node, source });
        }
      }

      if (
        typescript.isExportDeclaration(node) &&
        node.moduleSpecifier !== undefined &&
        typescript.isStringLiteral(node.moduleSpecifier) &&
        isServerModuleSpecifier(node.moduleSpecifier.text, source)
      ) {
        serverModuleReferences.push({ node, source });
      }

      if (
        typescript.isFunctionDeclaration(node) &&
        node.name?.text === "buildApp"
      ) {
        buildAppDefinitions.push({ kind: "function", node, source });
      }

      if (
        typescript.isFunctionDeclaration(node) &&
        node.name?.text === "startProductionServer"
      ) {
        startProductionServerDefinitions.push({ node, source });
      }

      if (
        typescript.isVariableDeclaration(node) &&
        typescript.isIdentifier(node.name) &&
        node.name.text === "buildApp"
      ) {
        buildAppDefinitions.push({ kind: "variable", node, source });
      }

      if (typescript.isIfStatement(node) && isImportMetaMain(node.expression)) {
        productionEntryGuards.push({ node, source });
      }

      if (
        typescript.isPropertyAccessExpression(node) ||
        typescript.isElementAccessExpression(node)
      ) {
        const propertyName = getPropertyName(node);
        const receiverName = getReceiverName(node);
        const access = { node, propertyName, receiverName, source };

        memberAccesses.push(access);
      }

      if (
        typescript.isBinaryExpression(node) &&
        node.operatorToken.kind === typescript.SyntaxKind.EqualsToken &&
        isBoundaryHost(node.left) &&
        containsBoundaryReference(node.right)
      ) {
        appBoundaryLeaks.push({ node, source });
      }

      if (typescript.isCallExpression(node)) {
        const [moduleSpecifier] = node.arguments;

        if (
          moduleSpecifier !== undefined &&
          typescript.isStringLiteral(moduleSpecifier) &&
          ((node.expression.kind === typescript.SyntaxKind.ImportKeyword &&
            isServerModuleSpecifier(moduleSpecifier.text, source)) ||
            (typescript.isIdentifier(node.expression) &&
              node.expression.text === "require" &&
              isServerModuleSpecifier(moduleSpecifier.text, source)))
        ) {
          serverModuleReferences.push({ node, source });
        }

        if (
          typescript.isIdentifier(node.expression) &&
          node.expression.text === "Fastify"
        ) {
          fastifyCalls.push({ node, source });
        }

        if (
          typescript.isIdentifier(node.expression) &&
          ["startProductionServer", "startServer"].includes(
            node.expression.text,
          )
        ) {
          callExpressions.push({
            directCalleeName: node.expression.text,
            node,
            source,
          });
        } else {
          const propertyName = getPropertyName(node.expression);
          const receiverName = getReceiverName(node.expression);
          const call = { node, propertyName, receiverName, source };

          callExpressions.push(call);

          if (
            (receiverName === "Object" &&
              ["assign", "defineProperties", "defineProperty"].includes(
                propertyName,
              )) ||
            (receiverName === "Reflect" && propertyName === "set")
          ) {
            const [target] = node.arguments;

            if (
              target !== undefined &&
              typescript.isIdentifier(target) &&
              ["app", "request", "reply"].includes(target.text) &&
              node.arguments.slice(1).some(containsBoundaryReference)
            ) {
              appBoundaryLeaks.push(call);
            }
          }

          if (
            receiverName === "app" &&
            ["decorate", "decorateReply", "decorateRequest"].includes(
              propertyName,
            ) &&
            node.arguments.some(containsBoundaryReference)
          ) {
            appBoundaryLeaks.push(call);
          }
        }
      }

      typescript.forEachChild(node, visit);
    };

    visit(source.sourceFile);
  }

  if (
    fastifyFactoryImports.length !== 1 ||
    fastifyFactoryImports[0].source !== appSource ||
    fastifyFactoryImports[0].defaultImportName !== "Fastify"
  ) {
    fail(
      `Fastify must be default-imported exactly once by apps/api/src/app.ts; found ${describeLocations(fastifyFactoryImports)}.`,
    );
  }

  if (fastifyCalls.length !== 1 || fastifyCalls[0].source !== appSource) {
    fail(
      `Fastify must be constructed exactly once by apps/api/src/app.ts; found ${describeLocations(fastifyCalls)}.`,
    );
  }

  if (
    buildAppDefinitions.length !== 1 ||
    buildAppDefinitions[0].kind !== "function" ||
    buildAppDefinitions[0].source !== appSource
  ) {
    fail(
      `buildApp must be one function in apps/api/src/app.ts; found ${describeLocations(buildAppDefinitions)}.`,
    );
  }

  const [buildAppDefinition] = buildAppDefinitions;
  const buildAppParameters = buildAppDefinition.node.parameters;
  const [buildAppParameter] = buildAppParameters;
  const parameterNames =
    buildAppParameter !== undefined &&
    typescript.isObjectBindingPattern(buildAppParameter.name)
      ? buildAppParameter.name.elements.map((element) =>
          typescript.isIdentifier(element.name) ? element.name.text : undefined,
        )
      : [];

  if (
    !isExported(buildAppDefinition.node) ||
    buildAppParameters.length !== 1 ||
    parameterNames.join(",") !== "config,dependencies" ||
    !isNamedType(buildAppParameter?.type, "BuildAppOptions")
  ) {
    fail(
      "app.ts must expose buildApp({ config, dependencies }: BuildAppOptions).",
    );
  }

  if (!isNodeInside(fastifyCalls[0].node, buildAppDefinition.node)) {
    fail("Fastify construction must remain inside buildApp.");
  }

  if (serverModuleReferences.length > 0) {
    fail(
      `production source must not import, re-export, or dynamically load server.ts; found ${describeLocations(serverModuleReferences)}.`,
    );
  }

  const buildAppOptions = appSource.sourceFile.statements.filter(
    (statement) =>
      typescript.isInterfaceDeclaration(statement) &&
      statement.name.text === "BuildAppOptions",
  );

  if (buildAppOptions.length !== 1 || !isExported(buildAppOptions[0])) {
    fail("app.ts must export one BuildAppOptions interface.");
  }

  const optionMembers = buildAppOptions[0].members.filter((member) =>
    typescript.isPropertySignature(member),
  );
  const expectedOptionTypes = new Map([
    ["config", "ApiConfig"],
    ["dependencies", "ApiApplicationDependencies"],
  ]);

  if (optionMembers.length !== expectedOptionTypes.size) {
    fail("BuildAppOptions must expose only config and dependencies.");
  }

  for (const [name, typeName] of expectedOptionTypes) {
    const member = optionMembers.find(
      (candidate) =>
        typescript.isIdentifier(candidate.name) && candidate.name.text === name,
    );

    if (
      member === undefined ||
      !isReadonly(member) ||
      !isNamedType(member.type, typeName)
    ) {
      fail(`BuildAppOptions.${name} must be readonly ${typeName}.`);
    }
  }

  const listenerAccesses = memberAccesses.filter(
    ({ propertyName }) => propertyName === "listen",
  );
  const listenerCalls = callExpressions.filter(
    ({ propertyName }) => propertyName === "listen",
  );
  const [listenerCall] = listenerCalls;

  if (
    listenerAccesses.length !== 1 ||
    listenerCalls.length !== 1 ||
    listenerCall.source !== serverSource ||
    listenerCall.receiverName !== "app" ||
    !typescript.isAwaitExpression(listenerCall.node.parent)
  ) {
    fail(
      `server.ts must contain the only awaited app.listen() call; found ${describeLocations(listenerAccesses)}.`,
    );
  }

  const readyAccesses = memberAccesses.filter(
    ({ propertyName, receiverName }) =>
      propertyName === "ready" && receiverName === "app",
  );
  const readyCalls = callExpressions.filter(
    ({ propertyName, receiverName }) =>
      propertyName === "ready" && receiverName === "app",
  );
  const [readyCall] = readyCalls;

  if (
    readyAccesses.length !== 1 ||
    readyCalls.length !== 1 ||
    readyCall.source !== serverSource ||
    readyCall.receiverName !== "app" ||
    !typescript.isAwaitExpression(readyCall.node.parent) ||
    readyCall.node.pos >= listenerCall.node.pos
  ) {
    fail("server.ts must await app.ready() before the sole app.listen() call.");
  }

  const processExitAccesses = memberAccesses.filter(
    ({ propertyName, receiverName }) =>
      propertyName === "exit" && receiverName === "process",
  );
  const processExitCalls = callExpressions.filter(
    ({ propertyName, receiverName }) =>
      propertyName === "exit" && receiverName === "process",
  );
  const [processExitCall] = processExitCalls;

  if (
    processExitAccesses.length !== 1 ||
    processExitCalls.length !== 1 ||
    processExitCall.source !== serverSource
  ) {
    fail(
      `process.exit() must occur only once in apps/api/src/server.ts; found ${describeLocations(processExitAccesses)}.`,
    );
  }

  const productionStarts = callExpressions.filter(
    ({ directCalleeName }) => directCalleeName === "startProductionServer",
  );
  const [productionStart] = productionStarts;
  const [productionEntryGuard] = productionEntryGuards;
  const [startProductionServerDefinition] = startProductionServerDefinitions;

  if (
    startProductionServerDefinitions.length !== 1 ||
    startProductionServerDefinition.source !== serverSource ||
    productionEntryGuards.length !== 1 ||
    productionEntryGuard.source !== serverSource ||
    productionEntryGuard.node.parent !== serverSource.sourceFile ||
    productionStarts.length !== 1 ||
    productionStart.source !== serverSource ||
    !isNodeInside(productionStart.node, productionEntryGuard.node.thenStatement)
  ) {
    fail(
      "server.ts must keep the sole production startup call inside a top-level import.meta.main guard.",
    );
  }

  const startServerCalls = callExpressions.filter(
    ({ directCalleeName }) => directCalleeName === "startServer",
  );
  const [startServerCall] = startServerCalls;

  if (
    startServerCalls.length !== 1 ||
    startServerCall.source !== serverSource ||
    !isNodeInside(startServerCall.node, startProductionServerDefinition.node)
  ) {
    fail(
      "startServer() must be called only by startProductionServer() in server.ts.",
    );
  }

  const startupCatchAccess = productionStart.node.parent;
  const startupCatch = startupCatchAccess.parent;
  const startupVoid = startupCatch.parent;

  if (
    !typescript.isPropertyAccessExpression(startupCatchAccess) ||
    startupCatchAccess.name.text !== "catch" ||
    startupCatchAccess.expression !== productionStart.node ||
    !typescript.isCallExpression(startupCatch) ||
    startupCatch.expression !== startupCatchAccess ||
    startupVoid.kind !== typescript.SyntaxKind.VoidExpression ||
    startupVoid.expression !== startupCatch
  ) {
    fail(
      "the guarded production startup call must discard only a caught rejection.",
    );
  }

  if (appBoundaryLeaks.length > 0) {
    fail(
      "app/request/reply must not receive the composition or dependency boundary through assignment, mutation, or Fastify decoration.",
    );
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
assertAppListenerBoundary();
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
  `Boundary verification passed: ${negativeFixtureCount} negative fixtures, ${expectedPositiveFixtures.length} positive fixtures, the complete API source graph, and the app/listener ownership contract.`,
);
