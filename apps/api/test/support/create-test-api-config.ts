import {
  parseApiConfig,
  type ApiConfig,
  type RawEnvironment,
} from "../../src/infrastructure/config/index.js";

const HMAC_32_BYTES = "A".repeat(43);

const validLocalEnvironment: RawEnvironment = Object.freeze({
  NODE_ENV: "test",
  APP_ENV: "local",
  HOST: "127.0.0.1",
  API_PREFIX: "/api/v1",
  CORS_ORIGINS: "http://localhost:5173",
  SUPABASE_URL: "http://127.0.0.1:54321",
  SUPABASE_PROJECT_REF: "local",
  SUPABASE_PUBLISHABLE_KEY: "sb_publishable_test_only",
  SUPABASE_SECRET_KEY: "sb_secret_test_only",
  SUPABASE_JWT_ISSUER: "http://localhost:54321/auth/v1",
  SUPABASE_JWT_AUDIENCE: "authenticated",
  CURSOR_HMAC_SECRET: HMAC_32_BYTES,
});

/** Builds a synthetic frozen API configuration without mutating process.env. */
export function createTestApiConfig(
  overrides: Readonly<Record<string, string | undefined>> = {},
): ApiConfig {
  return parseApiConfig(
    Object.freeze({ ...validLocalEnvironment, ...overrides }),
  );
}
