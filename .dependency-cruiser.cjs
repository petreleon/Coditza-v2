"use strict";

/*
 * ARC-BOUND-001 owns this static import graph. It deliberately does not extend
 * dependency-cruiser's generic recommendations: fixture cases intentionally
 * use an unresolved Supabase import, and a generic unresolvable-import rule
 * would hide the architectural rule being proved.
 */

const API_SOURCE = "(?:^|/)apps/api/src";
const API_ENTRYPOINT = `${API_SOURCE}/(?:app|server)[.]ts$`;
const API_BOOTSTRAP = `${API_SOURCE}/bootstrap/`;
const PLATFORM_INFRASTRUCTURE = `${API_SOURCE}/infrastructure/`;
const PLATFORM_HTTP_INFRASTRUCTURE = `${PLATFORM_INFRASTRUCTURE}http/`;
const NON_SUPABASE_INFRASTRUCTURE = `${PLATFORM_INFRASTRUCTURE}(?!supabase/)`;
const SHARED_KERNEL = `${API_SOURCE}/shared/kernel/`;
const MODULE_ROOT = `${API_SOURCE}/modules`;
const MODULE_ADAPTER = `${MODULE_ROOT}/[^/]+/adapters/`;
const OUTBOUND_ADAPTER = `${MODULE_ROOT}/[^/]+/adapters/outbound/`;
const INBOUND_HTTP_ADAPTER = `${MODULE_ROOT}/[^/]+/adapters/inbound/http/`;
const SUPABASE_BOUNDARY = `${PLATFORM_INFRASTRUCTURE}supabase/`;
const HTTP_OR_TYPEBOX_PACKAGE =
  "(?:^|/)(?:node_modules/)?(?:fastify|fastify-plugin|@fastify/[^/]+|typebox)(?:/|$)";
const SUPABASE_PACKAGE =
  "(?:^|/)(?:node_modules/)?@supabase/supabase-js(?:/|$)";
const OPERATOR_ENTRYPOINT = "(?:^|/)(?:scripts|apps/api/src/operators)/";
const GRADER_ROOT = "(?:^|/)apps/grader-controller/src/";
const FORBIDDEN_FASTIFY_STATE_CAPABILITY = [
  SUPABASE_BOUNDARY,
  `${PLATFORM_INFRASTRUCTURE}(?:repositories|services|service-locator)(?:[.]ts$|/)`,
];

/** @type {import("dependency-cruiser").IConfiguration} */
module.exports = {
  forbidden: [
    {
      name: "BND-001",
      severity: "error",
      comment:
        "Shared kernel stays technology- and business-module-free so it cannot become a hidden owner.",
      from: { path: SHARED_KERNEL },
      to: {
        path: [
          MODULE_ROOT,
          PLATFORM_INFRASTRUCTURE,
          API_ENTRYPOINT,
          API_BOOTSTRAP,
          HTTP_OR_TYPEBOX_PACKAGE,
          SUPABASE_PACKAGE,
        ],
      },
    },
    {
      name: "BND-001",
      severity: "error",
      comment:
        "Platform infrastructure has no product workflow and cannot import a business module.",
      from: { path: PLATFORM_INFRASTRUCTURE },
      to: { path: MODULE_ROOT },
    },
    {
      name: "BND-002",
      severity: "error",
      comment:
        "Domain and application code cannot depend on adapters, platform infrastructure, API wiring, or technology packages.",
      from: { path: `${MODULE_ROOT}/[^/]+/(?:domain|application)/` },
      to: {
        path: [
          MODULE_ADAPTER,
          PLATFORM_INFRASTRUCTURE,
          API_ENTRYPOINT,
          API_BOOTSTRAP,
          HTTP_OR_TYPEBOX_PACKAGE,
          SUPABASE_PACKAGE,
        ],
      },
    },
    {
      name: "BND-002",
      severity: "error",
      comment:
        "Domain code can import only its own domain and the shared kernel, never an application or public contract.",
      from: { path: `${MODULE_ROOT}/([^/]+)/domain/` },
      to: {
        path: `${MODULE_ROOT}/[^/]+/(?:domain|application|public[.]ts$)`,
        pathNot: `${MODULE_ROOT}/$1/domain/`,
      },
    },
    {
      name: "BND-003",
      severity: "error",
      comment:
        "Inbound HTTP adapters may use only their own application facade/public contract, not domain or adapter implementations.",
      from: {
        path: `${MODULE_ROOT}/([^/]+)/adapters/inbound/http/`,
      },
      to: {
        path: `${MODULE_ROOT}/[^/]+/(?:domain|application|public[.]ts$)`,
        pathNot: [
          `${MODULE_ROOT}/$1/application/`,
          `${MODULE_ROOT}/$1/public[.]ts$`,
        ],
      },
    },
    {
      name: "BND-003",
      severity: "error",
      comment:
        "Inbound HTTP adapters cannot access an outbound or foreign adapter implementation.",
      from: {
        path: `${MODULE_ROOT}/([^/]+)/adapters/inbound/http/`,
      },
      to: {
        path: MODULE_ADAPTER,
        pathNot: `${MODULE_ROOT}/$1/adapters/inbound/http/`,
      },
    },
    {
      name: "BND-003",
      severity: "error",
      comment:
        "Inbound HTTP adapters cannot access the Supabase boundary or API wiring directly.",
      from: { path: INBOUND_HTTP_ADAPTER },
      to: {
        path: [
          SUPABASE_BOUNDARY,
          SUPABASE_PACKAGE,
          API_ENTRYPOINT,
          API_BOOTSTRAP,
        ],
      },
    },
    {
      name: "BND-004",
      severity: "error",
      comment:
        "A Supabase outbound adapter may use only its own domain, application ports, and mapping boundary.",
      from: {
        path: `${MODULE_ROOT}/([^/]+)/adapters/outbound/supabase/`,
      },
      to: {
        path: `${MODULE_ROOT}/[^/]+/`,
        pathNot: [
          `${MODULE_ROOT}/$1/domain/`,
          `${MODULE_ROOT}/$1/application/ports/`,
          `${MODULE_ROOT}/$1/adapters/outbound/supabase/`,
        ],
      },
    },
    {
      name: "BND-004",
      severity: "error",
      comment:
        "A Supabase outbound adapter cannot reach HTTP infrastructure or API wiring.",
      from: { path: OUTBOUND_ADAPTER },
      to: {
        path: [
          NON_SUPABASE_INFRASTRUCTURE,
          API_ENTRYPOINT,
          API_BOOTSTRAP,
          HTTP_OR_TYPEBOX_PACKAGE,
        ],
      },
    },
    {
      name: "BND-005",
      severity: "error",
      comment:
        "Application code may not deep-import another module's domain or application implementation.",
      from: { path: `${MODULE_ROOT}/([^/]+)/application/` },
      to: {
        path: `${MODULE_ROOT}/[^/]+/(?:domain|application)/`,
        pathNot: `${MODULE_ROOT}/$1/`,
      },
    },
    {
      name: "BND-005",
      severity: "error",
      comment:
        "Identity, curriculum, and operations cannot consume a module public contract.",
      from: {
        path: `${MODULE_ROOT}/(?:identity|curriculum|operations)/application/`,
      },
      to: { path: `${MODULE_ROOT}/[^/]+/public[.]ts$` },
    },
    {
      name: "BND-005",
      severity: "error",
      comment:
        "Assessment may consume curriculum.public.ts and no other public contract.",
      from: { path: `${MODULE_ROOT}/assessment/application/` },
      to: {
        path: `${MODULE_ROOT}/[^/]+/public[.]ts$`,
        pathNot: `${MODULE_ROOT}/curriculum/public[.]ts$`,
      },
    },
    {
      name: "BND-005",
      severity: "error",
      comment:
        "Progress may consume only curriculum.public.ts and assessment.public.ts.",
      from: { path: `${MODULE_ROOT}/progress/application/` },
      to: {
        path: `${MODULE_ROOT}/[^/]+/public[.]ts$`,
        pathNot: [
          `${MODULE_ROOT}/curriculum/public[.]ts$`,
          `${MODULE_ROOT}/assessment/public[.]ts$`,
        ],
      },
    },
    {
      name: "BND-006",
      severity: "error",
      comment:
        "A public.ts file exports only its own application contract and never a module implementation.",
      from: { path: `${MODULE_ROOT}/([^/]+)/public[.]ts$` },
      to: {
        path: `${MODULE_ROOT}/[^/]+/`,
        pathNot: `${MODULE_ROOT}/$1/application/`,
      },
    },
    {
      name: "BND-006",
      severity: "error",
      comment:
        "A public.ts file cannot re-export infrastructure, API wiring, or a framework/database capability.",
      from: { path: `${MODULE_ROOT}/[^/]+/public[.]ts$` },
      to: {
        path: [
          PLATFORM_INFRASTRUCTURE,
          API_ENTRYPOINT,
          API_BOOTSTRAP,
          HTTP_OR_TYPEBOX_PACKAGE,
          SUPABASE_PACKAGE,
        ],
      },
    },
    {
      name: "BND-007",
      severity: "error",
      comment:
        "No API source file can import an operator executable or private grader root.",
      from: { path: API_SOURCE },
      to: { path: [OPERATOR_ENTRYPOINT, GRADER_ROOT] },
    },
    {
      name: "BND-008",
      severity: "error",
      comment:
        "The private grader controller cannot reach API infrastructure or an API root/bootstrap capability.",
      from: { path: GRADER_ROOT },
      to: {
        path: [
          HTTP_OR_TYPEBOX_PACKAGE,
          API_ENTRYPOINT,
          API_BOOTSTRAP,
          PLATFORM_INFRASTRUCTURE,
        ],
      },
    },
    {
      name: "BND-008",
      severity: "error",
      comment:
        "The private grader controller cannot consume another business module.",
      from: { path: GRADER_ROOT },
      to: {
        path: `${MODULE_ROOT}/(?:identity|curriculum|progress|operations)/`,
      },
    },
    {
      name: "BND-008",
      severity: "error",
      comment:
        "The private grader controller may consume assessment.public.ts, never assessment internals.",
      from: { path: GRADER_ROOT },
      to: {
        path: `${MODULE_ROOT}/assessment/(?:domain|application|adapters)/`,
      },
    },
    {
      name: "BND-009",
      severity: "error",
      comment:
        "Fastify platform decoration/request code cannot import a raw client or service-locator-style bag.",
      from: {
        path: [`${API_SOURCE}/app[.]ts$`, PLATFORM_HTTP_INFRASTRUCTURE],
      },
      to: { path: FORBIDDEN_FASTIFY_STATE_CAPABILITY },
    },
    {
      name: "BND-010",
      severity: "error",
      comment:
        "One-off executables are isolated from Fastify plugin surfaces, API wiring, and HTTP infrastructure.",
      from: { path: OPERATOR_ENTRYPOINT },
      to: {
        path: [
          HTTP_OR_TYPEBOX_PACKAGE,
          API_ENTRYPOINT,
          API_BOOTSTRAP,
          PLATFORM_HTTP_INFRASTRUCTURE,
        ],
      },
    },
  ],
  options: {
    doNotFollow: {
      path: "node_modules",
      dependencyTypes: [
        "npm",
        "npm-dev",
        "npm-optional",
        "npm-peer",
        "npm-bundled",
        "npm-no-pkg",
      ],
    },
    moduleSystems: ["cjs", "es6"],
    tsPreCompilationDeps: true,
  },
};
