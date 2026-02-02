# Claude Code Resources

Personal collection of Claude Code configurations, templates, agents, and skills for streamlined development workflows.

## Contents

- **config/global/** - Global `CLAUDE.md` configuration loaded in every Claude Code session
- **config/templates/** - Project-specific `CLAUDE.md` templates for different project types
- **agents/** - Custom Claude subagents (coming soon)
- **skills/** - Custom Claude skills (coming soon)
- **bin/** - Utility scripts for project initialization

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
init-claude-project 
```

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

### General Guidelines

- **Start with 3-4 skills**: Balance utility with context window efficiency
- **Core + Domain**: Always include foundational skill + domain-specific skills
- **Testing is universal**: Include testing skills for production code
- **Add specialized skills as needed**: Performance, error handling, etc.