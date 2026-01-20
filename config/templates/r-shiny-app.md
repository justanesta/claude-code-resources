# R Shiny Application

## Project Type
Interactive web application or dashboard built with R Shiny for data exploration, reporting, or decision support tools.

## Project-Specific Standards

### Project Structure
- R/
  - server_modules.R (server-side logic modules)
  - ui_modules.R (UI component modules)
  - data_processing.R (data prep functions)
  - plotting.R (ggplot2 functions)
  - utils.R (helper functions)
- app.R (main application file) OR ui.R + server.R (for larger apps)
- data/
  - raw/ (original data)
  - processed/ (cleaned, aggregated - load this in app)
- www/ (static assets: CSS, images, JavaScript)
- tests/testthat/ (unit tests for non-reactive functions)
- config.yml (app configuration via config package)

### Core Shiny Libraries
- shiny (core framework)
- shinydashboard or bslib for layout (bslib is newer, more modern)
- shinyjs for JavaScript interactions
- waiter or shinycssloaders for loading indicators
- shinyWidgets for enhanced input controls
- DT for interactive tables
- plotly for interactive plots (or ggplot2 + ggiraph)

### Application Architecture
- Modular approach: Break UI and server into modules
- One module per logical component (e.g., filter panel, results table, plot viewer)
- Keep app.R minimal - it should mostly call modules
- Separate business logic from reactivity (functions in R/, reactivity in server)
- Preprocess data outside of reactive context (on app load, not every render)

### Data Management
- Load processed data on app startup (not raw data)
- For large datasets:
  - Use data.table or dtplyr (faster than dplyr)
  - Consider DuckDB for SQL queries on local data
  - Filter to relevant subset on load
  - Use reactiveFileReader() for auto-updating data
- Cache expensive computations (bindCache() or memoise)
- Never load entire dataset into memory if user only needs subsets

### Reactivity Best Practices
- Use reactive() for intermediate calculations (reusable)
- Use observe() for side effects (printing, writing files)
- Use eventReactive() or observeEvent() to control when reactions fire
- Minimize reactive dependencies (isolate() for non-reactive reads)
- Use req() to handle missing inputs gracefully
- Avoid reactive expressions inside renderPlot/renderTable (compute first, then render)

### UI/UX Design
- Clean, uncluttered layout
- Responsive design (works on mobile, tablet, desktop)
- Loading indicators for long computations
- Input validation with shinyFeedback or validate()
- Informative error messages (not just red text)
- Tooltips for complex controls (shinyBS or bslib)
- Consider: Dark mode option (bslib themes)

### Performance Optimization
- Profile with profvis to identify bottlenecks
- Precompute what you can (on app load, not reactively)
- Use async processing for long tasks (promises + future)
- Debounce rapid inputs (textInput typing, slider dragging)
- Limit plot/table size (pagination, aggregation)
- Use updateSelectInput() for large dropdown options (server-side)

### Testing Strategy
- testthat for non-reactive functions (data processing, plotting)
- shinytest2 for end-to-end app testing (recommended over shinytest)
- Unit tests: Test R/ functions independently
- Integration tests: Test module server functions with testServer()
- Manual testing: Test on different browsers, screen sizes
- Load testing: Use shinyloadtest for performance under concurrent users

### Code Quality
- styler for formatting
- lintr for linting
- checkmate for input validation in functions
- Modular code: Each module in separate file or clearly delineated
- Document modules: Describe inputs, outputs, purpose

### Deployment
- Local: Just run the app (shiny::runApp())
- Free hosting: shinyapps.io free tier (5 apps, 25 active hours/month)
- Self-hosted: Shiny Server (open source, runs on Linux)
- Professional: Posit Connect (paid) or ShinyProxy (Docker-based)
- Docker: Containerize app for consistent deployment (rocker/shiny base image)

### Security Considerations
- Never hardcode credentials (use environment variables or config.yml not in git)
- Sanitize user inputs (especially if using SQL queries)
- Use httr or httr2 with secrets for API calls
- Consider: Authentication with shinymanager or custom auth
- HTTPS for production deployments (especially if handling sensitive data)

### Configuration Management
- Use config package for environment-specific settings
- config.yml with sections: default, development, production
- Example configs: database connections, API keys, app behavior
- Access with config::get() in app

### Logging & Monitoring
- Use logger package for structured logging
- Log: User actions, errors, performance metrics
- Consider: shinylogs for automatic usage tracking
- Monitor memory usage (gc(), pryr::mem_used())
- Set up error alerts (email or Slack on crash)

### Documentation Requirements
- README.md: App purpose, how to run locally, deployment instructions
- documentation/
  - architecture.md: Module structure, data flow, key design decisions
  - user-guide.md: How to use the app, feature descriptions
  - development.md: Local setup, testing, adding new features
  - deployment.md: Deployment process, environment variables, troubleshooting

### Quality Gates (Before Next Feature)
- [ ] Feature works as expected in app
- [ ] No console errors or warnings
- [ ] Tests passing (unit tests + shinytest2 where applicable)
- [ ] Performance acceptable (no long hangs, test with realistic data)
- [ ] UI is responsive and accessible
- [ ] Error handling graceful (no cryptic red error messages)
- [ ] styler formatting applied
- [ ] lintr passes
- [ ] Documentation updated

### Accessibility
- Semantic HTML (use proper tags, not just divs)
- Keyboard navigation support
- Alt text for images and plots
- Color-blind friendly palettes
- Sufficient text contrast (WCAG AA minimum)
- Test with screen reader if possible

### Common Pitfalls to Avoid
- Don't use <<- (global assignment) - breaks reactivity
- Don't put heavy computation in renderPlot/renderTable - compute first in reactive()
- Don't use observe() when you need reactive() (and vice versa)
- Don't forget to use req() for required inputs
- Don't load massive datasets into memory - filter first
- Don't ignore mobile users - test responsive design

### Shiny-Specific Best Practices
- Name reactive values descriptively (data_filtered not rv)
- Use actionButton() + eventReactive() for user-triggered updates
- Bookmarking: Enable bookmarkButton() for shareable app states
- Download handlers: Use downloadButton() + downloadHandler() for exports
- Progress indicators: Use withProgress() for long operations
- Use browser() for debugging reactive contexts

### Cost Considerations
- Development: Free (local R + Shiny)
- Hosting: shinyapps.io free tier (25 hours/month, 5 apps)
- Scaling: Open source Shiny Server (free, but need Linux server)
- Cheapest cloud: AWS/GCP free tier + Shiny Server
- Avoid: Posit Connect (expensive) unless organization is paying