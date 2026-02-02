# Static Site / Blog

## Project Type
Static website or blog with static site generator.

## Generator (Pick One)
- **Astro** (recommended: fast, modern, MD support)
- **Hugo** (fastest builds, large sites)
- **Eleventy** (simple, flexible)

## Structure (Astro)
- src/pages/, src/layouts/, src/components/, src/content/
- public/ for static assets

## Content
- Markdown/MDX for all content
- Front matter: title, date, description, tags
- Images optimized (automatic in Astro)

## SEO Essentials
- Meta tags: title, description, Open Graph
- Sitemap.xml (auto-generated)
- Alt text for all images

## Styling
- Tailwind CSS (recommended)
- Responsive, mobile-first
- Dark mode support

## Performance Targets
- Lighthouse score: 90+ on all metrics
- Lazy load images
- Minimal JavaScript

## Deployment
- Free: Netlify, Vercel, or Cloudflare Pages
- Auto-deploy on git push

## Documentation (in documentation/)
- content-guide.md: How to write posts, front matter schema