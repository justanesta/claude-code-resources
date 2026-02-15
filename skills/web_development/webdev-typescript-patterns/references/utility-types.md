# Utility Types

## Built-in Utility Types Reference

```typescript
interface User {
  id: string;
  name: string;
  email: string;
  role: "admin" | "editor" | "viewer";
  settings: {
    theme: "light" | "dark";
    notifications: boolean;
    language: string;
  };
}

// Partial<T> - All properties optional
type UserDraft = Partial<User>;

// Required<T> - All properties required
type CompleteUser = Required<User>;

// Readonly<T> - All properties readonly
type FrozenUser = Readonly<User>;

// Pick<T, K> - Select specific properties
type UserPreview = Pick<User, "id" | "name">;

// Omit<T, K> - Exclude specific properties
type UserWithoutId = Omit<User, "id">;

// Record<K, V> - Key-value mapping
type UsersByRole = Record<User["role"], User[]>;

// Extract<T, U> - Members of T assignable to U
type AdminOrEditor = Extract<User["role"], "admin" | "editor">;

// Exclude<T, U> - Members of T not assignable to U
type NonAdmin = Exclude<User["role"], "admin">;

// NonNullable<T> - Remove null and undefined
type Defined = NonNullable<string | null | undefined>; // string

// ReturnType<T> - Extract function return type
function getUser(): User { /* ... */ }
type GetUserReturn = ReturnType<typeof getUser>; // User

// Parameters<T> - Extract function parameter types
function createUser(name: string, email: string, role: User["role"]): User { /* ... */ }
type CreateUserParams = Parameters<typeof createUser>;
// => [name: string, email: string, role: "admin" | "editor" | "viewer"]

// Awaited<T> - Unwrap Promise types
type ResolvedUser = Awaited<Promise<Promise<User>>>; // User

// ConstructorParameters<T> - Extract constructor params
class UserService {
  constructor(private baseUrl: string, private timeout: number) {}
}
type ServiceParams = ConstructorParameters<typeof UserService>;
// => [baseUrl: string, timeout: number]

// InstanceType<T> - Extract instance type from constructor
type ServiceInstance = InstanceType<typeof UserService>; // UserService
```

## Composing Built-in Utilities

```typescript
// Common composition patterns
interface Product {
  id: string;
  name: string;
  price: number;
  description: string;
  category: string;
  tags: string[];
  createdAt: Date;
  updatedAt: Date;
}

// Create input: no id or timestamps
type ProductCreate = Omit<Product, "id" | "createdAt" | "updatedAt">;

// Update input: all fields optional except id
type ProductUpdate = Pick<Product, "id"> & Partial<Omit<Product, "id">>;

// List item: subset of fields, all required
type ProductListItem = Required<Pick<Product, "id" | "name" | "price" | "category">>;

// Search params: optional subset
type ProductSearch = Partial<Pick<Product, "name" | "category" | "tags">>;

// Readonly for props in React
type ProductCardProps = Readonly<{
  product: ProductListItem;
  onSelect: (id: string) => void;
}>;
```

## Custom Utility Types

```typescript
// DeepPartial - Recursively make all properties optional
type DeepPartial<T> = T extends object
  ? { [K in keyof T]?: DeepPartial<T[K]> }
  : T;

// Usage: deeply nested config updates
interface AppConfig {
  server: { host: string; port: number };
  database: { url: string; pool: { min: number; max: number } };
}

function updateConfig(patch: DeepPartial<AppConfig>): void {
  // Can pass { database: { pool: { max: 20 } } }
}

// DeepReadonly - Recursively make all properties readonly
type DeepReadonly<T> = T extends Function
  ? T
  : T extends object
    ? { readonly [K in keyof T]: DeepReadonly<T[K]> }
    : T;

const frozenConfig: DeepReadonly<AppConfig> = {
  server: { host: "localhost", port: 3000 },
  database: { url: "postgres://...", pool: { min: 2, max: 10 } },
};
// frozenConfig.server.port = 4000; // Error - readonly

// DeepRequired - Recursively make all properties required
type DeepRequired<T> = T extends object
  ? { [K in keyof T]-?: DeepRequired<T[K]> }
  : T;

// ValueOf - Extract value types from an object
type ValueOf<T> = T[keyof T];
type UserValues = ValueOf<User>; // string | "admin" | "editor" | "viewer" | { ... }

// KeysOfType - Extract keys that have values of a specific type
type KeysOfType<T, V> = {
  [K in keyof T]: T[K] extends V ? K : never;
}[keyof T];

type StringKeys = KeysOfType<User, string>; // "id" | "name" | "email"
```

## Recursive Types

```typescript
// JSON type definition
type JsonPrimitive = string | number | boolean | null;
type JsonArray = JsonValue[];
type JsonObject = { [key: string]: JsonValue };
type JsonValue = JsonPrimitive | JsonObject | JsonArray;

// Recursive path type for dot notation
type Path<T, Prefix extends string = ""> = T extends object
  ? {
      [K in keyof T & string]: T[K] extends object
        ? Path<T[K], `${Prefix}${K}.`> | `${Prefix}${K}`
        : `${Prefix}${K}`;
    }[keyof T & string]
  : never;

type UserPath = Path<User>;
// => "id" | "name" | "email" | "role" | "settings" | "settings.theme" | ...

// Type-safe deep get
type DeepGet<T, P extends string> = P extends `${infer Head}.${infer Tail}`
  ? Head extends keyof T
    ? DeepGet<T[Head], Tail>
    : never
  : P extends keyof T
    ? T[P]
    : never;

function deepGet<T, P extends Path<T>>(obj: T, path: P): DeepGet<T, P> {
  return path.split(".").reduce((acc: unknown, key) => (acc as Record<string, unknown>)[key], obj) as DeepGet<T, P>;
}

// Usage
const user: User = { /* ... */ } as User;
const theme = deepGet(user, "settings.theme"); // "light" | "dark"

// Recursive tree structure
interface TreeNode<T> {
  value: T;
  children: TreeNode<T>[];
}

function mapTree<T, U>(node: TreeNode<T>, fn: (value: T) => U): TreeNode<U> {
  return {
    value: fn(node.value),
    children: node.children.map((child) => mapTree(child, fn)),
  };
}
```

## Branded and Opaque Types

```typescript
// Branded type pattern for type-safe identifiers
declare const __brand: unique symbol;
type Brand<T, B> = T & { readonly [__brand]: B };

type UserId = Brand<string, "UserId">;
type OrderId = Brand<string, "OrderId">;
type Email = Brand<string, "Email">;
type PositiveNumber = Brand<number, "PositiveNumber">;

// Smart constructors with validation
function createEmail(value: string): Email {
  if (!value.includes("@")) {
    throw new Error(`Invalid email: ${value}`);
  }
  return value as Email;
}

function createPositive(value: number): PositiveNumber {
  if (value <= 0) {
    throw new Error(`Must be positive: ${value}`);
  }
  return value as PositiveNumber;
}

// Type-safe API boundaries
function sendEmail(to: Email, subject: string): void { /* ... */ }
function getOrder(id: OrderId): void { /* ... */ }

const email = createEmail("alice@example.com");
sendEmail(email, "Hello"); // OK
// sendEmail("raw-string", "Hello"); // Error - string is not Email
```

## String Manipulation Types

```typescript
// Built-in string manipulation types
type Upper = Uppercase<"hello">; // "HELLO"
type Lower = Lowercase<"HELLO">; // "hello"
type Cap = Capitalize<"hello">;  // "Hello"
type Uncap = Uncapitalize<"Hello">; // "hello"

// Convert object keys to different cases
type CamelToSnake<S extends string> = S extends `${infer Head}${infer Tail}`
  ? Head extends Uppercase<Head>
    ? `_${Lowercase<Head>}${CamelToSnake<Tail>}`
    : `${Head}${CamelToSnake<Tail>}`
  : S;

type SnakeCase = CamelToSnake<"firstName">; // "first_name"

// Build event handler types from event names
type EventHandlers<Events extends string> = {
  [E in Events as `on${Capitalize<E>}`]: (event: E) => void;
};

type MouseEvents = EventHandlers<"click" | "mousedown" | "mouseup">;
// => { onClick: (event: "click") => void; onMousedown: ...; onMouseup: ... }

```

## Conditional Utility Helpers

```typescript
// Strict omit that only allows existing keys
type StrictOmit<T, K extends keyof T> = Pick<T, Exclude<keyof T, K>>;

// Overwrite specific properties
type Overwrite<T, U extends Partial<Record<keyof T, unknown>>> = Omit<T, keyof U> & U;
type UserWithNumericId = Overwrite<User, { id: number }>;

// Ensure at least one property is provided
type AtLeastOne<T> = {
  [K in keyof T]-?: Required<Pick<T, K>> & Partial<Omit<T, K>>;
}[keyof T];

type SearchFilter = AtLeastOne<{ name: string; email: string; role: string }>;
const filter1: SearchFilter = { name: "Alice" }; // OK
// const filter2: SearchFilter = {}; // Error
```
