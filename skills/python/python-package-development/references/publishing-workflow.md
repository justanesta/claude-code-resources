# Publishing Workflow

## Build Package

```bash
# Install build tools
pip install build twine

# Build distributions
python -m build

# Creates:
# dist/mypackage-0.1.0.tar.gz
# dist/mypackage-0.1.0-py3-none-any.whl
```

## Test on TestPyPI

```bash
# Upload to TestPyPI
twine upload --repository testpypi dist/*

# Test install
pip install --index-url https://test.pypi.org/simple/ mypackage

# Verify it works
python -c "import mypackage; print(mypackage.__version__)"
```

## Publish to PyPI

```bash
# Upload to PyPI
twine upload dist/*
```

## PyPI API Token Setup

```bash
# Create token at https://pypi.org/manage/account/token/

# Configure in ~/.pypirc
[pypi]
username = __token__
password = pypi-...your-token...

# Or use environment variable
export TWINE_PASSWORD=pypi-...your-token...
twine upload dist/*
```

## GitHub Actions Automation

```yaml
# .github/workflows/publish.yml
name: Publish

on:
  release:
    types: [published]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
      - name: Build
        run: |
          pip install build
          python -m build
      - name: Publish
        env:
          TWINE_USERNAME: __token__
          TWINE_PASSWORD: ${{ secrets.PYPI_TOKEN }}
        run: |
          pip install twine
          twine upload dist/*
```

## Release Checklist

1. Update version in pyproject.toml
2. Update CHANGELOG.md
3. Run tests: `pytest`
4. Build: `python -m build`
5. Test on TestPyPI
6. Create git tag: `git tag v1.0.0`
7. Push tag: `git push origin v1.0.0`
8. Upload to PyPI: `twine upload dist/*`
9. Create GitHub release
