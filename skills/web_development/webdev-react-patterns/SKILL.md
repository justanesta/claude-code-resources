---
name: webdev-react-patterns
description: Modern React 18+ patterns with TypeScript — hooks, state management, composition, performance optimization, and testing best practices.
---

# React Patterns & Best Practices

## Core Principles

1. **Composition over inheritance** — Build complex UIs by combining small, focused components
2. **Hooks for all logic** — Use hooks to encapsulate stateful logic and side effects. Never use class components
3. **Unidirectional data flow** — Data flows down via props; events flow up via callbacks
4. **Colocation** — Place state, styles, tests, and types next to the components that use them
5. **Type safety everywhere** — Use TypeScript for props, state, context, and hook return types

## Hooks Fundamentals

```tsx
function Search({ items, onSelect }: { items: string[]; onSelect: (item: string) => void }) {
  const [query, setQuery] = useState("");
  const inputRef = useRef<HTMLInputElement>(null);

  const filtered = useMemo(
    () => items.filter((item) => item.toLowerCase().includes(query.toLowerCase())),
    [items, query]
  );

  const handleSelect = useCallback(
    (item: string) => { setQuery(""); onSelect(item); },
    [onSelect]
  );

  useEffect(() => { inputRef.current?.focus(); }, []);

  return (
    <div>
      <input ref={inputRef} value={query} onChange={(e) => setQuery(e.target.value)} />
      {filtered.map((item) => (
        <button key={item} onClick={() => handleSelect(item)}>{item}</button>
      ))}
    </div>
  );
}
```

See [hooks-patterns](references/hooks-patterns.md) for:
- Rules of hooks, useId, useRef patterns
- Cleanup functions and dependency array pitfalls

## Custom Hooks

```tsx
function useFetch<T>(url: string) {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<Error | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    fetch(url, { signal: controller.signal })
      .then((res) => { if (!res.ok) throw new Error(`HTTP ${res.status}`); return res.json(); })
      .then((json) => setData(json as T))
      .catch((err) => { if (err.name !== "AbortError") setError(err); })
      .finally(() => setLoading(false));
    return () => controller.abort();
  }, [url]);

  return { data, error, loading };
}
```

See [custom-hooks](references/custom-hooks.md) for:
- Form hooks, event listener hooks, debounce hooks, and hook composition

## State Management

```tsx
type CartAction =
  | { type: "ADD_ITEM"; payload: { id: string; name: string; price: number } }
  | { type: "REMOVE_ITEM"; payload: { id: string } }
  | { type: "CLEAR" };

interface CartState { items: Array<{ id: string; name: string; price: number }> }

function cartReducer(state: CartState, action: CartAction): CartState {
  switch (action.type) {
    case "ADD_ITEM": return { items: [...state.items, action.payload] };
    case "REMOVE_ITEM": return { items: state.items.filter((i) => i.id !== action.payload.id) };
    case "CLEAR": return { items: [] };
  }
}

const CartContext = createContext<{ state: CartState; dispatch: React.Dispatch<CartAction> } | null>(null);

function CartProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(cartReducer, { items: [] });
  return <CartContext.Provider value={{ state, dispatch }}>{children}</CartContext.Provider>;
}

function useCart() {
  const ctx = useContext(CartContext);
  if (!ctx) throw new Error("useCart must be used within CartProvider");
  return ctx;
}
```

See [state-management](references/state-management.md) for:
- Zustand store patterns, Jotai atoms, context splitting

## Component Composition Patterns

```tsx
function Tabs({ children, defaultIndex = 0 }: { children: ReactNode; defaultIndex?: number }) {
  const [activeIndex, setActiveIndex] = useState(defaultIndex);
  const tabs = React.Children.toArray(children) as React.ReactElement<{ label: string; children: ReactNode }>[];

  return (
    <div>
      <div role="tablist">
        {tabs.map((tab, i) => (
          <button key={i} role="tab" aria-selected={i === activeIndex} onClick={() => setActiveIndex(i)}>
            {tab.props.label}
          </button>
        ))}
      </div>
      <div role="tabpanel">{tabs[activeIndex]?.props.children}</div>
    </div>
  );
}
```

See [component-patterns](references/component-patterns.md) for:
- Render props, HOCs, slot patterns, polymorphic components, forwardRef

## Performance Optimization

```tsx
const ExpensiveList = memo(function ExpensiveList({ items }: { items: string[] }) {
  return <ul>{items.map((item) => <li key={item}>{item}</li>)}</ul>;
});

const Dashboard = lazy(() => import("./Dashboard"));

function App() {
  const [isPending, startTransition] = useTransition();
  const [tab, setTab] = useState("home");

  return (
    <div>
      <button onClick={() => startTransition(() => setTab("dashboard"))}>Dashboard</button>
      {isPending && <span>Loading...</span>}
      <Suspense fallback={<div>Loading...</div>}>
        {tab === "dashboard" && <Dashboard />}
      </Suspense>
    </div>
  );
}
```

See [performance-patterns](references/performance-patterns.md) for:
- React.memo deep comparison, virtualization, bundle splitting, profiling

## Testing with React Testing Library

```tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";

test("filters items and calls onSelect when clicked", async () => {
  const user = userEvent.setup();
  const onSelect = vi.fn();
  render(<Search items={["Apple", "Banana", "Avocado"]} onSelect={onSelect} />);

  await user.type(screen.getByRole("textbox"), "av");
  expect(screen.getByText("Avocado")).toBeInTheDocument();
  expect(screen.queryByText("Banana")).not.toBeInTheDocument();

  await user.click(screen.getByText("Avocado"));
  expect(onSelect).toHaveBeenCalledWith("Avocado");
});
```

See [testing-patterns](references/testing-patterns.md) for:
- Async testing, MSW API mocking, testing hooks, context providers

## Anti-Patterns

| Avoid | Use Instead |
|---|---|
| `useEffect` for derived state | `useMemo` or compute inline during render |
| Prop drilling through 4+ levels | Context API or external store (Zustand) |
| `any` type for props or state | Explicit interfaces and generics |
| Index as key for dynamic lists | Stable unique IDs (`crypto.randomUUID()`) |
| Giant monolith components (300+ lines) | Extract sub-components and custom hooks |
| `useEffect` to sync props to state | Derive from props directly, use key to reset |
| Memoizing everything by default | Profile first, memoize only proven bottlenecks |
| Testing implementation details | Test rendered output and user interactions |
| Fetching in `useEffect` without cleanup | Use AbortController or a data-fetching library |

## Performance

- **Measure first** — Use React DevTools Profiler to identify actual bottlenecks before optimizing
- **Reduce re-renders** — Split context providers, use `memo` on expensive subtrees
- **Code-split aggressively** — Lazy-load routes and heavy components with `React.lazy` + `Suspense`
- **Virtualize long lists** — Use `react-window` or `@tanstack/react-virtual` for 100+ items
- **Debounce expensive operations** — Wrap search inputs with debounce or `useTransition`
- **Avoid inline objects in JSX** — `style={{}}` creates new references every render; hoist or memoize

source: React 18 documentation, React TypeScript Cheatsheet, Testing Library docs, Zustand/Jotai docs
