# Window Function Basics

## Anatomy of a Window Function

```sql
function_name(expression) OVER (
    [PARTITION BY partition_columns]
    [ORDER BY sort_columns]
    [frame_clause]
)
```

- **PARTITION BY** - Divides rows into groups (like GROUP BY but without collapsing)
- **ORDER BY** - Defines the logical ordering within each partition
- **Frame clause** - Controls which rows within the partition the function operates on

## PARTITION BY Mechanics

```sql
-- No partition: entire result set is one window
SELECT
    employee_name,
    salary,
    AVG(salary) OVER () AS company_avg,
    salary - AVG(salary) OVER () AS diff_from_avg
FROM employees;

-- Single partition column
SELECT
    department,
    employee_name,
    salary,
    AVG(salary) OVER (PARTITION BY department) AS dept_avg,
    salary - AVG(salary) OVER (PARTITION BY department) AS diff_from_dept_avg
FROM employees;

-- Multiple partition columns
SELECT
    region,
    department,
    employee_name,
    salary,
    RANK() OVER (
        PARTITION BY region, department
        ORDER BY salary DESC
    ) AS rank_in_region_dept
FROM employees;
```

## ORDER BY in Windows

```sql
-- ORDER BY changes behavior of aggregate window functions
SELECT
    order_date,
    amount,
    -- Without ORDER BY: total across entire partition
    SUM(amount) OVER () AS total_amount,
    -- With ORDER BY: running total (cumulative sum)
    SUM(amount) OVER (ORDER BY order_date) AS running_total
FROM orders;

-- Multiple ORDER BY columns ensure deterministic ranking
-- Use DESC NULLS LAST for rankings where NULLs should sort last
```

## ROW_NUMBER vs RANK vs DENSE_RANK

```sql
-- Comparison with tied values
SELECT
    employee_name,
    salary,
    ROW_NUMBER() OVER (ORDER BY salary DESC) AS row_num,    -- 1, 2, 3, 4, 5
    RANK()       OVER (ORDER BY salary DESC) AS rank_val,    -- 1, 2, 2, 4, 5
    DENSE_RANK() OVER (ORDER BY salary DESC) AS dense_val    -- 1, 2, 2, 3, 4
FROM employees;
```

**Decision matrix:**

| Function | Ties | Gaps | Use When |
|----------|------|------|----------|
| ROW_NUMBER | Breaks ties arbitrarily | No gaps | Need exactly one row per rank (dedup, pagination) |
| RANK | Ties get same rank | Gaps after ties | Competition-style ranking (1st, 2nd, 2nd, 4th) |
| DENSE_RANK | Ties get same rank | No gaps | Need continuous rank values (top-N categories) |

```sql
-- Practical: Top 3 salaries per department (allows ties)
WITH ranked AS (
    SELECT
        department,
        employee_name,
        salary,
        DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS salary_rank
    FROM employees
)
SELECT * FROM ranked WHERE salary_rank <= 3;

-- Practical: Exactly 1 record per customer (deduplication)
WITH ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_email
            ORDER BY last_purchase_date DESC, customer_id
        ) AS rn
    FROM customers
)
SELECT * FROM ranked WHERE rn = 1;
```

## NTILE for Bucketing

```sql
-- Divide customers into quartiles by lifetime value
SELECT
    customer_id,
    customer_name,
    lifetime_value,
    NTILE(4) OVER (ORDER BY lifetime_value DESC) AS value_quartile
FROM customers;

-- Assign to deciles for scoring
SELECT
    customer_id,
    lifetime_value,
    NTILE(10) OVER (ORDER BY lifetime_value DESC) AS decile,
    CASE NTILE(10) OVER (ORDER BY lifetime_value DESC)
        WHEN 1 THEN 'Top 10%'
        WHEN 2 THEN 'Top 20%'
        WHEN 3 THEN 'Top 30%'
        ELSE 'Bottom 70%'
    END AS segment
FROM customers;
```

**NTILE edge case:** When rows do not divide evenly, earlier buckets get one extra row. For 10 rows with NTILE(3): bucket 1 gets 4 rows, buckets 2 and 3 get 3 rows each.

## Frame Specifications

### Frame Syntax

```
frame_clause:
    { ROWS | RANGE | GROUPS } BETWEEN frame_start AND frame_end

frame_start / frame_end:
    UNBOUNDED PRECEDING
    | N PRECEDING
    | CURRENT ROW
    | N FOLLOWING
    | UNBOUNDED FOLLOWING
```

### ROWS Frame

Counts physical rows regardless of value.

```sql
-- 3-row moving average (current row + 2 preceding)
SELECT
    sale_date,
    amount,
    AVG(amount) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS moving_avg_3
FROM daily_sales;

-- Centered moving average (1 row before and after)
SELECT
    sale_date,
    amount,
    AVG(amount) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
    ) AS centered_avg
FROM daily_sales;
```

### RANGE Frame

Groups rows with the same ORDER BY value together.

```sql
-- Sum all orders on the same date (RANGE treats ties as one unit)
SELECT
    order_date,
    order_id,
    amount,
    SUM(amount) OVER (
        ORDER BY order_date
        RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_total_range
FROM orders;

-- PostgreSQL: RANGE with interval for date-based windows
SELECT
    sale_date,
    amount,
    AVG(amount) OVER (
        ORDER BY sale_date
        RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW
    ) AS avg_last_7_calendar_days
FROM daily_sales;
```

### GROUPS Frame (PostgreSQL 11+)

Counts distinct groups of ORDER BY values instead of physical rows or logical ranges.

### Default Frame Behavior

```sql
-- IMPORTANT: Default frames differ based on presence of ORDER BY

-- No ORDER BY: frame is the entire partition
SUM(x) OVER (PARTITION BY dept)
-- Equivalent to: ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING

-- With ORDER BY: default frame is RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
SUM(x) OVER (PARTITION BY dept ORDER BY hire_date)
-- This creates a running total, but RANGE means ties are grouped!
-- Use ROWS explicitly for predictable running totals:
SUM(x) OVER (PARTITION BY dept ORDER BY hire_date ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
```

## Named Windows (WINDOW Clause)

```sql
-- PostgreSQL and MySQL 8.0+
SELECT
    department,
    employee_name,
    salary,
    ROW_NUMBER() OVER w AS row_num,
    RANK()       OVER w AS rank_val,
    SUM(salary)  OVER w AS running_salary,
    AVG(salary)  OVER w AS running_avg
FROM employees
WINDOW w AS (PARTITION BY department ORDER BY salary DESC);

-- Named windows can be extended: OVER (w ORDER BY salary DESC)
```

## Common Pitfalls

### LAST_VALUE Trap

```sql
-- BUG: LAST_VALUE returns current row due to default frame
SELECT
    employee_name,
    salary,
    LAST_VALUE(employee_name) OVER (ORDER BY salary) AS highest_paid  -- WRONG!
FROM employees;

-- FIX: Extend frame to entire partition
SELECT
    employee_name,
    salary,
    LAST_VALUE(employee_name) OVER (
        ORDER BY salary
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS highest_paid
FROM employees;
```

### Non-Deterministic ROW_NUMBER

```sql
-- BUG: Ties produce unpredictable ordering across executions
SELECT name, salary, ROW_NUMBER() OVER (ORDER BY salary) AS rn
FROM employees;  -- Two people with same salary get arbitrary rn

-- FIX: Add tiebreaker columns
SELECT name, salary, ROW_NUMBER() OVER (ORDER BY salary, employee_id) AS rn
FROM employees;
```

### PostgreSQL FILTER with Windows

```sql
-- FILTER clause works with window functions (PostgreSQL only)
SELECT order_date, category, amount,
    SUM(amount) FILTER (WHERE category = 'Electronics')
        OVER (ORDER BY order_date) AS electronics_running_total
FROM orders;
```
