# Package Testing

## Test Structure

```
mypackage/
├── src/
│   └── mypackage/
│       ├── __init__.py
│       └── core.py
├── tests/
│   ├── __init__.py
│   ├── test_core.py
│   └── test_integration.py
└── pyproject.toml
```

## Basic Tests

```python
# tests/test_core.py
import pytest
from mypackage import main_function

def test_main_function():
    result = main_function(input_data)
    assert result == expected

def test_error_handling():
    with pytest.raises(ValueError):
        main_function(invalid_input)
```

## Testing with Multiple Python Versions

```ini
# tox.ini
[tox]
envlist = py310,py311,py312

[testenv]
deps = pytest
commands = pytest tests/
```

## GitHub Actions CI

```yaml
# .github/workflows/test.yml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ['3.10', '3.11', '3.12']
    
    steps:
    - uses: actions/checkout@v3
    - uses: actions/setup-python@v4
      with:
        python-version: ${{ matrix.python-version }}
    - name: Install dependencies
      run: |
        pip install -e ".[dev]"
    - name: Run tests
      run: pytest
```

## Coverage

```bash
# Install
pip install pytest-cov

# Run with coverage
pytest --cov=mypackage --cov-report=html

# Enforce minimum coverage
pytest --cov=mypackage --cov-fail-under=80
```
