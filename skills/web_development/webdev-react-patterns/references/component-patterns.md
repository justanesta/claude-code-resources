# Component Patterns Reference

Advanced composition patterns for building flexible, reusable React components with TypeScript.

## Children Composition

The simplest and most common pattern. Pass components as children to avoid prop drilling.

```tsx
import { type ReactNode } from "react";

interface CardProps {
  children: ReactNode;
  variant?: "default" | "outlined";
}

function Card({ children, variant = "default" }: CardProps) {
  return <div className={`card card--${variant}`}>{children}</div>;
}

function CardHeader({ children }: { children: ReactNode }) {
  return <div className="card-header">{children}</div>;
}

function CardBody({ children }: { children: ReactNode }) {
  return <div className="card-body">{children}</div>;
}

// Usage
<Card variant="outlined">
  <CardHeader>Title</CardHeader>
  <CardBody>Content goes here</CardBody>
</Card>
```

## Compound Components

Share implicit state between a parent and its children using context.

```tsx
import { createContext, useContext, useState, type ReactNode } from "react";

interface AccordionContextValue {
  openItems: Set<string>;
  toggle: (id: string) => void;
}

const AccordionContext = createContext<AccordionContextValue | null>(null);

function useAccordion() {
  const ctx = useContext(AccordionContext);
  if (!ctx) throw new Error("Accordion components must be used within <Accordion>");
  return ctx;
}

interface AccordionProps {
  children: ReactNode;
  allowMultiple?: boolean;
}

function Accordion({ children, allowMultiple = false }: AccordionProps) {
  const [openItems, setOpenItems] = useState<Set<string>>(new Set());

  function toggle(id: string) {
    setOpenItems((prev) => {
      const next = new Set(allowMultiple ? prev : []);
      if (prev.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  }

  return (
    <AccordionContext.Provider value={{ openItems, toggle }}>
      <div role="region">{children}</div>
    </AccordionContext.Provider>
  );
}

interface AccordionItemProps {
  id: string;
  title: string;
  children: ReactNode;
}

function AccordionItem({ id, title, children }: AccordionItemProps) {
  const { openItems, toggle } = useAccordion();
  const isOpen = openItems.has(id);

  return (
    <div>
      <button
        role="button"
        aria-expanded={isOpen}
        onClick={() => toggle(id)}
      >
        {title}
      </button>
      {isOpen && <div role="region">{children}</div>}
    </div>
  );
}

// Attach sub-components for clean API
Accordion.Item = AccordionItem;

// Usage
<Accordion allowMultiple>
  <Accordion.Item id="faq-1" title="What is React?">
    A JavaScript library for building user interfaces.
  </Accordion.Item>
  <Accordion.Item id="faq-2" title="What are hooks?">
    Functions that let you use state and lifecycle in function components.
  </Accordion.Item>
</Accordion>
```

## Render Props

Pass a function as a prop to share rendering logic. Useful when the parent needs fine-grained control.

```tsx
interface MousePosition {
  x: number;
  y: number;
}

interface MouseTrackerProps {
  render: (position: MousePosition) => ReactNode;
}

function MouseTracker({ render }: MouseTrackerProps) {
  const [position, setPosition] = useState<MousePosition>({ x: 0, y: 0 });

  return (
    <div
      onMouseMove={(e) => setPosition({ x: e.clientX, y: e.clientY })}
      style={{ height: "100vh" }}
    >
      {render(position)}
    </div>
  );
}

// Usage
<MouseTracker
  render={({ x, y }) => (
    <div style={{ position: "absolute", left: x, top: y }}>
      Cursor at ({x}, {y})
    </div>
  )}
/>
```

### Children as render prop

```tsx
interface DataLoaderProps<T> {
  url: string;
  children: (data: T, loading: boolean) => ReactNode;
}

function DataLoader<T>({ url, children }: DataLoaderProps<T>) {
  const { data, loading } = useFetch<T>(url);
  return <>{children(data as T, loading)}</>;
}

// Usage
<DataLoader<User[]> url="/api/users">
  {(users, loading) =>
    loading ? <Spinner /> : users.map((u) => <UserCard key={u.id} user={u} />)
  }
</DataLoader>
```

## Higher-Order Components (HOCs)

Wrap a component to inject additional props or behavior. Use sparingly — prefer hooks for most cases.

```tsx
interface WithAuthProps {
  user: User;
}

function withAuth<P extends WithAuthProps>(WrappedComponent: React.ComponentType<P>) {
  function AuthenticatedComponent(props: Omit<P, keyof WithAuthProps>) {
    const { user } = useAuthState();

    if (!user) return <Navigate to="/login" />;

    return <WrappedComponent {...(props as P)} user={user} />;
  }

  AuthenticatedComponent.displayName = `withAuth(${
    WrappedComponent.displayName || WrappedComponent.name || "Component"
  })`;

  return AuthenticatedComponent;
}

// Usage
function Dashboard({ user }: WithAuthProps) {
  return <h1>Welcome, {user.name}</h1>;
}

const ProtectedDashboard = withAuth(Dashboard);
// <ProtectedDashboard /> — no need to pass `user`
```

## Polymorphic Components

Allow the rendered element to be customized via an `as` prop.

```tsx
import { type ElementType, type ComponentPropsWithoutRef } from "react";

type ButtonProps<T extends ElementType = "button"> = {
  as?: T;
  variant?: "primary" | "secondary" | "ghost";
  children: ReactNode;
} & ComponentPropsWithoutRef<T>;

function Button<T extends ElementType = "button">({
  as,
  variant = "primary",
  children,
  ...rest
}: ButtonProps<T>) {
  const Component = as ?? "button";

  return (
    <Component className={`btn btn--${variant}`} {...rest}>
      {children}
    </Component>
  );
}

// Usage
<Button variant="primary" onClick={handleClick}>Click me</Button>
<Button as="a" href="/about" variant="ghost">About</Button>
<Button as={Link} to="/dashboard" variant="secondary">Dashboard</Button>
```

## Slot Pattern

Named slots give consumers control over specific areas of a component.

```tsx
interface PageLayoutProps {
  header: ReactNode;
  sidebar?: ReactNode;
  children: ReactNode;
  footer?: ReactNode;
}

function PageLayout({ header, sidebar, children, footer }: PageLayoutProps) {
  return (
    <div className="layout">
      <header className="layout-header">{header}</header>
      <div className="layout-body">
        {sidebar && <aside className="layout-sidebar">{sidebar}</aside>}
        <main className="layout-content">{children}</main>
      </div>
      {footer && <footer className="layout-footer">{footer}</footer>}
    </div>
  );
}

// Usage
<PageLayout
  header={<NavBar />}
  sidebar={<SideMenu />}
  footer={<FooterLinks />}
>
  <ArticleContent />
</PageLayout>
```

## forwardRef Pattern

Forward refs to inner DOM elements for imperative access from parent components.

```tsx
import { forwardRef, useImperativeHandle, useRef } from "react";

interface InputProps {
  label: string;
  error?: string;
}

const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { label, error },
  ref
) {
  const id = useId();

  return (
    <div>
      <label htmlFor={id}>{label}</label>
      <input ref={ref} id={id} aria-invalid={!!error} aria-describedby={error ? `${id}-error` : undefined} />
      {error && <p id={`${id}-error`} role="alert">{error}</p>}
    </div>
  );
});

// Usage
function Form() {
  const inputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    inputRef.current?.focus();
  }, []);

  return <Input ref={inputRef} label="Email" />;
}
```

### useImperativeHandle for custom ref API

```tsx
interface ModalHandle {
  open: () => void;
  close: () => void;
}

const Modal = forwardRef<ModalHandle, { children: ReactNode }>(function Modal(
  { children },
  ref
) {
  const [isOpen, setIsOpen] = useState(false);

  useImperativeHandle(ref, () => ({
    open: () => setIsOpen(true),
    close: () => setIsOpen(false),
  }));

  if (!isOpen) return null;
  return <div role="dialog">{children}</div>;
});

// Usage
function App() {
  const modalRef = useRef<ModalHandle>(null);

  return (
    <>
      <button onClick={() => modalRef.current?.open()}>Open Modal</button>
      <Modal ref={modalRef}>
        <p>Modal content</p>
        <button onClick={() => modalRef.current?.close()}>Close</button>
      </Modal>
    </>
  );
}
```

## Controlled vs Uncontrolled Pattern

Support both controlled and uncontrolled usage for maximum flexibility.

```tsx
interface ToggleProps {
  defaultChecked?: boolean;
  checked?: boolean;
  onChange?: (checked: boolean) => void;
  label: string;
}

function Toggle({ defaultChecked = false, checked: controlledChecked, onChange, label }: ToggleProps) {
  const [internalChecked, setInternalChecked] = useState(defaultChecked);
  const isControlled = controlledChecked !== undefined;
  const isChecked = isControlled ? controlledChecked : internalChecked;

  function handleToggle() {
    const next = !isChecked;
    if (!isControlled) setInternalChecked(next);
    onChange?.(next);
  }

  return (
    <button role="switch" aria-checked={isChecked} onClick={handleToggle}>
      {label}: {isChecked ? "On" : "Off"}
    </button>
  );
}

// Uncontrolled
<Toggle label="Notifications" defaultChecked onChange={console.log} />

// Controlled
<Toggle label="Dark Mode" checked={isDark} onChange={setIsDark} />
```

## Generic List Component

Type-safe list rendering with a render prop for each item.

```tsx
interface ListProps<T> {
  items: T[];
  renderItem: (item: T, index: number) => ReactNode;
  keyExtractor: (item: T) => string;
  emptyMessage?: string;
}

function List<T>({ items, renderItem, keyExtractor, emptyMessage = "No items" }: ListProps<T>) {
  if (items.length === 0) return <p>{emptyMessage}</p>;

  return (
    <ul>
      {items.map((item, index) => (
        <li key={keyExtractor(item)}>{renderItem(item, index)}</li>
      ))}
    </ul>
  );
}

// Usage
<List
  items={users}
  keyExtractor={(user) => user.id}
  renderItem={(user) => <UserCard user={user} />}
  emptyMessage="No users found"
/>
```
