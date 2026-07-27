import { describe, expect, it } from "vitest";

import { createInMemoryTestScope } from "./in-memory-test-scope.js";

describe("createInMemoryTestScope", () => {
  it("owns deterministic in-memory labels and never shares cleanup", () => {
    const first = createInMemoryTestScope("first-test");
    const second = createInMemoryTestScope("second-test");

    expect(first.reserve("attempt")).toBe("first-test:attempt:1");
    expect(first.reserve("attempt")).toBe("first-test:attempt:2");
    expect(second.reserve("attempt")).toBe("second-test:attempt:1");
    expect(first.pending()).toStrictEqual([
      "first-test:attempt:1",
      "first-test:attempt:2",
    ]);
    expect(second.pending()).toStrictEqual(["second-test:attempt:1"]);

    expect(first.cleanup()).toStrictEqual({ released: 2 });
    expect(first.pending()).toStrictEqual([]);
    expect(second.pending()).toStrictEqual(["second-test:attempt:1"]);
    expect(first.cleanup()).toStrictEqual({ released: 0 });
    expect(() => first.reserve("later")).toThrowError(
      "In-memory test scope is closed.",
    );
  });

  it("rejects blank namespaces and labels", () => {
    expect(() => createInMemoryTestScope(" ")).toThrowError(
      "An in-memory test scope namespace is required.",
    );

    const scope = createInMemoryTestScope("unit-scope");
    expect(() => scope.reserve(" ")).toThrowError(
      "An in-memory test scope label is required.",
    );
  });
});
