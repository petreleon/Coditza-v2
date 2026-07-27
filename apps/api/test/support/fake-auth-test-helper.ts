import type {
  SyntheticActor,
  SyntheticIdentityFactory,
  SyntheticPrincipal,
  TestAal,
} from "./synthetic-identities.js";

const fakeAuthTokenBrand = Symbol("coditza.fake-auth-token");

export interface FakeAuthToken {
  readonly [fakeAuthTokenBrand]: true;
}

export interface FakeAuthIssueInput {
  readonly actor?: SyntheticActor;
  readonly aal: TestAal;
}

export type FakeAuthResolution =
  | Readonly<{ readonly kind: "invalid" }>
  | Readonly<{
      readonly kind: "principal";
      readonly principal: SyntheticPrincipal;
    }>;

export interface AuthTestHelper<Token> {
  readonly issue: (
    input: FakeAuthIssueInput,
  ) => Promise<
    Readonly<{ readonly token: Token; readonly principal: SyntheticPrincipal }>
  >;
  readonly resolve: (token: Token) => Promise<FakeAuthResolution>;
  readonly cleanup: () => Promise<Readonly<{ readonly released: number }>>;
}

function createFakeAuthToken(): FakeAuthToken {
  return Object.freeze({ [fakeAuthTokenBrand]: true }) as FakeAuthToken;
}

/**
 * This models only injected test assurance state. It does not authenticate a
 * password, enroll a factor, verify TOTP, or create a provider session.
 */
export function createFakeAuthTestHelper(
  identities: SyntheticIdentityFactory,
): AuthTestHelper<FakeAuthToken> {
  const issued = new Map<FakeAuthToken, SyntheticPrincipal>();
  const invalidResolution = Object.freeze({ kind: "invalid" } as const);
  let closed = false;

  const issue = async (
    input: FakeAuthIssueInput,
  ): Promise<
    Readonly<{
      readonly token: FakeAuthToken;
      readonly principal: SyntheticPrincipal;
    }>
  > => {
    if (closed) {
      throw new Error("Fake Auth test helper is closed.");
    }

    const principal =
      input.actor === undefined
        ? identities.createPrincipal({ aal: input.aal })
        : identities.createPrincipal({ actor: input.actor, aal: input.aal });
    const token = createFakeAuthToken();
    issued.set(token, principal);

    return Object.freeze({ token, principal });
  };

  const resolve = async (token: FakeAuthToken): Promise<FakeAuthResolution> => {
    const principal = issued.get(token);

    return principal === undefined
      ? invalidResolution
      : Object.freeze({ kind: "principal" as const, principal });
  };

  const cleanup = async (): Promise<
    Readonly<{ readonly released: number }>
  > => {
    const released = issued.size;
    issued.clear();
    closed = true;

    return Object.freeze({ released });
  };

  return Object.freeze({ issue, resolve, cleanup });
}
