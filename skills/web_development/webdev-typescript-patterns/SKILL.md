---
name: webdev-typescript-patterns
description: |
  TypeScript 5.x type system patterns for production web development. Use this skill when
  writing TypeScript code, designing type-safe APIs, migrating from JavaScript, or building
  robust type architectures. Covers generics, utility types, discriminated unions, strict
  mode configuration, and declaration patterns.
---

# TypeScript Patterns

Production-ready TypeScript 5.x patterns emphasizing type safety, inference, and maintainability.

## Core Principles

1. **Type safety over convenience** - Avoid `any`; use `unknown` when the type is genuinely uncertain
2. **Enable strict mode from day one** - All `strict` flags on; never selectively disable
3. **Prefer inference over annotation** - Let TypeScript infer when the result is unambiguous
4. **Model domain states explicitly** - Use discriminated unions to make illegal states unrepresentable
5. **Types are documentation** - Well-named types replace comments and reduce cognitive load

## Type System Fundamentals

**Use unions, intersections, and literal types to model data precisely**

```typescript
// Literal types constrain to exact values
type HttpMethod = "GET" | "POST" | "PUT" | "DELETE";

// Intersection types compose capabilities
type Timestamped = { createdAt: Date; updatedAt: Date };
type SoftDeletable = { deletedAt: Date | null };
type BaseEntity = Timestamped & SoftDeletable & { id: string };

// Union types model alternatives
type Result<T> = { ok: true; value: T } | { ok: false; error: Error };

// Template literal types build string patterns
type EventName = `on${Capitalize<"click" | "focus" | "blur">}`;
// => "onClick" | "onFocus" | "onBlur"
```

Key rules:
- Use `string` literal unions instead of `enum` for simple value sets
- Prefer `interface` for object shapes that may be extended; `type` for unions and computed types
- Use `readonly` arrays and tuples to prevent mutation

See [type-system-patterns.md](references/type-system-patterns.md) for:
- Conditional types and `infer` keyword
- Mapped types and key remapping
- Template literal type utilities
- Index signatures and record patterns

## Generics

**Use generics to write reusable, type-safe abstractions**

```typescript
// Constrained generic with default
interface Repository<T extends { id: string }, K extends keyof T = "id"> {
  findById(id: T[K]): Promise<T | null>;
  findAll(filter?: Partial<T>): Promise<T[]>;
  save(entity: Omit<T, "id">): Promise<T>;
}

// Generic function with inference
function groupBy<T, K extends string | number>(
  items: T[],
  keyFn: (item: T) => K
): Record<K, T[]> {
  return items.reduce((acc, item) => {
    const key = keyFn(item);
    (acc[key] ??= []).push(item);
    return acc;
  }, {} as Record<K, T[]>);
}

// Usage - types inferred from arguments
const grouped = groupBy(users, (u) => u.role);
// => Record<string, User[]>
```

Guidelines:
- Name generics meaningfully: `TItem`, `TResult`, not just `T` for complex signatures
- Add constraints with `extends` to communicate expectations
- Use defaults for commonly assumed types

See [generics-patterns.md](references/generics-patterns.md) for:
- Generic component patterns for React
- Builder and factory generics
- Inference helpers and generic utilities
- Variadic tuple types

## Utility Types

**Use built-in utility types to transform existing types**

```typescript
interface User {
  id: string;
  name: string;
  email: string;
  role: "admin" | "user";
}

// Partial for optional updates, Pick to select fields
type UserUpdate = Partial<Pick<User, "name" | "email">>;

// Omit to exclude, Required to enforce completeness
type UserCreate = Required<Omit<User, "id">>;

// Record for lookup maps, Extract/Exclude for filtering unions
type RolePermissions = Record<User["role"], string[]>;
type NonAdmin = Exclude<User["role"], "admin">; // "user"
```

Composition pattern: chain utilities to build precise types without repetition.

See [utility-types.md](references/utility-types.md) for:
- Custom utility type implementations
- `DeepPartial`, `DeepReadonly`, and recursive types
- `Awaited`, `ReturnType`, `Parameters` patterns
- Branded and opaque types

## Discriminated Unions and Type Guards

**Use tagged unions to make state transitions explicit**

```typescript
type AsyncState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error };

function renderState<T>(state: AsyncState<T>): string {
  switch (state.status) {
    case "idle":
      return "Ready";
    case "loading":
      return "Loading...";
    case "success":
      return `Data: ${JSON.stringify(state.data)}`;
    case "error":
      return `Error: ${state.error.message}`;
  }
  // No default needed - TypeScript ensures exhaustiveness
}

// Custom type guard
function isNonNullable<T>(value: T): value is NonNullable<T> {
  return value !== null && value !== undefined;
}

const values = [1, null, 3, undefined, 5];
const clean: number[] = values.filter(isNonNullable);
```

See [discriminated-unions.md](references/discriminated-unions.md) for:
- Exhaustive switch patterns with `never`
- Type narrowing with `in`, `instanceof`, and custom guards
- State machine modeling
- Pattern matching utilities

## Strict Mode Configuration

**Always enable the full strict family in tsconfig.json**

```typescript
// tsconfig.json (essential strict options)
{
  "compilerOptions": {
    "strict": true,                    // Enables all strict checks
    "noUncheckedIndexedAccess": true,  // Array/object index returns T | undefined
    "exactOptionalProperties": true,   // Distinguishes missing vs undefined
    "verbatimModuleSyntax": true,      // Enforce explicit type-only imports
    "isolatedDeclarations": true       // 5.5+ parallel declaration emit
  }
}
```

See [strict-mode-guide.md](references/strict-mode-guide.md) for:
- Full tsconfig strict option reference
- Migration strategy from JavaScript
- Handling `strictNullChecks` in legacy code
- Per-file `@ts-expect-error` migration patterns

## Module and Declaration Patterns

**Use explicit imports and declaration files for clean module boundaries**

```typescript
// Type-only imports keep runtime bundles lean
import type { User, UserCreate } from "./types.js";
import { createUser } from "./services.js";

// Declaration merging for third-party augmentation
declare module "express" {
  interface Request {
    user?: User;
    requestId: string;
  }
}

// Const assertion for immutable literal types
const ROUTES = {
  home: "/",
  users: "/users",
  settings: "/settings",
} as const;

type Route = (typeof ROUTES)[keyof typeof ROUTES];
// => "/" | "/users" | "/settings"
```

See [declaration-patterns.md](references/declaration-patterns.md) for:
- Writing `.d.ts` declaration files
- Module augmentation and global types
- Ambient declarations for untyped libraries
- Barrel exports and module organization

## Anti-Patterns

| Avoid | Use Instead |
|-------|-------------|
| `any` for unknown data | `unknown` with type guards |
| `as` type assertions | Type narrowing with control flow |
| `enum` for string values | String literal union types |
| Nested ternary type conditionals | Helper types with meaningful names |
| `!` non-null assertions | Explicit null checks or optional chaining |
| `object` or `{}` as a type | Specific interface or `Record<string, unknown>` |
| `Function` type | Explicit signature `(arg: T) => R` |
| Disabling strict checks | Fixing the underlying type issue |
| `@ts-ignore` | `@ts-expect-error` with explanation comment |
| Index signatures for known keys | Mapped types or explicit properties |

## Performance

Compilation and type-checking performance guidelines:

- **Project references** - Split large codebases with `composite: true` for incremental builds
- **`skipLibCheck: true`** - Skip type-checking `.d.ts` files to reduce build times
- **Isolate heavy types** - Move complex conditional/mapped types to separate utility files
- **Avoid deeply recursive types** - TypeScript caps recursion at ~50 levels; flatten where possible
- **Use `isolatedDeclarations`** - Enables parallel declaration emit in TS 5.5+
- **`tsc --noEmit` in CI** - Separate type-checking from bundling for faster feedback loops
- **Prefer `interface` over `type` for object shapes** - Interfaces are internally cached more efficiently
- **Limit union breadth** - Unions with 100+ members slow down assignability checks

source: TypeScript 5.x handbook, official documentation, and production best practices
