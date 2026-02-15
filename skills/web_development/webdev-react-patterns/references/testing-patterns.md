# Testing Patterns Reference

Best practices for testing React components with React Testing Library, user-event, and Vitest/Jest.

## Core Philosophy

1. **Test behavior, not implementation** — test what the user sees and does, not internal state or method calls.
2. **Query by accessibility** — prefer `getByRole`, `getByLabelText`, `getByPlaceholderText` over `getByTestId`.
3. **Use userEvent over fireEvent** — `userEvent` simulates real browser behavior (focus, type, click).
4. **Arrange, Act, Assert** — structure every test clearly.

## Setup

### Vitest configuration

```typescript
// vitest.config.ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    globals: true,
    setupFiles: ["./src/test/setup.ts"],
    css: true,
  },
});
```

### Test setup file

```typescript
// src/test/setup.ts
import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";

afterEach(() => {
  cleanup();
});
```

## Querying Elements

### Priority order (most to least preferred)

```tsx
import { render, screen } from "@testing-library/react";

render(<LoginForm />);

// 1. getByRole — best for interactive elements
screen.getByRole("button", { name: "Submit" });
screen.getByRole("textbox", { name: "Email" });
screen.getByRole("heading", { level: 1 });

// 2. getByLabelText — best for form fields
screen.getByLabelText("Email address");

// 3. getByPlaceholderText — when no label exists
screen.getByPlaceholderText("Search...");

// 4. getByText — for non-interactive elements
screen.getByText("Welcome back");

// 5. getByDisplayValue — for pre-filled inputs
screen.getByDisplayValue("john@example.com");

// 6. getByAltText — for images
screen.getByAltText("Company logo");

// 7. getByTestId — last resort
screen.getByTestId("custom-dropdown");
```

### Query variants

```tsx
// getBy — throws if not found (use for elements that must exist)
screen.getByRole("button", { name: "Save" });

// queryBy — returns null if not found (use for asserting absence)
expect(screen.queryByText("Error")).not.toBeInTheDocument();

// findBy — returns a promise, waits for element to appear (use for async)
const message = await screen.findByText("Saved successfully");
```

## User Interactions with userEvent

Always call `userEvent.setup()` before rendering.

```tsx
import userEvent from "@testing-library/user-event";
import { render, screen } from "@testing-library/react";

test("submits form with user data", async () => {
  const user = userEvent.setup();
  const handleSubmit = vi.fn();

  render(<SignupForm onSubmit={handleSubmit} />);

  // Type into fields
  await user.type(screen.getByLabelText("Name"), "Jane Doe");
  await user.type(screen.getByLabelText("Email"), "jane@example.com");

  // Select from dropdown
  await user.selectOptions(screen.getByLabelText("Role"), "admin");

  // Check a checkbox
  await user.click(screen.getByLabelText("Agree to terms"));

  // Submit
  await user.click(screen.getByRole("button", { name: "Sign Up" }));

  expect(handleSubmit).toHaveBeenCalledWith({
    name: "Jane Doe",
    email: "jane@example.com",
    role: "admin",
    agreedToTerms: true,
  });
});
```

### Keyboard interactions

```tsx
test("navigates options with keyboard", async () => {
  const user = userEvent.setup();
  render(<ComboBox options={["Apple", "Banana", "Cherry"]} />);

  const input = screen.getByRole("combobox");
  await user.click(input);
  await user.keyboard("{ArrowDown}{ArrowDown}{Enter}");

  expect(input).toHaveValue("Banana");
});
```

### Clearing and replacing text

```tsx
test("clears and replaces input value", async () => {
  const user = userEvent.setup();
  render(<input defaultValue="old value" />);

  const input = screen.getByRole("textbox");
  await user.clear(input);
  await user.type(input, "new value");

  expect(input).toHaveValue("new value");
});
```

## Async Testing

### waitFor

```tsx
import { render, screen, waitFor } from "@testing-library/react";

test("loads and displays user data", async () => {
  render(<UserProfile userId="123" />);

  // Wait for loading to finish
  expect(screen.getByText("Loading...")).toBeInTheDocument();

  // findBy waits automatically
  const name = await screen.findByText("Jane Doe");
  expect(name).toBeInTheDocument();

  // waitFor for more complex assertions
  await waitFor(() => {
    expect(screen.getByText("jane@example.com")).toBeInTheDocument();
    expect(screen.queryByText("Loading...")).not.toBeInTheDocument();
  });
});
```

### waitForElementToBeRemoved

```tsx
test("shows and then hides loading spinner", async () => {
  render(<Dashboard />);

  await waitForElementToBeRemoved(() => screen.queryByText("Loading..."));

  expect(screen.getByRole("heading", { name: "Dashboard" })).toBeInTheDocument();
});
```

## Mocking API Calls with MSW

Use Mock Service Worker for realistic API mocking at the network level.

```tsx
import { http, HttpResponse } from "msw";
import { setupServer } from "msw/node";

const server = setupServer(
  http.get("/api/users/:id", ({ params }) => {
    return HttpResponse.json({
      id: params.id,
      name: "Jane Doe",
      email: "jane@example.com",
    });
  }),

  http.post("/api/users", async ({ request }) => {
    const body = await request.json();
    return HttpResponse.json({ id: "new-id", ...body }, { status: 201 });
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

test("displays user profile from API", async () => {
  render(<UserProfile userId="123" />);
  expect(await screen.findByText("Jane Doe")).toBeInTheDocument();
});

test("handles API error", async () => {
  // Override handler for this single test
  server.use(
    http.get("/api/users/:id", () => {
      return HttpResponse.json({ message: "Not found" }, { status: 404 });
    })
  );

  render(<UserProfile userId="999" />);
  expect(await screen.findByText("User not found")).toBeInTheDocument();
});
```

## Testing Hooks

Use `renderHook` to test custom hooks in isolation.

```tsx
import { renderHook, act, waitFor } from "@testing-library/react";

test("useCounter increments and decrements", () => {
  const { result } = renderHook(() => useCounter(0));

  expect(result.current.count).toBe(0);

  act(() => {
    result.current.increment();
  });
  expect(result.current.count).toBe(1);

  act(() => {
    result.current.decrement();
  });
  expect(result.current.count).toBe(0);
});

test("useFetch returns data", async () => {
  const { result } = renderHook(() => useFetch<User>("/api/users/1"));

  expect(result.current.loading).toBe(true);

  await waitFor(() => {
    expect(result.current.loading).toBe(false);
    expect(result.current.data?.name).toBe("Jane Doe");
  });
});
```

## Testing with Context Providers

Create a custom render function that wraps components in necessary providers.

```tsx
import { render, type RenderOptions } from "@testing-library/react";
import { type ReactElement, type ReactNode } from "react";

interface WrapperProps {
  children: ReactNode;
}

function AllProviders({ children }: WrapperProps) {
  return (
    <ThemeProvider>
      <AuthProvider>
        <Router>{children}</Router>
      </AuthProvider>
    </ThemeProvider>
  );
}

function customRender(ui: ReactElement, options?: Omit<RenderOptions, "wrapper">) {
  return render(ui, { wrapper: AllProviders, ...options });
}

// Re-export everything from testing library
export * from "@testing-library/react";
export { customRender as render };
```

### Usage in tests

```tsx
import { render, screen } from "../test/test-utils"; // custom render

test("shows navigation for authenticated user", async () => {
  render(<Navigation />);
  expect(screen.getByRole("link", { name: "Dashboard" })).toBeInTheDocument();
});
```

## Testing Components with Router

```tsx
import { MemoryRouter, Route, Routes } from "react-router-dom";

test("navigates to profile page", async () => {
  const user = userEvent.setup();

  render(
    <MemoryRouter initialEntries={["/"]}>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/profile" element={<Profile />} />
      </Routes>
    </MemoryRouter>
  );

  await user.click(screen.getByRole("link", { name: "Profile" }));
  expect(screen.getByRole("heading", { name: "Your Profile" })).toBeInTheDocument();
});
```

## Mocking Modules

```tsx
// Mock a module
vi.mock("./api", () => ({
  fetchUser: vi.fn(),
}));

import { fetchUser } from "./api";

test("handles fetch error", async () => {
  vi.mocked(fetchUser).mockRejectedValueOnce(new Error("Network error"));

  render(<UserProfile userId="1" />);
  expect(await screen.findByText("Network error")).toBeInTheDocument();
});
```

### Mocking child components

```tsx
vi.mock("./HeavyChart", () => ({
  HeavyChart: ({ data }: { data: number[] }) => (
    <div data-testid="mock-chart">Chart with {data.length} points</div>
  ),
}));

test("renders dashboard with chart", () => {
  render(<Dashboard data={[1, 2, 3]} />);
  expect(screen.getByTestId("mock-chart")).toHaveTextContent("Chart with 3 points");
});
```

## Snapshot Testing (Use Sparingly)

Prefer explicit assertions. Use snapshots only for output that is hard to assert inline.

```tsx
test("renders error banner correctly", () => {
  const { container } = render(
    <ErrorBanner message="Something went wrong" severity="critical" />
  );
  expect(container.firstChild).toMatchSnapshot();
});

// Inline snapshots for small outputs
test("formats currency correctly", () => {
  expect(formatCurrency(1234.5)).toMatchInlineSnapshot(`"$1,234.50"`);
});
```

## Testing Accessibility

```tsx
import { axe, toHaveNoViolations } from "jest-axe";

expect.extend(toHaveNoViolations);

test("form has no accessibility violations", async () => {
  const { container } = render(<LoginForm />);
  const results = await axe(container);
  expect(results).toHaveNoViolations();
});
```

## Common Testing Mistakes

### Using getBy for async content

```tsx
// WRONG: getByText is synchronous, will fail if content loads async
test("bad async test", () => {
  render(<AsyncComponent />);
  expect(screen.getByText("Loaded")).toBeInTheDocument(); // fails
});

// CORRECT: use findByText which waits
test("good async test", async () => {
  render(<AsyncComponent />);
  expect(await screen.findByText("Loaded")).toBeInTheDocument();
});
```

### Wrapping non-state updates in act

```tsx
// WRONG: unnecessary act wrapping — userEvent handles it
test("bad act usage", async () => {
  const user = userEvent.setup();
  render(<Counter />);
  await act(async () => {
    await user.click(screen.getByRole("button"));
  });
});

// CORRECT: userEvent handles act internally
test("good usage", async () => {
  const user = userEvent.setup();
  render(<Counter />);
  await user.click(screen.getByRole("button"));
  expect(screen.getByText("1")).toBeInTheDocument();
});
```

### Testing implementation details

```tsx
// WRONG: testing internal state
test("bad test", () => {
  const { result } = renderHook(() => useState(0));
  expect(result.current[0]).toBe(0); // tests implementation

});

// CORRECT: test the component output
test("good test", async () => {
  const user = userEvent.setup();
  render(<Counter />);
  await user.click(screen.getByRole("button", { name: "Increment" }));
  expect(screen.getByText("Count: 1")).toBeInTheDocument();
});
```
