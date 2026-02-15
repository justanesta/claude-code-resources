# State Management Reference

Patterns for managing state at every scale — local component state, shared context, and external stores.

## When to Use What

| State Type | Tool | Example |
|---|---|---|
| UI-only, single component | `useState` | Toggle, input value, modal open |
| Complex local transitions | `useReducer` | Form with many fields, wizard steps |
| Shared across a subtree | Context + `useReducer` | Theme, locale, auth status |
| Global client state | Zustand or Jotai | Shopping cart, notifications, sidebar |
| Server/async state | TanStack Query or SWR | API data, pagination, caching |
| URL state | URL search params | Filters, pagination, sort order |

## useReducer Patterns

### Typed reducer with discriminated unions

```tsx
import { useReducer, type Reducer } from "react";

interface Todo {
  id: string;
  text: string;
  completed: boolean;
}

type TodoAction =
  | { type: "ADD"; payload: { text: string } }
  | { type: "TOGGLE"; payload: { id: string } }
  | { type: "DELETE"; payload: { id: string } }
  | { type: "EDIT"; payload: { id: string; text: string } };

interface TodoState {
  todos: Todo[];
}

function todoReducer(state: TodoState, action: TodoAction): TodoState {
  switch (action.type) {
    case "ADD":
      return {
        todos: [
          ...state.todos,
          { id: crypto.randomUUID(), text: action.payload.text, completed: false },
        ],
      };
    case "TOGGLE":
      return {
        todos: state.todos.map((t) =>
          t.id === action.payload.id ? { ...t, completed: !t.completed } : t
        ),
      };
    case "DELETE":
      return { todos: state.todos.filter((t) => t.id !== action.payload.id) };
    case "EDIT":
      return {
        todos: state.todos.map((t) =>
          t.id === action.payload.id ? { ...t, text: action.payload.text } : t
        ),
      };
  }
}

function TodoApp() {
  const [state, dispatch] = useReducer<Reducer<TodoState, TodoAction>>(todoReducer, {
    todos: [],
  });

  return (
    <div>
      <button onClick={() => dispatch({ type: "ADD", payload: { text: "New task" } })}>
        Add
      </button>
      {state.todos.map((todo) => (
        <div key={todo.id}>
          <span
            style={{ textDecoration: todo.completed ? "line-through" : "none" }}
            onClick={() => dispatch({ type: "TOGGLE", payload: { id: todo.id } })}
          >
            {todo.text}
          </span>
          <button onClick={() => dispatch({ type: "DELETE", payload: { id: todo.id } })}>
            Delete
          </button>
        </div>
      ))}
    </div>
  );
}
```

### Reducer with init function

```tsx
function createInitialState(userId: string): UserState {
  return {
    userId,
    preferences: loadPreferences(userId),
    notifications: [],
  };
}

function UserSettings({ userId }: { userId: string }) {
  const [state, dispatch] = useReducer(userReducer, userId, createInitialState);
  // createInitialState only runs once, with userId as argument
}
```

## Context API Patterns

### Split context to avoid unnecessary re-renders

Separate state from dispatch so components that only dispatch do not re-render when state changes.

```tsx
import { createContext, useContext, useReducer, type ReactNode, type Dispatch } from "react";

interface AuthState {
  user: User | null;
  token: string | null;
}

type AuthAction =
  | { type: "LOGIN"; payload: { user: User; token: string } }
  | { type: "LOGOUT" };

const AuthStateContext = createContext<AuthState | null>(null);
const AuthDispatchContext = createContext<Dispatch<AuthAction> | null>(null);

function authReducer(state: AuthState, action: AuthAction): AuthState {
  switch (action.type) {
    case "LOGIN":
      return { user: action.payload.user, token: action.payload.token };
    case "LOGOUT":
      return { user: null, token: null };
  }
}

function AuthProvider({ children }: { children: ReactNode }) {
  const [state, dispatch] = useReducer(authReducer, { user: null, token: null });

  return (
    <AuthStateContext.Provider value={state}>
      <AuthDispatchContext.Provider value={dispatch}>
        {children}
      </AuthDispatchContext.Provider>
    </AuthStateContext.Provider>
  );
}

function useAuthState() {
  const ctx = useContext(AuthStateContext);
  if (!ctx) throw new Error("useAuthState must be within AuthProvider");
  return ctx;
}

function useAuthDispatch() {
  const ctx = useContext(AuthDispatchContext);
  if (!ctx) throw new Error("useAuthDispatch must be within AuthProvider");
  return ctx;
}

// LogoutButton only subscribes to dispatch — does NOT re-render when auth state changes
function LogoutButton() {
  const dispatch = useAuthDispatch();
  return <button onClick={() => dispatch({ type: "LOGOUT" })}>Log out</button>;
}
```

### Context with default value factory

```tsx
interface ThemeContextValue {
  theme: "light" | "dark";
  toggleTheme: () => void;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

function useTheme(): ThemeContextValue {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used within ThemeProvider");
  return ctx;
}

function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setTheme] = useState<"light" | "dark">("light");
  const toggleTheme = useCallback(() => setTheme((t) => (t === "light" ? "dark" : "light")), []);

  // Memoize the value object to prevent child re-renders
  const value = useMemo(() => ({ theme, toggleTheme }), [theme, toggleTheme]);

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}
```

## Zustand Patterns

Zustand provides a minimal, unopinionated global store with no providers required.

### Basic store

```tsx
import { create } from "zustand";

interface CartItem {
  id: string;
  name: string;
  price: number;
  quantity: number;
}

interface CartStore {
  items: CartItem[];
  addItem: (item: Omit<CartItem, "quantity">) => void;
  removeItem: (id: string) => void;
  updateQuantity: (id: string, quantity: number) => void;
  total: () => number;
}

const useCartStore = create<CartStore>((set, get) => ({
  items: [],
  addItem: (item) =>
    set((state) => {
      const existing = state.items.find((i) => i.id === item.id);
      if (existing) {
        return { items: state.items.map((i) => (i.id === item.id ? { ...i, quantity: i.quantity + 1 } : i)) };
      }
      return { items: [...state.items, { ...item, quantity: 1 }] };
    }),
  removeItem: (id) => set((state) => ({ items: state.items.filter((i) => i.id !== id) })),
  updateQuantity: (id, quantity) =>
    set((state) => ({
      items: state.items.map((i) => (i.id === id ? { ...i, quantity } : i)),
    })),
  total: () => get().items.reduce((sum, item) => sum + item.price * item.quantity, 0),
}));

// Usage — only subscribes to `items`, not the whole store
function CartCount() {
  const count = useCartStore((state) => state.items.length);
  return <span>Cart ({count})</span>;
}

function AddToCartButton({ product }: { product: Product }) {
  const addItem = useCartStore((state) => state.addItem);
  return <button onClick={() => addItem(product)}>Add to Cart</button>;
}
```

### Zustand with middleware (persist + devtools)

```tsx
import { create } from "zustand";
import { persist, devtools } from "zustand/middleware";

const useSettingsStore = create<SettingsStore>()(
  devtools(
    persist(
      (set) => ({
        locale: "en",
        notifications: true,
        setLocale: (locale: string) => set({ locale }),
        toggleNotifications: () => set((s) => ({ notifications: !s.notifications })),
      }),
      { name: "settings-storage" }
    )
  )
);
```

## Jotai Patterns

Jotai uses atomic state — each piece of state is an independent atom.

### Basic atoms

```tsx
import { atom, useAtom, useAtomValue, useSetAtom } from "jotai";

// Primitive atom
const countAtom = atom(0);

// Derived (read-only) atom
const doubleCountAtom = atom((get) => get(countAtom) * 2);

// Writable derived atom
const countWithMinAtom = atom(
  (get) => get(countAtom),
  (get, set, newValue: number) => set(countAtom, Math.max(0, newValue))
);

function Counter() {
  const [count, setCount] = useAtom(countAtom);
  const doubleCount = useAtomValue(doubleCountAtom);

  return (
    <div>
      <p>Count: {count} (Double: {doubleCount})</p>
      <button onClick={() => setCount((c) => c + 1)}>Increment</button>
    </div>
  );
}
```

### Async atoms

```tsx
import { atom, useAtomValue } from "jotai";

const userIdAtom = atom<string | null>(null);

const userAtom = atom(async (get) => {
  const id = get(userIdAtom);
  if (!id) return null;
  const res = await fetch(`/api/users/${id}`);
  return res.json() as Promise<User>;
});

// Wrap consumer in Suspense
function UserInfo() {
  const user = useAtomValue(userAtom);
  if (!user) return <p>No user selected</p>;
  return <h2>{user.name}</h2>;
}

// <Suspense fallback={<Loading />}><UserInfo /></Suspense>
```

## URL State

Use URL search parameters for state that should be shareable and bookmarkable.

```tsx
import { useSearchParams } from "react-router-dom";

function ProductList() {
  const [searchParams, setSearchParams] = useSearchParams();
  const page = Number(searchParams.get("page") ?? "1");
  const sort = searchParams.get("sort") ?? "name";

  function setPage(newPage: number) {
    setSearchParams((prev) => {
      prev.set("page", String(newPage));
      return prev;
    });
  }

  function setSort(newSort: string) {
    setSearchParams((prev) => {
      prev.set("sort", newSort);
      prev.set("page", "1"); // reset page on sort change
      return prev;
    });
  }

  return (
    <div>
      <select value={sort} onChange={(e) => setSort(e.target.value)}>
        <option value="name">Name</option>
        <option value="price">Price</option>
      </select>
      {/* render products */}
      <button onClick={() => setPage(page + 1)}>Next Page</button>
    </div>
  );
}
```
