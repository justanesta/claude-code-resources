# Pandas Method Chaining

## Why Method Chaining?

Method chaining creates a single, readable pipeline rather than multiple intermediate variables.

```python
# With chaining (clear pipeline)
result = (
    pd.read_csv("data.csv")
    .query("age > 18")
    .assign(adult=True)
    .groupby("city")
    .size()
    .reset_index(name="count")
)
```

## Lambda in assign() for Sequential Dependencies

```python
# Lambda allows referencing previously created columns
df = df.assign(
    total=lambda x: x["price"] * x["quantity"],
    discount=lambda x: x["total"] * 0.1,  # Can use 'total'
    final_price=lambda x: x["total"] - x["discount"]
)
```

## pipe() for Custom Transformations

```python
def remove_outliers(df, column, n_std=3):
    mean = df[column].mean()
    std = df[column].std()
    return df[
        (df[column] > mean - n_std * std) &
        (df[column] < mean + n_std * std)
    ]

result = (
    df
    .pipe(normalize_columns)
    .pipe(remove_outliers, "salary", n_std=2)
    .sort_values("salary", ascending=False)
)
```

## Complex Transformations

```python
cleaned_df = (
    raw_df
    .rename(columns=lambda x: x.strip().lower().replace(" ", "_"))
    .assign(
        age=lambda x: x["age"].fillna(x["age"].median()),
        city=lambda x: x["city"].fillna("Unknown")
    )
    .query("age >= 0 and age <= 120")
    .assign(
        age_group=lambda x: pd.cut(x["age"], bins=[0, 18, 35, 50, 100]),
        high_earner=lambda x: x["salary"] > x["salary"].quantile(0.75)
    )
    .sort_values(["city", "age"])
    .reset_index(drop=True)
)
```

## Debugging Chains

```python
def debug_df(df, message=""):
    print(f"\n{message} - Shape: {df.shape}")
    print(df.head())
    return df

result = (
    df
    .pipe(debug_df, "After loading")
    .query("age > 18")
    .pipe(debug_df, "After filtering")
)
```
