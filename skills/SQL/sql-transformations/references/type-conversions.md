# Type Conversions

## String to Numeric Conversions

```sql
-- Safe string to numeric conversion
SELECT 
    product_id,
    price_string,
    -- PostgreSQL: Safe conversion with validation
    CASE 
        WHEN price_string ~ '^[0-9]+\.?[0-9]*$' 
        THEN price_string::NUMERIC(10,2)
        ELSE NULL
    END AS price_numeric,
    
    -- Alternative with TRY_CAST (SQL Server, PostgreSQL 13+)
    TRY_CAST(price_string AS NUMERIC(10,2)) AS price_safe,
    
    -- Remove non-numeric characters before conversion
    CAST(REGEXP_REPLACE(price_string, '[^0-9.]', '', 'g') AS NUMERIC(10,2)) AS price_cleaned,
    
    -- Handle currency symbols
    CAST(REPLACE(REPLACE(price_string, '$', ''), ',', '') AS NUMERIC(10,2)) AS price_from_currency
FROM staging_products;

-- Integer conversions
SELECT 
    -- String to integer
    CAST(quantity_str AS INTEGER) AS quantity_int,
    quantity_str::INTEGER AS quantity_int_alt,  -- PostgreSQL shorthand
    
    -- Round then convert
    CAST(ROUND(price_decimal) AS INTEGER) AS price_rounded,
    
    -- Floor/Ceiling conversions
    CAST(FLOOR(price) AS INTEGER) AS price_floor,
    CAST(CEILING(price) AS INTEGER) AS price_ceiling
FROM products;

-- Handle thousand separators and decimals
SELECT 
    '1,234.56' AS original,
    CAST(REPLACE('1,234.56', ',', '') AS NUMERIC(10,2)) AS converted;
```

## String to Date/Timestamp Conversions

```sql
-- Various date string formats to DATE
SELECT 
    -- ISO format (recommended)
    CAST('2024-01-15' AS DATE) AS date_iso,
    '2024-01-15'::DATE AS date_iso_pg,  -- PostgreSQL
    
    -- TO_DATE with format string (PostgreSQL, Oracle)
    TO_DATE('01/15/2024', 'MM/DD/YYYY') AS date_us_format,
    TO_DATE('15-01-2024', 'DD-MM-YYYY') AS date_eu_format,
    TO_DATE('January 15, 2024', 'Month DD, YYYY') AS date_text,
    
    -- MySQL date parsing
    STR_TO_DATE('01/15/2024', '%m/%d/%Y') AS date_mysql,
    
    -- SQL Server
    CONVERT(DATE, '01/15/2024', 101) AS date_sqlserver,  -- 101 = MM/DD/YYYY
    
    -- Safe conversion with validation
    CASE 
        WHEN date_string ~ '^\d{4}-\d{2}-\d{2}$'
        THEN date_string::DATE
        ELSE NULL
    END AS date_validated;

-- Timestamp conversions
SELECT 
    -- String to timestamp
    CAST('2024-01-15 14:30:00' AS TIMESTAMP) AS ts,
    TO_TIMESTAMP('2024-01-15 14:30:00', 'YYYY-MM-DD HH24:MI:SS') AS ts_formatted,
    
    -- Unix timestamp to timestamp
    TO_TIMESTAMP(1705329000) AS ts_from_unix,  -- PostgreSQL
    FROM_UNIXTIME(1705329000) AS ts_from_unix_mysql,
    
    -- Timestamp to date
    CAST(created_timestamp AS DATE) AS created_date,
    DATE(created_timestamp) AS created_date_alt;

-- Handle different date formats dynamically
SELECT 
    CASE 
        WHEN date_str ~ '^\d{4}-\d{2}-\d{2}$' 
            THEN TO_DATE(date_str, 'YYYY-MM-DD')
        WHEN date_str ~ '^\d{2}/\d{2}/\d{4}$' 
            THEN TO_DATE(date_str, 'MM/DD/YYYY')
        WHEN date_str ~ '^\d{2}-\d{2}-\d{4}$' 
            THEN TO_DATE(date_str, 'DD-MM-YYYY')
        ELSE NULL
    END AS parsed_date
FROM staging_data;
```

## Numeric to String Conversions

```sql
-- Number to string with formatting
SELECT 
    product_id,
    price,
    
    -- Basic conversion
    CAST(price AS VARCHAR) AS price_string,
    price::TEXT AS price_text,  -- PostgreSQL
    
    -- Format with specific decimal places
    TO_CHAR(price, '9999.99') AS price_formatted,
    TO_CHAR(price, '$9,999.99') AS price_currency,
    FORMAT('%.2f', price) AS price_decimal_places,
    
    -- Pad with leading zeros
    LPAD(product_id::TEXT, 8, '0') AS product_id_padded,
    
    -- Round before converting
    CAST(ROUND(price, 2) AS VARCHAR) AS price_rounded_str
FROM products;

-- Special numeric formats
SELECT 
    12345.67 AS amount,
    TO_CHAR(12345.67, '999,999.99') AS formatted_comma,
    TO_CHAR(12345.67, '$999,999.99') AS formatted_currency,
    TO_CHAR(0.85, '99%') AS formatted_percent;
```

## Boolean Conversions

```sql
-- String to boolean
SELECT 
    CASE 
        WHEN UPPER(active_str) IN ('TRUE', 'YES', 'Y', '1', 'T') THEN TRUE
        WHEN UPPER(active_str) IN ('FALSE', 'NO', 'N', '0', 'F') THEN FALSE
        ELSE NULL
    END AS active_boolean,
    
    -- PostgreSQL specific
    CAST(CASE WHEN active_str = '1' THEN 'true' ELSE 'false' END AS BOOLEAN) AS active_bool;

-- Numeric to boolean
SELECT 
    CASE WHEN is_active_num = 1 THEN TRUE ELSE FALSE END AS is_active,
    is_active_num::BOOLEAN AS is_active_direct;  -- 0=false, non-zero=true

-- Boolean to string/numeric
SELECT 
    is_active,
    CASE WHEN is_active THEN 'Yes' ELSE 'No' END AS is_active_str,
    CASE WHEN is_active THEN 1 ELSE 0 END AS is_active_num,
    CAST(is_active AS INTEGER) AS is_active_int;  -- TRUE=1, FALSE=0
```

## JSON and Array Conversions

```sql
-- JSON to structured data (PostgreSQL)
SELECT 
    order_id,
    json_data,
    
    -- Extract JSON fields
    json_data->>'customer_id' AS customer_id_str,
    (json_data->>'customer_id')::INTEGER AS customer_id,
    (json_data->>'total')::NUMERIC(10,2) AS total,
    (json_data->>'order_date')::DATE AS order_date,
    
    -- Extract nested JSON
    json_data->'items'->0->>'product_id' AS first_product_id,
    
    -- JSON array to rows
    jsonb_array_elements_text(json_data->'tags') AS tag
FROM orders_json;

-- Structured data to JSON
SELECT 
    jsonb_build_object(
        'customer_id', customer_id,
        'email', email,
        'total_orders', total_orders
    ) AS customer_json
FROM customers;

-- Array operations
SELECT 
    product_id,
    tags,  -- text[] array
    
    -- Array to string
    ARRAY_TO_STRING(tags, ', ') AS tags_string,
    
    -- String to array
    STRING_TO_ARRAY('red,blue,green', ',') AS colors_array,
    
    -- Array elements
    tags[1] AS first_tag,
    CARDINALITY(tags) AS tag_count
FROM products;
```

## Cross-Database Type Conversion Syntax

```sql
-- PostgreSQL
SELECT 
    price::NUMERIC(10,2) AS price_numeric,
    date_str::DATE AS date_converted,
    value::INTEGER AS value_int;

-- MySQL
SELECT 
    CAST(price AS DECIMAL(10,2)) AS price_numeric,
    CAST(date_str AS DATE) AS date_converted,
    CAST(value AS SIGNED) AS value_int;

-- SQL Server
SELECT 
    CAST(price AS DECIMAL(10,2)) AS price_numeric,
    CONVERT(DECIMAL(10,2), price) AS price_numeric_alt,
    CAST(date_str AS DATE) AS date_converted,
    CAST(value AS INT) AS value_int;

-- Safe conversions (SQL Server)
SELECT 
    TRY_CAST(price_str AS DECIMAL(10,2)) AS price_safe,
    TRY_CONVERT(DATE, date_str) AS date_safe,
    TRY_PARSE(json_str AS JSON) AS json_safe;
```

## Handling NULL in Conversions

```sql
-- NULL-safe conversions
SELECT 
    product_id,
    
    -- Convert NULL to specific value
    COALESCE(CAST(price_str AS NUMERIC), 0.0) AS price,
    COALESCE(quantity_str::INTEGER, 0) AS quantity,
    
    -- Only convert non-NULL values
    CASE 
        WHEN price_str IS NOT NULL 
        THEN CAST(price_str AS NUMERIC(10,2))
        ELSE NULL
    END AS price_converted,
    
    -- NULLIF to convert value to NULL
    NULLIF(CAST(discount_str AS NUMERIC), 0) AS discount_non_zero
FROM staging_products;
```

## Data Type Size Conversions

```sql
-- Numeric precision conversions
SELECT 
    price,
    CAST(price AS NUMERIC(10,2)) AS price_precise,  -- 10 digits, 2 decimals
    CAST(price AS NUMERIC(5,0)) AS price_rounded,   -- Integer, 5 digits
    CAST(price AS REAL) AS price_float,  -- Floating point
    CAST(price AS DOUBLE PRECISION) AS price_double;

-- String length conversions
SELECT 
    long_text,
    CAST(long_text AS VARCHAR(100)) AS text_truncated,
    LEFT(long_text, 100) AS text_limited,
    SUBSTRING(long_text, 1, 100) AS text_substr;
```

## Error Handling in Conversions

```sql
-- PostgreSQL: Handle conversion errors
WITH conversion_attempts AS (
    SELECT 
        price_string,
        CASE 
            WHEN price_string ~ '^[0-9]+\.?[0-9]*$' 
            THEN price_string::NUMERIC
            ELSE NULL
        END AS price_converted,
        CASE 
            WHEN price_string ~ '^[0-9]+\.?[0-9]*$' 
            THEN FALSE
            ELSE TRUE
        END AS conversion_failed
    FROM staging_data
)
SELECT * FROM conversion_attempts
WHERE conversion_failed = TRUE;  -- Review failed conversions

-- SQL Server: Use TRY_CAST for safe conversion
SELECT 
    price_string,
    TRY_CAST(price_string AS DECIMAL(10,2)) AS price,
    CASE 
        WHEN TRY_CAST(price_string AS DECIMAL(10,2)) IS NULL 
        THEN 'Conversion Failed'
        ELSE 'Success'
    END AS status
FROM staging_data;
```
