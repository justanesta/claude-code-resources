# Running Calculations

## Basic Running Total

```sql
-- Cumulative revenue by day
SELECT
    order_date,
    daily_revenue,
    SUM(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM daily_sales
ORDER BY order_date;

-- Running total with explicit ROWS (recommended over default RANGE)
SELECT
    transaction_id,
    transaction_date,
    amount,
    SUM(amount) OVER (
        ORDER BY transaction_date, transaction_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance
FROM account_transactions
WHERE account_id = 1001;
```

## Running Totals with Partition Resets

```sql
-- Running total that resets each month
SELECT
    order_date,
    daily_revenue,
    SUM(daily_revenue) OVER (
        PARTITION BY DATE_TRUNC('month', order_date)
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS mtd_revenue
FROM daily_sales;

-- Running total that resets each quarter
SELECT
    order_date,
    daily_revenue,
    SUM(daily_revenue) OVER (
        PARTITION BY DATE_TRUNC('quarter', order_date)
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS qtd_revenue,
    SUM(daily_revenue) OVER (
        PARTITION BY DATE_TRUNC('year', order_date)
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS ytd_revenue
FROM daily_sales;

-- Running total per customer
SELECT
    customer_id,
    order_date,
    order_total,
    SUM(order_total) OVER (
        PARTITION BY customer_id
        ORDER BY order_date, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS customer_lifetime_spend
FROM orders;
```

## Cumulative Count and Average

```sql
-- Cumulative order count and average order value
SELECT
    order_date,
    order_total,
    COUNT(*) OVER (
        ORDER BY order_date, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_orders,
    AVG(order_total) OVER (
        ORDER BY order_date, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_avg_order,
    SUM(order_total) OVER (
        ORDER BY order_date, order_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM orders;

-- Cumulative distinct count (requires a workaround)
-- Count distinct categories seen so far
WITH ordered_sales AS (
    SELECT
        sale_date,
        category,
        ROW_NUMBER() OVER (PARTITION BY category ORDER BY sale_date) AS category_appearance
    FROM sales
)
SELECT
    sale_date,
    category,
    SUM(CASE WHEN category_appearance = 1 THEN 1 ELSE 0 END) OVER (
        ORDER BY sale_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_distinct_categories
FROM ordered_sales
ORDER BY sale_date;
```

## Cumulative Percentage / Contribution

```sql
-- Running percentage of total revenue
SELECT
    order_date,
    daily_revenue,
    SUM(daily_revenue) OVER (
        ORDER BY order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue,
    ROUND(
        100.0 * SUM(daily_revenue) OVER (
            ORDER BY order_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) / SUM(daily_revenue) OVER (), 2
    ) AS cumulative_pct_of_total
FROM daily_sales
ORDER BY order_date;

-- Pareto analysis: identify products contributing 80% of revenue
WITH product_revenue AS (
    SELECT
        product_id,
        product_name,
        SUM(quantity * unit_price) AS total_revenue
    FROM order_items oi
    INNER JOIN products p ON oi.product_id = p.product_id
    GROUP BY product_id, product_name
),
ranked AS (
    SELECT
        product_id,
        product_name,
        total_revenue,
        SUM(total_revenue) OVER (ORDER BY total_revenue DESC) AS cumulative_revenue,
        SUM(total_revenue) OVER () AS grand_total,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS revenue_rank
    FROM product_revenue
)
SELECT
    product_id,
    product_name,
    total_revenue,
    cumulative_revenue,
    ROUND(100.0 * cumulative_revenue / grand_total, 2) AS cumulative_pct,
    CASE
        WHEN 100.0 * cumulative_revenue / grand_total <= 80 THEN 'A (top 80%)'
        WHEN 100.0 * cumulative_revenue / grand_total <= 95 THEN 'B (next 15%)'
        ELSE 'C (bottom 5%)'
    END AS abc_class
FROM ranked
ORDER BY revenue_rank;
```

## Conditional Running Totals

```sql
-- Running total only for specific transaction types
SELECT
    transaction_date,
    transaction_type,
    amount,
    SUM(CASE WHEN transaction_type = 'credit' THEN amount ELSE 0 END) OVER (
        ORDER BY transaction_date, transaction_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_credits,
    SUM(CASE WHEN transaction_type = 'debit' THEN amount ELSE 0 END) OVER (
        ORDER BY transaction_date, transaction_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_debits,
    SUM(CASE
        WHEN transaction_type = 'credit' THEN amount
        WHEN transaction_type = 'debit' THEN -amount
        ELSE 0
    END) OVER (
        ORDER BY transaction_date, transaction_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_balance
FROM account_transactions
WHERE account_id = 1001;

-- PostgreSQL FILTER syntax (cleaner)
SELECT
    transaction_date,
    transaction_type,
    amount,
    SUM(amount) FILTER (WHERE transaction_type = 'credit') OVER (
        ORDER BY transaction_date, transaction_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_credits,
    SUM(amount) FILTER (WHERE transaction_type = 'debit') OVER (
        ORDER BY transaction_date, transaction_id
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS running_debits
FROM account_transactions
WHERE account_id = 1001;
```

## Running Min / Max (High Water Mark)

```sql
-- Track all-time high stock price
SELECT
    trade_date,
    close_price,
    MAX(close_price) OVER (
        ORDER BY trade_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS all_time_high,
    MIN(close_price) OVER (
        ORDER BY trade_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS all_time_low,
    close_price - MAX(close_price) OVER (
        ORDER BY trade_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS drawdown_from_high
FROM stock_prices
WHERE ticker = 'ACME';

-- Track maximum drawdown
WITH price_data AS (
    SELECT
        trade_date,
        close_price,
        MAX(close_price) OVER (
            ORDER BY trade_date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_high
    FROM stock_prices
    WHERE ticker = 'ACME'
)
SELECT
    trade_date,
    close_price,
    running_high,
    ROUND(100.0 * (close_price - running_high) / running_high, 2) AS drawdown_pct,
    MIN(ROUND(100.0 * (close_price - running_high) / running_high, 2)) OVER (
        ORDER BY trade_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS max_drawdown_pct
FROM price_data;
```

## Cross-Database Notes

```sql
-- PostgreSQL, MySQL 8.0+, SQL Server 2012+: identical syntax
SUM(amount) OVER (ORDER BY order_date ROWS UNBOUNDED PRECEDING)

-- SQL Server pre-2012: use correlated subquery
SELECT o1.order_date, o1.amount,
    (SELECT SUM(o2.amount) FROM orders o2 WHERE o2.order_date <= o1.order_date) AS running_total
FROM orders o1;
```

## Running Calculations with Gap Handling

```sql
-- Fill date gaps before computing running totals
WITH date_spine AS (
    SELECT generate_series(
        (SELECT MIN(order_date) FROM daily_sales),
        (SELECT MAX(order_date) FROM daily_sales),
        '1 day'::INTERVAL
    )::DATE AS sale_date
),
filled AS (
    SELECT
        ds.sale_date,
        COALESCE(s.daily_revenue, 0) AS daily_revenue
    FROM date_spine ds
    LEFT JOIN daily_sales s ON ds.sale_date = s.order_date
)
SELECT
    sale_date,
    daily_revenue,
    SUM(daily_revenue) OVER (
        ORDER BY sale_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM filled
ORDER BY sale_date;
```
