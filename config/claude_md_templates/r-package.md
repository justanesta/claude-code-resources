# R Package Development

## Project Type
R package for distributing reusable R functions, suitable for CRAN submission or internal use.

## Project-Specific Standards

### Package Structure
- Standard R package structure (usethis::create_package())
- R/ (function definitions)
- tests/testthat/ (test files)
- man/ (auto-generated documentation via roxygen2)
- vignettes/ (long-form documentation)
- data/ (package datasets, if applicable)
- data-raw/ (scripts to create package data)

### Core Development Tools
- usethis for package development workflow
- devtools for building, checking, installing
- roxygen2 for documentation
- testthat for testing
- pkgdown for package website (optional but recommended)

### Testing Strategy
- testthat for all tests
- Coverage target: 80% minimum (covr package)
- Test categories:
  - Unit: Individual functions with various inputs
  - Integration: Functions that call other package functions
  - Edge cases: NULL, NA, empty vectors, wrong types
- Use expect_error(), expect_warning() for expected failures
- Test examples in documentation (they run during R CMD check)

### Code Quality
- air for consistent code formatting
- lintr for linting
- r-lib type checking where applicable
- checkmate for input validation in functions

### Documentation Requirements
- README.md: Package purpose, installation, basic usage examples
- Roxygen2 documentation for ALL exported functions:
  - @param descriptions for every parameter
  - @return description of output
  - @examples with runnable code
  - @export tag for user-facing functions
- Vignettes (articles/) for:
  - Getting started guide
  - Advanced usage patterns
  - Specific use cases or workflows
- NEWS.md: Track changes between versions

### Function Design Practices
- Use checkmate::assert_* for input validation at function start
- Return informative error messages (not just "invalid input")
- Follow tidyverse design principles if building on tidyverse
- Avoid modifying global state (use functional programming)
- Consider S3 methods for generic functions (print, summary, plot)

### Dependencies
- Minimize dependencies (each one is a potential maintenance burden)
- DESCRIPTION file:
  - Imports: Packages your package needs
  - Suggests: Packages for tests, vignettes, or optional features
  - Use specific version requirements only when necessary
- Never use library() or require() in package code (use :: or import in NAMESPACE)

### Package Checks
- R CMD check must pass with no errors, warnings, or notes
- Run devtools::check() frequently during development
- Test on multiple R versions if targeting CRAN
- Use rhub or GitHub Actions for multi-platform testing

### Version Control & Releases
- Semantic versioning (major.minor.patch)
- Tag releases in git
- Update NEWS.md for each release
- Use usethis::use_version() to bump version

### Quality Gates (Before Next Feature)
- [ ] New functions work as specified
- [ ] testthat tests written and passing
- [ ] roxygen2 documentation complete
- [ ] devtools::check() passes (0 errors, 0 warnings, 0 notes)
- [ ] styler formatting applied
- [ ] lintr passes (or exceptions documented)
- [ ] Examples in documentation run successfully
- [ ] NEWS.md updated

### Documentation Structure
- README.md: One paragraph package description, installation, quick example
- documentation/ (supplementary docs, not in package itself):
  - architecture.md: Package design decisions, module organization
  - development.md: How to contribute, run tests, build vignettes
  - release-process.md: Steps for releasing new versions

### Cost Considerations
- Free: GitHub for hosting, GitHub Actions for CI/CD
- Free: pkgdown site hosted on GitHub Pages
- CRAN submission is free