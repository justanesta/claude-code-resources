# Fetch API Patterns Reference

Comprehensive reference for HTTP request patterns using the Fetch API in modern web development.

---

## Base Request Helper

A typed wrapper around fetch that handles JSON serialization and error checking.

```javascript
class ApiClient {
  #baseUrl;
  #defaultHeaders;

  constructor(baseUrl, defaultHeaders = {}) {
    this.#baseUrl = baseUrl;
    this.#defaultHeaders = {
      "Content-Type": "application/json",
      ...defaultHeaders,
    };
  }

  async #request(endpoint, options = {}) {
    const config = {
      ...options,
      headers: { ...this.#defaultHeaders, ...options.headers },
    };
    const response = await fetch(`${this.#baseUrl}${endpoint}`, config);
    if (!response.ok) {
      throw new HttpError(response.status, await response.text());
    }
    if (response.status === 204) return null;
    return response.json();
  }

  get(endpoint, options) {
    return this.#request(endpoint, { ...options, method: "GET" });
  }

  post(endpoint, body, options) {
    return this.#request(endpoint, {
      ...options, method: "POST", body: JSON.stringify(body),
    });
  }

  put(endpoint, body, options) {
    return this.#request(endpoint, {
      ...options, method: "PUT", body: JSON.stringify(body),
    });
  }

  patch(endpoint, body, options) {
    return this.#request(endpoint, {
      ...options, method: "PATCH", body: JSON.stringify(body),
    });
  }

  delete(endpoint, options) {
    return this.#request(endpoint, { ...options, method: "DELETE" });
  }
}
```

---

## CRUD Operations

### GET — Retrieve resources

```javascript
const api = new ApiClient("/api");
const users = await api.get("/users");

// GET with query parameters
async function searchUsers(query, page = 1, limit = 20) {
  const params = new URLSearchParams({ q: query, page, limit });
  return api.get(`/users?${params}`);
}
```

### POST — Create resources

```javascript
const newUser = await api.post("/users", {
  name: "Ada Lovelace",
  email: "ada@example.com",
});

// File upload with FormData
async function uploadFile(file, metadata = {}) {
  const formData = new FormData();
  formData.append("file", file);
  formData.append("metadata", JSON.stringify(metadata));

  const response = await fetch("/api/uploads", {
    method: "POST",
    body: formData, // Do NOT set Content-Type — browser sets multipart boundary
  });
  if (!response.ok) throw new HttpError(response.status, await response.text());
  return response.json();
}
```

### PUT / PATCH / DELETE

```javascript
await api.put("/users/42", { name: "Ada Lovelace", role: "admin" });
await api.patch("/users/42", { role: "admin" });
await api.delete("/users/42");
```

---

## Authentication Headers

```javascript
function createAuthClient(baseUrl) {
  const client = new ApiClient(baseUrl, {
    Authorization: `Bearer ${localStorage.getItem("access_token")}`,
  });
  return client;
}

// CORS credentials for cookie-based auth
const response = await fetch("https://api.example.com/data", {
  credentials: "include",
  mode: "cors",
});
```

---

## Retry Logic

```javascript
async function fetchWithRetry(url, options = {}, retryOptions = {}) {
  const { retries = 3, baseDelay = 500, retryOn = [502, 503, 504] } = retryOptions;

  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      const response = await fetch(url, options);
      if (!response.ok && retryOn.includes(response.status) && attempt < retries) {
        const delay = Math.min(baseDelay * 2 ** attempt, 10_000);
        await new Promise((r) => setTimeout(r, delay * (0.5 + Math.random() * 0.5)));
        continue;
      }
      return response;
    } catch (error) {
      if (attempt === retries) throw error;
      await new Promise((r) => setTimeout(r, baseDelay * 2 ** attempt));
    }
  }
}
```

---

## Request Cancellation

### AbortController with timeout

```javascript
async function fetchWithTimeout(url, options = {}, timeoutMs = 10_000) {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), timeoutMs);

  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } catch (error) {
    if (error.name === "AbortError") {
      throw new AppError("Request timed out", "TIMEOUT", { url, timeoutMs });
    }
    throw error;
  } finally {
    clearTimeout(timeoutId);
  }
}

// Using AbortSignal.timeout (modern browsers)
const response = await fetch(url, { signal: AbortSignal.timeout(10_000) });
```

### Cancel on navigation or component unmount

```javascript
function createRequestScope() {
  const controller = new AbortController();
  return {
    signal: controller.signal,
    fetch: (url, options = {}) =>
      fetch(url, { ...options, signal: controller.signal }),
    abort: () => controller.abort(),
  };
}

const scope = createRequestScope();
const data = await scope.fetch("/api/data");
// On cleanup:
scope.abort();
```

---

## Streaming Responses

### Server-Sent Events via fetch

```javascript
async function* streamSSE(url, signal) {
  const response = await fetch(url, {
    headers: { Accept: "text/event-stream" },
    signal,
  });
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let buffer = "";

  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;

      buffer += decoder.decode(value, { stream: true });
      const events = buffer.split("\n\n");
      buffer = events.pop();

      for (const event of events) {
        const data = event
          .split("\n")
          .filter((line) => line.startsWith("data: "))
          .map((line) => line.slice(6))
          .join("\n");
        if (data) yield JSON.parse(data);
      }
    }
  } finally {
    reader.releaseLock();
  }
}
```

### Download with progress

```javascript
async function downloadWithProgress(url, onProgress) {
  const response = await fetch(url);
  const total = Number(response.headers.get("Content-Length")) || 0;
  const reader = response.body.getReader();
  const chunks = [];
  let loaded = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    loaded += value.length;
    if (total > 0) onProgress({ loaded, total, percent: (loaded / total) * 100 });
  }
  return new Blob(chunks);
}
```

---

## Headers and Content Types

```javascript
const response = await fetch("/api/data", {
  headers: {
    "Content-Type": "application/json",
    "Accept": "application/json",
    "X-Request-ID": crypto.randomUUID(),
  },
});

// Reading response headers
const rateLimitRemaining = response.headers.get("X-RateLimit-Remaining");
const retryAfter = response.headers.get("Retry-After");
```

source: MDN Web Docs, web.dev, JavaScript.info
