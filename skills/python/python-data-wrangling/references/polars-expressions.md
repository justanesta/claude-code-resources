# Polars Expressions

## Basic Expressions

```python
import polars as pl

# Select with expressions
df.select([
    pl.col("name"),
    pl.col("age"),
    (pl.col("salary") * 1.1).alias("new_salary")
])

# Multiple column operations
df.select([
    pl.col("*"),  # All columns
    (pl.col("price") * pl.col("quantity")).alias("total")
])
```

## Conditional Logic with when/then/otherwise

```python
df.select([
    pl.col("name"),
    pl.when(pl.col("age") < 18)
      .then(pl.lit("Minor"))
      .when(pl.col("age") < 65)
      .then(pl.lit("Adult"))
      .otherwise(pl.lit("Senior"))
      .alias("age_group")
])
```

## String Operations

```python
df.select([
    pl.col("name").str.to_lowercase().alias("name_lower"),
    pl.col("email").str.contains("@gmail").alias("is_gmail"),
    pl.col("text").str.split(" ").alias("words")
])
```

## List Operations

```python
# Work with list columns
df = pl.DataFrame({
    "id": [1, 2, 3],
    "tags": [["a", "b"], ["c"], ["d", "e", "f"]]
})

df.select([
    pl.col("id"),
    pl.col("tags").list.len().alias("num_tags"),
    pl.col("tags").list.first().alias("first_tag"),
    pl.col("tags").list.contains("a").alias("has_a")
])
```

## Aggregation Expressions

```python
df.group_by("category").agg([
    pl.col("sales").sum().alias("total_sales"),
    pl.col("sales").mean().alias("avg_sales"),
    pl.col("sales").std().alias("std_sales"),
    pl.col("customer_id").n_unique().alias("unique_customers"),
    pl.col("product").first().alias("first_product")
])
```

## Window Functions

```python
df.with_columns([
    pl.col("sales").rank().over("category").alias("rank_in_category"),
    pl.col("sales").sum().over("category").alias("category_total"),
    pl.col("sales").pct_change().over("date").alias("daily_change")
])
```

## Complex Expression Composition

```python
# Build complex expressions
avg_sales = pl.col("sales").mean()
std_sales = pl.col("sales").std()

df.with_columns([
    ((pl.col("sales") - avg_sales) / std_sales).alias("z_score")
])
```
