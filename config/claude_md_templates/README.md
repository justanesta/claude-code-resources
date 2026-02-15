# Claude Project Templates

Project-specific `CLAUDE.md` templates for different development workflows.

## Using Templates

From your project directory, run:
```bash
init-claude-project              # interactive — select type, skills, subagents
init-claude-project python-etl   # skip the type menu
init-claude-project python-etl --defaults  # non-interactive, use recommended set
```

This creates `CLAUDE.md`, `CLAUDE.local.md`, and copies selected skills/subagents into `.claude/`.

## Template Frontmatter

Each template begins with YAML frontmatter that the installer reads and strips:

```yaml
---
name: template-name
description: One-line description shown in the selection menu
skills:
  - skill-directory-name
  - another-skill
subagents:
  - subagent-name
  - another-subagent
---
```

- **name**: Template identifier (matches the filename without `.md`)
- **description**: Shown next to the template name during interactive selection
- **skills**: Pre-selected in the skills checkbox menu (user can toggle on/off)
- **subagents**: Pre-selected in the subagents checkbox menu (user can toggle on/off)

The frontmatter is stripped when the template is copied to `CLAUDE.md` — users never see it.

## Available Templates

### Python

**python-django-app** - Django web applications
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

**typescript-react-app** - React + TypeScript apps
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
2. Add YAML frontmatter with `name`, `description`, `skills`, and `subagents`
3. Keep structure consistent: Project Type → Standards → Testing → Documentation
4. Aim for 100-200 words
5. Focus on project-specific essentials
6. Save as `<descriptive-name>.md` in this directory
7. The installer auto-discovers templates — no registration needed