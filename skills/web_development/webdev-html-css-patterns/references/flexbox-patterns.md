# Flexbox Patterns Reference

Guide to CSS Flexbox layout including alignment, wrapping, sizing, and production-ready component recipes.

---

## Flex Container Fundamentals

```css
.flex-container {
  display: flex;             /* or inline-flex */
  flex-direction: row;       /* row, row-reverse, column, column-reverse */
  flex-wrap: wrap;           /* nowrap (default), wrap, wrap-reverse */
  gap: 1rem;
}

/* Shorthand: flex-flow combines direction and wrap */
.flex-container { flex-flow: row wrap; }
```

---

## Alignment Properties

### Main Axis (justify-content)

```css
.justify-start   { justify-content: flex-start; }    /* default */
.justify-end     { justify-content: flex-end; }
.justify-center  { justify-content: center; }
.justify-between { justify-content: space-between; }  /* first/last flush */
.justify-around  { justify-content: space-around; }   /* equal space around */
.justify-evenly  { justify-content: space-evenly; }   /* equal gaps everywhere */
```

### Cross Axis (align-items / align-self)

```css
.align-stretch  { align-items: stretch; }    /* default */
.align-start    { align-items: flex-start; }
.align-center   { align-items: center; }
.align-baseline { align-items: baseline; }

/* Override on individual items */
.item-self-end  { align-self: flex-end; }
```

### Multi-line (align-content)

Only applies when `flex-wrap: wrap` produces multiple lines.

```css
.multiline {
  display: flex;
  flex-wrap: wrap;
  align-content: flex-start;
  /* Also: flex-end, center, space-between, space-around, stretch */
}
```

---

## Flex Item Sizing

```css
/* flex shorthand: grow shrink basis */
.item-auto    { flex: 1 1 auto; }    /* grow/shrink from content size */
.item-none    { flex: 0 0 auto; }    /* fixed at content size */
.item-fill    { flex: 1 1 0%; }      /* equal distribution, ignore content */
.item-initial { flex: 0 1 auto; }    /* default: shrink only */

/* One item fills remaining space */
.sidebar { flex: 0 0 250px; }
.content { flex: 1 1 0%; }
```

### Understanding flex-basis

```css
.item { flex-basis: 200px; }         /* starts at 200px, may grow or shrink */

/* flex-basis: auto uses width/height as the basis */
.item { width: 300px; flex-basis: auto; }  /* basis is 300px */

/* flex-basis: 0 for equal columns regardless of content */
.equal-columns > * { flex: 1 1 0%; }
```

---

## Common Layout Patterns

### Navigation Bar

```css
.navbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1.5rem;
  gap: 1rem;
}
.navbar__logo    { flex: 0 0 auto; }
.navbar__links   { display: flex; gap: 1.5rem; list-style: none; margin: 0; padding: 0; }
.navbar__actions { display: flex; gap: 0.5rem; flex: 0 0 auto; }
```

### Card with Pinned Footer

```css
.card        { display: flex; flex-direction: column; height: 100%; }
.card__image { flex: 0 0 auto; aspect-ratio: 16/9; object-fit: cover; width: 100%; }
.card__body  { flex: 1 1 auto; padding: 1rem; }
.card__footer { flex: 0 0 auto; padding: 1rem; margin-top: auto; }
```

### Centered Content

```css
.centered {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 100dvh;
}
```

### Media Object (Image + Text)

```css
.media       { display: flex; gap: 1rem; align-items: flex-start; }
.media__image { flex: 0 0 auto; width: 64px; height: 64px; border-radius: 50%; object-fit: cover; }
.media__body { flex: 1 1 0%; min-width: 0; }
```

### Holy Grail with Flexbox

```css
.page          { display: flex; flex-direction: column; min-height: 100dvh; }
.page__header  { flex: 0 0 auto; }
.page__footer  { flex: 0 0 auto; }
.page__body    { flex: 1 1 auto; display: flex; gap: 1rem; }
.page__nav     { flex: 0 0 200px; order: -1; }
.page__main    { flex: 1 1 auto; min-width: 0; }
.page__sidebar { flex: 0 0 250px; }
```

### Input Group

```css
.input-group        { display: flex; align-items: stretch; }
.input-group__addon  { flex: 0 0 auto; display: flex; align-items: center; padding: 0 0.75rem; background: #f0f0f0; border: 1px solid #ccc; }
.input-group__input  { flex: 1 1 auto; min-width: 0; padding: 0.5rem 0.75rem; border: 1px solid #ccc; border-left: none; }
.input-group__button { flex: 0 0 auto; padding: 0.5rem 1rem; border: 1px solid #ccc; border-left: none; }
```

---

## Wrapping Patterns

### Tag/Chip List

```css
.tag-list { display: flex; flex-wrap: wrap; gap: 0.5rem; }
.tag {
  flex: 0 0 auto;
  padding: 0.25rem 0.75rem;
  border-radius: 9999px;
  background: #e0e7ff;
  font-size: 0.875rem;
}
```

### Responsive Wrap with Minimum Width

```css
.feature-list { display: flex; flex-wrap: wrap; gap: 1.5rem; }
.feature-item { flex: 1 1 300px; max-width: 100%; }
```

---

## Order and Visual Reordering

```css
.item--first { order: -1; }
.item--last  { order: 99; }
```

**Accessibility warning:** `order` does not change tab order or screen reader order. Keep source order logical.

---

## Edge Cases and Common Mistakes

- **`min-width: 0`** -- Flex items default to `min-width: auto`, preventing shrinking below content size. Add `min-width: 0` or `overflow: hidden` to allow shrinking.
- **`flex: 1` shorthand** -- Expands to `flex: 1 1 0%`, not `flex: 1 1 auto`. Items ignore content size.
- **Margin auto** -- `margin: auto` absorbs extra space. Useful for pushing items apart (e.g., `margin-left: auto`).
- **Gap vs margin** -- Use `gap` for consistent spacing. Margin creates unwanted space on first/last children.
- **`flex-grow` with different bases** -- Items with `flex-grow: 1` but different `flex-basis` will NOT be equal width. Use `flex: 1 1 0%`.
- **Column direction height** -- `flex-direction: column` needs explicit height for `justify-content` and `flex-grow` to work visibly.
- **Nested containers** -- Parent flex properties do not cascade to nested flex containers.
