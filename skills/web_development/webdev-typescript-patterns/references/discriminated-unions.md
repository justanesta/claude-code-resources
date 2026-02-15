# Discriminated Unions and Type Guards

## Tagged Union Basics

```typescript
// The discriminant property (tag) must be a literal type
type Result<T, E = Error> =
  | { success: true; data: T }
  | { success: false; error: E };

function processResult<T>(result: Result<T>): T {
  if (result.success) {
    return result.data; // TypeScript knows data exists here
  }
  throw result.error; // TypeScript knows error exists here
}

// Multiple discriminant values for complex state machines
type ConnectionState =
  | { status: "disconnected" }
  | { status: "connecting"; attempt: number }
  | { status: "connected"; socket: WebSocket; connectedAt: Date }
  | { status: "reconnecting"; attempt: number; lastError: Error }
  | { status: "failed"; error: Error; failedAt: Date };

function getStatusMessage(state: ConnectionState): string {
  switch (state.status) {
    case "disconnected":
      return "Not connected";
    case "connecting":
      return `Connecting (attempt ${state.attempt})...`;
    case "connected":
      return `Connected since ${state.connectedAt.toISOString()}`;
    case "reconnecting":
      return `Reconnecting (attempt ${state.attempt}): ${state.lastError.message}`;
    case "failed":
      return `Connection failed: ${state.error.message}`;
  }
}
```

## Exhaustive Switch with never

```typescript
// The assertNever function catches unhandled cases at compile time
function assertNever(value: never, message?: string): never {
  throw new Error(message ?? `Unexpected value: ${JSON.stringify(value)}`);
}

type Action =
  | { type: "ADD_TODO"; text: string }
  | { type: "TOGGLE_TODO"; id: number }
  | { type: "DELETE_TODO"; id: number }
  | { type: "CLEAR_COMPLETED" };

interface Todo {
  id: number;
  text: string;
  completed: boolean;
}

function todoReducer(state: Todo[], action: Action): Todo[] {
  switch (action.type) {
    case "ADD_TODO":
      return [...state, { id: Date.now(), text: action.text, completed: false }];
    case "TOGGLE_TODO":
      return state.map((todo) =>
        todo.id === action.id ? { ...todo, completed: !todo.completed } : todo
      );
    case "DELETE_TODO":
      return state.filter((todo) => todo.id !== action.id);
    case "CLEAR_COMPLETED":
      return state.filter((todo) => !todo.completed);
    default:
      // If a new action type is added but not handled, this line will error
      return assertNever(action);
  }
}

// Alternative: satisfies never for inline exhaustiveness
function getActionLabel(action: Action): string {
  switch (action.type) {
    case "ADD_TODO": return "Add";
    case "TOGGLE_TODO": return "Toggle";
    case "DELETE_TODO": return "Delete";
    case "CLEAR_COMPLETED": return "Clear";
    default: {
      const _exhaustive: never = action;
      return _exhaustive;
    }
  }
}
```

## Type Narrowing Techniques

```typescript
// typeof narrowing
function formatValue(value: string | number | boolean): string {
  if (typeof value === "string") {
    return value.toUpperCase();
  }
  if (typeof value === "number") {
    return value.toFixed(2);
  }
  return value ? "Yes" : "No";
}

// instanceof narrowing
class ApiError extends Error {
  constructor(
    message: string,
    public statusCode: number,
    public body?: unknown
  ) {
    super(message);
  }
}

class NetworkError extends Error {
  constructor(message: string, public retryable: boolean) {
    super(message);
  }
}

function handleError(error: Error): string {
  if (error instanceof ApiError) {
    return `API Error ${error.statusCode}: ${error.message}`;
  }
  if (error instanceof NetworkError) {
    return error.retryable
      ? `Network error (retrying): ${error.message}`
      : `Network error (fatal): ${error.message}`;
  }
  return `Unknown error: ${error.message}`;
}

// "in" operator narrowing
type Fish = { swim: () => void };
type Bird = { fly: () => void };
type Amphibian = { swim: () => void; walk: () => void };

function move(animal: Fish | Bird | Amphibian): void {
  if ("fly" in animal) {
    animal.fly(); // Bird
  } else if ("walk" in animal) {
    animal.swim(); // Amphibian (has both swim and walk)
    animal.walk();
  } else {
    animal.swim(); // Fish
  }
}

// Truthiness narrowing
function printName(name: string | null | undefined): void {
  if (name) {
    console.log(name.toUpperCase()); // string (not null/undefined/empty)
  }
}
```

## Custom Type Guards

```typescript
// Type predicate functions
interface Cat { meow(): void; purr(): void }
interface Dog { bark(): void; fetch(): void }

function isCat(animal: Cat | Dog): animal is Cat {
  return "meow" in animal;
}

function interact(animal: Cat | Dog): void {
  if (isCat(animal)) {
    animal.purr(); // Cat
  } else {
    animal.fetch(); // Dog
  }
}

// Type guard for filtering arrays
function isNonNull<T>(value: T | null | undefined): value is T {
  return value != null;
}

const mixed: (string | null)[] = ["hello", null, "world", null];
const strings: string[] = mixed.filter(isNonNull);

// Assertion functions (throw instead of returning boolean)
function assertIsString(value: unknown): asserts value is string {
  if (typeof value !== "string") {
    throw new TypeError(`Expected string, got ${typeof value}`);
  }
}

function processInput(input: unknown): string {
  assertIsString(input);
  return input.toUpperCase(); // input narrowed to string
}

// General assertion helper
function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message);
}
```

## State Machine Modeling

```typescript
// Model valid state transitions with discriminated unions
type FormState =
  | { step: "input"; data: Partial<FormData> }
  | { step: "validating"; data: FormData }
  | { step: "submitting"; data: FormData; attemptCount: number }
  | { step: "success"; data: FormData; response: { id: string } }
  | { step: "error"; data: FormData; error: Error; canRetry: boolean };

interface FormData { name: string; email: string }

type FormAction =
  | { type: "SUBMIT" }
  | { type: "VALIDATION_PASS" }
  | { type: "SUBMIT_SUCCESS"; response: { id: string } }
  | { type: "SUBMIT_FAIL"; error: Error }
  | { type: "RETRY" };

function formReducer(state: FormState, action: FormAction): FormState {
  switch (state.step) {
    case "input":
      if (action.type === "SUBMIT" && state.data.name && state.data.email) {
        return { step: "validating", data: state.data as FormData };
      }
      return state;
    case "validating":
      if (action.type === "VALIDATION_PASS") {
        return { step: "submitting", data: state.data, attemptCount: 1 };
      }
      return state;
    case "submitting":
      if (action.type === "SUBMIT_SUCCESS") {
        return { step: "success", data: state.data, response: action.response };
      }
      if (action.type === "SUBMIT_FAIL") {
        return { step: "error", data: state.data, error: action.error, canRetry: state.attemptCount < 3 };
      }
      return state;
    case "error":
      if (action.type === "RETRY" && state.canRetry) {
        return { step: "validating", data: state.data };
      }
      return state;
    case "success":
      return state; // Terminal state
  }
}
```

## Pattern Matching Utilities

```typescript
// Simple pattern matching helper
type Pattern<T extends { type: string }> = {
  [K in T["type"]]: (value: Extract<T, { type: K }>) => void;
};

function match<T extends { type: string }>(value: T, patterns: Pattern<T>): void {
  const handler = patterns[value.type as T["type"]];
  handler(value as Extract<T, { type: T["type"] }>);
}

type AppEvent =
  | { type: "page_view"; url: string }
  | { type: "click"; elementId: string }
  | { type: "error"; message: string; stack?: string };

function trackEvent(event: AppEvent): void {
  match(event, {
    page_view: ({ url }) => console.log(`Page: ${url}`),
    click: ({ elementId }) => console.log(`Click: ${elementId}`),
    error: ({ message, stack }) => console.error(message, stack),
  });
}

// Exhaustive matching with return values
type MatchReturn<T extends { type: string }, R> = {
  [K in T["type"]]: (value: Extract<T, { type: K }>) => R;
};

function matchReturn<T extends { type: string }, R>(
  value: T,
  patterns: MatchReturn<T, R>
): R {
  const handler = patterns[value.type as T["type"]];
  return handler(value as Extract<T, { type: T["type"] }>);
}
```
