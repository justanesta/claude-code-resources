# Python Data Analysis Project

## Project Type
Data analysis project in Python for exploratory analysis, reporting, or blog post development.

## Project-Specific Standards

### Framework & Structure
- Jupyter notebooks for exploration (notebooks/ folder)
- Python scripts for production analysis (src/analysis/)
- Data pipeline: raw → processed → analysis → outputs
- Config files (YAML or TOML) for analysis parameters

### Core Libraries
- pandas for data manipulation
- numpy for numerical operations
- matplotlib/seaborn for visualization
- jupyter for notebooks
- Consider: polars for larger datasets (more performant than pandas)

### Data Management
- data/
  - raw/ (immutable, original data)
  - processed/ (cleaned, transformed)
  - outputs/ (figures, tables, final results)
- Document data sources in documentation/data-sources.md
- Use DVC (Data Version Control) if datasets are large or changing frequently

### Testing Strategy
- pytest for analysis scripts
- Unit tests: Data cleaning functions, transformations, calculations
- Integration tests: End-to-end pipeline runs with sample data
- Validate outputs: Expected column names, value ranges, no nulls where unexpected
- Use checkmate for data validation checks

### Reproducibility
- requirements.txt or pyproject.toml with pinned versions
- Random seeds set for any stochastic processes
- Document Python version in README
- Consider: Include sample data or data generation script for testing

### Code Quality
- Type hints with pyright for core functions
- Pydantic for configuration validation and input data schemas
- ruff for linting
- Keep notebooks clean: refactor repeated code into src/ modules

### Documentation Requirements
- README.md: What analysis answers, data sources, how to run
- documentation/
  - methodology.md: Analysis approach, statistical methods, assumptions
  - data-sources.md: Where data came from, how to access/update
  - results.md: Key findings, figures, tables (or link to notebook outputs)
  - development.md: How to run analysis, regenerate outputs

### Notebook Practices
- One notebook per major analysis step or question
- Clear markdown explanations between code cells
- Import custom functions from src/, don't duplicate code
- Save key outputs (figures, tables) to data/outputs/
- Consider: Use nbconvert to generate HTML reports from notebooks

### Output Standards
- Figures: Publication-ready quality, consistent style
- Tables: Export to CSV or Excel for sharing
- Reports: Markdown or HTML format for sharing findings

### Quality Gates (Before Next Feature)
- [ ] Analysis produces expected outputs
- [ ] Tests passing for all data processing functions
- [ ] Notebooks run end-to-end without errors
- [ ] Key findings documented in results.md or notebook
- [ ] ruff linting passes
- [ ] Type checking passes on core functions
- [ ] Figures/tables ready for presentation or publication

### Cost Considerations
- Local execution preferred (no cloud compute costs)
- If data is too large: Consider DuckDB (fast, local) before cloud solutions
- Cloud storage: Use free tiers (Google Drive, Dropbox) before S3/GCS