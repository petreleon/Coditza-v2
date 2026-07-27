import type { FastifyInstance } from "fastify";

import type { FoundationCompositionContract } from "./bootstrap/composition-root.js";
import type { ApiConfig } from "./infrastructure/config/types.js";

/**
 * The future app factory receives only an injected configuration contract and
 * a composition-root contract. FAST-BOOT-001 owns the actual buildApp factory.
 */
export interface ApiApplicationContract {
  readonly config: ApiConfig;
  readonly composition: FoundationCompositionContract;
  readonly instance: FastifyInstance;
}
