# NULL Handling

## COALESCE for Fallback Values

```sql
-- COALESCE returns first non-NULL value
SELECT 
    customer_id,
    customer_name,
    
    -- Provide fallback values
    COALESCE(email, 'no-email@example.com') AS email,
    COALESCE(phone_mobile, phone_home, phone_work, 'No Phone') AS primary_phone,
    COALESCE(discount_rate, 0.0) AS discount_rate,
    COALESCE(shipping_address, billing_address, 'Address Unknown') AS ship_to_address,
    
    -- Multiple fallbacks
    COALESCE(
        preferred_contact_email,
        work_email,
        personal_email,
        'no-contact@example.com'
    ) AS contact_email,
    
    -- Fallback to calculated value
    COALESCE(total_purchases, order_count * avg_order_value, 0) AS estimated_value
FROM customers;

-- COALESCE in arithmetic (NULL-safe calculations)
SELECT 
    product_id,
    price,
    quantity,
    tax_rate,
    
    -- Without COALESCE (NULLs propagate)
    price * quantity AS subtotal_nullable,  -- NULL if either is NULL
    
    -- With COALESCE (NULL-safe)
    COALESCE(price, 0) * COALESCE(quantity, 0) AS subtotal,
    COALESCE(price, 0) * COALESCE(quantity, 0) * (1 + COALESCE(tax_rate, 0)) AS total
FROM order_items;
```

## NULLIF to Convert Values to NULL

```sql
-- NULLIF(value1, value2) returns NULL if value1 = value2, otherwise value1
SELECT 
    product_id,
    
    -- Convert empty strings to NULL
    NULLIF(TRIM(description), '') AS description_clean,
    NULLIF(notes, '') AS notes_clean,
    
    -- Convert zero to NULL (useful for division)
    price / NULLIF(quantity, 0) AS price_per_unit,  -- Avoids divide by zero
    
    -- Convert specific values to NULL
    NULLIF(status, 'unknown') AS status_clean,
    NULLIF(country, 'N/A') AS country_clean,
    
    -- Combined with COALESCE
    COALESCE(
        NULLIF(TRIM(phone_mobile), ''),
        NULLIF(TRIM(phone_home), ''),
        'No Phone'
    ) AS phone_best
FROM products;

-- Use in WHERE clauses
SELECT *
FROM customers
WHERE NULLIF(TRIM(email), '') IS NOT NULL  -- Has non-empty email
  AND NULLIF(total_purchases, 0) IS NOT NULL;  -- Has made purchases
```

## NULL in Comparisons

```sql
-- NULL comparisons
SELECT 
    customer_id,
    email,
    phone,
    
    -- Standard NULL checks
    email IS NULL AS has_no_email,
    email IS NOT NULL AS has_email,
    
    -- NULL in equality (always returns NULL/FALSE)
    email = NULL AS wrong_check,  -- WRONG - always FALSE
    email != NULL AS still_wrong,  -- WRONG - always FALSE
    
    -- NULL-safe equality (PostgreSQL, MySQL)
    email IS NOT DISTINCT FROM NULL AS is_null_safe,  -- PostgreSQL
    email <=> NULL AS is_null_mysql,  -- MySQL
    
    -- Three-valued logic
    CASE 
        WHEN email IS NULL THEN 'NULL'
        WHEN email = 'test@example.com' THEN 'Test Email'
        ELSE 'Other'
    END AS email_category
FROM customers;

-- NULL in WHERE clauses
SELECT *
FROM orders
WHERE total_amount IS NOT NULL  -- Has value
  AND discount IS NULL  -- No discount applied
  AND (notes IS NULL OR notes = '');  -- No notes or empty notes
```

## NULL in Logical Operations

```sql
-- AND, OR, NOT with NULLs (three-valued logic)
SELECT 
    customer_id,
    is_active,
    is_verified,
    has_purchases,
    
    -- AND: NULL if any operand is NULL and no operand is FALSE
    is_active AND is_verified AS both_active_verified,
    
    -- OR: NULL if any operand is NULL and no operand is TRUE
    is_active OR is_verified AS either_active_verified,
    
    -- NOT: NULL becomes NULL
    NOT is_active AS not_active,
    
    -- Explicit NULL handling
    COALESCE(is_active, FALSE) AND COALESCE(is_verified, FALSE) AS both_true_or_false,
    is_active IS TRUE AND is_verified IS TRUE AS both_explicitly_true,
    
    -- IS TRUE / IS FALSE / IS UNKNOWN
    is_active IS TRUE AS definitely_active,
    is_active IS FALSE AS definitely_inactive,
    is_active IS NULL AS activity_unknown
FROM customers;
```

## NULL in Aggregations

```sql
-- Aggregates ignore NULLs (except COUNT(*))
SELECT 
    category,
    
    -- COUNT variations
    COUNT(*) AS total_rows,              -- Counts all rows
    COUNT(price) AS non_null_prices,     -- Counts non-NULL prices
    COUNT(DISTINCT price) AS unique_prices,  -- Counts unique non-NULL prices
    
    -- Other aggregates ignore NULLs
    AVG(price) AS avg_price,             -- Average of non-NULL values
    SUM(price) AS total_price,           -- Sum of non-NULL values
    MIN(price) AS min_price,             -- Min of non-NULL values
    MAX(price) AS max_price,             -- Max of non-NULL values
    
    -- Include NULLs in calculations
    AVG(COALESCE(price, 0)) AS avg_with_zeros,
    SUM(COALESCE(price, 0)) AS sum_with_zeros,
    
    -- Count NULLs specifically
    COUNT(*) - COUNT(price) AS null_count,
    COUNT(CASE WHEN price IS NULL THEN 1 END) AS null_count_alt,
    
    -- Percentage NULL
    ROUND(
        100.0 * (COUNT(*) - COUNT(price)) / NULLIF(COUNT(*), 0),
        2
    ) AS percent_null
FROM products
GROUP BY category;
```

## NULL in Sorting

```sql
-- NULL sort behavior (database-specific)
SELECT 
    customer_name,
    last_order_date
FROM customers
ORDER BY last_order_date;  
-- PostgreSQL: NULLs last by default (ascending)
-- MySQL: NULLs first by default
-- SQL Server: NULLs first by default

-- Explicit NULL positioning
SELECT *
FROM customers
ORDER BY last_order_date NULLS FIRST;  -- PostgreSQL

SELECT *
FROM customers
ORDER BY last_order_date NULLS LAST;   -- PostgreSQL

-- Simulate NULLS LAST in MySQL
SELECT *
FROM customers
ORDER BY last_order_date IS NULL, last_order_date;

-- Simulate NULLS FIRST in MySQL  
SELECT *
FROM customers
ORDER BY last_order_date IS NOT NULL, last_order_date;
```

## NULL-Safe Operations

```sql
-- Division by zero protection
SELECT 
    product_id,
    revenue,
    order_count,
    
    -- NULLIF prevents division by zero
    revenue / NULLIF(order_count, 0) AS avg_order_value,
    
    -- Combined with COALESCE for default
    COALESCE(revenue / NULLIF(order_count, 0), 0) AS avg_order_value_safe,
    
    -- CASE for more control
    CASE 
        WHEN order_count = 0 OR order_count IS NULL THEN 0
        ELSE revenue / order_count
    END AS avg_order_value_explicit
FROM product_stats;

-- String concatenation with NULLs
SELECT 
    first_name,
    last_name,
    middle_name,
    
    -- PostgreSQL || operator: NULL propagates
    first_name || ' ' || last_name AS full_name_nullable,  -- NULL if either is NULL
    
    -- CONCAT function: ignores NULLs
    CONCAT(first_name, ' ', last_name) AS full_name_safe,
    
    -- CONCAT_WS: ignores NULLs, uses separator
    CONCAT_WS(' ', first_name, middle_name, last_name) AS full_name_complete,
    
    -- Explicit NULL handling
    COALESCE(first_name, '') || ' ' || COALESCE(last_name, '') AS full_name_coalesce
FROM customers;
```

## Default Value Strategies

```sql
-- Different strategies for handling NULLs
WITH customer_data AS (
    SELECT 
        customer_id,
        email,
        phone,
        total_purchases,
        last_order_date
    FROM customers
)
SELECT 
    customer_id,
    
    -- Strategy 1: Replace with constant
    COALESCE(email, 'no-email@example.com') AS email_with_default,
    
    -- Strategy 2: Replace with calculated value
    COALESCE(
        total_purchases,
        (SELECT AVG(total_purchases) FROM customer_data WHERE total_purchases IS NOT NULL)
    ) AS purchases_with_avg,
    
    -- Strategy 3: Forward fill from related record
    COALESCE(
        phone,
        (SELECT phone FROM customer_phones WHERE customer_phones.customer_id = customer_data.customer_id LIMIT 1)
    ) AS phone_from_related,
    
    -- Strategy 4: Use previous non-NULL value (window function)
    COALESCE(
        total_purchases,
        LAST_VALUE(total_purchases IGNORE NULLS) OVER (
            ORDER BY customer_id 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        )
    ) AS purchases_forward_filled,
    
    -- Strategy 5: Mark as missing for later handling
    CASE 
        WHEN email IS NULL THEN 'MISSING'
        ELSE email
    END AS email_flagged
FROM customer_data;
```

## NULL in CASE Expressions

```sql
-- CASE with NULL handling
SELECT 
    customer_id,
    total_purchases,
    loyalty_tier,
    
    -- Explicit NULL handling in CASE
    CASE 
        WHEN total_purchases IS NULL THEN 'No Purchase History'
        WHEN total_purchases = 0 THEN 'Zero Purchases'
        WHEN total_purchases < 100 THEN 'Low Value'
        WHEN total_purchases < 1000 THEN 'Medium Value'
        ELSE 'High Value'
    END AS purchase_category,
    
    -- NULL in CASE conditions
    CASE 
        WHEN loyalty_tier IS NOT NULL AND loyalty_tier = 'Gold' THEN 'Gold Member'
        WHEN loyalty_tier IS NOT NULL THEN loyalty_tier
        WHEN total_purchases > 5000 THEN 'Unranked VIP'
        ELSE 'Standard'
    END AS member_status,
    
    -- COALESCE in CASE
    CASE COALESCE(loyalty_tier, 'None')
        WHEN 'Platinum' THEN 25
        WHEN 'Gold' THEN 15
        WHEN 'Silver' THEN 10
        ELSE 0
    END AS discount_percent
FROM customers;
```

## NULL Propagation in Expressions

```sql
-- Understanding NULL propagation
SELECT 
    price,
    quantity,
    tax_rate,
    
    -- Arithmetic: NULL propagates
    price * quantity AS subtotal,  -- NULL if either is NULL
    price + 10 AS price_plus_ten,  -- NULL if price is NULL
    
    -- String operations: Often propagate NULLs
    'Product: ' || description AS labeled,  -- NULL if description is NULL
    
    -- Comparison: Returns NULL (not TRUE or FALSE)
    price > 100 AS is_expensive,  -- NULL if price is NULL
    
    -- Functions: Usually propagate NULLs
    UPPER(description) AS desc_upper,  -- NULL if description is NULL
    LENGTH(notes) AS notes_length,  -- NULL if notes is NULL
    
    -- Some functions handle NULLs specially
    CONCAT(first_name, last_name) AS full_name,  -- Ignores NULLs
    GREATEST(price, COALESCE(discount_price, price)) AS best_price  -- GREATEST returns NULL if any arg is NULL
FROM products;
```

## Anti-Patterns

```sql
-- AVOID: Checking NULL with = or !=
SELECT *
FROM customers
WHERE email = NULL;  -- WRONG - always returns FALSE

-- CORRECT:
SELECT *
FROM customers
WHERE email IS NULL;

-- AVOID: Forgetting NULLs in NOT IN
SELECT *
FROM products
WHERE category_id NOT IN (SELECT category_id FROM excluded_categories);
-- If excluded_categories contains any NULL, returns 0 rows!

-- CORRECT:
SELECT *
FROM products
WHERE category_id NOT IN (
    SELECT category_id FROM excluded_categories WHERE category_id IS NOT NULL
);
-- Or use NOT EXISTS:
SELECT *
FROM products p
WHERE NOT EXISTS (
    SELECT 1 FROM excluded_categories e WHERE e.category_id = p.category_id
);

-- AVOID: Assuming COUNT(*) = COUNT(column)
SELECT COUNT(*) AS total FROM customers;  -- All rows
SELECT COUNT(email) AS has_email FROM customers;  -- Non-NULL emails only
-- These can be different!

-- CORRECT: Be explicit about what you're counting
SELECT 
    COUNT(*) AS total_customers,
    COUNT(email) AS customers_with_email,
    COUNT(*) - COUNT(email) AS customers_without_email
FROM customers;
```
