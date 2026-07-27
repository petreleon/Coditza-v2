# Coditza architecture ownership inventory

Status: accepted by ARC-DESIGN-001 on 2026-07-27.

This is the single-owner inventory for every currently planned durable table,
server-only RPC facade, HTTP route, recurring job, and permitted executable.
It is a design contract, not a request to create schema or application code.
An artifact not listed here is denied by default. A future task must amend this
inventory and its owning ADR before it creates a new durable artifact.

The words public SQL schema, public HTTP route, and public.ts source contract
describe separate boundaries. A public-schema RPC is still server-only when its
execute grants are denied to PUBLIC, anon, and authenticated.

## Ownership rules

1. Exactly one business context owns every listed business artifact.
2. A route is an inbound adapter of its owner; admin, authoring, and catalog
   are route groups, never owners.
3. A server-only RPC has one coordinator context. Collaborators are private SQL
   helpers in that same transaction, not foreign application adapters.
4. A table may be read by another context only through the named public
   contract or a named coordinator's private SQL helper. No context receives a
   direct foreign-table privilege.
5. Supabase Auth remains an external provider boundary. It is not made a
   Coditza context by this inventory.

## Context ownership summary

| Context | Sole responsibility |
| --- | --- |
| identity | Coditza profile, role, security-hold, and system identity workflows. |
| curriculum | Module, chapter, theory content, its lifecycle, and learner catalog. |
| assessment | Exercise and quiz definitions, protected keys, attempts, grading, Python queue, and expiry. |
| progress | Theory completion, derived chapter/module progress, and reconciliation. |
| operations | Audit projection, idempotency retention, and explicitly approved maintenance scheduling. |
| platform database kernel | Non-business shared database primitives and readiness only. |
| platform health | Liveness/readiness HTTP adapters only. |

## Durable data ownership

### External/provider data

| Artifact | Owner | Coditza rule |
| --- | --- | --- |
| Supabase Auth users, passwords, sessions, refresh tokens, factor records, TOTP secrets/codes, QR/otpauth data, and issued tokens | Supabase Auth, not Coditza | Fastify validates only the issued access token; no Coditza module writes, copies, logs, or accepts this material. |
| Auth user identifier referenced by Coditza rows | Supabase Auth, not Coditza | Identity may reference the UUID but does not own account credentials or factor state. |

### Coditza physical tables and protected data

| Artifact | Sole owner | Allowed collaborators and boundary |
| --- | --- | --- |
| public.profiles | identity | Identity reads/writes through identity facades. Other coordinators may recheck role only through identity-owned private helper. |
| public.modules | curriculum | Assessment and progress may consume effective-publication information only through curriculum's approved contract or private helper. |
| public.chapters | curriculum | Same boundary as public.modules. |
| public.theory_sections | curriculum | Progress may coordinate theory completion only after curriculum publication checks. |
| public.exercises | assessment | Curriculum may use an assessment private publication validator inside an approved curriculum publication transaction; it may not import assessment adapters. |
| public.exercise_options | assessment | Never exposed as a correctness association. |
| private.exercise_answer_keys | assessment | Only named assessment server-only facades may access it; no direct user, route, or catalog access. |
| public.quizzes | assessment | Same ownership and publication rule as public.exercises. |
| public.quiz_questions | assessment | Retained immutable definition rows support attempts; never expose a private answer association. |
| public.quiz_question_options | assessment | Same boundary as public.exercise_options. |
| private.quiz_question_answer_keys | assessment | Only named assessment server-only facades may access it. |
| public.exercise_attempts | assessment | Assessment owns immutable attempt insert/read and invokes progress recalculation as a private collaborator. |
| public.quiz_attempts | assessment | Assessment owns start, save, submit, expiry, and terminal replay. |
| public.quiz_attempt_answers | assessment | Assessment owns it as a child of public.quiz_attempts. |
| private.python_exercise_definitions | assessment | Protected runtime/private-test definition. Learner/catalog projections receive only an explicit safe subset. |
| private.python_grading_jobs | assessment | The private grader-controller uses only an assessment queue adapter/facade; Fastify does not claim or finalize jobs. |
| private.python_exercise_attempt_evidence | assessment | Reserved physical relation name for the one-to-one private digest/verdict/runner evidence of a Python exercise attempt. SUP-WASM-001 owns its exact columns, grants, retention, and migration. |
| Selected protected storage object for learner Python source | assessment | The storage product/bucket choice remains deferred to the selected Supabase boundary. It is not a new business owner, and source never enters audit/idempotency/log rows. |
| public.theory_section_completions | progress | Progress owns completion transition; curriculum validates effective publication inside its coordinator path. |
| public.chapter_progress | progress | Recalculable snapshot. Module progress is derived; no module-progress cache table is authorized. |
| private.idempotency_records | operations | Operations owns retention and private helpers. A coordinator supplies fixed operation and canonical request facts; no generic user-visible idempotency API exists. |
| private.audit_events | operations | Operations owns append/projection mechanics. Other module coordinators provide sanitized events only through the operations private helper. |

No other Coditza table, materialized view, cache table, database, message store,
or storage copy is authorized by ARC-DESIGN-001.

### Shared non-business database primitives

| Artifact | Sole owner | Limitation |
| --- | --- | --- |
| Shared enums and common timestamp convention | platform database kernel | Types and generic timestamp mechanics only; no product workflow. |
| private.set_updated_at | platform database kernel | Trigger helper only. |
| private.normalize_short_text | assessment | Exact shared grading/authoring normalization; it is not a generic text service. |
| private.has_role and private.is_staff | identity | Role reads only; no caller receives a direct profiles-table privilege. |
| Effective-publication helpers | curriculum for module/chapter/theory; assessment for exercise/quiz | Each helper is private, schema-qualified, and static. |
| private.validate_exercise_definition and private.validate_quiz_definition | assessment | Protected definition validation only. |
| private.recalculate_chapter_progress | progress | Private collaborator called by named coordinators under the documented transaction lock order. |

## Server-only RPC facade ownership

The function names below are the public-schema facade names to implement. They
replace the earlier logical generic names. A facade has explicit server-only
grants and must not accept an arbitrary resource type, SQL identifier, actor,
score, or private result from a client.

### Identity

| Facade | Owner | Invocation |
| --- | --- | --- |
| identity_update_own_profile | identity | Fastify identity adapter with verified actor. |
| identity_change_user_role | identity | Fastify admin adapter with verified actor. |
| identity_bootstrap_first_admin | identity | Isolated first-admin executable only; system context. |
| identity_set_security_hold | identity | Isolated recovery operator only; no HTTP route. |

### Curriculum lifecycle

| Facade family | Owner | Replaces logical generic operation |
| --- | --- | --- |
| curriculum_create_draft_module | curriculum | create_draft_content for module |
| curriculum_create_draft_chapter | curriculum | create_draft_content for chapter |
| curriculum_create_draft_theory_section | curriculum | create_draft_content for theory_section |
| curriculum_update_draft_module | curriculum | update_draft_content for module |
| curriculum_update_draft_chapter | curriculum | update_draft_content for chapter |
| curriculum_update_draft_theory_section | curriculum | update_draft_content for theory_section |
| curriculum_correct_published_module | curriculum | correct_published_content for module |
| curriculum_correct_published_chapter | curriculum | correct_published_content for chapter |
| curriculum_correct_published_theory_section | curriculum | correct_published_content for theory_section |
| curriculum_publish_module, curriculum_publish_chapter, curriculum_publish_theory_section | curriculum | publish_content split by owned resource |
| curriculum_archive_module, curriculum_archive_chapter, curriculum_archive_theory_section | curriculum | archive_content split by owned resource |
| curriculum_reorder_modules, curriculum_reorder_chapters, curriculum_reorder_theory_sections | curriculum | reorder_content split by sibling scope |

### Assessment authoring, lifecycle, and learner workflows

| Facade family | Owner | Replaces logical generic operation |
| --- | --- | --- |
| assessment_create_draft_exercise, assessment_create_draft_quiz | assessment | create_draft_content for assessment roots |
| assessment_update_draft_exercise, assessment_update_draft_quiz | assessment | update_draft_content for assessment roots |
| assessment_replace_draft_quiz_definition | assessment | replace_draft_quiz_definition |
| assessment_get_draft_exercise_authoring, assessment_get_draft_quiz_authoring | assessment | get_draft_assessment_authoring split by type |
| assessment_publish_exercise, assessment_publish_quiz | assessment | publish_content split by owned resource |
| assessment_archive_exercise, assessment_archive_quiz | assessment | archive_content split by owned resource |
| assessment_reorder_exercises, assessment_reorder_quizzes | assessment | reorder_content split by sibling scope |
| assessment_clone_exercise, assessment_clone_quiz | assessment | clone_assessment split by type |
| assessment_replace_published_exercise, assessment_replace_published_quiz | assessment | replace_published_assessment split by type |
| assessment_submit_exercise_attempt | assessment | submit_exercise_attempt |
| assessment_list_own_exercise_attempts, assessment_get_own_exercise_attempt | assessment | exercise attempt history projections |
| assessment_start_quiz_attempt | assessment | start_quiz_attempt |
| assessment_save_quiz_answer, assessment_remove_quiz_answer, assessment_submit_quiz_attempt | assessment | quiz mutation operations |
| assessment_list_own_quiz_attempts, assessment_get_own_quiz_attempt | assessment | quiz attempt history projections |
| assessment_finalize_expired_quiz_attempts | assessment | scheduled expiry finalization |
| assessment_reserve_python_grading_job | assessment | Python reservation from a Fastify adapter |
| assessment_claim_python_grading_jobs | assessment | private grader-controller only |
| assessment_finalize_python_grading_job | assessment | private grader-controller only |

### Progress, operations, and platform

| Facade | Owner | Invocation |
| --- | --- | --- |
| progress_set_theory_completion | progress | Fastify progress adapter with verified owner actor. |
| progress_list_own_modules | progress | Fastify progress adapter with verified owner actor. |
| progress_get_own_module | progress | Fastify progress adapter with verified owner actor. |
| progress_reconcile_chapter | progress | Fastify admin adapter with verified admin actor. |
| operations_list_audit_events | operations | Fastify admin adapter with verified admin actor. |
| operations_purge_expired_idempotency | operations | Bounded scheduled system job only. |
| server_readiness | platform database kernel | Platform readiness adapter only. |

The following public generic facade names are prohibited: create_draft_content,
update_draft_content, correct_published_content, publish_content,
archive_content, reorder_content, clone_assessment, and
replace_published_assessment. They remain historical logical operation labels
in the planning documents, not runtime entrypoints. Private static helpers may
share code only within the owning coordinator and cannot be executed directly.

## HTTP route ownership

Every listed domain route requires the established AAL2 boundary unless it is a
health route. There are no Fastify signup, password, login, TOTP, factor,
logout, or recovery routes; these remain direct Supabase Auth client
operations or an isolated identity operator.

| Owner | Exact route family |
| --- | --- |
| platform health | GET /health/live; GET /health/ready |
| identity | GET /api/v1/me; PATCH /api/v1/me; PUT /api/v1/admin/users/:userId/role |
| curriculum learner catalog | GET /api/v1/modules; GET /api/v1/modules/:moduleId; GET /api/v1/modules/:moduleId/chapters; GET /api/v1/chapters/:chapterId |
| curriculum learner theory | GET /api/v1/chapters/:chapterId/theory; GET /api/v1/theory-sections/:sectionId |
| assessment learner definition | GET /api/v1/chapters/:chapterId/exercises; GET /api/v1/exercises/:exerciseId; GET /api/v1/chapters/:chapterId/quizzes; GET /api/v1/quizzes/:quizId |
| assessment exercise attempts | POST /api/v1/exercises/:exerciseId/attempts; GET /api/v1/me/exercise-attempts; GET /api/v1/me/exercise-attempts/:attemptId |
| assessment quiz attempts | POST /api/v1/quizzes/:quizId/attempts; GET /api/v1/me/quiz-attempts; GET /api/v1/me/quiz-attempts/:attemptId; PUT /api/v1/me/quiz-attempts/:attemptId/answers/:questionId; DELETE /api/v1/me/quiz-attempts/:attemptId/answers/:questionId; POST /api/v1/me/quiz-attempts/:attemptId/submit |
| assessment Python | POST /api/v1/exercises/:exerciseId/python-grading-requests; GET /api/v1/me/python-grading-requests/:requestId |
| progress | PUT /api/v1/me/theory-sections/:sectionId/completion; DELETE /api/v1/me/theory-sections/:sectionId/completion; GET /api/v1/me/progress; GET /api/v1/me/progress/modules/:moduleId; POST /api/v1/admin/progress/reconcile |
| curriculum administration | GET, POST /api/v1/admin/modules; GET, PATCH /api/v1/admin/modules/:id; POST /api/v1/admin/modules/:id/publish; POST /api/v1/admin/modules/:id/archive; PUT /api/v1/admin/modules/order; GET /api/v1/admin/chapters; GET, PATCH /api/v1/admin/chapters/:id; POST /api/v1/admin/modules/:moduleId/chapters; POST /api/v1/admin/chapters/:id/publish; POST /api/v1/admin/chapters/:id/archive; PUT /api/v1/admin/modules/:moduleId/chapters/order; GET /api/v1/admin/theory-sections; GET, PATCH /api/v1/admin/theory-sections/:id; POST /api/v1/admin/chapters/:chapterId/theory-sections; POST /api/v1/admin/theory-sections/:id/publish; POST /api/v1/admin/theory-sections/:id/archive; PUT /api/v1/admin/chapters/:chapterId/theory-sections/order |
| assessment administration | GET /api/v1/admin/exercises; GET, PATCH /api/v1/admin/exercises/:id; POST /api/v1/admin/chapters/:chapterId/exercises; POST /api/v1/admin/exercises/:id/publish; POST /api/v1/admin/exercises/:id/archive; POST /api/v1/admin/exercises/:id/clone; POST /api/v1/admin/exercises/:oldId/replace; GET /api/v1/admin/exercises/:id/authoring; PUT /api/v1/admin/chapters/:chapterId/exercises/order; GET /api/v1/admin/quizzes; GET, PATCH /api/v1/admin/quizzes/:id; POST /api/v1/admin/chapters/:chapterId/quizzes; POST /api/v1/admin/quizzes/:id/publish; POST /api/v1/admin/quizzes/:id/archive; POST /api/v1/admin/quizzes/:id/clone; POST /api/v1/admin/quizzes/:oldId/replace; GET /api/v1/admin/quizzes/:id/authoring; PUT /api/v1/admin/quizzes/:quizId/definition; PUT /api/v1/admin/chapters/:chapterId/quizzes/order |
| operations | GET /api/v1/admin/audit-events |

## Jobs and isolated executables

| Artifact | Sole semantic owner | Invocation and hard boundary |
| --- | --- | --- |
| Python grader-controller claim/run/finalize loop | assessment | Private process from the reviewed release. No public listener; no Auth/TOTP or raw-client escape. |
| Expired quiz finalization | assessment | Scheduled invocation of assessment_finalize_expired_quiz_attempts. Operations may schedule it but cannot change its business behavior. |
| Idempotency purge | operations | Bounded scheduled invocation of operations_purge_expired_idempotency. |
| Supabase migration/reset/seed/type-generation commands | platform database kernel | Supabase CLI/developer or CI commands; never imported by Fastify. |
| First-admin bootstrap | identity | Isolated executable with exact environment/project/user/reason confirmation; never an HTTP route. |
| Identity recovery hold | identity | Isolated staged begin, prepare-enrollment, status, and complete executable; never imported by Fastify. |
| Explicit maintenance command | operations | Compile-time allowlist of approved jobs only, with environment/project confirmation. |

No automatic progress repair, audit retention/anonymization, backup/restore
automation, generic command runner, or generic worker queue is authorized yet.
Those require their own approved task, privacy/recovery contract, and inventory
entry.

## Cross-context coordinator map

| Durable workflow | Coordinator / public facade owner | Permitted private collaborators |
| --- | --- | --- |
| Module, chapter, theory draft create/update/correct/reorder/publish/archive | curriculum | assessment publication validator where a chapter/module publish needs assessment completeness; progress recalculation; operations audit/idempotency. |
| Exercise/quiz draft update, definition replacement, publish/archive/reorder/clone/replace | assessment | curriculum ancestor/effective-publication helper; progress recalculation; operations audit/idempotency. |
| Exercise submission, quiz start/save/remove/submit/expiry | assessment | curriculum effective-publication helper; progress recalculation; operations idempotency. |
| Python reserve/claim/sandbox/finalize/retry | assessment | curriculum effective-publication helper; progress recalculation; safe operations metrics. The sandbox gets no module capability. |
| Theory completion, progress reads, progress reconciliation | progress | curriculum published read contract; assessment safe source read contract; operations audit for reconciliation. |
| Profile edit, role change, first-admin bootstrap, security hold | identity | operations audit helper only. |
| Idempotency retention purge | operations | None. |
| Platform readiness | platform health | Bounded platform database adapter only. |

The coordinator is the only application use case that initiates a named
cross-context write. It may not import a second context's Supabase adapter.
A named public facade owns the transaction. A private collaborator never
creates a second independently callable lifecycle path.
