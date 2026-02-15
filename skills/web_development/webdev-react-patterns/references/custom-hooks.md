# Custom Hooks Reference

Patterns for building reusable, composable custom hooks in React with TypeScript.

## Principles

- A custom hook is a function that calls other hooks and starts with `use`.
- Return values should be typed explicitly — prefer objects for hooks with multiple return values, tuples for simple two-value returns.
- Keep hooks focused on a single responsibility.
- Accept configuration via parameters; return state and actions.

## Data Fetching Hook

A generic fetch hook with loading, error, and refetch support.

```tsx
import { useState, useEffect, useCallback } from "react";

interface UseFetchResult<T> {
  data: T | null;
  error: Error | null;
  loading: boolean;
  refetch: () => void;
}

function useFetch<T>(url: string, options?: RequestInit): UseFetchResult<T> {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<Error | null>(null);
  const [loading, setLoading] = useState(true);
  const [fetchCount, setFetchCount] = useState(0);

  const refetch = useCallback(() => {
    setFetchCount((c) => c + 1);
  }, []);

  useEffect(() => {
    const controller = new AbortController();
    setLoading(true);
    setError(null);

    fetch(url, { ...options, signal: controller.signal })
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}: ${res.statusText}`);
        return res.json();
      })
      .then((json) => setData(json as T))
      .catch((err) => {
        if (err.name !== "AbortError") setError(err);
      })
      .finally(() => setLoading(false));

    return () => controller.abort();
  }, [url, fetchCount]);

  return { data, error, loading, refetch };
}

// Usage
function UserProfile({ userId }: { userId: string }) {
  const { data: user, loading, error, refetch } = useFetch<User>(`/api/users/${userId}`);

  if (loading) return <p>Loading...</p>;
  if (error) return <p>Error: {error.message} <button onClick={refetch}>Retry</button></p>;
  return <h1>{user?.name}</h1>;
}
```

## Form Hook

Manage form state, validation, and submission with type safety.

```tsx
import { useState, useCallback, type ChangeEvent, type FormEvent } from "react";

interface UseFormOptions<T extends Record<string, unknown>> {
  initialValues: T;
  validate?: (values: T) => Partial<Record<keyof T, string>>;
  onSubmit: (values: T) => void | Promise<void>;
}

interface UseFormResult<T extends Record<string, unknown>> {
  values: T;
  errors: Partial<Record<keyof T, string>>;
  touched: Partial<Record<keyof T, boolean>>;
  submitting: boolean;
  handleChange: (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
  handleBlur: (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => void;
  handleSubmit: (e: FormEvent) => void;
  setFieldValue: (field: keyof T, value: T[keyof T]) => void;
  reset: () => void;
}

function useForm<T extends Record<string, unknown>>({
  initialValues,
  validate,
  onSubmit,
}: UseFormOptions<T>): UseFormResult<T> {
  const [values, setValues] = useState<T>(initialValues);
  const [errors, setErrors] = useState<Partial<Record<keyof T, string>>>({});
  const [touched, setTouched] = useState<Partial<Record<keyof T, boolean>>>({});
  const [submitting, setSubmitting] = useState(false);

  const handleChange = useCallback((e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
    const { name, value } = e.target;
    setValues((prev) => ({ ...prev, [name]: value }));
  }, []);

  const handleBlur = useCallback(
    (e: ChangeEvent<HTMLInputElement | HTMLTextAreaElement>) => {
      const { name } = e.target;
      setTouched((prev) => ({ ...prev, [name]: true }));
      if (validate) {
        setErrors(validate(values));
      }
    },
    [validate, values]
  );

  const handleSubmit = useCallback(
    async (e: FormEvent) => {
      e.preventDefault();
      const validationErrors = validate?.(values) ?? {};
      setErrors(validationErrors);

      if (Object.keys(validationErrors).length > 0) return;

      setSubmitting(true);
      try {
        await onSubmit(values);
      } finally {
        setSubmitting(false);
      }
    },
    [values, validate, onSubmit]
  );

  const setFieldValue = useCallback((field: keyof T, value: T[keyof T]) => {
    setValues((prev) => ({ ...prev, [field]: value }));
  }, []);

  const reset = useCallback(() => {
    setValues(initialValues);
    setErrors({});
    setTouched({});
  }, [initialValues]);

  return { values, errors, touched, submitting, handleChange, handleBlur, handleSubmit, setFieldValue, reset };
}

// Usage
function SignupForm() {
  const form = useForm({
    initialValues: { email: "", password: "" },
    validate: (values) => {
      const errors: Partial<Record<string, string>> = {};
      if (!values.email) errors.email = "Required";
      if (values.password.length < 8) errors.password = "Min 8 characters";
      return errors;
    },
    onSubmit: async (values) => {
      await api.signup(values);
    },
  });

  return (
    <form onSubmit={form.handleSubmit}>
      <input name="email" value={form.values.email} onChange={form.handleChange} onBlur={form.handleBlur} />
      {form.touched.email && form.errors.email && <span>{form.errors.email}</span>}
      <input name="password" type="password" value={form.values.password} onChange={form.handleChange} />
      <button type="submit" disabled={form.submitting}>Sign Up</button>
    </form>
  );
}
```

## Event Listener Hook

Attach and clean up event listeners declaratively.

```tsx
import { useEffect, useRef } from "react";

function useEventListener<K extends keyof WindowEventMap>(
  eventName: K,
  handler: (event: WindowEventMap[K]) => void,
  element?: HTMLElement | null
) {
  const savedHandler = useRef(handler);

  useEffect(() => {
    savedHandler.current = handler;
  }, [handler]);

  useEffect(() => {
    const target = element ?? window;
    const listener = (event: Event) => savedHandler.current(event as WindowEventMap[K]);

    target.addEventListener(eventName, listener);
    return () => target.removeEventListener(eventName, listener);
  }, [eventName, element]);
}

// Usage: close modal on Escape
function Modal({ onClose }: { onClose: () => void }) {
  useEventListener("keydown", (e) => {
    if (e.key === "Escape") onClose();
  });

  return <div role="dialog">Modal content</div>;
}
```

## Debounce Hook

Debounce a value for search inputs and other high-frequency updates.

```tsx
import { useState, useEffect } from "react";

function useDebounce<T>(value: T, delay: number): T {
  const [debouncedValue, setDebouncedValue] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedValue(value), delay);
    return () => clearTimeout(timer);
  }, [value, delay]);

  return debouncedValue;
}

// Usage
function SearchPage() {
  const [query, setQuery] = useState("");
  const debouncedQuery = useDebounce(query, 300);
  const { data } = useFetch<SearchResult[]>(`/api/search?q=${debouncedQuery}`);

  return (
    <div>
      <input value={query} onChange={(e) => setQuery(e.target.value)} placeholder="Search..." />
      {data?.map((result) => <div key={result.id}>{result.title}</div>)}
    </div>
  );
}
```

## Local Storage Hook

Persist state to localStorage with SSR safety.

```tsx
import { useState, useEffect } from "react";

function useLocalStorage<T>(key: string, initialValue: T): [T, (value: T | ((prev: T) => T)) => void] {
  const [storedValue, setStoredValue] = useState<T>(() => {
    if (typeof window === "undefined") return initialValue;
    try {
      const item = localStorage.getItem(key);
      return item ? (JSON.parse(item) as T) : initialValue;
    } catch {
      return initialValue;
    }
  });

  useEffect(() => {
    try {
      localStorage.setItem(key, JSON.stringify(storedValue));
    } catch {
      console.warn(`Failed to write to localStorage key "${key}"`);
    }
  }, [key, storedValue]);

  return [storedValue, setStoredValue];
}

// Usage
function Settings() {
  const [theme, setTheme] = useLocalStorage<"light" | "dark">("theme", "light");
  return <button onClick={() => setTheme((t) => (t === "light" ? "dark" : "light"))}>{theme}</button>;
}
```

## Hook Composition

Combine smaller hooks to build complex behaviors.

```tsx
function useSearchWithHistory(endpoint: string) {
  const [query, setQuery] = useState("");
  const debouncedQuery = useDebounce(query, 300);
  const { data, loading, error } = useFetch<SearchResult[]>(
    debouncedQuery ? `${endpoint}?q=${debouncedQuery}` : ""
  );
  const [history, setHistory] = useLocalStorage<string[]>("search-history", []);

  const search = useCallback(
    (term: string) => {
      setQuery(term);
      setHistory((prev) => [term, ...prev.filter((h) => h !== term)].slice(0, 10));
    },
    [setHistory]
  );

  return { query, setQuery: search, results: data, loading, error, history };
}
```

## Testing Custom Hooks

Use `renderHook` from React Testing Library.

```tsx
import { renderHook, act, waitFor } from "@testing-library/react";
import { useDebounce } from "./useDebounce";

test("debounces value updates", async () => {
  const { result, rerender } = renderHook(
    ({ value, delay }) => useDebounce(value, delay),
    { initialProps: { value: "hello", delay: 300 } }
  );

  expect(result.current).toBe("hello");

  rerender({ value: "world", delay: 300 });
  // Not yet debounced
  expect(result.current).toBe("hello");

  await waitFor(() => {
    expect(result.current).toBe("world");
  });
});
```
