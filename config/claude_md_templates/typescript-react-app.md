# TypeScript React Application

## Project Type
React + TypeScript SPA or web application.

## Framework
- Vite for build tooling
- React 18+ with hooks (no class components)

## Structure
- src/components/, src/pages/, src/hooks/, src/utils/, src/types/, src/api/

## Core Libraries
- React Router for routing
- TanStack Query for data fetching
- Zod for validation
- Tailwind CSS for styling

## TypeScript Standards
- Strict mode enabled
- Proper typing for props, state, API responses
- Zod schemas + infer types for API data

## Component Design
- Functional components only
- Small, focused (single responsibility)
- Props interface for every component

## Testing
- Vitest + React Testing Library
- Test user interactions, not implementation
- Mock APIs with MSW
- Coverage target: 70%+

## Performance
- Code splitting: React.lazy() + Suspense
- Memoization: useMemo/useCallback where needed

## Accessibility
- Semantic HTML
- ARIA labels where needed
- Keyboard navigation
- WCAG AA contrast

## Deployment
- Build: `npm run build` → dist/
- Hosting: Vercel or Netlify (free tier)

## Documentation (in documentation/)
- architecture.md: Component structure, state management
- api.md: Endpoints, request/response shapes