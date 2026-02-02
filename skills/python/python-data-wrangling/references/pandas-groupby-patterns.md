# Pandas GroupBy Patterns

## Named Aggregations (Pandas 0.25+)

```python
summary = df.groupby("category").agg(
    total_sales=("sales", "sum"),
    avg_sales=("sales", "mean"),
    num_transactions=("sales", "count"),
    max_sale=("sales", "max")
)
```

## Multiple Grouping Levels

```python
# Group by multiple columns
summary = df.groupby(["region", "category"]).agg({
    "sales": ["sum", "mean"],
    "quantity": "sum"
})

# Unstack for pivot-like structure
pivot = summary.unstack(level="category")
```

## Window Functions (Transform)

```python
# Rank within groups
df["rank"] = df.groupby("category")["sales"].rank(method="dense", ascending=False)

# Running totals
df["cumsum"] = df.groupby("category")["sales"].cumsum()

# Percentage of group total
df["pct_of_category"] = df.groupby("category")["sales"].transform(
    lambda x: x / x.sum()
)

# Deviation from group mean
df["deviation"] = df.groupby("category")["sales"].transform(
    lambda x: x - x.mean()
)
```

## Custom Aggregation Functions

```python
def top_2_average(series):
    """Average of top 2 values."""
    return series.nlargest(2).mean()

def coef_of_variation(series):
    """Coefficient of variation."""
    return series.std() / series.mean()

result = df.groupby("category").agg({
    "sales": ["sum", "mean", top_2_average, coef_of_variation]
})
```

## Filtering Groups

```python
# Keep groups with more than 10 items
large_groups = df.groupby("category").filter(lambda x: len(x) > 10)

# Keep groups where total sales > 1000
high_sales = df.groupby("category").filter(
    lambda x: x["sales"].sum() > 1000
)
```

## GroupBy with Multiple Operations

```python
result = (
    df
    .groupby("category")
    .agg(
        total_sales=("sales", "sum"),
        avg_price=("price", "mean"),
        num_products=("product_id", "nunique")
    )
    .assign(
        sales_per_product=lambda x: x["total_sales"] / x["num_products"]
    )
    .sort_values("total_sales", ascending=False)
)
```

## GroupBy Apply for Complex Logic

```python
def top_performers(group):
    """Get top 3 performers by sales."""
    return group.nlargest(3, "sales")

top_by_category = df.groupby("category").apply(top_performers)
```
