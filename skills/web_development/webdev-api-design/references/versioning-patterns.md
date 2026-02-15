# Versioning Patterns Reference

Strategies for API versioning, content negotiation, deprecation timelines, backward-compatible changes, and migration support.

---

## URL Path Versioning

The most widely used approach. The version is visible in every request.

```http
# Version in the path
GET /api/v1/users
GET /api/v2/users

# With a base URL
https://api.example.com/v1/users
https://api.example.com/v2/users
```

### Routing Structure

```
api/
  v1/
    routes/
      users.js
      orders.js
    controllers/
      users-controller.js
  v2/
    routes/
      users.js        # Updated routes
      orders.js        # May import from v1 if unchanged
    controllers/
      users-controller.js
```

### Advantages and Trade-Offs

| Aspect | Details |
|--------|---------|
| Visibility | Version is obvious in every URL and every log entry |
| Caching | CDNs and proxies can cache each version independently |
| Simplicity | Easy to understand, implement, and document |
| Routing | Straightforward server-side routing |
| Drawback | URL changes between versions, breaking bookmarks and hardcoded paths |
| Drawback | Can lead to code duplication between version modules |

---

## Header Versioning

Version specified via custom headers or the `Accept` header. URLs remain stable.

### Custom Header

```http
GET /api/users
API-Version: 2

# Response includes the version used
HTTP/1.1 200 OK
API-Version: 2
```

### Accept Header (Content Negotiation)

```http
# Vendor media type with version
GET /api/users
Accept: application/vnd.example.v2+json

# Response
HTTP/1.1 200 OK
Content-Type: application/vnd.example.v2+json
```

### Media Type Structure

```
application/vnd.{company}.{version}+json

# Examples
application/vnd.example.v1+json
application/vnd.example.v2+json
application/vnd.github.v3+json        # GitHub API style
application/vnd.example.v1.full+json   # With representation variant
application/vnd.example.v1.compact+json
```

### Advantages and Trade-Offs

| Aspect | Details |
|--------|---------|
| Clean URLs | Resource URLs never change between versions |
| REST purity | More aligned with REST content negotiation principles |
| Flexibility | Can version individual resources differently |
| Drawback | Less visible -- version is hidden in headers |
| Drawback | Harder to test in a browser or share URLs |
| Drawback | CDN/proxy caching requires `Vary: Accept` or `Vary: API-Version` |

---

## Query Parameter Versioning

```http
GET /api/users?version=2
GET /api/users?v=2
GET /api/users?api-version=2025-10-01
```

### Date-Based Versioning

Used by Stripe and other APIs. Clients pin to the API version on the date they integrated.

```http
GET /api/users
Stripe-Version: 2025-10-01

# Or as query parameter
GET /api/users?api-version=2025-10-01
```

```json
// Account settings store the default version
{
  "api_version": "2025-10-01",
  "latest_version": "2026-01-15",
  "versions_behind": 2
}
```

### Advantages and Trade-Offs

| Aspect | Details |
|--------|---------|
| Easy to switch | Changing a query param is trivial for testing |
| Optional | Can default to latest version if omitted |
| Date-based | Natural ordering, clear release timeline |
| Drawback | Query params are typically for filtering, not versioning |
| Drawback | Can pollute cache keys |

---

## Deprecation and Sunset Headers

### Standard Headers

```http
# Deprecation header (RFC draft) -- when the version was deprecated
Deprecation: Sun, 01 Jun 2025 00:00:00 GMT

# Sunset header (RFC 8594) -- when the version will be removed
Sunset: Mon, 01 Dec 2025 00:00:00 GMT

# Link to successor and deprecation docs
Link: </api/v2/users>; rel="successor-version",
      <https://developer.example.com/docs/migration/v1-to-v2>; rel="deprecation"
```

### Deprecation Response Body

Include deprecation warnings in response metadata.

```json
{
  "data": { "..." },
  "meta": {
    "api_version": "v1",
    "deprecation": {
      "deprecated": true,
      "deprecated_at": "2025-06-01T00:00:00Z",
      "sunset_at": "2025-12-01T00:00:00Z",
      "message": "API v1 is deprecated. Please migrate to v2.",
      "migration_guide": "https://developer.example.com/docs/migration/v1-to-v2",
      "successor": "/api/v2/users"
    }
  }
}
```

### Deprecation Timeline Template

| Phase | Duration | Actions |
|-------|----------|---------|
| Announcement | Day 0 | Announce new version, publish migration guide |
| Active development | 0-6 months | Both versions receive bug fixes; new features only in new version |
| Deprecation notice | 6 months | Add `Deprecation` header to old version responses |
| Migration period | 6-12 months | Old version still operational, send email warnings to active consumers |
| Sunset warning | 12 months | Add `Sunset` header, increase warning frequency |
| Read-only mode | 12-14 months | Old version becomes read-only (optional) |
| Shutdown | 14-18 months | Old version returns `410 Gone` |

---

## Backward-Compatible Changes

These changes do NOT require a new version. Add freely without breaking clients.

### Safe Additive Changes

```json
// v1 original response
{
  "id": "usr_a1b2c3",
  "name": "Jane Park",
  "email": "jane@example.com"
}

// v1 response after additive change (backward compatible)
{
  "id": "usr_a1b2c3",
  "name": "Jane Park",
  "email": "jane@example.com",
  "avatar_url": "https://cdn.example.com/avatars/usr_a1b2c3.jpg",
  "created_at": "2025-09-15T08:30:00Z"
}
```

### List of Backward-Compatible Changes

- Adding new fields to response bodies
- Adding new optional query parameters
- Adding new optional request body fields
- Adding new endpoints
- Adding new enum values (if clients handle unknown values)
- Adding new HTTP methods to existing endpoints
- Adding new response headers
- Relaxing validation (accepting a wider range of inputs)

### Breaking Changes (Require New Version)

- Removing or renaming a field in request or response
- Changing a field's type (string to integer)
- Making an optional field required
- Changing the URL structure of existing endpoints
- Removing an endpoint
- Changing authentication scheme
- Changing error response format
- Changing the meaning/behavior of an existing field
- Tightening validation (rejecting previously valid input)
- Changing pagination format

---

## Migration Support Patterns

### Version Discovery Endpoint

```http
GET /api/versions

{
  "versions": [
    {
      "version": "v1",
      "status": "deprecated",
      "deprecated_at": "2025-06-01",
      "sunset_at": "2025-12-01",
      "base_url": "https://api.example.com/v1",
      "documentation": "https://developer.example.com/docs/v1"
    },
    {
      "version": "v2",
      "status": "current",
      "released_at": "2025-06-01",
      "base_url": "https://api.example.com/v2",
      "documentation": "https://developer.example.com/docs/v2",
      "changelog": "https://developer.example.com/docs/changelog/v2"
    }
  ],
  "current": "v2",
  "migration_guides": {
    "v1_to_v2": "https://developer.example.com/docs/migration/v1-to-v2"
  }
}
```

### Dual Writing During Migration

When data formats change between versions, maintain both representations during the migration period.

```
Client Request --> API Gateway --> Version Router
                                      |
                              v1 Handler    v2 Handler
                                      |         |
                                      +----+----+
                                           |
                                     Shared Data Layer
                                    (stores both formats)
```

### Request/Response Transformation

For minor differences, transform between versions without duplicating business logic.

```
v1 Request --> v1-to-v2 Transformer --> Shared Handler --> v2-to-v1 Transformer --> v1 Response
v2 Request --------------------------> Shared Handler --------------------------> v2 Response
```

### Field Mapping Example

```json
// v1 response shape
{
  "id": "usr_a1b2c3",
  "firstName": "Jane",       // camelCase in v1
  "lastName": "Park",
  "emailAddress": "jane@example.com"
}

// v2 response shape (same data, different format)
{
  "id": "usr_a1b2c3",
  "first_name": "Jane",      // snake_case in v2
  "last_name": "Park",
  "email": "jane@example.com" // simplified field name
}
```

---

## Gone (410) for Removed Versions

After the sunset date, return `410 Gone` with guidance.

```http
GET /api/v1/users
HTTP/1.1 410 Gone
Content-Type: application/problem+json

{
  "type": "https://api.example.com/errors/version-removed",
  "title": "API Version Removed",
  "status": 410,
  "detail": "API v1 was removed on December 1, 2025. Please use v2.",
  "migration_guide": "https://developer.example.com/docs/migration/v1-to-v2",
  "current_version": "v2",
  "current_base_url": "https://api.example.com/v2"
}
```

---

## Client Version Tracking

Track which API versions each client uses to plan deprecations effectively.

```json
// Admin endpoint: version usage analytics
GET /api/admin/version-usage

{
  "period": "2025-10-01 to 2025-10-15",
  "versions": {
    "v1": {
      "total_requests": 1250000,
      "unique_clients": 47,
      "percentage": 12.3,
      "top_clients": [
        { "client_id": "app_legacy1", "requests": 850000 },
        { "client_id": "app_legacy2", "requests": 320000 }
      ]
    },
    "v2": {
      "total_requests": 8900000,
      "unique_clients": 312,
      "percentage": 87.7
    }
  }
}
```

Use this data to:
- Identify clients still on deprecated versions and reach out proactively
- Set realistic sunset timelines based on actual migration progress
- Prioritize migration support for high-traffic clients
