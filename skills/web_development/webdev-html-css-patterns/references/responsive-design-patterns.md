# Responsive Design Patterns Reference

Guide to responsive web design including breakpoints, fluid typography, responsive images, container queries, and user preference media features.

---

## Breakpoint Strategy

### Standard Breakpoints (Mobile-First)

```css
/* Base styles for smallest screens */

@media (min-width: 640px)  { /* Small tablets */ }
@media (min-width: 768px)  { /* Tablets */ }
@media (min-width: 1024px) { /* Small desktops */ }
@media (min-width: 1280px) { /* Large desktops */ }
@media (min-width: 1536px) { /* Extra-large screens */ }
```

### Custom Properties at Breakpoints

```css
:root {
  --content-max-width: 100%;
  --content-padding: 1rem;
}

@media (min-width: 768px) {
  :root { --content-padding: 2rem; }
}

@media (min-width: 1024px) {
  :root {
    --content-max-width: 1200px;
    --content-padding: 3rem;
  }
}

.page {
  max-width: var(--content-max-width);
  padding: var(--content-padding);
  margin: 0 auto;
}
```

---

## Fluid Typography

### clamp() for Font Sizes

```css
h1 { font-size: clamp(2rem, 1.5rem + 2.5vw, 4rem); }
h2 { font-size: clamp(1.5rem, 1.2rem + 1.5vw, 2.5rem); }
h3 { font-size: clamp(1.25rem, 1rem + 1vw, 1.75rem); }
body {
  font-size: clamp(1rem, 0.95rem + 0.25vw, 1.125rem);
  line-height: 1.6;
}
```

### Fluid Spacing

```css
:root {
  --space-xs: clamp(0.25rem, 0.2rem + 0.25vw, 0.5rem);
  --space-sm: clamp(0.5rem, 0.4rem + 0.5vw, 1rem);
  --space-md: clamp(1rem, 0.8rem + 1vw, 2rem);
  --space-lg: clamp(1.5rem, 1rem + 2.5vw, 4rem);
  --space-xl: clamp(2rem, 1.5rem + 3vw, 6rem);
}
```

### Typographic Scale

```css
:root {
  --step--1: clamp(0.833rem, 0.8rem + 0.17vw, 0.889rem);
  --step-0:  clamp(1rem, 0.95rem + 0.25vw, 1.125rem);
  --step-1:  clamp(1.2rem, 1.1rem + 0.5vw, 1.5rem);
  --step-2:  clamp(1.44rem, 1.25rem + 0.95vw, 2rem);
  --step-3:  clamp(1.728rem, 1.4rem + 1.64vw, 2.667rem);
  --step-4:  clamp(2.074rem, 1.55rem + 2.62vw, 3.556rem);
}

small { font-size: var(--step--1); }
body  { font-size: var(--step-0); }
h4    { font-size: var(--step-1); }
h3    { font-size: var(--step-2); }
h2    { font-size: var(--step-3); }
h1    { font-size: var(--step-4); }
```

---

## Responsive Images

### srcset and sizes

```html
<img
  src="photo-800.jpg"
  srcset="photo-400.jpg 400w, photo-800.jpg 800w, photo-1200.jpg 1200w, photo-1600.jpg 1600w"
  sizes="(max-width: 640px) 100vw, (max-width: 1024px) 50vw, 33vw"
  alt="Descriptive alt text"
  width="1600" height="900" loading="lazy" decoding="async"
>
```

### Picture Element with Art Direction

```html
<picture>
  <source media="(max-width: 639px)" srcset="hero-mobile.avif" type="image/avif">
  <source media="(max-width: 639px)" srcset="hero-mobile.webp" type="image/webp">
  <source srcset="hero-desktop.avif" type="image/avif">
  <source srcset="hero-desktop.webp" type="image/webp">
  <img src="hero-desktop.jpg" alt="Hero image description" width="1920" height="800">
</picture>
```

### Fluid Images and Video

```css
img {
  max-width: 100%;
  height: auto;
  display: block;
}

.video-wrapper {
  aspect-ratio: 16 / 9;
  width: 100%;
}
.video-wrapper > iframe {
  width: 100%;
  height: 100%;
  border: 0;
}

.hero-image {
  width: 100%;
  height: 400px;
  object-fit: cover;
  object-position: center top;
}
```

---

## Container Queries

### Basic Container Query

```css
.card-wrapper {
  container: card / inline-size;
}

@container card (min-width: 400px) {
  .card {
    display: flex;
    flex-direction: row;
    gap: 1rem;
  }
  .card__image { flex: 0 0 40%; }
}

@container card (min-width: 700px) {
  .card__title { font-size: 1.5rem; }
  .card__meta { display: flex; gap: 1rem; }
}
```

### Container Query Units

```css
.card-wrapper { container-type: inline-size; }

.card__title {
  font-size: clamp(1rem, 4cqw, 2rem);  /* cqw = 1% of container width */
  padding: 2cqw;
}
```

### Nested Containers

```css
.sidebar        { container: sidebar / inline-size; }
.sidebar__widget { container: widget / inline-size; }

@container sidebar (min-width: 300px) {
  .sidebar__title { font-size: 1.25rem; }
}
@container widget (min-width: 200px) {
  .widget__grid { display: grid; grid-template-columns: 1fr 1fr; }
}
```

---

## Responsive Tables

### Horizontal Scroll

```css
.table-wrapper {
  overflow-x: auto;
  -webkit-overflow-scrolling: touch;
}
.table-wrapper table {
  min-width: 600px;
  width: 100%;
}
```

### Stacked Cards on Mobile

```css
@media (max-width: 640px) {
  table, thead, tbody, tr, th, td { display: block; }
  thead { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0,0,0,0); }
  tr { margin-bottom: 1rem; border: 1px solid #ddd; border-radius: 0.5rem; padding: 0.75rem; }
  td { display: flex; justify-content: space-between; padding: 0.25rem 0; border: none; }
  td::before { content: attr(data-label); font-weight: 700; flex: 0 0 40%; }
}
```

---

## User Preference Media Features

### Dark Mode

```css
:root {
  --color-bg: #ffffff;
  --color-text: #1a1a1a;
  --color-primary: #2563eb;
}
@media (prefers-color-scheme: dark) {
  :root {
    --color-bg: #0f0f0f;
    --color-text: #e5e5e5;
    --color-primary: #60a5fa;
  }
}
body { background-color: var(--color-bg); color: var(--color-text); }
```

### Reduced Motion

```css
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

### Forced Colors / High Contrast

```css
@media (forced-colors: active) {
  .button { border: 2px solid ButtonText; }
}
@media (prefers-contrast: more) {
  :root { --color-border: #000000; --color-text: #000000; }
}
```

---

## Edge Cases

- **`100vh` on mobile** -- Does not account for browser chrome. Use `100dvh`.
- **Font size minimum** -- Never set body text below `16px` / `1rem`.
- **Touch targets** -- At least 44x44px tap area. Use padding to increase.
- **Container query sizing** -- `container-type: inline-size` means the element cannot size itself from its content inline.
- **Print styles** -- Include `@media print` to hide nav, adjust colors, show URLs after links.
- **Testing** -- Test on real devices, not just browser DevTools resize.
