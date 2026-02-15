# Type System Patterns

## Union Types and Narrowing

```typescript
// Discriminated union with exhaustive handling
type Shape =
  | { kind: "circle"; radius: number }
  | { kind: "rectangle"; width: number; height: number }
  | { kind: "triangle"; base: number; height: number };

function area(shape: Shape): number {
  switch (shape.kind) {
    case "circle":
      return Math.PI * shape.radius ** 2;
    case "rectangle":
      return shape.width * shape.height;
    case "triangle":
      return (shape.base * shape.height) / 2;
  }
}

// String literal unions with computed members
type Direction = "north" | "south" | "east" | "west";
type Opposite<D extends Direction> = D extends "north"
  ? "south"
  : D extends "south"
    ? "north"
    : D extends "east"
      ? "west"
      : "east";

const opposite: Opposite<"north"> = "south"; // Only "south" is valid
```

## Intersection Types

```typescript
// Composing object types
type HasId = { id: string };
type HasTimestamps = { createdAt: Date; updatedAt: Date };
type HasSoftDelete = { deletedAt: Date | null };

type BaseEntity = HasId & HasTimestamps & HasSoftDelete;

// Intersection with generics for mixins
type WithMetadata<T> = T & {
  metadata: Record<string, string>;
  version: number;
};

type UserWithMeta = WithMetadata<{ name: string; email: string }>;
// => { name: string; email: string; metadata: Record<string, string>; version: number }

// Intersection for function overload patterns
type Logger = {
  log(message: string): void;
} & {
  log(level: "error" | "warn" | "info", message: string): void;
};
```

## Conditional Types

```typescript
// Basic conditional type
type IsString<T> = T extends string ? true : false;

// Distributive conditional types (distributes over unions)
type ToArray<T> = T extends unknown ? T[] : never;
type Result = ToArray<string | number>; // string[] | number[]

// Non-distributive (wrap in tuple to prevent distribution)
type ToArrayNonDist<T> = [T] extends [unknown] ? T[] : never;
type Result2 = ToArrayNonDist<string | number>; // (string | number)[]

// Infer keyword to extract types
type UnpackPromise<T> = T extends Promise<infer U> ? U : T;
type A = UnpackPromise<Promise<string>>; // string
type B = UnpackPromise<number>;          // number

// Extract function return type manually
type GetReturn<T> = T extends (...args: unknown[]) => infer R ? R : never;

// Nested conditional for complex transformations
type JsonPrimitive = string | number | boolean | null;
type JsonValue = JsonPrimitive | JsonObject | JsonArray;
type JsonObject = { [key: string]: JsonValue };
type JsonArray = JsonValue[];

type Serializable<T> = T extends JsonValue
  ? T
  : T extends { toJSON(): infer R }
    ? R
    : never;
```

## Mapped Types

```typescript
// Basic mapped type
type Optional<T> = {
  [K in keyof T]?: T[K];
};

// Mapped type with key remapping (4.1+)
type Getters<T> = {
  [K in keyof T as `get${Capitalize<string & K>}`]: () => T[K];
};

interface Person {
  name: string;
  age: number;
}

type PersonGetters = Getters<Person>;
// => { getName: () => string; getAge: () => number }

// Filtering keys with remapping
type OnlyStrings<T> = {
  [K in keyof T as T[K] extends string ? K : never]: T[K];
};

type StringFields = OnlyStrings<{ name: string; age: number; email: string }>;
// => { name: string; email: string }

// Mapped type modifiers
type Mutable<T> = {
  -readonly [K in keyof T]: T[K];
};

type Concrete<T> = {
  [K in keyof T]-?: T[K];
};

// Recursive mapped type for deep operations
type DeepReadonly<T> = T extends object
  ? { readonly [K in keyof T]: DeepReadonly<T[K]> }
  : T;
```

## Template Literal Types

```typescript
// Building string patterns
type HttpMethod = "GET" | "POST" | "PUT" | "DELETE" | "PATCH";
type ApiVersion = "v1" | "v2";
type Resource = "users" | "posts" | "comments";

type ApiEndpoint = `/${ApiVersion}/${Resource}`;
// => "/v1/users" | "/v1/posts" | "/v1/comments" | "/v2/users" | ...

// Event handler names
type DomEvent = "click" | "focus" | "blur" | "input" | "change";
type EventHandler = `on${Capitalize<DomEvent>}`;
// => "onClick" | "onFocus" | "onBlur" | "onInput" | "onChange"

// Parsing strings with template literals and infer
type ParseRoute<S extends string> = S extends `${infer _Start}:${infer Param}/${infer Rest}`
  ? Param | ParseRoute<Rest>
  : S extends `${infer _Start}:${infer Param}`
    ? Param
    : never;

type RouteParams = ParseRoute<"/users/:userId/posts/:postId">;
// => "userId" | "postId"

// CSS unit types
type CSSUnit = "px" | "em" | "rem" | "vh" | "vw" | "%";
type CSSValue = `${number}${CSSUnit}` | "auto" | "inherit";

function setWidth(value: CSSValue): void {
  // Only accepts valid CSS values
}
setWidth("100px");  // OK
setWidth("2.5rem"); // OK
setWidth("auto");   // OK
// setWidth("abc"); // Error
```

## Index Signatures and Record Patterns

```typescript
// Index signature basics
interface StringMap {
  [key: string]: string;
}

// Mixing known and dynamic keys
interface Config {
  name: string;
  version: number;
  [key: string]: string | number; // Must be compatible with known properties
}

// Prefer Record for simple key-value mappings
type FeatureFlags = Record<string, boolean>;
type ErrorCodes = Record<number, string>;

// Typed index signatures with template literals
type CSSProperties = {
  [K in `--${string}`]: string; // CSS custom properties
};

const styles: CSSProperties = {
  "--primary-color": "#007bff",
  "--font-size": "16px",
};

// noUncheckedIndexedAccess behavior
const flags: Record<string, boolean> = { darkMode: true };
const value = flags["darkMode"]; // boolean | undefined (with noUncheckedIndexedAccess)
if (value !== undefined) {
  console.log(value); // boolean (narrowed)
}
```

## Const Assertions and Literal Inference

```typescript
// as const creates deeply readonly literal types
const config = {
  api: {
    baseUrl: "https://api.example.com",
    timeout: 5000,
  },
  features: ["auth", "logging", "cache"],
} as const;

type BaseUrl = typeof config.api.baseUrl; // "https://api.example.com" (literal)
type Features = (typeof config.features)[number]; // "auth" | "logging" | "cache"

// satisfies operator (4.9+) for validation without widening
const palette = {
  red: [255, 0, 0],
  green: "#00ff00",
  blue: [0, 0, 255],
} satisfies Record<string, string | readonly number[]>;

// palette.red is still number[] (not string | number[])
const redChannel = palette.red[0]; // number

// Combining as const with satisfies for best of both worlds
const routes = {
  home: "/",
  users: "/users",
  settings: "/settings",
} as const satisfies Record<string, `/${string}`>;

type RoutePath = (typeof routes)[keyof typeof routes];
// => "/" | "/users" | "/settings"
```

## Branded / Opaque Types

```typescript
// Branding prevents accidental mixing of structurally identical types
type Brand<T, B extends string> = T & { readonly __brand: B };

type UserId = Brand<string, "UserId">;
type PostId = Brand<string, "PostId">;

function createUserId(id: string): UserId {
  return id as UserId;
}

function getUser(id: UserId): void { /* ... */ }
function getPost(id: PostId): void { /* ... */ }

const userId = createUserId("usr_123");
getUser(userId); // OK
// getPost(userId); // Error - UserId is not assignable to PostId

// Branded primitives for units
type Kilometers = Brand<number, "Kilometers">;
type Miles = Brand<number, "Miles">;

function kmToMiles(km: Kilometers): Miles {
  return (km * 0.621371) as Miles;
}
```
