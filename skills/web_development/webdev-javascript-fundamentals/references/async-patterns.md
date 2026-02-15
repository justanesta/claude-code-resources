# Async/Await Patterns Reference

Comprehensive reference for asynchronous JavaScript patterns in modern web development.

---

## Promise Combinators

### Promise.all — Fail fast on any rejection

Use when all results are required and any failure should abort the operation.

```javascript
async function loadUserDashboard(userId) {
  try {
    const [profile, orders, preferences] = await Promise.all([
      fetchProfile(userId),
      fetchOrders(userId),
      fetchPreferences(userId),
    ]);
    return { profile, orders, preferences };
  } catch (error) {
    // First rejection cancels everything — handle at this boundary
    throw new AppError("Dashboard load failed", "DASHBOARD_ERROR", { userId, cause: error });
  }
}
```

### Promise.allSettled — Collect all results regardless of failures

Use when partial results are acceptable and you need to handle each outcome individually.

```javascript
async function sendNotifications(users, message) {
  const results = await Promise.allSettled(
    users.map((user) => sendNotification(user.id, message))
  );

  const succeeded = results.filter((r) => r.status === "fulfilled").map((r) => r.value);
  const failed = results.filter((r) => r.status === "rejected").map((r) => r.reason);

  if (failed.length > 0) {
    console.warn(`${failed.length}/${results.length} notifications failed`, failed);
  }

  return { succeeded, failed, total: results.length };
}
```

### Promise.race — First settled result wins

Use for timeouts and competitive fetching from multiple sources.

```javascript
function withTimeout(promise, ms, message = "Operation timed out") {
  const timeout = new Promise((_, reject) =>
    setTimeout(() => reject(new AppError(message, "TIMEOUT")), ms)
  );
  return Promise.race([promise, timeout]);
}

// Competitive fetching from multiple CDNs
async function fetchFromFastestCDN(resource) {
  const cdns = ["https://cdn1.example.com", "https://cdn2.example.com"];
  return Promise.race(cdns.map((base) => fetch(`${base}/${resource}`)));
}
```

### Promise.any — First fulfilled result wins (ignores rejections)

Use when you need at least one success from multiple sources.

```javascript
async function resolveFromMirrors(url) {
  try {
    return await Promise.any([
      fetch(`https://mirror1.example.com${url}`),
      fetch(`https://mirror2.example.com${url}`),
      fetch(`https://mirror3.example.com${url}`),
    ]);
  } catch (error) {
    // AggregateError — all promises rejected
    throw new AppError("All mirrors failed", "MIRROR_ERROR", {
      errors: error.errors,
    });
  }
}
```

---

## AbortController Patterns

### Basic cancellation

```javascript
function createCancellableRequest(url, options = {}) {
  const controller = new AbortController();

  const promise = fetch(url, {
    ...options,
    signal: controller.signal,
  });

  return {
    promise,
    cancel: () => controller.abort(),
  };
}

// Usage
const { promise, cancel } = createCancellableRequest("/api/data");
// Cancel after 5s or on user action
setTimeout(cancel, 5000);
```

### Linked abort signals (ES2024 AbortSignal.any)

```javascript
async function fetchWithCancellation(url, externalSignal) {
  const timeoutSignal = AbortSignal.timeout(10_000);
  const combinedSignal = AbortSignal.any([timeoutSignal, externalSignal]);

  const response = await fetch(url, { signal: combinedSignal });
  if (!response.ok) throw new HttpError(response.status, await response.text());
  return response.json();
}

// Usage — the request cancels on timeout OR external abort
const controller = new AbortController();
const data = await fetchWithCancellation("/api/search", controller.signal);
```

### Search input with abort on new keystroke

```javascript
function createSearchHandler(endpoint) {
  let currentController = null;

  return async function handleSearch(query) {
    // Abort previous in-flight request
    currentController?.abort();
    currentController = new AbortController();

    if (!query.trim()) return [];

    try {
      const response = await fetch(
        `${endpoint}?q=${encodeURIComponent(query)}`,
        { signal: currentController.signal }
      );
      if (!response.ok) throw new HttpError(response.status);
      return response.json();
    } catch (error) {
      if (error.name === "AbortError") return null; // Silently ignore aborted requests
      throw error;
    }
  };
}

const search = createSearchHandler("/api/search");
inputElement.addEventListener("input", (e) => search(e.target.value));
```

---

## Async Iteration

### for-await-of with async generators

```javascript
async function* paginateAPI(endpoint, pageSize = 50) {
  let cursor = null;
  while (true) {
    const params = new URLSearchParams({ limit: pageSize });
    if (cursor) params.set("cursor", cursor);

    const response = await fetch(`${endpoint}?${params}`);
    const { data, nextCursor } = await response.json();

    yield* data;

    if (!nextCursor) break;
    cursor = nextCursor;
  }
}

// Usage — processes items one at a time, fetches pages lazily
for await (const item of paginateAPI("/api/items")) {
  await processItem(item);
}
```

### ReadableStream consumption

```javascript
async function* streamLines(response) {
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split("\n");
      buffer = lines.pop(); // Keep incomplete line in buffer

      for (const line of lines) {
        if (line.trim()) yield line;
      }
    }
    if (buffer.trim()) yield buffer;
  } finally {
    reader.releaseLock();
  }
}

// Usage — streaming server-sent events
const response = await fetch("/api/stream");
for await (const line of streamLines(response)) {
  const event = JSON.parse(line);
  handleEvent(event);
}
```

---

## Error Handling in Async Code

### Structured error boundaries

```javascript
async function withErrorBoundary(fn, fallback, onError) {
  try {
    return await fn();
  } catch (error) {
    onError?.(error);
    return fallback;
  }
}

// Usage
const users = await withErrorBoundary(
  () => fetchUsers(),
  [],  // fallback to empty array
  (err) => console.error("Failed to fetch users:", err)
);
```

### Sequential async with error accumulation

```javascript
async function processAllWithErrors(items, processor) {
  const results = [];
  const errors = [];

  for (const item of items) {
    try {
      results.push(await processor(item));
    } catch (error) {
      errors.push({ item, error });
    }
  }

  return { results, errors };
}
```

### Retry with exponential backoff and jitter

```javascript
async function retryWithBackoff(fn, options = {}) {
  const { retries = 3, baseDelay = 200, maxDelay = 10_000 } = options;

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      if (attempt === retries) throw error;

      const delay = Math.min(baseDelay * 2 ** attempt, maxDelay);
      const jitter = delay * (0.5 + Math.random() * 0.5);
      await new Promise((resolve) => setTimeout(resolve, jitter));
    }
  }
}
```

source: MDN Web Docs, TC39 Proposals, JavaScript.info
