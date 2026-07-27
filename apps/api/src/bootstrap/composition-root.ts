/**
 * FAST-BOOT-001 owns construction of the concrete API composition root.
 * This contract reserves its typed seam without constructing an adapter,
 * client, repository bag, or framework instance.
 */
export interface FoundationCompositionContract {
  readonly context: "api";
}
