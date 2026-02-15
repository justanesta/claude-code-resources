---
name: webdev-javascript-fundamentals
description: Modern JavaScript fundamentals for web development — ES2024+ patterns, async/await, array methods, modules, fetch API, and error handling
---

# JavaScript Fundamentals for Web Development

## Core Principles

1. **Modern ES2024+ syntax** — Use `const`/`let`, arrow functions, optional chaining, nullish coalescing, and structured clone as defaults
2. **Immutability by default** — Prefer `const`, non-mutating array methods (`toSorted`, `toReversed`, `toSpliced`), and `structuredClone` for deep copies
3. **Async-first patterns** — Use `async`/`await` over raw Promises; handle errors at appropriate boundaries with structured error types
4. **Declarative array transformations** — Chain `map`, `filter`, `reduce`, `flatMap` instead of imperative loops
5. **Explicit module boundaries** — Use ES modules with named exports; keep module APIs small and focused

---

## Modern Variable Declarations and Destructuring

Use `const` for all bindings that are not reassigned. Use `let` only when reassignment is necessary. Never use `var`.

```javascript
// Destructuring objects with defaults and renaming
const { name, age = 0, address: { city } = {} } = user;

// Destructuring arrays with skip and rest
const [first, , third, ...remaining] = items;

// Nested destructuring in function parameters
function createOrder({ product: { id, name }, quantity = 1, discount = 0 }) {
  const total = calculatePrice(id, quantity) * (1 - discount);
  return { id: crypto.randomUUID(), product: name, quantity, total };
}

// Nullish coalescing and optional chaining
const displayName = user?.profile?.displayName ?? user?.name ?? "Anonymous";
const theme = settings?.theme ?? "system";

// Structured clone for deep copies (no prototype or function copying)
const snapshot = structuredClone(state);
```

See [async-patterns.md](references/async-patterns.md) for: advanced destructuring in async contexts and parameter handling.

---

## Async/Await Patterns

Always use `async`/`await` for asynchronous code. Handle errors at the appropriate boundary rather than on every call.

```javascript
// Parallel execution with Promise.all
async function loadDashboard(userId) {
  const [profile, orders, notifications] = await Promise.all([
    fetchProfile(userId),
    fetchOrders(userId),
    fetchNotifications(userId),
  ]);
  return { profile, orders, notifications };
}

// Error boundary with structured error handling
async function fetchWithRetry(url, options = {}, retries = 3) {
  for (let attempt = 1; attempt <= retries; attempt++) {
    try {
      const response = await fetch(url, options);
      if (!response.ok) throw new HttpError(response.status, await response.text());
      return await response.json();
    } catch (error) {
      if (attempt === retries) throw error;
      await new Promise((r) => setTimeout(r, 2 ** attempt * 100));
    }
  }
}

// AbortController for cancellation
async function searchWithTimeout(query, timeoutMs = 5000) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(`/api/search?q=${encodeURIComponent(query)}`, {
      signal: controller.signal,
    });
  } finally {
    clearTimeout(timeoutId);
  }
}
```

See [async-patterns.md](references/async-patterns.md) for: Promise.allSettled, async iteration, AbortController patterns, and error propagation.

---

## Array Methods

Prefer non-mutating methods. Use the new ES2023+ immutable array methods (`toSorted`, `toReversed`, `toSpliced`) over their mutating counterparts.

```javascript
// Chained transformations — filter, map, sort immutably
const activeUserEmails = users
  .filter((user) => user.isActive && user.emailVerified)
  .map((user) => user.email.toLowerCase())
  .toSorted((a, b) => a.localeCompare(b));

// reduce for aggregation
const orderTotalsByCustomer = orders.reduce((totals, order) => {
  totals[order.customerId] = (totals[order.customerId] ?? 0) + order.amount;
  return totals;
}, {});

// flatMap for one-to-many transformations
const allTags = posts.flatMap((post) => post.tags);

// Object.groupBy (ES2024)
const usersByRole = Object.groupBy(users, (user) => user.role);

// find and some for early termination
const admin = users.find((user) => user.role === "admin");
const hasExpired = tokens.some((token) => token.expiresAt < Date.now());
```

See [array-methods.md](references/array-methods.md) for: reduce patterns, groupBy, toSorted/toReversed/toSpliced, and performance considerations.

---

## ES Modules

Use named exports for most cases. Use default exports only for a module's primary entity when it has a clear single purpose.

```javascript
// Named exports — preferred
export function validateEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}
export function sanitizeInput(input) {
  return input.replace(/[<>&"']/g, (ch) => `&#${ch.charCodeAt(0)};`);
}

// Re-exporting from a barrel file (index.js)
export { validateEmail, sanitizeInput } from "./validation.js";
export { formatDate, formatCurrency } from "./formatting.js";

// Dynamic import for code splitting
async function loadEditor() {
  const { EditorModule } = await import("./editor/index.js");
  return new EditorModule({ container: document.getElementById("editor") });
}

// Import assertions for JSON (ES2025)
import config from "./config.json" with { type: "json" };
```

See [module-patterns.md](references/module-patterns.md) for: barrel file best practices, dynamic import patterns, tree shaking, and circular dependency avoidance.

---

## Fetch API and HTTP Requests

Use the Fetch API with structured request/response handling. Always check `response.ok` before parsing.

```javascript
// Typed request helper with automatic JSON handling
async function apiRequest(endpoint, { method = "GET", body, headers = {} } = {}) {
  const config = {
    method,
    headers: { "Content-Type": "application/json", ...headers },
    ...(body && { body: JSON.stringify(body) }),
  };
  const response = await fetch(`/api${endpoint}`, config);
  if (!response.ok) {
    throw new HttpError(response.status, await response.text());
  }
  if (response.status === 204) return null;
  return response.json();
}

// Usage
const user = await apiRequest("/users/42");
const created = await apiRequest("/users", { method: "POST", body: { name: "Ada" } });
```

See [fetch-api-patterns.md](references/fetch-api-patterns.md) for: interceptors, streaming responses, upload progress, retry logic, and request cancellation.

---

## Error Handling Patterns

Create structured error hierarchies. Catch errors at boundaries, not at every call site.

```javascript
// Custom error classes
class AppError extends Error {
  constructor(message, code, context = {}) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
    this.context = context;
  }
}

class ValidationError extends AppError {
  constructor(field, message) {
    super(message, "VALIDATION_ERROR", { field });
  }
}

class HttpError extends AppError {
  constructor(status, body) {
    super(`HTTP ${status}`, "HTTP_ERROR", { status, body });
  }
}

// Global unhandled rejection handler
window.addEventListener("unhandledrejection", (event) => {
  console.error("Unhandled promise rejection:", event.reason);
  event.preventDefault();
});
```

See [error-handling-patterns.md](references/error-handling-patterns.md) for: Result types, error boundaries, global handlers, and error logging strategies.

---

## Anti-Patterns

| Avoid | Use Instead |
|---|---|
| `var x = 10` | `const x = 10` or `let x = 10` |
| `arr.sort()` mutating in place | `arr.toSorted()` returning new array |
| `.then().catch()` chains | `async`/`await` with `try`/`catch` |
| `for (let i = 0; i < arr.length; i++)` | `arr.map()`, `arr.filter()`, `for...of` |
| `fetch(url).then(r => r.json())` without status check | Check `response.ok` before parsing |
| `JSON.parse(JSON.stringify(obj))` for deep clone | `structuredClone(obj)` |
| `== null` loose equality | `=== null \|\| === undefined` or `??` operator |
| Catching errors at every call site | Error boundaries at service/route level |
| `require()` CommonJS in browsers | `import`/`export` ES modules |
| Nested `.then` callbacks (Promise hell) | `await` sequential or `Promise.all` parallel |

---

## Performance

- **Use `AbortController`** — Cancel in-flight requests when components unmount or user navigates away to prevent memory leaks
- **Debounce and throttle** — Wrap high-frequency event handlers (scroll, resize, input) with `requestAnimationFrame` or custom debounce
- **Lazy load modules** — Use dynamic `import()` for routes and heavy libraries; split bundles at route boundaries
- **Prefer `for...of` for large iterations** — Array method chains create intermediate arrays; use `for...of` with early `break` for large datasets
- **Use `Map` and `Set` over plain objects** — `Map` provides O(1) key lookup without prototype chain issues; `Set` deduplicates in O(n)
- **Batch DOM reads and writes** — Group `getBoundingClientRect` calls together, then apply mutations to avoid forced layout thrashing

source: MDN Web Docs, TC39 Proposals, JavaScript.info, web.dev
