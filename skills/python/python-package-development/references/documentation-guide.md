# Documentation Guide

## README.md Essentials

```markdown
# MyPackage

Brief description.

## Installation

```bash
pip install mypackage
```

## Quick Start

```python
from mypackage import main_function
result = main_function(data)
```

## Features

- Feature 1
- Feature 2

## Documentation

Full docs: https://mypackage.readthedocs.io

## License

MIT
```

## Docstring Styles

### Google Style

```python
def function(arg1: int, arg2: str) -> bool:
    """
    Summary line.
    
    Extended description.
    
    Args:
        arg1: Description of arg1
        arg2: Description of arg2
    
    Returns:
        Description of return value
    
    Raises:
        ValueError: When validation fails
    """
    pass
```

### NumPy Style

```python
def function(arg1, arg2):
    """
    Summary line.
    
    Parameters
    ----------
    arg1 : int
        Description
    arg2 : str
        Description
    
    Returns
    -------
    bool
        Description
    """
    pass
```

## Building Docs with MkDocs

```bash
# Install
pip install mkdocs mkdocs-material

# Create config
# mkdocs.yml
site_name: MyPackage
theme:
  name: material

nav:
  - Home: index.md
  - API: api.md

# Serve locally
mkdocs serve

# Build
mkdocs build
```
