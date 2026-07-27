# Identity and catalog endpoints

Every route below requires a cryptographically verified `aal2` principal.
Password-only `aal1` returns `403 mfa_required` before profile or curriculum
ports are called.

## Profile

### `GET /api/v1/me`

Returns only:

```text
id, displayName, role, createdAt, updatedAt
```

### `PATCH /api/v1/me`

- body: `{ displayName }` and no other fields;
- trims and validates 1–80 characters;
- cannot update ID, role, email, Auth metadata, or timestamps;
- returns the updated profile.

## Modules

### `GET /api/v1/modules`

- query: `limit`, `cursor`;
- only effectively published modules;
- returns `id`, `slug`, `title`, `descriptionMarkdown`, and `position`;
- progress fields are omitted until API-PROGRESS-001 is complete; after that
  task they may be included only using the exact progress DTO;
- stable cursor order.

### `GET /api/v1/modules/:moduleId`

- UUID param;
- learner sees published module only;
- includes same fields plus published chapter summary count;
- inaccessible draft/archived module returns 404.

### `GET /api/v1/modules/:moduleId/chapters`

- query: `limit`, `cursor`;
- published chapters whose module is published;
- returns `id`, `moduleId`, `slug`, `title`, `summaryMarkdown`, `position`,
  `estimatedMinutes`;
- progress fields follow the same API-PROGRESS-001 rule as module responses.

### `GET /api/v1/chapters/:chapterId`

- returns chapter metadata and counts of visible theory/exercises/quizzes;
- does not embed every child or answer/attempt data.

## API-CATALOG-001 — Implement vertical read slice

Implement in this order:

1. `GET /me`;
2. module list/detail;
3. chapter list/detail.

For each:

- [ ] schema and safe examples;
- [ ] narrow application read port plus module-owned Supabase adapter with
      explicit columns and actor context;
- [ ] use case, persistence mapper and separate HTTP presenter;
- [ ] inbound adapter injection tests through the composition root;
- [ ] genuine AAL1 denial and TOTP AAL2 success;
- [ ] local server-authorization tests for published/draft/archived and direct
      Data API denial;
- [ ] cursor boundary/limit tests;
- [ ] OpenAPI update.

Gate: a learner can traverse published module -> chapter, while learner and
anonymous direct/API attempts cannot see a draft/archived hierarchy.
