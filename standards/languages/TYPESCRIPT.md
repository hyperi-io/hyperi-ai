---
name: typescript-standards
description: TypeScript coding standards using strict mode, ESLint, and modern patterns. Use when writing TypeScript or JavaScript code, reviewing TS/JS, or setting up Node.js projects.
rule_paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
detect_markers:
  - "file:tsconfig.json"
  - "file:package.json"
  - "deep_file:tsconfig.json"
  - "deep_file:package.json"
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
---

# TypeScript Standards for HyperI Projects

**Comprehensive TypeScript coding standards for monorepos, backend services, and React applications**

---

## Quick Reference

```bash
pnpm install                    # Install dependencies
pnpm build                      # Build all packages
pnpm test                       # Run tests
pnpm lint                       # Lint all packages
pnpm typecheck                  # Type check only
turbo run build                 # Build with caching
```

---

## Project Structure

### Monorepo Layout (Turborepo)

```text
myproject/
├── apps/
│   ├── web/                    # React frontend
│   │   ├── src/
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   └── vite.config.ts
│   └── server/                 # Node.js backend
│       ├── src/
│       ├── package.json
│       └── tsconfig.json
├── packages/
│   ├── shared/                 # Shared types/utilities
│   │   ├── src/
│   │   └── package.json
│   ├── eslint-config/          # Shared ESLint config
│   │   ├── base.js
│   │   └── react.js
│   └── typescript-config/      # Shared tsconfig
│       ├── base.json
│       └── react.json
├── package.json                # Root workspace config
├── pnpm-workspace.yaml
└── turbo.json
```

### Package.json Conventions

```json
{
  "name": "@repo/mypackage",
  "version": "0.0.0",
  "type": "module",
  "exports": {
    ".": "./src/index.ts",
    "./models/*": "./src/models/*.ts"
  },
  "scripts": {
    "build": "tsc -b",
    "test": "vitest run",
    "lint": "eslint .",
    "typecheck": "tsc --noEmit"
  },
  "devDependencies": {
    "@repo/eslint-config": "*",
    "@repo/typescript-config": "*"
  }
}
```

### Semantic Release Configuration

```json
{
  "name": "@repo/mypackage",
  "version": "0.0.0",
  "release": {
    "branches": ["main"],
    "plugins": [
      "@semantic-release/commit-analyzer",
      "@semantic-release/release-notes-generator",
      "@semantic-release/npm",
      "@semantic-release/github"
    ]
  }
}
```

**Note:** Version `"0.0.0"` is intentional - semantic-release manages versioning based on commit messages.

---

## TypeScript Configuration

### Base Configuration (Strict Mode Required)

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2023"],
    "module": "NodeNext",
    "moduleResolution": "NodeNext",

    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true,
    "noUncheckedSideEffectImports": true,

    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "skipLibCheck": true,

    "verbatimModuleSyntax": true,
    "moduleDetection": "force",
    "esModuleInterop": true,
    "resolveJsonModule": true
  }
}
```

### React/Vite Configuration

```json
{
  "extends": "@repo/typescript-config/react.json",
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2023", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",

    "jsx": "react-jsx",
    "useDefineForClassFields": true,
    "allowImportingTsExtensions": true,
    "noEmit": true,

    "baseUrl": ".",
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["src"]
}
```

### Why These Settings

| Setting | Purpose |
|---------|---------|
| `strict: true` | Enables all strict type checks |
| `noUncheckedIndexedAccess` | Arrays return `T \| undefined` |
| `verbatimModuleSyntax` | Preserves import/export for bundlers |
| `moduleResolution: bundler` | For Vite/esbuild (not Node resolution) |
| `noEmit: true` | Type check only, bundler handles output |

---

## ESLint Configuration (Flat Config)

### Base Configuration

```javascript
// packages/eslint-config/base.js
import js from "@eslint/js";
import eslintConfigPrettier from "eslint-config-prettier";
import tseslint from "typescript-eslint";
import turboPlugin from "eslint-plugin-turbo";

export const config = [
  js.configs.recommended,
  eslintConfigPrettier,
  ...tseslint.configs.recommended,
  {
    plugins: { turbo: turboPlugin },
    rules: {
      "turbo/no-undeclared-env-vars": "warn",
    },
  },
  {
    ignores: ["dist/**", "node_modules/**"],
  },
];
```

### React Configuration

```javascript
// packages/eslint-config/react.js
import { config as baseConfig } from "./base.js";
import reactPlugin from "eslint-plugin-react";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";

export default [
  ...baseConfig,
  {
    plugins: {
      react: reactPlugin,
      "react-hooks": reactHooks,
      "react-refresh": reactRefresh,
    },
    rules: {
      "react/react-in-jsx-scope": "off",
      "react-hooks/rules-of-hooks": "error",
      "react-hooks/exhaustive-deps": "warn",
      "@typescript-eslint/no-unused-vars": [
        "error",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
          caughtErrorsIgnorePattern: "^_",
        },
      ],
    },
  },
];
```

### App-Level Configuration

```javascript
// apps/web/eslint.config.js
import { defineConfig, globalIgnores } from "eslint/config";
import baseConfig from "@repo/eslint-config/react";

export default defineConfig([
  globalIgnores(["dist"]),
  ...baseConfig,
]);
```

---

## Effect-TS Patterns

### Service Definition with Context.Tag

```typescript
import { Context, Effect, Layer } from "effect";

// Define service interface
export class DatabaseClient extends Context.Tag("DatabaseClient")<
  DatabaseClient,
  {
    readonly query: <T>(sql: string, params: unknown[]) => Effect.Effect<T[], DatabaseError>;
    readonly execute: (sql: string, params: unknown[]) => Effect.Effect<void, DatabaseError>;
  }
>() {}

// Implement service layer
export const DatabaseClientLive = Layer.effect(
  DatabaseClient,
  Effect.gen(function* () {
    const connectionString = yield* Config.string("DATABASE_URL");
    const pool = createPool(connectionString);

    return {
      query: (sql, params) =>
        Effect.tryPromise({
          try: () => pool.query(sql, params),
          catch: (error) => new DatabaseError({ cause: error }),
        }),
      execute: (sql, params) =>
        Effect.tryPromise({
          try: () => pool.execute(sql, params),
          catch: (error) => new DatabaseError({ cause: error }),
        }),
    };
  })
);
```

### Effect.gen for Monadic Composition

```typescript
import { Effect, pipe } from "effect";

// ✅ Good - Effect.gen for complex logic
const processOrder = (orderId: string) =>
  Effect.gen(function* () {
    const order = yield* OrderRepository.findById(orderId);
    const inventory = yield* InventoryService.check(order.items);

    if (!inventory.available) {
      return yield* Effect.fail(new InsufficientInventoryError({ orderId }));
    }

    const payment = yield* PaymentService.charge(order.total);
    const shipment = yield* ShippingService.create(order, payment);

    return { order, payment, shipment };
  });

// ✅ Good - pipe for simple transformations
const getOrderTotal = (orderId: string) =>
  pipe(
    OrderRepository.findById(orderId),
    Effect.map((order) => order.total),
    Effect.withSpan("getOrderTotal"),
  );
```

### Error Handling with Match

```typescript
import { Match, pipe } from "effect";

// Define domain errors
export class NotFoundError extends Schema.TaggedError<NotFoundError>()(
  "NotFoundError",
  { resource: Schema.String, id: Schema.String }
) {}

export class ValidationError extends Schema.TaggedError<ValidationError>()(
  "ValidationError",
  { field: Schema.String, message: Schema.String }
) {}

type DomainError = NotFoundError | ValidationError;

// Exhaustive error handling
const handleError = (error: DomainError) =>
  pipe(
    Match.type<DomainError>(),
    Match.tag("NotFoundError", (e) => ({
      status: 404,
      message: `${e.resource} not found: ${e.id}`,
    })),
    Match.tag("ValidationError", (e) => ({
      status: 400,
      message: `Invalid ${e.field}: ${e.message}`,
    })),
    Match.exhaustive,
  )(error);
```

### Layer Composition

```typescript
import { Layer } from "effect";

// Compose layers for dependency injection
const MainLayer = Layer.mergeAll(
  DatabaseClientLive,
  CacheClientLive,
  LoggerLive,
).pipe(
  Layer.provideMerge(ConfigLive),
);

// Run program with layers
const main = Effect.gen(function* () {
  const db = yield* DatabaseClient;
  const cache = yield* CacheClient;
  // ...
});

Effect.runPromise(
  main.pipe(Effect.provide(MainLayer))
);
```

---

## Schema Validation (@effect/schema)

### Schema Definition

```typescript
import { Schema } from "@effect/schema";

// Define schema with type inference
export const User = Schema.Struct({
  id: Schema.String,
  email: Schema.String.pipe(Schema.pattern(/^[^\s@]+@[^\s@]+\.[^\s@]+$/)),
  name: Schema.String.pipe(Schema.minLength(1)),
  age: Schema.Number.pipe(Schema.int(), Schema.between(0, 150)),
  role: Schema.Union(
    Schema.Literal("admin"),
    Schema.Literal("user"),
    Schema.Literal("guest"),
  ),
  createdAt: Schema.Date,
  metadata: Schema.optional(Schema.Record({ key: Schema.String, value: Schema.Unknown })),
});

// Extract type from schema
export type User = typeof User.Type;

// For input (before transformation)
export type UserInput = typeof User.Encoded;
```

### Schema Transformations

```typescript
// Transform between formats
export const DateFromUnix = Schema.transform(
  Schema.Number,
  Schema.Date,
  {
    decode: (unix) => new Date(unix * 1000),
    encode: (date) => Math.floor(date.getTime() / 1000),
  }
);

// Use in struct
export const Event = Schema.Struct({
  id: Schema.String,
  timestamp: DateFromUnix,
  data: Schema.Unknown,
});
```

### Runtime Validation

```typescript
import { Effect, pipe } from "effect";
import { Schema } from "@effect/schema";

// Validate unknown data
const parseUser = (input: unknown) =>
  pipe(
    input,
    Schema.decodeUnknown(User),
    Effect.mapError((error) => new ValidationError({
      field: "user",
      message: String(error),
    })),
  );

// In request handler
const handleRequest = (body: unknown) =>
  Effect.gen(function* () {
    const user = yield* parseUser(body);
    const saved = yield* UserRepository.save(user);
    return saved;
  });
```

### API Error Schemas

```typescript
import { HttpApiSchema } from "@effect/platform";

export class UnauthorizedError extends Schema.TaggedError<UnauthorizedError>()(
  "UnauthorizedError",
  { message: Schema.String },
  HttpApiSchema.annotations({
    status: 401,
    description: "Authentication required",
  })
) {}

export class RateLimitError extends Schema.TaggedError<RateLimitError>()(
  "RateLimitError",
  { retryAfter: Schema.Number },
  HttpApiSchema.annotations({
    status: 429,
    description: "Too many requests",
  })
) {}
```

---

## SQL Injection Prevention

### Parameterized Queries (CRITICAL)

```typescript
// ❌ BAD - SQL injection vulnerability
const getUser = (userId: string) => {
  const sql = `SELECT * FROM users WHERE id = '${userId}'`;  // DANGER!
  return db.query(sql);
};

// ✅ GOOD - Parameterized query
const getUser = (userId: string) => {
  const sql = `SELECT * FROM users WHERE id = $1`;
  return db.query(sql, [userId]);
};

// ✅ GOOD - ClickHouse placeholders
const getEvents = (filters: Filter[]) => {
  const params: Record<string, unknown> = {};
  const conditions: string[] = [];

  filters.forEach((filter, i) => {
    params[`col_${i}`] = filter.column;
    params[`val_${i}`] = filter.value;
    conditions.push(`{col_${i}:Identifier} = {val_${i}:String}`);
  });

  const sql = `SELECT * FROM events WHERE ${conditions.join(" AND ")}`;
  return client.query(sql, params);
};
```

### ClickHouse Placeholder Types

| Placeholder | Use For |
|-------------|---------|
| `{name:Identifier}` | Column/table names |
| `{name:String}` | String values |
| `{name:Int32}` | Integer values |
| `{name:DateTime}` | Date/time values |
| `{name:Array(String)}` | Array values |

---

## Testing

### Vitest Configuration

```typescript
// vitest.config.ts
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    include: ["**/*.test.ts"],
    coverage: {
      provider: "v8",
      reporter: ["text", "json", "html"],
      thresholds: {
        lines: 80,
        functions: 80,
        branches: 80,
      },
    },
  },
});
```

### Testing Effect Code

```typescript
import { describe, it, expect } from "vitest";
import { Effect, Layer, TestContext } from "effect";

describe("UserService", () => {
  // Test layer with mock implementations
  const TestLayer = Layer.succeed(
    DatabaseClient,
    {
      query: () => Effect.succeed([{ id: "1", name: "Test" }]),
      execute: () => Effect.succeed(undefined),
    }
  );

  it("should find user by id", async () => {
    const result = await Effect.gen(function* () {
      const service = yield* UserService;
      return yield* service.findById("1");
    }).pipe(
      Effect.provide(UserServiceLive),
      Effect.provide(TestLayer),
      Effect.runPromise,
    );

    expect(result).toEqual({ id: "1", name: "Test" });
  });

  it("should handle not found", async () => {
    const NotFoundLayer = Layer.succeed(DatabaseClient, {
      query: () => Effect.succeed([]),
      execute: () => Effect.succeed(undefined),
    });

    const result = await Effect.gen(function* () {
      const service = yield* UserService;
      return yield* service.findById("999");
    }).pipe(
      Effect.provide(UserServiceLive),
      Effect.provide(NotFoundLayer),
      Effect.runPromise,
    ).catch((e) => e);

    expect(result).toBeInstanceOf(NotFoundError);
  });
});
```

### Schema Testing

```typescript
import { describe, it, expect } from "vitest";
import { Effect, pipe } from "effect";
import { Schema } from "@effect/schema";

describe("User schema", () => {
  it("should decode valid input", () => {
    const input = {
      id: "123",
      email: "test@example.com",
      name: "Test User",
      age: 25,
      role: "user",
      createdAt: "2024-01-01T00:00:00Z",
    };

    const result = pipe(
      input,
      Schema.decodeUnknownSync(User),
    );

    expect(result.id).toBe("123");
    expect(result.createdAt).toBeInstanceOf(Date);
  });

  it("should reject invalid email", () => {
    const input = { ...validInput, email: "invalid" };

    expect(() =>
      Schema.decodeUnknownSync(User)(input)
    ).toThrow();
  });

  it("should be isomorphic (encode/decode)", () => {
    const user: User = { /* valid user */ };

    const result = pipe(
      user,
      Schema.encodeSync(User),
      Schema.decodeUnknownSync(User),
    );

    expect(result).toEqual(user);
  });
});
```

---

## React Patterns

### Component Structure

```typescript
// components/UserCard/UserCard.tsx
import { type FC } from "react";
import styles from "./UserCard.module.css";

interface UserCardProps {
  user: User;
  onSelect?: (user: User) => void;
}

export const UserCard: FC<UserCardProps> = ({ user, onSelect }) => {
  return (
    <div className={styles.card} onClick={() => onSelect?.(user)}>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  );
};
```

### Async State Pattern

```typescript
type AsyncState<T, E = Error> =
  | { status: "idle" }
  | { status: "loading"; data?: T }
  | { status: "error"; error: E; data?: T }
  | { status: "success"; data: T };

const useAsync = <T,>(
  effect: Effect.Effect<T, Error>
): AsyncState<T> => {
  const [state, setState] = useState<AsyncState<T>>({ status: "idle" });

  useEffect(() => {
    setState((prev) => ({ status: "loading", data: prev.data }));

    Effect.runPromise(effect)
      .then((data) => setState({ status: "success", data }))
      .catch((error) => setState({ status: "error", error }));
  }, [effect]);

  return state;
};
```

### Error Boundary with Effect Errors

```typescript
import { Runtime } from "effect";

export const errorToMessage = (error: unknown): string => {
  if (Runtime.isFiberFailure(error)) {
    const cause = error[Runtime.FiberFailureCauseId];

    return pipe(
      Match.value(cause.error),
      Match.tag("NotFoundError", (e) => `${e.resource} not found`),
      Match.tag("ValidationError", (e) => e.message),
      Match.orElse(() => "An unexpected error occurred"),
    );
  }

  return error instanceof Error ? error.message : "Unknown error";
};
```

---

## Turborepo Configuration

### turbo.json

```json
{
  "$schema": "https://turbo.build/schema.json",
  "tasks": {
    "build": {
      "dependsOn": ["^build"],
      "inputs": ["$TURBO_DEFAULT$", ".env*"],
      "outputs": ["dist/**", ".next/**"]
    },
    "test": {
      "dependsOn": ["^build"],
      "inputs": ["$TURBO_DEFAULT$", ".env.test"],
      "outputs": ["coverage/**"]
    },
    "lint": {
      "dependsOn": ["^build"],
      "outputs": []
    },
    "typecheck": {
      "dependsOn": ["^build"],
      "outputs": []
    },
    "dev": {
      "cache": false,
      "persistent": true
    }
  }
}
```

### pnpm-workspace.yaml

```yaml
packages:
  - "apps/*"
  - "packages/*"
```

---

## Naming Conventions

### Variables and Functions

```typescript
// camelCase for variables and functions
const userCount = 10;
const calculateTotal = (items: Item[]) => { };

// PascalCase for types, interfaces, classes
interface UserProfile { }
type PaymentMethod = "card" | "bank";
class OrderService { }

// UPPER_SNAKE_CASE for constants
const MAX_RETRIES = 3;
const API_BASE_URL = "https://api.example.com";

// Prefix private with underscore (convention)
const _internalCache = new Map();
```

### File Naming

```typescript
// kebab-case for files
user-service.ts
order-repository.ts
auth-middleware.ts

// PascalCase for React components
UserCard.tsx
OrderList.tsx

// .test.ts suffix for tests
user-service.test.ts
UserCard.test.tsx
```

---

## Common Pitfalls

### Type Narrowing

```typescript
// ❌ Bad - type assertion without check
const user = data as User;

// ✅ Good - runtime validation
const user = Schema.decodeUnknownSync(User)(data);

// ✅ Good - type guard
function isUser(data: unknown): data is User {
  return (
    typeof data === "object" &&
    data !== null &&
    "id" in data &&
    "email" in data
  );
}
```

### Null Handling

```typescript
// ❌ Bad - non-null assertion
const name = user!.name;

// ✅ Good - optional chaining with fallback
const name = user?.name ?? "Unknown";

// ✅ Good - explicit check
if (user) {
  console.log(user.name);
}
```

### Array Index Access

```typescript
// With noUncheckedIndexedAccess: true
const items = ["a", "b", "c"];
const first = items[0];  // type: string | undefined

// ✅ Good - handle undefined
const first = items[0] ?? "default";

// ✅ Good - use .at() with check
const first = items.at(0);
if (first !== undefined) {
  console.log(first);
}
```

### Promise Handling

```typescript
// ❌ Bad - floating promise
fetchData();

// ✅ Good - await or void
await fetchData();

// ✅ Good - explicit void for fire-and-forget
void fetchData();

// ✅ Good - Effect for composition
Effect.runPromise(fetchData).catch(console.error);
```

---

## Build Configuration

### Vite (Frontend)

```typescript
// vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
  build: {
    sourcemap: true,
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ["react", "react-dom"],
        },
      },
    },
  },
});
```

### esbuild (Backend)

```bash
esbuild src/main.ts \
  --bundle \
  --platform=node \
  --target=node20 \
  --outfile=dist/server.js \
  --sourcemap \
  --external:@effect/*
```

---

## HTTP Client (Effect Platform)

### Basic HTTP Client

```typescript
import { HttpClient, HttpClientRequest } from "@effect/platform";
import { Effect, pipe } from "effect";

const fetchUser = (userId: string) =>
  pipe(
    HttpClientRequest.get(`/api/users/${userId}`),
    HttpClient.execute,
    Effect.andThen((response) => response.json),
    Effect.andThen(Schema.decodeUnknown(User)),
    Effect.withSpan("fetchUser", { attributes: { userId } }),
  );
```

### HTTP Client with Retry

```typescript
import { Schedule } from "effect";

const fetchWithRetry = (url: string) =>
  pipe(
    HttpClientRequest.get(url),
    HttpClient.execute,
    Effect.retry(
      Schedule.exponential("100 millis").pipe(
        Schedule.compose(Schedule.recurs(3)),
        Schedule.jittered,
      )
    ),
    Effect.timeout("30 seconds"),
    Effect.catchTag("TimeoutException", () =>
      Effect.fail(new RequestTimeoutError({ url }))
    ),
  );
```

### HTTP Client with Authentication

```typescript
const AuthenticatedClient = Effect.gen(function* () {
  const baseClient = yield* HttpClient.HttpClient;
  const config = yield* Config.string("API_TOKEN");

  return baseClient.pipe(
    HttpClient.mapRequest(
      HttpClientRequest.setHeader("Authorization", `Bearer ${config}`)
    ),
    HttpClient.filterStatusOk,
  );
});

export const AuthenticatedClientLayer = Layer.effect(
  HttpClient.HttpClient,
  AuthenticatedClient,
);
```

---

## Configuration Management (HyperI Cascade)

TypeScript implements the 7-layer config cascade using Effect-TS Config + dotenv:

**Priority (highest to lowest):**

1. CLI args (via commander/yargs)
2. ENV variables (process.env)
3. .env file (dotenv)
4. config.{env}.json/yaml
5. config.json/yaml
6. defaults in code
7. Hard-coded fallbacks

### Effect Config

```typescript
import { Config, ConfigProvider, Layer } from "effect";

// Define configuration schema
const AppConfig = Config.all({
  port: Config.number("PORT").pipe(Config.withDefault(3000)),
  host: Config.string("HOST").pipe(Config.withDefault("localhost")),
  databaseUrl: Config.string("DATABASE_URL"),
  logLevel: Config.literal("debug", "info", "warn", "error")("LOG_LEVEL").pipe(
    Config.withDefault("info" as const)
  ),
  features: Config.struct({
    enableCache: Config.boolean("ENABLE_CACHE").pipe(Config.withDefault(true)),
    maxConnections: Config.number("MAX_CONNECTIONS").pipe(Config.withDefault(10)),
  }),
});

// Use in Effect.gen
const startServer = Effect.gen(function* () {
  const config = yield* AppConfig;
  console.log(`Starting server on ${config.host}:${config.port}`);
  // ...
});
```

### Environment Variables with .env

```typescript
import { PlatformConfigProvider } from "@effect/platform";

// Load .env file
const ConfigLayer = PlatformConfigProvider.layerDotEnvAdd(".env").pipe(
  Layer.merge(ConfigProvider.fromEnv()),
);

// Run with config
Effect.runPromise(
  main.pipe(Effect.provide(ConfigLayer))
);
```

### Secret Handling

```typescript
import { Config, Secret } from "effect";

// Secrets are never logged
const DatabaseConfig = Config.all({
  host: Config.string("DB_HOST"),
  port: Config.number("DB_PORT"),
  password: Config.secret("DB_PASSWORD"),  // Returns Secret type
});

// Access secret value explicitly
Effect.gen(function* () {
  const config = yield* DatabaseConfig;
  const password = Secret.value(config.password);  // string
});
```

---

## Logging (HyperI Standard)

**Output Modes:**

| Context | Format | Colours |
|---------|--------|---------|
| Console (dev) | Human-friendly | Yes |
| Container/CI | RFC 3339 JSON | No |
| File | RFC 3339 plain | No |

**RFC 3339 timestamp:** `2025-01-20T14:30:00.123Z`

### Effect Logger

```typescript
import { Effect, Logger, LogLevel } from "effect";

// Structured logging
Effect.gen(function* () {
  yield* Effect.log("Processing started");
  yield* Effect.logDebug("Debug info", { userId: "123" });
  yield* Effect.logWarning("Slow response", { latency: 500 });
  yield* Effect.logError("Operation failed", { error: "timeout" });
});

// Configure log level
const program = main.pipe(
  Logger.withMinimumLogLevel(LogLevel.Debug),
);
```

### JSON Logger for Production

```typescript
import { Logger } from "effect";

const JsonLogger = Logger.json;

const ProductionLogger = Logger.replace(
  Logger.defaultLogger,
  JsonLogger,
);

// Use in production
main.pipe(Effect.provide(ProductionLogger));
```

### Logging with Spans

```typescript
const processOrder = (orderId: string) =>
  Effect.gen(function* () {
    yield* Effect.logInfo("Processing order");

    const order = yield* OrderRepository.findById(orderId);
    yield* Effect.logDebug("Order fetched", { items: order.items.length });

    const result = yield* processPayment(order);
    yield* Effect.logInfo("Order completed", { total: result.total });

    return result;
  }).pipe(
    Effect.withSpan("processOrder", {
      attributes: { orderId },
    }),
  );
```

---

## Stream Processing

### Basic Streams

```typescript
import { Stream, Effect } from "effect";

// Create stream from array
const numbers = Stream.fromIterable([1, 2, 3, 4, 5]);

// Transform stream
const doubled = numbers.pipe(
  Stream.map((n) => n * 2),
  Stream.filter((n) => n > 4),
);

// Collect results
const result = await Stream.runCollect(doubled).pipe(Effect.runPromise);
// [6, 8, 10]
```

### Async Streams

```typescript
// Stream from async iterator
const queryStream = Stream.fromAsyncIterable(
  client.stream("SELECT * FROM events"),
  (error) => new DatabaseError({ cause: error }),
);

// Process with batching
const processEvents = queryStream.pipe(
  Stream.map((row) => row.json()),
  Stream.mapEffect((event) => processEvent(event)),
  Stream.grouped(100),  // Batch of 100
  Stream.mapEffect((batch) => saveBatch(batch)),
  Stream.runDrain,
);
```

### Stream with Rate Limiting

```typescript
import { Schedule, Duration } from "effect";

const rateLimitedStream = sourceStream.pipe(
  Stream.schedule(Schedule.spaced(Duration.millis(100))),  // 10 per second
  Stream.mapEffect((item) => processItem(item)),
);
```

---

## Caching

### TTL Cache

```typescript
import { Effect, Duration } from "effect";

// Cache with TTL
const CachedJWTKeys = Effect.cachedWithTTL(
  Effect.gen(function* () {
    const response = yield* fetchJWKS();
    return yield* Schema.decodeUnknown(JWKSSchema)(response);
  }),
  Duration.hours(24),  // Refresh every 24 hours
);

// Use cached value
Effect.gen(function* () {
  const keys = yield* CachedJWTKeys;  // Returns cached or fetches new
});
```

### Request Deduplication

```typescript
import { Request, RequestResolver, Effect } from "effect";

// Define request type
interface GetUser extends Request.Request<User, UserNotFoundError> {
  readonly _tag: "GetUser";
  readonly id: string;
}

const GetUser = Request.tagged<GetUser>("GetUser");

// Resolver with batching
const UserResolver = RequestResolver.makeBatched(
  (requests: GetUser[]) =>
    Effect.gen(function* () {
      const ids = requests.map((r) => r.id);
      const users = yield* UserRepository.findByIds(ids);

      return requests.map((request) => {
        const user = users.find((u) => u.id === request.id);
        return user
          ? Request.succeed(request, user)
          : Request.fail(request, new UserNotFoundError({ id: request.id }));
      });
    }),
);
```

---

## Middleware Patterns

### Express-Style Middleware

```typescript
import { HttpMiddleware, HttpServerRequest } from "@effect/platform";

const LoggingMiddleware = HttpMiddleware.make((app) =>
  Effect.gen(function* () {
    const request = yield* HttpServerRequest.HttpServerRequest;
    const start = Date.now();

    yield* Effect.logInfo("Request started", {
      method: request.method,
      url: request.url,
    });

    const response = yield* app;

    yield* Effect.logInfo("Request completed", {
      method: request.method,
      url: request.url,
      duration: Date.now() - start,
    });

    return response;
  }),
);
```

### Authentication Middleware

```typescript
const AuthMiddleware = HttpMiddleware.make((app) =>
  Effect.gen(function* () {
    const request = yield* HttpServerRequest.HttpServerRequest;
    const authHeader = request.headers.authorization;

    if (!authHeader?.startsWith("Bearer ")) {
      return yield* Effect.fail(new UnauthorizedError({ message: "Missing token" }));
    }

    const token = authHeader.slice(7);
    const user = yield* verifyToken(token);

    // Add user to context
    return yield* app.pipe(
      Effect.provideService(CurrentUser, user),
    );
  }),
);
```

---

## Error Recovery Patterns

### Fallback Values

```typescript
const getUserWithFallback = (userId: string) =>
  pipe(
    UserRepository.findById(userId),
    Effect.orElseSucceed(() => ({
      id: userId,
      name: "Unknown User",
      role: "guest" as const,
    })),
  );
```

### Circuit Breaker

```typescript
import { Effect, Schedule } from "effect";

const withCircuitBreaker = <A, E>(
  effect: Effect.Effect<A, E>,
  maxFailures: number = 5,
) => {
  let failures = 0;
  let lastFailure = 0;
  const resetTimeout = 60000;  // 1 minute

  return Effect.suspend(() => {
    const now = Date.now();
    if (failures >= maxFailures && now - lastFailure < resetTimeout) {
      return Effect.fail(new CircuitOpenError());
    }

    return effect.pipe(
      Effect.tap(() => {
        failures = 0;  // Reset on success
      }),
      Effect.tapError(() => {
        failures++;
        lastFailure = Date.now();
      }),
    );
  });
};
```

### Graceful Degradation

```typescript
const getProductWithReviews = (productId: string) =>
  Effect.gen(function* () {
    const product = yield* ProductRepository.findById(productId);

    // Reviews are optional - don't fail if unavailable
    const reviews = yield* ReviewService.getForProduct(productId).pipe(
      Effect.catchAll(() => Effect.succeed([])),
      Effect.timeout("2 seconds"),
      Effect.catchTag("TimeoutException", () => Effect.succeed([])),
    );

    return { ...product, reviews };
  });
```

---

## Type Utilities

### Branded Types

```typescript
import { Brand } from "effect";

// Create branded type
type UserId = string & Brand.Brand<"UserId">;
const UserId = Brand.nominal<UserId>();

type Email = string & Brand.Brand<"Email">;
const Email = Brand.refined<Email>(
  (s) => /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(s),
  (s) => Brand.error(`Invalid email: ${s}`),
);

// Usage
const userId: UserId = UserId("user-123");
const email: Email = Email("test@example.com");

// Type safety
function getUser(id: UserId): Effect.Effect<User> { }
getUser("raw-string");  // Type error!
getUser(UserId("user-123"));  // OK
```

### Discriminated Unions

```typescript
// Use Schema.TaggedClass for discriminated unions
class Success extends Schema.TaggedClass<Success>()("Success", {
  data: Schema.Unknown,
}) {}

class Failure extends Schema.TaggedClass<Failure>()("Failure", {
  error: Schema.String,
}) {}

const Result = Schema.Union(Success, Failure);
type Result = typeof Result.Type;

// Pattern matching
const handleResult = (result: Result) =>
  Match.value(result).pipe(
    Match.tag("Success", ({ data }) => `Got: ${data}`),
    Match.tag("Failure", ({ error }) => `Error: ${error}`),
    Match.exhaustive,
  );
```

---

## Dependencies

### Core Dependencies

| Package | Purpose |
|---------|---------|
| `effect` | Functional effect system |
| `@effect/schema` | Runtime validation |
| `@effect/platform` | HTTP client, file system |
| `typescript` | Type checking |

### React Dependencies

| Package | Purpose |
|---------|---------|
| `react`, `react-dom` | UI framework |
| `@tanstack/react-query` | Server state |
| `vite` | Build tool |

### Testing Dependencies

| Package | Purpose |
|---------|---------|
| `vitest` | Test runner |
| `@testing-library/react` | React testing |
| `happy-dom` | DOM implementation |

---

## Resources

- TypeScript Handbook: <https://www.typescriptlang.org/docs/handbook/>
- Effect Documentation: <https://effect.website/>
- Turborepo Documentation: <https://turbo.build/repo/docs>
- Vitest Documentation: <https://vitest.dev/>

---

## For AI Code Assistants

The following sections are specific guidance for AI code assistants working with TypeScript.

---

## AI Pitfalls to Avoid

**Before generating TypeScript code, check these patterns:**

### DO NOT Generate

```typescript
// ❌ Using 'any' type
function process(data: any): any {  // NEVER use any
// ✅ Use proper types or unknown
function process(data: unknown): Result {
function process<T>(data: T): ProcessResult<T> {

// ❌ Non-null assertion without checks
const value = obj.property!;  // Asserts non-null, may crash
// ✅ Proper null handling
const value = obj.property ?? defaultValue;
if (obj.property !== undefined) {
  const value = obj.property;
}

// ❌ Type assertions to bypass checks
const user = data as User;  // Dangerous if data isn't User
// ✅ Use type guards or validation
function isUser(data: unknown): data is User {
  return typeof data === 'object' && data !== null && 'id' in data;
}
if (isUser(data)) {
  const user = data;  // Safely narrowed
}

// ❌ Ignoring Promise rejections
fetchData().then(process);  // Unhandled rejection
// ✅ Handle errors
fetchData().then(process).catch(handleError);
// Or with async/await:
try {
  const data = await fetchData();
  process(data);
} catch (error) {
  handleError(error);
}

// ❌ == instead of ===
if (value == null) {  // Loose equality, confusing
// ✅ Strict equality
if (value === null || value === undefined) {
if (value == null) {  // Only OK for null/undefined check
```

### Package Verification Required

```typescript
// ❌ These are common AI hallucinations:
import { something } from "ts-migrate-parser";     // DOES NOT EXIST
import { helper } from "@effect/utils";            // Often wrong
import { validate } from "express-validator-v2";   // Check version

// ✅ Verify on npm before using
npm view package-name versions

// ✅ Use well-known packages:
// effect, zod, valibot, hono, express, vitest, typescript
```

### Effect-TS Pitfalls

```typescript
// ❌ Throwing in Effect code
const program = Effect.sync(() => {
  if (!valid) throw new Error("Invalid");  // WRONG - breaks Effect
});
// ✅ Use Effect.fail
const program = Effect.gen(function* () {
  if (!valid) return yield* Effect.fail(new InvalidError());
});

// ❌ Using Promise in Effect without conversion
const program = Effect.gen(function* () {
  const data = await fetchPromise();  // WRONG - mixing paradigms
});
// ✅ Convert Promise to Effect
const program = Effect.gen(function* () {
  const data = yield* Effect.tryPromise(() => fetchPromise());
});

// ❌ Not using generators for Effect.gen
const program = Effect.gen(() => {  // Missing function*
  Effect.log("hello");
});
// ✅ Use generator function
const program = Effect.gen(function* () {
  yield* Effect.log("hello");
});
```

### React Patterns (if applicable)

```typescript
// ❌ Missing dependency array
useEffect(() => {
  fetchData(userId);
});  // Runs on every render
// ✅ Include dependencies
useEffect(() => {
  fetchData(userId);
}, [userId]);

// ❌ Mutating state directly
const [items, setItems] = useState<string[]>([]);
items.push(newItem);  // WRONG - mutates existing array
setItems(items);      // Won't trigger re-render
// ✅ Create new array
setItems([...items, newItem]);
setItems(prev => [...prev, newItem]);
```
