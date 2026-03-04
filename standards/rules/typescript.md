---
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
---

## Commands

```bash
pnpm install && pnpm build && pnpm test && pnpm lint && pnpm typecheck
turbo run build  # Build with caching
```

## TypeScript Configuration

- Always enable `strict: true`
- Enable `noUncheckedIndexedAccess: true` — array access returns `T | undefined`
- Enable `verbatimModuleSyntax: true`
- Use `moduleResolution: "NodeNext"` for Node, `"bundler"` for Vite/esbuild
- Use `"noEmit": true` when bundler handles output

## ESLint

- Use flat config format with `typescript-eslint`, `eslint-config-prettier`
- React: enable `react-hooks/rules-of-hooks` (error), `react-hooks/exhaustive-deps` (warn)
- Unused vars pattern: `argsIgnorePattern: "^_"`, `varsIgnorePattern: "^_"`, `caughtErrorsIgnorePattern: "^_"`

## Naming Conventions

- `camelCase` for variables/functions, `PascalCase` for types/interfaces/classes/React components
- `UPPER_SNAKE_CASE` for constants
- `kebab-case` for non-component filenames (`user-service.ts`)
- `PascalCase` for React component files (`UserCard.tsx`)
- `.test.ts` / `.test.tsx` suffix for tests

## Monorepo

- Use `@repo/` namespace for internal packages
- Set `"version": "0.0.0"` — semantic-release manages versions
- Set `"type": "module"` in package.json
- Share tsconfig and eslint-config as packages

## Type Safety — Never Violate

- **Never use `any`** — use `unknown`, generics, or proper types
- **Never use non-null assertion `!`** — use optional chaining + nullish coalescing (`?.`, `??`)
- **Never use `as` type assertions** to bypass checks — use runtime validation or type guards
- **Never use `== ` for comparison** except `== null` for null/undefined check — use `===`
- Handle `T | undefined` from indexed access: `items[0] ?? "default"`

❌ `const user = data as User;`
✅ `const user = Schema.decodeUnknownSync(User)(data);`

## Promise / Async Rules

- Never leave floating promises — always `await`, `void`, or `.catch()`
- Never mix `await` inside `Effect.gen` — use `yield* Effect.tryPromise()`

❌ `fetchData();`
✅ `await fetchData();` or `void fetchData();`

## Effect-TS Patterns

- Define services with `Context.Tag`, implement with `Layer.effect`
- Use `Effect.gen(function* () { ... })` for complex logic — **never omit `function*`**
- Use `pipe()` for simple transformations
- Never `throw` inside Effect code — use `Effect.fail()`
- Convert promises: `Effect.tryPromise({ try: () => promise, catch: (e) => new MyError({ cause: e }) })`
- Compose layers with `Layer.mergeAll()` and `Layer.provideMerge()`
- Use `Effect.provide(layer)` to supply dependencies

❌ `Effect.gen(() => { Effect.log("hello"); });`
✅ `Effect.gen(function* () { yield* Effect.log("hello"); });`

## Schema Validation (@effect/schema)

- Define schemas with `Schema.Struct`, extract type with `typeof MySchema.Type`
- Use `Schema.decodeUnknown(MySchema)` for runtime validation of unknown data
- Use `Schema.TaggedError` for domain errors with HTTP status annotations
- Use `Schema.TaggedClass` for discriminated unions
- Test schemas for isomorphism (encode then decode returns same value)

## SQL Injection Prevention (CRITICAL)

- **Always use parameterized queries** — never interpolate user input into SQL strings
- ClickHouse: use `{name:Type}` placeholders (`Identifier`, `String`, `Int32`, `DateTime`, `Array(String)`)

❌ `` `SELECT * FROM users WHERE id = '${userId}'` ``
✅ `` `SELECT * FROM users WHERE id = $1`, [userId] ``

## Error Handling

- Use `Match.type<E>()` with `Match.tag()` + `Match.exhaustive` for exhaustive error matching
- Use `Effect.catchAll` / `Effect.catchTag` for recovery
- Use `Effect.orElseSucceed` for fallback values
- Use `Effect.timeout` + catch `TimeoutException` for timeouts
- Use `Effect.retry` with `Schedule.exponential` + `Schedule.jittered` for retries

## Branded Types

- Use `Brand.nominal<T>()` for opaque IDs, `Brand.refined<T>()` for validated brands
- Branded types prevent passing raw strings where typed IDs are expected

## React Patterns

- Use `FC<Props>` with explicit interface for props
- Always include dependency arrays in `useEffect`/`useMemo`/`useCallback`
- Never mutate state directly — create new objects/arrays

❌ `items.push(newItem); setItems(items);`
✅ `setItems(prev => [...prev, newItem]);`

- Use `Runtime.isFiberFailure` to extract Effect errors in error boundaries

## Streams & Caching

- Use `Stream.fromIterable` / `Stream.fromAsyncIterable` for stream creation
- Use `Stream.grouped(n)` for batching, `Stream.schedule` for rate limiting
- Use `Effect.cachedWithTTL` for time-based caching
- Use `Request` + `RequestResolver.makeBatched` for request deduplication

## Logging

- Dev: human-friendly with colors; Container/CI: RFC 3339 JSON; File: RFC 3339 plain
- Use `Effect.log`, `Effect.logDebug`, `Effect.logWarning`, `Effect.logError`
- Use `Logger.json` in production, `Effect.withSpan` for tracing

## Configuration

- Priority: CLI args > ENV > .env > config.{env}.json > config.json > code defaults > fallbacks
- Use `Config.string`, `Config.number`, `Config.boolean`, `Config.literal` with `Config.withDefault`
- Use `Config.secret` for sensitive values — access via `Secret.value()`

## Testing (Vitest)

- Coverage thresholds: 80% lines, functions, branches
- Test Effect code: create test layers with `Layer.succeed`, run with `Effect.provide` + `Effect.runPromise`
- Test schemas: validate decoding, rejection of invalid input, encode/decode isomorphism

## Package Verification

- Verify packages exist on npm before importing — AI commonly hallucinates package names
- Stick to well-known packages: `effect`, `@effect/schema`, `@effect/platform`, `vitest`, `vite`, `react`

## Build

- Frontend: Vite with `@vitejs/plugin-react`, path alias `@/` → `./src/*`
- Backend: esbuild with `--platform=node --external:@effect/*`
- Turbo: `build` depends on `^build`, `dev` has `cache: false, persistent: true`
```
