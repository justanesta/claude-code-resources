---
name: sql-query-fundamentals
description: |
  Core SQL query patterns for SELECT, JOINs, WHERE, GROUP BY, and subqueries. Use this 
  skill when writing basic to intermediate SQL queries, need to understand join types, 
  or work with filtering and aggregation. Covers SELECT fundamentals, all join types, 
  subqueries, CTEs, CASE expressions, and common table operations.
---

# SQL Query Fundamentals

Essential SQL patterns for querying relational databases.

## Core Principles

1. **SELECT only what you need** - Avoid `SELECT *` in production
2. **Use explicit JOINs** - Never use implicit joins with WHERE
3. **Filter early** - Apply WHERE before GROUP BY when possible
4. **Use CTEs for clarity** - Make complex queries readable

## Basic SELECT Patterns

```sql
-- Select specific columns
SELECT 
    customer_id,
    first_name,
    last_name,
    email
FROM customers
WHERE status = 'active'
ORDER BY last_name, first_name;

-- Distinct values
SELECT DISTINCT country
FROM customers
ORDER BY country;

-- Limiting results
SELECT * 
FROM orders 
LIMIT 10 OFFSET 20;  -- PostgreSQL, MySQL
```

See [select-patterns.md](references/select-patterns.md) for:
- Column aliases and calculated columns
- DISTINCT vs GROUP BY
- LIMIT/OFFSET pagination across databases
- Column selection best practices

## JOIN Types

```sql
-- INNER JOIN (only matching rows)
SELECT o.order_id, c.customer_name, o.order_date
FROM orders o
INNER JOIN customers c ON o.customer_id = c.customer_id;

-- LEFT JOIN (all from left table)
SELECT c.customer_name, o.order_id
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id;

-- Find records with no match
SELECT c.customer_id, c.customer_name
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;
```

See [join-patterns.md](references/join-patterns.md) for:
- Join types decision matrix
- Multiple table joins
- Self joins for hierarchical data
- Join conditions vs WHERE filters

## WHERE Clause Patterns

```sql
-- Comparison and logical operators
WHERE age >= 18 AND age < 65

-- IN clause (better than multiple ORs)
WHERE country IN ('USA', 'Canada', 'Mexico')

-- BETWEEN for ranges
WHERE order_date BETWEEN '2024-01-01' AND '2024-12-31'

-- LIKE for pattern matching
WHERE email LIKE '%@gmail.com'

-- NULL handling
WHERE phone_number IS NULL
WHERE COALESCE(mobile_phone, home_phone) IS NOT NULL
```

See [where-clause-patterns.md](references/where-clause-patterns.md) for:
- Operator precedence
- NULL handling strategies
- Pattern matching with LIKE
- Performance considerations (sargable queries)

## GROUP BY and Aggregations

```sql
-- Basic aggregation
SELECT 
    category,
    COUNT(*) as product_count,
    AVG(price) as avg_price,
    MIN(price) as min_price,
    MAX(price) as max_price,
    SUM(price * quantity) as total_revenue
FROM products
GROUP BY category
ORDER BY total_revenue DESC;

-- HAVING clause (filter after grouping)
SELECT 
    customer_id,
    COUNT(*) as order_count,
    SUM(total_amount) as total_spent
FROM orders
GROUP BY customer_id
HAVING COUNT(*) > 5 AND SUM(total_amount) > 1000;
```

See [groupby-aggregation.md](references/groupby-aggregation.md) for:
- Common aggregate functions
- GROUP BY vs DISTINCT
- HAVING vs WHERE
- Multiple grouping columns

## Subqueries

```sql
-- Subquery in WHERE (filtering)
SELECT customer_name, email
FROM customers
WHERE customer_id IN (
    SELECT DISTINCT customer_id
    FROM orders
    WHERE order_date >= '2024-01-01'
);

-- Subquery in FROM (derived table)
SELECT 
    category,
    avg_price,
    product_count
FROM (
    SELECT 
        category,
        AVG(price) as avg_price,
        COUNT(*) as product_count
    FROM products
    GROUP BY category
) AS category_stats
WHERE product_count > 10;

-- Correlated subquery
SELECT 
    e.employee_name,
    e.salary,
    e.department_id,
    (SELECT AVG(salary) 
     FROM employees e2 
     WHERE e2.department_id = e.department_id) as dept_avg_salary
FROM employees e
WHERE e.salary > (
    SELECT AVG(salary) 
    FROM employees e3 
    WHERE e3.department_id = e.department_id
);
```

See [subquery-patterns.md](references/subquery-patterns.md) for:
- Subquery types (scalar, column, row, table)
- Correlated vs non-correlated
- EXISTS vs IN performance
- When to use subquery vs JOIN

## Common Table Expressions (CTEs)

```sql
-- Basic CTE (makes query more readable)
WITH active_customers AS (
    SELECT customer_id, customer_name, email
    FROM customers
    WHERE status = 'active'
        AND last_purchase_date >= CURRENT_DATE - INTERVAL '90 days'
)
SELECT 
    ac.customer_name,
    COUNT(o.order_id) as recent_order_count,
    SUM(o.total_amount) as total_spent
FROM active_customers ac
LEFT JOIN orders o 
    ON ac.customer_id = o.customer_id
    AND o.order_date >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY ac.customer_name
ORDER BY total_spent DESC;

-- Multiple CTEs
WITH 
    high_value_orders AS (
        SELECT * 
        FROM orders 
        WHERE total_amount > 1000
    ),
    vip_customers AS (
        SELECT DISTINCT customer_id, COUNT(*) as high_value_count
        FROM high_value_orders
        GROUP BY customer_id
        HAVING COUNT(*) >= 3
    )
SELECT 
    c.customer_name,
    c.email,
    vc.high_value_count
FROM customers c
INNER JOIN vip_customers vc ON c.customer_id = vc.customer_id;
```

See [cte-patterns.md](references/cte-patterns.md) for:
- CTE vs subquery (when to use each)
- Recursive CTEs for hierarchical data
- CTE optimization considerations
- Materialized CTEs (PostgreSQL)

## CASE Expressions

```sql
-- Simple CASE for categorization
SELECT 
    product_name,
    price,
    CASE 
        WHEN price < 10 THEN 'Budget'
        WHEN price < 50 THEN 'Standard'
        WHEN price < 200 THEN 'Premium'
        ELSE 'Luxury'
    END as price_category
FROM products;

-- CASE in aggregation (conditional counting)
SELECT 
    category,
    COUNT(*) as total_products,
    COUNT(CASE WHEN price < 20 THEN 1 END) as budget_count,
    COUNT(CASE WHEN price BETWEEN 20 AND 100 THEN 1 END) as standard_count,
    COUNT(CASE WHEN price > 100 THEN 1 END) as premium_count,
    AVG(CASE WHEN in_stock = true THEN price END) as avg_available_price
FROM products
GROUP BY category;

-- CASE for data transformation
SELECT 
    order_id,
    order_date,
    status,
    CASE status
        WHEN 'pending' THEN 1
        WHEN 'processing' THEN 2
        WHEN 'shipped' THEN 3
        WHEN 'delivered' THEN 4
        ELSE 0
    END as status_order
FROM orders
ORDER BY status_order, order_date;
```

See [case-expressions.md](references/case-expressions.md) for:
- Simple vs searched CASE
- Conditional aggregation patterns
- Pivot table simulation with CASE
- CASE performance considerations

## Cross-Database Compatibility

### Key Differences

**PostgreSQL** (standard-compliant):
```sql
-- String concatenation
SELECT first_name || ' ' || last_name AS full_name
-- Date arithmetic
SELECT current_date + INTERVAL '7 days'
-- LIMIT syntax
SELECT * FROM orders LIMIT 10 OFFSET 20
```

**MySQL**:
```sql
-- String concatenation
SELECT CONCAT(first_name, ' ', last_name) AS full_name
-- Date arithmetic
SELECT DATE_ADD(CURDATE(), INTERVAL 7 DAY)
-- LIMIT syntax (same as PostgreSQL)
SELECT * FROM orders LIMIT 10 OFFSET 20
```

**SQL Server**:
```sql
-- String concatenation
SELECT first_name + ' ' + last_name AS full_name
-- Date arithmetic
SELECT DATEADD(day, 7, GETDATE())
-- LIMIT equivalent
SELECT * FROM orders 
ORDER BY order_id
OFFSET 20 ROWS FETCH NEXT 10 ROWS ONLY
```

## Anti-Patterns to Avoid

| Avoid | Use Instead | Why |
|-------|-------------|-----|
| `SELECT *` | Explicit column list | Breaks code when schema changes, wastes resources |
| Implicit joins (`FROM a, b WHERE a.id = b.id`) | Explicit `JOIN ON` | Hard to read, error-prone |
| `OR` in JOIN conditions | Separate queries with UNION | Poor performance |
| Functions on indexed columns in WHERE | Sargable predicates | Can't use indexes |
| Subquery when JOIN works | JOIN | Usually faster |
| NOT IN with nullable columns | NOT EXISTS or LEFT JOIN WHERE NULL | NULL handling issues |

## Performance Tips

```sql
-- GOOD - Can use index
WHERE created_date >= '2024-01-01'

-- BAD - Can't use index
WHERE YEAR(created_date) = 2024

-- GOOD - Can use index
WHERE customer_id = 12345

-- BAD - Can't use index  
WHERE customer_id::text = '12345'

-- GOOD - Can use index
WHERE email = 'user@example.com'

-- BAD - Can't use index
WHERE LOWER(email) = 'user@example.com'
```

source: PostgreSQL docs, MySQL docs, SQL Server docs, SQL standards
