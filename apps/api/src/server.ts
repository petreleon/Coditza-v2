import { clearTimeout, setTimeout } from "node:timers";

import { buildApp, type BuildAppOptions } from "./app.js";
import {
  createApiDependencies,
  type ApiApplicationDependencies,
} from "./bootstrap/composition-root.js";
import {
  loadApiConfigFromProcessEnv,
  type ApiConfig,
} from "./infrastructure/config/index.js";

const STARTUP_FAILURE_MESSAGE = "Coditza API startup failed.";
const SHUTDOWN_FAILURE_MESSAGE = "Coditza API shutdown failed.";
const SHUTDOWN_SIGNALS = ["SIGTERM", "SIGINT"] as const;

export type ShutdownSignal = (typeof SHUTDOWN_SIGNALS)[number];
export type ShutdownTimerHandle = ReturnType<typeof setTimeout>;

/** A deliberately narrow Fastify lifecycle surface for deterministic tests. */
export interface ApiServerApplication {
  ready(): PromiseLike<void>;
  listen(options: {
    readonly host: string;
    readonly port: number;
  }): PromiseLike<string>;
  close(): PromiseLike<void>;
}

export type ApiAppFactory = (options: BuildAppOptions) => ApiServerApplication;

export interface SignalSource {
  on(signal: ShutdownSignal, listener: () => void): void;
  off(signal: ShutdownSignal, listener: () => void): void;
}

export interface ShutdownTimer {
  setTimeout(callback: () => void, timeoutMs: number): ShutdownTimerHandle;
  clearTimeout(handle: ShutdownTimerHandle): void;
}

export interface ServerRuntime {
  readonly signals: SignalSource;
  readonly timer: ShutdownTimer;
  readonly setExitCode: (code: number) => void;
  readonly reportFailure: (message: string) => void;
  readonly terminate: (code: number) => void;
}

export interface StartServerOptions {
  readonly config: ApiConfig;
  readonly dependencies: ApiApplicationDependencies;
  readonly appFactory?: ApiAppFactory;
  readonly runtime?: ServerRuntime;
}

export interface StartedApiServer {
  readonly app: ApiServerApplication;
  readonly stop: () => Promise<void>;
}

export class ApiServerStartupError extends Error {
  constructor() {
    super(STARTUP_FAILURE_MESSAGE);
    this.name = "ApiServerStartupError";
  }
}

export class ApiServerShutdownError extends Error {
  constructor() {
    super(SHUTDOWN_FAILURE_MESSAGE);
    this.name = "ApiServerShutdownError";
  }
}

const productionRuntime: ServerRuntime = {
  signals: {
    on(signal, listener) {
      process.on(signal, listener);
    },
    off(signal, listener) {
      process.off(signal, listener);
    },
  },
  timer: {
    setTimeout(callback, timeoutMs) {
      return setTimeout(callback, timeoutMs);
    },
    clearTimeout(handle) {
      clearTimeout(handle);
    },
  },
  setExitCode(code) {
    process.exitCode = code;
  },
  reportFailure(message) {
    console.error(message);
  },
  terminate(code) {
    process.exit(code);
  },
};

function closeWithinTimeout(
  app: ApiServerApplication,
  timeoutMs: number,
  timer: ShutdownTimer,
): Promise<void> {
  return new Promise((resolve, reject) => {
    let settled = false;
    let timeoutHandle: ShutdownTimerHandle | undefined;

    const finish = (error?: ApiServerShutdownError): void => {
      if (settled) {
        return;
      }

      settled = true;

      if (timeoutHandle !== undefined) {
        timer.clearTimeout(timeoutHandle);
      }

      if (error === undefined) {
        resolve();
        return;
      }

      reject(error);
    };

    try {
      timeoutHandle = timer.setTimeout(() => {
        finish(new ApiServerShutdownError());
      }, timeoutMs);
    } catch {
      finish(new ApiServerShutdownError());
      return;
    }

    void Promise.resolve()
      .then(() => app.close())
      .then(
        () => {
          finish();
        },
        () => {
          finish(new ApiServerShutdownError());
        },
      );
  });
}

async function closeAfterStartupFailure(
  app: ApiServerApplication,
  timeoutMs: number,
  timer: ShutdownTimer,
): Promise<boolean> {
  try {
    await closeWithinTimeout(app, timeoutMs, timer);
    return true;
  } catch {
    // Startup has one safe outcome: the fixed startup failure below. Raw close
    // failures must not reach a process log that could contain configuration.
    return false;
  }
}

/**
 * Starts an already-composed API process. The app factory itself never opens a
 * listener; this function is the only path that does so.
 */
export async function startServer({
  config,
  dependencies,
  appFactory = buildApp,
  runtime = productionRuntime,
}: StartServerOptions): Promise<StartedApiServer> {
  let app: ApiServerApplication | undefined;

  try {
    app = appFactory({ config, dependencies });
    await app.ready();
    await app.listen({
      host: config.server.host,
      port: config.server.port,
    });
  } catch {
    const closed =
      app === undefined ||
      (await closeAfterStartupFailure(
        app,
        config.limits.timeouts.shutdownMs,
        runtime.timer,
      ));

    runtime.setExitCode(1);
    runtime.reportFailure(STARTUP_FAILURE_MESSAGE);

    if (!closed) {
      runtime.terminate(1);
    }

    throw new ApiServerStartupError();
  }

  if (app === undefined) {
    runtime.setExitCode(1);
    runtime.reportFailure(STARTUP_FAILURE_MESSAGE);
    throw new ApiServerStartupError();
  }

  let shutdownPromise: Promise<void> | undefined;

  const removeSignalHandlers = (): void => {
    for (const signal of SHUTDOWN_SIGNALS) {
      runtime.signals.off(signal, signalHandler);
    }
  };

  const stop = (): Promise<void> => {
    if (shutdownPromise !== undefined) {
      return shutdownPromise;
    }

    shutdownPromise = closeWithinTimeout(
      app,
      config.limits.timeouts.shutdownMs,
      runtime.timer,
    ).then(
      () => {
        removeSignalHandlers();
      },
      () => {
        removeSignalHandlers();
        runtime.setExitCode(1);
        runtime.reportFailure(SHUTDOWN_FAILURE_MESSAGE);
        runtime.terminate(1);
        throw new ApiServerShutdownError();
      },
    );

    return shutdownPromise;
  };

  const signalHandler = (): void => {
    void stop().catch(() => undefined);
  };

  for (const signal of SHUTDOWN_SIGNALS) {
    runtime.signals.on(signal, signalHandler);
  }

  return { app, stop };
}

/** Production-only construction path; imports do not start a listener. */
export async function startProductionServer(): Promise<StartedApiServer> {
  try {
    const config = loadApiConfigFromProcessEnv();
    const dependencies = createApiDependencies();

    return await startServer({ config, dependencies });
  } catch (error) {
    if (error instanceof ApiServerStartupError) {
      throw error;
    }

    productionRuntime.setExitCode(1);
    productionRuntime.reportFailure(STARTUP_FAILURE_MESSAGE);
    throw new ApiServerStartupError();
  }
}

if (import.meta.main) {
  void startProductionServer().catch(() => undefined);
}
