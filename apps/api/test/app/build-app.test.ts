import { describe, expect, it } from "vitest";

import { buildApp } from "../../src/app.js";
import type { ApiApplicationDependencies } from "../../src/bootstrap/composition-root.js";
import { createTestApiConfig } from "../support/create-test-api-config.js";

const fakeDependencies: ApiApplicationDependencies = Object.freeze({
  composition: Object.freeze({ context: "api" }),
});

describe("buildApp", () => {
  it("serves the closed liveness response without a listener or dependencies", async () => {
    const config = createTestApiConfig();
    const inaccessibleDependencies: ApiApplicationDependencies = new Proxy(
      fakeDependencies,
      {
        get() {
          throw new Error("The liveness route must not access dependencies.");
        },
      },
    );
    const app = buildApp({
      config,
      dependencies: inaccessibleDependencies,
    });

    try {
      expect(app.server.listening).toBe(false);

      const response = await app.inject({
        method: "GET",
        url: "/health/live",
      });

      expect(response.statusCode).toBe(200);
      expect(response.json()).toStrictEqual({ status: "ok" });
      expect(app.server.listening).toBe(false);

      const headResponse = await app.inject({
        method: "HEAD",
        url: "/health/live",
      });

      expect(headResponse.statusCode).toBe(404);
    } finally {
      await app.close();
    }
  });

  it("creates an unlistened Fastify app from explicit inputs", async () => {
    const config = createTestApiConfig();
    const app = buildApp({ config, dependencies: fakeDependencies });

    try {
      expect(app.server.listening).toBe(false);
      expect(app.initialConfig).toMatchObject({
        bodyLimit: config.limits.bodyLimitBytes,
        connectionTimeout: config.limits.timeouts.connectionMs,
        keepAliveTimeout: config.limits.timeouts.keepAliveMs,
        requestIdHeader: config.server.requestIdHeader,
      });
      expect(app.server.requestTimeout).toBe(
        config.limits.timeouts.requestReceiveMs,
      );
      expect(app.server.headersTimeout).toBe(config.limits.timeouts.headersMs);

      const response = await app.inject({
        method: "GET",
        url: "/api/v1/not-configured-yet",
      });

      expect(response.statusCode).toBe(404);
      expect(app.server.listening).toBe(false);
    } finally {
      await app.close();
    }
  });
});
