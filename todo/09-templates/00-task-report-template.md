# Task report template

Copy this into the future implementation-report directory.

```md
# <TASK-ID> — <title>

Outcome: COMPLETE | BLOCKED | FAILED
Environment: NONE | LOCAL | DEVELOPMENT | STAGING | PRODUCTION
Date:
Agent/person:
Authorization checked:
Prerequisites/gate checked:
Decisions/defaults used:

## Scope

- Intended:
- Explicitly excluded:

## Changed

- <file/resource>: <purpose>

## Verification

- Command/check:
  - Result: PASS | FAIL
  - Non-secret evidence:

## External actions

- NONE, or exact Chrome/Dashboard/deployment action with non-secret
  project/environment metadata and approval.

## Deviations/ADRs

- NONE, or IDs and consequences.

## Risks/blockers

- NONE, or:
  - exact issue;
  - why it blocks;
  - smallest required user/external action;
  - safe state/rollback.

## Secret-safety confirmation

- No credential, token, connection string, private data, protected answer,
  TOTP/QR/`otpauth`/factor/challenge material, or unsafe screenshot/log was
  recorded.

## Next

- Exactly one unblocked task ID and why it is eligible.
```
