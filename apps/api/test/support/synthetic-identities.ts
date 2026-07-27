/**
 * Test-only identities are deterministic data objects. They do not represent
 * passwords, sessions from an identity provider, or verified Auth factors.
 */
export type TestRole = "learner" | "editor" | "admin";
export type TestAal = "aal1" | "aal2";

export interface SyntheticActor {
  readonly namespace: string;
  readonly userId: string;
  readonly role: TestRole;
  readonly createdAtMs: number;
}

export interface SyntheticPrincipal {
  readonly userId: string;
  readonly role: TestRole;
  readonly sessionId: string;
  readonly aal: TestAal;
  readonly issuedAtMs: number;
}

export interface CreateSyntheticActorOptions {
  readonly role?: TestRole;
}

export interface CreateSyntheticPrincipalOptions {
  readonly actor?: SyntheticActor;
  readonly aal: TestAal;
}

export interface SyntheticIdentityFactory {
  readonly createActor: (
    options?: CreateSyntheticActorOptions,
  ) => SyntheticActor;
  readonly createPrincipal: (
    options: CreateSyntheticPrincipalOptions,
  ) => SyntheticPrincipal;
}

export interface SyntheticIdentityFactoryOptions {
  readonly namespace: string;
  readonly now?: () => number;
  readonly idFor?: (kind: "user" | "session", ordinal: number) => string;
}

const defaultNow = (): number => 0;
const defaultIdFor = (kind: "user" | "session", ordinal: number): string =>
  kind + "-" + ordinal;

export function createSyntheticIdentityFactory(
  options: SyntheticIdentityFactoryOptions,
): SyntheticIdentityFactory {
  const namespace = options.namespace.trim();

  if (namespace.length === 0) {
    throw new Error("A synthetic identity namespace is required.");
  }

  const now = options.now ?? defaultNow;
  const idFor = options.idFor ?? defaultIdFor;
  let ordinal = 0;

  const nextId = (kind: "user" | "session"): string => {
    ordinal += 1;
    const id = idFor(kind, ordinal).trim();

    if (id.length === 0) {
      throw new Error("Synthetic test identifiers must not be empty.");
    }

    return namespace + ":" + id;
  };

  const createActor = (
    input: CreateSyntheticActorOptions = {},
  ): SyntheticActor =>
    Object.freeze({
      namespace,
      userId: nextId("user"),
      role: input.role ?? "learner",
      createdAtMs: now(),
    });

  const createPrincipal = (
    input: CreateSyntheticPrincipalOptions,
  ): SyntheticPrincipal => {
    const actor = input.actor ?? createActor();

    return Object.freeze({
      userId: actor.userId,
      role: actor.role,
      sessionId: nextId("session"),
      aal: input.aal,
      issuedAtMs: now(),
    });
  };

  return Object.freeze({ createActor, createPrincipal });
}
