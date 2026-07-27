# Performance and future-client contract

## Performance tasks

### QA-PERF-001 — Establish pre-production baselines

- [ ] Use large synthetic content/attempt fixtures.
- [ ] Measure p50/p95/p99 for module list, chapter content, attempt start/submit,
      and progress.
- [ ] Record API, Supabase, fixture size, concurrency, image revision, and
      environment with results.
- [ ] Confirm bounded DB query count; no route performs one query per child item.
- [ ] Test Supabase slow/unavailable behavior, readiness, timeout, and recovery.
- [ ] Test rate limiting and payload rejection without resource exhaustion.
- [ ] Set alert/SLO thresholds only after DEC-020 review.

Do not claim production capacity from laptop measurements. Treat baselines as
regression evidence.

## API/client accessibility contract

No client is implemented, but the backend must not make an accessible client
impossible.

- Markdown must preserve semantic headings, lists, code, quotations, and links.
- Initial content has the known language `ro-RO`; code identifiers remain
  English. Add per-content language only when localization enters scope.
- If media later enters scope, require meaningful alternative text plus
  captions/transcripts before publication.
- Errors expose stable codes and safe field paths so a client can associate
  messages with controls.
- Question DTOs expose labels/instructions and stable grouping without relying
  on color, position alone, or auto-advance.
- Timer fields are explicit and nullable. A future accommodations design is
  required before timed quizzes are used for high-stakes assessment.
- Recoverable save errors must allow a future client to preserve learner input.
- Empty, loading, retry, unauthorized, expired-session, and expired-attempt
  states are documented in OpenAPI examples/consumer notes.
- The future client must implement the exact signed-out, confirmation,
  enrollment, challenge, authenticated and stale-factor states in
  PRD-AUTH-001. A session alone is not treated as Coditza access.
- The future client renders the Supabase-provided enrollment QR/manual secret
  transiently, supports verified-factor selection and safe 429 retry, and never
  persists or reports Authenticator material.
- Future client target is WCAG 2.2 AA, but no frontend technology is selected
  here.

## QA-CLIENT-001 — Contract review

- [ ] OpenAPI examples cover empty/error/retry/expiry states.
- [ ] Error field paths are stable.
- [ ] Content/assessment DTOs contain enough semantic labels/instructions.
- [ ] No required interaction depends on hover, color, or automatic time alone.
- [ ] Accessibility decisions are revisited if media/math/timing expands.
- [ ] Registration/login consumer notes explain `mfa_required`, `aal2` handoff,
      factor selection, cancellation/resume and recovery limitation without
      pretending this backend ships user-facing screens.
