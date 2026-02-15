# Generics Patterns

## Generic Constraints

```typescript
// Constraining to objects with specific properties
function getProperty<T, K extends keyof T>(obj: T, key: K): T[K] {
  return obj[key];
}

const user = { name: "Alice", age: 30 };
const name = getProperty(user, "name"); // string
// getProperty(user, "email"); // Error - "email" not in keyof typeof user

// Constraining to specific structures
interface HasLength {
  length: number;
}

function logLength<T extends HasLength>(item: T): T {
  console.log(`Length: ${item.length}`);
  return item;
}

logLength("hello");     // string has .length
logLength([1, 2, 3]);   // array has .length
// logLength(42);        // Error - number has no .length

// Multiple constraints with intersection
function merge<T extends object, U extends object>(a: T, b: U): T & U {
  return { ...a, ...b };
}

// Constraining to constructor types
type Constructor<T = object> = new (...args: unknown[]) => T;

function createInstance<T>(ctor: Constructor<T>): T {
  return new ctor();
}
```

## Generic Defaults

```typescript
// Default type parameters
interface ApiResponse<TData = unknown, TError = Error> {
  data: TData | null;
  error: TError | null;
  status: number;
}

// Uses defaults
const response: ApiResponse = { data: null, error: null, status: 200 };

// Overrides first default only
const userResponse: ApiResponse<User> = {
  data: { id: "1", name: "Alice", email: "a@b.com", role: "user" } as User,
  error: null,
  status: 200,
};

// Generic class with defaults
class EventEmitter<TEvents extends Record<string, unknown[]> = Record<string, unknown[]>> {
  private listeners = new Map<keyof TEvents, Set<Function>>();

  on<K extends keyof TEvents>(event: K, handler: (...args: TEvents[K]) => void): void {
    if (!this.listeners.has(event)) {
      this.listeners.set(event, new Set());
    }
    this.listeners.get(event)!.add(handler);
  }

  emit<K extends keyof TEvents>(event: K, ...args: TEvents[K]): void {
    this.listeners.get(event)?.forEach((handler) => handler(...args));
  }
}

// Typed events
interface AppEvents {
  login: [user: { id: string; name: string }];
  logout: [];
  error: [code: number, message: string];
}

const emitter = new EventEmitter<AppEvents>();
emitter.on("login", (user) => console.log(user.name)); // user is typed
emitter.on("error", (code, msg) => console.error(code, msg));
// emitter.emit("login"); // Error - missing user argument
```

## Type Inference with Generics

```typescript
// Let TypeScript infer from usage
function createState<T>(initial: T) {
  let value = initial;
  return {
    get: () => value,
    set: (next: T) => { value = next; },
  };
}

const counter = createState(0);       // T inferred as number
counter.set(5);                        // OK
// counter.set("five");               // Error

// Inference with callback patterns
function pipe<A, B>(value: A, fn: (input: A) => B): B {
  return fn(value);
}

const result = pipe("hello", (s) => s.length); // result: number

// Multi-step inference
function createBuilder<T extends object>() {
  type Builder = {
    set<K extends keyof T>(key: K, value: T[K]): Builder;
    build(): T;
  };

  const data: Partial<T> = {};

  const builder: Builder = {
    set(key, value) {
      (data as Record<string, unknown>)[key as string] = value;
      return builder;
    },
    build() {
      return data as T;
    },
  };

  return builder;
}

interface UserConfig {
  host: string;
  port: number;
  debug: boolean;
}

const config = createBuilder<UserConfig>()
  .set("host", "localhost")
  .set("port", 3000)
  .set("debug", true)
  .build();
```

## Generic Components (React)

```typescript
// Generic list component
interface ListProps<T> {
  items: T[];
  renderItem: (item: T, index: number) => React.ReactNode;
  keyExtractor: (item: T) => string;
  emptyMessage?: string;
}

function List<T>({ items, renderItem, keyExtractor, emptyMessage }: ListProps<T>) {
  if (items.length === 0) {
    return <p>{emptyMessage ?? "No items"}</p>;
  }

  return (
    <ul>
      {items.map((item, index) => (
        <li key={keyExtractor(item)}>{renderItem(item, index)}</li>
      ))}
    </ul>
  );
}

// Usage - T inferred from items
<List
  items={users}
  renderItem={(user) => <span>{user.name}</span>}
  keyExtractor={(user) => user.id}
/>;

// Generic hook
function useLocalStorage<T>(key: string, initialValue: T) {
  const [value, setValue] = React.useState<T>(() => {
    const stored = localStorage.getItem(key);
    return stored ? (JSON.parse(stored) as T) : initialValue;
  });

  React.useEffect(() => {
    localStorage.setItem(key, JSON.stringify(value));
  }, [key, value]);

  return [value, setValue] as const;
}

// T inferred from initialValue
const [theme, setTheme] = useLocalStorage("theme", "light");
```

## Variadic Tuple Types

```typescript
// Typing variadic functions precisely
type Concat<A extends unknown[], B extends unknown[]> = [...A, ...B];
type Result = Concat<[1, 2], [3, 4]>; // [1, 2, 3, 4]

// Typed zip function
function zip<T extends unknown[][]>(
  ...arrays: T
): { [K in keyof T]: T[K] extends (infer U)[] ? U : never }[] {
  const minLength = Math.min(...arrays.map((a) => a.length));
  return Array.from({ length: minLength }, (_, i) =>
    arrays.map((a) => a[i])
  ) as any;
}

const zipped = zip(["a", "b"], [1, 2], [true, false]);
// => [string, number, boolean][]
```

## Utility Generic Patterns

```typescript
// Type-safe object entries
function typedEntries<T extends object>(obj: T): [keyof T, T[keyof T]][] {
  return Object.entries(obj) as [keyof T, T[keyof T]][];
}

// Type-safe object keys
function typedKeys<T extends object>(obj: T): (keyof T)[] {
  return Object.keys(obj) as (keyof T)[];
}

// Generic assertion function
function assertDefined<T>(value: T, message?: string): asserts value is NonNullable<T> {
  if (value === null || value === undefined) {
    throw new Error(message ?? "Value is null or undefined");
  }
}

// Generic retry wrapper
async function withRetry<T>(
  fn: () => Promise<T>,
  options: { maxAttempts?: number; delayMs?: number } = {}
): Promise<T> {
  const { maxAttempts = 3, delayMs = 1000 } = options;

  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === maxAttempts) throw error;
      await new Promise((resolve) => setTimeout(resolve, delayMs * attempt));
    }
  }

  throw new Error("Unreachable");
}
```

## Generic Mapped Utilities

```typescript
// Make specific keys optional
type PartialBy<T, K extends keyof T> = Omit<T, K> & Partial<Pick<T, K>>;

// Make specific keys required
type RequiredBy<T, K extends keyof T> = Omit<T, K> & Required<Pick<T, K>>;

// Make all keys nullable
type Nullable<T> = { [K in keyof T]: T[K] | null };

// Pick by value type
type PickByValue<T, V> = {
  [K in keyof T as T[K] extends V ? K : never]: T[K];
};

interface User {
  id: string;
  name: string;
  age: number;
  active: boolean;
}

type StringFields = PickByValue<User, string>;
// => { id: string; name: string }

// Merge two types with second taking precedence
type Merge<A, B> = Omit<A, keyof B> & B;
```
