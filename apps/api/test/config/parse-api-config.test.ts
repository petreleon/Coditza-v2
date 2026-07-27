import { inspect } from "node:util";

import { Value } from "typebox/value";
import { describe, expect, it, vi } from "vitest";

import {
  ConfigSchema,
  ConfigValidationError,
  parseApiConfig,
  type RawEnvironment,
} from "../../src/infrastructure/config/index.js";

const HMAC_32_BYTES = "A".repeat(43);
const HOSTED_PROJECT_REF = "abcdefghijklmnopqrst";

const validLocalEnvironment: RawEnvironment = Object.freeze({
  NODE_ENV: "test",
  APP_ENV: "local",
  HOST: "127.0.0.1",
  API_PREFIX: "/api/v1",
  CORS_ORIGINS: "HTTPS://APP.Local.Test:8443, http://localhost:5173",
  SUPABASE_URL: "http://127.0.0.1:54321",
  SUPABASE_PROJECT_REF: "local",
  SUPABASE_PUBLISHABLE_KEY: "sb_publishable_test_only",
  SUPABASE_SECRET_KEY: "sb_secret_test_only",
  SUPABASE_JWT_ISSUER: "http://localhost:54321/auth/v1",
  SUPABASE_JWT_AUDIENCE: "authenticated",
  CURSOR_HMAC_SECRET: HMAC_32_BYTES,
});

function environment(
  overrides: Readonly<Record<string, string | undefined>> = {},
): RawEnvironment {
  return Object.freeze({ ...validLocalEnvironment, ...overrides });
}

function hostedEnvironment(
  appEnv: "development" | "staging" | "production" = "production",
  overrides: Readonly<Record<string, string | undefined>> = {},
): RawEnvironment {
  return environment({
    NODE_ENV: "production",
    APP_ENV: appEnv,
    PORT: "3000",
    CORS_ORIGINS: "https://app.coditza.example",
    SWAGGER_UI_ENABLED: "false",
    SUPABASE_URL: `https://${HOSTED_PROJECT_REF}.supabase.co`,
    SUPABASE_PROJECT_REF: HOSTED_PROJECT_REF,
    SUPABASE_JWT_ISSUER: `https://${HOSTED_PROJECT_REF}.supabase.co/auth/v1`,
    ...overrides,
  });
}

function configurationError(raw: RawEnvironment): ConfigValidationError {
  try {
    parseApiConfig(raw);
  } catch (error) {
    expect(error).toBeInstanceOf(ConfigValidationError);
    return error as ConfigValidationError;
  }

  throw new Error("Expected configuration parsing to fail");
}

function expectField(
  raw: RawEnvironment,
  variable: string,
): ConfigValidationError {
  const error = configurationError(raw);
  expect(error.fields).toContain(variable);
  return error;
}

describe("parseApiConfig", () => {
  it("parses injected local values, applies every API default, and makes no network call", () => {
    const fetchSpy = vi.fn();
    vi.stubGlobal("fetch", fetchSpy);

    try {
      const config = parseApiConfig(validLocalEnvironment);

      expect(fetchSpy).not.toHaveBeenCalled();
      expect(config).toMatchObject({
        environment: { nodeEnv: "test", appEnv: "local" },
        server: {
          host: "127.0.0.1",
          port: 3000,
          apiPrefix: "/api/v1",
          logLevel: "info",
          trustProxy: false,
          requestIdHeader: "x-request-id",
          swaggerUiEnabled: true,
        },
        cors: {
          origins: ["https://app.local.test:8443", "http://localhost:5173"],
        },
        limits: {
          bodyLimitBytes: 1_048_576,
          rateLimit: {
            max: 100,
            windowMs: 60_000,
            attemptMax: 20,
            adminMax: 30,
          },
          timeouts: {
            connectionMs: 10_000,
            requestReceiveMs: 30_000,
            dependencyMs: 10_000,
            handlerMs: 15_000,
            keepAliveMs: 65_000,
            headersMs: 66_000,
            readinessMs: 2_000,
            shutdownMs: 10_000,
          },
        },
        supabase: {
          url: "http://127.0.0.1:54321",
          jwtIssuer: "http://localhost:54321/auth/v1",
          jwtAudience: "authenticated",
        },
        pythonGrader: { enabled: false, concurrency: 2, queueLimit: 1_000 },
      });
      expect(config.supabase.url).not.toBe(config.supabase.jwtIssuer);
      expect(Value.Check(ConfigSchema, config)).toBe(true);
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it("does not mutate an injected record and ignores controller-only raw variables", () => {
    const raw = environment({
      PYTHON_WASM_RUNTIME_MANIFEST: "/controller-only/runtime.lock.json",
      PYTHON_SANDBOX_LAUNCHER_PROFILE: "controller-only-profile",
      PYTHON_GRADER_CLAIM_BATCH_SIZE: "not-an-api-value",
      PYTHON_GRADER_POLL_INTERVAL_MS: "not-an-api-value",
      PYTHON_GRADER_LEASE_MS: "not-an-api-value",
      PYTHON_GRADER_MAX_RETRIES: "not-an-api-value",
      ALLOW_HOSTED_TEST_TARGET: "controller-only-target",
      PYTHON_SANDBOX_BINDING: "controller-only-binding",
    });
    const before = { ...raw };

    const config = parseApiConfig(raw);

    expect(raw).toEqual(before);
    expect(config.pythonGrader).toEqual({
      enabled: false,
      concurrency: 2,
      queueLimit: 1_000,
    });
    expect(config).not.toHaveProperty("pythonWasmRuntimeManifest");
    expect(config).not.toHaveProperty("allowHostedTestTarget");
  });

  it("returns a deeply immutable plain-data object", () => {
    const config = parseApiConfig(validLocalEnvironment);

    expect(Object.isFrozen(config)).toBe(true);
    expect(Object.isFrozen(config.environment)).toBe(true);
    expect(Object.isFrozen(config.server)).toBe(true);
    expect(Object.isFrozen(config.cors)).toBe(true);
    expect(Object.isFrozen(config.cors.origins)).toBe(true);
    expect(Object.isFrozen(config.limits.timeouts)).toBe(true);
    expect(Object.isFrozen(config.supabase)).toBe(true);

    expect(() => {
      (config.cors.origins as string[]).push("https://mutated.example");
    }).toThrow(TypeError);
    expect(() => {
      (config.server as { port: number }).port = 1;
    }).toThrow(TypeError);
  });

  it.each([
    "NODE_ENV",
    "APP_ENV",
    "HOST",
    "API_PREFIX",
    "CORS_ORIGINS",
    "SUPABASE_URL",
    "SUPABASE_PROJECT_REF",
    "SUPABASE_PUBLISHABLE_KEY",
    "SUPABASE_SECRET_KEY",
    "SUPABASE_JWT_ISSUER",
    "SUPABASE_JWT_AUDIENCE",
    "CURSOR_HMAC_SECRET",
  ])("rejects a missing required variable: %s", (variable) => {
    expectField(environment({ [variable]: undefined }), variable);
  });

  it("rejects an invalid host independently of other validation failures", () => {
    expectField(environment({ HOST: " " }), "HOST");
  });

  it.each([
    ["test", "local"],
    ["development", "local"],
    ["production", "development"],
    ["production", "staging"],
    ["production", "production"],
  ] as const)("accepts approved mode pair %s/%s", (nodeEnv, appEnv) => {
    const raw =
      appEnv === "local"
        ? environment({ NODE_ENV: nodeEnv, APP_ENV: appEnv })
        : hostedEnvironment(appEnv);

    expect(parseApiConfig(raw).environment).toEqual({ nodeEnv, appEnv });
  });

  it.each([
    ["test", "development"],
    ["test", "staging"],
    ["test", "production"],
    ["development", "development"],
    ["development", "staging"],
    ["development", "production"],
    ["production", "local"],
  ] as const)("rejects mode pair %s/%s", (nodeEnv, appEnv) => {
    const raw =
      appEnv === "local"
        ? environment({ NODE_ENV: nodeEnv, APP_ENV: appEnv })
        : hostedEnvironment(appEnv, { NODE_ENV: nodeEnv });
    const error = configurationError(raw);

    expect(error.fields).toEqual(
      expect.arrayContaining(["NODE_ENV", "APP_ENV"]),
    );
  });

  it.each([
    ["NODE_ENV", "preview"],
    ["APP_ENV", "preview"],
  ] as const)(
    "rejects an unsupported environment enum: %s",
    (variable, value) => {
      expectField(environment({ [variable]: value }), variable);
    },
  );

  it("requires an explicit port in hosted modes while preserving the local default", () => {
    expect(parseApiConfig(validLocalEnvironment).server.port).toBe(3000);
    expectField(hostedEnvironment("production", { PORT: undefined }), "PORT");
  });

  it("defaults Swagger UI to false in hosted modes", () => {
    expect(
      parseApiConfig(
        hostedEnvironment("production", { SWAGGER_UI_ENABLED: undefined }),
      ).server.swaggerUiEnabled,
    ).toBe(false);
  });

  it("keeps local Supabase endpoint and issuer inputs separate", () => {
    const config = parseApiConfig(
      environment({
        SUPABASE_URL: "http://api.internal.local:54321",
        SUPABASE_JWT_ISSUER: "http://issuer.internal.local:9000/auth/v1",
      }),
    );

    expect(config.supabase.url).toBe("http://api.internal.local:54321");
    expect(config.supabase.jwtIssuer).toBe(
      "http://issuer.internal.local:9000/auth/v1",
    );
  });

  it.each([
    ["SUPABASE_URL", `http://${HOSTED_PROJECT_REF}.supabase.co`],
    ["SUPABASE_JWT_ISSUER", `http://${HOSTED_PROJECT_REF}.supabase.co/auth/v1`],
    ["SUPABASE_PROJECT_REF", "local"],
    ["SUPABASE_URL", "https://wrongprojectref00.supabase.co"],
    ["SUPABASE_JWT_ISSUER", "https://wrongprojectref00.supabase.co/auth/v1"],
  ] as const)(
    "rejects an unsafe or mismatched hosted Supabase value: %s",
    (variable, value) => {
      expectField(
        hostedEnvironment("production", { [variable]: value }),
        variable,
      );
    },
  );

  it.each(["/api", "/api/v2", "/api/v1/", "api/v1"])(
    "rejects an API prefix other than the MVP contract: %s",
    (apiPrefix) => {
      expectField(environment({ API_PREFIX: apiPrefix }), "API_PREFIX");
    },
  );

  it.each(["trace", "debug", "info", "warn", "error", "fatal", "silent"])(
    "accepts the Pino log level: %s",
    (logLevel) => {
      expect(
        parseApiConfig(environment({ LOG_LEVEL: logLevel })).server.logLevel,
      ).toBe(logLevel);
    },
  );

  it.each(["INFO", "verbose", "", " info"])(
    "rejects invalid Pino level: %s",
    (logLevel) => {
      expectField(environment({ LOG_LEVEL: logLevel }), "LOG_LEVEL");
    },
  );

  it.each(["x-request-id", "x_coritza-id", "trace.1"])(
    "accepts a lower-case request-ID header: %s",
    (requestIdHeader) => {
      expect(
        parseApiConfig(environment({ REQUEST_ID_HEADER: requestIdHeader }))
          .server.requestIdHeader,
      ).toBe(requestIdHeader);
    },
  );

  it.each(["X-Request-Id", "x request id", "x:request-id", ""])(
    "rejects an invalid request-ID header: %s",
    (requestIdHeader) => {
      expectField(
        environment({ REQUEST_ID_HEADER: requestIdHeader }),
        "REQUEST_ID_HEADER",
      );
    },
  );

  it.each([
    ["SUPABASE_URL", "relative/path"],
    ["SUPABASE_URL", "ftp://supabase.example"],
    ["SUPABASE_URL", "https://user:pass@supabase.example"],
    ["SUPABASE_URL", "https://supabase.example/path"],
    ["SUPABASE_URL", "https://supabase.example?query=value"],
    ["SUPABASE_URL", "https://supabase.example#fragment"],
    ["SUPABASE_JWT_ISSUER", "relative/path"],
    ["SUPABASE_JWT_ISSUER", "https://user:pass@supabase.example/auth/v1"],
    ["SUPABASE_JWT_ISSUER", "https://supabase.example/not-auth"],
    ["SUPABASE_JWT_ISSUER", "https://supabase.example/auth/v1?query=value"],
  ] as const)("rejects an invalid Supabase URL form: %s", (variable, value) => {
    expectField(environment({ [variable]: value }), variable);
  });

  it.each([
    ["SUPABASE_PUBLISHABLE_KEY", "sb_secret_wrong_kind"],
    ["SUPABASE_SECRET_KEY", "sb_publishable_wrong_kind"],
    ["SUPABASE_PUBLISHABLE_KEY", "anon-legacy-key"],
    ["SUPABASE_SECRET_KEY", "service-role-legacy-key"],
    ["SUPABASE_JWT_AUDIENCE", "anon"],
    ["CURSOR_HMAC_SECRET", "A".repeat(42)],
    ["CURSOR_HMAC_SECRET", `${"A".repeat(42)}B`],
  ] as const)(
    "rejects an invalid Supabase credential or JWT setting: %s",
    (variable, value) => {
      expectField(environment({ [variable]: value }), variable);
    },
  );

  const boundedNumberFields = [
    { variable: "PORT", minimum: 1, maximum: 65_535 },
    { variable: "CONNECTION_TIMEOUT_MS", minimum: 1_000, maximum: 60_000 },
    {
      variable: "REQUEST_RECEIVE_TIMEOUT_MS",
      minimum: 1_000,
      maximum: 120_000,
    },
    { variable: "DEPENDENCY_TIMEOUT_MS", minimum: 100, maximum: 120_000 },
    { variable: "HANDLER_TIMEOUT_MS", minimum: 1_000, maximum: 120_000 },
    {
      variable: "KEEP_ALIVE_TIMEOUT_MS",
      minimum: 1_000,
      maximum: 119_999,
      dependencies: { HEADERS_TIMEOUT_MS: "120000" },
    },
    {
      variable: "HEADERS_TIMEOUT_MS",
      minimum: 1_001,
      maximum: 120_000,
      dependencies: { KEEP_ALIVE_TIMEOUT_MS: "1000" },
    },
    { variable: "READINESS_TIMEOUT_MS", minimum: 100, maximum: 10_000 },
    { variable: "SHUTDOWN_TIMEOUT_MS", minimum: 1_000, maximum: 60_000 },
    { variable: "PYTHON_GRADER_CONCURRENCY", minimum: 1, maximum: 8 },
    { variable: "PYTHON_GRADER_QUEUE_LIMIT", minimum: 1, maximum: 10_000 },
  ] as const;

  it.each(boundedNumberFields)(
    "accepts both bounds for $variable",
    ({ variable, minimum, maximum, dependencies = {} }) => {
      expect(() =>
        parseApiConfig(
          environment({ ...dependencies, [variable]: String(minimum) }),
        ),
      ).not.toThrow();
      expect(() =>
        parseApiConfig(
          environment({ ...dependencies, [variable]: String(maximum) }),
        ),
      ).not.toThrow();
    },
  );

  it.each(boundedNumberFields)(
    "rejects values outside the bounds for $variable",
    ({ variable, minimum, maximum, dependencies = {} }) => {
      expectField(
        environment({ ...dependencies, [variable]: String(minimum - 1) }),
        variable,
      );
      expectField(
        environment({ ...dependencies, [variable]: String(maximum + 1) }),
        variable,
      );
    },
  );

  it.each([
    "BODY_LIMIT_BYTES",
    "RATE_LIMIT_MAX",
    "RATE_LIMIT_WINDOW_MS",
    "ATTEMPT_RATE_LIMIT_MAX",
    "ADMIN_RATE_LIMIT_MAX",
  ])("requires a positive integer for %s", (variable) => {
    expect(() =>
      parseApiConfig(environment({ [variable]: "1" })),
    ).not.toThrow();
    expectField(environment({ [variable]: "0" }), variable);
    expectField(environment({ [variable]: "-1" }), variable);
  });

  it.each([
    "",
    " 1",
    "1 ",
    "1.1",
    "1e3",
    "NaN",
    "Infinity",
    "9007199254740992",
  ])("rejects a non-strict integer lexical form: %s", (value) => {
    expectField(environment({ PORT: value }), "PORT");
  });

  it("enforces the strict relation between headers and keep-alive timeouts", () => {
    expectField(
      environment({
        KEEP_ALIVE_TIMEOUT_MS: "1000",
        HEADERS_TIMEOUT_MS: "1000",
      }),
      "HEADERS_TIMEOUT_MS",
    );
    expectField(
      environment({
        KEEP_ALIVE_TIMEOUT_MS: "2000",
        HEADERS_TIMEOUT_MS: "1999",
      }),
      "HEADERS_TIMEOUT_MS",
    );
  });

  it.each(["TRUST_PROXY", "SWAGGER_UI_ENABLED", "PYTHON_GRADER_ENABLED"])(
    "parses false as a real boolean for %s",
    (variable) => {
      const config = parseApiConfig(environment({ [variable]: "false" }));

      if (variable === "TRUST_PROXY") {
        expect(config.server.trustProxy).toBe(false);
      } else if (variable === "SWAGGER_UI_ENABLED") {
        expect(config.server.swaggerUiEnabled).toBe(false);
      } else {
        expect(config.pythonGrader.enabled).toBe(false);
      }
    },
  );

  it.each(["False", "FALSE", "0", "1", "yes", "", " false"])(
    "rejects non-strict boolean text: %s",
    (value) => {
      for (const variable of [
        "TRUST_PROXY",
        "SWAGGER_UI_ENABLED",
        "PYTHON_GRADER_ENABLED",
      ]) {
        expectField(environment({ [variable]: value }), variable);
      }
    },
  );

  it("fails closed for unreviewed proxy trust, hosted Swagger, and enabled WASM grading", () => {
    expectField(environment({ TRUST_PROXY: "true" }), "TRUST_PROXY");
    expectField(
      hostedEnvironment("production", { SWAGGER_UI_ENABLED: "true" }),
      "SWAGGER_UI_ENABLED",
    );
    expectField(
      environment({ PYTHON_GRADER_ENABLED: "true" }),
      "PYTHON_GRADER_ENABLED",
    );
  });

  it("accepts local API-only CORS while requiring a hosted allowlist", () => {
    expect(
      parseApiConfig(environment({ CORS_ORIGINS: "" })).cors.origins,
    ).toEqual([]);
    expectField(
      hostedEnvironment("production", { CORS_ORIGINS: "" }),
      "CORS_ORIGINS",
    );
  });

  it.each(["development", "staging", "production"] as const)(
    "requires HTTPS CORS origins in hosted %s mode",
    (appEnv) => {
      expectField(
        hostedEnvironment(appEnv, {
          CORS_ORIGINS: "http://app.coditza.example",
        }),
        "CORS_ORIGINS",
      );
    },
  );

  it("preserves an explicitly supplied default CORS port while detecting its semantic duplicate", () => {
    expect(
      parseApiConfig(
        environment({ CORS_ORIGINS: "HTTPS://APP.Local.Test:443" }),
      ).cors.origins,
    ).toEqual(["https://app.local.test:443"]);
    expectField(
      environment({
        CORS_ORIGINS: "HTTPS://duplicate.example:443,https://duplicate.example",
      }),
      "CORS_ORIGINS",
    );
  });

  it.each([
    "*",
    "https://*.coditza.example",
    "https://user:pass@coditza.example",
    "https://coditza.example/path",
    "https://coditza.example?query=value",
    "https://coditza.example#fragment",
    "ftp://coditza.example",
    "not an absolute URL",
    "https://first.example,,https://second.example",
  ])("rejects unsafe or duplicate CORS input: %s", (corsOrigins) => {
    expectField(environment({ CORS_ORIGINS: corsOrigins }), "CORS_ORIGINS");
  });

  it.each([
    "http://localhost:5173",
    "https://localhost.:5173",
    "https://app.localhost.:8443",
    "https://127.0.0.1:8443",
    "http://[::1]:5173",
    "https://[::ffff:127.0.0.1]:5173",
    "https://[::ffff:7f00:1]:5173",
  ])("rejects a production loopback CORS origin: %s", (corsOrigins) => {
    expectField(
      hostedEnvironment("production", { CORS_ORIGINS: corsOrigins }),
      "CORS_ORIGINS",
    );
  });

  it("does not disclose sensitive supplied values in errors, stacks, JSON, or console output", () => {
    const publishableCanary = "NON_SECRET_PUBLISHABLE_CANARY";
    const secretCanary = "NON_SECRET_SECRET_CANARY";
    const cursorCanary = "NON_SECRET_CURSOR_CANARY";
    const consoleError = vi.spyOn(console, "error");
    const consoleWarn = vi.spyOn(console, "warn");
    const consoleInfo = vi.spyOn(console, "info");
    const consoleLog = vi.spyOn(console, "log");
    const consoleDebug = vi.spyOn(console, "debug");

    try {
      const error = configurationError(
        environment({
          HOST: " ",
          SUPABASE_PUBLISHABLE_KEY: `invalid-${publishableCanary}`,
          SUPABASE_SECRET_KEY: `invalid-${secretCanary}`,
          CURSOR_HMAC_SECRET: cursorCanary,
        }),
      );
      const rendered = [
        String(error),
        error.message,
        error.stack ?? "",
        JSON.stringify(error),
        inspect(error),
      ].join("\n");

      for (const canary of [publishableCanary, secretCanary, cursorCanary]) {
        expect(rendered).not.toContain(canary);
      }

      expect(consoleError).not.toHaveBeenCalled();
      expect(consoleWarn).not.toHaveBeenCalled();
      expect(consoleInfo).not.toHaveBeenCalled();
      expect(consoleLog).not.toHaveBeenCalled();
      expect(consoleDebug).not.toHaveBeenCalled();
    } finally {
      consoleError.mockRestore();
      consoleWarn.mockRestore();
      consoleInfo.mockRestore();
      consoleLog.mockRestore();
      consoleDebug.mockRestore();
    }
  });

  it("does not disclose valid sensitive values when another field is invalid", () => {
    const publishableCanary = "sb_publishable_VALID_PUBLISHABLE_CANARY";
    const secretCanary = "sb_secret_VALID_SECRET_CANARY";
    const cursorCanary = HMAC_32_BYTES;
    const error = configurationError(
      environment({
        HOST: " ",
        SUPABASE_PUBLISHABLE_KEY: publishableCanary,
        SUPABASE_SECRET_KEY: secretCanary,
        CURSOR_HMAC_SECRET: cursorCanary,
      }),
    );
    const rendered = [
      String(error),
      error.message,
      error.stack ?? "",
      JSON.stringify(error),
      inspect(error),
    ].join("\n");

    for (const canary of [publishableCanary, secretCanary, cursorCanary]) {
      expect(rendered).not.toContain(canary);
    }
  });
});
