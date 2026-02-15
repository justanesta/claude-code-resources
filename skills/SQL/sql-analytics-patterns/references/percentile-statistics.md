# Percentile and Statistical Functions

## PERCENTILE_CONT vs PERCENTILE_DISC

```sql
-- PERCENTILE_CONT: Continuous (interpolates between values)
-- Returns a value that may not exist in the data
-- Best for: continuous numeric data like revenue, latency

-- PERCENTILE_DISC: Discrete (returns actual value from dataset)
-- Returns the first value at or above the target percentile
-- Best for: discrete data or when you need an actual existing value

-- Comparison example
-- Data: [10, 20, 30, 40, 50]
-- 50th percentile:
--   PERCENTILE_CONT(0.5) = 30 (exact midpoint)
--   PERCENTILE_DISC(0.5) = 30 (actual value)
-- 25th percentile:
--   PERCENTILE_CONT(0.25) = 20 (interpolated)
--   PERCENTILE_DISC(0.25) = 20 (actual value at or above 25th pct)
-- 40th percentile:
--   PERCENTILE_CONT(0.4) = 26 (interpolated between 20 and 30)
--   PERCENTILE_DISC(0.4) = 30 (first actual value >= 40th pct)
```

## PostgreSQL: Ordered-Set Aggregate Functions

```sql
-- Aggregate form (one row per group)
SELECT
    department,
    COUNT(*) AS employee_count,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary)::NUMERIC, 2) AS p25,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY salary)::NUMERIC, 2) AS median,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary)::NUMERIC, 2) AS p75,
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY salary)::NUMERIC, 2) AS p90,
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY salary)::NUMERIC, 2) AS p99
FROM employees
GROUP BY department;

-- Window function form (preserves all rows)
SELECT DISTINCT
    department,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY salary)
        OVER (PARTITION BY department) AS dept_median
FROM employees;

-- Multiple percentiles with PERCENTILE_DISC
SELECT
    department,
    PERCENTILE_DISC(0.25) WITHIN GROUP (ORDER BY salary) AS p25_actual,
    PERCENTILE_DISC(0.50) WITHIN GROUP (ORDER BY salary) AS median_actual,
    PERCENTILE_DISC(0.75) WITHIN GROUP (ORDER BY salary) AS p75_actual
FROM employees
GROUP BY department;
```

## SQL Server PERCENTILE_CONT

```sql
-- SQL Server uses PERCENTILE_CONT as a window function only
SELECT DISTINCT
    department,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary)
        OVER (PARTITION BY department) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY salary)
        OVER (PARTITION BY department) AS median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary)
        OVER (PARTITION BY department) AS p75
FROM employees;

-- Alternative using APPROX_PERCENTILE_CONT (SQL Server 2022+)
-- Faster for large datasets, uses approximate algorithm
SELECT
    department,
    APPROX_PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY salary) AS approx_median
FROM employees
GROUP BY department;
```

## MySQL: Median and Percentile Workarounds

```sql
-- MySQL does not have native PERCENTILE_CONT/DISC
-- Workaround using ROW_NUMBER and COUNT

-- Median calculation in MySQL 8.0+
WITH ranked AS (
    SELECT
        department,
        salary,
        ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary) AS rn,
        COUNT(*) OVER (PARTITION BY department) AS cnt
    FROM employees
)
SELECT
    department,
    AVG(salary) AS median_salary
FROM ranked
WHERE rn IN (FLOOR((cnt + 1) / 2), CEIL((cnt + 1) / 2))
GROUP BY department;

-- Percentile approximation in MySQL using NTILE
WITH quartiled AS (
    SELECT
        department,
        salary,
        NTILE(100) OVER (PARTITION BY department ORDER BY salary) AS percentile_bucket
    FROM employees
)
SELECT
    department,
    MAX(CASE WHEN percentile_bucket = 25 THEN salary END) AS approx_p25,
    MAX(CASE WHEN percentile_bucket = 50 THEN salary END) AS approx_median,
    MAX(CASE WHEN percentile_bucket = 75 THEN salary END) AS approx_p75,
    MAX(CASE WHEN percentile_bucket = 90 THEN salary END) AS approx_p90
FROM quartiled
GROUP BY department;
```

## PERCENT_RANK and CUME_DIST

```sql
-- PERCENT_RANK: relative rank as percentage (0 to 1)
-- Formula: (rank - 1) / (total_rows - 1)
-- First row = 0.0, last row = 1.0

-- CUME_DIST: cumulative distribution (fraction of rows <= current)
-- Formula: count of rows <= current / total_rows
-- Always > 0, last row = 1.0

SELECT
    employee_name,
    department,
    salary,
    ROUND(PERCENT_RANK() OVER (
        PARTITION BY department ORDER BY salary
    )::NUMERIC, 4) AS pct_rank,
    ROUND(CUME_DIST() OVER (
        PARTITION BY department ORDER BY salary
    )::NUMERIC, 4) AS cume_dist
FROM employees
ORDER BY department, salary;

-- Example results for 5 employees with salaries [50, 60, 60, 80, 100]:
-- salary=50:  PERCENT_RANK=0.00, CUME_DIST=0.20
-- salary=60:  PERCENT_RANK=0.25, CUME_DIST=0.60  (ties share rank)
-- salary=60:  PERCENT_RANK=0.25, CUME_DIST=0.60
-- salary=80:  PERCENT_RANK=0.75, CUME_DIST=0.80
-- salary=100: PERCENT_RANK=1.00, CUME_DIST=1.00

-- Practical: Find employees in top 10% of salary per department
WITH salary_ranks AS (
    SELECT
        employee_name,
        department,
        salary,
        PERCENT_RANK() OVER (PARTITION BY department ORDER BY salary) AS pct_rank
    FROM employees
)
SELECT *
FROM salary_ranks
WHERE pct_rank >= 0.90;
```

## Outlier Detection with IQR

```sql
-- Interquartile range method for outlier detection
WITH quartiles AS (
    SELECT
        product_category,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY order_total) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY order_total) AS q3
    FROM orders
    GROUP BY product_category
),
bounds AS (
    SELECT
        product_category,
        q1,
        q3,
        q3 - q1 AS iqr,
        q1 - 1.5 * (q3 - q1) AS lower_bound,
        q3 + 1.5 * (q3 - q1) AS upper_bound
    FROM quartiles
)
SELECT
    o.order_id,
    o.product_category,
    o.order_total,
    b.lower_bound,
    b.upper_bound,
    CASE
        WHEN o.order_total < b.lower_bound THEN 'Low Outlier'
        WHEN o.order_total > b.upper_bound THEN 'High Outlier'
        ELSE 'Normal'
    END AS outlier_status
FROM orders o
INNER JOIN bounds b ON o.product_category = b.product_category
ORDER BY o.product_category, o.order_total;
```

## Distribution Analysis

```sql
-- Full distribution summary per group
SELECT
    department,
    COUNT(*) AS n,
    ROUND(AVG(salary)::NUMERIC, 2) AS mean,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY salary)::NUMERIC, 2) AS median,
    ROUND(STDDEV(salary)::NUMERIC, 2) AS std_dev,
    MIN(salary) AS min_val,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary)::NUMERIC, 2) AS p25,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary)::NUMERIC, 2) AS p75,
    MAX(salary) AS max_val,
    ROUND((AVG(salary) - PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY salary))::NUMERIC, 2)
        AS mean_median_diff  -- Positive = right-skewed
FROM employees
GROUP BY department;

-- Histogram bucketing
WITH bounds AS (
    SELECT
        MIN(order_total) AS min_val,
        MAX(order_total) AS max_val,
        (MAX(order_total) - MIN(order_total)) / 10.0 AS bucket_width
    FROM orders
)
SELECT
    FLOOR((o.order_total - b.min_val) / b.bucket_width) + 1 AS bucket,
    ROUND((b.min_val + (FLOOR((o.order_total - b.min_val) / b.bucket_width)) * b.bucket_width)::NUMERIC, 2) AS bucket_start,
    ROUND((b.min_val + (FLOOR((o.order_total - b.min_val) / b.bucket_width) + 1) * b.bucket_width)::NUMERIC, 2) AS bucket_end,
    COUNT(*) AS frequency
FROM orders o
CROSS JOIN bounds b
GROUP BY bucket, bucket_start, bucket_end
ORDER BY bucket;
```

## Percentile-Based Segmentation

```sql
-- Customer segmentation by spending percentile
WITH customer_spend AS (
    SELECT
        customer_id,
        SUM(order_total) AS total_spend,
        COUNT(*) AS order_count
    FROM orders
    WHERE order_date >= CURRENT_DATE - INTERVAL '12 months'
    GROUP BY customer_id
),
with_percentiles AS (
    SELECT
        customer_id,
        total_spend,
        order_count,
        NTILE(5) OVER (ORDER BY total_spend) AS spend_quintile,
        PERCENT_RANK() OVER (ORDER BY total_spend) AS spend_pct_rank
    FROM customer_spend
)
SELECT
    customer_id,
    total_spend,
    order_count,
    spend_quintile,
    ROUND(spend_pct_rank::NUMERIC, 4) AS spend_pct_rank,
    CASE spend_quintile
        WHEN 5 THEN 'VIP (Top 20%)'
        WHEN 4 THEN 'High Value'
        WHEN 3 THEN 'Medium Value'
        WHEN 2 THEN 'Low Value'
        WHEN 1 THEN 'At Risk'
    END AS customer_segment
FROM with_percentiles
ORDER BY total_spend DESC;
```

## Latency / Performance Percentiles

```sql
-- API response time percentiles (common SRE metric)
SELECT
    endpoint,
    COUNT(*) AS request_count,
    ROUND(AVG(response_time_ms)::NUMERIC, 2) AS avg_ms,
    ROUND(PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY response_time_ms)::NUMERIC, 2) AS p50_ms,
    ROUND(PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY response_time_ms)::NUMERIC, 2) AS p90_ms,
    ROUND(PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY response_time_ms)::NUMERIC, 2) AS p95_ms,
    ROUND(PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY response_time_ms)::NUMERIC, 2) AS p99_ms,
    MAX(response_time_ms) AS max_ms
FROM api_requests
WHERE request_date >= CURRENT_DATE - INTERVAL '24 hours'
GROUP BY endpoint
ORDER BY p99_ms DESC;
```
