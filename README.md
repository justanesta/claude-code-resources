# Claude Code Resources

Personal collection of Claude Code configurations, templates, agents, and skills for streamlined development workflows.

## Contents

- **config/global/** - Global `CLAUDE.md` configuration loaded in every Claude Code session
- **[config/claude_md_templates/](claude_md_template/README.md)** - Project-specific `CLAUDE.md` templates for different project types
- **[subagents/](subagents/README.md)** - Custom Claude subagents for code analysis, testing, docs, SQL review, and more
- **[skills/](skills/README.md)** - Custom Claude skills organized by language/domain
- **bin/** - Utility script for project initialization

## Quick Start

### Setup

1. Clone this repository:
```bash
   git clone https://github.com/yourusername/claude-code-resources.git ~/code/claude-code-resources
```

2. Add the bin directory to your PATH (add to `~/.bashrc` or `~/.zshrc`):
```bash
   export PATH="$HOME/code/claude-code-resources/bin:$PATH"
```

3. Reload your shell:
```bash
   source ~/.bashrc  # or source ~/.zshrc
```

### Initialize a New Project

Navigate to your project directory and run:
```bash
init-claude-project                        # interactive — pick type, skills, subagents
init-claude-project python-etl             # skip the type menu
init-claude-project python-etl --defaults  # non-interactive, install recommended set
```

The installer will:
1. Let you select a project type (or pass it as an argument)
2. Show a checkbox menu of all available skills, with template recommendations pre-selected
3. Show a checkbox menu of all available subagents, with template recommendations pre-selected
4. Confirm and install `CLAUDE.md`, `CLAUDE.local.md`, `.claude/skills/`, and `.claude/agents/`

## Recommended Skill Combinations by Project Type

### Python Projects

**Data Analysis Project**
- `modern-python-patterns` (foundation)
- `python-data-wrangling` (pandas/polars)
- `python-testing` (quality assurance)
- Optional: `python-performance` (large datasets)

**Web API Project**
- `modern-python-patterns` (foundation)
- `python-api-development` (FastAPI/Flask)
- `python-async-patterns` (async endpoints)
- `python-testing` (API testing)
- Optional: `python-error-handling` (production errors)

**Data Pipeline Project**
- `modern-python-patterns` (foundation)
- `python-data-pipelines` (Prefect/Airflow)
- `python-data-wrangling` (transformations)
- `python-testing` (pipeline testing)

**DevOps/Infrastructure Project**
- `modern-python-patterns` (foundation)
- `python-devops-automation` (CLI, boto3, Docker)
- `python-error-handling` (robust automation)
- `python-testing` (infrastructure tests)

**Package Development**
- `modern-python-patterns` (foundation)
- `python-package-development` (pyproject.toml, publishing)
- `python-testing` (comprehensive tests)
- Optional: `python-performance` (performance-critical)

**ML/Data Science Project**
- `modern-python-patterns` (foundation)
- `python-data-wrangling` (data prep)
- `python-performance` (optimization)
- `python-testing` (model testing)

### R Projects

**Data Analysis Project**
- `writing-tidyverse-r` (foundation)
- `metaprogramming-rlang` (functions with tidy evaluation)
- Optional: `optimizing-r` (performance issues)

**Package Development Project**
- `writing-tidyverse-r` (modern patterns)
- `developing-packages-r` (package structure, testing)
- `metaprogramming-rlang` (tidy eval APIs)
- Optional: `designing-oop-r` (S7/S3 classes)

**Statistical Analysis with Custom Types**
- `writing-tidyverse-r` (foundation)
- `customizing-vectors-r` (vctrs for type-stable operations)
- `designing-oop-r` (S7 classes)

**Performance-Critical Analysis**
- `writing-tidyverse-r` (foundation)
- `optimizing-r` (profiling and optimization)
- Optional: `metaprogramming-rlang` (if building functions)

**Production Data Pipeline**
- `writing-tidyverse-r` (data manipulation)
- `developing-packages-r` (robust code)
- `optimizing-r` (performance)

### SQL Projects

**Analytics/BI Project**
- `sql-query-fundamentals` (foundation)
- `sql-analytics-patterns` (window functions, pivots)
- Optional: `sql-query-optimization` (performance)

**Application Development**
- `sql-query-fundamentals` (foundation)
- `sql-data-modeling` (schema design)
- `sql-integration-patterns` (ORM, connections)

**Data Engineering Project**
- `sql-query-fundamentals` (foundation)
- `sql-transformations` (ETL patterns)
- `sql-integration-patterns` (dbt, Python/R)
- Optional: `sql-query-optimization` (large datasets)

**Data Warehouse Project**
- `sql-query-fundamentals` (foundation)
- `sql-analytics-patterns` (complex queries)
- `sql-data-modeling` (star schema, slowly changing dimensions)
- `sql-query-optimization` (performance at scale)

**Database Administration**
- `sql-data-modeling` (schema design)
- `sql-query-optimization` (performance tuning)
- `sql-advanced-features` (stored procedures, triggers)

### Data Engineering Projects

**Batch Pipeline**
- `data-eng-data-quality` (validation frameworks)
- `data-eng-testing-patterns` (pipeline testing)
- `python-data-pipelines` (Prefect/Airflow)
- `sql-transformations` (SQL transforms)

**Data Warehouse**
- `data-eng-warehouse-patterns` (Snowflake/BigQuery/Redshift)
- `sql-data-modeling` (star schema, SCDs)
- `sql-analytics-patterns` (complex queries)
- `data-eng-data-quality` (quality gates)

**Real-Time System**
- `data-eng-streaming-patterns` (Kafka, CDC)
- `data-eng-data-quality` (stream validation)
- `data-eng-cloud-infrastructure` (cloud services)

### Web Development Projects

**React Frontend**
- `webdev-javascript-fundamentals` (ES2024+ patterns)
- `webdev-typescript-patterns` (type safety)
- `webdev-react-patterns` (hooks, state, testing)

**Full-Stack Application**
- `webdev-react-patterns` (frontend)
- `python-api-development` (backend API)
- `webdev-api-design` (REST conventions)
- Optional: `webdev-typescript-patterns` (type safety)

**Static Site / Landing Page**
- `webdev-html-css-patterns` (semantic HTML, CSS Grid/Flexbox)
- `webdev-javascript-fundamentals` (interactivity)

### DevOps Projects

**Containerized Application**
- `devops-docker-patterns` (Dockerfile, Compose)
- `devops-cicd-patterns` (CI/CD pipelines)
- `devops-monitoring-observability` (logging, metrics)

**Cloud Infrastructure**
- `devops-terraform-patterns` (IaC)
- `devops-docker-patterns` (containerization)
- `devops-cicd-patterns` (deployment automation)

### Git Workflows

**Team Collaboration**
- `git-workflow-patterns` (branching, PRs, conventions)
- Optional: `git-advanced-operations` (rebase, recovery)

### General Guidelines

- **Start with 3-4 skills**: Balance utility with context window efficiency
- **Core + Domain**: Always include foundational skill + domain-specific skills
- **Testing is universal**: Include testing skills for production code
- **Add specialized skills as needed**: Performance, error handling, etc.
- **Cross-domain combos**: Combine SQL + Python + Data Engineering for end-to-end pipelines
