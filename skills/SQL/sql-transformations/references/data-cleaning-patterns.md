# Data Cleaning Patterns

## Validation and Quality Checks

```sql
-- Comprehensive data quality validation
WITH quality_checks AS (
    SELECT 
        customer_id,
        email,
        phone,
        country,
        -- Email validation
        CASE 
            WHEN email IS NULL THEN 'missing_email'
            WHEN email NOT LIKE '%@%' THEN 'invalid_email_format'
            WHEN email LIKE '%@%@%' THEN 'malformed_email'
            WHEN LENGTH(email) < 5 THEN 'email_too_short'
            ELSE 'valid_email'
        END AS email_status,
        -- Phone validation
        CASE 
            WHEN phone IS NULL THEN 'missing_phone'
            WHEN REGEXP_REPLACE(phone, '[^0-9]', '', 'g') !~ '^[0-9]{10}$' THEN 'invalid_phone_length'
            ELSE 'valid_phone'
        END AS phone_status,
        -- Country validation
        CASE 
            WHEN country IS NULL OR TRIM(country) = '' THEN 'missing_country'
            WHEN country NOT IN (SELECT code FROM valid_countries) THEN 'unknown_country'
            ELSE 'valid_country'
        END AS country_status
    FROM raw_customers
)
SELECT 
    email_status,
    phone_status,
    country_status,
    COUNT(*) AS record_count
FROM quality_checks
GROUP BY email_status, phone_status, country_status
ORDER BY record_count DESC;
```

## Standardization Patterns

```sql
-- Standardize common data formats
SELECT 
    customer_id,
    
    -- Email standardization
    LOWER(TRIM(email)) AS email_standardized,
    
    -- Country name standardization
    CASE 
        WHEN UPPER(TRIM(country)) IN ('US', 'USA', 'UNITED STATES', 'U.S.A.', 'U.S.') 
            THEN 'United States'
        WHEN UPPER(TRIM(country)) IN ('UK', 'UNITED KINGDOM', 'GREAT BRITAIN', 'GB', 'U.K.') 
            THEN 'United Kingdom'
        WHEN UPPER(TRIM(country)) IN ('CA', 'CAN', 'CANADA') 
            THEN 'Canada'
        WHEN TRIM(country) = '' OR country IS NULL
            THEN 'Unknown'
        ELSE INITCAP(TRIM(country))
    END AS country_standardized,
    
    -- Phone number standardization (US format)
    CASE 
        WHEN REGEXP_REPLACE(phone, '[^0-9]', '', 'g') ~ '^[0-9]{10}$' THEN
            '(' || SUBSTRING(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 1, 3) || ') ' ||
            SUBSTRING(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 4, 3) || '-' ||
            SUBSTRING(REGEXP_REPLACE(phone, '[^0-9]', '', 'g'), 7, 4)
        ELSE phone
    END AS phone_standardized,
    
    -- State abbreviation standardization
    CASE 
        WHEN UPPER(state) = 'CALIFORNIA' THEN 'CA'
        WHEN UPPER(state) = 'NEW YORK' THEN 'NY'
        WHEN UPPER(state) = 'TEXAS' THEN 'TX'
        WHEN LENGTH(TRIM(state)) = 2 THEN UPPER(TRIM(state))
        ELSE state
    END AS state_standardized,
    
    -- Currency code standardization
    CASE 
        WHEN UPPER(currency) IN ('USD', 'US$', '$', 'DOLLAR', 'DOLLARS') THEN 'USD'
        WHEN UPPER(currency) IN ('EUR', '€', 'EURO', 'EUROS') THEN 'EUR'
        WHEN UPPER(currency) IN ('GBP', '£', 'POUND', 'POUNDS') THEN 'GBP'
        ELSE UPPER(TRIM(currency))
    END AS currency_standardized
    
FROM raw_customers;
```

## Handling Missing and Invalid Data

```sql
-- Strategy 1: Replace with defaults
SELECT 
    customer_id,
    COALESCE(email, 'no-email@missing.com') AS email,
    COALESCE(country, 'Unknown') AS country,
    COALESCE(phone, 'No Phone') AS phone,
    COALESCE(discount_rate, 0.0) AS discount_rate,
    COALESCE(loyalty_points, 0) AS loyalty_points
FROM customers;

-- Strategy 2: Derive from related data
SELECT 
    o.order_id,
    o.customer_id,
    -- If shipping address missing, use billing address
    COALESCE(o.shipping_address, o.billing_address) AS shipping_address,
    COALESCE(o.shipping_city, o.billing_city) AS shipping_city,
    -- If customer name missing, derive from order
    COALESCE(c.customer_name, o.ship_to_name) AS customer_name
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id;

-- Strategy 3: Mark as invalid for review
SELECT 
    customer_id,
    email,
    CASE 
        WHEN email IS NULL THEN TRUE
        WHEN email NOT LIKE '%@%' THEN TRUE
        ELSE FALSE
    END AS needs_email_review,
    CASE 
        WHEN phone IS NULL THEN TRUE
        WHEN REGEXP_REPLACE(phone, '[^0-9]', '', 'g') !~ '^[0-9]{10}$' THEN TRUE
        ELSE FALSE
    END AS needs_phone_review
FROM customers;

-- Strategy 4: Filter out entirely
SELECT *
FROM customers
WHERE email IS NOT NULL
  AND email LIKE '%@%'
  AND created_date IS NOT NULL
  AND customer_name IS NOT NULL
  AND TRIM(customer_name) != '';
```

## Multi-Stage Cleaning Pipeline

```sql
-- Comprehensive cleaning with stages
WITH 
    -- Stage 1: Initial validation and filtering
    stage1_validated AS (
        SELECT *
        FROM raw_customer_imports
        WHERE email IS NOT NULL
          AND email LIKE '%@%'
          AND created_date IS NOT NULL
          AND created_date <= CURRENT_DATE
    ),
    
    -- Stage 2: Standardization
    stage2_standardized AS (
        SELECT 
            customer_id,
            LOWER(TRIM(email)) AS email,
            TRIM(REGEXP_REPLACE(customer_name, '\s+', ' ', 'g')) AS customer_name,
            CASE 
                WHEN UPPER(country) IN ('US', 'USA') THEN 'United States'
                WHEN UPPER(country) IN ('UK', 'GB') THEN 'United Kingdom'
                ELSE INITCAP(TRIM(country))
            END AS country,
            REGEXP_REPLACE(phone, '[^0-9]', '', 'g') AS phone_digits,
            created_date,
            COALESCE(total_purchases, 0.0) AS total_purchases
        FROM stage1_validated
    ),
    
    -- Stage 3: Deduplication
    stage3_deduplicated AS (
        SELECT DISTINCT ON (email)
            *,
            ROW_NUMBER() OVER (
                PARTITION BY email 
                ORDER BY created_date DESC, total_purchases DESC
            ) AS row_num
        FROM stage2_standardized
    ),
    
    -- Stage 4: Enrichment
    stage4_enriched AS (
        SELECT 
            s.*,
            c.country_code,
            c.region,
            CASE 
                WHEN s.total_purchases > 10000 THEN 'VIP'
                WHEN s.total_purchases > 1000 THEN 'Regular'
                ELSE 'New'
            END AS customer_tier
        FROM stage3_deduplicated s
        LEFT JOIN country_lookup c ON s.country = c.country_name
        WHERE row_num = 1
    )
    
SELECT 
    customer_id,
    email,
    customer_name,
    country,
    country_code,
    region,
    phone_digits AS phone,
    created_date,
    total_purchases,
    customer_tier
FROM stage4_enriched;
```

## Outlier Detection and Handling

```sql
-- Detect outliers using statistical methods
WITH stats AS (
    SELECT 
        AVG(order_amount) AS mean_amount,
        STDDEV(order_amount) AS stddev_amount,
        PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY order_amount) AS q1,
        PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY order_amount) AS q3
    FROM orders
),
outlier_detection AS (
    SELECT 
        o.*,
        s.mean_amount,
        s.stddev_amount,
        s.q3 - s.q1 AS iqr,
        -- Z-score method (±3 standard deviations)
        CASE 
            WHEN ABS(o.order_amount - s.mean_amount) > 3 * s.stddev_amount 
            THEN TRUE ELSE FALSE
        END AS is_outlier_zscore,
        -- IQR method (1.5 * IQR beyond quartiles)
        CASE 
            WHEN o.order_amount < s.q1 - 1.5 * (s.q3 - s.q1) 
              OR o.order_amount > s.q3 + 1.5 * (s.q3 - s.q1)
            THEN TRUE ELSE FALSE
        END AS is_outlier_iqr
    FROM orders o
    CROSS JOIN stats s
)
SELECT 
    order_id,
    order_amount,
    is_outlier_zscore,
    is_outlier_iqr,
    CASE 
        WHEN is_outlier_zscore OR is_outlier_iqr THEN 'Review Required'
        ELSE 'Normal'
    END AS status
FROM outlier_detection
WHERE is_outlier_zscore OR is_outlier_iqr;
```

## Data Quality Scoring

```sql
-- Assign data quality score to each record
SELECT 
    customer_id,
    email,
    phone,
    address,
    -- Calculate completeness score (0-100)
    (
        CASE WHEN email IS NOT NULL AND email LIKE '%@%' THEN 20 ELSE 0 END +
        CASE WHEN phone IS NOT NULL THEN 20 ELSE 0 END +
        CASE WHEN address IS NOT NULL AND TRIM(address) != '' THEN 20 ELSE 0 END +
        CASE WHEN city IS NOT NULL THEN 15 ELSE 0 END +
        CASE WHEN state IS NOT NULL THEN 15 ELSE 0 END +
        CASE WHEN postal_code IS NOT NULL THEN 10 ELSE 0 END
    ) AS quality_score,
    -- Categorize data quality
    CASE 
        WHEN (
            CASE WHEN email IS NOT NULL AND email LIKE '%@%' THEN 20 ELSE 0 END +
            CASE WHEN phone IS NOT NULL THEN 20 ELSE 0 END +
            CASE WHEN address IS NOT NULL AND TRIM(address) != '' THEN 20 ELSE 0 END +
            CASE WHEN city IS NOT NULL THEN 15 ELSE 0 END +
            CASE WHEN state IS NOT NULL THEN 15 ELSE 0 END +
            CASE WHEN postal_code IS NOT NULL THEN 10 ELSE 0 END
        ) >= 80 THEN 'High Quality'
        WHEN (
            CASE WHEN email IS NOT NULL AND email LIKE '%@%' THEN 20 ELSE 0 END +
            CASE WHEN phone IS NOT NULL THEN 20 ELSE 0 END +
            CASE WHEN address IS NOT NULL AND TRIM(address) != '' THEN 20 ELSE 0 END +
            CASE WHEN city IS NOT NULL THEN 15 ELSE 0 END +
            CASE WHEN state IS NOT NULL THEN 15 ELSE 0 END +
            CASE WHEN postal_code IS NOT NULL THEN 10 ELSE 0 END
        ) >= 50 THEN 'Medium Quality'
        ELSE 'Low Quality'
    END AS quality_tier
FROM customers;
```

## Fuzzy Matching for Data Cleanup

```sql
-- PostgreSQL with pg_trgm extension for fuzzy matching
-- Find potential duplicate company names
SELECT 
    c1.company_name AS name1,
    c2.company_name AS name2,
    SIMILARITY(c1.company_name, c2.company_name) AS similarity_score
FROM companies c1
CROSS JOIN companies c2
WHERE c1.company_id < c2.company_id
  AND SIMILARITY(c1.company_name, c2.company_name) > 0.6
ORDER BY similarity_score DESC;

-- Levenshtein distance for string similarity
SELECT 
    customer_name,
    LEVENSHTEIN(customer_name, 'John Smith') AS distance
FROM customers
WHERE LEVENSHTEIN(customer_name, 'John Smith') <= 3
ORDER BY distance;
```

## Audit Trail for Data Changes

```sql
-- Track what was cleaned and changed
WITH before_cleaning AS (
    SELECT 
        customer_id,
        email AS original_email,
        country AS original_country,
        phone AS original_phone
    FROM raw_customers
),
after_cleaning AS (
    SELECT 
        customer_id,
        LOWER(TRIM(email)) AS cleaned_email,
        CASE WHEN UPPER(country) = 'US' THEN 'United States' ELSE country END AS cleaned_country,
        REGEXP_REPLACE(phone, '[^0-9]', '', 'g') AS cleaned_phone
    FROM raw_customers
)
SELECT 
    b.customer_id,
    b.original_email,
    a.cleaned_email,
    CASE WHEN b.original_email != a.cleaned_email THEN TRUE ELSE FALSE END AS email_changed,
    b.original_country,
    a.cleaned_country,
    CASE WHEN b.original_country != a.cleaned_country THEN TRUE ELSE FALSE END AS country_changed,
    b.original_phone,
    a.cleaned_phone,
    CASE WHEN b.original_phone != a.cleaned_phone THEN TRUE ELSE FALSE END AS phone_changed
FROM before_cleaning b
INNER JOIN after_cleaning a ON b.customer_id = a.customer_id
WHERE b.original_email != a.cleaned_email
   OR b.original_country != a.cleaned_country
   OR b.original_phone != a.cleaned_phone;
```
