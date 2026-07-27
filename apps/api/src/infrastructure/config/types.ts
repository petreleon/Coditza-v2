/**
 * FAST-CONFIG-001 replaces this contract with the parsed, immutable API
 * configuration. Until then, composition receives configuration only by
 * injection and this module deliberately does not read process.env.
 */
export interface FoundationConfigContract {
  readonly source: "injected";
}
