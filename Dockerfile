# Verified 2026-07-27 against the Docker Official Image multi-platform index.
FROM node:24.18.0-bookworm-slim@sha256:6f7b03f7c2c8e2e784dcf9295400527b9b1270fd37b7e9a7285cf83b6951452d AS base

WORKDIR /workspace
RUN chown node:node /workspace
USER node

# Node includes fetch, so the image never needs curl or wget only for liveness.
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=12 CMD ["node", "-e", "const port = process.env.PORT ?? '3000'; fetch('http://127.0.0.1:' + port + '/health/live').then((response) => { if (response.status !== 200) process.exit(1); }).catch(() => process.exit(1));"]

FROM base AS dependencies

COPY --chown=node:node package.json package-lock.json ./
COPY --chown=node:node apps/api/package.json apps/api/package.json
RUN npm ci --ignore-scripts

FROM dependencies AS build

COPY --chown=node:node tsconfig.base.json ./
COPY --chown=node:node apps/api apps/api
RUN npm run build

FROM dependencies AS development

ENV NODE_ENV=development

COPY --chown=node:node tsconfig.base.json ./
COPY --chown=node:node apps/api apps/api

# Node is the foreground process; tsx loads the mounted TypeScript source in
# memory and Node restarts it with SIGTERM when a watched source file changes.
CMD ["node", "--import", "tsx", "--watch", "--watch-kill-signal=SIGTERM", "--watch-preserve-output", "apps/api/src/server.ts"]

FROM base AS production-dependencies

COPY --chown=node:node package.json package-lock.json ./
COPY --chown=node:node apps/api/package.json apps/api/package.json
RUN npm ci --ignore-scripts --omit=dev

FROM base AS runtime

ENV NODE_ENV=production

COPY --from=production-dependencies --chown=node:node /workspace/node_modules ./node_modules
COPY --from=build --chown=node:node /workspace/apps/api/package.json apps/api/package.json
COPY --from=build --chown=node:node /workspace/apps/api/dist apps/api/dist

CMD ["node", "apps/api/dist/server.js"]
