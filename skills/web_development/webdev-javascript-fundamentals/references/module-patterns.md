# ES Module Patterns Reference

Comprehensive reference for modern JavaScript module system patterns in web development.

---

## Named Exports

Named exports are the preferred default. They enable tree shaking and provide clear, discoverable APIs.

```javascript
// utils/validation.js — multiple named exports
export function validateEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

export function validatePhone(phone) {
  return /^\+?[\d\s-()]{7,15}$/.test(phone);
}

export function validateRequired(value) {
  return value !== null && value !== undefined && String(value).trim().length > 0;
}

// Exporting constants
export const MAX_FILE_SIZE = 10 * 1024 * 1024; // 10 MB
export const ALLOWED_MIME_TYPES = ["image/png", "image/jpeg", "image/webp"];
```

### Importing named exports

```javascript
// Import specific exports
import { validateEmail, validatePhone } from "./utils/validation.js";

// Rename on import to avoid conflicts
import { validateEmail as isValidEmail } from "./utils/validation.js";

// Import all as namespace
import * as Validation from "./utils/validation.js";
Validation.validateEmail("test@example.com");
```

---

## Default Exports

Use default exports sparingly — only for a module's single primary entity.

```javascript
// services/UserService.js — class as default export
export default class UserService {
  #apiBase;

  constructor(apiBase = "/api") {
    this.#apiBase = apiBase;
  }

  async getUser(id) {
    const response = await fetch(`${this.#apiBase}/users/${id}`);
    if (!response.ok) throw new HttpError(response.status);
    return response.json();
  }

  async updateUser(id, data) {
    const response = await fetch(`${this.#apiBase}/users/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(data),
    });
    if (!response.ok) throw new HttpError(response.status);
    return response.json();
  }
}

// Importing default export
import UserService from "./services/UserService.js";
const userService = new UserService();
```

### Mixing default and named exports

```javascript
// config.js
export const ENV = import.meta.env?.MODE ?? "development";
export const API_BASE = import.meta.env?.VITE_API_URL ?? "http://localhost:3000";

const config = { ENV, API_BASE };
export default config;

// Importing both
import config, { ENV, API_BASE } from "./config.js";
```

---

## Re-exports and Barrel Files

### Barrel file pattern (index.js)

Barrel files aggregate exports from multiple modules into a single entry point.

```javascript
// utils/index.js — barrel file
export { validateEmail, validatePhone, validateRequired } from "./validation.js";
export { formatDate, formatCurrency, formatNumber } from "./formatting.js";
export { debounce, throttle, memoize } from "./performance.js";
export { cn, classNames } from "./classnames.js";
```

### Barrel file cautions

```javascript
// PROBLEM: barrel files can defeat tree shaking if not structured carefully

// BAD — imports everything in the barrel, bundler may not tree-shake
import { validateEmail } from "./utils/index.js";

// BETTER — direct import when bundle size matters
import { validateEmail } from "./utils/validation.js";

// BEST — barrel files work well with modern bundlers (Vite, Rollup, esbuild)
// when every re-export is a pure named export from a separate file
```

### Selective re-exports

```javascript
// public-api.js — expose only the public API
export { createApp, defineComponent } from "./core.js";
export { ref, reactive, computed } from "./reactivity.js";
// Internal helpers are NOT re-exported
```

---

## Dynamic Imports

### Route-based code splitting

```javascript
// Route-level lazy loading
const routes = {
  "/": () => import("./pages/Home.js"),
  "/dashboard": () => import("./pages/Dashboard.js"),
  "/settings": () => import("./pages/Settings.js"),
};

async function navigateTo(path) {
  const loader = routes[path];
  if (!loader) {
    const { NotFound } = await import("./pages/NotFound.js");
    return new NotFound();
  }
  const module = await loader();
  return new module.default();
}
```

### Conditional feature loading

```javascript
// Load heavy libraries only when needed
async function initializeEditor(container) {
  const { marked } = await import("marked");
  const { highlight } = await import("highlight.js");

  return {
    render(markdown) {
      return marked(markdown, {
        highlight: (code, lang) => highlight(code, { language: lang }).value,
      });
    },
  };
}

// Feature detection before loading
async function initAnalytics() {
  if (navigator.doNotTrack === "1") return;
  const { Analytics } = await import("./analytics.js");
  return new Analytics(window.location.origin);
}
```

### Preloading modules

```javascript
// Preload on hover for faster navigation
function preloadOnHover(link, moduleLoader) {
  let preloaded = false;
  link.addEventListener(
    "mouseenter",
    () => {
      if (!preloaded) {
        moduleLoader(); // Starts the fetch, result is cached by the browser
        preloaded = true;
      }
    },
    { once: false }
  );
}

// Link-based preloading
const moduleLink = document.createElement("link");
moduleLink.rel = "modulepreload";
moduleLink.href = "./pages/Dashboard.js";
document.head.appendChild(moduleLink);
```

---

## Import Attributes (ES2025)

```javascript
// JSON imports
import translations from "./locales/en.json" with { type: "json" };

// CSS imports (where supported)
import styles from "./component.css" with { type: "css" };
document.adoptedStyleSheets.push(styles);

// Dynamic import with attributes
const config = await import("./config.json", { with: { type: "json" } });
```

---

## Module Metadata

```javascript
// import.meta — module-specific metadata
console.log(import.meta.url); // Full URL of the current module

// Resolve relative paths from the module
const workerUrl = new URL("./worker.js", import.meta.url);
const worker = new Worker(workerUrl, { type: "module" });

// Load assets relative to the module
const iconUrl = new URL("../assets/icon.svg", import.meta.url);

// Environment variables (Vite pattern)
const isDev = import.meta.env?.DEV ?? false;
```

---

## Circular Dependency Avoidance

### Problem — circular imports

```javascript
// BAD: circular dependency
// fileA.js
import { funcB } from "./fileB.js"; // fileB imports from fileA
export function funcA() { return funcB(); }

// fileB.js
import { funcA } from "./fileA.js"; // Circular!
export function funcB() { return funcA(); }
```

### Solution — extract shared code

```javascript
// GOOD: extract shared dependency into a third module
// shared.js
export function sharedLogic() { /* ... */ }

// fileA.js
import { sharedLogic } from "./shared.js";
export function funcA() { return sharedLogic(); }

// fileB.js
import { sharedLogic } from "./shared.js";
export function funcB() { return sharedLogic(); }
```

---

## Tree Shaking Best Practices

- **Use named exports** — default exports are harder for bundlers to analyze statically
- **Avoid side effects in module scope** — mark packages as `"sideEffects": false` in `package.json`
- **Do not re-export entire namespaces** — `export * from` prevents dead code elimination
- **Keep modules focused** — smaller modules with fewer exports are easier to tree-shake

```javascript
// package.json — enable tree shaking
{
  "sideEffects": false,
  "exports": {
    ".": { "import": "./dist/esm/index.js", "require": "./dist/cjs/index.js" },
    "./utils": "./dist/esm/utils/index.js"
  }
}
```

source: MDN Web Docs, Node.js Documentation, Vite Documentation, Rollup Documentation
