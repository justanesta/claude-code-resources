# Pivot and Crosstab Patterns

## CASE-Based Pivot (All Databases)

```sql
-- Basic pivot: rows to columns
-- Transform rows of monthly data into columns
SELECT
    product_name,
    SUM(CASE WHEN sale_month = '2024-01' THEN revenue ELSE 0 END) AS jan_2024,
    SUM(CASE WHEN sale_month = '2024-02' THEN revenue ELSE 0 END) AS feb_2024,
    SUM(CASE WHEN sale_month = '2024-03' THEN revenue ELSE 0 END) AS mar_2024,
    SUM(CASE WHEN sale_month = '2024-04' THEN revenue ELSE 0 END) AS apr_2024,
    SUM(revenue) AS total
FROM monthly_product_sales
WHERE sale_month BETWEEN '2024-01' AND '2024-04'
GROUP BY product_name
ORDER BY total DESC;

-- Pivot with multiple aggregations
SELECT
    department,
    COUNT(CASE WHEN gender = 'M' THEN 1 END) AS male_count,
    COUNT(CASE WHEN gender = 'F' THEN 1 END) AS female_count,
    ROUND(AVG(CASE WHEN gender = 'M' THEN salary END)::NUMERIC, 2) AS male_avg_salary,
    ROUND(AVG(CASE WHEN gender = 'F' THEN salary END)::NUMERIC, 2) AS female_avg_salary
FROM employees
GROUP BY department
ORDER BY department;

-- Pivot with boolean flags
SELECT
    customer_id,
    customer_name,
    MAX(CASE WHEN permission = 'read' THEN 1 ELSE 0 END) AS can_read,
    MAX(CASE WHEN permission = 'write' THEN 1 ELSE 0 END) AS can_write,
    MAX(CASE WHEN permission = 'admin' THEN 1 ELSE 0 END) AS is_admin
FROM customer_permissions
GROUP BY customer_id, customer_name;
```

## Multi-Level Pivot

```sql
-- Pivot with two dimensions: region x quarter
SELECT
    region,
    SUM(CASE WHEN quarter = 'Q1' AND metric = 'revenue' THEN value ELSE 0 END) AS q1_revenue,
    SUM(CASE WHEN quarter = 'Q1' AND metric = 'orders' THEN value ELSE 0 END) AS q1_orders,
    SUM(CASE WHEN quarter = 'Q2' AND metric = 'revenue' THEN value ELSE 0 END) AS q2_revenue,
    SUM(CASE WHEN quarter = 'Q2' AND metric = 'orders' THEN value ELSE 0 END) AS q2_orders,
    SUM(CASE WHEN quarter = 'Q3' AND metric = 'revenue' THEN value ELSE 0 END) AS q3_revenue,
    SUM(CASE WHEN quarter = 'Q3' AND metric = 'orders' THEN value ELSE 0 END) AS q3_orders,
    SUM(CASE WHEN quarter = 'Q4' AND metric = 'revenue' THEN value ELSE 0 END) AS q4_revenue,
    SUM(CASE WHEN quarter = 'Q4' AND metric = 'orders' THEN value ELSE 0 END) AS q4_orders
FROM regional_metrics
GROUP BY region
ORDER BY region;

-- Pivot survey responses
SELECT
    question_id,
    question_text,
    COUNT(CASE WHEN response = 'Strongly Agree' THEN 1 END) AS strongly_agree,
    COUNT(CASE WHEN response = 'Agree' THEN 1 END) AS agree,
    COUNT(CASE WHEN response = 'Neutral' THEN 1 END) AS neutral,
    COUNT(CASE WHEN response = 'Disagree' THEN 1 END) AS disagree,
    COUNT(CASE WHEN response = 'Strongly Disagree' THEN 1 END) AS strongly_disagree,
    COUNT(*) AS total_responses
FROM survey_responses
GROUP BY question_id, question_text
ORDER BY question_id;
```

## PostgreSQL: CROSSTAB (tablefunc Extension)

```sql
-- Enable the extension
CREATE EXTENSION IF NOT EXISTS tablefunc;

-- Basic CROSSTAB: monthly revenue by product
SELECT *
FROM CROSSTAB(
    $$
    SELECT
        product_name,
        TO_CHAR(sale_date, 'YYYY-MM') AS sale_month,
        SUM(revenue)::NUMERIC AS total_revenue
    FROM sales
    WHERE sale_date >= '2024-01-01' AND sale_date < '2024-05-01'
    GROUP BY product_name, TO_CHAR(sale_date, 'YYYY-MM')
    ORDER BY product_name, sale_month
    $$,
    $$ VALUES ('2024-01'), ('2024-02'), ('2024-03'), ('2024-04') $$
) AS ct(
    product_name TEXT,
    jan_2024 NUMERIC,
    feb_2024 NUMERIC,
    mar_2024 NUMERIC,
    apr_2024 NUMERIC
);

-- CROSSTAB with explicit category list (handles missing values)
SELECT *
FROM CROSSTAB(
    $$
    SELECT
        department,
        job_title,
        COUNT(*)::INTEGER AS employee_count
    FROM employees
    GROUP BY department, job_title
    ORDER BY department, job_title
    $$,
    $$ SELECT DISTINCT job_title FROM employees ORDER BY job_title $$
) AS ct(
    department TEXT,
    analyst INTEGER,
    engineer INTEGER,
    manager INTEGER,
    director INTEGER
);
-- Missing combinations show as NULL instead of being skipped
```

## SQL Server: PIVOT Operator

```sql
-- Basic PIVOT syntax
SELECT
    product_name,
    [2024-01] AS jan_2024,
    [2024-02] AS feb_2024,
    [2024-03] AS mar_2024,
    [2024-04] AS apr_2024
FROM (
    SELECT
        product_name,
        FORMAT(sale_date, 'yyyy-MM') AS sale_month,
        revenue
    FROM sales
    WHERE sale_date >= '2024-01-01' AND sale_date < '2024-05-01'
) AS source_data
PIVOT (
    SUM(revenue)
    FOR sale_month IN ([2024-01], [2024-02], [2024-03], [2024-04])
) AS pivot_table
ORDER BY product_name;

-- Note: Columns not in PIVOT or FOR are implicitly grouped by
```

## SQL Server: UNPIVOT (Columns to Rows)

```sql
-- UNPIVOT: Convert columns back to rows
SELECT
    product_id,
    quarter,
    sales_amount
FROM (
    SELECT product_id, q1_sales, q2_sales, q3_sales, q4_sales
    FROM quarterly_sales
) AS src
UNPIVOT (
    sales_amount FOR quarter IN (q1_sales, q2_sales, q3_sales, q4_sales)
) AS unpvt;

-- Use REPLACE(quarter, '_sales', '') to clean column names in output
```

## Unpivot Patterns (Cross-Database)

```sql
-- UNION ALL approach (works everywhere)
SELECT product_id, 'Q1' AS quarter, q1_sales AS sales FROM quarterly_sales
UNION ALL
SELECT product_id, 'Q2', q2_sales FROM quarterly_sales
UNION ALL
SELECT product_id, 'Q3', q3_sales FROM quarterly_sales
UNION ALL
SELECT product_id, 'Q4', q4_sales FROM quarterly_sales
ORDER BY product_id, quarter;

-- PostgreSQL: UNNEST with arrays
SELECT
    product_id,
    quarter,
    sales
FROM quarterly_sales,
LATERAL UNNEST(
    ARRAY['Q1', 'Q2', 'Q3', 'Q4'],
    ARRAY[q1_sales, q2_sales, q3_sales, q4_sales]
) AS t(quarter, sales);

-- PostgreSQL: VALUES lateral join
SELECT
    qs.product_id,
    v.quarter,
    v.sales
FROM quarterly_sales qs
CROSS JOIN LATERAL (
    VALUES
        ('Q1', qs.q1_sales),
        ('Q2', qs.q2_sales),
        ('Q3', qs.q3_sales),
        ('Q4', qs.q4_sales)
) AS v(quarter, sales);
```

## Dynamic Pivot Strategies

```sql
-- PostgreSQL: Dynamic pivot using json_object_agg
SELECT
    product_name,
    json_object_agg(sale_month, monthly_revenue ORDER BY sale_month) AS monthly_data
FROM (
    SELECT
        product_name,
        TO_CHAR(sale_date, 'YYYY-MM') AS sale_month,
        SUM(revenue) AS monthly_revenue
    FROM sales
    GROUP BY product_name, TO_CHAR(sale_date, 'YYYY-MM')
) sub
GROUP BY product_name;
-- Returns JSON: {"2024-01": 5000, "2024-02": 6200, ...}

-- SQL Server: Dynamic PIVOT with sp_executesql
DECLARE @columns NVARCHAR(MAX), @sql NVARCHAR(MAX);

SELECT @columns = STRING_AGG(QUOTENAME(sale_month), ', ')
FROM (
    SELECT DISTINCT FORMAT(sale_date, 'yyyy-MM') AS sale_month
    FROM sales
    WHERE sale_date >= '2024-01-01'
) AS months;

SET @sql = N'
SELECT product_name, ' + @columns + N'
FROM (
    SELECT product_name, FORMAT(sale_date, ''yyyy-MM'') AS sale_month, revenue
    FROM sales
    WHERE sale_date >= ''2024-01-01''
) AS src
PIVOT (SUM(revenue) FOR sale_month IN (' + @columns + N')) AS pvt
ORDER BY product_name';

EXEC sp_executesql @sql;

```

## Pivot with Totals and Subtotals

```sql
-- Pivot with row and column totals
WITH monthly_data AS (
    SELECT
        COALESCE(category_name, 'TOTAL') AS category_name,
        SUM(CASE WHEN sale_month = '2024-01' THEN revenue ELSE 0 END) AS jan,
        SUM(CASE WHEN sale_month = '2024-02' THEN revenue ELSE 0 END) AS feb,
        SUM(CASE WHEN sale_month = '2024-03' THEN revenue ELSE 0 END) AS mar,
        SUM(revenue) AS total
    FROM monthly_product_sales
    GROUP BY ROLLUP(category_name)
)
SELECT * FROM monthly_data
ORDER BY
    CASE WHEN category_name = 'TOTAL' THEN 1 ELSE 0 END,
    category_name;

-- Using GROUPING SETS for subtotals
SELECT
    COALESCE(region, 'All Regions') AS region,
    COALESCE(category, 'All Categories') AS category,
    SUM(revenue) AS total_revenue,
    COUNT(*) AS order_count
FROM orders
GROUP BY GROUPING SETS (
    (region, category),
    (region),
    (category),
    ()
)
ORDER BY
    GROUPING(region),
    GROUPING(category),
    region,
    category;
```
