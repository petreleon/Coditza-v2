export interface ShortTextNormalizationGoldenVector {
  readonly input: string;
  readonly output: string;
}

export const SHORT_TEXT_NORMALIZATION_GOLDEN_VECTORS = Object.freeze([
  Object.freeze({ input: "Café", output: "café" }),
  Object.freeze({ input: "Cafe\u0301", output: "café" }),
  Object.freeze({ input: "A\tB\n C", output: "a b c" }),
  Object.freeze({ input: " \r\n\t ", output: "" }),
  Object.freeze({ input: "PyThOn", output: "python" }),
  Object.freeze({ input: "İSTANBUL", output: "İstanbul" }),
] satisfies readonly ShortTextNormalizationGoldenVector[]);
