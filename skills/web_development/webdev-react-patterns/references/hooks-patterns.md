# Hooks Patterns Reference

Comprehensive patterns for React's built-in hooks with TypeScript. Covers rules, gotchas, and real-world usage.

## Rules of Hooks

1. Only call hooks at the top level of a component or custom hook — never inside loops, conditions, or nested functions.
2. Only call hooks from React function components or custom hooks — never from regular JavaScript functions.
3. Custom hooks must start with `use` — this enables the linter to enforce the rules above.

```tsx
// WRONG: conditional hook call
function Profile({ userId }: { userId?: string }) {
  if (userId) {
    const [user, setUser] = useState(null); // breaks rules of hooks
  }
}

// CORRECT: always call the hook, guard inside
function Profile({ userId }: { userId?: string }) {
  const [user, setUser] = useState<User | null>(null);

  useEffect(() => {
    if (!userId) return;
    fetchUser(userId).then(setUser);
  }, [userId]);
}
```

## useState Patterns

### Lazy initialization

Use a function initializer for expensive computations that should only run once.

```tsx
// Expensive: parses on every render if written inline
const [data, setData] = useState(JSON.parse(localStorage.getItem("draft") ?? "{}"));

// Correct: function runs only on mount
const [data, setData] = useState(() =>
  JSON.parse(localStorage.getItem("draft") ?? "{}")
);
```

### Functional updates

When next state depends on previous state, use the updater form to avoid stale closures.

```tsx
function Counter() {
  const [count, setCount] = useState(0);

  function incrementByThree() {
    // WRONG: all three refer to the same stale `count`
    // setCount(count + 1);
    // setCount(count + 1);
    // setCount(count + 1);

    // CORRECT: each updater receives the latest value
    setCount((prev) => prev + 1);
    setCount((prev) => prev + 1);
    setCount((prev) => prev + 1);
  }

  return <button onClick={incrementByThree}>{count}</button>;
}
```

### Typed state with discriminated unions

```tsx
type AsyncState<T> =
  | { status: "idle" }
  | { status: "loading" }
  | { status: "success"; data: T }
  | { status: "error"; error: Error };

function useAsyncState<T>() {
  return useState<AsyncState<T>>({ status: "idle" });
}
```

## useEffect Patterns

### Cleanup functions

Always clean up subscriptions, timers, and listeners to prevent memory leaks.

```tsx
function useWindowSize() {
  const [size, setSize] = useState({ width: window.innerWidth, height: window.innerHeight });

  useEffect(() => {
    function handleResize() {
      setSize({ width: window.innerWidth, height: window.innerHeight });
    }

    window.addEventListener("resize", handleResize);
    return () => window.removeEventListener("resize", handleResize);
  }, []);

  return size;
}
```

### AbortController for fetch

```tsx
useEffect(() => {
  const controller = new AbortController();

  async function load() {
    try {
      const res = await fetch(`/api/users/${id}`, { signal: controller.signal });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const json = await res.json();
      setUser(json);
    } catch (err) {
      if (err instanceof Error && err.name !== "AbortError") {
        setError(err);
      }
    }
  }

  load();
  return () => controller.abort();
}, [id]);
```

### Dependency array pitfalls

```tsx
// BUG: object/array deps cause infinite re-runs
useEffect(() => {
  fetchData(filters);
}, [filters]); // if `filters` is recreated each render, this loops

// FIX 1: memoize the dependency
const stableFilters = useMemo(() => filters, [filters.search, filters.page]);

// FIX 2: compare specific primitive values
useEffect(() => {
  fetchData({ search: filters.search, page: filters.page });
}, [filters.search, filters.page]);
```

### Avoiding useEffect for derived state

```tsx
// WRONG: syncing props to state via effect
function BadComponent({ items }: { items: Item[] }) {
  const [sorted, setSorted] = useState<Item[]>([]);
  useEffect(() => {
    setSorted([...items].sort((a, b) => a.name.localeCompare(b.name)));
  }, [items]);
}

// CORRECT: compute during render
function GoodComponent({ items }: { items: Item[] }) {
  const sorted = useMemo(
    () => [...items].sort((a, b) => a.name.localeCompare(b.name)),
    [items]
  );
}
```

## useRef Patterns

### DOM references

```tsx
function AutoFocusInput() {
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  return <input ref={inputRef} />;
}
```

### Mutable instance values (not triggering re-render)

```tsx
function useInterval(callback: () => void, delay: number | null) {
  const savedCallback = useRef(callback);

  // Update ref on every render so the interval always calls the latest callback
  useEffect(() => {
    savedCallback.current = callback;
  }, [callback]);

  useEffect(() => {
    if (delay === null) return;

    const id = setInterval(() => savedCallback.current(), delay);
    return () => clearInterval(id);
  }, [delay]);
}
```

### Previous value ref

```tsx
function usePrevious<T>(value: T): T | undefined {
  const ref = useRef<T | undefined>(undefined);

  useEffect(() => {
    ref.current = value;
  });

  return ref.current;
}
```

## useMemo and useCallback

### When to use useMemo

Use `useMemo` when a computation is expensive or when referential equality matters for downstream dependencies.

```tsx
interface DataTableProps {
  rows: Row[];
  sortKey: string;
  filterText: string;
}

function DataTable({ rows, sortKey, filterText }: DataTableProps) {
  // Expensive: sorting + filtering thousands of rows
  const processedRows = useMemo(() => {
    const filtered = rows.filter((r) => r.name.includes(filterText));
    return filtered.sort((a, b) => (a[sortKey] > b[sortKey] ? 1 : -1));
  }, [rows, sortKey, filterText]);

  return (
    <table>
      <tbody>
        {processedRows.map((row) => (
          <tr key={row.id}><td>{row.name}</td></tr>
        ))}
      </tbody>
    </table>
  );
}
```

### When to use useCallback

Use `useCallback` when passing callbacks to memoized children or when the callback is a dependency of another hook.

```tsx
function Parent() {
  const [count, setCount] = useState(0);

  // Without useCallback, MemoChild re-renders on every Parent render
  const handleClick = useCallback(() => {
    setCount((prev) => prev + 1);
  }, []);

  return <MemoChild onClick={handleClick} />;
}

const MemoChild = memo(function MemoChild({ onClick }: { onClick: () => void }) {
  console.log("MemoChild rendered");
  return <button onClick={onClick}>Click</button>;
});
```

## useId

Generate unique IDs for accessibility attributes. Never use for list keys.

```tsx
function FormField({ label }: { label: string }) {
  const id = useId();

  return (
    <div>
      <label htmlFor={id}>{label}</label>
      <input id={id} />
    </div>
  );
}

// Multiple IDs from one call
function PasswordField() {
  const id = useId();

  return (
    <>
      <label htmlFor={`${id}-password`}>Password</label>
      <input id={`${id}-password`} type="password" aria-describedby={`${id}-hint`} />
      <p id={`${id}-hint`}>Must be at least 8 characters</p>
    </>
  );
}
```

## Common Mistakes

### Stale closure in event handlers

```tsx
function Chat() {
  const [messages, setMessages] = useState<string[]>([]);

  useEffect(() => {
    const ws = new WebSocket("/chat");

    ws.onmessage = (event) => {
      // BUG: `messages` is always the initial [] due to stale closure
      // setMessages([...messages, event.data]);

      // FIX: use functional update
      setMessages((prev) => [...prev, event.data]);
    };

    return () => ws.close();
  }, []); // empty deps means `messages` is captured once
}
```

### Forgetting to type generic hooks

```tsx
// Untyped: data is `unknown`
const [data, setData] = useState(null);

// Typed: data is `User | null`
const [data, setData] = useState<User | null>(null);

// Typed ref: ref.current is `HTMLDivElement | null`
const ref = useRef<HTMLDivElement>(null);
```
