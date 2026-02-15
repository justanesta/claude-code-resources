# REST Conventions Reference

Comprehensive guide to RESTful resource naming, HTTP method semantics, status code selection, and HATEOAS implementation.

---

## Resource Naming Rules

### Use Plural Nouns for Collections

```http
# Correct -- plural nouns
GET /api/v1/users
GET /api/v1/products
GET /api/v1/order-items

# Incorrect -- singular or verbs
GET /api/v1/user
GET /api/v1/getProducts
GET /api/v1/orderItem
```

### Naming Conventions

- Use **kebab-case** for multi-word resource names: `/order-items`, `/shipping-addresses`
- Use **snake_case** for JSON field names: `first_name`, `created_at`, `order_id`
- Use **lowercase** exclusively in URLs -- never mix casing
- Avoid file extensions in URLs: `/users` not `/users.json`

### Resource Hierarchy

Nest resources to express parent-child ownership. Limit nesting depth to 2-3 levels.

```http
# Good -- clear ownership
GET  /api/v1/users/42/orders              # Orders belonging to user 42
GET  /api/v1/users/42/orders/7            # Specific order of user 42
POST /api/v1/users/42/orders              # Create order for user 42

# Good -- flatten when the child has a global identity
GET  /api/v1/orders/7                     # Order by global ID
GET  /api/v1/orders/7/line-items          # Line items within order

# Avoid -- too deeply nested
GET  /api/v1/users/42/orders/7/line-items/3/reviews
# Better -- flatten
GET  /api/v1/line-items/3/reviews
```

### Singleton Sub-Resources

Some resources are inherently singular within their parent context.

```http
GET  /api/v1/users/42/profile             # User's single profile
PUT  /api/v1/users/42/profile             # Replace profile
GET  /api/v1/users/42/settings            # User's settings
```

### Action Endpoints

When an operation doesn't map cleanly to CRUD, use a verb as a sub-resource with POST.

```http
POST /api/v1/orders/7/cancel
POST /api/v1/users/42/verify-email
POST /api/v1/reports/monthly/generate
POST /api/v1/caches/invalidate
```

### Filtering, Sorting, and Searching

Use query parameters for collection operations. Do not encode filters in the path.

```http
# Filtering
GET /api/v1/orders?status=shipped&created_after=2025-01-01

# Sorting (prefix with - for descending)
GET /api/v1/products?sort=-created_at,name

# Searching
GET /api/v1/users?q=jane+park

# Field selection
GET /api/v1/users?fields=id,name,email

# Combined
GET /api/v1/orders?status=pending&sort=-created_at&fields=id,total&limit=20
```

---

## HTTP Method Semantics

### Method Properties

| Method | Safe | Idempotent | Request Body | Typical Use |
|--------|------|------------|-------------|-------------|
| GET | Yes | Yes | No | Retrieve resource(s) |
| HEAD | Yes | Yes | No | Check existence, get headers only |
| POST | No | No | Yes | Create resource, trigger action |
| PUT | No | Yes | Yes | Full replacement of a resource |
| PATCH | No | No* | Yes | Partial update of a resource |
| DELETE | No | Yes | Rarely | Remove a resource |
| OPTIONS | Yes | Yes | No | Describe allowed methods (CORS) |

*PATCH can be made idempotent with JSON Merge Patch (RFC 7396) but is not guaranteed to be.

### PUT vs PATCH

```http
# PUT -- full replacement. Omitted fields are set to defaults/null.
PUT /api/v1/users/42
Content-Type: application/json

{
  "name": "Jane Park",
  "email": "jane@example.com",
  "bio": "Updated bio",
  "role": "admin"
}

# PATCH -- partial update. Only specified fields change.
PATCH /api/v1/users/42
Content-Type: application/merge-patch+json

{
  "bio": "Updated bio"
}
```

### POST for Non-CRUD Operations

```http
# Bulk operations
POST /api/v1/users/batch
Content-Type: application/json

{
  "operations": [
    { "method": "create", "body": { "name": "User A", "email": "a@example.com" } },
    { "method": "create", "body": { "name": "User B", "email": "b@example.com" } }
  ]
}
```

---

## Status Code Selection Guide

### Success Codes (2xx)

```http
# 200 OK -- General success for GET, PUT, PATCH
GET /api/v1/users/42
HTTP/1.1 200 OK

# 201 Created -- Resource created. Include Location header.
POST /api/v1/users
HTTP/1.1 201 Created
Location: /api/v1/users/43

# 202 Accepted -- Async operation started
POST /api/v1/reports/generate
HTTP/1.1 202 Accepted
Location: /api/v1/jobs/abc123

# 204 No Content -- Success with no body (DELETE, some PUT/PATCH)
DELETE /api/v1/users/42
HTTP/1.1 204 No Content
```

### Client Error Codes (4xx)

| Code | When to Use |
|------|------------|
| 400 Bad Request | Malformed JSON, missing required fields, invalid query params |
| 401 Unauthorized | No authentication credentials provided or credentials invalid |
| 403 Forbidden | Authenticated but lacks permission for this resource/action |
| 404 Not Found | Resource does not exist (also use for unauthorized access to hide existence) |
| 405 Method Not Allowed | HTTP method not supported on this endpoint |
| 406 Not Acceptable | Cannot produce a response matching `Accept` header |
| 409 Conflict | State conflict (duplicate, concurrent edit, state machine violation) |
| 415 Unsupported Media Type | `Content-Type` not supported |
| 422 Unprocessable Entity | Well-formed request but semantic validation failed |
| 429 Too Many Requests | Rate limit exceeded. Include `Retry-After` header |

### Server Error Codes (5xx)

| Code | When to Use |
|------|------------|
| 500 Internal Server Error | Unexpected server failure -- never expose stack traces |
| 502 Bad Gateway | Upstream service returned invalid response |
| 503 Service Unavailable | Temporarily down (maintenance, overload). Include `Retry-After` |
| 504 Gateway Timeout | Upstream service timed out |

---

## HATEOAS and Hypermedia Links

Hypermedia as the Engine of Application State -- include links that tell clients what actions are available.

```json
{
  "data": {
    "id": "ord_x7k9m2",
    "type": "order",
    "attributes": {
      "status": "pending",
      "total": 59.99
    },
    "links": {
      "self": "/api/v1/orders/ord_x7k9m2",
      "cancel": "/api/v1/orders/ord_x7k9m2/cancel",
      "payment": "/api/v1/orders/ord_x7k9m2/payment",
      "customer": "/api/v1/users/usr_a1b2c3"
    }
  }
}
```

### Link Relations in Headers

```http
HTTP/1.1 200 OK
Link: </api/v1/orders?cursor=abc>; rel="next",
      </api/v1/orders?cursor=xyz>; rel="prev",
      </api/v1/orders>; rel="first"
```

### Conditional Links Based on State

Only include links for actions the client can actually perform in the current state.

```json
// Order in "pending" state -- can be cancelled or paid
{
  "links": {
    "self": "/api/v1/orders/ord_x7k9m2",
    "cancel": "/api/v1/orders/ord_x7k9m2/cancel",
    "payment": "/api/v1/orders/ord_x7k9m2/payment"
  }
}

// Order in "shipped" state -- can only track
{
  "links": {
    "self": "/api/v1/orders/ord_x7k9m2",
    "tracking": "/api/v1/orders/ord_x7k9m2/tracking"
  }
}
```

---

## Content Negotiation

### Request Headers

```http
# Client requests JSON
GET /api/v1/users
Accept: application/json

# Client requests specific API version via media type
GET /api/v1/users
Accept: application/vnd.example.v2+json

# Client sends JSON
POST /api/v1/users
Content-Type: application/json
```

### Server Responses

```http
# Reject unsupported Accept header
HTTP/1.1 406 Not Acceptable
Content-Type: application/problem+json

{
  "type": "https://api.example.com/errors/not-acceptable",
  "title": "Not Acceptable",
  "status": 406,
  "detail": "Supported media types: application/json"
}

# Reject unsupported Content-Type
HTTP/1.1 415 Unsupported Media Type
Content-Type: application/problem+json

{
  "type": "https://api.example.com/errors/unsupported-media-type",
  "title": "Unsupported Media Type",
  "status": 415,
  "detail": "Expected Content-Type: application/json"
}
```

---

## Idempotency Keys

For non-idempotent operations (POST), allow clients to safely retry by including an idempotency key.

```http
POST /api/v1/payments
Idempotency-Key: idk_8f14e45f-ceea-467f-a830-2dba7e3e1abc
Content-Type: application/json

{
  "amount": 2500,
  "currency": "usd",
  "customer_id": "usr_a1b2c3"
}
```

**Server behavior:**
- First request: process normally, store result keyed by idempotency key
- Subsequent requests with same key: return stored result without re-processing
- Keys should expire after 24-72 hours
- Return `409 Conflict` if the same key is used with a different request body
