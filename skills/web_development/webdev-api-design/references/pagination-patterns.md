# Pagination Patterns Reference

Detailed patterns for cursor-based, offset, and keyset pagination, including infinite scroll support, total count trade-offs, and edge cases.

---

## Cursor-Based Pagination

The recommended default for most APIs. Cursors are opaque tokens that point to a position in the result set.

### Basic Implementation

```http
# First page
GET /api/v1/orders?limit=20

# Response
HTTP/1.1 200 OK
Content-Type: application/json

{
  "data": [
    { "id": "ord_001", "total": 59.99, "created_at": "2025-10-15T10:00:00Z" },
    { "id": "ord_002", "total": 129.50, "created_at": "2025-10-14T09:30:00Z" }
  ],
  "pagination": {
    "next_cursor": "eyJpZCI6Im9yZF8wMjAiLCJjcmVhdGVkX2F0IjoiMjAyNS0xMC0wMVQwODowMDowMFoifQ==",
    "has_more": true,
    "limit": 20
  }
}

# Next page -- pass cursor from previous response
GET /api/v1/orders?limit=20&cursor=eyJpZCI6Im9yZF8wMjAiLCJjcmVhdGVkX2F0IjoiMjAyNS0xMC0wMVQwODowMDowMFoifQ==
```

### Cursor Encoding

Cursors should be opaque to clients but meaningful to the server. Base64-encode a JSON payload containing the sort key values.

```json
// Decoded cursor (server-side only)
{
  "id": "ord_020",
  "created_at": "2025-10-01T08:00:00Z"
}

// Encoded cursor (sent to client)
"eyJpZCI6Im9yZF8wMjAiLCJjcmVhdGVkX2F0IjoiMjAyNS0xMC0wMVQwODowMDowMFoifQ=="
```

**What goes into the cursor:**
- The primary sort column value (e.g., `created_at`)
- A tiebreaker column value (e.g., `id`) to ensure deterministic ordering
- The sort direction, if it can change per request

### Bidirectional Cursors

Support both forward and backward navigation.

```json
{
  "data": [ "..." ],
  "pagination": {
    "next_cursor": "eyJkaXIiOiJuZXh0IiwiaWQiOiJvcmRfMDQwIn0=",
    "previous_cursor": "eyJkaXIiOiJwcmV2IiwiaWQiOiJvcmRfMDIxIn0=",
    "has_more": true,
    "has_previous": true,
    "limit": 20
  }
}
```

### Edge Cases

- **Empty result set**: Return an empty `data` array with `has_more: false` and no cursor.
- **Invalid cursor**: Return `400 Bad Request` with a clear message that the cursor is malformed or expired.
- **Deleted records**: Cursors should still work even if the record they point to was deleted -- use `>` not `>=` in the SQL WHERE clause.
- **Changed sort order**: Cursors are invalid when sort order changes. Return `400` and ask the client to restart pagination.

```json
// Empty result
{
  "data": [],
  "pagination": {
    "next_cursor": null,
    "has_more": false,
    "limit": 20
  }
}

// Invalid cursor error
{
  "type": "https://api.example.com/errors/invalid-cursor",
  "title": "Invalid Cursor",
  "status": 400,
  "detail": "The provided cursor is malformed or has expired. Please restart pagination without a cursor."
}
```

---

## Offset-Based Pagination

Simple to implement but has significant drawbacks for mutable data sets.

### Basic Implementation

```http
# First page
GET /api/v1/products?limit=20&offset=0

# Response
{
  "data": [ "..." ],
  "pagination": {
    "total_count": 582,
    "limit": 20,
    "offset": 0,
    "total_pages": 30
  }
}

# Page 3
GET /api/v1/products?limit=20&offset=40
```

### Alternative: Page Number Syntax

```http
# Page-based (maps to offset internally)
GET /api/v1/products?page=3&per_page=20

# Response
{
  "data": [ "..." ],
  "pagination": {
    "current_page": 3,
    "per_page": 20,
    "total_pages": 30,
    "total_count": 582
  }
}
```

### When Offset Pagination Breaks

```
Time T1: Client fetches page 1 (items 1-20)
Time T2: A new item is inserted at position 5
Time T3: Client fetches page 2 (items 21-40)
         -- Item 20 from page 1 now appears AGAIN as item 21
         -- Client sees a duplicate

Time T1: Client fetches page 1 (items 1-20)
Time T2: Item 10 is deleted
Time T3: Client fetches page 2 (items 21-40)
         -- Item 21 (old position) is now at position 20
         -- Client SKIPS this item entirely
```

### When Offset Is Acceptable

- **Static or slowly-changing data** -- product catalogs, reference data
- **Admin dashboards** -- where exact page numbers are needed for navigation
- **Search results** -- users expect page numbers and the data is a point-in-time snapshot
- **Small data sets** -- under a few thousand records

---

## Keyset Pagination

A variation of cursor pagination that uses actual column values instead of opaque tokens. More transparent but exposes implementation details.

### Basic Implementation

```http
# First page, sorted by created_at descending
GET /api/v1/events?limit=20&sort=-created_at

# Response includes the last item's sort key
{
  "data": [
    { "id": "evt_100", "created_at": "2025-10-15T10:00:00Z" },
    { "id": "evt_081", "created_at": "2025-10-01T08:00:00Z" }
  ],
  "pagination": {
    "has_more": true,
    "limit": 20
  }
}

# Next page -- filter using the last item's values
GET /api/v1/events?limit=20&sort=-created_at&created_at_before=2025-10-01T08:00:00Z&after_id=evt_081
```

### SQL Pattern for Keyset Pagination

```sql
-- First page
SELECT * FROM events
ORDER BY created_at DESC, id DESC
LIMIT 21;  -- fetch limit + 1 to determine has_more

-- Next page (using values from last row of previous page)
SELECT * FROM events
WHERE (created_at, id) < ('2025-10-01T08:00:00Z', 'evt_081')
ORDER BY created_at DESC, id DESC
LIMIT 21;
```

### Keyset vs Cursor Comparison

| Aspect | Cursor | Keyset |
|--------|--------|--------|
| Client sees sort values | No (opaque) | Yes (explicit params) |
| Bookmarkable | No (cursors expire) | Yes (values are stable) |
| Sort flexibility | Encoded in cursor | Requires explicit params |
| Implementation | Server encodes/decodes | Client passes filter values |
| Security | Hides internals | Exposes column values |

---

## Infinite Scroll Support

Design considerations for clients implementing infinite scroll (mobile apps, SPAs).

### Response Shape for Infinite Scroll

```json
{
  "data": [ "..." ],
  "pagination": {
    "next_cursor": "abc123",
    "has_more": true
  }
}
```

**Key design points:**
- `has_more` is critical -- clients need to know when to stop requesting
- Do not include `total_count` unless specifically requested (it's expensive and not needed for infinite scroll)
- Keep `limit` reasonable (20-50) to balance perceived speed and network usage
- Return items in a stable, deterministic order

### Handling Real-Time Inserts

When new items arrive while the user is scrolling:

```json
// Option 1: Separate "new items" endpoint
GET /api/v1/feed/new?since=2025-10-15T10:00:00Z

// Option 2: Include a "refresh_cursor" pointing to the newest item
{
  "data": [ "..." ],
  "pagination": {
    "next_cursor": "abc123",
    "refresh_cursor": "xyz789",
    "has_more": true,
    "new_items_available": 5
  }
}
```

---

## Total Count Trade-Offs

### The Cost of COUNT

`SELECT COUNT(*) FROM large_table WHERE ...` can be expensive on large tables, especially with complex filters.

### Strategies

```json
// Option 1: Include total_count (simple, but expensive)
{
  "pagination": {
    "total_count": 1482923,
    "limit": 20,
    "has_more": true
  }
}

// Option 2: Estimated count (fast, good enough for UI)
{
  "pagination": {
    "estimated_count": 1500000,
    "count_is_estimated": true,
    "limit": 20,
    "has_more": true
  }
}

// Option 3: Opt-in total count via query parameter
// GET /api/v1/orders?limit=20&include_total=true
{
  "pagination": {
    "total_count": 1482923,
    "limit": 20,
    "has_more": true
  }
}

// Option 4: No count at all (best performance)
{
  "pagination": {
    "limit": 20,
    "has_more": true,
    "next_cursor": "abc123"
  }
}
```

### Recommendations by Scale

| Data Size | Recommendation |
|-----------|---------------|
| < 10,000 rows | Include `total_count` freely |
| 10,000 - 1M rows | Make `total_count` opt-in via `?include_total=true` |
| > 1M rows | Use estimated counts or omit entirely |

---

## Limit Enforcement

Always enforce limits to prevent clients from requesting unbounded data.

```json
// Request with excessive limit
// GET /api/v1/users?limit=10000

// Response -- server caps at maximum
{
  "data": [ "..." ],
  "pagination": {
    "limit": 100,
    "has_more": true
  },
  "meta": {
    "note": "Requested limit 10000 was capped to maximum of 100"
  }
}
```

**Recommended defaults:**
- Default limit: 20
- Maximum limit: 100 (or 200 for lightweight resources)
- Minimum limit: 1

Return `400 Bad Request` for limit values of 0 or negative numbers.

---

## Link Headers for Pagination

Following RFC 8288 (Web Linking):

```http
HTTP/1.1 200 OK
Link: </api/v1/orders?cursor=abc>; rel="next",
      </api/v1/orders?cursor=def>; rel="prev",
      </api/v1/orders>; rel="first"
```

Useful for clients that parse headers (GitHub API style). Include both in-body pagination and Link headers for maximum compatibility.
