# Error Handling Patterns Reference

Comprehensive guide to RFC 7807 Problem Details, error code registries, validation error structures, retry-after headers, and error response best practices.

---

## RFC 7807 -- Problem Details for HTTP APIs

RFC 7807 defines a standard format for machine-readable error responses. Use `application/problem+json` as the content type.

### Required and Optional Fields

```json
{
  "type": "https://api.example.com/errors/insufficient-funds",
  "title": "Insufficient Funds",
  "status": 422,
  "detail": "Account usr_a1b2c3 has a balance of $10.00, but the transaction requires $25.00.",
  "instance": "/api/v1/payments/pay_xyz789"
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `type` | Yes | URI identifying the error type. Should be a URL that resolves to documentation. Use `about:blank` if no specific type applies |
| `title` | Yes | Short, human-readable summary. Should be the same for all occurrences of this error type |
| `status` | Yes | HTTP status code (must match the actual response status) |
| `detail` | No | Human-readable explanation specific to this occurrence |
| `instance` | No | URI identifying this specific occurrence (often the request path) |

### Extension Fields

RFC 7807 allows custom fields for additional context.

```json
{
  "type": "https://api.example.com/errors/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "detail": "2 fields failed validation.",
  "instance": "/api/v1/users",
  "request_id": "req_x7k9m2",
  "timestamp": "2025-10-15T10:30:00Z",
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

### Error Type URIs

Design a consistent URI scheme for error types. Each URI should resolve to a documentation page.

```
https://api.example.com/errors/validation-failed
https://api.example.com/errors/resource-not-found
https://api.example.com/errors/insufficient-funds
https://api.example.com/errors/rate-limit-exceeded
https://api.example.com/errors/authentication-required
https://api.example.com/errors/permission-denied
https://api.example.com/errors/conflict
https://api.example.com/errors/service-unavailable
```

When no specific type applies, use `about:blank` and rely on the `title` matching the HTTP status phrase:

```json
{
  "type": "about:blank",
  "title": "Not Found",
  "status": 404
}
```

---

## Error Code Registry

Define a catalog of machine-readable error codes that clients can programmatically handle.

### Structure

```json
{
  "type": "https://api.example.com/errors/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "errors": [
    {
      "field": "email",
      "code": "required",
      "message": "This field is required."
    }
  ]
}
```

### Common Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `required` | 422 | A required field was missing |
| `invalid_format` | 422 | Field value does not match expected format |
| `too_short` | 422 | String is shorter than minimum length |
| `too_long` | 422 | String exceeds maximum length |
| `out_of_range` | 422 | Numeric value outside allowed range |
| `not_unique` | 409 | Value already exists (duplicate) |
| `invalid_enum` | 422 | Value is not one of the allowed options |
| `invalid_type` | 400 | Wrong data type (string vs number) |
| `immutable` | 422 | Field cannot be changed after creation |
| `dependency_failed` | 422 | Field is required because of another field's value |

### Nested Field Paths

Use dot notation or JSON Pointer for nested field errors.

```json
{
  "errors": [
    {
      "field": "shipping_address.postal_code",
      "code": "invalid_format",
      "message": "Must be a valid postal code for the specified country."
    },
    {
      "field": "line_items[0].quantity",
      "code": "out_of_range",
      "message": "Must be at least 1.",
      "meta": { "min": 1 }
    },
    {
      "field": "line_items[2].product_id",
      "code": "resource_not_found",
      "message": "Product 'prod_xyz' does not exist."
    }
  ]
}
```

---

## Validation Error Patterns

### Single Field Errors

```json
// 422 Unprocessable Entity
{
  "type": "https://api.example.com/errors/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "detail": "The 'email' field is invalid.",
  "errors": [
    {
      "field": "email",
      "code": "invalid_format",
      "message": "Must be a valid email address.",
      "rejected_value": "not-an-email"
    }
  ]
}
```

### Multiple Field Errors

Return all validation errors at once. Do not fail on the first error.

```json
// 422 Unprocessable Entity
{
  "type": "https://api.example.com/errors/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "detail": "4 fields failed validation.",
  "errors": [
    {
      "field": "name",
      "code": "required",
      "message": "This field is required."
    },
    {
      "field": "email",
      "code": "not_unique",
      "message": "A user with this email already exists."
    },
    {
      "field": "password",
      "code": "too_short",
      "message": "Must be at least 8 characters.",
      "meta": { "min_length": 8 }
    },
    {
      "field": "role",
      "code": "invalid_enum",
      "message": "Must be one of: user, admin, moderator.",
      "meta": { "allowed_values": ["user", "admin", "moderator"] }
    }
  ]
}
```

### Cross-Field Validation

```json
{
  "type": "https://api.example.com/errors/validation-failed",
  "title": "Validation Failed",
  "status": 422,
  "errors": [
    {
      "field": null,
      "code": "date_range_invalid",
      "message": "start_date must be before end_date.",
      "meta": {
        "related_fields": ["start_date", "end_date"]
      }
    }
  ]
}
```

---

## Authentication and Authorization Errors

### 401 Unauthorized

Missing or invalid credentials. The client should authenticate.

```json
// No token provided
{
  "type": "https://api.example.com/errors/authentication-required",
  "title": "Authentication Required",
  "status": 401,
  "detail": "No authentication token was provided. Include a Bearer token in the Authorization header."
}

// Expired token
{
  "type": "https://api.example.com/errors/token-expired",
  "title": "Token Expired",
  "status": 401,
  "detail": "The provided authentication token has expired. Please obtain a new token."
}
```

Always include the `WWW-Authenticate` header with 401 responses:

```http
HTTP/1.1 401 Unauthorized
WWW-Authenticate: Bearer realm="api", error="invalid_token", error_description="Token has expired"
```

### 403 Forbidden

Authenticated but lacks the required permission.

```json
{
  "type": "https://api.example.com/errors/permission-denied",
  "title": "Permission Denied",
  "status": 403,
  "detail": "You do not have permission to delete users. Required scope: admin:users:delete."
}
```

### 404 for Authorization

Use 404 instead of 403 when you want to hide the resource's existence from unauthorized users.

```json
// User is not authorized to see this order, but we return 404 to hide its existence
{
  "type": "https://api.example.com/errors/resource-not-found",
  "title": "Not Found",
  "status": 404,
  "detail": "Order 'ord_secret123' was not found."
}
```

---

## Retry-After Patterns

### Rate Limiting

```http
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
  "detail": "You have exceeded 1000 requests per hour. Retry after 30 seconds.",
  "retry_after": 30,
  "rate_limit": {
    "limit": 1000,
    "window": "1 hour",
    "reset_at": "2025-10-15T11:00:00Z"
  }
}
```

### Service Unavailable

```http
HTTP/1.1 503 Service Unavailable
Retry-After: Wed, 15 Oct 2025 12:00:00 GMT
Content-Type: application/problem+json

{
  "type": "https://api.example.com/errors/service-unavailable",
  "title": "Service Unavailable",
  "status": 503,
  "detail": "The service is undergoing scheduled maintenance. Expected to be available at 12:00 UTC."
}
```

### Retry-After Header Formats

```http
# Seconds (preferred -- simpler for clients to parse)
Retry-After: 120

# HTTP-date (useful for scheduled maintenance)
Retry-After: Wed, 15 Oct 2025 12:00:00 GMT
```

---

## Conflict Errors (409)

Use for state conflicts, optimistic concurrency failures, and duplicate resources.

```json
// Duplicate resource
{
  "type": "https://api.example.com/errors/duplicate-resource",
  "title": "Conflict",
  "status": 409,
  "detail": "A user with email 'jane@example.com' already exists.",
  "conflicting_resource": {
    "id": "usr_a1b2c3",
    "field": "email"
  }
}

// Optimistic concurrency failure (ETag mismatch)
{
  "type": "https://api.example.com/errors/concurrency-conflict",
  "title": "Conflict",
  "status": 409,
  "detail": "The resource has been modified since you last retrieved it. Fetch the latest version and retry.",
  "current_etag": "\"v3-abc123\""
}

// State machine violation
{
  "type": "https://api.example.com/errors/invalid-state-transition",
  "title": "Conflict",
  "status": 409,
  "detail": "Order 'ord_x7k9m2' cannot be cancelled because it has already been shipped.",
  "current_state": "shipped",
  "attempted_transition": "cancel",
  "allowed_transitions": ["deliver", "return"]
}
```

---

## Error Response Best Practices

### Always Include

- `request_id` for tracing and support conversations
- Machine-readable `code` values for programmatic handling
- Human-readable `message` for developer debugging
- Consistent structure across all error responses

### Never Include

- Stack traces in production responses
- Internal system details (database names, internal IPs, file paths)
- Secrets or credentials in error messages
- Raw SQL error messages

### Error Logging vs Error Responses

```json
// What the client sees
{
  "type": "https://api.example.com/errors/internal-error",
  "title": "Internal Server Error",
  "status": 500,
  "detail": "An unexpected error occurred. Please contact support with request ID req_x7k9m2.",
  "request_id": "req_x7k9m2"
}

// What gets logged server-side (NEVER sent to client)
// {
//   "request_id": "req_x7k9m2",
//   "error": "NullPointerException at UserService.java:142",
//   "stack_trace": "...",
//   "user_id": "usr_a1b2c3",
//   "endpoint": "POST /api/v1/users",
//   "timestamp": "2025-10-15T10:30:00Z"
// }
```

### Batch Operation Errors

When a batch request partially fails, return `207 Multi-Status` or `200` with per-item results.

```json
// 207 Multi-Status
{
  "results": [
    {
      "index": 0,
      "status": 201,
      "data": { "id": "usr_new1" }
    },
    {
      "index": 1,
      "status": 409,
      "error": {
        "type": "https://api.example.com/errors/duplicate-resource",
        "title": "Conflict",
        "detail": "Email already exists."
      }
    },
    {
      "index": 2,
      "status": 201,
      "data": { "id": "usr_new3" }
    }
  ],
  "meta": {
    "total": 3,
    "succeeded": 2,
    "failed": 1
  }
}
```
