import { describe, expect, it, vi } from "vitest";

import {
  constructAfterLocalSupabaseTargetGuard,
  LocalSupabaseTargetError,
  parseLocalSupabaseTarget,
  type LocalSupabaseRunner,
  type LocalSupabaseTargetErrorCode,
  type LocalSupabaseTargetMetadata,
} from "./local-supabase-target.js";

const localMetadata: LocalSupabaseTargetMetadata = Object.freeze({
  projectRef: "local",
  supabaseUrl: "http://127.0.0.1:54321",
  jwtIssuer: "http://localhost:54321/auth/v1",
});

function expectTargetRejected(
  metadata: LocalSupabaseTargetMetadata,
  runner: LocalSupabaseRunner,
  code: LocalSupabaseTargetErrorCode,
): void {
  try {
    parseLocalSupabaseTarget(metadata, runner);
  } catch (error) {
    expect(error).toBeInstanceOf(LocalSupabaseTargetError);
    expect((error as LocalSupabaseTargetError).code).toBe(code);
    return;
  }

  throw new Error("Expected the local Supabase target guard to reject input.");
}

describe("parseLocalSupabaseTarget", () => {
  it("accepts only explicit local loopback metadata", () => {
    expect(parseLocalSupabaseTarget(localMetadata, "host")).toStrictEqual({
      projectRef: "local",
      supabaseUrl: "http://127.0.0.1:54321/",
      jwtIssuer: "http://localhost:54321/auth/v1",
      runner: "host",
    });
    expect(
      parseLocalSupabaseTarget(
        {
          ...localMetadata,
          supabaseUrl: "http://[::1]:54321",
          jwtIssuer: "http://[::1]:54321/auth/v1",
        },
        "host",
      ),
    ).toMatchObject({
      supabaseUrl: "http://[::1]:54321/",
      jwtIssuer: "http://[::1]:54321/auth/v1",
    });
    expect(
      parseLocalSupabaseTarget(
        {
          ...localMetadata,
          supabaseUrl: "http://host.docker.internal:54321",
        },
        "compose",
      ).supabaseUrl,
    ).toBe("http://host.docker.internal:54321/");
  });

  it.each([
    [
      "a non-local project reference",
      { ...localMetadata, projectRef: "hosted" },
      "host",
      "project_ref",
    ],
    [
      "an HTTPS API URL",
      { ...localMetadata, supabaseUrl: "https://127.0.0.1:54321" },
      "host",
      "supabase_url",
    ],
    [
      "a remote API URL",
      { ...localMetadata, supabaseUrl: "http://192.168.1.20:54321" },
      "host",
      "supabase_url",
    ],
    [
      "a public-network API URL",
      { ...localMetadata, supabaseUrl: "http://198.51.100.20:54321" },
      "host",
      "supabase_url",
    ],
    [
      "a hosted Supabase API URL",
      { ...localMetadata, supabaseUrl: "https://project.supabase.co" },
      "host",
      "supabase_url",
    ],
    [
      "the compose bridge URL on the host runner",
      {
        ...localMetadata,
        supabaseUrl: "http://host.docker.internal:54321",
      },
      "host",
      "supabase_url",
    ],
    [
      "a URL with credentials",
      {
        ...localMetadata,
        supabaseUrl: "http://user:password@127.0.0.1:54321",
      },
      "host",
      "supabase_url",
    ],
    [
      "an API URL with a fragment",
      {
        ...localMetadata,
        supabaseUrl: "http://127.0.0.1:54321#unexpected",
      },
      "host",
      "supabase_url",
    ],
    [
      "an API URL with a bare query delimiter",
      {
        ...localMetadata,
        supabaseUrl: "http://127.0.0.1:54321/?",
      },
      "host",
      "supabase_url",
    ],
    [
      "a non-local issuer",
      {
        ...localMetadata,
        jwtIssuer: "http://host.docker.internal:54321/auth/v1",
      },
      "compose",
      "jwt_issuer",
    ],
    [
      "an issuer with a query",
      {
        ...localMetadata,
        jwtIssuer: "http://localhost:54321/auth/v1?unexpected=true",
      },
      "host",
      "jwt_issuer",
    ],
    [
      "an issuer with a fragment",
      {
        ...localMetadata,
        jwtIssuer: "http://localhost:54321/auth/v1#unexpected",
      },
      "host",
      "jwt_issuer",
    ],
    [
      "a malformed issuer",
      { ...localMetadata, jwtIssuer: "not-a-url" },
      "host",
      "jwt_issuer",
    ],
    [
      "an issuer with a bare fragment delimiter",
      {
        ...localMetadata,
        jwtIssuer: "http://localhost:54321/auth/v1#",
      },
      "host",
      "jwt_issuer",
    ],
  ] as const)("rejects %s", (_description, metadata, runner, code) => {
    expectTargetRejected(metadata, runner, code);
  });

  it("runs before a future client factory and opens no network connection", () => {
    const construct = vi.fn();
    const fetchSpy = vi.fn();
    vi.stubGlobal("fetch", fetchSpy);

    try {
      expect(() =>
        constructAfterLocalSupabaseTargetGuard(
          {
            ...localMetadata,
            supabaseUrl: "https://project.supabase.co",
          },
          "host",
          construct,
        ),
      ).toThrow(LocalSupabaseTargetError);
      expect(construct).not.toHaveBeenCalled();
      expect(fetchSpy).not.toHaveBeenCalled();
    } finally {
      vi.unstubAllGlobals();
    }
  });
});
