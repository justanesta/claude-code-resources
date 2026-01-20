# Global Development Standards

## Development Philosophy

I follow test-driven development with iterative quality gates. A feature is only "done" when implementation, tests, and documentation are complete. I prioritize cost-conscious tooling and incremental improvement over perfection.

## Quality Gates Checklist

Before moving to next feature:
- [ ] Feature works as specified
- [ ] Unit tests written and passing
- [ ] Integration tests where applicable
- [ ] Documentation updated (inline + markdown)
- [ ] Linting passes
- [ ] Type checking passes (if applicable)

## Toolchain Standards

| Language   | Linting | Type Checking | Testing | Data Validation |
|------------|---------|---------------|---------|-----------------|
| Python     | ruff    | pyright       | pytest  | pydantic        |
| R          | styler  | r-lib types   | testthat| checkmate       |
| TypeScript | ESLint  | TypeScript    | Vitest  | Zod             |

## Documentation Structure

**README.md** (project root - 1-minute read):
- What: One sentence to one paragraph project description
- Why: Problem it solves
- Quick Start: Minimal example to run/use
- Core Features: 3-5 bullet points max

**documentation/** folder (detailed reference):
Contains domain-specific docs as needed (architecture, API reference, development setup, planning docs, etc.). Specific files determined per project.

Goal: README gives value in 1 min, documentation/ provides full understanding in 5 min.

## Standard Project Structure
```
project/
├── README.md
├── src/ or R/ or lib/
├── tests/
├── documentation/
├── data/ (if applicable)
└── [language-specific config files]
```

## Code Documentation Style

- Light inline comments for "why" not "what"
- Detailed function/class docstrings
- Separate markdown documentation for architecture and usage patterns