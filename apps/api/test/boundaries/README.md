# Boundary verification

`ARC-BOUND-001` owns the dependency-cruiser configuration, the production
source scan, and every isolated fixture in this directory. The fixtures mirror
future source paths only under `test/`; they do not create real business-module
or adapter directories.

- `npm run boundaries` scans every production TypeScript file in
  `apps/api/src`.
- `npm run test:boundaries` checks the source-path and alias guards, runs the
  production scan, then runs each fixture independently.
- Every negative fixture contains exactly one static import/export edge and
  must fail with its listed `BND-001` through `BND-010` identifier. Positive
  controls prove the legal own-layer and allowlisted `public.ts` imports.

The BND-009 and BND-010 checks prove source/capability edges only. Runtime
Fastify decoration and plugin-registration proof remains owned by
`FAST-PLUGIN-002` and `ARC-BOUND-002`.
