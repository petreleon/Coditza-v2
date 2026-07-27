/**
 * The intentionally empty API composition boundary. Future tasks may extend
 * it only with narrow inbound facades; raw clients and generic service bags
 * never cross into Fastify.
 */
export interface FoundationCompositionContract {
  readonly context: "api";
}

export interface ApiApplicationDependencies {
  readonly composition: FoundationCompositionContract;
}

/**
 * The sole production API wiring point. At this foundation stage it constructs
 * no client, adapter, module, controller, or external resource.
 */
export function createApiDependencies(): ApiApplicationDependencies {
  const composition: FoundationCompositionContract = Object.freeze({
    context: "api",
  });

  return Object.freeze({ composition });
}
