import { describe, expect, it, vi } from "vitest";

import type { ApiApplicationDependencies } from "../../src/bootstrap/composition-root.js";
import {
  ApiServerShutdownError,
  ApiServerStartupError,
  startServer,
  type ApiAppFactory,
  type ApiServerApplication,
  type ServerRuntime,
  type ShutdownSignal,
  type ShutdownTimer,
  type ShutdownTimerHandle,
  type SignalSource,
} from "../../src/server.js";
import { createTestApiConfig } from "../support/create-test-api-config.js";

const fakeDependencies: ApiApplicationDependencies = Object.freeze({
  composition: Object.freeze({ context: "api" }),
});

class TestSignalSource implements SignalSource {
  readonly onCalls = vi.fn();
  readonly offCalls = vi.fn();
  readonly listeners = new Map<ShutdownSignal, Set<() => void>>();

  on(signal: ShutdownSignal, listener: () => void): void {
    this.onCalls(signal, listener);
    const registered = this.listeners.get(signal) ?? new Set<() => void>();
    registered.add(listener);
    this.listeners.set(signal, registered);
  }

  off(signal: ShutdownSignal, listener: () => void): void {
    this.offCalls(signal, listener);
    this.listeners.get(signal)?.delete(listener);
  }

  emit(signal: ShutdownSignal): void {
    for (const listener of [...(this.listeners.get(signal) ?? [])]) {
      listener();
    }
  }

  listenerCount(signal: ShutdownSignal): number {
    return this.listeners.get(signal)?.size ?? 0;
  }
}

function createTestTimer(): {
  readonly timer: ShutdownTimer;
  readonly fire: () => void;
  readonly setTimeoutSpy: ReturnType<typeof vi.fn>;
  readonly clearTimeoutSpy: ReturnType<typeof vi.fn>;
} {
  let callback: (() => void) | undefined;
  const timeoutHandle = {} as ShutdownTimerHandle;
  const setTimeoutSpy = vi.fn(
    (nextCallback: () => void, _timeoutMs: number): ShutdownTimerHandle => {
      callback = nextCallback;
      return timeoutHandle;
    },
  );
  const clearTimeoutSpy = vi.fn(
    (_handle: ShutdownTimerHandle): void => undefined,
  );

  return {
    timer: {
      setTimeout: setTimeoutSpy,
      clearTimeout: clearTimeoutSpy,
    },
    fire: () => {
      callback?.();
    },
    setTimeoutSpy,
    clearTimeoutSpy,
  };
}

function createRuntime(timer: ShutdownTimer): {
  readonly runtime: ServerRuntime;
  readonly signals: TestSignalSource;
  readonly setExitCode: ReturnType<typeof vi.fn>;
  readonly reportFailure: ReturnType<typeof vi.fn>;
  readonly terminate: ReturnType<typeof vi.fn>;
} {
  const signals = new TestSignalSource();
  const setExitCode = vi.fn((_code: number): void => undefined);
  const reportFailure = vi.fn((_message: string): void => undefined);
  const terminate = vi.fn((_code: number): void => undefined);

  return {
    runtime: { signals, timer, setExitCode, reportFailure, terminate },
    signals,
    setExitCode,
    reportFailure,
    terminate,
  };
}

function createFakeApp(
  options: {
    readonly failAt?: "ready" | "listen";
    readonly failure?: Error;
    readonly close?: () => Promise<void>;
  } = {},
): {
  readonly app: ApiServerApplication;
  readonly calls: string[];
  readonly ready: ReturnType<typeof vi.fn>;
  readonly listen: ReturnType<typeof vi.fn>;
  readonly close: ReturnType<typeof vi.fn>;
} {
  const calls: string[] = [];
  const ready = vi.fn(async (): Promise<void> => {
    calls.push("ready");

    if (options.failAt === "ready") {
      throw options.failure;
    }
  });
  const listen = vi.fn(
    async (listenOptions: {
      readonly host: string;
      readonly port: number;
    }): Promise<string> => {
      calls.push("listen");

      if (options.failAt === "listen") {
        throw options.failure;
      }

      return `http://${listenOptions.host}:${listenOptions.port}`;
    },
  );
  const close = vi.fn(async (): Promise<void> => {
    calls.push("close");
    await options.close?.();
  });

  return {
    app: { ready, listen, close },
    calls,
    ready,
    listen,
    close,
  };
}

describe("startServer", () => {
  it("waits for Fastify readiness before listening with the injected host and port", async () => {
    const config = createTestApiConfig();
    const fakeApp = createFakeApp();
    const appFactory: ApiAppFactory = vi.fn(() => fakeApp.app);
    const testTimer = createTestTimer();
    const runtime = createRuntime(testTimer.timer);

    const started = await startServer({
      config,
      dependencies: fakeDependencies,
      appFactory,
      runtime: runtime.runtime,
    });

    expect(fakeApp.calls).toEqual(["ready", "listen"]);
    expect(fakeApp.listen).toHaveBeenCalledWith({
      host: config.server.host,
      port: config.server.port,
    });
    expect(runtime.signals.listenerCount("SIGTERM")).toBe(1);
    expect(runtime.signals.listenerCount("SIGINT")).toBe(1);

    await started.stop();

    expect(fakeApp.close).toHaveBeenCalledTimes(1);
    expect(testTimer.setTimeoutSpy).toHaveBeenCalledWith(
      expect.any(Function),
      config.limits.timeouts.shutdownMs,
    );
    expect(runtime.signals.listenerCount("SIGTERM")).toBe(0);
    expect(runtime.signals.listenerCount("SIGINT")).toBe(0);
  });

  it.each(["ready", "listen"] as const)(
    "fails %s safely without exposing configuration values",
    async (failAt) => {
      const sensitiveCanary = "sb_secret_STARTUP_FAILURE_CANARY";
      const fakeApp = createFakeApp({
        failAt,
        failure: new Error(sensitiveCanary),
      });
      const testTimer = createTestTimer();
      const runtime = createRuntime(testTimer.timer);
      const config = createTestApiConfig({
        SUPABASE_SECRET_KEY: sensitiveCanary,
      });

      let thrown: unknown;

      try {
        await startServer({
          config,
          dependencies: fakeDependencies,
          appFactory: () => fakeApp.app,
          runtime: runtime.runtime,
        });
      } catch (error) {
        thrown = error;
      }

      expect(thrown).toBeInstanceOf(ApiServerStartupError);
      expect(fakeApp.close).toHaveBeenCalledTimes(1);
      expect(runtime.setExitCode).toHaveBeenCalledWith(1);
      expect(runtime.reportFailure).toHaveBeenCalledWith(
        "Coditza API startup failed.",
      );
      expect(runtime.signals.listenerCount("SIGTERM")).toBe(0);
      expect(runtime.signals.listenerCount("SIGINT")).toBe(0);

      const rendered = [
        String(thrown),
        thrown instanceof Error ? thrown.message : "",
        JSON.stringify(thrown),
        runtime.reportFailure.mock.calls.flat().join("\n"),
      ].join("\n");

      expect(rendered).not.toContain(sensitiveCanary);
    },
  );

  it("terminates when failed startup cleanup exceeds the injected timeout", async () => {
    const sensitiveCanary = "sb_secret_STARTUP_CLEANUP_CANARY";
    let markCloseStarted: (() => void) | undefined;
    const closeStarted = new Promise<void>((resolve) => {
      markCloseStarted = resolve;
    });
    const closeNeverResolves = new Promise<void>(() => undefined);
    const fakeApp = createFakeApp({
      failAt: "ready",
      failure: new Error(sensitiveCanary),
      close: () => {
        markCloseStarted?.();
        return closeNeverResolves;
      },
    });
    const testTimer = createTestTimer();
    const runtime = createRuntime(testTimer.timer);
    const config = createTestApiConfig({
      SUPABASE_SECRET_KEY: sensitiveCanary,
      SHUTDOWN_TIMEOUT_MS: "1000",
    });

    const startup = startServer({
      config,
      dependencies: fakeDependencies,
      appFactory: () => fakeApp.app,
      runtime: runtime.runtime,
    });

    await closeStarted;
    testTimer.fire();

    await expect(startup).rejects.toBeInstanceOf(ApiServerStartupError);

    expect(fakeApp.close).toHaveBeenCalledTimes(1);
    expect(runtime.setExitCode).toHaveBeenCalledWith(1);
    expect(runtime.reportFailure).toHaveBeenCalledWith(
      "Coditza API startup failed.",
    );
    expect(runtime.terminate).toHaveBeenCalledOnce();
    expect(runtime.terminate).toHaveBeenCalledWith(1);

    const rendered = runtime.reportFailure.mock.calls.flat().join("\n");
    expect(rendered).not.toContain(sensitiveCanary);
  });

  it("shares one idempotent shutdown across SIGTERM and SIGINT", async () => {
    const config = createTestApiConfig();
    const fakeApp = createFakeApp();
    const testTimer = createTestTimer();
    const runtime = createRuntime(testTimer.timer);
    const started = await startServer({
      config,
      dependencies: fakeDependencies,
      appFactory: () => fakeApp.app,
      runtime: runtime.runtime,
    });

    runtime.signals.emit("SIGTERM");
    runtime.signals.emit("SIGINT");
    await started.stop();

    expect(fakeApp.close).toHaveBeenCalledTimes(1);
    expect(runtime.reportFailure).not.toHaveBeenCalled();
    expect(runtime.setExitCode).not.toHaveBeenCalled();
    expect(runtime.terminate).not.toHaveBeenCalled();
    expect(runtime.signals.offCalls).toHaveBeenCalledTimes(2);
  });

  it("fails shutdown within the injected timeout and removes both signal handlers", async () => {
    const closeNeverResolves = new Promise<void>(() => undefined);
    const fakeApp = createFakeApp({ close: () => closeNeverResolves });
    const testTimer = createTestTimer();
    const runtime = createRuntime(testTimer.timer);
    const config = createTestApiConfig({ SHUTDOWN_TIMEOUT_MS: "1000" });
    const started = await startServer({
      config,
      dependencies: fakeDependencies,
      appFactory: () => fakeApp.app,
      runtime: runtime.runtime,
    });

    const shutdown = started.stop();
    await Promise.resolve();
    testTimer.fire();

    await expect(shutdown).rejects.toBeInstanceOf(ApiServerShutdownError);

    expect(fakeApp.close).toHaveBeenCalledTimes(1);
    expect(testTimer.setTimeoutSpy).toHaveBeenCalledWith(
      expect.any(Function),
      1_000,
    );
    expect(runtime.setExitCode).toHaveBeenCalledWith(1);
    expect(runtime.reportFailure).toHaveBeenCalledWith(
      "Coditza API shutdown failed.",
    );
    expect(runtime.terminate).toHaveBeenCalledWith(1);
    expect(runtime.signals.listenerCount("SIGTERM")).toBe(0);
    expect(runtime.signals.listenerCount("SIGINT")).toBe(0);
  });
});
