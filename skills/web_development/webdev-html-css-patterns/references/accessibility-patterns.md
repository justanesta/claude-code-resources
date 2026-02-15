# Accessibility Patterns Reference

Guide to web accessibility including ARIA roles/properties, keyboard navigation, focus management, screen readers, and color contrast.

---

## ARIA Landmark Roles

```html
<header role="banner">          <!-- Site header (implicit on <header> if not nested) -->
<nav role="navigation">         <!-- Navigation region (implicit on <nav>) -->
<main role="main">              <!-- Primary content (implicit on <main>) -->
<aside role="complementary">    <!-- Supporting content (implicit on <aside>) -->
<footer role="contentinfo">     <!-- Site footer (implicit on <footer> if not nested) -->
<form role="search">            <!-- Search form -->
<section role="region" aria-labelledby="section-heading">  <!-- Generic named region -->
```

Use semantic HTML elements first. Only add explicit `role` when the implicit role needs reinforcement or when using non-semantic elements.

---

## ARIA Properties and States

### Labeling

```html
<!-- aria-label: text label when no visible label exists -->
<button aria-label="Close dialog">
  <svg aria-hidden="true"><!-- X icon --></svg>
</button>

<!-- aria-labelledby: references visible text as the label -->
<section aria-labelledby="pricing-heading">
  <h2 id="pricing-heading">Pricing Plans</h2>
</section>

<!-- aria-describedby: references text that describes the element -->
<input type="password" aria-describedby="password-requirements">
<p id="password-requirements">Must be at least 8 characters with one number.</p>
```

### Live Regions

```html
<div aria-live="polite" aria-atomic="true">3 items in your cart</div>
<div role="alert" aria-live="assertive">Error: payment failed.</div>
<div role="status" aria-live="polite">File upload: 75% complete</div>
```

### States

```html
<button aria-expanded="false" aria-controls="menu-dropdown">Menu</button>
<ul id="menu-dropdown" hidden>
  <li><a href="/settings">Settings</a></li>
</ul>

<li role="tab" aria-selected="true">Active Tab</li>
<button aria-disabled="true">Submit (disabled)</button>
<a href="/dashboard" aria-current="page">Dashboard</a>

<input type="email" aria-invalid="true" aria-errormessage="email-error">
<span id="email-error" role="alert">Please enter a valid email address.</span>
```

---

## Keyboard Navigation

### Focus Order and Tab Index

```html
<!-- Natural tab order (follow DOM order) -->
<button>First</button>
<a href="/link">Second</a>
<input type="text" placeholder="Third">

<!-- tabindex="0": adds element to natural tab order -->
<div role="button" tabindex="0">Custom button</div>

<!-- tabindex="-1": focusable via JavaScript but not in tab order -->
<div id="modal-content" tabindex="-1"></div>

<!-- NEVER use tabindex > 0: it disrupts natural order -->
```

### Keyboard Interaction -- Tabs Pattern

```html
<div role="tablist" aria-label="Account settings">
  <button role="tab" id="tab-1" aria-selected="true" aria-controls="panel-1" tabindex="0">General</button>
  <button role="tab" id="tab-2" aria-selected="false" aria-controls="panel-2" tabindex="-1">Security</button>
</div>
<div role="tabpanel" id="panel-1" aria-labelledby="tab-1" tabindex="0">General settings...</div>
<div role="tabpanel" id="panel-2" aria-labelledby="tab-2" tabindex="0" hidden>Security settings...</div>
```

### Skip Navigation

```html
<a href="#main-content" class="skip-link">Skip to main content</a>
```

```css
.skip-link {
  position: absolute;
  top: -100%;
  left: 0;
  z-index: 9999;
  padding: 0.75rem 1.5rem;
  background: #000;
  color: #fff;
}
.skip-link:focus { top: 0; }
```

---

## Focus Management

### Focus Trapping in Modals

```html
<dialog id="modal" aria-labelledby="modal-title" aria-modal="true">
  <h2 id="modal-title">Edit Profile</h2>
  <form method="dialog">
    <label for="display-name">Display Name</label>
    <input type="text" id="display-name" autofocus>
    <button type="submit" value="save">Save</button>
    <button type="submit" value="cancel">Cancel</button>
  </form>
</dialog>
```

Native `<dialog>` with `showModal()` automatically traps focus.

### Focus Indicators

```css
:focus-visible {
  outline: 3px solid #2563eb;
  outline-offset: 2px;
}
:focus:not(:focus-visible) {
  outline: none;
}
```

### Focus Restoration

When a modal closes, return focus to the element that opened it:

```html
<button id="open-modal" aria-haspopup="dialog">Edit Profile</button>
<script>
  const trigger = document.getElementById('open-modal');
  const dialog = document.getElementById('modal');
  trigger.addEventListener('click', () => dialog.showModal());
  dialog.addEventListener('close', () => trigger.focus());
</script>
```

---

## Screen Reader Patterns

### Visually Hidden Content

```css
.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}
```

### Hiding Decorative Content

```html
<svg aria-hidden="true" focusable="false"><!-- decorative icon --></svg>
<img src="divider.png" alt="" role="presentation">
<button>
  <svg aria-hidden="true"><!-- icon --></svg>
  <span class="sr-only">Delete item</span>
</button>
```

### Announcing Dynamic Changes

```html
<div role="status" aria-live="polite" class="sr-only">
  <!-- JS updates: "Showing 15 results for 'CSS Grid'" -->
</div>
<div role="alert" aria-live="assertive">
  <!-- JS updates when errors occur -->
</div>
```

---

## Color and Contrast

### WCAG Contrast Requirements

| Level | Normal Text | Large Text (18pt+/14pt+ bold) | UI Components |
|---|---|---|---|
| AA | 4.5:1 | 3:1 | 3:1 |
| AAA | 7:1 | 4.5:1 | 4.5:1 |

### Sufficient Contrast Examples

```css
.text-primary   { color: #1a1a1a; }  /* on white: 16.6:1 */
.text-secondary { color: #525252; }  /* on white: 7.4:1 (AAA) */
.text-muted     { color: #737373; }  /* on white: 4.6:1 (AA) */
```

Never rely on color alone. Pair color with icons, text, or underlines:

```html
<!-- Bad: color is the only indicator -->
<span style="color: red;">Required</span>

<!-- Good: color plus text and icon -->
<span class="required-field">
  <svg aria-hidden="true" class="icon-warning"><!-- icon --></svg>
  Required field
</span>
```

---

## Accessible Components

### Accordion

```html
<h3>
  <button aria-expanded="false" aria-controls="section1-content" id="section1-header">
    What is your return policy?
  </button>
</h3>
<div id="section1-content" role="region" aria-labelledby="section1-header" hidden>
  <p>We accept returns within 30 days of purchase.</p>
</div>
```

### Breadcrumb

```html
<nav aria-label="Breadcrumb">
  <ol>
    <li><a href="/">Home</a></li>
    <li><a href="/products">Products</a></li>
    <li><a href="/products/phones" aria-current="page">Phones</a></li>
  </ol>
</nav>
```

---

## Testing Checklist

- **Keyboard** -- Tab, Shift+Tab, Enter, Space, Escape, arrows. All interactive elements reachable.
- **Screen reader** -- VoiceOver (macOS/iOS), NVDA/JAWS (Windows), TalkBack (Android).
- **Zoom** -- Usable at 200% zoom, up to 400% for WCAG 2.2 AA.
- **Contrast** -- All text and UI components meet AA ratios (axe DevTools, Lighthouse).
- **Reduced motion** -- Animations respect `prefers-reduced-motion: reduce`.
- **Heading structure** -- Logical hierarchy, no skipped levels.
- **Alt text** -- Informative images have descriptions; decorative images use `alt=""`.
