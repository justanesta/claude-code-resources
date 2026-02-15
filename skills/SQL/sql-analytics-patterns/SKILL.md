---
name: sql-analytics-patterns
description: |
  Window functions, analytical queries, and advanced aggregation patterns for business
  intelligence and reporting. Use this skill when writing ranking queries, running totals,
  moving averages, percentile calculations, period-over-period comparisons, gap-and-island
  analysis, or pivot/crosstab transformations. Covers all major window functions, frame
  specifications, and cross-database syntax differences.
---

# SQL Analytics Patterns

Advanced analytical SQL patterns for business intelligence, reporting, and data analysis.

## Core Principles

1. **Window functions preserve row detail** - Unlike GROUP BY, window functions add analytical columns without collapsing rows
2. **Frame specification matters** - ROWS vs RANGE vs GROUPS produce different results; always be explicit
3. **PARTITION BY defines scope** - Think of it as GROUP BY for window functions without aggregation
4. **ORDER BY within windows controls logic** - Determines ranking order, running total direction, and LAG/LEAD sequence
5. **CTEs before windows** - Pre-filter and prepare data in CTEs, then apply window functions for clarity and performance

## Window Function Fundamentals

```sql
SELECT
    department,
    employee_name,
    salary,
    ROW_NUMBER() OVER (PARTITION BY department ORDER BY salary DESC) AS dept_rank,
    RANK()       OVER (PARTITION BY department ORDER BY salary DESC) AS dept_rank_with_gaps,
    DENSE_RANK() OVER (PARTITION BY department ORDER BY salary DESC) AS dept_rank_no_gaps,
    NTILE(4)     OVER (PARTITION BY department ORDER BY salary DESC) AS salary_quartile
FROM employees;
```

See [window-function-basics.md](references/window-function-basics.md) for:
- PARTITION BY and ORDER BY mechanics
- Frame specifications (ROWS, RANGE, GROUPS)
- Named window definitions with WINDOW clause
- Default frame behavior and common pitfalls

## Ranking Functions

```sql
-- Top-N per group: find the 3 best-selling products per category
WITH ranked_products AS (
    SELECT
        p.category_id,
        p.product_name,
        SUM(oi.quantity * oi.unit_price) AS total_revenue,
        ROW_NUMBER() OVER (
            PARTITION BY p.category_id
            ORDER BY SUM(oi.quantity * oi.unit_price) DESC
        ) AS revenue_rank
    FROM products p
    INNER JOIN order_items oi ON p.product_id = oi.product_id
    GROUP BY p.category_id, p.product_name
)
SELECT * FROM ranked_products WHERE revenue_rank <= 3;
```

See [window-function-basics.md](references/window-function-basics.md) for:
- ROW_NUMBER vs RANK vs DENSE_RANK decision matrix
- NTILE for percentile bucketing
- Deduplication with ROW_NUMBER

## Running Totals and Cumulative Calculations

```sql
SELECT
    order_date,
    daily_revenue,
    SUM(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue,
    COUNT(*) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_order_count,
    AVG(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_avg_revenue
FROM daily_sales;
```

See [running-calculations.md](references/running-calculations.md) for:
- Running totals with partition resets (monthly, quarterly)
- Cumulative percentages and contribution analysis
- Running distinct counts and conditional cumulations

## Moving Averages and Sliding Windows

```sql
-- 7-day simple moving average of daily revenue
SELECT
    sale_date,
    daily_revenue,
    AVG(daily_revenue) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS moving_avg_7d,
    MAX(daily_revenue) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) AS rolling_max_30d
FROM daily_sales
ORDER BY sale_date;
```

See [moving-averages.md](references/moving-averages.md) for:
- Simple and weighted moving averages
- ROWS vs RANGE frame behavior with dates
- Sliding window min/max/sum patterns
- Handling gaps in time series data

## Percentiles and Statistical Functions

```sql
-- Salary distribution analysis per department
SELECT DISTINCT
    department,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY salary) OVER (PARTITION BY department) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY salary) OVER (PARTITION BY department) AS median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY salary) OVER (PARTITION BY department) AS p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY salary) OVER (PARTITION BY department) AS p90
FROM employees;
```

See [percentile-statistics.md](references/percentile-statistics.md) for:
- PERCENTILE_CONT vs PERCENTILE_DISC
- PERCENT_RANK and CUME_DIST for relative positioning
- Median calculation across databases
- Outlier detection with IQR

## Lead/Lag for Period Comparisons

```sql
-- Month-over-month and year-over-year revenue growth
SELECT
    revenue_month,
    monthly_revenue,
    LAG(monthly_revenue, 1)  OVER (ORDER BY revenue_month) AS prev_month_revenue,
    LAG(monthly_revenue, 12) OVER (ORDER BY revenue_month) AS prev_year_revenue,
    ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue, 1) OVER (ORDER BY revenue_month))
        / NULLIF(LAG(monthly_revenue, 1) OVER (ORDER BY revenue_month), 0), 2) AS mom_growth_pct,
    ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue, 12) OVER (ORDER BY revenue_month))
        / NULLIF(LAG(monthly_revenue, 12) OVER (ORDER BY revenue_month), 0), 2) AS yoy_growth_pct
FROM monthly_revenue_summary;
```

See [lead-lag-patterns.md](references/lead-lag-patterns.md) for:
- LAG/LEAD with default values
- FIRST_VALUE and LAST_VALUE patterns
- Churn detection and retention analysis
- Time-to-event calculations

## Gap and Island Analysis

```sql
-- Identify consecutive login streaks per user
WITH login_groups AS (
    SELECT
        user_id,
        login_date,
        login_date - (ROW_NUMBER() OVER (
            PARTITION BY user_id ORDER BY login_date
        ))::INT AS island_group
    FROM (SELECT DISTINCT user_id, login_date::DATE AS login_date FROM user_logins) d
)
SELECT
    user_id,
    MIN(login_date) AS streak_start,
    MAX(login_date) AS streak_end,
    COUNT(*)        AS streak_length
FROM login_groups
GROUP BY user_id, island_group
HAVING COUNT(*) >= 3
ORDER BY user_id, streak_start;
```

See [gap-island-analysis.md](references/gap-island-analysis.md) for:
- Gap detection in sequences and dates
- Island identification with ROW_NUMBER technique
- Session analysis and sessionization
- Status change tracking and duration analysis

## Pivot and Crosstab Patterns

```sql
-- Manual pivot: monthly revenue by category
SELECT
    category_name,
    SUM(CASE WHEN EXTRACT(MONTH FROM order_date) = 1 THEN revenue ELSE 0 END) AS jan,
    SUM(CASE WHEN EXTRACT(MONTH FROM order_date) = 2 THEN revenue ELSE 0 END) AS feb,
    SUM(CASE WHEN EXTRACT(MONTH FROM order_date) = 3 THEN revenue ELSE 0 END) AS mar,
    SUM(CASE WHEN EXTRACT(MONTH FROM order_date) = 4 THEN revenue ELSE 0 END) AS apr
FROM order_summary
GROUP BY category_name
ORDER BY category_name;
```

See [pivot-crosstab-patterns.md](references/pivot-crosstab-patterns.md) for:
- CASE-based pivot patterns (all databases)
- PostgreSQL CROSSTAB with tablefunc
- SQL Server PIVOT/UNPIVOT operators
- Dynamic pivoting strategies

## Cross-Database Compatibility

| Feature | PostgreSQL | MySQL | SQL Server |
|---------|-----------|-------|------------|
| ROW_NUMBER / RANK | Full support | 8.0+ | Full support |
| NTILE | `NTILE(n)` | 8.0+ | `NTILE(n)` |
| PERCENTILE_CONT | Window + ordered-set aggregate | No native (use variables) | `PERCENTILE_CONT` within `OVER` |
| Frame GROUPS | PG 11+ | Not supported | Not supported |
| FIRST_VALUE / LAST_VALUE | Full support | 8.0+ | Full support |
| Named windows (WINDOW clause) | Full support | 8.0+ | Not supported |
| LAG / LEAD default value | `LAG(col, 1, default)` | `LAG(col, 1, default)` 8.0+ | `LAG(col, 1, default)` |
| PIVOT operator | Use CROSSTAB (tablefunc) | CASE-based only | Native `PIVOT` / `UNPIVOT` |
| FILTER clause | `COUNT(*) FILTER (WHERE ...)` | Not supported | Not supported |
| RANGE frame with dates | Full support | Limited | Limited |

## Anti-Patterns to Avoid

| Avoid | Use Instead | Why |
|-------|-------------|-----|
| `SELECT *, ROW_NUMBER() OVER ()` without ORDER BY | Always specify ORDER BY in window | Non-deterministic results across executions |
| Using RANGE when you mean ROWS | Explicit `ROWS BETWEEN ...` | RANGE groups ties together, giving unexpected running totals |
| Repeating the same OVER clause many times | Named windows with `WINDOW w AS (...)` | Readability and maintenance (PG/MySQL 8.0) |
| `LAST_VALUE()` without explicit frame | Add `ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING` | Default frame ends at CURRENT ROW, not partition end |
| Correlated subquery for running totals | `SUM() OVER (ORDER BY ...)` | O(n^2) vs O(n) performance |
| Self-join for LAG/LEAD comparisons | `LAG()` / `LEAD()` window functions | Simpler, faster, and handles edge cases |
| GROUP BY then re-joining for detail | Window function on ungrouped data | Single pass instead of two scans |

## Performance Tips

- **Index the ORDER BY columns** used in window functions for large tables
- **Pre-filter with CTEs** before applying window functions to reduce the working set
- **Limit partitions** - Window functions over very large partitions consume significant memory
- **Avoid redundant sorts** - Multiple window functions with the same OVER clause share a single sort
- **Use ROWS over RANGE** when possible - ROWS is generally faster because it avoids tie-handling logic
- **Materialize intermediate CTEs** in PostgreSQL with `AS MATERIALIZED` when the optimizer misjudges cost

source: PostgreSQL docs, SQL Server docs, MySQL 8.0 reference, SQL:2011 standard, Modern SQL (use-the-index-luke.com)
