# Claude Code Skills

Reusable skill definitions for Claude Code. Each skill is a directory containing a `SKILL.md` prompt and a `references/` folder of detailed examples and patterns that Claude loads on demand.

## How to Use

Skills are installed into a project's `.claude/skills/` directory by the `init-claude-project` script. Each project template pre-selects relevant skills, but you can toggle them during interactive setup.

### In CLAUDE.md

```markdown
When writing Python, follow the patterns in .claude/skills/modern-python-patterns/.
When writing SQL, reference .claude/skills/sql-query-fundamentals/.
```

## Skill Structure

```
skill-name/
  SKILL.md              # Core prompt — principles, patterns, anti-patterns
  references/
    topic-one.md        # Detailed examples for a specific subtopic
    topic-two.md        # Each reference is loaded only when relevant
```

- **SKILL.md** defines the skill's scope, key principles, and when to consult references
- **references/** contain detailed code examples, patterns, and explanations that Claude pulls in as needed to avoid bloating context

## Skill Index

### Python (11 skills)

| Skill | Purpose | Refs |
|-------|---------|------|
| [modern-python-patterns](python/modern-python-patterns/) | Python 3.10+ patterns: type hints, dataclasses, modern idioms | 7 |
| [python-api-development](python/python-api-development/) | API development with FastAPI and Flask (REST, auth, validation) | 5 |
| [python-async-patterns](python/python-async-patterns/) | Asyncio patterns, concurrent I/O, sync-to-async migration | 4 |
| [python-data-pipelines](python/python-data-pipelines/) | Pipeline orchestration with Prefect and Airflow (ETL/ELT) | 4 |
| [python-data-wrangling](python/python-data-wrangling/) | Data wrangling with pandas and polars | 5 |
| [python-devops-automation](python/python-devops-automation/) | DevOps automation: boto3, CLIs (click/typer), subprocesses | 6 |
| [python-error-handling](python/python-error-handling/) | Error handling, exception hierarchies, debugging, logging | 5 |
| [python-package-development](python/python-package-development/) | Package development: pyproject.toml, src layout, versioning, PyPI | 6 |
| [python-performance](python/python-performance/) | Performance profiling and optimization | 6 |
| [python-testing](python/python-testing/) | Testing with pytest: fixtures, parametrization, test infrastructure | 4 |

### R (6 skills)

| Skill | Purpose | Refs |
|-------|---------|------|
| [writing-tidyverse-r](R/writing-tidyverse-r/) | Modern tidyverse patterns, style guide, migration guidance | 8 |
| [metaprogramming-rlang](R/metaprogramming-rlang/) | Tidy evaluation, programmatic tidyverse with rlang | 12 |
| [developing-packages-r](R/developing-packages-r/) | R package development with modern tidyverse patterns | 6 |
| [designing-oop-r](R/designing-oop-r/) | OOP in R: S7, S3, S4, and vctrs class design | 5 |
| [customizing-vectors-r](R/customizing-vectors-r/) | Custom vector classes with vctrs for type-stable operations | 5 |
| [optimizing-r](R/optimizing-r/) | R performance profiling, benchmarking, parallel processing | 6 |

### SQL (7 skills)

| Skill | Purpose | Refs |
|-------|---------|------|
| [sql-query-fundamentals](SQL/sql-query-fundamentals/) | Core SQL: SELECT, JOINs, WHERE, GROUP BY, subqueries | 7 |
| [sql-transformations](SQL/sql-transformations/) | ETL patterns, data cleaning, type conversions, string/date manipulation | 6 |
| [sql-data-modeling](SQL/sql-data-modeling/) | Schema design, normalization, constraints, indexing, warehouse modeling | 7 |
| [sql-query-optimization](SQL/sql-query-optimization/) | Query tuning, EXPLAIN plans, indexing strategies | 7 |
| [sql-analytics-patterns](SQL/sql-analytics-patterns/) | Window functions, analytical queries, advanced aggregations | 7 |
| [sql-advanced-features](SQL/sql-advanced-features/) | Views, stored procedures, functions, triggers, transactions | 7 |
| [sql-integration-patterns](SQL/sql-integration-patterns/) | Database connections from Python, R, dbt (ORMs, parameterized queries) | 6 |

### Web Development (5 skills)

| Skill | Purpose | Refs |
|-------|---------|------|
| [webdev-html-css-patterns](web_development/webdev-html-css-patterns/) | HTML5/CSS3: semantic markup, layout, responsive design, accessibility | 5 |
| [webdev-javascript-fundamentals](web_development/webdev-javascript-fundamentals/) | Modern JavaScript ES2024+: async/await, array methods, modules, fetch | 6 |
| [webdev-typescript-patterns](web_development/webdev-typescript-patterns/) | TypeScript 5.x type system patterns for production web development | 6 |
| [webdev-react-patterns](web_development/webdev-react-patterns/) | React 18+ with TypeScript: hooks, state management, composition | 6 |
| [webdev-api-design](web_development/webdev-api-design/) | REST API design: conventions, error handling, pagination, versioning | 5 |

### Data Engineering (5 skills)

| Skill | Purpose | Refs |
|-------|---------|------|
| [data-eng-cloud-infrastructure](data_engineering/data-eng-cloud-infrastructure/) | Cloud data infrastructure on AWS/GCP, IaC, data lake architectures | 6 |
| [data-eng-data-quality](data_engineering/data-eng-data-quality/) | Data quality validation, observability, and monitoring | 6 |
| [data-eng-streaming-patterns](data_engineering/data-eng-streaming-patterns/) | Streaming data patterns, event-driven architectures, real-time processing | 6 |
| [data-eng-testing-patterns](data_engineering/data-eng-testing-patterns/) | Testing patterns for data pipelines, SQL transforms, dbt models | 5 |
| [data-eng-warehouse-patterns](data_engineering/data-eng-warehouse-patterns/) | Cloud data warehouses, lakehouse, Data Vault 2.0, ELT patterns | 6 |

### DevOps (4 skills)

| Skill | Purpose | Refs |
|-------|---------|------|
| [devops-cicd-patterns](devops/devops-cicd-patterns/) | CI/CD pipelines across GitHub Actions, GitLab CI, general design | 5 |
| [devops-docker-patterns](devops/devops-docker-patterns/) | Docker containerization, Compose, image optimization, security | 5 |
| [devops-monitoring-observability](devops/devops-monitoring-observability/) | Monitoring, observability, alerting (Prometheus, OpenTelemetry) | 5 |
| [devops-terraform-patterns](devops/devops-terraform-patterns/) | Terraform IaC: module design, state management, CI/CD integration | 5 |

### Git (2 skills)

| Skill | Purpose | Refs |
|-------|---------|------|
| [git-workflow-patterns](git/git-workflow-patterns/) | Branching strategies, commit messages, pull requests, conflict resolution | 5 |
| [git-advanced-operations](git/git-advanced-operations/) | Interactive rebases, recovering commits, hooks, worktrees | 5 |

## Recommended Combinations by Template

| Template | Skills |
|----------|--------|
| **python-django-app** | modern-python-patterns, python-api-development, python-testing, python-error-handling |
| **python-analysis** | modern-python-patterns, python-data-wrangling, python-testing, python-performance |
| **python-etl** | modern-python-patterns, python-data-pipelines, python-data-wrangling, python-testing |
| **typescript-react-app** | webdev-javascript-fundamentals, webdev-typescript-patterns, webdev-react-patterns |
| **static-site** | webdev-html-css-patterns, webdev-javascript-fundamentals |
| **database-project** | sql-query-fundamentals, sql-data-modeling, sql-query-optimization, sql-advanced-features |
| **r-package** | writing-tidyverse-r, developing-packages-r, metaprogramming-rlang, designing-oop-r |
| **r-analysis** | writing-tidyverse-r, metaprogramming-rlang, optimizing-r |
| **r-dataviz** | writing-tidyverse-r, metaprogramming-rlang |
| **r-shiny-app** | writing-tidyverse-r, metaprogramming-rlang |

## Design Principles

- **Two-layer architecture** — `SKILL.md` stays in context; `references/` are loaded on demand
- **Example-driven** — references emphasize runnable code over prose
- **Anti-pattern aware** — each skill documents what to avoid alongside what to do
- **Framework-specific** — skills target specific tools (e.g., polars vs pandas) rather than generic concepts
- **Convention detection** — skills teach Claude to match the project's existing style

## Creating New Skills

1. Create a directory under the appropriate category: `skills/<category>/<skill-name>/`
2. Write `SKILL.md` with scope, key principles, and a list of references
3. Add reference files in `references/` with detailed examples
4. Aim for 4-7 reference files per skill
5. Add the skill name to relevant template frontmatter in `config/claude_md_templates/`
6. The installer auto-discovers skills — no registration needed
