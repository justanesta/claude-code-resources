# Claude Project Templates

Project-specific `CLAUDE.md` templates for different development workflows.

## Using Templates

From your project directory, run:
```bash
init-claude-project <template-name>
```

This creates `CLAUDE.md` and `CLAUDE.local.md` in your current directory.

## Available Templates

### Python

**python-django-web** - Django web applications
- Django-specific patterns, DRF for APIs, pytest-django
- PostgreSQL production, SQLite dev

**python-analysis** - Data analysis projects
- Jupyter notebooks, pandas/numpy, reproducible pipelines
- Testing data transformations

**python-etl** - ETL data pipelines
- Extract/Transform/Load architecture, Pydantic validation
- Error handling, idempotent operations

### R

**r-package** - R package development
- Standard package structure, roxygen2 docs, testthat
- CRAN-ready practices

**r-analysis** - Data analysis in R
- Tidyverse-focused, numbered scripts, renv
- R Markdown/Quarto reports

**r-dataviz** - Data visualization projects
- ggplot2, publication-ready outputs, accessibility
- Iterative design workflow

**r-shiny-app** - Shiny web applications
- Modular architecture, reactivity best practices
- Performance optimization, deployment

### Web & Other

**typescript-react** - React + TypeScript apps
- Vite, TanStack Query, Zod validation, Tailwind
- Component testing with Vitest

**static-site** - Static websites and blogs
- Astro/Hugo/Eleventy, Markdown content
- SEO optimization, free hosting

**database-project** - Database work
- Schema design, migrations, query optimization
- PostgreSQL/MySQL/SQLite

## Template Structure

Each template includes:
- **Project Type** - Brief description
- **Key Standards** - Framework-specific conventions
- **Testing Strategy** - What and how to test
- **Documentation** - Required docs in `documentation/` folder
- **Project-Specific Practices** - Domain-specific patterns

## Customizing Templates

Templates are intentionally lean (150-300 words) to avoid bloating context windows. Edit templates to match your workflow, but keep them concise.

### What to Include
- Project-specific tooling and structure
- Testing approach for this project type
- Framework-specific best practices
- Documentation requirements

### What to Exclude
- General programming knowledge
- Language basics
- Universal standards (those belong in global config)
- Long explanations

## Tips

1. **Start with a template** - Always initialize projects with a template rather than blank `CLAUDE.md`

2. **Customize per project** - Edit `CLAUDE.md` after initialization to add project-specific context

3. **Use CLAUDE.local.md** - For temporary notes and experiments that shouldn't be in version control

4. **Keep it lean** - More context = higher token costs. Only include what Claude needs for *this* project.

5. **Iterate** - Refine templates based on what works. This is a living system.

## Creating New Templates

1. Copy an existing template as a starting point
2. Keep structure consistent: Project Type → Standards → Testing → Documentation
3. Aim for 100-200 words
4. Focus on project-specific essentials
5. Save as `<descriptive-name>.md` in this directory
6. Template name becomes the command: `init-claude-project <descriptive-name>`