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