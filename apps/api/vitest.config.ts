import process from "node:process";
import { fileURLToPath } from "node:url";

import { defineConfig, defineProject } from "vitest/config";

const apiRoot = fileURLToPath(new URL(".", import.meta.url));
const reportsEnabled = process.env.CODITZA_TEST_REPORTS === "1";

function nodeLayerProject(name: string, include: readonly string[]) {
  return defineProject({
    test: {
      name,
      environment: "node",
      isolate: true,
      fileParallelism: true,
      restoreMocks: true,
      unstubGlobals: true,
      unstubEnvs: true,
      include: [...include],
    },
  });
}

export default defineConfig({
  root: apiRoot,
  envDir: false,
  test: {
    allowOnly: false,
    passWithNoTests: false,
    reporters: reportsEnabled
      ? [
          "default",
          [
            "junit",
            {
              outputFile: "coverage/junit.xml",
              suiteName: "coditza-unit",
              classnameTemplate: "{filename}",
              hostname: "local",
              addFileAttribute: false,
              includeConsoleOutput: false,
            },
          ],
        ]
      : ["default"],
    coverage: {
      provider: "v8",
      reportsDirectory: "coverage",
      reporter: ["text-summary", "json", "lcovonly"],
      include: ["src/**/*.ts"],
      exclude: ["test/**", "dist/**", "vitest.config.ts"],
    },
    projects: [
      nodeLayerProject("unit", [
        "test/app/**/*.test.ts",
        "test/config/**/*.test.ts",
        "test/modules/**/*.test.ts",
        "test/server/**/*.test.ts",
        "test/support/**/*.test.ts",
      ]),
      nodeLayerProject("integration", ["test/integration/**/*.test.ts"]),
      nodeLayerProject("contract", ["test/contract/**/*.test.ts"]),
      nodeLayerProject("db", ["test/db/**/*.test.ts"]),
      nodeLayerProject("e2e", ["test/e2e/**/*.test.ts"]),
      nodeLayerProject("security", ["test/security/**/*.test.ts"]),
      nodeLayerProject("wasm", ["test/wasm/**/*.test.ts"]),
    ],
  },
});
