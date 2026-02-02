# Dependency Strategies

## Version Specifiers

```toml
# Exact version (rarely needed)
dependencies = ["requests==2.31.0"]

# Minimum version
dependencies = ["requests>=2.31.0"]

# Version range
dependencies = ["requests>=2.31.0,<3.0.0"]

# Compatible release (recommended)
dependencies = ["requests~=2.31.0"]  # >=2.31.0, <2.32.0
```

## When to Pin vs Range

```toml
# Application - pin dependencies
dependencies = [
    "requests==2.31.0",
    "pandas==2.1.0"
]

# Library - use ranges
dependencies = [
    "requests>=2.31.0",
    "pandas>=2.0.0"
]
```

## Upper Bounds Debate

```toml
# Conservative (safer, may limit users)
dependencies = ["package>=1.0.0,<2.0.0"]

# Liberal (flexible, may break)
dependencies = ["package>=1.0.0"]

# Recommended: Only add upper bound for known incompatibilities
dependencies = [
    "pandas>=2.0.0",
    "numpy>=1.24.0,<2.0.0"  # numpy 2.0 has breaking changes
]
```

## Managing Transitive Dependencies

```bash
# Lock file for applications
pip freeze > requirements.txt

# Or use pipenv/poetry
pipenv lock
poetry lock
```
