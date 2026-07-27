# ARC-TREE-001 — Create the root workspace

Outcome: COMPLETE
Environment: LOCAL
Date: 2026-07-27
Agent/person: Codex
Authorization checked: Implementation is authorized. This task makes only local
workspace metadata and does not change external state.
Prerequisites/gate checked: ARC-TREE-002 is complete; ARC-TREE-001 was the sole
`next` task; the working tree was clean and no root `package.json` existed.
Decisions/defaults used:

- Product display name remains `Coditza`; npm package name is lowercase
  `coditza`, consistent with current npm package-name rules.
- The root is private, uses ESM, and declares only the `apps/*` workspace.
- No `version`, dependencies, scripts, lockfile, runtime/tooling choice,
  `apps/api`, or generated root configuration is created in this task.

## Scope

- Intended: add the smallest valid npm-workspace root metadata.
- Explicitly excluded: package installation, version selection, scripts,
  TypeScript/Fastify/Node tooling, source files, Docker, Supabase, Chrome,
  Vercel, SMTP, credentials, and external state.

## Changed

- `package.json`: private ESM workspace metadata only.
- `docs/implementation/ARC-TREE-001.md`: task report.
- `todo/02-architecture/01-target-project-structure.md`: completed root-tree
  metadata actions and documented the lowercase technical name.
- `todo/TASKS.md`, `todo/STATUS.md`, `todo/NEXT.md`, `todo/README.md`,
  `todo/00-control/00-scope-and-non-goals.md`, and
  `todo/08-execution/00-roadmap.md`: synchronized task state.

## Verification

- `npm --version`
  - Result: PASS (11.12.1)
  - Non-secret evidence: local npm is available for metadata validation.
- `npm pkg get name private type workspaces`
  - Result: PASS
  - Non-secret evidence: reports only `coditza`, `true`, `module`, and
    `apps/*` workspace metadata.
- JSON shape assertion plus absence checks for `package-lock.json` and `apps/`
  - Result: PASS
  - Non-secret evidence: no version, dependencies, scripts, lockfile, or
    application directory was introduced.
- `git diff --check`
  - Result: PASS
  - Non-secret evidence: no whitespace error in the task change.

## External actions

- NONE.

## Deviations/ADRs

- The plan's human-facing `Coditza` package-name wording is implemented as
  lowercase `coditza` because current npm package-name rules prohibit uppercase
  letters. The product and repository display names remain unchanged.

## Risks/blockers

- NONE for this task. Version and dependency selection remain deliberately
  deferred to FOUND-001.

## Secret-safety confirmation

- No credential, token, connection string, private data, protected answer,
  TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
  recorded.

## Next

- `ARC-DESIGN-001` is the only unblocked next task because the root workspace
  exists and it owns the required architecture ADR and ownership contracts.
