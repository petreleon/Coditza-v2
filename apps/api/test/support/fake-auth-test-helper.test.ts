import { describe, expect, it } from "vitest";

import { createFakeAuthTestHelper } from "./fake-auth-test-helper.js";
import { createSyntheticIdentityFactory } from "./synthetic-identities.js";

describe("createFakeAuthTestHelper", () => {
  it("models only deterministic injected assurance state", async () => {
    const identities = createSyntheticIdentityFactory({
      namespace: "auth-helper",
    });
    const helper = createFakeAuthTestHelper(identities);
    const actor = identities.createActor({ role: "learner" });

    const aal1 = await helper.issue({ actor, aal: "aal1" });
    const aal2 = await helper.issue({ actor, aal: "aal2" });

    expect(aal1.principal).toMatchObject({
      userId: actor.userId,
      role: "learner",
      aal: "aal1",
    });
    expect(aal2.principal).toMatchObject({
      userId: actor.userId,
      role: "learner",
      aal: "aal2",
    });
    expect(aal1.principal.sessionId).not.toBe(aal2.principal.sessionId);
    expect(JSON.stringify(aal1.token)).toBe("{}");
    await expect(helper.resolve(aal1.token)).resolves.toStrictEqual({
      kind: "principal",
      principal: aal1.principal,
    });
  });

  it("keeps opaque tokens instance-local and cleans up idempotently", async () => {
    const first = createFakeAuthTestHelper(
      createSyntheticIdentityFactory({ namespace: "first-helper" }),
    );
    const second = createFakeAuthTestHelper(
      createSyntheticIdentityFactory({ namespace: "second-helper" }),
    );
    const issued = await first.issue({ aal: "aal1" });

    await expect(second.resolve(issued.token)).resolves.toStrictEqual({
      kind: "invalid",
    });
    await expect(first.cleanup()).resolves.toStrictEqual({ released: 1 });
    await expect(first.resolve(issued.token)).resolves.toStrictEqual({
      kind: "invalid",
    });
    await expect(first.cleanup()).resolves.toStrictEqual({ released: 0 });
    await expect(first.issue({ aal: "aal2" })).rejects.toThrowError(
      "Fake Auth test helper is closed.",
    );
  });
});
