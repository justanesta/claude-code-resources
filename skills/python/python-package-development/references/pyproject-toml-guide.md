# Pyproject.toml Guide

## Basic Structure

```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "mypackage"
version = "0.1.0"
description = "Short description"
readme = "README.md"
requires-python = ">=3.10"
license = {text = "MIT"}
authors = [
    {name = "Your Name", email = "you@example.com"}
]
dependencies = [
    "pandas>=2.0.0",
    "numpy>=1.24.0",
]
```

## Build Backend Options

```toml
# Hatchling (modern, simple)
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

# Setuptools (traditional, widely used)
[build-system]
requires = ["setuptools>=61.0"]
build-backend = "setuptools.build_meta"

# Flit (minimal, simple packages)
[build-system]
requires = ["flit_core>=3.2"]
build-backend = "flit_core.buildapi"
```

## Optional Dependencies

```toml
[project.optional-dependencies]
dev = [
    "pytest>=7.0.0",
    "black>=23.0.0",
    "ruff>=0.1.0",
]
docs = [
    "mkdocs>=1.5.0",
]
test = [
    "pytest>=7.0.0",
    "pytest-cov>=4.0.0",
]
# Install with: pip install mypackage[dev]
```

## Scripts and Entry Points

```toml
[project.scripts]
mypackage = "mypackage.cli:main"
my-tool = "mypackage.tools:run"
```

## URLs

```toml
[project.urls]
Homepage = "https://github.com/user/package"
Documentation = "https://package.readthedocs.io"
Repository = "https://github.com/user/package.git"
Issues = "https://github.com/user/package/issues"
Changelog = "https://github.com/user/package/blob/main/CHANGELOG.md"
```

## Tool Configurations

```toml
[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py"]
addopts = "--cov=mypackage --cov-report=html"

[tool.ruff]
line-length = 88
target-version = "py310"
select = ["E", "F", "I"]

[tool.black]
line-length = 88
target-version = ['py310', 'py311']

[tool.mypy]
python_version = "3.10"
warn_return_any = true
warn_unused_configs = true
```

## Classifiers

```toml
classifiers = [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
    "Programming Language :: Python :: 3.12",
    "Topic :: Software Development :: Libraries",
]
```
