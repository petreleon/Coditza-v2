export interface InMemoryTestScope {
  readonly namespace: string;
  readonly reserve: (label: string) => string;
  readonly pending: () => readonly string[];
  readonly cleanup: () => Readonly<{ readonly released: number }>;
}

/**
 * A test fixture namespace owns only in-memory labels. Its cleanup cannot
 * delete database rows, containers, files, or hosted resources.
 */
export function createInMemoryTestScope(
  namespaceInput: string,
): InMemoryTestScope {
  const namespace = namespaceInput.trim();

  if (namespace.length === 0) {
    throw new Error("An in-memory test scope namespace is required.");
  }

  const reserved = new Set<string>();
  let ordinal = 0;
  let closed = false;

  const reserve = (labelInput: string): string => {
    if (closed) {
      throw new Error("In-memory test scope is closed.");
    }

    const label = labelInput.trim();

    if (label.length === 0) {
      throw new Error("An in-memory test scope label is required.");
    }

    ordinal += 1;
    const identifier = namespace + ":" + label + ":" + ordinal;
    reserved.add(identifier);

    return identifier;
  };

  const pending = (): readonly string[] => Object.freeze([...reserved].sort());

  const cleanup = (): Readonly<{ readonly released: number }> => {
    const released = reserved.size;
    reserved.clear();
    closed = true;

    return Object.freeze({ released });
  };

  return Object.freeze({ namespace, reserve, pending, cleanup });
}
