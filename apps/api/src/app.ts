import Fastify, { type FastifyInstance } from "fastify";

import type { ApiApplicationDependencies } from "./bootstrap/composition-root.js";
import type { ApiConfig } from "./infrastructure/config/types.js";

export interface BuildAppOptions {
  readonly config: ApiConfig;
  readonly dependencies: ApiApplicationDependencies;
}

/**
 * Creates the public API application from explicit, already-validated inputs.
 * It deliberately installs no route, plugin, decoration, or listener.
 */
export function buildApp({
  config,
  dependencies,
}: BuildAppOptions): FastifyInstance {
  // The composition boundary is required at this factory seam but cannot be
  // exposed through Fastify until a later task owns a narrow route facade.
  void dependencies;

  const app = Fastify({
    bodyLimit: config.limits.bodyLimitBytes,
    connectionTimeout: config.limits.timeouts.connectionMs,
    handlerTimeout: config.limits.timeouts.handlerMs,
    keepAliveTimeout: config.limits.timeouts.keepAliveMs,
    logger: false,
    requestIdHeader: config.server.requestIdHeader,
    requestTimeout: config.limits.timeouts.requestReceiveMs,
    trustProxy: config.server.trustProxy,
  });

  // Fastify delegates this Node HTTP setting to the created server instance.
  app.server.headersTimeout = config.limits.timeouts.headersMs;

  return app;
}
