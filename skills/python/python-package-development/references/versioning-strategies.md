# Versioning Strategies

## Semantic Versioning (SemVer)

```
MAJOR.MINOR.PATCH

Examples:
1.0.0 → Initial release
1.0.1 → Backward-compatible bug fix
1.1.0 → New backward-compatible feature
2.0.0 → Breaking change
```

## Pre-release Versions

```
1.0.0a1   # Alpha
1.0.0b1   # Beta  
1.0.0rc1  # Release candidate
1.0.0     # Final release
```

## Version in pyproject.toml

```toml
[project]
version = "1.2.3"
```

## Dynamic Versioning from Git Tags

```bash
# Tag a release
git tag v1.0.0
git push origin v1.0.0

# Use setuptools_scm
# pyproject.toml
[build-system]
requires = ["setuptools>=64", "setuptools-scm>=8"]

[tool.setuptools_scm]
version_file = "src/mypackage/_version.py"

# In __init__.py
from ._version import __version__
```

## CalVer (Calendar Versioning)

```
YYYY.MM.MICRO

Examples:
2024.01.0  # January 2024, first release
2024.01.1  # January 2024, second release
2024.02.0  # February 2024, first release
```

## Version Bumping

```bash
# Manual
# Edit pyproject.toml, update version

# With tool (bump2version)
pip install bump2version
bump2version patch  # 1.0.0 → 1.0.1
bump2version minor  # 1.0.0 → 1.1.0
bump2version major  # 1.0.0 → 2.0.0
```
