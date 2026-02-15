# Moving Averages and Sliding Windows

## Simple Moving Average (SMA)

```sql
-- 7-day simple moving average
SELECT
    sale_date,
    daily_revenue,
    AVG(daily_revenue) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS sma_7d,
    AVG(daily_revenue) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 29 PRECEDING AND CURRENT ROW
    ) AS sma_30d
FROM daily_sales
ORDER BY sale_date;

-- SMA with minimum period check (avoid incomplete windows)
SELECT
    sale_date,
    daily_revenue,
    CASE
        WHEN COUNT(*) OVER (
            ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        ) = 7
        THEN AVG(daily_revenue) OVER (
            ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
        )
        ELSE NULL
    END AS sma_7d_strict
FROM daily_sales
ORDER BY sale_date;
```

## ROWS vs RANGE: Critical Difference for Moving Averages

```sql
-- ROWS counts physical rows (use this for standard moving averages)
SELECT
    sale_date,
    daily_revenue,
    AVG(daily_revenue) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS avg_rows_7
FROM daily_sales;
-- Always includes exactly 7 rows (or fewer at start)

-- RANGE uses logical value ranges (groups ties together)
SELECT
    sale_date,
    daily_revenue,
    AVG(daily_revenue) OVER (
        ORDER BY sale_date
        RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW
    ) AS avg_range_7d
FROM daily_sales;
-- Includes all rows within 7 calendar days
-- Handles missing dates correctly (skips gaps)

-- When dates have duplicates, ROWS and RANGE differ significantly:
-- If 2024-01-15 has 3 rows:
--   ROWS BETWEEN 6 PRECEDING: counts those as 3 of the 7 physical rows
--   RANGE BETWEEN 6 DAYS PRECEDING: includes all rows from Jan 9-15
```

## Sliding Window Aggregates

```sql
-- Rolling min, max, sum over 7 days
SELECT
    sale_date,
    daily_revenue,
    MIN(daily_revenue) OVER w AS rolling_min_7d,
    MAX(daily_revenue) OVER w AS rolling_max_7d,
    SUM(daily_revenue) OVER w AS rolling_sum_7d,
    AVG(daily_revenue) OVER w AS rolling_avg_7d,
    COUNT(*)            OVER w AS rolling_count_7d
FROM daily_sales
WINDOW w AS (ORDER BY sale_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
ORDER BY sale_date;

-- Rolling standard deviation (volatility measure)
SELECT
    trade_date,
    close_price,
    AVG(close_price) OVER w AS avg_20d,
    STDDEV(close_price) OVER w AS stddev_20d,
    -- Bollinger Bands
    AVG(close_price) OVER w + 2 * STDDEV(close_price) OVER w AS upper_band,
    AVG(close_price) OVER w - 2 * STDDEV(close_price) OVER w AS lower_band
FROM stock_prices
WHERE ticker = 'ACME'
WINDOW w AS (ORDER BY trade_date ROWS BETWEEN 19 PRECEDING AND CURRENT ROW)
ORDER BY trade_date;
```

## Weighted Moving Average

```sql
-- Linearly weighted moving average (recent values weighted more)
-- For a 5-day WMA: weights are 5, 4, 3, 2, 1 (sum = 15)
WITH numbered AS (
    SELECT
        sale_date,
        daily_revenue,
        ROW_NUMBER() OVER (ORDER BY sale_date) AS rn
    FROM daily_sales
),
with_weights AS (
    SELECT
        a.sale_date,
        a.daily_revenue,
        b.daily_revenue AS window_revenue,
        a.rn - b.rn AS days_back,
        5 - (a.rn - b.rn) AS weight  -- 5 for current, 4 for t-1, etc.
    FROM numbered a
    INNER JOIN numbered b
        ON b.rn BETWEEN a.rn - 4 AND a.rn
)
SELECT
    sale_date,
    MAX(daily_revenue) AS daily_revenue,
    ROUND(SUM(window_revenue * weight)::NUMERIC / SUM(weight), 2) AS wma_5d
FROM with_weights
GROUP BY sale_date
ORDER BY sale_date;

-- Exponential moving average approximation using recursive CTE (PostgreSQL)
WITH RECURSIVE daily AS (
    SELECT
        sale_date,
        daily_revenue,
        ROW_NUMBER() OVER (ORDER BY sale_date) AS rn
    FROM daily_sales
),
ema AS (
    -- Base case: first row
    SELECT
        rn,
        sale_date,
        daily_revenue,
        daily_revenue AS ema_value
    FROM daily
    WHERE rn = 1

    UNION ALL

    -- Recursive case: EMA = alpha * current + (1 - alpha) * previous_ema
    -- alpha = 2 / (N + 1), for 10-day EMA: alpha = 2/11 = 0.1818
    SELECT
        d.rn,
        d.sale_date,
        d.daily_revenue,
        ROUND((0.1818 * d.daily_revenue + 0.8182 * e.ema_value)::NUMERIC, 2) AS ema_value
    FROM daily d
    INNER JOIN ema e ON d.rn = e.rn + 1
)
SELECT sale_date, daily_revenue, ema_value AS ema_10d
FROM ema
ORDER BY sale_date;
```

## Centered Moving Average

```sql
-- Centered moving average (for seasonal decomposition)
-- Useful for identifying trends by smoothing seasonality
SELECT
    sale_date,
    daily_revenue,
    AVG(daily_revenue) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 3 PRECEDING AND 3 FOLLOWING
    ) AS centered_ma_7d
FROM daily_sales
ORDER BY sale_date;

-- Even-window centered MA (e.g., 12-month) requires two passes:
-- first average over ROWS BETWEEN 5 PRECEDING AND 6 FOLLOWING,
-- then average adjacent results to center the window.
```

## Handling Gaps in Time Series

```sql
-- Problem: gaps in dates cause incorrect ROWS-based moving averages
-- Solution 1: Fill gaps with a date spine
WITH date_spine AS (
    SELECT generate_series(
        '2024-01-01'::DATE,
        '2024-12-31'::DATE,
        '1 day'::INTERVAL
    )::DATE AS sale_date
),
filled AS (
    SELECT
        ds.sale_date,
        COALESCE(s.daily_revenue, 0) AS daily_revenue,
        CASE WHEN s.sale_date IS NOT NULL THEN 1 ELSE 0 END AS has_data
    FROM date_spine ds
    LEFT JOIN daily_sales s ON ds.sale_date = s.sale_date
)
SELECT
    sale_date,
    daily_revenue,
    has_data,
    AVG(daily_revenue) OVER (
        ORDER BY sale_date
        ROWS BETWEEN 6 PRECEDING AND CURRENT ROW
    ) AS sma_7d_with_gaps_filled
FROM filled
ORDER BY sale_date;

-- Solution 2: Use RANGE frame with date interval (PostgreSQL)
SELECT
    sale_date,
    daily_revenue,
    AVG(daily_revenue) OVER (
        ORDER BY sale_date
        RANGE BETWEEN INTERVAL '6 days' PRECEDING AND CURRENT ROW
    ) AS sma_7_calendar_days
FROM daily_sales
ORDER BY sale_date;
-- Automatically handles missing dates by using calendar logic

-- Solution 3: Carry forward last known value (LOCF)
-- Use MAX(sale_date) OVER (ORDER BY date) to find last known date, then join back
```

## Moving Average for Business KPIs

```sql
-- SaaS metrics: 7-day rolling active users and revenue per user
WITH daily_metrics AS (
    SELECT
        activity_date,
        COUNT(DISTINCT user_id) AS daily_active_users,
        SUM(revenue) AS daily_revenue
    FROM user_activity
    GROUP BY activity_date
)
SELECT
    activity_date,
    daily_active_users,
    daily_revenue,
    AVG(daily_active_users) OVER w AS avg_dau_7d,
    AVG(daily_revenue) OVER w AS avg_revenue_7d,
    CASE
        WHEN AVG(daily_active_users) OVER w > 0
        THEN ROUND(AVG(daily_revenue) OVER w / AVG(daily_active_users) OVER w, 2)
        ELSE 0
    END AS arpu_7d
FROM daily_metrics
WINDOW w AS (ORDER BY activity_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
ORDER BY activity_date;

-- E-commerce: rolling conversion rate
WITH daily_funnel AS (
    SELECT
        event_date,
        COUNT(DISTINCT CASE WHEN event_type = 'visit' THEN session_id END) AS visits,
        COUNT(DISTINCT CASE WHEN event_type = 'purchase' THEN session_id END) AS purchases
    FROM web_events
    GROUP BY event_date
)
SELECT
    event_date,
    visits,
    purchases,
    ROUND(100.0 * purchases / NULLIF(visits, 0), 2) AS daily_conversion_rate,
    ROUND(100.0 *
        SUM(purchases) OVER w / NULLIF(SUM(visits) OVER w, 0), 2
    ) AS rolling_conversion_rate_7d
FROM daily_funnel
WINDOW w AS (ORDER BY event_date ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)
ORDER BY event_date;
```

## Cross-Database Notes

```sql
-- PostgreSQL: RANGE with interval supported
AVG(val) OVER (ORDER BY dt RANGE BETWEEN INTERVAL '7 days' PRECEDING AND CURRENT ROW)

-- MySQL 8.0+ / SQL Server 2012+: use ROWS (RANGE with interval not supported)
AVG(val) OVER (ORDER BY dt ROWS BETWEEN 6 PRECEDING AND CURRENT ROW)

-- SQL Server pre-2012: use correlated subquery
SELECT a.sale_date,
    (SELECT AVG(b.daily_revenue) FROM daily_sales b
     WHERE b.sale_date BETWEEN DATEADD(day, -6, a.sale_date) AND a.sale_date) AS sma_7d
FROM daily_sales a;
```
