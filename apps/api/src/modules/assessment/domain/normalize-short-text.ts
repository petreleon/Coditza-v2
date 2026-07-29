/**
 * Mirrors PostgreSQL private.normalize_short_text exactly. It is deliberately
 * assessment-owned because it is part of scalar exercise and quiz grading,
 * rather than a generic text utility.
 */
export const SHORT_TEXT_NORMALIZATION_VERSION =
  "nfkc_ascii_ws_ascii_lower_v1" as const;

function isAsciiGradingWhitespace(character: string): boolean {
  const codePoint = character.codePointAt(0);

  return (
    codePoint === 0x20 ||
    (codePoint !== undefined && codePoint >= 0x09 && codePoint <= 0x0d)
  );
}

function lowercaseAscii(character: string): string {
  const codePoint = character.codePointAt(0);

  if (codePoint !== undefined && codePoint >= 0x41 && codePoint <= 0x5a) {
    return String.fromCodePoint(codePoint + 0x20);
  }

  return character;
}

/**
 * Applies NFKC, collapses only ASCII tab-through-carriage-return plus space,
 * trims ASCII space, then lowercases ASCII letters only. Do not replace this
 * with locale-sensitive lowercasing: non-ASCII case distinctions are part of
 * the persisted grading contract.
 */
export function normalizeShortText(input: string): string {
  const characters: string[] = [];
  let appendSpaceBeforeNextCharacter = false;

  for (const character of input.normalize("NFKC")) {
    if (isAsciiGradingWhitespace(character)) {
      appendSpaceBeforeNextCharacter = characters.length > 0;
      continue;
    }

    if (appendSpaceBeforeNextCharacter) {
      characters.push(" ");
      appendSpaceBeforeNextCharacter = false;
    }
    characters.push(lowercaseAscii(character));
  }

  return characters.join("");
}
