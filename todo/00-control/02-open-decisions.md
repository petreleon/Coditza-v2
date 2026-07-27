# Open decisions and safe defaults

An implementation agent must not invent product behavior. Until the user changes
a row below, use its safe default. A decision becomes blocking only at the named
deadline.

| ID | Question | Safe default | Decision deadline |
| --- | --- | --- | --- |
| DEC-001 | Who is the initial audience? | General adult learners; no child-specific data collection | Before production privacy review |
| DEC-002 | Which content language? | Resolved: Romanian (`ro-RO`) learner content with English code identifiers; no localization layer yet | Resolved by user on 2026-07-27 |
| DEC-003 | Is the catalog public? | Require an authenticated user for all Coditza domain endpoints | Before API contract freeze |
| DEC-004 | Which first-factor sign-in method? | Resolved: email and password only; require confirmed email outside local development | Resolved by user on 2026-07-27 |
| DEC-005 | May anyone sign up? | Allow learner self-sign-up; staff roles require an admin action | Before hosted Auth setup |
| DEC-006 | Which frontend? | None in this repository phase; only publish an OpenAPI contract | Before any client task |
| DEC-007 | Which deployment topology hosts the API and private grader? | The user requires Vercel for the public API release. OPS-VERCEL-001 must verify current Vercel capability and record whether a separately approved private grader/sandbox host is required; never silently choose one | Topology before ARC-WASM-001; exact service, region, tier, cost, and owner at OPS-HOST-001 |
| DEC-008 | Are uploaded media needed? | No; Markdown text only | Before authoring real media |
| DEC-009 | How many quiz attempts? | Quiz field is nullable; `null` means unlimited | Before real quizzes are published |
| DEC-010 | When is feedback revealed? | Return correctness and authored feedback after submission, never the raw key | Before attempt endpoints |
| DEC-011 | How is short text graded? | Apply Unicode NFKC, collapse only ASCII whitespace, trim, map ASCII `A-Z` to `a-z`, then exact-match; non-ASCII letters remain case-sensitive | Before grading service |
| DEC-012 | What passes an exercise? | Full points only; no partial credit in the MVP | Before grading service |
| DEC-013 | What completes a chapter? | All published theory sections complete, every required exercise correct once, and every required quiz passed | Before progress service |
| DEC-014 | How is overall progress weighted? | Equal thirds for theory/exercises/quizzes; empty non-required groups count complete | Before progress service |
| DEC-015 | Quiz time expiration behavior? | Finalize saved answers once at/after expiry when submit/new-start encounters the attempt or the bounded maintenance job selects it | Before quiz attempt service |
| DEC-016 | Can published assessment content change? | No after publication, even before an attempt; clone and archive instead | Before admin publishing |
| DEC-017 | What deletion policy applies to users? | Delete profile and learner-owned records after confirmed account deletion; keep aggregate metrics only if anonymized | Before production |
| DEC-018 | What Supabase region/tier? | Choose in Chrome based on expected users, residency, and cost; require user confirmation | Before creating each hosted project |
| DEC-019 | What recovery objective is required? | Target RPO <= 24 hours and RTO <= 4 hours; select a Supabase tier only after cost approval | Before production project/tier approval |
| DEC-020 | What service objectives apply? | Establish selected pre-production baselines first; no contractual uptime/latency promise in MVP | Before production monitoring sign-off |
| DEC-021 | Can new required content reopen completion? | Yes; clear current `completedAt`, preserve `firstCompletedAt`, and show the new denominator | Before progress service |
| DEC-022 | Does starting a quiz consume an attempt? | Yes, including an attempt that later expires; this prevents unlimited previewing | Before quiz attempt service |
| DEC-023 | How long are operational records retained? | Idempotency 24 hours, application logs 30 days, audit events 365 days; shorten or anonymize where privacy requires | Before production |
| DEC-024 | Which source host, CI provider, and OCI registry? | Reuse a user-confirmed existing repository provider where possible; otherwise stop before provider-specific CI or image publication | At OPS-SOURCE-001; before OPS-CI-001 or registry publication |
| DEC-025 | What are the exact client Site URL and Auth redirect origins? | No invented origin and no self-service email flow; use explicitly created synthetic test users for API-only preview | Before hosted Auth can be signed off |
| DEC-026 | How is production Auth email delivered and owned? | Production self-service signup remains disabled until an approved SMTP/email provider, sender domain, owner, and delivery test exist. The local Gmail App Password path proves only local delivery and does not select production email | Before production self-service signup |
| DEC-027 | Is a separately billed staging environment required? | Do not create it; use isolated synthetic data in development as pre-production unless the user approves staging cost/ownership | Before SUP-CHROME-STAGING-001 |
| DEC-028 | Is Authenticator-app MFA mandatory? | Resolved: yes, TOTP is mandatory for registration completion and every later login; all Coditza roles require `aal2` | Resolved by user on 2026-07-27 |
| DEC-029 | How is access recovered when every TOTP factor is lost? | No self-service/public factor reset and no invented recovery codes; encourage a second factor. Any operator recovery must set the Coditza hold first; revoke sessions/delete factors; quarantine for the configured maximum access-token lifetime plus skew; revoke/delete again; require fresh verified TOTP; and clear the hold last. Production remains blocked until identity-proof, first-factor-compromise handling, audit, notification and operator-approval details are accepted | Before production self-service signup |
| DEC-030 | How many TOTP factors and how are they replaced? | Allow at most two verified factors (primary plus backup); verify a replacement before removing the old factor and do not offer removal of the final factor | Before SUP-MFA-001 |
| DEC-031 | When is a new TOTP code required? | Once for every new Supabase sign-in session; ordinary refresh of the same `aal2` session does not re-prompt. Target an access-token lifetime of at most 15 minutes if supported, and record the bounded stale-token window | Before hosted Auth setup |
| DEC-032 | Which outer sandbox launcher will isolate authoritative Python/WASM locally and on the selected host? | Do not fall back to a Node worker thread, Node WASI, an API-mounted Docker socket, or an in-process runner. ARC-WASM-001 must select and prove a disposable no-network/secret-free/read-only/non-root/resource-limited container, microVM, or equivalent narrow launcher; block Python exercise publication/deployment if none is available | Before ARC-WASM-001 |

## Decision procedure

- [ ] The active task identifies every decision it depends on.
- [ ] If the deadline has not arrived, use the documented safe default.
- [ ] If the deadline has arrived and the default is unacceptable or unsafe,
      stop and ask the user one concise question.
- [ ] Record a confirmed change in an ADR and update the affected task files.
- [ ] Never change a database or API contract merely because a UI might need it.

## Decisions deliberately postponed

The following do not block local backend MVP work: frontend framework, frontend
hosting, custom domain, social sign-in, media storage, and analytics vendor.
The API hosting provider, client origins, production email delivery,
source/CI/registry, and a separately billed staging environment become blocking
only at the exact deadlines above.
