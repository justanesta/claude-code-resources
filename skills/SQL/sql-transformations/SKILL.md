---
name: sql-transformations
description: |
  ETL patterns, data cleaning, type conversions, and string/date manipulation for data
  transformations. Use this skill when building data pipelines, cleaning messy data,
  standardizing formats, or performing complex transformations. Covers data quality patterns,
  type conversions, string operations, date/time handling, NULL strategies, and deduplication.
---

# SQL Transformations

Essential SQL patterns for ETL, data cleaning, and transformation workflows.

## Core Principles

1. **Clean at the source** - Fix data quality issues as early as possible
2. **Idempotent transformations** - Same input always produces same output
3. **Document assumptions** - Make data quality rules explicit
4. **Handle NULLs explicitly** - Never assume NULL behavior
5. **Test transformations** - Validate with sample data before production

## Data Cleaning Strategies

```sql
WITH
    valid_records AS (
        SELECT * FROM raw_customer_data
        WHERE email IS NOT NULL AND email LIKE '%@%'
    ),
    standardized AS (
        SELECT
            customer_id,
            TRIM(UPPER(email)) AS email,
            CASE
                WHEN UPPER(country) IN ('US', 'USA', 'UNITED STATES') THEN 'United States'
                WHEN UPPER(country) IN ('UK', 'UNITED KINGDOM', 'GB') THEN 'United Kingdom'
                ELSE INITCAP(TRIM(country))
            END AS country,
            REGEXP_REPLACE(phone, '[^0-9]', '', 'g') AS phone_digits_only
        FROM valid_records
    )
SELECT * FROM standardized;
```

See [data-cleaning-patterns.md](references/data-cleaning-patterns.md) for:
- Validation rules and quality checks
- Standardization patterns and multi-stage pipelines
- Outlier detection and data quality scoring

## Type Conversions

```sql
SELECT
    -- Safe string to numeric
    CASE
        WHEN price_str ~ '^[0-9]+\.?[0-9]*$' THEN price_str::NUMERIC
        ELSE NULL
    END AS price,
    -- Safe string to date
    CASE
        WHEN date_str ~ '^\d{4}-\d{2}-\d{2}$' THEN date_str::DATE
        ELSE NULL
    END AS order_date,
    -- JSON extraction
    (json_data->>'customer_id')::INTEGER AS customer_id
FROM staging_data;
```

See [type-conversions.md](references/type-conversions.md) for:
- Safe type casting patterns across databases
- JSON and array handling
- Cross-database conversion syntax

## String Operations

```sql
SELECT
    INITCAP(product_name) AS product_title_case,
    LPAD(id::TEXT, 10, '0') AS id_padded,
    SPLIT_PART(email, '@', 2) AS email_domain,
    REGEXP_REPLACE(phone, '[^0-9]', '', 'g') AS phone_numbers_only,
    CONCAT_WS(', ', city, state, country) AS location
FROM products;
```

See [string-operations.md](references/string-operations.md) for:
- SUBSTRING, SPLIT_PART, string parsing
- REGEXP_REPLACE for pattern matching
- Text cleaning and normalization

## Date and Time Operations

```sql
SELECT
    order_date,
    order_date + INTERVAL '7 days' AS delivery_date,
    EXTRACT(YEAR FROM order_date) AS order_year,
    DATE_TRUNC('month', order_date) AS order_month_start,
    TO_CHAR(order_date, 'YYYY-MM-DD') AS date_iso,
    DATE_PART('year', AGE(CURRENT_DATE, birth_date)) AS age_years
FROM orders;
```

See [date-time-operations.md](references/date-time-operations.md) for:
- Date arithmetic across databases
- Time zone handling
- Business day calculations

## NULL Handling Strategies

```sql
SELECT
    COALESCE(phone_mobile, phone_home, phone_work, 'No Phone') AS primary_phone,
    NULLIF(TRIM(notes), '') AS notes_cleaned,
    COALESCE(price, 0) * COALESCE(quantity, 0) AS total,
    CASE
        WHEN email IS NULL THEN 'missing'
        WHEN email = '' THEN 'empty'
        ELSE 'valid'
    END AS email_status
FROM customers;
```

See [null-handling.md](references/null-handling.md) for:
- COALESCE vs NULLIF patterns
- NULL in aggregations and sorting
- Default value strategies

## Deduplication Strategies

```sql
WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY email
            ORDER BY created_date DESC, customer_id DESC
        ) AS rn
    FROM customers
)
SELECT * FROM ranked WHERE rn = 1;
```

See [deduplication-strategies.md](references/deduplication-strategies.md) for:
- Finding and merging duplicate records
- DISTINCT ON (PostgreSQL)
- Deduplication with aggregation

## Common Transformation Patterns

```sql
-- Pivot (rows to columns)
SELECT
    product_id,
    MAX(CASE WHEN attr = 'color' THEN value END) AS color,
    MAX(CASE WHEN attr = 'size' THEN value END) AS size
FROM product_attributes
GROUP BY product_id;

-- Unpivot (columns to rows)
SELECT product_id, 'Q1' AS quarter, q1_sales AS sales FROM quarterly_sales
UNION ALL
SELECT product_id, 'Q2', q2_sales FROM quarterly_sales;
```

## ETL Best Practices

```sql
-- Idempotent upsert pattern
INSERT INTO target_table (id, name, value, updated_at)
SELECT id, name, value, CURRENT_TIMESTAMP
FROM source_table
ON CONFLICT (id)
DO UPDATE SET
    name = EXCLUDED.name,
    value = EXCLUDED.value,
    updated_at = CURRENT_TIMESTAMP;
```

## Cross-Database Compatibility

| Feature | PostgreSQL | MySQL | SQL Server |
|---------|-----------|-------|------------|
| String split | `STRING_TO_ARRAY()` | `SUBSTRING_INDEX()` | `STRING_SPLIT()` |
| Regex replace | `REGEXP_REPLACE()` | `REGEXP_REPLACE()` (8.0+) | N/A (use CLR) |
| Group concat | `STRING_AGG()` | `GROUP_CONCAT()` | `STRING_AGG()` (2017+) |
| JSON extract | `->>` operator | `JSON_EXTRACT()` | `JSON_VALUE()` |

## Anti-Patterns to Avoid

| Avoid | Use Instead | Why |
|-------|-------------|-----|
| `UPDATE` without `WHERE` | Always specify conditions | Data corruption risk |
| Hardcoded dates | Parameterized or relative dates | Maintenance nightmare |
| Multiple `REPLACE` calls | `REGEXP_REPLACE` | More efficient |
| Implicit NULL conversion | Explicit `COALESCE` | Predictable behavior |
| `DISTINCT` to fix duplicates | Investigate root cause | May hide data quality issues |

## Performance Tips

- Filter early, transform late — apply WHERE before expensive string/date operations
- Use batch updates over row-by-row processing
- Prefer `EXISTS` over `IN` for existence checks against large tables
- Index columns used in JOIN and WHERE before running ETL

source: PostgreSQL docs, dbt best practices, Kimball ETL patterns
