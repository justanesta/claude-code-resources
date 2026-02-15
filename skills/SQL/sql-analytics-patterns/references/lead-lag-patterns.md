# Lead/Lag Patterns

## LAG and LEAD Basics

```sql
-- LAG: access previous row's value
-- LEAD: access next row's value
-- Syntax: LAG(column, offset, default) OVER (PARTITION BY ... ORDER BY ...)

SELECT
    order_date,
    daily_revenue,
    LAG(daily_revenue, 1)    OVER (ORDER BY order_date) AS prev_day_revenue,
    LEAD(daily_revenue, 1)   OVER (ORDER BY order_date) AS next_day_revenue,
    LAG(daily_revenue, 7)    OVER (ORDER BY order_date) AS same_day_last_week,
    LAG(daily_revenue, 1, 0) OVER (ORDER BY order_date) AS prev_day_or_zero  -- default value
FROM daily_sales
ORDER BY order_date;

-- Offset parameter: how many rows back (LAG) or forward (LEAD)
-- Default parameter: returned when offset goes beyond partition boundary
```

## Month-over-Month (MoM) Growth

```sql
-- Basic MoM revenue growth
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS revenue_month,
        SUM(order_total) AS monthly_revenue
    FROM orders
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    revenue_month,
    monthly_revenue,
    LAG(monthly_revenue) OVER (ORDER BY revenue_month) AS prev_month,
    monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY revenue_month) AS mom_change,
    ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY revenue_month))
        / NULLIF(LAG(monthly_revenue) OVER (ORDER BY revenue_month), 0), 2) AS mom_growth_pct
FROM monthly
ORDER BY revenue_month;

-- MoM growth per product category
WITH monthly_category AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS revenue_month,
        category,
        SUM(order_total) AS monthly_revenue
    FROM orders
    GROUP BY DATE_TRUNC('month', order_date), category
)
SELECT
    revenue_month,
    category,
    monthly_revenue,
    LAG(monthly_revenue) OVER (PARTITION BY category ORDER BY revenue_month) AS prev_month,
    ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue) OVER (
        PARTITION BY category ORDER BY revenue_month
    )) / NULLIF(LAG(monthly_revenue) OVER (
        PARTITION BY category ORDER BY revenue_month
    ), 0), 2) AS mom_growth_pct
FROM monthly_category
ORDER BY category, revenue_month;
```

## Year-over-Year (YoY) Growth

```sql
-- YoY growth: compare same month across years
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', order_date)::DATE AS revenue_month,
        EXTRACT(YEAR FROM order_date) AS year,
        EXTRACT(MONTH FROM order_date) AS month,
        SUM(order_total) AS monthly_revenue
    FROM orders
    GROUP BY DATE_TRUNC('month', order_date),
             EXTRACT(YEAR FROM order_date),
             EXTRACT(MONTH FROM order_date)
)
SELECT
    revenue_month,
    monthly_revenue AS current_revenue,
    LAG(monthly_revenue, 12) OVER (ORDER BY revenue_month) AS same_month_last_year,
    ROUND(100.0 * (monthly_revenue - LAG(monthly_revenue, 12) OVER (ORDER BY revenue_month))
        / NULLIF(LAG(monthly_revenue, 12) OVER (ORDER BY revenue_month), 0), 2) AS yoy_growth_pct
FROM monthly
ORDER BY revenue_month;

-- Alternative: use self-join when months may be missing
-- JOIN monthly prev ON curr.revenue_month = prev.revenue_month + INTERVAL '12 months'
```

## FIRST_VALUE and LAST_VALUE

```sql
-- FIRST_VALUE: get first value in the partition
SELECT
    employee_name,
    department,
    salary,
    FIRST_VALUE(employee_name) OVER (
        PARTITION BY department ORDER BY salary DESC
    ) AS highest_paid_in_dept,
    FIRST_VALUE(salary) OVER (
        PARTITION BY department ORDER BY salary DESC
    ) AS top_salary_in_dept,
    salary - FIRST_VALUE(salary) OVER (
        PARTITION BY department ORDER BY salary DESC
    ) AS gap_from_top
FROM employees;

-- LAST_VALUE requires explicit frame (default frame stops at CURRENT ROW)
SELECT
    employee_name,
    department,
    salary,
    LAST_VALUE(employee_name) OVER (
        PARTITION BY department ORDER BY salary DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS lowest_paid_in_dept,
    LAST_VALUE(salary) OVER (
        PARTITION BY department ORDER BY salary DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS bottom_salary_in_dept
FROM employees;

-- NTH_VALUE: get Nth value in partition
SELECT
    employee_name,
    department,
    salary,
    NTH_VALUE(employee_name, 2) OVER (
        PARTITION BY department ORDER BY salary DESC
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    ) AS second_highest_paid
FROM employees;
```

## Churn Detection and Retention

```sql
-- Identify churned customers (no order in 90+ days after previous order)
WITH customer_orders AS (
    SELECT
        customer_id,
        order_date,
        LEAD(order_date) OVER (
            PARTITION BY customer_id ORDER BY order_date
        ) AS next_order_date
    FROM orders
)
SELECT
    customer_id,
    order_date AS last_order_before_gap,
    next_order_date AS returned_on,
    COALESCE(next_order_date, CURRENT_DATE) - order_date AS days_until_next,
    CASE
        WHEN next_order_date IS NULL AND CURRENT_DATE - order_date > 90 THEN 'Churned'
        WHEN next_order_date - order_date > 90 THEN 'Returned after churn'
        ELSE 'Active'
    END AS status
FROM customer_orders
WHERE next_order_date IS NULL  -- Last known order
   OR next_order_date - order_date > 90  -- Gap > 90 days
ORDER BY days_until_next DESC;

-- SaaS subscription churn: detect downgrade and cancellation signals
WITH monthly_usage AS (
    SELECT
        account_id,
        usage_month,
        active_users,
        LAG(active_users) OVER (PARTITION BY account_id ORDER BY usage_month) AS prev_month_users,
        LAG(active_users, 3) OVER (PARTITION BY account_id ORDER BY usage_month) AS users_3m_ago
    FROM account_monthly_metrics
)
SELECT
    account_id,
    usage_month,
    active_users,
    prev_month_users,
    ROUND(100.0 * (active_users - prev_month_users)
        / NULLIF(prev_month_users, 0), 2) AS mom_user_change_pct,
    CASE
        WHEN active_users = 0 THEN 'Churned'
        WHEN active_users < prev_month_users * 0.5 THEN 'High Churn Risk'
        WHEN active_users < prev_month_users * 0.8 THEN 'Moderate Churn Risk'
        WHEN active_users < users_3m_ago * 0.7 THEN 'Declining Trend'
        ELSE 'Healthy'
    END AS health_status
FROM monthly_usage
WHERE prev_month_users IS NOT NULL
ORDER BY account_id, usage_month;
```

## Time-to-Event Calculations

```sql
-- Time between customer orders (inter-purchase interval)
SELECT
    customer_id,
    order_date,
    order_total,
    LAG(order_date) OVER w AS prev_order_date,
    order_date - LAG(order_date) OVER w AS days_since_last_order,
    ROW_NUMBER() OVER w AS order_number
FROM orders
WINDOW w AS (PARTITION BY customer_id ORDER BY order_date)
ORDER BY customer_id, order_date;

-- Average time between orders per customer
WITH order_intervals AS (
    SELECT
        customer_id,
        order_date - LAG(order_date) OVER (
            PARTITION BY customer_id ORDER BY order_date
        ) AS days_between
    FROM orders
)
SELECT
    customer_id,
    COUNT(*) AS interval_count,
    ROUND(AVG(days_between)::NUMERIC, 1) AS avg_days_between_orders,
    MIN(days_between) AS min_interval,
    MAX(days_between) AS max_interval
FROM order_intervals
WHERE days_between IS NOT NULL
GROUP BY customer_id
ORDER BY avg_days_between_orders;

-- Funnel conversion time: time from signup to first purchase
WITH first_events AS (
    SELECT
        user_id,
        MIN(CASE WHEN event_type = 'signup' THEN event_timestamp END) AS signup_time,
        MIN(CASE WHEN event_type = 'first_purchase' THEN event_timestamp END) AS first_purchase_time
    FROM user_events
    GROUP BY user_id
)
SELECT
    user_id,
    signup_time,
    first_purchase_time,
    EXTRACT(EPOCH FROM first_purchase_time - signup_time) / 3600.0 AS hours_to_convert,
    CASE
        WHEN first_purchase_time IS NULL THEN 'Never Converted'
        WHEN first_purchase_time - signup_time < INTERVAL '1 hour' THEN 'Immediate'
        WHEN first_purchase_time - signup_time < INTERVAL '1 day' THEN 'Same Day'
        WHEN first_purchase_time - signup_time < INTERVAL '7 days' THEN 'First Week'
        ELSE 'Delayed'
    END AS conversion_speed
FROM first_events
ORDER BY hours_to_convert NULLS LAST;
```

## Price and Value Change Tracking

```sql
-- Track product price changes
SELECT
    product_id,
    effective_date,
    price,
    LAG(price) OVER (PARTITION BY product_id ORDER BY effective_date) AS prev_price,
    price - LAG(price) OVER (PARTITION BY product_id ORDER BY effective_date) AS price_change,
    ROUND(100.0 * (price - LAG(price) OVER (PARTITION BY product_id ORDER BY effective_date))
        / NULLIF(LAG(price) OVER (PARTITION BY product_id ORDER BY effective_date), 0), 2)
        AS pct_change,
    CASE
        WHEN price > LAG(price) OVER (PARTITION BY product_id ORDER BY effective_date) THEN 'Increase'
        WHEN price < LAG(price) OVER (PARTITION BY product_id ORDER BY effective_date) THEN 'Decrease'
        ELSE 'No Change'
    END AS change_direction
FROM product_price_history
ORDER BY product_id, effective_date;

```

## Cross-Database Notes

```sql
-- LAG/LEAD/FIRST_VALUE/LAST_VALUE: identical syntax across PostgreSQL, MySQL 8.0+, SQL Server 2012+
LAG(salary, 1, 0) OVER (PARTITION BY dept ORDER BY hire_date)

-- NTH_VALUE: PostgreSQL and MySQL 8.0+ only (SQL Server 2022+)
```
