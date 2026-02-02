---
name: python-package-development
description: |
  Modern Python package development. Use this skill when creating packages, choosing 
  build tools, or publishing to PyPI. Covers pyproject.toml, src layout, versioning, 
  dependency management, testing, documentation, and publication workflow.
---

# Python Package Development

Modern patterns for building and distributing Python packages.

## Modern Package Structure (src layout)

```
my-package/
├── src/
│   └── mypackage/
│       ├── __init__.py
│       └── core.py
├── tests/
├── docs/
├── pyproject.toml
├── README.md
└── LICENSE
```

**Why src layout?**
- Ensures tests run against installed package
- Prevents accidental imports from working directory
- Industry best practice

## pyproject.toml Configuration

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "mypackage"
version = "0.1.0"
description = "A short description"
readme = "README.md"
requires-python = ">=3.10"
dependencies = [
    "pandas>=2.0.0",
]

[project.optional-dependencies]
dev = ["pytest>=7.0.0", "black>=23.0.0"]
```

See [pyproject-toml-guide.md](references/pyproject-toml-guide.md) for:
- Build backend choices
- Dynamic versioning
- Entry points

## Versioning Strategy

### Semantic Versioning

```
MAJOR.MINOR.PATCH

1.0.0 → Initial release
1.0.1 → Bug fix
1.1.0 → New feature
2.0.0 → Breaking change
```

See [versioning-strategies.md](references/versioning-strategies.md) for:
- CalVer
- Automatic versioning from git tags

## Dependency Management

```toml
# Library - use ranges
dependencies = ["requests>=2.31.0"]

# Application - pin versions
dependencies = ["requests==2.31.0"]
```

See [dependency-strategies.md](references/dependency-strategies.md) for:
- When to pin vs range
- Upper bounds debate

## Testing Packages

```python
# tests/test_core.py
import pytest
from mypackage import main_function

def test_main_function():
    result = main_function(input_data)
    assert result == expected
```

See [package-testing.md](references/package-testing.md) for:
- Integration testing
- Coverage requirements
- CI/CD setup

## Documentation

See [documentation-guide.md](references/documentation-guide.md) for:
- README essentials
- Docstring styles
- MkDocs/Sphinx

## Building and Publishing

```bash
# Build
python -m build

# Test on TestPyPI
twine upload --repository testpypi dist/*

# Publish to PyPI
twine upload dist/*
```

See [publishing-workflow.md](references/publishing-workflow.md) for:
- PyPI token setup
- GitHub Actions automation
- Release checklist

## Anti-Patterns to Avoid

| Avoid | Use Instead |
|-------|-------------|
| Flat layout | src layout |
| setup.py for simple packages | pyproject.toml only |
| Hard-coded version in multiple places | Single source |

source: Python Packaging User Guide
