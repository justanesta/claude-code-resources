# Declaration Patterns

## Writing .d.ts Declaration Files

```typescript
// types.d.ts - Standalone type declarations
// Declaration files describe the shape of JavaScript code for TypeScript

// Declare a module with no existing types
declare module "untyped-library" {
  export function process(input: string): string;
  export function transform<T>(data: T, options?: TransformOptions): T;

  export interface TransformOptions {
    deep?: boolean;
    preserveNulls?: boolean;
  }

  export type ProcessResult = {
    output: string;
    metadata: Record<string, unknown>;
  };
}

// Declare a JSON module
declare module "*.json" {
  const value: Record<string, unknown>;
  export default value;
}

// Declare asset modules (common in bundler setups)
declare module "*.svg" { const content: string; export default content; }
declare module "*.css" { const classes: Record<string, string>; export default classes; }
declare module "*.png" { const src: string; export default src; }
```

## Module Augmentation

```typescript
// Extending third-party types without modifying node_modules

// Augment Express Request (express.d.ts)
import type { User } from "./models/user.js";

declare module "express-serve-static-core" {
  interface Request {
    user?: User;
    requestId: string;
    startTime: number;
  }

  interface Response {
    success<T>(data: T): void;
    error(code: number, message: string): void;
  }
}

// Usage in middleware
import type { Request, Response, NextFunction } from "express";

function authMiddleware(req: Request, res: Response, next: NextFunction): void {
  // req.user is now typed as User | undefined
  // req.requestId is typed as string
  next();
}

// Augment Window for global variables
declare global {
  interface Window {
    __APP_CONFIG__: {
      apiUrl: string;
      version: string;
      features: Record<string, boolean>;
    };
    dataLayer: Array<Record<string, unknown>>;
  }
}

// Usage
const apiUrl = window.__APP_CONFIG__.apiUrl; // Typed

// Augment existing interfaces from libraries
declare module "next" {
  interface NextApiRequest {
    session?: {
      userId: string;
      role: "admin" | "user";
    };
  }
}

// Augment process.env
declare global {
  namespace NodeJS {
    interface ProcessEnv {
      NODE_ENV: "development" | "production" | "test";
      PORT: string;
      DATABASE_URL: string;
      API_KEY: string;
      REDIS_URL?: string;
    }
  }
}

// Usage - typed environment variables
const port = parseInt(process.env.PORT, 10); // string (not string | undefined)
const redisUrl = process.env.REDIS_URL; // string | undefined (marked optional)
```

## Global Types and Declarations

```typescript
// global.d.ts - Types available everywhere without importing

// Global type aliases
declare global {
  type UUID = string & { readonly __brand: "UUID" };
  type Timestamp = number & { readonly __brand: "Timestamp" };
  type NonEmptyArray<T> = [T, ...T[]];

  // Global utility types
  type Nullable<T> = T | null;
  type Optional<T> = T | undefined;
  type Nullish<T> = T | null | undefined;
}

// Note: global.d.ts must have an export or import to be treated as a module
export {};

// Global constants from build tools
declare const __DEV__: boolean;
declare const __VERSION__: string;
declare const __BUILD_TIME__: string;

// Usage anywhere in the project
if (__DEV__) {
  console.log(`Version: ${__VERSION__}, Built: ${__BUILD_TIME__}`);
}

// Global functions injected by the runtime
declare function requestIdleCallback(
  callback: (deadline: { didTimeout: boolean; timeRemaining: () => number }) => void,
  options?: { timeout: number }
): number;

declare function cancelIdleCallback(handle: number): void;
```

## Ambient Declarations for Untyped Libraries

```typescript
// When a library has no @types package, create ambient declarations

// vendor.d.ts - Minimal declarations for an analytics library
declare module "analytics-sdk" {
  interface AnalyticsConfig {
    apiKey: string;
    endpoint?: string;
    debug?: boolean;
    batchSize?: number;
  }

  interface TrackEvent {
    name: string;
    properties?: Record<string, string | number | boolean>;
    timestamp?: Date;
  }

  interface Analytics {
    init(config: AnalyticsConfig): void;
    track(event: TrackEvent): void;
    identify(userId: string, traits?: Record<string, unknown>): void;
    page(name: string, properties?: Record<string, unknown>): void;
    flush(): Promise<void>;
    reset(): void;
  }

  const analytics: Analytics;
  export default analytics;
}

// Gradually typing: start loose, tighten over time
declare module "internal-utils" {
  // Phase 1: Basic structure
  export function parseConfig(raw: string): Record<string, unknown>;
  // Phase 2: Add overloads as you understand the code
  export function parseConfig(raw: string | Buffer): AppConfig;
}
```

## Barrel Exports and Module Organization

```typescript
// Barrel pattern: re-export from a single index file
// src/models/index.ts

// Re-export types (type-only)
export type { User, UserCreate, UserUpdate } from "./user.js";
export type { Post, PostCreate } from "./post.js";
export type { Comment } from "./comment.js";

// Re-export values
export { UserRole, DEFAULT_USER } from "./user.js";
export { PostStatus } from "./post.js";

// Re-export everything (use sparingly - harder to tree-shake)
export * from "./shared.js";

// Namespace re-exports for grouping
export * as UserModels from "./user.js";
export * as PostModels from "./post.js";

// Usage
import type { User, Post } from "./models/index.js";
import { UserRole, PostStatus } from "./models/index.js";

// Anti-pattern: circular barrel exports
// src/a.ts imports from src/index.ts which imports from src/a.ts
// Solution: import directly from the source file, not the barrel

// Recommended project structure
// src/
//   types/           - Shared type definitions
//     index.ts       - Barrel export
//     user.ts
//     api.ts
//   utils/           - Utility functions
//     index.ts
//   services/        - Business logic
//     index.ts
//   models/          - Data models
//     index.ts
```

## Const Assertions and Object Types

```typescript
// as const for immutable literal types
const HTTP_STATUS = {
  OK: 200,
  CREATED: 201,
  BAD_REQUEST: 400,
  UNAUTHORIZED: 401,
  NOT_FOUND: 404,
  SERVER_ERROR: 500,
} as const;

// Derive types from const objects
type HttpStatusCode = (typeof HTTP_STATUS)[keyof typeof HTTP_STATUS];
// => 200 | 201 | 400 | 401 | 404 | 500

type HttpStatusName = keyof typeof HTTP_STATUS;
// => "OK" | "CREATED" | "BAD_REQUEST" | "UNAUTHORIZED" | "NOT_FOUND" | "SERVER_ERROR"

// Const enum alternative (string-based)
const EVENTS = {
  USER_LOGIN: "user:login",
  USER_LOGOUT: "user:logout",
  PAGE_VIEW: "page:view",
  CLICK: "ui:click",
} as const;

type EventType = (typeof EVENTS)[keyof typeof EVENTS];
// => "user:login" | "user:logout" | "page:view" | "ui:click"

```

## Declaration Merging

```typescript
// Interface merging (most common)
interface Box { width: number; height: number }
interface Box { depth: number }
// Result: { width: number; height: number; depth: number }

// Class + namespace merging for static utilities
class Validator {
  validate(input: string): boolean {
    return Validator.patterns.email.test(input);
  }
}

namespace Validator {
  export const patterns = {
    email: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
    url: /^https?:\/\/.+/,
  };
}
```
