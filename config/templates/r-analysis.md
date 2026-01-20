# R Data Analysis Project

## Project Type
Data analysis project in R for exploratory analysis, statistical modeling, or report generation.

## Project-Specific Standards

### Project Structure
- R/ (analysis scripts, custom functions)
- data/
  - raw/ (original, immutable data)
  - processed/ (cleaned, transformed)
  - outputs/ (results, figures, tables)
- scripts/ (numbered analysis scripts: 01-import.R, 02-clean.R, 03-analyze.R)
- reports/ (R Markdown or Quarto documents)
- renv.lock (reproducible package environment)

### Core Libraries (Tidyverse-focused)
- tidyverse (dplyr, ggplot2, tidyr, readr, purrr)
- here for file paths (makes scripts portable)
- janitor for data cleaning
- lubridate for dates
- Consider: data.table for larger datasets (faster than dplyr)

### Reproducibility
- renv for package management (renv::init())
- Set random seed for any stochastic analyses
- Document R version in README
- Use here::here() for all file paths (never setwd())
- Include sessionInfo() or devtools::session_info() in reports

### Testing Strategy
- testthat for custom analysis functions
- Unit tests: Data cleaning functions, statistical calculations
- Validation tests: Expected column names, value ranges, data types
- Use checkmate for data validation and assertions
- Test with subset of real data or synthetic data

### Code Quality
- air for consistent code formatting
- lintr for linting
- r-lib type checking where applicable
- checkmate for function input validation
- DRY principle: Move repeated code into R/ functions

### Script Organization
- Numbered scripts for analysis workflow:
  - 01-import.R: Load raw data
  - 02-clean.R: Clean and transform
  - 03-explore.R: EDA and visualization
  - 04-model.R: Statistical modeling
  - 05-report.R: Generate outputs
- Each script should be runnable independently (using processed data)
- Use source("R/functions.R") to load custom functions

### Data Management
- Keep raw data immutable (never overwrite)
- Document data sources in documentation/data-sources.md
- Use readr or data.table::fread() for CSV imports
- Save intermediate data as RDS files (saveRDS/readRDS) - preserves types
- Consider: pins package for versioned data storage

### Reporting
- Use R Markdown or Quarto for reports
- Separate code (in scripts/) from narrative (in reports/)
- Reports should source data from data/processed/ not regenerate from raw
- Parameterized reports for multiple similar analyses
- Export key figures as high-res PNG or PDF for reuse

### Visualization Standards
- ggplot2 for all visualizations
- Consistent theme across all plots (create custom theme in R/theme.R)
- Color-blind friendly palettes (viridis, RColorBrewer)
- Save publication-ready figures (300 DPI minimum)
- Include alt text for accessibility

### Quality Gates (Before Next Feature)
- [ ] Analysis produces expected outputs
- [ ] Tests passing for custom functions
- [ ] Scripts run end-to-end without errors
- [ ] Key findings documented in report or results.md
- [ ] styler formatting applied
- [ ] lintr passes
- [ ] Figures publication-ready
- [ ] Data validation checks passing

### Documentation Requirements
- README.md: Analysis purpose, data sources, how to reproduce
- documentation/
  - methodology.md: Statistical methods, assumptions, analysis approach
  - data-sources.md: Where data came from, update procedures
  - results.md: Key findings, or link to rendered report
  - development.md: How to run analysis, environment setup

### Statistical Analysis Best Practices
- Check model assumptions (residual plots, diagnostic tests)
- Report confidence intervals, not just p-values
- Consider effect sizes and practical significance
- Use tidymodels for machine learning workflows
- Document any data exclusions or transformations

### Cost Considerations
- Local execution (no cloud costs)
- If data is large: Use data.table or DuckDB before cloud solutions
- Free storage: Google Drive, Dropbox
- Quarto Pub or GitHub Pages for free report hosting