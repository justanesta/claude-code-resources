#!/bin/bash
# Initialize a new project with Claude Code configuration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_DIR="$(dirname "$SCRIPT_DIR")/config/templates"

PROJECT_TYPE=$1

show_usage() {
    echo "Usage: init-claude-project <project-type>"
    echo ""
    echo "Available templates:"
    ls -1 "$TEMPLATES_DIR"/*.md 2>/dev/null | xargs -n 1 basename | sed 's/.md$//' | sed 's/^/  - /' || echo "  No templates found"
    echo ""
    echo "Example: init-claude-project python-django-web"
}

if [ -z "$PROJECT_TYPE" ]; then
    show_usage
    exit 1
fi

TEMPLATE="$TEMPLATES_DIR/${PROJECT_TYPE}.md"

if [ ! -f "$TEMPLATE" ]; then
    echo "❌ Template not found: ${PROJECT_TYPE}"
    echo ""
    show_usage
    exit 1
fi

# Check if CLAUDE.md already exists
if [ -f "./CLAUDE.md" ]; then
    echo "⚠️  CLAUDE.md already exists in current directory"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        exit 0
    fi
fi

# Copy template
cp "$TEMPLATE" ./CLAUDE.md
echo "✓ Created CLAUDE.md from ${PROJECT_TYPE} template"

# Create CLAUDE.local.md if it doesn't exist
if [ ! -f "./CLAUDE.local.md" ]; then
    cat > ./CLAUDE.local.md << 'EOF'
# Project-Specific Overrides

<!-- Use this file for temporary notes, experiments, or overrides 
     that shouldn't be committed to the main CLAUDE.md -->

EOF
    echo "✓ Created CLAUDE.local.md"
else
    echo "ℹ️  CLAUDE.local.md already exists (not overwritten)"
fi

echo ""
echo "🎉 Project initialized! You can now run 'claude' in this directory."