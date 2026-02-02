# Polars Lazy Evaluation

## Lazy vs Eager

```python
import polars as pl

# Eager - executes immediately
df_eager = pl.read_csv("data.csv")

# Lazy - builds query plan, executes on collect()
df_lazy = pl.scan_csv("data.csv")
```

## Query Optimization Benefits

```python
# Lazy evaluation optimizes this automatically
result = (
    pl.scan_csv("large_data.csv")
    .filter(pl.col("year") == 2024)  # Pushed down to CSV reader
    .select(["id", "sales"])  # Only reads these columns
    .group_by("id")
    .agg(pl.col("sales").sum())
    .collect()  # Execute optimized plan
)

# Equivalent eager (reads entire file)
result_eager = (
    pl.read_csv("large_data.csv")  # Reads ALL data
    .filter(pl.col("year") == 2024)
    .select(["id", "sales"])
    .group_by("id")
    .agg(pl.col("sales").sum())
)
```

## Inspecting Query Plans

```python
lazy_df = (
    pl.scan_csv("data.csv")
    .filter(pl.col("amount") > 100)
    .group_by("category")
    .agg(pl.col("amount").sum())
)

# View optimized plan
print(lazy_df.explain())
```

## Streaming for Large Data

```python
# For data larger than RAM
result = (
    pl.scan_csv("huge_file.csv")
    .filter(pl.col("date") > "2024-01-01")
    .group_by("user_id")
    .agg(pl.col("amount").sum())
    .collect(streaming=True)  # Process in chunks
)
```

## When to Use Lazy

**Use lazy when:**
- Working with large files (>1GB)
- Multiple filtering/selection operations
- Reading from formats supporting pushdown (CSV, Parquet)
- Query optimization would help

**Use eager when:**
- Small datasets (<100MB)
- Interactive exploration
- Need immediate feedback
- Already in memory

## Combining Lazy and Eager

```python
# Start lazy, switch to eager for exploration
df = (
    pl.scan_csv("data.csv")
    .filter(pl.col("year") == 2024)
    .collect()  # Now eager
)

# Continue with eager operations
df = df.with_columns(
    pl.col("amount").log().alias("log_amount")
)
```

## Performance Comparison

```python
import time

# Eager (slower)
start = time.time()
result = (
    pl.read_csv("large.csv")
    .filter(pl.col("value") > 100)
    .select(["id", "value"])
)
print(f"Eager: {time.time() - start:.2f}s")

# Lazy (faster)
start = time.time()
result = (
    pl.scan_csv("large.csv")
    .filter(pl.col("value") > 100)
    .select(["id", "value"])
    .collect()
)
print(f"Lazy: {time.time() - start:.2f}s")
```
