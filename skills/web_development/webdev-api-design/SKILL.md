---
name: API Design
description: REST API design patterns, conventions, error handling, pagination, versioning, and rate limiting for building consistent and scalable web APIs
---

# API Design

## Core Principles

1. **Resource-Oriented Design** -- Model APIs around resources (nouns), not actions (verbs). Use HTTP methods to express operations on those resources.
2. **Consistency** -- Apply uniform naming conventions, response structures, error formats, and pagination across every endpoint. Consumers should learn the pattern once and apply it everywhere.
3. **Standards Compliance** -- Follow established RFCs and specifications (HTTP semantics, RFC 7807 for errors, OpenAPI for documentation). Standards reduce ambiguity and enable tooling.
4. **Evolvability** -- Design APIs that can grow without breaking existing clients. Use versioning strategies, additive changes, and deprecation policies.
5. **Least Surprise** -- Endpoints should behave the way experienced developers expect. Status codes, method semantics, and error responses should align with HTTP conventions.

---

## REST Resource Design

Use plural nouns for collections. Nest resources to express ownership. Map CRUD operations to HTTP methods.

```http
# Collection operations
GET    /api/v1/users                  # List users
POST   /api/v1/users                  # Create a user

# Instance operations
GET    /api/v1/users/42               # Get user 42
PUT    /api/v1/users/42               # Replace user 42
PATCH  /api/v1/users/42               # Partially update user 42
DELETE /api/v1/users/42               # Delete user 42

# Nested resources (express ownership)
GET    /api/v1/users/42/orders        # List orders for user 42
POST   /api/v1/users/42/orders        # Create order for user 42
GET    /api/v1/users/42/orders/7      # Get specific order

# Actions as sub-resources (when CRUD doesn't fit)
POST   /api/v1/orders/7/cancel        # Cancel order 7
POST   /api/v1/users/42/verify-email  # Trigger email verification
```

See [rest-conventions.md](references/rest-conventions.md) for: resource naming rules, HTTP method semantics, status code selection, and HATEOAS links.

---

## Request/Response Patterns

Use correct HTTP status codes. Return consistent envelope structures. Support content negotiation.

```json
// Successful response -- 200 OK
{
  "data": {
    "id": "usr_a1b2c3",
    "type": "user",
    "attributes": {
      "email": "jane@example.com",
      "name": "Jane Park",
      "created_at": "2025-09-15T08:30:00Z"
    }
  },
  "meta": {
    "request_id": "req_x7k9m2"
  }
}

// Collection response -- 200 OK
{
  "data": [
    { "id": "usr_a1b2c3", "type": "user", "attributes": { "name": "Jane Park" } },
    { "id": "usr_d4e5f6", "type": "user", "attributes": { "name": "Alex Chen" } }
  ],
  "meta": {
    "total_count": 143,
    "request_id": "req_p3q8r1"
  },
  "pagination": {
    "cursor": "eyJpZCI6InVzcl9kNGU1ZjYifQ==",
    "has_more": true
  }
}
```

| Range | Meaning | Common Codes |
|-------|---------|-------------|
| 2xx | Success | 200 OK, 201 Created, 204 No Content |
| 3xx | Redirection | 301 Moved, 304 Not Modified |
| 4xx | Client error | 400 Bad Request, 401 Unauthorized, 403 Forbidden, 404 Not Found, 409 Conflict, 422 Unprocessable, 429 Too Many Requests |
| 5xx | Server error | 500 Internal, 502 Bad Gateway, 503 Unavailable |

---

## Pagination Patterns

Choose a pagination strategy based on data characteristics. Cursor-based pagination is the most robust default.

```json
// Cursor-based pagination (recommended default)
// Request:  GET /api/v1/orders?limit=20&cursor=eyJpZCI6MTAwfQ==
// Response:
{
  "data": [ "..." ],
  "pagination": {
    "next_cursor": "eyJpZCI6MTIwfQ==",
    "previous_cursor": "eyJpZCI6MTAxfQ==",
    "has_more": true,
    "limit": 20
  }
}

// Offset-based pagination (simple but fragile with mutations)
// Request:  GET /api/v1/products?limit=20&offset=40
// Response:
{
  "data": [ "..." ],
  "pagination": {
    "total_count": 582,
    "limit": 20,
    "offset": 40
  }
}
```

See [pagination-patterns.md](references/pagination-patterns.md) for: cursor encoding, keyset pagination, infinite scroll support, and total count trade-offs.

---

## Error Response Design

Follow RFC 7807 (Problem Details for HTTP APIs). Include machine-readable codes alongside human-readable messages.

```json
// Single error -- 422 Unprocessable Entity
{
  "type": "https://api.example.com/errors/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "detail": "The request body contains invalid fields.",
  "instance": "/api/v1/users",
  "request_id": "req_x7k9m2",
  "errors": [
    {
      "field": "email",
      "code": "invalid_format",
      "message": "Must be a valid email address."
    },
    {
      "field": "age",
      "code": "out_of_range",
      "message": "Must be between 13 and 150.",
      "meta": { "min": 13, "max": 150 }
    }
  ]
}
```

See [error-handling-patterns.md](references/error-handling-patterns.md) for: RFC 7807 details, error code registries, validation error structures, and retry-after headers.

---

## API Versioning Strategies

Version APIs to allow evolution without breaking clients. Prefer URL-path versioning for simplicity.

```http
# URL path versioning (most common, most visible)
GET /api/v1/users
GET /api/v2/users

# Header versioning
GET /api/users
Accept: application/vnd.example.v2+json

# Query parameter versioning
GET /api/users?version=2

# Deprecation headers in responses
HTTP/1.1 200 OK
Deprecation: Sun, 01 Jun 2026 00:00:00 GMT
Sunset: Sun, 01 Dec 2026 00:00:00 GMT
Link: </api/v2/users>; rel="successor-version"
```

See [versioning-patterns.md](references/versioning-patterns.md) for: version negotiation, deprecation timelines, migration guides, and backward-compatible changes.

---

## Rate Limiting and Throttling

Protect APIs with rate limits. Communicate limits clearly through standard headers.

```http
# Rate limit headers (IETF draft standard)
HTTP/1.1 200 OK
RateLimit-Limit: 1000
RateLimit-Remaining: 742
RateLimit-Reset: 1672531200

# Rate limit exceeded -- 429 Too Many Requests
HTTP/1.1 429 Too Many Requests
Retry-After: 30
RateLimit-Limit: 1000
RateLimit-Remaining: 0
RateLimit-Reset: 1672531200
Content-Type: application/problem+json

{
  "type": "https://api.example.com/errors/rate-limit-exceeded",
  "title": "Rate Limit Exceeded",
  "status": 429,
  "detail": "You have exceeded 1000 requests per hour. Try again in 30 seconds.",
  "retry_after": 30
}
```

Common strategies: **fixed window** (count per interval), **sliding window** (rolling window), **token bucket** (replenishing tokens), **leaky bucket** (constant drain rate).

---

## Anti-Patterns

| Avoid | Use Instead |
|-------|-------------|
| `GET /getUsers`, `POST /createUser` | `GET /users`, `POST /users` -- let HTTP methods convey the action |
| `200 OK` with error body | Proper status codes: `400`, `422`, `404`, `500` |
| Unstructured error strings | RFC 7807 Problem Details with `type`, `title`, `status`, `detail` |
| Returning unbounded collections | Always paginate -- default `limit` of 20-100 with a max cap |
| Nested URLs deeper than 3 levels | Flatten: `/orders/7` instead of `/users/42/accounts/3/orders/7` |
| Breaking changes without versioning | Version the API and use `Deprecation`/`Sunset` headers |
| Exposing database IDs directly | Use prefixed opaque IDs (`usr_a1b2c3`) or UUIDs |
| Inconsistent naming (`userId` vs `user_id`) | Pick one convention (snake_case recommended) and enforce it globally |
| Custom date formats | ISO 8601: `2025-09-15T08:30:00Z` |
| Ignoring `Accept` / `Content-Type` headers | Validate content types and return `406` or `415` when unsupported |

---

## Performance

- **ETags and conditional requests** -- return `ETag` on GET; honor `If-None-Match` to return `304 Not Modified`.
- **Field selection** -- allow `?fields=id,name,email` to reduce payload size for mobile clients.
- **Compression** -- enable `gzip` or `br`; respect `Accept-Encoding`.
- **Batch endpoints** -- provide `POST /api/v1/users/batch` to reduce round trips.
- **Cache-Control headers** -- set `Cache-Control`, `Vary`, and `max-age` directives appropriately.
- **Limit nested includes** -- cap `?include=orders.items` at depth 2 with record limits.
- **Async for long operations** -- return `202 Accepted` with a status URL; clients poll or use webhooks.

See [openapi-patterns.md](references/openapi-patterns.md) for: OpenAPI 3.1 specification patterns, reusable schemas, path design, and code generation workflows.

source: REST API Design Rulebook (O'Reilly), RFC 9110 (HTTP Semantics), RFC 7807 (Problem Details), OpenAPI 3.1 Specification, Google API Design Guide, Microsoft REST API Guidelines, Stripe API Reference
