# Semantic HTML Patterns Reference

Guide to HTML5 semantic elements, forms, tables, metadata, and SEO markup for production applications.

---

## Document Structure and Landmarks

```html
<!DOCTYPE html>
<html lang="en" dir="ltr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Descriptive Page Title | Site Name</title>
</head>
<body>
  <header role="banner">
    <a href="/" aria-label="Home - Site Name">
      <img src="logo.svg" alt="Site Name logo" width="120" height="40">
    </a>
    <nav aria-label="Primary">
      <ul role="list">
        <li><a href="/products">Products</a></li>
        <li><a href="/docs">Documentation</a></li>
      </ul>
    </nav>
  </header>

  <main id="main-content"></main>

  <footer role="contentinfo">
    <nav aria-label="Footer">
      <ul role="list">
        <li><a href="/privacy">Privacy Policy</a></li>
      </ul>
    </nav>
  </footer>
</body>
</html>
```

---

## Content Sectioning

### Article vs Section

- `<article>` -- Self-contained, independently distributable content (blog post, product card).
- `<section>` -- Thematic grouping within a page or article. Always pair with a heading.

```html
<main>
  <article>
    <header>
      <h1>Understanding CSS Grid</h1>
      <p><time datetime="2026-02-10">February 10, 2026</time></p>
    </header>
    <section aria-labelledby="basics">
      <h2 id="basics">Grid Basics</h2>
      <p>CSS Grid provides two-dimensional layout control...</p>
    </section>
    <footer>
      <p>Written by <address><a href="/authors/jane" rel="author">Jane Doe</a></address></p>
    </footer>
  </article>
  <aside aria-label="Related articles">
    <h2>Related Reading</h2>
    <ul>
      <li><a href="/flexbox-guide">Flexbox Guide</a></li>
    </ul>
  </aside>
</main>
```

### Figure and Figcaption

```html
<figure>
  <img src="chart.png" alt="Bar chart showing monthly revenue Jan-Dec 2025" width="800" height="400">
  <figcaption>Figure 1: Monthly revenue trends for fiscal year 2025.</figcaption>
</figure>
```

---

## Form Patterns

### Accessible Form

```html
<form action="/api/register" method="POST" novalidate>
  <fieldset>
    <legend>Create Account</legend>
    <div class="form-group">
      <label for="full-name">Full Name <span aria-hidden="true">*</span></label>
      <input type="text" id="full-name" name="fullName" required
        autocomplete="name" aria-required="true" aria-describedby="name-hint">
      <small id="name-hint">Enter your first and last name.</small>
    </div>
    <div class="form-group">
      <label for="email">Email <span aria-hidden="true">*</span></label>
      <input type="email" id="email" name="email" required
        autocomplete="email" aria-required="true" aria-describedby="email-error" aria-invalid="false">
      <span id="email-error" class="error" role="alert" hidden>Please enter a valid email.</span>
    </div>
    <div class="form-group">
      <label for="password">Password <span aria-hidden="true">*</span></label>
      <input type="password" id="password" name="password" required minlength="8"
        autocomplete="new-password" aria-required="true" aria-describedby="password-reqs">
      <small id="password-reqs">Minimum 8 characters with at least one number.</small>
    </div>
    <fieldset>
      <legend>Notification Preferences</legend>
      <label><input type="checkbox" name="notifications" value="email"> Email updates</label>
      <label><input type="checkbox" name="notifications" value="sms"> SMS alerts</label>
    </fieldset>
    <button type="submit">Create Account</button>
  </fieldset>
</form>
```

### Search Form

```html
<form role="search" action="/search" method="GET">
  <label for="search-input" class="sr-only">Search</label>
  <input type="search" id="search-input" name="q" placeholder="Search articles..." aria-label="Search articles">
  <button type="submit"><span class="sr-only">Submit search</span></button>
</form>
```

---

## Table Patterns

```html
<table>
  <caption>Quarterly Sales Report, 2025</caption>
  <thead>
    <tr>
      <th scope="col">Quarter</th>
      <th scope="col">Revenue</th>
      <th scope="col">Growth</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <th scope="row">Q1</th>
      <td>$1.2M</td>
      <td>+12%</td>
    </tr>
    <tr>
      <th scope="row">Q2</th>
      <td>$1.4M</td>
      <td>+16%</td>
    </tr>
  </tbody>
  <tfoot>
    <tr>
      <th scope="row">Total</th>
      <td>$2.6M</td>
      <td>Average: +14%</td>
    </tr>
  </tfoot>
</table>
```

---

## Meta Tags and SEO

### Essential Head Elements

```html
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="150-160 character page description for search results.">
  <meta name="robots" content="index, follow">
  <link rel="canonical" href="https://example.com/page">

  <!-- Open Graph -->
  <meta property="og:title" content="Page Title">
  <meta property="og:description" content="Description for social cards.">
  <meta property="og:image" content="https://example.com/og-image.jpg">
  <meta property="og:url" content="https://example.com/page">
  <meta property="og:type" content="article">

  <!-- Favicons -->
  <link rel="icon" href="/favicon.ico" sizes="32x32">
  <link rel="icon" href="/icon.svg" type="image/svg+xml">
  <link rel="apple-touch-icon" href="/apple-touch-icon.png">

  <!-- Preload critical assets -->
  <link rel="preload" href="/fonts/main.woff2" as="font" type="font/woff2" crossorigin>
  <title>Page Title | Site Name</title>
</head>
```

### Structured Data (JSON-LD)

```html
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Article",
  "headline": "Understanding CSS Grid",
  "author": { "@type": "Person", "name": "Jane Doe" },
  "datePublished": "2026-02-10",
  "publisher": { "@type": "Organization", "name": "Example Site" }
}
</script>
```

---

## Interactive Disclosure Elements

```html
<details>
  <summary>What is your return policy?</summary>
  <p>We accept returns within 30 days of purchase.</p>
</details>

<dialog id="settings-dialog" aria-labelledby="settings-title">
  <form method="dialog">
    <h2 id="settings-title">Settings</h2>
    <label for="theme-select">Theme</label>
    <select id="theme-select">
      <option value="light">Light</option>
      <option value="dark">Dark</option>
      <option value="auto">System</option>
    </select>
    <button type="submit" value="save">Save</button>
    <button type="submit" value="cancel">Cancel</button>
  </form>
</dialog>
```

---

## Edge Cases and Common Mistakes

- **Multiple `<main>` elements** -- Only one visible `<main>` per page. Others must have `hidden`.
- **Heading hierarchy** -- Never skip levels. `<h3>` must follow `<h2>`, not `<h1>`.
- **Empty links** -- Every `<a>` must have discernible text, either as content or via `aria-label`.
- **Button vs link** -- Links navigate; buttons perform actions. Do not use `<a href="#">` as a button.
- **Language attribute** -- Always set `lang` on `<html>`. Use `lang` on elements for mixed-language content.
- **Image alt text** -- Decorative images use `alt=""`. Informative images need descriptive alt text.
