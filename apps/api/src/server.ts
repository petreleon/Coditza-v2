import type { ApiApplicationContract } from "./app.js";

/**
 * FAST-BOOT-001 turns this compiled ESM entry module into the sole listener.
 * FOUND-001 intentionally exports only its contract and opens no socket.
 */
export type ApiServerEntrypointContract = ApiApplicationContract;
