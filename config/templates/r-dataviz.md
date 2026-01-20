# R Data Visualization Project

## Project Type
Iterative data visualization project for creating publication-quality graphics, dashboards, or interactive visualizations.

## Project-Specific Standards

### Project Structure
- R/ (custom plotting functions, themes)
- data/
  - raw/ (original data)
  - processed/ (cleaned data for plotting)
- visualizations/ (output directory for figures)
  - exploratory/ (draft visualizations)
  - final/ (publication-ready)
- scripts/ (numbered viz scripts: 01-wrangle.R, 02-plot-theme1.R, etc.)
- config/ (color palettes, plot dimensions as YAML or R list)

### Core Visualization Libraries
- ggplot2 (primary plotting)
- patchwork for combining plots
- scales for axis formatting
- ggtext for enhanced text (markdown in labels)
- Consider: gganimate for animations, plotly for interactivity

### Specialized Viz Libraries
- Based on project needs:
  - sf + ggplot2 for maps
  - ggiraph for interactive ggplot2
  - leaflet for interactive maps
  - highcharter for business charts
  - visNetwork or ggraph for network graphs
  - DT for interactive tables

### Design Standards
- Custom ggplot2 theme stored in R/theme.R
- Consistent color palette (define in R/colors.R or config/colors.R)
  - Use color-blind friendly palettes (viridis, RColorBrewer, colorspace)
  - Define semantic colors (e.g., highlight_color, neutral_color)
- Typography: Consistent fonts across all visualizations
  - Use systemfonts or showtext for custom fonts
- Consistent sizing: Store standard dimensions in config

### Code Quality
- air for formatting
- lintr for linting  
- Modular plotting functions: One function per plot type
- Use ggplot2 + functions, not repetitive plot code
- Parameters for customization (colors, labels, size)

### Testing Strategy
- Visual regression testing (vdiffr package)
- Unit tests for data preparation functions (testthat)
- Tests for plotting functions: Do they run without error?
- Validate plot outputs: Correct number of layers, expected data ranges

### Iteration Workflow
- exploratory/ folder for draft visualizations
- Iterate: Data → Draft plot → Review → Refine → Final
- Version control for major iterations (git commits with descriptive messages)
- Save plot code in scripts/, not just outputs

### Output Standards
- Final visualizations saved as:
  - PNG (300 DPI minimum) for presentations/web
  - PDF (vector) for print publications
  - SVG for web embedding (scales infinitely)
- Naming convention: descriptive-name_YYYY-MM-DD.png
- Include plot code in git, not just images

### Accessibility
- Color-blind friendly palettes
- Sufficient contrast (test with colorspace::contrast_ratio())
- Alt text descriptions (save as separate .txt file with same name)
- Consider: Direct labeling instead of legends where possible
- Avoid red/green as sole differentiator

### Documentation Requirements
- README.md: Project purpose, key visualizations, how to regenerate
- documentation/
  - design-decisions.md: Color choices, typography, layout rationale
  - data-sources.md: Where data came from
  - gallery.md: Showcase of final visualizations with descriptions
  - development.md: How to run scripts, regenerate plots

### Data Preparation
- Clean data wrangling separate from plotting (in numbered scripts)
- Save processed data as RDS for quick plot iterations
- Use checkmate to validate data before plotting
- Document any data transformations or filtering

### Reproducibility
- renv for package management
- here::here() for file paths
- Seed for any random elements (jitter, sampling)
- Document R version and system fonts used

### Interactive Visualizations
- If building Shiny apps or dashboards:
  - Use shinydashboard or bslib for layout
  - Preprocess data (don't wrangle in Shiny reactive context)
  - Test with realistic data volumes
  - Consider: Deploy to shinyapps.io free tier

### Quality Gates (Before Next Feature)
- [ ] Visualization accurately represents data
- [ ] Plot code runs without errors or warnings
- [ ] Color palette is colorblind-friendly
- [ ] Text is legible at intended display size
- [ ] Final version saved in multiple formats
- [ ] styler formatting applied
- [ ] Alt text or description written
- [ ] Documentation updated with new visualization

### Cost Considerations
- Local rendering (no cloud costs)
- Fonts: Use Google Fonts (free) or system fonts
- Shiny hosting: shinyapps.io free tier (5 apps, 25 active hours/month)
- Static viz hosting: GitHub Pages, Quarto Pub (free)