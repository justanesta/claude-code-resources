# Claude Code Subagents

Reusable subagent definitions for Claude Code's Task tool. Each `.md` file defines a specialized agent with a focused purpose, minimal tool set, and structured output format.

## How to Use

Reference a subagent by passing its system prompt to the Task tool via `subagent_type` in your `CLAUDE.md` or by copying the prompt into a Task tool call. These are designed for the `sonnet` model to balance capability and speed.

### In CLAUDE.md

```markdown
When analyzing code, use the Task tool with the codebase-analyzer subagent prompt.
When reviewing SQL, use the Task tool with the sql-reviewer subagent prompt.
```

## Subagent Index

### Tier 1: Universal (All Project Types)

| Agent | Purpose | Tools | Modifies Files? |
|-------|---------|-------|-----------------|
| [codebase-analyzer](codebase-analyzer.md) | Understand how code works with file:line references | Read, Grep, Glob, Bash | No |
| [tests-refresher](tests-refresher.md) | Audit test gaps, generate/update tests | Read, Grep, Glob, Bash, Write, Edit | Yes |
| [documentation-updater](documentation-updater.md) | Keep docs in sync with code changes | Read, Grep, Glob, Write, Edit | Yes |
| [refactor-planner](refactor-planner.md) | Analyze code for refactoring with risk-assessed plan | Read, Grep, Glob, Bash | No |

### Tier 2: Data-Focused (Data Engineering + Data Science)

| Agent | Purpose | Tools | Modifies Files? |
|-------|---------|-------|-----------------|
| [sql-reviewer](sql-reviewer.md) | Review SQL/dbt for correctness and performance | Read, Grep, Glob | No |
| [pipeline-debugger](pipeline-debugger.md) | Diagnose data pipeline and ETL failures | Read, Grep, Glob, Bash | No |

### Tier 3: Web-Focused (React, TypeScript, APIs)

| Agent | Purpose | Tools | Modifies Files? |
|-------|---------|-------|-----------------|
| [component-scaffolder](component-scaffolder.md) | Generate React/TS components + tests matching conventions | Read, Grep, Glob, Write | Yes |
| [api-spec-generator](api-spec-generator.md) | Generate/update OpenAPI specs from route handlers | Read, Grep, Glob, Write | Yes |

## Recommended Combinations

### Data Pipeline Development
1. `codebase-analyzer` — understand existing pipeline structure
2. `sql-reviewer` — review SQL transformations
3. `tests-refresher` — add missing pipeline tests
4. `documentation-updater` — update pipeline docs

### Web Application Feature
1. `codebase-analyzer` — understand the feature area
2. `component-scaffolder` — generate React components
3. `api-spec-generator` — update API docs
4. `tests-refresher` — fill test coverage gaps

### Code Quality Review
1. `codebase-analyzer` — understand current architecture
2. `refactor-planner` — identify improvements with risk assessment
3. `tests-refresher` — ensure test coverage before refactoring
4. `documentation-updater` — update docs after changes

### Pipeline Incident Response
1. `pipeline-debugger` — diagnose the failure
2. `codebase-analyzer` — understand the affected code area
3. `sql-reviewer` — review SQL fixes before applying
4. `tests-refresher` — add regression tests

## Design Principles

- **Minimal tool sets** — read-only agents have no Write/Edit tools
- **Structured output** — every agent has a detailed output template for consistent results
- **Positive framing** — clear scope statements instead of redundant "DO NOT" lists
- **Convention detection** — agents that modify files first learn the project's existing patterns
- **Numbered processes** — explicit step-by-step workflows for autonomous execution
