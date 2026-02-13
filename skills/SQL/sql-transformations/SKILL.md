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
-- Multi-stage cleaning pipeline
WITH 
    -- Stage 1: Initial filtering
    valid_records AS (
        SELECT *
        FROM raw_customer_data
        WHERE email IS NOT NULL
          AND email LIKE '%@%'
          AND created_date IS NOT NULL
    ),
    -- Stage 2: Standardization
    standardized AS (
        SELECT 
            customer_id,
            TRIM(UPPER(email)) AS email,
            CASE 
                WHEN UPPER(country) IN ('US', 'USA', 'UNITED STATES') THEN 'United States'
                WHEN UPPER(country) IN ('UK', 'UNITED KINGDOM', 'GB') THEN 'United Kingdom'
                ELSE INITCAP(TRIM(country))
            END AS country,
            REGEXP_REPLACE(phone, '[^0-9]', '', 'g') AS phone_digits_only,
            created_date
        FROM valid_records
    ),
    -- Stage 3: Deduplication
    deduplicated AS (
        SELECT DISTINCT ON (email)
            *,
            ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_date DESC) AS rn
        FROM standardized
    )
SELECT *
FROM deduplicated
WHERE rn = 1;
```

See [data-cleaning-patterns.md](references/data-cleaning-patterns.md) for:
- Validation rules and quality checks
- Standardization patterns
- Handling missing/invalid data
- Multi-stage cleaning pipelines

## Type Conversions

```sql
-- Safe type conversions with error handling
SELECT 
    -- String to numeric (safe)
    CASE 
        WHEN price_str ~ '^[0-9]+\.?[0-9]*$' 
        THEN price_str::NUMERIC
        ELSE NULL
    END AS price,
    
    -- String to date (safe)
    CASE 
        WHEN date_str ~ '^\d{4}-\d{2}-\d{2}$'
        THEN date_str::DATE
        ELSE NULL
    END AS order_date,
    
    -- JSON to structured data
    (json_data->>'customer_id')::INTEGER AS customer_id,
    json_data->>'email' AS email,
    
    -- Array to string
    ARRAY_TO_STRING(tags, ', ') AS tags_list
FROM staging_data;

-- Type coercion across databases
-- PostgreSQL
SELECT CAST(price AS NUMERIC(10,2));
SELECT price::NUMERIC(10,2);

-- MySQL / SQL Server
SELECT CAST(price AS DECIMAL(10,2));
SELECT CONVERT(DECIMAL(10,2), price);
```

See [type-conversions.md](references/type-conversions.md) for:
- Safe type casting patterns
- String to numeric/date conversions
- JSON and array handling
- Cross-database conversion syntax

## String Operations

```sql
-- Common string transformations
SELECT 
    product_name,
    -- Case conversion
    UPPER(product_name) AS product_upper,
    LOWER(product_name) AS product_lower,
    INITCAP(product_name) AS product_title_case,
    
    -- Trimming and padding
    TRIM(description) AS description_trimmed,
    LTRIM(code) AS code_left_trim,
    LPAD(id::TEXT, 10, '0') AS id_padded,
    
    -- Substring extraction
    SUBSTRING(sku FROM 1 FOR 3) AS category_code,
    SPLIT_PART(email, '@', 2) AS email_domain,
    
    -- Pattern replacement
    REGEXP_REPLACE(phone, '[^0-9]', '', 'g') AS phone_numbers_only,
    REPLACE(description, 'old_brand', 'new_brand') AS updated_description,
    
    -- Concatenation
    first_name || ' ' || last_name AS full_name,
    CONCAT_WS(', ', city, state, country) AS location
FROM products;
```

See [string-operations.md](references/string-operations.md) for:
- SUBSTRING, SPLIT_PART, string parsing
- REGEXP_REPLACE for pattern matching
- String concatenation strategies
- Text cleaning and normalization

## Date and Time Operations

```sql
-- Date transformations and calculations
SELECT 
    order_date,
    
    -- Date arithmetic
    order_date + INTERVAL '7 days' AS delivery_date,
    order_date - INTERVAL '1 month' AS one_month_ago,
    
    -- Extract components
    EXTRACT(YEAR FROM order_date) AS order_year,
    EXTRACT(MONTH FROM order_date) AS order_month,
    EXTRACT(DOW FROM order_date) AS day_of_week,
    
    -- Date truncation (for grouping)
    DATE_TRUNC('month', order_date) AS order_month_start,
    DATE_TRUNC('week', order_date) AS order_week_start,
    
    -- Formatting
    TO_CHAR(order_date, 'YYYY-MM-DD') AS date_iso,
    TO_CHAR(order_date, 'Mon DD, YYYY') AS date_readable,
    
    -- Age calculations
    AGE(CURRENT_DATE, birth_date) AS age,
    DATE_PART('year', AGE(CURRENT_DATE, birth_date)) AS age_years,
    
    -- Business days calculation (excluding weekends)
    CASE EXTRACT(DOW FROM order_date)
        WHEN 0 THEN 2  -- Sunday -> Monday
        WHEN 6 THEN 2  -- Saturday -> Monday  
        ELSE 1         -- Next day
    END AS days_to_next_business_day
FROM orders;
```

See [date-time-operations.md](references/date-time-operations.md) for:
- Date arithmetic across databases
- Time zone handling
- Date formatting and parsing
- Business day calculations

## NULL Handling Strategies

```sql
-- Comprehensive NULL handling
SELECT 
    customer_id,
    
    -- COALESCE for fallback values
    COALESCE(phone_mobile, phone_home, phone_work, 'No Phone') AS primary_phone,
    COALESCE(discount_rate, 0.0) AS discount_rate,
    
    -- NULLIF to convert values to NULL
    NULLIF(TRIM(notes), '') AS notes_cleaned,
    NULLIF(price, 0) AS non_zero_price,
    
    -- NULL-safe arithmetic
    COALESCE(price, 0) * COALESCE(quantity, 0) AS total,
    price * quantity AS total_nullable,  -- NULL if either is NULL
    
    -- NULL checking in CASE
    CASE 
        WHEN email IS NULL THEN 'missing'
        WHEN email = '' THEN 'empty'
        ELSE 'valid'
    END AS email_status,
    
    -- Aggregate with NULL handling
    COUNT(*) AS total_rows,
    COUNT(email) AS non_null_emails,
    COUNT(DISTINCT email) AS unique_emails
FROM customers;
```

See [null-handling.md](references/null-handling.md) for:
- COALESCE vs NULLIF patterns
- NULL-safe operations
- NULL in aggregations
- Default value strategies

## Deduplication Strategies

```sql
-- Find duplicates
WITH duplicate_check AS (
    SELECT 
        email,
        COUNT(*) AS duplicate_count,
        STRING_AGG(customer_id::TEXT, ', ' ORDER BY created_date DESC) AS customer_ids
    FROM customers
    GROUP BY email
    HAVING COUNT(*) > 1
)
SELECT * FROM duplicate_check
ORDER BY duplicate_count DESC;

-- Remove duplicates - keep most recent
WITH ranked AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY email 
            ORDER BY created_date DESC, customer_id DESC
        ) AS rn
    FROM customers
)
SELECT * 
FROM ranked 
WHERE rn = 1;

-- Merge duplicate records
WITH duplicates AS (
    SELECT 
        email,
        MIN(customer_id) AS primary_id,
        ARRAY_AGG(customer_id ORDER BY created_date) AS all_ids,
        MAX(last_order_date) AS most_recent_order,
        SUM(total_purchases) AS combined_purchases
    FROM customers
    GROUP BY email
    HAVING COUNT(*) > 1
)
SELECT 
    primary_id,
    email,
    most_recent_order,
    combined_purchases
FROM duplicates;
```

See [deduplication-strategies.md](references/deduplication-strategies.md) for:
- Finding duplicate records
- ROW_NUMBER for deduplication
- DISTINCT ON (PostgreSQL)
- Merging duplicate data

## Common Transformation Patterns

### Pivot (Rows to Columns)

```sql
-- Transform row data into columnar format
SELECT 
    product_id,
    MAX(CASE WHEN attribute_name = 'color' THEN attribute_value END) AS color,
    MAX(CASE WHEN attribute_name = 'size' THEN attribute_value END) AS size,
    MAX(CASE WHEN attribute_name = 'weight' THEN attribute_value END) AS weight
FROM product_attributes
GROUP BY product_id;
```

### Unpivot (Columns to Rows)

```sql
-- Transform columnar data into rows
SELECT product_id, 'Q1' AS quarter, q1_sales AS sales FROM quarterly_sales
UNION ALL
SELECT product_id, 'Q2', q2_sales FROM quarterly_sales
UNION ALL
SELECT product_id, 'Q3', q3_sales FROM quarterly_sales
UNION ALL
SELECT product_id, 'Q4', q4_sales FROM quarterly_sales;
```

### Splitting Delimited Data

```sql
-- Split comma-separated values into rows
SELECT 
    id,
    TRIM(UNNEST(STRING_TO_ARRAY(tags, ','))) AS tag
FROM products
WHERE tags IS NOT NULL;
```

## ETL Best Practices

```sql
-- Idempotent upsert pattern (safe to run multiple times)
INSERT INTO target_table (id, name, value, updated_at)
SELECT id, name, value, CURRENT_TIMESTAMP
FROM source_table
ON CONFLICT (id) 
DO UPDATE SET
    name = EXCLUDED.name,
    value = EXCLUDED.value,
    updated_at = CURRENT_TIMESTAMP;

-- Incremental loading pattern
INSERT INTO fact_sales (order_id, customer_id, amount, order_date)
SELECT 
    order_id,
    customer_id,
    total_amount,
    order_date
FROM staging_orders
WHERE order_date >= (
    SELECT COALESCE(MAX(order_date), '1900-01-01') 
    FROM fact_sales
)
AND NOT EXISTS (
    SELECT 1 FROM fact_sales f 
    WHERE f.order_id = staging_orders.order_id
);
```

## Cross-Database Compatibility

### PostgreSQL Specifics
```sql
-- String to array
SELECT STRING_TO_ARRAY('a,b,c', ',');

-- Regex replace
SELECT REGEXP_REPLACE(text, 'pattern', 'replacement', 'g');

-- JSON operations
SELECT data->>'field' FROM json_table;
```

### MySQL Specifics
```sql
-- String split (requires MySQL 8.0+)
SELECT SUBSTRING_INDEX(tags, ',', 1) AS first_tag;

-- Group concat
SELECT GROUP_CONCAT(name SEPARATOR ', ') FROM items;
```

### SQL Server Specifics
```sql
-- String split
SELECT value FROM STRING_SPLIT('a,b,c', ',');

-- Date formatting
SELECT FORMAT(order_date, 'yyyy-MM-dd');

-- JSON operations
SELECT JSON_VALUE(data, '$.field') FROM json_table;
```

## Anti-Patterns to Avoid

| Avoid | Use Instead | Why |
|-------|-------------|-----|
| `UPDATE` without `WHERE` | Always specify conditions | Data corruption risk |
| Hardcoded dates | Parameterized or relative dates | Maintenance nightmare |
| String concatenation in loops | `STRING_AGG` / `GROUP_CONCAT` | Performance |
| Multiple `REPLACE` calls | `REGEXP_REPLACE` | More efficient |
| Implicit NULL conversion | Explicit `COALESCE` | Predictable behavior |
| `DISTINCT` without understanding why | Investigate root cause | May hide data quality issues |

## Performance Considerations

```sql
-- GOOD: Filter early, transform late
WITH filtered AS (
    SELECT * FROM large_table WHERE date >= '2024-01-01'
)
SELECT 
    UPPER(name),
    COMPLEX_TRANSFORMATION(value)
FROM filtered;

-- BAD: Transform everything, filter later
SELECT UPPER(name), COMPLEX_TRANSFORMATION(value)
FROM large_table
WHERE date >= '2024-01-01';

-- GOOD: Batch updates
UPDATE products 
SET updated_at = CURRENT_TIMESTAMP
WHERE product_id IN (SELECT product_id FROM changed_products);

-- BAD: Row-by-row updates in application
-- Multiple individual UPDATE statements
```

source: PostgreSQL docs, dbt best practices, Kimball ETL patterns
