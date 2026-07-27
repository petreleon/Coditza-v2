import { describe, expect, it } from "vitest";

import { createSyntheticIdentityFactory } from "./synthetic-identities.js";

describe("createSyntheticIdentityFactory", () => {
  it("creates immutable, deterministic principals without shared state", () => {
    const identities = createSyntheticIdentityFactory({
      namespace: "unit-identities",
      now: () => 1_700_000_000_000,
      idFor: (kind, ordinal) => kind + "-" + ordinal,
    });

    const actor = identities.createActor({ role: "editor" });
    const principal = identities.createPrincipal({ actor, aal: "aal2" });

    expect(actor).toStrictEqual({
      namespace: "unit-identities",
      userId: "unit-identities:user-1",
      role: "editor",
      createdAtMs: 1_700_000_000_000,
    });
    expect(principal).toStrictEqual({
      userId: "unit-identities:user-1",
      role: "editor",
      sessionId: "unit-identities:session-2",
      aal: "aal2",
      issuedAtMs: 1_700_000_000_000,
    });
    expect(Object.isFrozen(actor)).toBe(true);
    expect(Object.isFrozen(principal)).toBe(true);

    const otherFactory = createSyntheticIdentityFactory({
      namespace: "other-identities",
    });

    expect(otherFactory.createActor().userId).toBe("other-identities:user-1");
  });

  it("rejects blank namespaces and blank injected identifiers", () => {
    expect(() =>
      createSyntheticIdentityFactory({ namespace: "   " }),
    ).toThrowError("A synthetic identity namespace is required.");

    const identities = createSyntheticIdentityFactory({
      namespace: "unit-identities",
      idFor: () => " ",
    });

    expect(() => identities.createActor()).toThrowError(
      "Synthetic test identifiers must not be empty.",
    );
  });
});
