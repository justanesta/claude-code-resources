# Error Handling Patterns Reference

Comprehensive reference for structured error handling in modern JavaScript web applications.

---

## Custom Error Hierarchy

### Base application error

```javascript
class AppError extends Error {
  constructor(message, code, context = {}) {
    super(message);
    this.name = this.constructor.name;
    this.code = code;
    this.context = context;
    this.timestamp = Date.now();
  }

  toJSON() {
    return {
      name: this.name,
      message: this.message,
      code: this.code,
      context: this.context,
      timestamp: this.timestamp,
    };
  }
}
```

### Specific error types

```javascript
class HttpError extends AppError {
  constructor(status, body = "") {
    super(`HTTP ${status}`, "HTTP_ERROR", { status, body });
    this.status = status;
  }

  get isClientError() {
    return this.status >= 400 && this.status < 500;
  }

  get isServerError() {
    return this.status >= 500;
  }
}

class ValidationError extends AppError {
  constructor(field, message, value) {
    super(message, "VALIDATION_ERROR", { field, value });
    this.field = field;
  }
}

class NetworkError extends AppError {
  constructor(cause) {
    super("Network request failed", "NETWORK_ERROR", { cause: cause?.message });
  }
}

class TimeoutError extends AppError {
  constructor(operation, durationMs) {
    super(`${operation} timed out after ${durationMs}ms`, "TIMEOUT_ERROR", {
      operation,
      durationMs,
    });
  }
}
```

---

## Try/Catch Patterns

### Structured error boundaries

```javascript
// Catch at the boundary, not at every call site
async function handleUserAction(action) {
  try {
    const result = await action();
    return { success: true, data: result };
  } catch (error) {
    if (error instanceof ValidationError) {
      showFieldError(error.field, error.message);
      return { success: false, error };
    }
    if (error instanceof HttpError && error.status === 401) {
      redirectToLogin();
      return { success: false, error };
    }
    // Unexpected errors — log and show generic message
    logError(error);
    showGenericError("Something went wrong. Please try again.");
    return { success: false, error };
  }
}
```

### Selective catching by type

```javascript
async function fetchUserData(userId) {
  try {
    return await api.get(`/users/${userId}`);
  } catch (error) {
    if (error instanceof HttpError && error.status === 404) {
      return null; // User not found is an expected case
    }
    throw error; // Re-throw unexpected errors
  }
}
```

---

## Result Type Pattern

An alternative to try/catch that makes error handling explicit in return values.

```javascript
class Result {
  #value;
  #error;
  #ok;

  constructor(ok, value, error) {
    this.#ok = ok;
    this.#value = value;
    this.#error = error;
  }

  static ok(value) { return new Result(true, value, null); }
  static err(error) { return new Result(false, null, error); }

  get isOk() { return this.#ok; }
  get isErr() { return !this.#ok; }

  unwrap() {
    if (this.#ok) return this.#value;
    throw this.#error;
  }

  unwrapOr(fallback) {
    return this.#ok ? this.#value : fallback;
  }

  map(fn) {
    return this.#ok ? Result.ok(fn(this.#value)) : this;
  }

  match({ ok, err }) {
    return this.#ok ? ok(this.#value) : err(this.#error);
  }
}

// Wrap async functions to return Result
async function tryCatch(fn) {
  try {
    return Result.ok(await fn());
  } catch (error) {
    return Result.err(error);
  }
}

// Usage
const result = await tryCatch(() => api.get("/users/42"));
const displayName = result
  .map((user) => `${user.firstName} ${user.lastName}`)
  .unwrapOr("Unknown User");
```

---

## Form Validation Errors

```javascript
// Validation rules as composable functions
const required = (value, field) =>
  !value?.toString().trim() ? `${field} is required` : null;

const minLength = (min) => (value, field) =>
  value?.length < min ? `${field} must be at least ${min} characters` : null;

const isEmail = (value, field) =>
  !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value) ? `${field} must be a valid email` : null;

// Multi-field validation collecting all errors
function validateForm(data, rules) {
  const errors = [];
  for (const [field, fieldRules] of Object.entries(rules)) {
    for (const rule of fieldRules) {
      const error = rule(data[field], field, data);
      if (error) {
        errors.push(new ValidationError(field, error, data[field]));
        break;
      }
    }
  }
  if (errors.length > 0) {
    throw new AppError("Validation failed", "VALIDATION_AGGREGATE", { errors });
  }
  return data;
}
```

---

## Global Error Handlers

```javascript
// Unhandled promise rejections
window.addEventListener("unhandledrejection", (event) => {
  event.preventDefault();
  logError({
    type: "unhandled_rejection",
    error: event.reason instanceof Error ? event.reason.message : String(event.reason),
    stack: event.reason?.stack,
  });
});

// Global error handler
window.addEventListener("error", (event) => {
  if (event.filename && !event.filename.includes(window.location.origin)) return;
  logError({
    type: "global_error",
    message: event.message,
    filename: event.filename,
    lineno: event.lineno,
    stack: event.error?.stack,
  });
});
```

---

## Async Error Boundary

```javascript
async function withAsyncBoundary(fn, options = {}) {
  const { fallback, onError, retries = 0 } = options;

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === retries) {
        onError?.(error);
        if (fallback !== undefined) return fallback;
        throw error;
      }
    }
  }
}

// Usage
const userData = await withAsyncBoundary(
  () => api.get("/users/me"),
  {
    fallback: { name: "Guest", isAuthenticated: false },
    onError: (err) => console.warn("Failed to load user:", err),
    retries: 2,
  }
);
```

---

## Best Practices

- **Create specific error types** — use `instanceof` checks instead of string matching on error messages
- **Catch at boundaries** — handle errors at route/service/component boundaries, not at every function call
- **Always re-throw unexpected errors** — catch only the error types you can handle; let others propagate
- **Use `Error.cause`** — chain errors with `new Error("Context message", { cause: originalError })`
- **Log context, not just messages** — include request URLs, user IDs, and operation names in error logs
- **Never swallow errors silently** — every catch block should either handle the error or re-throw it

```javascript
// Error.cause for error chaining (ES2022)
async function getOrderDetails(orderId) {
  try {
    return await api.get(`/orders/${orderId}`);
  } catch (error) {
    throw new AppError(
      `Failed to load order ${orderId}`,
      "ORDER_LOAD_ERROR",
      { orderId, cause: error }
    );
  }
}
```

source: MDN Web Docs, JavaScript.info, web.dev
