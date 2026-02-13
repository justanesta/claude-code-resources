# Deduplication Strategies

## Finding Duplicates

```sql
-- Identify duplicate records by key columns
SELECT 
    email,
    COUNT(*) AS duplicate_count,
    STRING_AGG(customer_id::TEXT, ', ' ORDER BY created_date DESC) AS customer_ids,
    MIN(created_date) AS earliest_record,
    MAX(created_date) AS latest_record
FROM customers
GROUP BY email
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC, email;

-- Find duplicates across multiple columns
SELECT 
    first_name,
    last_name,
    birth_date,
    COUNT(*) AS duplicate_count,
    ARRAY_AGG(customer_id ORDER BY created_date DESC) AS ids
FROM customers
GROUP BY first_name, last_name, birth_date
HAVING COUNT(*) > 1;

-- Find exact duplicate rows (all columns)
SELECT 
    email,
    phone,
    address,
    COUNT(*) AS row_count
FROM customers
GROUP BY email, phone, address
HAVING COUNT(*) > 1;

-- Identify fuzzy duplicates (similar but not exact)
SELECT 
    c1.customer_id AS id1,
    c2.customer_id AS id2,
    c1.customer_name AS name1,
    c2.customer_name AS name2,
    SIMILARITY(c1.customer_name, c2.customer_name) AS name_similarity,
    c1.email AS email1,
    c2.email AS email2
FROM customers c1
CROSS JOIN customers c2
WHERE c1.customer_id < c2.customer_id
  AND (
      SIMILARITY(c1.customer_name, c2.customer_name) > 0.8
      OR c1.email = c2.email
      OR c1.phone = c2.phone
  )
ORDER BY name_similarity DESC;
```

## Remove Duplicates - Keep First/Last

```sql
-- Keep most recent record (PostgreSQL DISTINCT ON)
SELECT DISTINCT ON (email)
    customer_id,
    email,
    customer_name,
    created_date,
    total_purchases
FROM customers
ORDER BY email, created_date DESC;  -- Keep latest by created_date

-- Keep record with highest value
SELECT DISTINCT ON (email)
    *
FROM customers
ORDER BY email, total_purchases DESC NULLS LAST, created_date DESC;

-- Using ROW_NUMBER (works across all databases)
WITH ranked AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY email 
            ORDER BY created_date DESC, total_purchases DESC NULLS LAST
        ) AS rn
    FROM customers
)
SELECT 
    customer_id,
    email,
    customer_name,
    created_date,
    total_purchases
FROM ranked
WHERE rn = 1;

-- Keep first record by insertion order
WITH ranked AS (
    SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY email 
            ORDER BY customer_id ASC  -- Assuming customer_id is sequential
        ) AS rn
    FROM customers
)
SELECT * FROM ranked WHERE rn = 1;
```

## Remove Duplicates - Aggregate/Merge

```sql
-- Merge duplicate records by taking best value from each
WITH duplicates AS (
    SELECT 
        email,
        MIN(customer_id) AS primary_id,  -- Keep lowest ID as primary
        MAX(customer_name) AS customer_name,  -- Take longest name
        MAX(phone) AS phone,  -- Take non-NULL phone
        MAX(last_order_date) AS last_order_date,  -- Most recent order
        SUM(total_purchases) AS total_purchases,  -- Sum all purchases
        COUNT(*) AS merge_count
    FROM customers
    GROUP BY email
)
SELECT 
    primary_id,
    email,
    customer_name,
    phone,
    last_order_date,
    total_purchases,
    merge_count
FROM duplicates;

-- Merge with preference for non-NULL values
WITH duplicates AS (
    SELECT 
        email,
        MIN(customer_id) AS primary_id,
        -- Take first non-NULL value
        MAX(CASE WHEN customer_name IS NOT NULL THEN customer_name END) AS customer_name,
        MAX(CASE WHEN phone IS NOT NULL THEN phone END) AS phone,
        MAX(CASE WHEN address IS NOT NULL THEN address END) AS address,
        -- Aggregate numeric values
        MAX(last_order_date) AS last_order_date,
        SUM(COALESCE(total_purchases, 0)) AS total_purchases,
        -- Track merged IDs
        ARRAY_AGG(customer_id ORDER BY created_date) AS merged_ids,
        COUNT(*) AS merged_count
    FROM customers
    GROUP BY email
    HAVING COUNT(*) > 1
)
SELECT * FROM duplicates;
```

## Deduplication with CTE Pipeline

```sql
-- Multi-stage deduplication process
WITH 
    -- Stage 1: Identify duplicate groups
    duplicate_groups AS (
        SELECT 
            email,
            COUNT(*) AS dup_count,
            ARRAY_AGG(customer_id ORDER BY created_date DESC) AS customer_ids
        FROM customers
        WHERE email IS NOT NULL
        GROUP BY email
        HAVING COUNT(*) > 1
    ),
    
    -- Stage 2: Rank within each duplicate group
    ranked_duplicates AS (
        SELECT 
            c.*,
            dg.dup_count,
            ROW_NUMBER() OVER (
                PARTITION BY c.email 
                ORDER BY 
                    c.total_purchases DESC NULLS LAST,
                    c.created_date DESC,
                    c.customer_id ASC
            ) AS rn
        FROM customers c
        INNER JOIN duplicate_groups dg ON c.email = dg.email
    ),
    
    -- Stage 3: Select primary record
    primary_records AS (
        SELECT * 
        FROM ranked_duplicates 
        WHERE rn = 1
    ),
    
    -- Stage 4: Get unique records (no duplicates)
    unique_records AS (
        SELECT c.*
        FROM customers c
        LEFT JOIN duplicate_groups dg ON c.email = dg.email
        WHERE dg.email IS NULL
    )

-- Stage 5: Combine primary records and unique records
SELECT * FROM primary_records
UNION ALL
SELECT * FROM unique_records
ORDER BY customer_id;
```

## Delete Duplicates Keeping One

```sql
-- Delete duplicates, keep most recent (PostgreSQL)
DELETE FROM customers
WHERE customer_id IN (
    SELECT customer_id
    FROM (
        SELECT 
            customer_id,
            ROW_NUMBER() OVER (
                PARTITION BY email 
                ORDER BY created_date DESC
            ) AS rn
        FROM customers
    ) AS ranked
    WHERE rn > 1
);

-- SQL Server: Use CTE with DELETE
WITH ranked AS (
    SELECT 
        customer_id,
        ROW_NUMBER() OVER (
            PARTITION BY email 
            ORDER BY created_date DESC
        ) AS rn
    FROM customers
)
DELETE FROM ranked
WHERE rn > 1;

-- MySQL: Delete duplicates keeping lowest ID
DELETE c1 FROM customers c1
INNER JOIN customers c2 
WHERE c1.customer_id > c2.customer_id
  AND c1.email = c2.email;

-- Safe approach: Create new table with deduplicated data
CREATE TABLE customers_deduplicated AS
SELECT DISTINCT ON (email)
    *
FROM customers
ORDER BY email, created_date DESC;

-- Then swap tables
DROP TABLE customers;
ALTER TABLE customers_deduplicated RENAME TO customers;
```

## Prevent Duplicates with Constraints

```sql
-- Add unique constraint to prevent future duplicates
ALTER TABLE customers
ADD CONSTRAINT customers_email_unique UNIQUE (email);

-- Composite unique constraint
ALTER TABLE order_items
ADD CONSTRAINT order_items_unique UNIQUE (order_id, product_id);

-- Unique index (allows NULL values to duplicate)
CREATE UNIQUE INDEX idx_customers_email_unique 
ON customers (email);

-- Partial unique index (only for specific conditions)
CREATE UNIQUE INDEX idx_active_customers_email 
ON customers (email) 
WHERE status = 'active';

-- Handle constraint violations gracefully
INSERT INTO customers (customer_id, email, name)
VALUES (123, 'user@example.com', 'John Doe')
ON CONFLICT (email) 
DO UPDATE SET 
    name = EXCLUDED.name,
    updated_at = CURRENT_TIMESTAMP;
```

## Deduplication for INSERT Operations

```sql
-- Remove duplicates before inserting
INSERT INTO target_table (id, email, name)
SELECT DISTINCT ON (email)
    id, email, name
FROM source_table
ORDER BY email, created_date DESC
ON CONFLICT (email) DO NOTHING;

-- Or use window function approach
INSERT INTO target_table (id, email, name)
SELECT id, email, name
FROM (
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_date DESC) AS rn
    FROM source_table
) ranked
WHERE rn = 1;

-- Upsert pattern (INSERT or UPDATE)
INSERT INTO customers (customer_id, email, name, total_purchases)
SELECT 
    customer_id,
    email,
    name,
    total_purchases
FROM (
    SELECT DISTINCT ON (email)
        *
    FROM staging_customers
    ORDER BY email, updated_at DESC
) deduplicated
ON CONFLICT (email) 
DO UPDATE SET
    name = EXCLUDED.name,
    total_purchases = customers.total_purchases + EXCLUDED.total_purchases,
    updated_at = CURRENT_TIMESTAMP;
```

## Deduplication Quality Checks

```sql
-- Verify deduplication results
WITH dedup_check AS (
    SELECT 
        email,
        COUNT(*) AS count
    FROM customers_deduplicated
    GROUP BY email
    HAVING COUNT(*) > 1
)
SELECT 
    CASE 
        WHEN COUNT(*) = 0 THEN 'Success: No duplicates remain'
        ELSE 'Failure: ' || COUNT(*) || ' email(s) still have duplicates'
    END AS deduplication_status,
    COUNT(*) AS remaining_duplicate_groups
FROM dedup_check;

-- Compare record counts
SELECT 
    'Original' AS source,
    COUNT(*) AS total_records,
    COUNT(DISTINCT email) AS unique_emails,
    COUNT(*) - COUNT(DISTINCT email) AS duplicate_count
FROM customers_original

UNION ALL

SELECT 
    'Deduplicated' AS source,
    COUNT(*) AS total_records,
    COUNT(DISTINCT email) AS unique_emails,
    COUNT(*) - COUNT(DISTINCT email) AS duplicate_count
FROM customers_deduplicated;
```

## Advanced Deduplication Strategies

```sql
-- Fuzzy deduplication using similarity
WITH potential_duplicates AS (
    SELECT 
        c1.customer_id AS id1,
        c2.customer_id AS id2,
        c1.customer_name AS name1,
        c2.customer_name AS name2,
        SIMILARITY(c1.customer_name, c2.customer_name) AS name_sim,
        CASE 
            WHEN c1.email = c2.email THEN 1.0
            ELSE 0.0
        END AS email_match,
        CASE 
            WHEN c1.phone = c2.phone THEN 1.0
            ELSE 0.0
        END AS phone_match
    FROM customers c1
    CROSS JOIN customers c2
    WHERE c1.customer_id < c2.customer_id
),
scored_matches AS (
    SELECT 
        *,
        (name_sim * 0.5 + email_match * 0.3 + phone_match * 0.2) AS match_score
    FROM potential_duplicates
    WHERE name_sim > 0.7 OR email_match = 1 OR phone_match = 1
)
SELECT 
    id1,
    id2,
    name1,
    name2,
    ROUND(match_score::NUMERIC, 3) AS match_score,
    CASE 
        WHEN match_score > 0.9 THEN 'Very Likely Duplicate'
        WHEN match_score > 0.7 THEN 'Likely Duplicate'
        ELSE 'Possible Duplicate'
    END AS duplicate_likelihood
FROM scored_matches
WHERE match_score > 0.5
ORDER BY match_score DESC;

-- Deduplication with audit trail
CREATE TABLE customer_dedup_audit AS
WITH dedup_action AS (
    SELECT 
        customer_id,
        email,
        CASE 
            WHEN ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_date DESC) = 1 
            THEN 'Kept'
            ELSE 'Merged'
        END AS action,
        ROW_NUMBER() OVER (PARTITION BY email ORDER BY created_date DESC) AS row_num
    FROM customers
)
SELECT 
    customer_id,
    email,
    action,
    CURRENT_TIMESTAMP AS processed_at,
    CURRENT_USER AS processed_by
FROM dedup_action;
```
