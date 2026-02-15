# Performance Patterns Reference

Techniques for optimizing React application performance — memoization, code splitting, virtualization, and profiling.

## React.memo

Prevents re-renders when props have not changed. Use for components that are expensive to render or receive the same props frequently.

### Basic usage

```tsx
import { memo } from "react";

interface UserCardProps {
  name: string;
  email: string;
  avatar: string;
}

const UserCard = memo(function UserCard({ name, email, avatar }: UserCardProps) {
  return (
    <div className="user-card">
      <img src={avatar} alt={name} />
      <h3>{name}</h3>
      <p>{email}</p>
    </div>
  );
});
```

### Custom comparison

Use a custom comparator when shallow equality is not sufficient.

```tsx
interface ChartProps {
  data: number[];
  title: string;
}

const Chart = memo(
  function Chart({ data, title }: ChartProps) {
    // Expensive chart rendering
    return <canvas data-title={title} />;
  },
  (prevProps, nextProps) => {
    // Only re-render if data length or title changes
    return (
      prevProps.title === nextProps.title &&
      prevProps.data.length === nextProps.data.length &&
      prevProps.data.every((val, i) => val === nextProps.data[i])
    );
  }
);
```

### When memo does NOT help

```tsx
// INEFFECTIVE: Parent passes a new object/function every render
function Parent() {
  return (
    <MemoChild
      style={{ color: "red" }}          // new object each render
      onClick={() => console.log("hi")} // new function each render
    />
  );
}

// FIX: hoist or memoize props
const style = { color: "red" } as const;

function Parent() {
  const handleClick = useCallback(() => console.log("hi"), []);
  return <MemoChild style={style} onClick={handleClick} />;
}
```

## useMemo for Expensive Computations

```tsx
function Analytics({ transactions }: { transactions: Transaction[] }) {
  // Only recalculates when transactions change
  const stats = useMemo(() => {
    const total = transactions.reduce((sum, t) => sum + t.amount, 0);
    const average = total / transactions.length;
    const max = Math.max(...transactions.map((t) => t.amount));
    const byCategory = transactions.reduce<Record<string, number>>((acc, t) => {
      acc[t.category] = (acc[t.category] ?? 0) + t.amount;
      return acc;
    }, {});
    return { total, average, max, byCategory };
  }, [transactions]);

  return (
    <div>
      <p>Total: ${stats.total.toFixed(2)}</p>
      <p>Average: ${stats.average.toFixed(2)}</p>
      <p>Max: ${stats.max.toFixed(2)}</p>
    </div>
  );
}
```

## useCallback for Stable References

```tsx
function SearchPage() {
  const [query, setQuery] = useState("");
  const [results, setResults] = useState<Item[]>([]);

  // Stable reference — only changes when query changes
  const handleSearch = useCallback(async () => {
    const data = await fetchItems(query);
    setResults(data);
  }, [query]);

  return (
    <div>
      <SearchInput onSearch={handleSearch} />
      <ResultList items={results} />
    </div>
  );
}

// SearchInput is memoized; stable onSearch prevents re-renders
const SearchInput = memo(function SearchInput({ onSearch }: { onSearch: () => void }) {
  return <button onClick={onSearch}>Search</button>;
});
```

## Code Splitting with React.lazy

### Route-level splitting

```tsx
import { lazy, Suspense } from "react";
import { Routes, Route } from "react-router-dom";

const Home = lazy(() => import("./pages/Home"));
const Dashboard = lazy(() => import("./pages/Dashboard"));
const Settings = lazy(() => import("./pages/Settings"));
const Profile = lazy(() => import("./pages/Profile"));

function App() {
  return (
    <Suspense fallback={<FullPageSpinner />}>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/settings" element={<Settings />} />
        <Route path="/profile" element={<Profile />} />
      </Routes>
    </Suspense>
  );
}
```

### Component-level splitting

```tsx
const HeavyEditor = lazy(() => import("./HeavyEditor"));

function ArticlePage({ article }: { article: Article }) {
  const [editing, setEditing] = useState(false);

  return (
    <div>
      <h1>{article.title}</h1>
      <p>{article.body}</p>
      <button onClick={() => setEditing(true)}>Edit</button>
      {editing && (
        <Suspense fallback={<div>Loading editor...</div>}>
          <HeavyEditor content={article.body} onSave={handleSave} />
        </Suspense>
      )}
    </div>
  );
}
```

### Named exports with lazy

```tsx
// React.lazy only supports default exports; wrap named exports
const BarChart = lazy(() =>
  import("./charts").then((mod) => ({ default: mod.BarChart }))
);
```

## useTransition for Non-Urgent Updates

```tsx
import { useState, useTransition } from "react";

function FilterableList({ items }: { items: string[] }) {
  const [filter, setFilter] = useState("");
  const [isPending, startTransition] = useTransition();
  const [filteredItems, setFilteredItems] = useState(items);

  function handleFilter(value: string) {
    setFilter(value); // urgent: update input immediately

    startTransition(() => {
      // non-urgent: can be interrupted
      setFilteredItems(
        items.filter((item) => item.toLowerCase().includes(value.toLowerCase()))
      );
    });
  }

  return (
    <div>
      <input value={filter} onChange={(e) => handleFilter(e.target.value)} />
      {isPending && <span>Filtering...</span>}
      <ul>
        {filteredItems.map((item) => (
          <li key={item}>{item}</li>
        ))}
      </ul>
    </div>
  );
}
```

## useDeferredValue

Defer rendering of a non-critical value so the UI stays responsive.

```tsx
import { useDeferredValue, useMemo } from "react";

function SearchResults({ query }: { query: string }) {
  const deferredQuery = useDeferredValue(query);
  const isStale = query !== deferredQuery;

  const results = useMemo(
    () => expensiveSearch(deferredQuery),
    [deferredQuery]
  );

  return (
    <div style={{ opacity: isStale ? 0.6 : 1 }}>
      {results.map((r) => (
        <div key={r.id}>{r.title}</div>
      ))}
    </div>
  );
}
```

## Virtualization

Render only visible items for long lists. Use `@tanstack/react-virtual` or `react-window`.

### react-window example

```tsx
import { FixedSizeList } from "react-window";

interface VirtualListProps {
  items: string[];
}

function VirtualList({ items }: VirtualListProps) {
  return (
    <FixedSizeList
      height={400}
      width="100%"
      itemCount={items.length}
      itemSize={50}
    >
      {({ index, style }) => (
        <div style={style} className="list-item">
          {items[index]}
        </div>
      )}
    </FixedSizeList>
  );
}
```

### @tanstack/react-virtual example

```tsx
import { useVirtualizer } from "@tanstack/react-virtual";
import { useRef } from "react";

function VirtualizedList({ items }: { items: Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 60,
    overscan: 5,
  });

  return (
    <div ref={parentRef} style={{ height: 400, overflow: "auto" }}>
      <div style={{ height: virtualizer.getTotalSize(), position: "relative" }}>
        {virtualizer.getVirtualItems().map((virtualRow) => (
          <div
            key={virtualRow.key}
            style={{
              position: "absolute",
              top: virtualRow.start,
              height: virtualRow.size,
              width: "100%",
            }}
          >
            {items[virtualRow.index].name}
          </div>
        ))}
      </div>
    </div>
  );
}
```

## Avoiding Inline Object and Array Allocations

```tsx
// BAD: new object and array created every render
function Badge({ count }: { count: number }) {
  return (
    <span style={{ color: "red", fontWeight: "bold" }}>{count}</span>
  );
}

// GOOD: hoist static objects outside the component
const badgeStyle = { color: "red", fontWeight: "bold" } as const;

function Badge({ count }: { count: number }) {
  return <span style={badgeStyle}>{count}</span>;
}

// GOOD: memoize dynamic objects
function DynamicBadge({ count, color }: { count: number; color: string }) {
  const style = useMemo(() => ({ color, fontWeight: "bold" as const }), [color]);
  return <span style={style}>{count}</span>;
}
```

## React Profiler

### Component-based profiling

```tsx
import { Profiler, type ProfilerOnRenderCallback } from "react";

const onRender: ProfilerOnRenderCallback = (id, phase, actualDuration) => {
  console.log(`${id} [${phase}] took ${actualDuration.toFixed(2)}ms`);
};

function App() {
  return (
    <Profiler id="Sidebar" onRender={onRender}>
      <Sidebar />
    </Profiler>
  );
}
```

### DevTools Profiler workflow

1. Open React DevTools and switch to the Profiler tab.
2. Click Record, perform the interaction you want to measure.
3. Click Stop and review the flame chart.
4. Look for components with high "self time" — these are optimization targets.
5. Check "Why did this render?" to identify unnecessary re-renders.

## Performance Checklist

- Use React DevTools Profiler before optimizing anything.
- Wrap expensive list items in `React.memo`.
- Hoist static objects, arrays, and styles outside components.
- Use `useCallback` for event handlers passed to memoized children.
- Split large contexts into separate state and dispatch contexts.
- Lazy-load routes and heavy components with `React.lazy` + `Suspense`.
- Virtualize lists with more than 100 items.
- Use `useTransition` or `useDeferredValue` for non-urgent updates.
- Debounce rapid inputs (search, resize) with a 200-300ms delay.
- Bundle analyze with `source-map-explorer` or `@next/bundle-analyzer` to find bloat.
