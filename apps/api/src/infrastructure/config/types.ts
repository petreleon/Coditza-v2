import type { ParsedApiConfig } from "./schema.js";

export type RawEnvironment = Readonly<Record<string, string | undefined>>;

export type DeepReadonly<T> = T extends readonly (infer Item)[]
  ? readonly DeepReadonly<Item>[]
  : T extends object
    ? { readonly [Key in keyof T]: DeepReadonly<T[Key]> }
    : T;

export type ApiConfig = DeepReadonly<ParsedApiConfig>;

export interface ConfigIssue {
  readonly variable: string;
  readonly reason: string;
}

/**
 * Deliberately exposes only variable names and fixed validation reasons.
 * Raw values must never be interpolated into this error or its stack.
 */
export class ConfigValidationError extends Error {
  readonly fields: readonly string[];
  readonly issues: readonly ConfigIssue[];

  constructor(issues: readonly ConfigIssue[]) {
    const uniqueIssues = issues.filter(
      (issue, index) =>
        issues.findIndex(
          (candidate) =>
            candidate.variable === issue.variable &&
            candidate.reason === issue.reason,
        ) === index,
    );

    super(
      `Invalid configuration: ${uniqueIssues
        .map((issue) => `${issue.variable} (${issue.reason})`)
        .join(", ")}`,
    );

    this.name = "ConfigValidationError";
    this.fields = Object.freeze([
      ...new Set(uniqueIssues.map((issue) => issue.variable)),
    ]);
    this.issues = Object.freeze(
      uniqueIssues.map((issue) => Object.freeze({ ...issue })),
    );
  }
}
