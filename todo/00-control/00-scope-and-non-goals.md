# Scope and non-goals

## Product objective

Build a reliable API for a structured learning product named **Coditza**.
Authenticated learners browse published modules and chapters, read theory,
submit exercises and quizzes, and see their progress. Editors create and
publish content. Administrators can additionally manage staff roles and
environment-level operations.

## MVP scope

- Supabase Auth with email/password as the first factor, mandatory
  Authenticator-app TOTP as the second factor, and an automatically created
  learner profile.
- Roles: `learner`, `editor`, and `admin`.
- Ordered modules and chapters.
- Ordered theory sections, exercises, and quizzes within each chapter.
- Deterministically graded question types:
  `single_choice`, `multiple_choice`, and `short_text`.
- Deterministically graded `python_code` exercises using a pinned
  Python-on-WebAssembly runtime. A hardened server-side sandbox is
  authoritative; any future browser Web Worker run is provisional only.
- Exercise attempts, timed or untimed quiz attempts, and chapter/module
  progress.
- Draft, published, and archived content lifecycle.
- Versioned SQL migrations, seed data, generated database types, and RLS tests.
- Fastify REST API under `/api/v1`, with OpenAPI output.
- Docker images and a Docker Compose development workflow for the API plus the
  private grader-controller/isolation test path after ARC-WASM-001.
- Local Supabase through the official CLI and Docker runtime.
- Separate development and production configuration; add a separately billed
  staging environment only when DEC-027 explicitly approves it.
- Logs, health checks, CI gates, backup verification, and release checklist.

## Explicit non-goals for the MVP

- A web, mobile, or desktop frontend.
- An editor/admin graphical interface.
- Payments, subscriptions, organizations, classrooms, teachers, invitations,
  certificates, streaks, badges, comments, chat, notifications, or social
  features.
- AI grading, fuzzy grading, essay/manual grading, non-Python executable
  exercises, arbitrary package installation, or unrestricted code execution.
- Rich collaborative editing or real-time presence.
- SCORM, LTI, xAPI, external LMS integration, or content import/export.
- Multi-language UI/content localization beyond storing Unicode text.
- Offline synchronization.
- A custom identity/password system inside Fastify.
- Using Python/WASM to register, log in, verify tokens, validate Authenticator
  codes, or replace any Supabase Auth/TOTP responsibility.
- Proxying passwords, TOTP codes, QR codes, or Auth refresh tokens through
  Fastify.
- Self-hosting the full Supabase platform with a hand-maintained Compose file.
- Production deployment before the selected hosted pre-production environment
  passes G7 and the user explicitly approves the exact production action.

## Execution restriction

- Product/backend plan changes live under `todo/`; Romanian curriculum plan
  changes live under `todo-curriculum-ro/`.
- The sole active task defines the permitted implementation scope. G0 and
  PLAN-004 have passed; ARC-TREE-002 may create only the first
  implementation-report location and report, not application or infrastructure
  artifacts.
- A hosted, production, billing-sensitive, destructive, or secret-dependent
  action still needs its own task-specific authority; broad implementation
  authorization does not authorize it.
- Do not choose a frontend framework.
- Commands in planning files are future verification instructions until their
  owning task is active.

## Scope-change rule

Any request outside the MVP must be recorded as an ADR. The ADR must describe:

1. the requested behavior;
2. why the current scope cannot satisfy it;
3. schema/API/security consequences;
4. migration and rollback impact;
5. added tests;
6. whether the roadmap or phase gates change.

Do not opportunistically implement out-of-scope features while doing another
task.
