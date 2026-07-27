export type LocalSupabaseRunner = "host" | "compose";

export interface LocalSupabaseTargetMetadata {
  readonly projectRef: string;
  readonly supabaseUrl: string;
  readonly jwtIssuer: string;
}

export interface LocalSupabaseTarget {
  readonly projectRef: "local";
  readonly supabaseUrl: string;
  readonly jwtIssuer: string;
  readonly runner: LocalSupabaseRunner;
}

export type LocalSupabaseTargetErrorCode =
  "project_ref" | "supabase_url" | "jwt_issuer";

export class LocalSupabaseTargetError extends Error {
  readonly code: LocalSupabaseTargetErrorCode;

  constructor(code: LocalSupabaseTargetErrorCode) {
    super("The integration target is not an approved local Supabase target.");
    this.name = "LocalSupabaseTargetError";
    this.code = code;
  }
}

function fail(code: LocalSupabaseTargetErrorCode): never {
  throw new LocalSupabaseTargetError(code);
}

function parseUrl(value: string, code: LocalSupabaseTargetErrorCode): URL {
  if (
    value.trim() !== value ||
    value.length === 0 ||
    value.includes("?") ||
    value.includes("#")
  ) {
    return fail(code);
  }

  try {
    return new URL(value);
  } catch {
    return fail(code);
  }
}

function isLoopbackHost(host: string): boolean {
  return (
    host === "localhost" ||
    host === "127.0.0.1" ||
    host === "[::1]" ||
    host === "::1"
  );
}

function hasApprovedUrlShape(url: URL, path: string): boolean {
  return (
    url.protocol === "http:" &&
    url.username.length === 0 &&
    url.password.length === 0 &&
    url.pathname === path &&
    url.search.length === 0 &&
    url.hash.length === 0
  );
}

function parseSupabaseUrl(value: string, runner: LocalSupabaseRunner): URL {
  const url = parseUrl(value, "supabase_url");
  const host = url.hostname.toLowerCase();
  const allowedHost =
    isLoopbackHost(host) ||
    (runner === "compose" && host === "host.docker.internal");

  return hasApprovedUrlShape(url, "/") && allowedHost
    ? url
    : fail("supabase_url");
}

function parseJwtIssuer(value: string): URL {
  const url = parseUrl(value, "jwt_issuer");

  return hasApprovedUrlShape(url, "/auth/v1") &&
    isLoopbackHost(url.hostname.toLowerCase())
    ? url
    : fail("jwt_issuer");
}

/**
 * Validates test metadata only. It never resolves DNS or opens a connection.
 */
export function parseLocalSupabaseTarget(
  metadata: LocalSupabaseTargetMetadata,
  runner: LocalSupabaseRunner,
): LocalSupabaseTarget {
  if (metadata.projectRef !== "local") {
    return fail("project_ref");
  }

  const supabaseUrl = parseSupabaseUrl(metadata.supabaseUrl, runner);
  const jwtIssuer = parseJwtIssuer(metadata.jwtIssuer);

  return Object.freeze({
    projectRef: "local",
    supabaseUrl: supabaseUrl.toString(),
    jwtIssuer: jwtIssuer.toString(),
    runner,
  });
}

/**
 * The guard runs synchronously before a future integration adapter/client
 * factory can be invoked.
 */
export function constructAfterLocalSupabaseTargetGuard<Constructed>(
  metadata: LocalSupabaseTargetMetadata,
  runner: LocalSupabaseRunner,
  construct: (target: LocalSupabaseTarget) => Constructed,
): Constructed {
  return construct(parseLocalSupabaseTarget(metadata, runner));
}
