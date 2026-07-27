import { Type, type Static } from "typebox";

const NodeEnvironment = Type.Union([
  Type.Literal("development"),
  Type.Literal("test"),
  Type.Literal("production"),
]);

const ApplicationEnvironment = Type.Union([
  Type.Literal("local"),
  Type.Literal("development"),
  Type.Literal("staging"),
  Type.Literal("production"),
]);

const LogLevel = Type.Union([
  Type.Literal("trace"),
  Type.Literal("debug"),
  Type.Literal("info"),
  Type.Literal("warn"),
  Type.Literal("error"),
  Type.Literal("fatal"),
  Type.Literal("silent"),
]);

const PositiveInteger = Type.Integer({ minimum: 1 });

/**
 * The one schema for configuration owned by the API process. Raw environment
 * values are parsed before this schema is checked; TypeBox never coerces them.
 */
export const ConfigSchema = Type.Object(
  {
    environment: Type.Object(
      {
        nodeEnv: NodeEnvironment,
        appEnv: ApplicationEnvironment,
      },
      { additionalProperties: false },
    ),
    server: Type.Object(
      {
        host: Type.String({ minLength: 1 }),
        port: Type.Integer({ minimum: 1, maximum: 65_535 }),
        apiPrefix: Type.Literal("/api/v1"),
        logLevel: LogLevel,
        trustProxy: Type.Literal(false),
        requestIdHeader: Type.String({ minLength: 1 }),
        swaggerUiEnabled: Type.Boolean(),
      },
      { additionalProperties: false },
    ),
    cors: Type.Object(
      {
        origins: Type.Array(Type.String({ minLength: 1 })),
      },
      { additionalProperties: false },
    ),
    limits: Type.Object(
      {
        bodyLimitBytes: PositiveInteger,
        rateLimit: Type.Object(
          {
            max: PositiveInteger,
            windowMs: PositiveInteger,
            attemptMax: PositiveInteger,
            adminMax: PositiveInteger,
          },
          { additionalProperties: false },
        ),
        timeouts: Type.Object(
          {
            connectionMs: Type.Integer({ minimum: 1_000, maximum: 60_000 }),
            requestReceiveMs: Type.Integer({
              minimum: 1_000,
              maximum: 120_000,
            }),
            dependencyMs: Type.Integer({ minimum: 100, maximum: 120_000 }),
            handlerMs: Type.Integer({ minimum: 1_000, maximum: 120_000 }),
            keepAliveMs: Type.Integer({ minimum: 1_000, maximum: 119_999 }),
            headersMs: Type.Integer({ minimum: 1_001, maximum: 120_000 }),
            readinessMs: Type.Integer({ minimum: 100, maximum: 10_000 }),
            shutdownMs: Type.Integer({ minimum: 1_000, maximum: 60_000 }),
          },
          { additionalProperties: false },
        ),
      },
      { additionalProperties: false },
    ),
    supabase: Type.Object(
      {
        url: Type.String({ minLength: 1 }),
        projectRef: Type.String({ minLength: 1 }),
        publishableKey: Type.String({ minLength: 1 }),
        secretKey: Type.String({ minLength: 1 }),
        jwtIssuer: Type.String({ minLength: 1 }),
        jwtAudience: Type.Literal("authenticated"),
      },
      { additionalProperties: false },
    ),
    cursor: Type.Object(
      {
        hmacSecret: Type.String({
          minLength: 43,
          maxLength: 43,
          pattern: "^[A-Za-z0-9_-]{43}$",
        }),
      },
      { additionalProperties: false },
    ),
    pythonGrader: Type.Object(
      {
        enabled: Type.Boolean(),
        concurrency: Type.Integer({ minimum: 1, maximum: 8 }),
        queueLimit: Type.Integer({ minimum: 1, maximum: 10_000 }),
      },
      { additionalProperties: false },
    ),
  },
  { additionalProperties: false },
);

export type ParsedApiConfig = Static<typeof ConfigSchema>;
