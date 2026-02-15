# Strict Mode Guide

## Full Strict tsconfig Reference

```typescript
// tsconfig.json - recommended strict configuration for TypeScript 5.x
{
  "compilerOptions": {
    // --- Strict family (all enabled by "strict": true) ---
    "strict": true,
    // Individually, this enables:
    //   "strictNullChecks": true,        - null/undefined are distinct types
    //   "strictFunctionTypes": true,      - contravariant parameter checking
    //   "strictBindCallApply": true,      - typed bind/call/apply
    //   "strictPropertyInitialization": true, - class properties must be initialized
    //   "noImplicitAny": true,            - error on implicit any
    //   "noImplicitThis": true,           - error on implicit this
    //   "alwaysStrict": true,             - emit "use strict" in every file
    //   "useUnknownInCatchVariables": true - catch variables typed as unknown

    // --- Additional strictness (not part of "strict") ---
    "noUncheckedIndexedAccess": true,      // arr[0] returns T | undefined
    "exactOptionalProperties": true,        // {a?: string} !== {a: string | undefined}
    "noPropertyAccessFromIndexSignature": true, // obj["key"] not obj.key for index sigs
    "noImplicitReturns": true,              // error if not all paths return
    "noFallthroughCasesInSwitch": true,     // error on switch fallthrough
    "noImplicitOverride": true,             // require override keyword in subclasses
    "forceConsistentCasingInFileNames": true, // prevent case-sensitivity issues

    // --- Module system ---
    "module": "NodeNext",                    // or "ESNext" for bundled projects
    "moduleResolution": "NodeNext",          // or "Bundler" for Vite/webpack
    "verbatimModuleSyntax": true,            // enforce import type / export type
    "isolatedModules": true,                 // ensure per-file transpilation safety
    "isolatedDeclarations": true,            // 5.5+ parallel declaration emit

    // --- Output ---
    "target": "ES2022",
    "declaration": true,
    "declarationMap": true,
    "sourceMap": true,
    "outDir": "./dist",

    // --- Performance ---
    "skipLibCheck": true,
    "incremental": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

## Understanding strictNullChecks

```typescript
// WITHOUT strictNullChecks (dangerous - never do this)
// All types implicitly include null and undefined
// function getUser(): User could return null with no error

// WITH strictNullChecks (always enable)
function findUser(id: string): User | null {
  const user = database.get(id);
  return user ?? null; // Must explicitly handle null
}

// Accessing the result requires a null check
const user = findUser("123");
// user.name; // Error - user might be null
if (user) {
  user.name; // OK - narrowed to User
}

// Optional chaining for safe access
const name = user?.name; // string | undefined
const upper = user?.name?.toUpperCase(); // string | undefined

// Nullish coalescing for defaults
const displayName = user?.name ?? "Anonymous";

// Common patterns for handling nullable values
// Pattern 1: Early return
function getUserName(id: string): string {
  const user = findUser(id);
  if (!user) {
    throw new Error(`User not found: ${id}`);
  }
  return user.name; // User is narrowed, non-null
}

// Pattern 2: Map/transform when present
function getUserEmail(id: string): string | null {
  const user = findUser(id);
  return user?.email ?? null;
}

// Pattern 3: Array filtering
const userIds = ["1", "2", "3"];
const users: User[] = userIds
  .map(findUser)
  .filter((u): u is User => u !== null);
```

## noUncheckedIndexedAccess Patterns

```typescript
// With noUncheckedIndexedAccess: true
const numbers = [1, 2, 3];
const first = numbers[0]; // number | undefined (not just number)

// Must handle the undefined case
if (first !== undefined) {
  console.log(first.toFixed(2)); // OK
}

// Record types are also affected
const config: Record<string, string> = { host: "localhost" };
const host = config["host"]; // string | undefined

// Safe patterns for array access
// Pattern 1: Optional chaining
const items = ["a", "b", "c"];
const upper = items[0]?.toUpperCase(); // string | undefined

// Pattern 2: Destructuring with defaults
const [head = "default"] = items;

// Pattern 3: At method (returns undefined explicitly)
const last = items.at(-1); // string | undefined

// Pattern 4: Assert after bounds check
function getFirst<T>(arr: T[]): T {
  if (arr.length === 0) {
    throw new Error("Array is empty");
  }
  return arr[0]!; // Safe because we checked length
  // Note: the ! is justified here by the preceding check
}

```

## exactOptionalProperties

```typescript
// With exactOptionalProperties: true
interface Options { color?: string; width?: number }

const a: Options = {}; // OK - properties are absent
const b: Options = { color: "red" }; // OK - width is absent
// const c: Options = { color: undefined }; // Error! undefined !== absent

// Use for PATCH APIs: missing means "don't change", null means "clear it"
interface PatchUser {
  name?: string;
  bio?: string | null; // null = clear, absent = no change
}
// patchUser("1", { name: undefined }); // Error with exactOptionalProperties
```

## Migration from JavaScript

```typescript
// Step 1: Rename .js to .ts, start with loose config
// tsconfig.json (migration starting point)
{
  "compilerOptions": {
    "strict": false,
    "allowJs": true,
    "checkJs": false,
    "noEmit": true
  }
}

// Step 2: Enable checks incrementally
// Turn on one flag at a time, fix errors, commit

// Priority order for enabling strict flags:
// 1. noImplicitAny - biggest impact, catches most bugs
// 2. strictNullChecks - second biggest impact
// 3. strictFunctionTypes - usually few errors
// 4. strict: true - enable all remaining

// Step 3: Use @ts-expect-error for temporary suppression
function legacyFunction(data: any) {
  // @ts-expect-error -- TODO: migrate to proper types (#JIRA-123)
  return data.oldApi.deprecatedMethod();
}

```

## @ts-expect-error vs @ts-ignore

```typescript
// Use @ts-expect-error (not @ts-ignore) for known issues during migration
// @ts-expect-error will ERROR if the expected error goes away (good for cleanup)
// @ts-ignore silently suppresses forever (bad - masks real issues)

class LegacyService {
  // @ts-expect-error -- property types need migration (PROJ-456)
  private cache;

  // @ts-expect-error -- parameter types need migration (PROJ-456)
  processItem(item) {
    return this.cache.get(item.id);
  }
}
```

## strictFunctionTypes

```typescript
// strictFunctionTypes enables contravariant parameter checking
interface Animal { name: string }
interface Dog extends Animal { breed: string }

type AnimalHandler = (animal: Animal) => void;
type DogHandler = (dog: Dog) => void;

const handleAnimal: AnimalHandler = (animal) => console.log(animal.name);

// This is correctly an error with strictFunctionTypes:
// const broken: DogHandler = handleAnimal;
// handleAnimal doesn't know about breed, so it can't safely handle Dog

// Method syntax is bivariant; property syntax is contravariant (stricter)
// Prefer property syntax: emit: (event: E) => void over emit(event: E): void
```

## Handling strictPropertyInitialization

```typescript
// Class properties must be assigned in the constructor
class UserService {
  // Solution 1: Parameter properties (preferred)
  constructor(private apiClient: ApiClient) {}

  // Solution 2: Definite assignment assertion (use sparingly)
  private cache!: Map<string, unknown>; // Initialized in init()

  // Solution 3: Optional if truly not always present
  private connection?: WebSocket;
}

// Definite assignment (!) is acceptable when:
// - Framework lifecycle guarantees initialization (e.g., Angular @Input)
// - Lazy initialization with a known init pathway
// Always prefer explicit initialization over !
```

## verbatimModuleSyntax

```typescript
// verbatimModuleSyntax (TS 5.0+) replaces importsNotUsedAsValues
// It requires explicit type-only syntax for type imports

// Correct: type-only import for types
import type { User, UserCreate } from "./types.js";

// Correct: mixed import (values and types)
import { createUser, type UserConfig } from "./services.js";

// Correct: value import
import { validateEmail } from "./validators.js";

// Error: importing a type without type modifier
// import { User } from "./types.js"; // User is only a type!

// Re-exports must also be explicit
export type { User, UserCreate };
export { createUser };

// Type-only exports
export type { AppConfig } from "./config.js";

// This flag ensures:
// 1. No type-only imports are emitted to JavaScript
// 2. Import/export syntax is preserved as-is (no rewriting)
// 3. Clear distinction between runtime and type-level code
```
