# CSS Grid Patterns Reference

Guide to CSS Grid layout including named areas, responsive patterns, subgrid, and production-ready grid recipes.

---

## Grid Fundamentals

### Defining a Grid Container

```css
.grid {
  display: grid;
  grid-template-columns: 200px 1fr 200px;
  grid-template-rows: auto 1fr auto;
  gap: 1rem;
}
```

Key properties:
- `grid-template-columns` / `grid-template-rows` -- Define explicit tracks.
- `gap` -- Gutters between tracks (shorthand for `row-gap` and `column-gap`).
- `grid-auto-rows` / `grid-auto-columns` -- Size for implicitly created tracks.
- `grid-auto-flow` -- Controls auto-placement (`row`, `column`, `dense`).

### Placing Items

```css
.item-a { grid-column: 1 / 3; grid-row: 1 / 2; }  /* by line number */
.item-b { grid-column: span 2; }                     /* span syntax */

/* Named lines */
.grid {
  grid-template-columns: [sidebar-start] 250px [sidebar-end content-start] 1fr [content-end];
}
.sidebar { grid-column: sidebar-start / sidebar-end; }
.content { grid-column: content-start / content-end; }
```

---

## Named Grid Areas

```css
.page {
  display: grid;
  grid-template-areas:
    "header  header  header"
    "nav     main    aside"
    "footer  footer  footer";
  grid-template-columns: 200px 1fr 250px;
  grid-template-rows: auto 1fr auto;
  min-height: 100dvh;
}

.page > header { grid-area: header; }
.page > nav    { grid-area: nav; }
.page > main   { grid-area: main; }
.page > aside  { grid-area: aside; }
.page > footer { grid-area: footer; }

@media (max-width: 768px) {
  .page {
    grid-template-areas: "header" "main" "nav" "aside" "footer";
    grid-template-columns: 1fr;
  }
}
```

Use `.` (dot) to leave a cell empty:

```css
.layout {
  grid-template-areas:
    "header header"
    "main   ."
    "footer footer";
}
```

---

## auto-fit vs auto-fill

### auto-fit -- Items stretch to fill the row

```css
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(min(100%, 280px), 1fr));
  gap: 1.5rem;
}
```

### auto-fill -- Empty tracks preserved, consistent column widths

```css
.thumbnail-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 1rem;
}
```

Use `auto-fit` when items should grow to fill space. Use `auto-fill` when column widths should stay consistent.

---

## Subgrid

Inherit track sizing from parent, aligning nested content across siblings.

```css
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1.5rem;
}
.card {
  display: grid;
  grid-template-rows: subgrid;
  grid-row: span 3;  /* image, body, footer -- aligned across cards */
}
```

Subgrid on columns for form alignment:

```css
.form-grid {
  display: grid;
  grid-template-columns: [label] max-content [input] 1fr;
  gap: 0.75rem 1rem;
}
.form-row {
  display: grid;
  grid-template-columns: subgrid;
  grid-column: 1 / -1;
}
```

---

## Responsive Grid Recipes

### Holy Grail

```css
.holy-grail {
  display: grid;
  grid-template:
    "header header header" auto
    "nav    main   aside"  1fr
    "footer footer footer" auto
    / 200px 1fr    200px;
  min-height: 100dvh;
}
@media (max-width: 960px) {
  .holy-grail {
    grid-template: "header" auto "main" 1fr "nav" auto "aside" auto "footer" auto / 1fr;
  }
}
```

### Dashboard Grid

```css
.dashboard {
  display: grid;
  grid-template-columns: repeat(12, 1fr);
  grid-auto-rows: minmax(100px, auto);
  gap: 1rem;
}
.widget--small  { grid-column: span 3; }
.widget--medium { grid-column: span 6; }
.widget--large  { grid-column: span 12; }
.widget--tall   { grid-row: span 2; }

@media (max-width: 768px) {
  .widget--small, .widget--medium { grid-column: span 6; }
}
@media (max-width: 480px) {
  .dashboard { grid-template-columns: 1fr; }
  .widget--small, .widget--medium, .widget--large { grid-column: span 1; }
}
```

### Masonry-like (Dense Packing)

```css
.masonry {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  grid-auto-rows: 50px;
  grid-auto-flow: dense;
  gap: 0.5rem;
}
.masonry__item--tall { grid-row: span 3; }
.masonry__item--wide { grid-column: span 2; }
```

---

## Alignment in Grid

```css
.grid {
  justify-items: center;   /* horizontal within cells */
  align-items: center;     /* vertical within cells */
  justify-content: center; /* horizontal alignment of the grid */
  align-content: center;   /* vertical alignment of the grid */
}
/* Per-item override */
.grid__item--end { justify-self: end; align-self: end; }
```

---

## Implicit vs Explicit Tracks

```css
.grid {
  grid-template-columns: repeat(3, 1fr);  /* 3 explicit columns */
  grid-template-rows: 200px 200px;        /* 2 explicit rows */
  grid-auto-rows: minmax(100px, auto);    /* implicit rows */
  grid-auto-columns: 150px;              /* implicit columns */
}
```

---

## Edge Cases

- **`minmax()` with `auto-fit`** -- Wrap min with `min(100%, Xpx)` to prevent small-screen overflow.
- **Percentage gaps** -- Can behave unexpectedly. Prefer `rem` or `px`.
- **`fr` and `minmax()`** -- Bare `1fr` equals `minmax(auto, 1fr)`. Use `minmax(0, 1fr)` to allow shrinking below content.
- **Overlapping items** -- Grid items can share cells. Use `z-index` for stacking.
- **Subgrid support** -- All modern browsers since 2024. Provide fallback if needed.
- **Debugging** -- Use browser DevTools grid inspector to visualize tracks, areas, and gaps.
