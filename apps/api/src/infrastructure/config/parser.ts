import { Value } from "typebox/value";

import { ConfigSchema, type ParsedApiConfig } from "./schema.js";
import {
  ConfigValidationError,
  type ApiConfig,
  type ConfigIssue,
  type DeepReadonly,
  type RawEnvironment,
} from "./types.js";

const DEFAULTS = {
  logLevel: "info",
  port: 3_000,
  bodyLimitBytes: 1_048_576,
  rateLimitMax: 100,
  rateLimitWindowMs: 60_000,
  attemptRateLimitMax: 20,
  adminRateLimitMax: 30,
  connectionTimeoutMs: 10_000,
  requestReceiveTimeoutMs: 30_000,
  dependencyTimeoutMs: 10_000,
  handlerTimeoutMs: 15_000,
  keepAliveTimeoutMs: 65_000,
  headersTimeoutMs: 66_000,
  readinessTimeoutMs: 2_000,
  shutdownTimeoutMs: 10_000,
  requestIdHeader: "x-request-id",
  pythonGraderConcurrency: 2,
  pythonGraderQueueLimit: 1_000,
} as const;

const SCHEMA_PATH_TO_VARIABLE: Readonly<Record<string, string>> = {
  "/environment/nodeEnv": "NODE_ENV",
  "/environment/appEnv": "APP_ENV",
  "/server/host": "HOST",
  "/server/port": "PORT",
  "/server/apiPrefix": "API_PREFIX",
  "/server/logLevel": "LOG_LEVEL",
  "/server/trustProxy": "TRUST_PROXY",
  "/server/requestIdHeader": "REQUEST_ID_HEADER",
  "/server/swaggerUiEnabled": "SWAGGER_UI_ENABLED",
  "/cors/origins": "CORS_ORIGINS",
  "/limits/bodyLimitBytes": "BODY_LIMIT_BYTES",
  "/limits/rateLimit/max": "RATE_LIMIT_MAX",
  "/limits/rateLimit/windowMs": "RATE_LIMIT_WINDOW_MS",
  "/limits/rateLimit/attemptMax": "ATTEMPT_RATE_LIMIT_MAX",
  "/limits/rateLimit/adminMax": "ADMIN_RATE_LIMIT_MAX",
  "/limits/timeouts/connectionMs": "CONNECTION_TIMEOUT_MS",
  "/limits/timeouts/requestReceiveMs": "REQUEST_RECEIVE_TIMEOUT_MS",
  "/limits/timeouts/dependencyMs": "DEPENDENCY_TIMEOUT_MS",
  "/limits/timeouts/handlerMs": "HANDLER_TIMEOUT_MS",
  "/limits/timeouts/keepAliveMs": "KEEP_ALIVE_TIMEOUT_MS",
  "/limits/timeouts/headersMs": "HEADERS_TIMEOUT_MS",
  "/limits/timeouts/readinessMs": "READINESS_TIMEOUT_MS",
  "/limits/timeouts/shutdownMs": "SHUTDOWN_TIMEOUT_MS",
  "/supabase/url": "SUPABASE_URL",
  "/supabase/projectRef": "SUPABASE_PROJECT_REF",
  "/supabase/publishableKey": "SUPABASE_PUBLISHABLE_KEY",
  "/supabase/secretKey": "SUPABASE_SECRET_KEY",
  "/supabase/jwtIssuer": "SUPABASE_JWT_ISSUER",
  "/supabase/jwtAudience": "SUPABASE_JWT_AUDIENCE",
  "/cursor/hmacSecret": "CURSOR_HMAC_SECRET",
  "/pythonGrader/enabled": "PYTHON_GRADER_ENABLED",
  "/pythonGrader/concurrency": "PYTHON_GRADER_CONCURRENCY",
  "/pythonGrader/queueLimit": "PYTHON_GRADER_QUEUE_LIMIT",
};

const REQUEST_ID_HEADER = /^[a-z0-9!#$%&'*+.^_`|~-]+$/;
const STANDARD_HOSTED_PROJECT_REF = /^[a-z0-9]{20}$/;
const BASE64URL_32_BYTES = /^[A-Za-z0-9_-]{43}$/;

function addIssue(
  issues: ConfigIssue[],
  variable: string,
  reason: string,
): void {
  issues.push({ variable, reason });
}

function readRequiredText(
  raw: RawEnvironment,
  variable: string,
  issues: ConfigIssue[],
): string | undefined {
  const value = raw[variable];

  if (value === undefined) {
    addIssue(issues, variable, "is required");
    return undefined;
  }

  if (value.length === 0 || value !== value.trim()) {
    addIssue(issues, variable, "must be a non-empty trimmed value");
    return undefined;
  }

  return value;
}

function readOptionalText(
  raw: RawEnvironment,
  variable: string,
  defaultValue: string,
  issues: ConfigIssue[],
): string | undefined {
  if (raw[variable] === undefined) {
    return defaultValue;
  }

  return readRequiredText(raw, variable, issues);
}

function parseInteger(
  rawValue: string | undefined,
  variable: string,
  issues: ConfigIssue[],
): number | undefined {
  if (rawValue === undefined) {
    addIssue(issues, variable, "is required");
    return undefined;
  }

  if (!/^-?\d+$/.test(rawValue)) {
    addIssue(issues, variable, "must be an integer");
    return undefined;
  }

  const value = Number(rawValue);

  if (!Number.isSafeInteger(value)) {
    addIssue(issues, variable, "must be a safe integer");
    return undefined;
  }

  return value;
}

function parseOptionalInteger(
  raw: RawEnvironment,
  variable: string,
  defaultValue: number,
  issues: ConfigIssue[],
): number | undefined {
  return parseInteger(raw[variable] ?? String(defaultValue), variable, issues);
}

function parseStrictBoolean(
  rawValue: string | undefined,
  variable: string,
  issues: ConfigIssue[],
): boolean | undefined {
  if (rawValue === "true") {
    return true;
  }

  if (rawValue === "false") {
    return false;
  }

  if (rawValue === undefined) {
    addIssue(issues, variable, "is required");
  } else {
    addIssue(issues, variable, "must be exactly true or false");
  }

  return undefined;
}

function parseOptionalBoolean(
  raw: RawEnvironment,
  variable: string,
  defaultValue: boolean,
  issues: ConfigIssue[],
): boolean | undefined {
  return parseStrictBoolean(
    raw[variable] ?? String(defaultValue),
    variable,
    issues,
  );
}

function normalizeOrigin(url: URL): string {
  return `${url.protocol.toLowerCase()}//${url.host.toLowerCase()}`;
}

function parseSupabaseEndpoint(
  raw: RawEnvironment,
  variable: string,
  issues: ConfigIssue[],
): string | undefined {
  const value = readRequiredText(raw, variable, issues);

  if (value === undefined) {
    return undefined;
  }

  try {
    const url = new URL(value);

    if (
      (url.protocol !== "http:" && url.protocol !== "https:") ||
      url.username.length > 0 ||
      url.password.length > 0 ||
      url.pathname !== "/" ||
      url.search.length > 0 ||
      url.hash.length > 0
    ) {
      addIssue(issues, variable, "must be an absolute HTTP(S) endpoint origin");
      return undefined;
    }

    return normalizeOrigin(url);
  } catch {
    addIssue(issues, variable, "must be an absolute HTTP(S) endpoint origin");
    return undefined;
  }
}

function parseSupabaseIssuer(
  raw: RawEnvironment,
  variable: string,
  issues: ConfigIssue[],
): string | undefined {
  const value = readRequiredText(raw, variable, issues);

  if (value === undefined) {
    return undefined;
  }

  try {
    const url = new URL(value);

    if (
      (url.protocol !== "http:" && url.protocol !== "https:") ||
      url.username.length > 0 ||
      url.password.length > 0 ||
      url.pathname !== "/auth/v1" ||
      url.search.length > 0 ||
      url.hash.length > 0
    ) {
      addIssue(
        issues,
        variable,
        "must be the canonical HTTP(S) /auth/v1 issuer",
      );
      return undefined;
    }

    return `${normalizeOrigin(url)}/auth/v1`;
  } catch {
    addIssue(issues, variable, "must be the canonical HTTP(S) /auth/v1 issuer");
    return undefined;
  }
}

function parseSupabaseKey(
  raw: RawEnvironment,
  variable: "SUPABASE_PUBLISHABLE_KEY" | "SUPABASE_SECRET_KEY",
  prefix: "sb_publishable_" | "sb_secret_",
  issues: ConfigIssue[],
): string | undefined {
  const value = readRequiredText(raw, variable, issues);

  if (value === undefined) {
    return undefined;
  }

  if (!new RegExp(`^${prefix}[A-Za-z0-9_-]+$`).test(value)) {
    addIssue(issues, variable, "must use the current Supabase key format");
    return undefined;
  }

  return value;
}

function parseCursorHmacSecret(
  raw: RawEnvironment,
  issues: ConfigIssue[],
): string | undefined {
  const value = readRequiredText(raw, "CURSOR_HMAC_SECRET", issues);

  if (value === undefined) {
    return undefined;
  }

  if (!BASE64URL_32_BYTES.test(value)) {
    addIssue(
      issues,
      "CURSOR_HMAC_SECRET",
      "must be unpadded base64url for 32 bytes",
    );
    return undefined;
  }

  const decoded = Buffer.from(value, "base64url");

  if (decoded.byteLength !== 32 || decoded.toString("base64url") !== value) {
    addIssue(
      issues,
      "CURSOR_HMAC_SECRET",
      "must be unpadded base64url for 32 bytes",
    );
    return undefined;
  }

  return value;
}

function parseRequestIdHeader(
  raw: RawEnvironment,
  issues: ConfigIssue[],
): string | undefined {
  const value = readOptionalText(
    raw,
    "REQUEST_ID_HEADER",
    DEFAULTS.requestIdHeader,
    issues,
  );

  if (value !== undefined && !REQUEST_ID_HEADER.test(value)) {
    addIssue(
      issues,
      "REQUEST_ID_HEADER",
      "must be a lower-case HTTP field name",
    );
    return undefined;
  }

  return value;
}

function parseCorsOrigins(
  raw: RawEnvironment,
  issues: ConfigIssue[],
): string[] | undefined {
  const rawOrigins = raw.CORS_ORIGINS;

  if (rawOrigins === undefined) {
    addIssue(issues, "CORS_ORIGINS", "is required");
    return undefined;
  }

  if (rawOrigins === "") {
    return [];
  }

  const origins: string[] = [];
  const seenOrigins = new Set<string>();

  for (const entry of rawOrigins.split(",")) {
    const value = entry.trim();

    if (value.length === 0 || value === "*") {
      addIssue(issues, "CORS_ORIGINS", "must contain exact HTTP(S) origins");
      continue;
    }

    try {
      const url = new URL(value);

      if (
        (url.protocol !== "http:" && url.protocol !== "https:") ||
        url.hostname.includes("*") ||
        url.username.length > 0 ||
        url.password.length > 0 ||
        url.pathname !== "/" ||
        url.search.length > 0 ||
        url.hash.length > 0
      ) {
        addIssue(issues, "CORS_ORIGINS", "must contain exact HTTP(S) origins");
        continue;
      }

      const normalized = normalizeOrigin(url);

      if (seenOrigins.has(normalized)) {
        addIssue(
          issues,
          "CORS_ORIGINS",
          "contains duplicate normalized origins",
        );
        continue;
      }

      seenOrigins.add(normalized);
      origins.push(normalized);
    } catch {
      addIssue(issues, "CORS_ORIGINS", "must contain exact HTTP(S) origins");
    }
  }

  return origins;
}

function isLocalhostOrLoopback(hostname: string): boolean {
  const host = hostname.toLowerCase();

  return (
    host === "localhost" ||
    host.endsWith(".localhost") ||
    /^127(?:\.\d{1,3}){3}$/.test(host) ||
    host === "[::1]" ||
    host === "::1"
  );
}

function validateRelationships(
  config: ParsedApiConfig,
  issues: ConfigIssue[],
): void {
  const { appEnv, nodeEnv } = config.environment;
  const validModePair =
    (nodeEnv === "test" && appEnv === "local") ||
    (nodeEnv === "development" && appEnv === "local") ||
    (nodeEnv === "production" &&
      (appEnv === "development" ||
        appEnv === "staging" ||
        appEnv === "production"));

  if (!validModePair) {
    addIssue(issues, "NODE_ENV", "must form an approved pair with APP_ENV");
    addIssue(issues, "APP_ENV", "must form an approved pair with NODE_ENV");
  }

  if (config.limits.timeouts.headersMs <= config.limits.timeouts.keepAliveMs) {
    addIssue(
      issues,
      "HEADERS_TIMEOUT_MS",
      "must be greater than KEEP_ALIVE_TIMEOUT_MS",
    );
  }

  if (config.cors.origins.length === 0 && appEnv !== "local") {
    addIssue(
      issues,
      "CORS_ORIGINS",
      "requires an allowlist until an API-only hosted release is recorded",
    );
  }

  for (const origin of config.cors.origins) {
    const url = new URL(origin);

    if (appEnv === "production" && isLocalhostOrLoopback(url.hostname)) {
      addIssue(
        issues,
        "CORS_ORIGINS",
        "must not contain localhost or loopback origins",
      );
    }
  }

  if (appEnv !== "local" && config.server.swaggerUiEnabled) {
    addIssue(issues, "SWAGGER_UI_ENABLED", "may be true only in local mode");
  }

  if (config.pythonGrader.enabled) {
    addIssue(
      issues,
      "PYTHON_GRADER_ENABLED",
      "requires completed G-WASM and private controller configuration",
    );
  }

  const supabaseUrl = new URL(config.supabase.url);
  const jwtIssuer = new URL(config.supabase.jwtIssuer);

  if (appEnv === "local") {
    if (config.supabase.projectRef !== "local") {
      addIssue(issues, "SUPABASE_PROJECT_REF", "must be local in local mode");
    }

    return;
  }

  if (supabaseUrl.protocol !== "https:") {
    addIssue(issues, "SUPABASE_URL", "must use HTTPS in a hosted environment");
  }

  if (jwtIssuer.protocol !== "https:") {
    addIssue(
      issues,
      "SUPABASE_JWT_ISSUER",
      "must use HTTPS in a hosted environment",
    );
  }

  if (!STANDARD_HOSTED_PROJECT_REF.test(config.supabase.projectRef)) {
    addIssue(
      issues,
      "SUPABASE_PROJECT_REF",
      "must be an exact hosted project reference",
    );
    return;
  }

  const expectedOrigin = `https://${config.supabase.projectRef}.supabase.co`;
  const expectedIssuer = `${expectedOrigin}/auth/v1`;

  if (config.supabase.url !== expectedOrigin) {
    addIssue(issues, "SUPABASE_URL", "must match the hosted project reference");
  }

  if (config.supabase.jwtIssuer !== expectedIssuer) {
    addIssue(
      issues,
      "SUPABASE_JWT_ISSUER",
      "must match the hosted project reference",
    );
  }
}

function collectSchemaIssues(
  candidate: unknown,
  issues: ConfigIssue[],
): candidate is ParsedApiConfig {
  if (Value.Check(ConfigSchema, candidate)) {
    return true;
  }

  for (const error of Value.Errors(ConfigSchema, candidate)) {
    addIssue(
      issues,
      SCHEMA_PATH_TO_VARIABLE[error.instancePath] ?? "configuration",
      "has an invalid parsed value",
    );
  }

  return false;
}

function deepFreeze<T>(value: T): DeepReadonly<T> {
  if (value !== null && typeof value === "object" && !Object.isFrozen(value)) {
    for (const key of Reflect.ownKeys(value)) {
      const nestedValue = (value as Record<PropertyKey, unknown>)[key];
      deepFreeze(nestedValue);
    }

    Object.freeze(value);
  }

  return value as DeepReadonly<T>;
}

/**
 * Parses injected environment values without modifying global process state or
 * constructing infrastructure. Errors deliberately contain no raw values.
 */
export function parseApiConfig(raw: RawEnvironment): ApiConfig {
  const issues: ConfigIssue[] = [];
  const nodeEnv = readRequiredText(raw, "NODE_ENV", issues);
  const appEnv = readRequiredText(raw, "APP_ENV", issues);
  const portRaw =
    raw.PORT ?? (appEnv === "local" ? String(DEFAULTS.port) : undefined);
  const swaggerDefault = appEnv === "local";

  const candidate = {
    environment: {
      nodeEnv,
      appEnv,
    },
    server: {
      host: readRequiredText(raw, "HOST", issues),
      port: parseInteger(portRaw, "PORT", issues),
      apiPrefix: readRequiredText(raw, "API_PREFIX", issues),
      logLevel: readOptionalText(raw, "LOG_LEVEL", DEFAULTS.logLevel, issues),
      trustProxy: parseOptionalBoolean(raw, "TRUST_PROXY", false, issues),
      requestIdHeader: parseRequestIdHeader(raw, issues),
      swaggerUiEnabled: parseOptionalBoolean(
        raw,
        "SWAGGER_UI_ENABLED",
        swaggerDefault,
        issues,
      ),
    },
    cors: {
      origins: parseCorsOrigins(raw, issues),
    },
    limits: {
      bodyLimitBytes: parseOptionalInteger(
        raw,
        "BODY_LIMIT_BYTES",
        DEFAULTS.bodyLimitBytes,
        issues,
      ),
      rateLimit: {
        max: parseOptionalInteger(
          raw,
          "RATE_LIMIT_MAX",
          DEFAULTS.rateLimitMax,
          issues,
        ),
        windowMs: parseOptionalInteger(
          raw,
          "RATE_LIMIT_WINDOW_MS",
          DEFAULTS.rateLimitWindowMs,
          issues,
        ),
        attemptMax: parseOptionalInteger(
          raw,
          "ATTEMPT_RATE_LIMIT_MAX",
          DEFAULTS.attemptRateLimitMax,
          issues,
        ),
        adminMax: parseOptionalInteger(
          raw,
          "ADMIN_RATE_LIMIT_MAX",
          DEFAULTS.adminRateLimitMax,
          issues,
        ),
      },
      timeouts: {
        connectionMs: parseOptionalInteger(
          raw,
          "CONNECTION_TIMEOUT_MS",
          DEFAULTS.connectionTimeoutMs,
          issues,
        ),
        requestReceiveMs: parseOptionalInteger(
          raw,
          "REQUEST_RECEIVE_TIMEOUT_MS",
          DEFAULTS.requestReceiveTimeoutMs,
          issues,
        ),
        dependencyMs: parseOptionalInteger(
          raw,
          "DEPENDENCY_TIMEOUT_MS",
          DEFAULTS.dependencyTimeoutMs,
          issues,
        ),
        handlerMs: parseOptionalInteger(
          raw,
          "HANDLER_TIMEOUT_MS",
          DEFAULTS.handlerTimeoutMs,
          issues,
        ),
        keepAliveMs: parseOptionalInteger(
          raw,
          "KEEP_ALIVE_TIMEOUT_MS",
          DEFAULTS.keepAliveTimeoutMs,
          issues,
        ),
        headersMs: parseOptionalInteger(
          raw,
          "HEADERS_TIMEOUT_MS",
          DEFAULTS.headersTimeoutMs,
          issues,
        ),
        readinessMs: parseOptionalInteger(
          raw,
          "READINESS_TIMEOUT_MS",
          DEFAULTS.readinessTimeoutMs,
          issues,
        ),
        shutdownMs: parseOptionalInteger(
          raw,
          "SHUTDOWN_TIMEOUT_MS",
          DEFAULTS.shutdownTimeoutMs,
          issues,
        ),
      },
    },
    supabase: {
      url: parseSupabaseEndpoint(raw, "SUPABASE_URL", issues),
      projectRef: readRequiredText(raw, "SUPABASE_PROJECT_REF", issues),
      publishableKey: parseSupabaseKey(
        raw,
        "SUPABASE_PUBLISHABLE_KEY",
        "sb_publishable_",
        issues,
      ),
      secretKey: parseSupabaseKey(
        raw,
        "SUPABASE_SECRET_KEY",
        "sb_secret_",
        issues,
      ),
      jwtIssuer: parseSupabaseIssuer(raw, "SUPABASE_JWT_ISSUER", issues),
      jwtAudience: readRequiredText(raw, "SUPABASE_JWT_AUDIENCE", issues),
    },
    cursor: {
      hmacSecret: parseCursorHmacSecret(raw, issues),
    },
    pythonGrader: {
      enabled: parseOptionalBoolean(
        raw,
        "PYTHON_GRADER_ENABLED",
        false,
        issues,
      ),
      concurrency: parseOptionalInteger(
        raw,
        "PYTHON_GRADER_CONCURRENCY",
        DEFAULTS.pythonGraderConcurrency,
        issues,
      ),
      queueLimit: parseOptionalInteger(
        raw,
        "PYTHON_GRADER_QUEUE_LIMIT",
        DEFAULTS.pythonGraderQueueLimit,
        issues,
      ),
    },
  };

  if (!collectSchemaIssues(candidate, issues)) {
    throw new ConfigValidationError(issues);
  }

  validateRelationships(candidate, issues);

  if (issues.length > 0) {
    throw new ConfigValidationError(issues);
  }

  return deepFreeze(candidate);
}

/**
 * Production entry point. It intentionally does not load dotenv or construct
 * Fastify, Supabase, or any other dependency.
 */
export function loadApiConfigFromProcessEnv(): ApiConfig {
  return parseApiConfig(process.env);
}
