# Local Supabase Auth SMTP delivery

## Scope

The user requested local SMTP delivery through a personal Gmail account. This
requirement belongs to Supabase Auth because a client communicates directly
with Supabase Auth for signup, confirmation, password login, TOTP enrollment,
challenge, verification, refresh, and logout. Fastify never receives a
password, TOTP code, or Auth email credential.

The local Supabase CLI stack runs in Docker, but root `compose.yaml` owns only
the API and later private grading test wiring. It must not gain an Auth, SMTP,
or Gmail sidecar. The local CLI/Auth configuration method is rechecked against
the pinned current Supabase CLI documentation at task time.

## Secret and transport rules

- The Gmail address, account password, Gmail App Password, recipient address,
  message body, confirmation URL, OTP, token, and Auth response are secrets or
  private data and never enter source, reports, screenshots, shell history,
  Docker image layers, Compose files, logs, fixtures, or chat.
- Use a Gmail **App Password**, not the ordinary account password. If it is
  unavailable, invalid, or cannot be entered directly into approved ignored
  local secret storage, stop the task without weakening local Auth settings.
- Use the current documented Gmail SMTP endpoint, port, TLS mode, sender, and
  CLI/Auth variable names only after rechecking official documentation. Do not
  invent names or commit a secret-bearing `config.toml` edit.
- Store only non-secret, reviewed local configuration in version control. Load
  secret values at runtime from an ignored local secret file or user-controlled
  prompt/storage supported by the current CLI. Verify ignore rules before
  starting the stack.
- The test proves only local delivery to a user-controlled mailbox. It does not
  configure hosted Supabase, Vercel, a production sender domain, production
  self-signup, or DEC-026.

## SUP-SMTP-LOCAL-001 — Configure and prove local Auth SMTP delivery

Prerequisites: SUP-LOCAL-001, SUP-LOCAL-002, and PRD-AUTH-001 are complete;
the user provides a Gmail App Password directly to the approved ignored local
secret mechanism when this task is active.

- [ ] Inspect the pinned local Supabase CLI/Auth configuration and current
      official documentation to identify the supported local SMTP mechanism;
      record names and modes but never secret values.
- [ ] Confirm `.gitignore`, `.dockerignore`, and the selected local secret path
      exclude Gmail credentials, message artifacts, local CLI state, and test
      output from Git and API image build context.
- [ ] Configure only the CLI-owned local Auth process using runtime secret
      injection. Do not modify root `compose.yaml`, API runtime configuration,
      hosted project settings, or migration files for SMTP transport.
- [ ] Start the local CLI stack and trigger one approved synthetic Auth email
      flow to a user-controlled mailbox. The user handles mailbox access and
      any confirmation interaction; no URL, code, token, or message content is
      captured.
- [ ] Prove only a sanitized delivery outcome and the local-only target
      boundary. Redact/scan CLI/API/container output and tracked files for
      credential names with values, message bodies, confirmation links, and
      Auth secrets.
- [ ] Stop or restore the local stack without deleting unrelated local state.
      If credential configuration fails, remove only the task-created ignored
      local secret material through a user-approved recoverable method and
      leave versioned configuration safe.

Evidence is a sanitized local configuration/delivery/redaction report, exact
non-secret CLI version and configuration names, ignore-rule proof, and a proof
that root Compose and hosted projects were unchanged.
