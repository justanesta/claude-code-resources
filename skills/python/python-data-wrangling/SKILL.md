---
name: python-data-wrangling
description: |
  Modern data wrangling with pandas and polars. Use this skill when working with tabular 
  data, need to choose between pandas/polars, or want to write idiomatic data manipulation 
  code. Covers method chaining, idiomatic operations, performance considerations, and 
  migration between libraries.
---

# Python Data Wrangling

Modern patterns for pandas and polars data manipulation.

## Decision Matrix: Pandas vs Polars

| Factor | Pandas | Polars | Winner |
|--------|--------|--------|--------|
| **Data size** | <1GB | >1GB, especially >10GB | Polars for large data |
| **Query optimization** | No | Yes (lazy evaluation) | Polars |
| **Ecosystem integration** | Vast (sklearn, viz) | Growing | Pandas for ML/viz |
| **API familiarity** | DataFrame standard | Rust-inspired | Pandas for teams |
| **Performance** | Good | Excellent (2-10x) | Polars |
| **Memory usage** | Higher | Lower | Polars |

**General guidance**:
- **Use pandas when**: <1GB data, heavy ML/viz integration, team familiarity critical
- **Use polars when**: >1GB data, performance critical, greenfield projects

## Modern Pandas Patterns

### Method Chaining

**Chain operations for readability**

```python
result = (
    df
    .assign(
        total=lambda x: x["price"] * x["quantity"],
        date=lambda x: pd.to_datetime(x["date"])
    )
    .query("total > 100")
    .sort_values("total", ascending=False)
    .groupby("category")
    .agg({"total": ["sum", "mean"]})
    .reset_index()
)
```

See [pandas-method-chaining.md](references/pandas-method-chaining.md) for:
- Lambda vs direct assignment
- Pipe with custom functions
- Handling complex transformations

### Idiomatic Operations

```python
# Use .loc for explicit indexing
df.loc[df["score"] > 80, "grade"] = "A"

# Use .pipe() for custom transformations
result = df.pipe(normalize_columns).pipe(remove_duplicates)

# Use .assign() for new columns
df = df.assign(
    log_value=lambda x: np.log(x["value"]),
    is_high=lambda x: x["value"] > x["value"].median()
)
```

### GroupBy Patterns

```python
# Named aggregations (pandas 0.25+)
summary = df.groupby("category").agg(
    total_sales=("sales", "sum"),
    avg_sales=("sales", "mean"),
    num_transactions=("sales", "count")
)
```

See [pandas-groupby-patterns.md](references/pandas-groupby-patterns.md) for:
- Window functions
- Multiple grouping levels
- Custom aggregations

## Polars Patterns

### Lazy Evaluation

**Use lazy API for query optimization**

```python
import polars as pl

result = (
    pl.scan_csv("data.csv")  # Lazy
    .filter(pl.col("value") > 100)
    .group_by("category")
    .agg([
        pl.col("sales").sum().alias("total_sales"),
        pl.col("sales").mean().alias("avg_sales")
    ])
    .collect()  # Execute
)
```

See [polars-lazy-evaluation.md](references/polars-lazy-evaluation.md) for:
- When lazy helps vs hurts
- Streaming for huge data
- Query plan inspection

### Polars Expressions

**Use expressions for vectorized operations**

```python
result = df.select([
    pl.col("name"),
    (pl.col("salary") * 1.1).alias("new_salary"),
    pl.when(pl.col("age") > 30)
      .then(pl.lit("senior"))
      .otherwise(pl.lit("junior"))
      .alias("level")
])
```

See [polars-expressions.md](references/polars-expressions.md) for:
- Expression composition
- when().then().otherwise() patterns
- List and struct operations

## Migration Guide

### Pandas → Polars

| Pandas | Polars | Notes |
|--------|--------|-------|
| `df["col"]` | `df["col"]` or `pl.col("col")` | Expressions preferred |
| `df[df["x"] > 5]` | `df.filter(pl.col("x") > 5)` | Method-based |
| `df.groupby("x").agg({"y": "sum"})` | `df.group_by("x").agg(pl.col("y").sum())` | Expression-based |

See [migration-pandas-polars.md](references/migration-pandas-polars.md) for complete patterns.

## Performance Tips

### Pandas Performance

```python
# Use vectorized operations
df["result"] = df["a"] + df["b"]  # Good

# Use categorical for low-cardinality columns
df["category"] = df["category"].astype("category")

# Use eval for complex expressions
df.eval("total = price * quantity", inplace=True)
```

### Polars Performance

```python
# Use scan instead of read for lazy
df = pl.scan_csv("data.csv")

# Use streaming for data larger than memory
result = df.collect(streaming=True)
```

## Anti-Patterns to Avoid

| Avoid | Use Instead |
|-------|-------------|
| `df.iterrows()` | Vectorized operations |
| Chained indexing `df["a"]["b"] = x` | `.loc` |
| Growing DataFrames in loops | `pd.concat()` outside loop |
| Mixed types in columns | Consistent types |

source: pandas user guide, polars documentation
