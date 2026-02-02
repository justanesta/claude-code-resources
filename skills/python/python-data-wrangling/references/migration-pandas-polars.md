# Migration: Pandas to Polars

## Reading Data

```python
# Pandas
df = pd.read_csv("data.csv")

# Polars (eager)
df = pl.read_csv("data.csv")

# Polars (lazy - recommended)
df = pl.scan_csv("data.csv").collect()
```

## Selection and Filtering

```python
# Pandas
df[["col1", "col2"]]
df[df["age"] > 18]

# Polars
df.select(["col1", "col2"])
df.filter(pl.col("age") > 18)
```

## Adding Columns

```python
# Pandas
df["new_col"] = df["a"] + df["b"]
df.assign(new_col=lambda x: x["a"] + x["b"])

# Polars
df.with_columns(
    (pl.col("a") + pl.col("b")).alias("new_col")
)
```

## GroupBy Operations

```python
# Pandas
df.groupby("category").agg({"sales": "sum"})

# Polars
df.group_by("category").agg(pl.col("sales").sum())

# Pandas (named agg)
df.groupby("category").agg(
    total_sales=("sales", "sum"),
    avg_sales=("sales", "mean")
)

# Polars
df.group_by("category").agg([
    pl.col("sales").sum().alias("total_sales"),
    pl.col("sales").mean().alias("avg_sales")
])
```

## Sorting

```python
# Pandas
df.sort_values("age", ascending=False)

# Polars
df.sort("age", descending=True)
```

## Joins

```python
# Pandas
df1.merge(df2, on="id", how="left")

# Polars
df1.join(df2, on="id", how="left")
```

## Handling Missing Values

```python
# Pandas
df.fillna(0)
df.dropna()

# Polars
df.fill_null(0)
df.drop_nulls()
```

## Key Differences

1. **No Index**: Polars has no row index
2. **Expressions**: Polars uses `pl.col()` expressions
3. **Lazy Evaluation**: Polars supports query optimization
4. **Immutable**: Most Polars operations return new DataFrames
5. **Type Strict**: Polars is stricter about types
