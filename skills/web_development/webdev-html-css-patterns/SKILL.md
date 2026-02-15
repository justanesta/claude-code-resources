---
name: webdev-html-css-patterns
description: Modern HTML5 and CSS3 patterns for semantic markup, layout systems, responsive design, accessibility, and production-ready styling conventions
---

# HTML & CSS Patterns

## Core Principles

1. **Semantic HTML First** -- Use elements that convey meaning (`<article>`, `<nav>`, `<aside>`) rather than generic `<div>` and `<span>`. Semantic markup improves accessibility, SEO, and maintainability.
2. **Responsive by Default** -- Design for all viewports from the start using fluid units, modern layout systems, and progressive enhancement rather than retrofitting breakpoints.
3. **Accessibility as a Requirement** -- Every interface must be navigable by keyboard, screen reader, and assistive technology. ARIA supplements semantic HTML; it does not replace it.
4. **CSS Layout over Hacks** -- Use Grid and Flexbox for layout. Avoid floats, negative margins, and absolute positioning for page-level structure.
5. **Progressive Enhancement** -- Build a functional baseline with HTML, layer on styling with CSS, and enhance with JavaScript only when necessary.

---

## Semantic HTML5 Structure

Use landmark elements to define page regions. Screen readers and search engines rely on this hierarchy.

```html
<body>
  <header role="banner">
    <nav aria-label="Primary navigation">
      <ul>
        <li><a href="/">Home</a></li>
        <li><a href="/about">About</a></li>
      </ul>
    </nav>
  </header>

  <main id="main-content">
    <article>
      <h1>Article Heading</h1>
      <section aria-labelledby="section-title">
        <h2 id="section-title">Section Title</h2>
        <p>Content goes here.</p>
      </section>
    </article>
    <aside aria-label="Related content">
      <h2>Related Links</h2>
    </aside>
  </main>

  <footer role="contentinfo">
    <p>&copy; 2026 Company Name</p>
  </footer>
</body>
```

See [semantic-html-patterns](references/semantic-html-patterns.md) for: form patterns, table markup, meta tags, SEO elements, and content sectioning rules.

---

## CSS Grid Layout

Grid is the primary tool for two-dimensional layouts. Define explicit tracks or let the browser auto-place items.

```css
/* Responsive card grid with auto-fit */
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 300px), 1fr));
  gap: 1.5rem;
  padding: 1.5rem;
}

/* Named grid areas for page layout */
.page-layout {
  display: grid;
  grid-template-areas:
    "header  header"
    "sidebar main"
    "footer  footer";
  grid-template-columns: 250px 1fr;
  grid-template-rows: auto 1fr auto;
  min-height: 100dvh;
}

.page-layout > header  { grid-area: header; }
.page-layout > aside   { grid-area: sidebar; }
.page-layout > main    { grid-area: main; }
.page-layout > footer  { grid-area: footer; }
```

See [css-grid-patterns](references/css-grid-patterns.md) for: named areas, auto-fit vs auto-fill, subgrid, implicit tracks, and responsive grid recipes.

---

## Flexbox Patterns

Flexbox handles one-dimensional alignment and distribution. Use it for component-level layout within grid cells.

```css
/* Navigation bar */
.navbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1.5rem;
  gap: 1rem;
}

/* Centering content vertically and horizontally */
.centered-container {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100dvh;
}

/* Card with footer pinned to bottom */
.card {
  display: flex;
  flex-direction: column;
  min-height: 300px;
}

.card__body   { flex: 1 1 auto; }
.card__footer { flex: 0 0 auto; margin-top: auto; }
```

See [flexbox-patterns](references/flexbox-patterns.md) for: flex-grow/shrink/basis, wrapping, order, alignment edge cases, and common layout recipes.

---

## Responsive Design

Combine fluid units, modern CSS functions, and breakpoints. Prefer intrinsic sizing before reaching for media queries.

```css
/* Fluid typography with clamp() */
h1 {
  font-size: clamp(1.75rem, 1rem + 2.5vw, 3.5rem);
  line-height: 1.2;
}

p {
  font-size: clamp(1rem, 0.9rem + 0.5vw, 1.25rem);
  line-height: 1.6;
  max-width: 65ch;
}

/* Container queries for component-level responsiveness */
.card-wrapper {
  container-type: inline-size;
  container-name: card;
}

@container card (min-width: 400px) {
  .card {
    flex-direction: row;
  }
  .card__image {
    width: 40%;
  }
}

/* Standard breakpoint media queries */
@media (max-width: 768px) {
  .page-layout {
    grid-template-areas:
      "header"
      "main"
      "sidebar"
      "footer";
    grid-template-columns: 1fr;
  }
}
```

See [responsive-design-patterns](references/responsive-design-patterns.md) for: breakpoint strategies, fluid images, responsive tables, container queries, and `prefers-*` media features.

---

## Accessibility

Supplement semantic HTML with ARIA only when native elements cannot express the required role or state.

```html
<!-- Accessible modal dialog -->
<dialog id="confirm-dialog" aria-labelledby="dialog-title" aria-describedby="dialog-desc">
  <h2 id="dialog-title">Confirm Action</h2>
  <p id="dialog-desc">Are you sure you want to delete this item?</p>
  <div class="dialog-actions">
    <button type="button" autofocus>Cancel</button>
    <button type="button" class="btn--danger">Delete</button>
  </div>
</dialog>

<!-- Skip navigation link -->
<a href="#main-content" class="skip-link">Skip to main content</a>
```

See [accessibility-patterns](references/accessibility-patterns.md) for: ARIA roles and properties, keyboard navigation, focus management, color contrast, and screen reader testing.

---

## BEM Naming Convention

Block-Element-Modifier keeps CSS selectors flat, predictable, and collision-free.

```css
.card          { }               /* Block */
.card__title   { }               /* Element -- part of the block */
.card__body    { }
.card--featured { }              /* Modifier -- variation */
.nav__link--active {             /* Real-world modifier */
  font-weight: 700;
  border-bottom: 2px solid currentColor;
}
```

---

## Anti-Patterns

| Avoid | Use Instead |
|---|---|
| `<div class="header">` for page header | `<header role="banner">` with semantic element |
| `float: left` for multi-column layout | CSS Grid or Flexbox |
| `px` for font sizes | `rem`, `em`, or `clamp()` for fluid sizing |
| `!important` to override styles | Increase specificity or restructure cascade |
| Inline styles (`style="..."`) | External stylesheets or CSS custom properties |
| `<table>` for page layout | CSS Grid for two-dimensional layout |
| `<div onclick="...">` for buttons | `<button type="button">` with event listener |
| Deeply nested selectors `.a .b .c .d` | BEM flat selectors `.block__element--modifier` |
| Color as only indicator of state | Color plus icon, text, or pattern |

---

## Performance

- **Critical CSS** -- Inline above-the-fold styles in `<head>` and defer the rest with `media="print" onload="this.media='all'"`.
- **Image optimization** -- Use `<picture>` with `srcset`/`sizes`. Serve WebP/AVIF with fallbacks. Set `width`/`height` to prevent layout shift.
- **Font loading** -- Use `font-display: swap` and preload critical fonts with `<link rel="preload" as="font" crossorigin>`.
- **Reduce repaints** -- Animate only `transform` and `opacity`. Use `will-change` sparingly.
- **Minimize layout shift** -- Reserve space with `aspect-ratio`, explicit dimensions, or `min-height`.
- **Lazy loading** -- Add `loading="lazy"` to offscreen images and iframes.

```html
<picture>
  <source srcset="hero.avif" type="image/avif">
  <source srcset="hero.webp" type="image/webp">
  <img src="hero.jpg" alt="Descriptive alt text" width="1200" height="600" loading="lazy" decoding="async">
</picture>
```

source: MDN Web Docs (developer.mozilla.org), W3C HTML/CSS Specifications, Web Content Accessibility Guidelines (WCAG) 2.2, web.dev by Google
