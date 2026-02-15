# Array Methods Reference

Comprehensive reference for modern JavaScript array methods with practical web development examples.

---

## Transformation Methods

### map — Transform each element

```javascript
// Transform API response to view model
const userCards = users.map((user) => ({
  id: user.id,
  displayName: `${user.firstName} ${user.lastName}`,
  avatarUrl: user.avatar ?? "/default-avatar.png",
  initials: `${user.firstName[0]}${user.lastName[0]}`.toUpperCase(),
}));

// Map with index for numbered lists
const numberedItems = items.map((item, index) => ({
  ...item,
  position: index + 1,
}));
```

### flatMap — Map and flatten one level

```javascript
// Extract all tags from posts (one-to-many)
const allTags = posts.flatMap((post) => post.tags);

// Filter and transform in a single pass
const activeEmails = users.flatMap((user) =>
  user.isActive ? [user.email.toLowerCase()] : []
);

// Expand rows with multiple values
const searchTerms = queries.flatMap((query) =>
  query.split(/\s+/).map((term) => term.toLowerCase())
);

// Generate pairs
const pairs = items.flatMap((a, i) =>
  items.slice(i + 1).map((b) => [a, b])
);
```

---

## Filtering Methods

### filter — Select elements matching a condition

```javascript
// Complex filter with multiple conditions
const eligibleOrders = orders.filter(
  (order) =>
    order.status === "completed" &&
    order.total >= 50 &&
    order.createdAt >= startDate &&
    !order.isRefunded
);

// Remove falsy values
const validEntries = entries.filter(Boolean);

// Deduplicate by property
const uniqueByEmail = users.filter(
  (user, index, arr) => arr.findIndex((u) => u.email === user.email) === index
);
```

### find / findLast — First or last matching element

```javascript
// Find first admin user
const admin = users.find((user) => user.role === "admin");

// findLast — last matching element (ES2023)
const lastError = logs.findLast((entry) => entry.level === "error");

// findIndex for position
const insertionPoint = sortedItems.findIndex((item) => item.priority > newItem.priority);
```

### some / every — Boolean tests

```javascript
// Check if any item needs attention
const hasUrgent = tickets.some((ticket) => ticket.priority === "critical");

// Validate all fields are filled
const isComplete = requiredFields.every((field) => formData[field]?.trim().length > 0);

// Guard clause pattern
if (!permissions.some((p) => p.startsWith("admin:"))) {
  throw new AuthorizationError("Admin access required");
}
```

---

## Aggregation Methods

### reduce — Accumulate a single value

```javascript
// Group and sum — order totals by status
const totalsByStatus = orders.reduce((acc, order) => {
  acc[order.status] = (acc[order.status] ?? 0) + order.amount;
  return acc;
}, {});

// Build a lookup map
const usersById = users.reduce((map, user) => {
  map.set(user.id, user);
  return map;
}, new Map());

// Flatten nested arrays to a specific depth
const flat = nested.reduce(function flatten(acc, item) {
  return Array.isArray(item) ? item.reduce(flatten, acc) : [...acc, item];
}, []);

// Pipeline pattern — compose transformations
const pipeline = [removeNulls, normalize, validate, format];
const result = pipeline.reduce((data, fn) => fn(data), rawInput);

// Running totals
const runningBalance = transactions.reduce((acc, tx) => {
  const balance = (acc.at(-1)?.balance ?? 0) + tx.amount;
  return [...acc, { ...tx, balance }];
}, []);
```

---

## Immutable Sorting and Modification (ES2023+)

### toSorted — Immutable sort

```javascript
// Sort without mutating original
const byPrice = products.toSorted((a, b) => a.price - b.price);
const byName = products.toSorted((a, b) => a.name.localeCompare(b.name));

// Multi-field sort
const sorted = employees.toSorted((a, b) =>
  a.department.localeCompare(b.department) || b.salary - a.salary
);
```

### toReversed — Immutable reverse

```javascript
// Reverse chronological order without mutation
const newestFirst = events.toReversed();

// Combined with toSorted for descending sort
const highestRated = movies.toSorted((a, b) => a.rating - b.rating).toReversed();
// Or more simply:
const highestRated2 = movies.toSorted((a, b) => b.rating - a.rating);
```

### toSpliced — Immutable splice

```javascript
// Insert at position without mutation
const withInserted = items.toSpliced(2, 0, newItem);

// Remove at position without mutation
const withoutThird = items.toSpliced(2, 1);

// Replace at position without mutation
const withReplaced = items.toSpliced(2, 1, updatedItem);
```

### with — Immutable index replacement

```javascript
// Replace a single element by index
const updated = items.with(3, newValue);

// Update last element
const updatedLast = items.with(-1, newLastValue);

// Chain with other immutable operations
const processed = items.with(0, "first").toSorted().toReversed();
```

---

## Grouping (ES2024)

### Object.groupBy — Group into plain object

```javascript
// Group users by role
const usersByRole = Object.groupBy(users, (user) => user.role);
// { admin: [...], editor: [...], viewer: [...] }

// Group by computed key
const ordersByMonth = Object.groupBy(orders, (order) => {
  const date = new Date(order.createdAt);
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}`;
});

// Group by boolean condition
const { true: active, false: inactive } = Object.groupBy(
  users,
  (user) => user.isActive
);
```

### Map.groupBy — Group into Map (preserves key types)

```javascript
// Group with non-string keys
const productsByCategory = Map.groupBy(products, (product) => product.category);

// Group by object reference
const itemsByWarehouse = Map.groupBy(inventory, (item) => item.warehouse);
```

---

## Searching and Inclusion

### includes — Simple membership test

```javascript
const VALID_STATUSES = ["active", "pending", "completed"];
if (!VALID_STATUSES.includes(status)) {
  throw new ValidationError("status", `Invalid status: ${status}`);
}
```

### at — Index from end with negative indices

```javascript
// Last element
const latest = events.at(-1);

// Second to last
const previous = events.at(-2);

// Safer than bracket notation for computed indices
const item = items.at(computedIndex); // Returns undefined instead of accessing prototype
```

---

## Chaining Patterns

### Practical chain examples

```javascript
// Data pipeline: filter -> transform -> sort -> limit
const topContributors = users
  .filter((user) => user.contributions > 0)
  .map((user) => ({
    name: user.name,
    contributions: user.contributions,
    rank: null,
  }))
  .toSorted((a, b) => b.contributions - a.contributions)
  .slice(0, 10)
  .map((user, index) => ({ ...user, rank: index + 1 }));

// Search results processing
const searchResults = items
  .filter((item) => item.title.toLowerCase().includes(query.toLowerCase()))
  .flatMap((item) => (item.variants ? [item, ...item.variants] : [item]))
  .toSorted((a, b) => b.relevanceScore - a.relevanceScore)
  .slice(0, 20);
```

---

## Performance Considerations

- **Prefer `for...of` for large datasets** — method chains create intermediate arrays on each step
- **Use `Set` for membership tests** — `array.includes()` is O(n); `set.has()` is O(1)
- **Break early with `find`/`some`/`every`** — these short-circuit unlike `filter` which processes all elements
- **Avoid `reduce` for simple operations** — `map` + `filter` is more readable; use `reduce` only for true aggregations
- **Use `Map` over `reduce` for lookups** — `new Map(items.map(i => [i.id, i]))` is clearer than reduce-to-object

```javascript
// Fast membership test for large arrays
const validIds = new Set(allowedItems.map((item) => item.id));
const filtered = candidates.filter((c) => validIds.has(c.id));

// Early termination instead of filter + length check
const hasMatch = items.some((item) => item.meetsCriteria());
// NOT: items.filter(item => item.meetsCriteria()).length > 0
```

source: MDN Web Docs, TC39 Proposals, JavaScript.info
