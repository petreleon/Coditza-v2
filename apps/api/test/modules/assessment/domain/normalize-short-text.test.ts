import { describe, expect, it } from "vitest";

import { SHORT_TEXT_NORMALIZATION_GOLDEN_VECTORS } from "../../../../src/modules/assessment/domain/normalization-golden-vectors.js";
import {
  normalizeShortText,
  SHORT_TEXT_NORMALIZATION_VERSION,
} from "../../../../src/modules/assessment/domain/normalize-short-text.js";

describe("normalizeShortText", () => {
  it("uses the reviewed versioned rule", () => {
    expect(SHORT_TEXT_NORMALIZATION_VERSION).toBe(
      "nfkc_ascii_ws_ascii_lower_v1",
    );
  });

  it.each(SHORT_TEXT_NORMALIZATION_GOLDEN_VECTORS)(
    "normalizes %#",
    ({ input, output }) => {
      expect(normalizeShortText(input)).toBe(output);
    },
  );
});
