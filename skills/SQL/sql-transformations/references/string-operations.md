# String Operations

## Case Conversion

```sql
-- Change string case
SELECT 
    product_name,
    UPPER(product_name) AS product_upper,
    LOWER(product_name) AS product_lower,
    INITCAP(product_name) AS product_title_case,  -- PostgreSQL, Oracle
    
    -- SQL Server / MySQL alternatives for title case
    CONCAT(
        UPPER(SUBSTRING(product_name, 1, 1)),
        LOWER(SUBSTRING(product_name, 2, LEN(product_name)))
    ) AS product_title_manual
FROM products;
```

## Trimming and Padding

```sql
-- Remove whitespace
SELECT 
    '  hello  ' AS original,
    TRIM('  hello  ') AS trimmed,
    LTRIM('  hello  ') AS left_trimmed,
    RTRIM('  hello  ') AS right_trimmed,
    TRIM(BOTH ' ' FROM '  hello  ') AS both_trimmed,
    
    -- Remove specific characters
    TRIM('x' FROM 'xxxhelloxxx') AS trim_x,
    TRIM(LEADING '0' FROM '00012345') AS trim_leading_zeros,
    
    -- PostgreSQL: Multiple whitespace to single space
    REGEXP_REPLACE('hello    world', '\s+', ' ', 'g') AS normalized_spaces;

-- Add padding
SELECT 
    id,
    LPAD(id::TEXT, 8, '0') AS id_padded,  -- '00001234'
    RPAD(name, 20, '.') AS name_padded,    -- 'Product..............'
    
    -- Format as fixed-width columns
    RPAD(customer_name, 30, ' ') || LPAD(amount::TEXT, 10, ' ') AS formatted_line
FROM orders;
```

## Substring Extraction

```sql
-- Extract portions of strings
SELECT 
    email,
    -- SUBSTRING / SUBSTR
    SUBSTRING(email FROM 1 FOR 10) AS email_start,  -- PostgreSQL
    SUBSTRING(email, 1, 10) AS email_start_std,     -- Most databases
    SUBSTR(email, 1, 10) AS email_start_alt,        -- Oracle, SQLite
    
    -- Extract from position to end
    SUBSTRING(email FROM 5) AS email_from_fifth,
    
    -- Extract domain from email
    SUBSTRING(email FROM POSITION('@' IN email) + 1) AS email_domain,
    SPLIT_PART(email, '@', 2) AS email_domain_pg,  -- PostgreSQL
    
    -- LEFT and RIGHT
    LEFT(email, 5) AS email_left,
    RIGHT(email, 10) AS email_right,
    
    -- Extract area code from phone (555)-123-4567
    SUBSTRING(phone FROM 2 FOR 3) AS area_code,
    
    -- Extract year from date string YYYY-MM-DD
    LEFT(date_str, 4) AS year
FROM customers;
```

## String Splitting

```sql
-- PostgreSQL: Split string into array and rows
SELECT 
    product_id,
    tags_string,  -- 'red,blue,green'
    
    -- Split into array
    STRING_TO_ARRAY(tags_string, ',') AS tags_array,
    
    -- Split into rows
    UNNEST(STRING_TO_ARRAY(tags_string, ',')) AS tag,
    
    -- Split and trim each element
    TRIM(UNNEST(STRING_TO_ARRAY(tags_string, ','))) AS tag_trimmed,
    
    -- Split on delimiter and get specific part
    SPLIT_PART(tags_string, ',', 1) AS first_tag,
    SPLIT_PART(email, '@', 1) AS username,
    SPLIT_PART(email, '@', 2) AS domain
FROM products;

-- SQL Server: STRING_SPLIT
SELECT 
    product_id,
    value AS tag
FROM products
CROSS APPLY STRING_SPLIT(tags_string, ',');

-- MySQL: SUBSTRING_INDEX (works differently - returns up to Nth occurrence)
SELECT 
    SUBSTRING_INDEX(tags_string, ',', 1) AS first_tag,
    SUBSTRING_INDEX(tags_string, ',', 2) AS first_two_tags,
    SUBSTRING_INDEX(
        SUBSTRING_INDEX(tags_string, ',', 2),  -- Get first 2
        ',', -1                                 -- Then get last of those
    ) AS second_tag
FROM products;
```

## String Concatenation

```sql
-- Concatenate strings
SELECT 
    first_name,
    last_name,
    
    -- Concatenation operator (PostgreSQL, Oracle, SQLite)
    first_name || ' ' || last_name AS full_name,
    
    -- CONCAT function (works across databases, handles NULLs better)
    CONCAT(first_name, ' ', last_name) AS full_name_concat,
    
    -- CONCAT_WS (concatenate with separator, skips NULLs)
    CONCAT_WS(', ', city, state, postal_code) AS address,
    CONCAT_WS(' - ', product_code, product_name, category) AS product_full,
    
    -- Build formatted strings
    CONCAT(
        'Customer: ', customer_name, 
        ' (ID: ', customer_id, ')'
    ) AS customer_display,
    
    -- SQL Server uses + operator
    first_name + ' ' + last_name AS full_name_sqlserver
FROM customers;

-- Aggregate concatenation
SELECT 
    category,
    -- PostgreSQL
    STRING_AGG(product_name, ', ' ORDER BY product_name) AS products,
    STRING_AGG(DISTINCT manufacturer, '; ') AS manufacturers,
    
    -- MySQL
    GROUP_CONCAT(product_name ORDER BY product_name SEPARATOR ', ') AS products_mysql,
    
    -- SQL Server
    STRING_AGG(product_name, ', ') WITHIN GROUP (ORDER BY product_name) AS products_sqlserver
FROM products
GROUP BY category;
```

## Pattern Matching and Replacement

```sql
-- REPLACE - simple string replacement
SELECT 
    description,
    REPLACE(description, 'old_brand', 'new_brand') AS updated_description,
    REPLACE(REPLACE(phone, '-', ''), '(', '') AS phone_cleaned,
    
    -- Remove multiple different characters
    REPLACE(REPLACE(REPLACE(text, ',', ''), '.', ''), ';', '') AS text_cleaned;

-- REGEXP_REPLACE - pattern-based replacement (PostgreSQL)
SELECT 
    phone,
    -- Remove all non-digit characters
    REGEXP_REPLACE(phone, '[^0-9]', '', 'g') AS phone_digits_only,
    
    -- Replace multiple spaces with single space
    REGEXP_REPLACE(text, '\s+', ' ', 'g') AS normalized_spaces,
    
    -- Remove HTML tags
    REGEXP_REPLACE(html_text, '<[^>]+>', '', 'g') AS plain_text,
    
    -- Extract and format phone number
    REGEXP_REPLACE(
        REGEXP_REPLACE(phone, '[^0-9]', '', 'g'),
        '^(\d{3})(\d{3})(\d{4})$',
        '(\1) \2-\3'
    ) AS phone_formatted,
    
    -- Mask credit card (show last 4 digits)
    REGEXP_REPLACE(credit_card, '^(\d{12})(\d{4})$', '************\2') AS card_masked
FROM customer_data;

-- MySQL REGEXP_REPLACE (MySQL 8.0+)
SELECT 
    REGEXP_REPLACE(phone, '[^0-9]', '') AS phone_digits,
    REGEXP_REPLACE(text, '\s+', ' ') AS normalized;

-- TRANSLATE - character-by-character replacement
SELECT 
    phone,
    TRANSLATE(phone, '()-. ', '') AS phone_no_symbols,  -- Remove these chars
    TRANSLATE(text, 'aeiou', 'AEIOU') AS vowels_upper   -- Replace a→A, e→E, etc.
FROM data;
```

## Pattern Matching (Finding)

```sql
-- Check if pattern exists
SELECT 
    email,
    -- LIKE for simple patterns
    email LIKE '%@gmail.com' AS is_gmail,
    email LIKE 'admin%' AS starts_with_admin,
    email LIKE '%test%' AS contains_test,
    
    -- SIMILAR TO (SQL standard, PostgreSQL)
    email SIMILAR TO '%@(gmail|yahoo|hotmail).com' AS is_common_email,
    
    -- REGEXP (PostgreSQL)
    email ~ '^[a-z]+@[a-z]+\.(com|org|net)$' AS valid_email_pattern,
    email ~* '^admin' AS starts_with_admin_case_insensitive,
    
    -- Position of substring
    POSITION('@' IN email) AS at_sign_position,
    STRPOS(email, '@') AS at_sign_position_alt,  -- PostgreSQL
    
    -- Check if string contains substring
    CASE 
        WHEN POSITION('gmail' IN email) > 0 THEN TRUE 
        ELSE FALSE 
    END AS has_gmail
FROM customers;
```

## String Length and Character Operations

```sql
-- String length
SELECT 
    description,
    LENGTH(description) AS char_count,
    CHAR_LENGTH(description) AS char_count_alt,
    OCTET_LENGTH(description) AS byte_count,  -- May differ for UTF-8
    
    -- Check length for validation
    CASE 
        WHEN LENGTH(password) < 8 THEN 'Too Short'
        WHEN LENGTH(password) > 72 THEN 'Too Long'
        ELSE 'Valid Length'
    END AS password_status
FROM users;

-- Character operations
SELECT 
    -- Get ASCII value
    ASCII('A') AS ascii_value,  -- Returns 65
    CHR(65) AS char_from_ascii,  -- Returns 'A'
    
    -- Repeat string
    REPEAT('*', 10) AS stars,  -- '**********'
    REPEAT('-', LENGTH(title)) AS underline,
    
    -- Reverse string
    REVERSE(text) AS text_reversed
FROM data;
```

## Advanced String Manipulation

```sql
-- Extract all numbers from string
SELECT 
    mixed_string,
    REGEXP_REPLACE(mixed_string, '[^0-9]', '', 'g') AS numbers_only,
    
    -- Extract all letters
    REGEXP_REPLACE(mixed_string, '[^a-zA-Z]', '', 'g') AS letters_only,
    
    -- Capitalize first letter of each word
    INITCAP(LOWER(product_name)) AS product_proper_case,
    
    -- Remove accents/diacritics (PostgreSQL with unaccent extension)
    UNACCENT(text) AS text_no_accents,
    
    -- Convert to URL-friendly slug
    LOWER(
        REGEXP_REPLACE(
            REGEXP_REPLACE(product_name, '[^a-zA-Z0-9\s-]', '', 'g'),
            '\s+', '-', 'g'
        )
    ) AS url_slug
FROM products;

-- Format phone numbers intelligently
SELECT 
    phone_raw,
    CASE 
        WHEN REGEXP_REPLACE(phone_raw, '[^0-9]', '', 'g') ~ '^1?[0-9]{10}$' THEN
            REGEXP_REPLACE(
                REGEXP_REPLACE(phone_raw, '[^0-9]', '', 'g'),
                '^1?([0-9]{3})([0-9]{3})([0-9]{4})$',
                '(\1) \2-\3'
            )
        ELSE phone_raw
    END AS phone_formatted
FROM contacts;
```

## String Comparison

```sql
-- Case-sensitive vs case-insensitive comparison
SELECT 
    name,
    name = 'John' AS exact_match,
    UPPER(name) = 'JOHN' AS case_insensitive_match,
    name ILIKE 'john' AS ilike_match,  -- PostgreSQL case-insensitive LIKE
    
    -- Similarity functions (PostgreSQL with pg_trgm)
    SIMILARITY(name, 'John Smith') AS similarity_score,
    
    -- Levenshtein distance
    LEVENSHTEIN(name, 'John Smith') AS edit_distance
FROM customers;
```

## NULL and Empty String Handling

```sql
-- Distinguish between NULL and empty string
SELECT 
    description,
    CASE 
        WHEN description IS NULL THEN 'NULL'
        WHEN TRIM(description) = '' THEN 'Empty'
        ELSE 'Has Content'
    END AS content_status,
    
    -- Convert empty strings to NULL
    NULLIF(TRIM(description), '') AS description_clean,
    
    -- Convert NULL to empty string
    COALESCE(description, '') AS description_non_null,
    
    -- Get length (NULL-safe)
    COALESCE(LENGTH(description), 0) AS description_length
FROM products;
```
