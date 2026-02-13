# Date and Time Operations

## Date Arithmetic

```sql
-- Add/subtract intervals
SELECT 
    order_date,
    
    -- PostgreSQL interval syntax
    order_date + INTERVAL '7 days' AS delivery_date,
    order_date + INTERVAL '1 month' AS one_month_later,
    order_date - INTERVAL '90 days' AS ninety_days_ago,
    order_date + INTERVAL '2 hours 30 minutes' AS time_offset,
    
    -- MySQL date arithmetic
    DATE_ADD(order_date, INTERVAL 7 DAY) AS delivery_date_mysql,
    DATE_SUB(order_date, INTERVAL 1 MONTH) AS one_month_ago_mysql,
    order_date + INTERVAL 7 DAY AS delivery_date_alt,
    
    -- SQL Server DATEADD
    DATEADD(day, 7, order_date) AS delivery_date_sqlserver,
    DATEADD(month, -1, order_date) AS one_month_ago_sqlserver,
    
    -- Calculate difference between dates
    AGE(CURRENT_DATE, order_date) AS order_age,  -- PostgreSQL
    CURRENT_DATE - order_date AS days_since_order,  -- Returns integer
    DATEDIFF(CURRENT_DATE, order_date) AS days_diff_mysql,  -- MySQL
    DATEDIFF(day, order_date, CURRENT_DATE) AS days_diff_sqlserver  -- SQL Server
FROM orders;

-- Calculate business days (excluding weekends)
SELECT 
    start_date,
    end_date,
    end_date - start_date AS calendar_days,
    -- Approximate business days (doesn't account for holidays)
    CASE 
        WHEN end_date - start_date <= 0 THEN 0
        ELSE 
            (end_date - start_date) / 7 * 5 +
            CASE 
                WHEN EXTRACT(DOW FROM end_date) >= EXTRACT(DOW FROM start_date)
                THEN EXTRACT(DOW FROM end_date) - EXTRACT(DOW FROM start_date)
                ELSE 5 + EXTRACT(DOW FROM end_date) - EXTRACT(DOW FROM start_date)
            END
    END AS business_days_approx
FROM date_ranges;
```

## Date Extraction and Components

```sql
-- Extract date parts
SELECT 
    order_date,
    created_at,
    
    -- Extract components (PostgreSQL, MySQL, SQL Server)
    EXTRACT(YEAR FROM order_date) AS year,
    EXTRACT(MONTH FROM order_date) AS month,
    EXTRACT(DAY FROM order_date) AS day,
    EXTRACT(DOW FROM order_date) AS day_of_week,  -- 0=Sunday, 6=Saturday
    EXTRACT(DOY FROM order_date) AS day_of_year,
    EXTRACT(WEEK FROM order_date) AS week_number,
    EXTRACT(QUARTER FROM order_date) AS quarter,
    
    -- Extract from timestamp
    EXTRACT(HOUR FROM created_at) AS hour,
    EXTRACT(MINUTE FROM created_at) AS minute,
    EXTRACT(SECOND FROM created_at) AS second,
    
    -- PostgreSQL DATE_PART (alternative syntax)
    DATE_PART('year', order_date) AS year_alt,
    DATE_PART('month', order_date) AS month_alt,
    
    -- MySQL specific
    YEAR(order_date) AS year_mysql,
    MONTH(order_date) AS month_mysql,
    DAY(order_date) AS day_mysql,
    DAYOFWEEK(order_date) AS dow_mysql,  -- 1=Sunday, 7=Saturday
    QUARTER(order_date) AS quarter_mysql,
    HOUR(created_at) AS hour_mysql,
    
    -- SQL Server specific
    YEAR(order_date) AS year_sqlserver,
    MONTH(order_date) AS month_sqlserver,
    DAY(order_date) AS day_sqlserver,
    DATEPART(weekday, order_date) AS dow_sqlserver
FROM orders;

-- Get date names
SELECT 
    order_date,
    TO_CHAR(order_date, 'Day') AS day_name,  -- 'Monday   '
    TO_CHAR(order_date, 'Dy') AS day_abbrev,  -- 'Mon'
    TO_CHAR(order_date, 'Month') AS month_name,  -- 'January  '
    TO_CHAR(order_date, 'Mon') AS month_abbrev,  -- 'Jan'
    
    -- MySQL
    DAYNAME(order_date) AS day_name_mysql,
    MONTHNAME(order_date) AS month_name_mysql
FROM orders;
```

## Date Truncation (for Grouping)

```sql
-- Truncate to different granularities
SELECT 
    created_at,
    
    -- PostgreSQL DATE_TRUNC
    DATE_TRUNC('second', created_at) AS truncated_second,
    DATE_TRUNC('minute', created_at) AS truncated_minute,
    DATE_TRUNC('hour', created_at) AS truncated_hour,
    DATE_TRUNC('day', created_at) AS truncated_day,
    DATE_TRUNC('week', created_at) AS truncated_week,  -- Monday
    DATE_TRUNC('month', created_at) AS truncated_month,  -- First of month
    DATE_TRUNC('quarter', created_at) AS truncated_quarter,
    DATE_TRUNC('year', created_at) AS truncated_year,  -- Jan 1
    
    -- MySQL DATE_FORMAT for truncation
    DATE_FORMAT(created_at, '%Y-%m-01') AS first_of_month_mysql,
    DATE_FORMAT(created_at, '%Y-01-01') AS first_of_year_mysql,
    
    -- SQL Server DATETRUNC (SQL Server 2022+)
    DATETRUNC(day, created_at) AS truncated_day_sqlserver,
    DATETRUNC(month, created_at) AS truncated_month_sqlserver,
    
    -- SQL Server alternative (older versions)
    CAST(created_at AS DATE) AS date_only,
    DATEADD(month, DATEDIFF(month, 0, created_at), 0) AS first_of_month_alt
FROM events;

-- Group by time periods
SELECT 
    DATE_TRUNC('month', order_date) AS month,
    COUNT(*) AS order_count,
    SUM(total_amount) AS revenue
FROM orders
WHERE order_date >= '2024-01-01'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY month;
```

## Date Formatting

```sql
-- Format dates as strings
SELECT 
    order_date,
    
    -- PostgreSQL TO_CHAR
    TO_CHAR(order_date, 'YYYY-MM-DD') AS iso_format,
    TO_CHAR(order_date, 'MM/DD/YYYY') AS us_format,
    TO_CHAR(order_date, 'DD-Mon-YYYY') AS date_with_month,
    TO_CHAR(order_date, 'Month DD, YYYY') AS readable_format,
    TO_CHAR(order_date, 'Day, Month DD, YYYY') AS full_format,
    TO_CHAR(order_date, 'FMMonth DD, YYYY') AS no_padding,  -- FM = Fill Mode off
    
    -- Timestamp formatting
    TO_CHAR(created_at, 'YYYY-MM-DD HH24:MI:SS') AS timestamp_24hr,
    TO_CHAR(created_at, 'MM/DD/YYYY HH:MI:SS AM') AS timestamp_12hr,
    
    -- MySQL DATE_FORMAT
    DATE_FORMAT(order_date, '%Y-%m-%d') AS iso_format_mysql,
    DATE_FORMAT(order_date, '%m/%d/%Y') AS us_format_mysql,
    DATE_FORMAT(order_date, '%M %d, %Y') AS readable_mysql,
    DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:%s') AS timestamp_mysql,
    
    -- SQL Server FORMAT
    FORMAT(order_date, 'yyyy-MM-dd') AS iso_format_sqlserver,
    FORMAT(order_date, 'MM/dd/yyyy') AS us_format_sqlserver,
    FORMAT(order_date, 'MMMM dd, yyyy') AS readable_sqlserver,
    FORMAT(created_at, 'yyyy-MM-dd HH:mm:ss') AS timestamp_sqlserver
FROM orders;
```

## Date/Time Parsing

```sql
-- Parse strings to dates
SELECT 
    date_string,
    
    -- PostgreSQL TO_DATE
    TO_DATE(date_string, 'MM/DD/YYYY') AS parsed_date,
    TO_DATE(date_string, 'DD-Mon-YYYY') AS parsed_date_alt,
    TO_TIMESTAMP(datetime_string, 'YYYY-MM-DD HH24:MI:SS') AS parsed_timestamp,
    
    -- MySQL STR_TO_DATE
    STR_TO_DATE(date_string, '%m/%d/%Y') AS parsed_mysql,
    STR_TO_DATE(datetime_string, '%Y-%m-%d %H:%i:%s') AS parsed_ts_mysql,
    
    -- SQL Server CONVERT with style codes
    CONVERT(DATE, date_string, 101) AS parsed_sqlserver,  -- 101 = MM/DD/YYYY
    CONVERT(DATETIME, datetime_string, 120) AS parsed_ts_sqlserver  -- 120 = YYYY-MM-DD HH:MI:SS
FROM staging_data;
```

## Current Date/Time Functions

```sql
-- Get current date and time
SELECT 
    -- Current date
    CURRENT_DATE AS today,  -- Standard SQL
    CURRENT_DATE() AS today_mysql,  -- MySQL
    
    -- Current timestamp
    CURRENT_TIMESTAMP AS now,  -- Standard SQL
    NOW() AS now_function,  -- PostgreSQL, MySQL
    GETDATE() AS now_sqlserver,  -- SQL Server
    
    -- Current time
    CURRENT_TIME AS current_time_only,
    LOCALTIME AS local_time,
    
    -- PostgreSQL clock functions
    CLOCK_TIMESTAMP() AS clock_now,  -- Changes within statement
    STATEMENT_TIMESTAMP() AS statement_now,
    TRANSACTION_TIMESTAMP() AS transaction_now,
    
    -- Unix timestamp
    EXTRACT(EPOCH FROM CURRENT_TIMESTAMP) AS unix_timestamp_pg,
    UNIX_TIMESTAMP() AS unix_timestamp_mysql,
    DATEDIFF(second, '1970-01-01', GETDATE()) AS unix_timestamp_sqlserver;
```

## Age Calculations

```sql
-- Calculate ages and durations
SELECT 
    customer_id,
    birth_date,
    created_date,
    
    -- PostgreSQL AGE function
    AGE(CURRENT_DATE, birth_date) AS age_interval,
    DATE_PART('year', AGE(CURRENT_DATE, birth_date)) AS age_years,
    
    -- Calculate age in years (cross-database)
    EXTRACT(YEAR FROM CURRENT_DATE) - EXTRACT(YEAR FROM birth_date) -
    CASE 
        WHEN EXTRACT(MONTH FROM CURRENT_DATE) < EXTRACT(MONTH FROM birth_date)
          OR (EXTRACT(MONTH FROM CURRENT_DATE) = EXTRACT(MONTH FROM birth_date)
              AND EXTRACT(DAY FROM CURRENT_DATE) < EXTRACT(DAY FROM birth_date))
        THEN 1
        ELSE 0
    END AS age_years_calculated,
    
    -- Days since account creation
    CURRENT_DATE - created_date AS days_since_registration,
    
    -- Account age in months (approximate)
    ROUND((CURRENT_DATE - created_date) / 30.0) AS months_since_registration,
    
    -- MySQL TIMESTAMPDIFF
    TIMESTAMPDIFF(YEAR, birth_date, CURRENT_DATE) AS age_years_mysql,
    TIMESTAMPDIFF(MONTH, created_date, CURRENT_DATE) AS months_since_mysql,
    
    -- SQL Server DATEDIFF
    DATEDIFF(year, birth_date, GETDATE()) AS age_years_sqlserver
FROM customers;
```

## Time Zone Handling

```sql
-- Work with time zones (PostgreSQL)
SELECT 
    created_at,
    
    -- Convert to different time zone
    created_at AT TIME ZONE 'UTC' AS created_utc,
    created_at AT TIME ZONE 'America/New_York' AS created_eastern,
    created_at AT TIME ZONE 'America/Los_Angeles' AS created_pacific,
    
    -- Get current time in specific time zone
    CURRENT_TIMESTAMP AT TIME ZONE 'UTC' AS now_utc,
    CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Tokyo' AS now_tokyo,
    
    -- Extract time zone
    EXTRACT(TIMEZONE FROM created_at) AS tz_offset_seconds
FROM events;

-- Store and display in local time zone
WITH utc_data AS (
    SELECT 
        event_id,
        event_timestamp AT TIME ZONE 'UTC' AS event_utc
    FROM events
)
SELECT 
    event_id,
    event_utc AT TIME ZONE 'America/New_York' AS event_eastern,
    event_utc AT TIME ZONE 'Europe/London' AS event_london
FROM utc_data;
```

## Fiscal Year and Periods

```sql
-- Calculate fiscal year (assuming Oct 1 start)
SELECT 
    order_date,
    CASE 
        WHEN EXTRACT(MONTH FROM order_date) >= 10 
        THEN EXTRACT(YEAR FROM order_date) + 1
        ELSE EXTRACT(YEAR FROM order_date)
    END AS fiscal_year,
    
    -- Fiscal quarter
    CASE 
        WHEN EXTRACT(MONTH FROM order_date) BETWEEN 10 AND 12 THEN 'Q1'
        WHEN EXTRACT(MONTH FROM order_date) BETWEEN 1 AND 3 THEN 'Q2'
        WHEN EXTRACT(MONTH FROM order_date) BETWEEN 4 AND 6 THEN 'Q3'
        WHEN EXTRACT(MONTH FROM order_date) BETWEEN 7 AND 9 THEN 'Q4'
    END AS fiscal_quarter,
    
    -- Week number (ISO week)
    EXTRACT(WEEK FROM order_date) AS iso_week,
    TO_CHAR(order_date, 'IYYY-IW') AS iso_year_week  -- 2024-W15
FROM orders;
```

## Date Series Generation

```sql
-- Generate series of dates (PostgreSQL)
SELECT 
    generate_series(
        '2024-01-01'::DATE,
        '2024-12-31'::DATE,
        '1 day'::INTERVAL
    )::DATE AS date;

-- Generate hourly timestamps
SELECT 
    generate_series(
        '2024-01-01 00:00:00'::TIMESTAMP,
        '2024-01-01 23:00:00'::TIMESTAMP,
        '1 hour'::INTERVAL
    ) AS hour;

-- Use in queries to fill gaps
WITH date_series AS (
    SELECT generate_series(
        '2024-01-01'::DATE,
        '2024-01-31'::DATE,
        '1 day'::INTERVAL
    )::DATE AS date
)
SELECT 
    ds.date,
    COALESCE(COUNT(o.order_id), 0) AS order_count,
    COALESCE(SUM(o.total_amount), 0) AS revenue
FROM date_series ds
LEFT JOIN orders o ON o.order_date = ds.date
GROUP BY ds.date
ORDER BY ds.date;
```

## Common Date Patterns

```sql
-- First and last day of month
SELECT 
    order_date,
    DATE_TRUNC('month', order_date) AS first_of_month,
    DATE_TRUNC('month', order_date) + INTERVAL '1 month' - INTERVAL '1 day' AS last_of_month,
    
    -- First day of year
    DATE_TRUNC('year', order_date) AS first_of_year,
    
    -- First day of quarter
    DATE_TRUNC('quarter', order_date) AS first_of_quarter;

-- Check if date is weekend
SELECT 
    order_date,
    CASE 
        WHEN EXTRACT(DOW FROM order_date) IN (0, 6) THEN TRUE
        ELSE FALSE
    END AS is_weekend,
    
    -- Check if first/last day of month
    order_date = DATE_TRUNC('month', order_date) AS is_first_of_month,
    order_date = DATE_TRUNC('month', order_date) + INTERVAL '1 month' - INTERVAL '1 day' AS is_last_of_month;

-- Relative date ranges
SELECT *
FROM orders
WHERE order_date >= CURRENT_DATE - INTERVAL '30 days'  -- Last 30 days
  AND order_date < CURRENT_DATE;

SELECT *
FROM orders
WHERE DATE_TRUNC('month', order_date) = DATE_TRUNC('month', CURRENT_DATE);  -- This month
```
