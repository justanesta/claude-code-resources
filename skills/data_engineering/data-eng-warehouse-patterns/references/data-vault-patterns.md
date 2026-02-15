# Data Vault 2.0 Patterns Reference

Detailed patterns for Data Vault modeling including hubs, links, satellites, hash key generation, point-in-time tables, bridge tables, and the business vault.

---

## Data Vault Core Concepts

Data Vault 2.0 is a detail-oriented, historical tracking, and uniquely linked set of normalized tables that support one or more functional areas of business. It has three core entity types:

- **Hubs** — Unique business keys (the "nouns" of the business)
- **Links** — Relationships between hubs (the "verbs" of the business)
- **Satellites** — Descriptive attributes and history (the context)

---

## Hub Tables

Hubs store the unique set of business keys. They never change once loaded. Each hub has a hash key (surrogate), business key, load timestamp, and record source.

```sql
-- Hub for Customer business entity
CREATE TABLE raw_vault.hub_customer (
    hub_customer_hk     BINARY(32)      NOT NULL,
    customer_bk         VARCHAR(64)     NOT NULL,
    load_timestamp      TIMESTAMP_NTZ   NOT NULL,
    record_source       VARCHAR(128)    NOT NULL,
    CONSTRAINT pk_hub_customer PRIMARY KEY (hub_customer_hk)
);

-- Hub for Product business entity
CREATE TABLE raw_vault.hub_product (
    hub_product_hk      BINARY(32)      NOT NULL,
    product_bk          VARCHAR(64)     NOT NULL,
    load_timestamp      TIMESTAMP_NTZ   NOT NULL,
    record_source       VARCHAR(128)    NOT NULL,
    CONSTRAINT pk_hub_product PRIMARY KEY (hub_product_hk)
);

-- Hub for Order (transactional business key)
CREATE TABLE raw_vault.hub_order (
    hub_order_hk        BINARY(32)      NOT NULL,
    order_bk            VARCHAR(64)     NOT NULL,
    load_timestamp      TIMESTAMP_NTZ   NOT NULL,
    record_source       VARCHAR(128)    NOT NULL,
    CONSTRAINT pk_hub_order PRIMARY KEY (hub_order_hk)
);

-- Loading a hub: insert only new business keys
INSERT INTO raw_vault.hub_customer (hub_customer_hk, customer_bk, load_timestamp, record_source)
SELECT
    SHA2(UPPER(TRIM(src.customer_id)), 256)     AS hub_customer_hk,
    src.customer_id                              AS customer_bk,
    CURRENT_TIMESTAMP()                          AS load_timestamp,
    'crm_system'                                 AS record_source
FROM staging.stg_crm_customers src
LEFT JOIN raw_vault.hub_customer hub
    ON SHA2(UPPER(TRIM(src.customer_id)), 256) = hub.hub_customer_hk
WHERE hub.hub_customer_hk IS NULL;
```

### Hub Design Rules

- One hub per business concept (Customer, Product, Order, Account)
- Business key must uniquely identify the entity from the source system
- Hash key is derived from the business key using a consistent algorithm
- Never update or delete hub records
- Multiple source systems can feed the same hub (with different record_source values)

---

## Link Tables

Links capture the relationships between two or more hubs. They record when a relationship was first observed.

```sql
-- Link between Customer and Order
CREATE TABLE raw_vault.link_customer_order (
    link_customer_order_hk  BINARY(32)      NOT NULL,
    hub_customer_hk         BINARY(32)      NOT NULL,
    hub_order_hk            BINARY(32)      NOT NULL,
    load_timestamp          TIMESTAMP_NTZ   NOT NULL,
    record_source           VARCHAR(128)    NOT NULL,
    CONSTRAINT pk_lnk_cust_ord PRIMARY KEY (link_customer_order_hk),
    CONSTRAINT fk_lnk_cust FOREIGN KEY (hub_customer_hk) REFERENCES raw_vault.hub_customer(hub_customer_hk),
    CONSTRAINT fk_lnk_ord FOREIGN KEY (hub_order_hk) REFERENCES raw_vault.hub_order(hub_order_hk)
);

-- Link between Order and Product (many-to-many with dependent child key)
CREATE TABLE raw_vault.link_order_product (
    link_order_product_hk   BINARY(32)      NOT NULL,
    hub_order_hk            BINARY(32)      NOT NULL,
    hub_product_hk          BINARY(32)      NOT NULL,
    line_number             INTEGER         NOT NULL,  -- dependent child key
    load_timestamp          TIMESTAMP_NTZ   NOT NULL,
    record_source           VARCHAR(128)    NOT NULL,
    CONSTRAINT pk_lnk_ord_prod PRIMARY KEY (link_order_product_hk)
);

-- Loading a link: insert only new relationships
INSERT INTO raw_vault.link_customer_order
SELECT
    SHA2(CONCAT(
        SHA2(UPPER(TRIM(src.customer_id)), 256),
        SHA2(UPPER(TRIM(src.order_id)), 256)
    ), 256)                                     AS link_customer_order_hk,
    SHA2(UPPER(TRIM(src.customer_id)), 256)     AS hub_customer_hk,
    SHA2(UPPER(TRIM(src.order_id)), 256)        AS hub_order_hk,
    CURRENT_TIMESTAMP()                          AS load_timestamp,
    'order_system'                               AS record_source
FROM staging.stg_orders src
LEFT JOIN raw_vault.link_customer_order lnk
    ON SHA2(CONCAT(
        SHA2(UPPER(TRIM(src.customer_id)), 256),
        SHA2(UPPER(TRIM(src.order_id)), 256)
    ), 256) = lnk.link_customer_order_hk
WHERE lnk.link_customer_order_hk IS NULL;
```

### Link Types

| Type | Description | Example |
|---|---|---|
| Standard Link | Two or more hub references | Customer-Order link |
| Hierarchical Link | Self-referencing (same hub twice) | Employee-Manager link |
| Same-As Link | Tracks duplicates across sources | Customer_CRM-Customer_ERP |
| Non-historized Link | Transaction link (never changes) | Order-Product line items |

---

## Satellite Tables

Satellites store descriptive attributes and track all changes over time. Each satellite belongs to exactly one hub or link.

```sql
-- Satellite for customer descriptive details
CREATE TABLE raw_vault.sat_customer_details (
    hub_customer_hk     BINARY(32)      NOT NULL,
    load_timestamp      TIMESTAMP_NTZ   NOT NULL,
    load_end_timestamp  TIMESTAMP_NTZ   DEFAULT '9999-12-31'::TIMESTAMP_NTZ,
    hash_diff           BINARY(32)      NOT NULL,
    first_name          VARCHAR(128),
    last_name           VARCHAR(128),
    email               VARCHAR(256),
    phone               VARCHAR(32),
    address_line1       VARCHAR(256),
    address_city        VARCHAR(128),
    address_state       VARCHAR(64),
    address_postal      VARCHAR(16),
    address_country     VARCHAR(2),
    record_source       VARCHAR(128)    NOT NULL,
    CONSTRAINT pk_sat_cust_det PRIMARY KEY (hub_customer_hk, load_timestamp)
);

-- Satellite for order status changes (on a link)
CREATE TABLE raw_vault.sat_order_status (
    link_customer_order_hk  BINARY(32)      NOT NULL,
    load_timestamp          TIMESTAMP_NTZ   NOT NULL,
    load_end_timestamp      TIMESTAMP_NTZ   DEFAULT '9999-12-31'::TIMESTAMP_NTZ,
    hash_diff               BINARY(32)      NOT NULL,
    order_status            VARCHAR(32),
    status_reason           VARCHAR(256),
    record_source           VARCHAR(128)    NOT NULL,
    CONSTRAINT pk_sat_ord_stat PRIMARY KEY (link_customer_order_hk, load_timestamp)
);

-- Loading a satellite with change detection using hash_diff
INSERT INTO raw_vault.sat_customer_details
SELECT
    SHA2(UPPER(TRIM(src.customer_id)), 256)     AS hub_customer_hk,
    CURRENT_TIMESTAMP()                          AS load_timestamp,
    '9999-12-31'::TIMESTAMP_NTZ                  AS load_end_timestamp,
    SHA2(CONCAT_WS('||',
        COALESCE(src.first_name, ''),
        COALESCE(src.last_name, ''),
        COALESCE(src.email, ''),
        COALESCE(src.phone, ''),
        COALESCE(src.address_line1, ''),
        COALESCE(src.address_city, ''),
        COALESCE(src.address_state, ''),
        COALESCE(src.address_postal, ''),
        COALESCE(src.address_country, '')
    ), 256)                                      AS hash_diff,
    src.first_name,
    src.last_name,
    src.email,
    src.phone,
    src.address_line1,
    src.address_city,
    src.address_state,
    src.address_postal,
    src.address_country,
    'crm_system'                                 AS record_source
FROM staging.stg_crm_customers src
INNER JOIN raw_vault.hub_customer hub
    ON SHA2(UPPER(TRIM(src.customer_id)), 256) = hub.hub_customer_hk
LEFT JOIN raw_vault.sat_customer_details sat
    ON hub.hub_customer_hk = sat.hub_customer_hk
    AND sat.load_end_timestamp = '9999-12-31'::TIMESTAMP_NTZ
WHERE sat.hub_customer_hk IS NULL
   OR sat.hash_diff != SHA2(CONCAT_WS('||',
        COALESCE(src.first_name, ''),
        COALESCE(src.last_name, ''),
        COALESCE(src.email, ''),
        COALESCE(src.phone, ''),
        COALESCE(src.address_line1, ''),
        COALESCE(src.address_city, ''),
        COALESCE(src.address_state, ''),
        COALESCE(src.address_postal, ''),
        COALESCE(src.address_country, '')
    ), 256);
```

---

## Hash Key Generation

Consistent hash key generation is critical. All team members must use the same algorithm and preprocessing.

```sql
-- Standard hash key function pattern
-- 1. TRIM whitespace
-- 2. UPPER case for case-insensitive matching
-- 3. COALESCE nulls to empty string
-- 4. Concatenate with a delimiter
-- 5. Apply SHA-256

-- Single business key hash
SELECT SHA2(UPPER(TRIM(COALESCE(customer_id, ''))), 256) AS hub_customer_hk;

-- Composite business key hash (for links)
SELECT SHA2(CONCAT_WS('||',
    UPPER(TRIM(COALESCE(customer_id, ''))),
    UPPER(TRIM(COALESCE(order_id, '')))
), 256) AS link_customer_order_hk;

-- Hash diff for change detection (satellite attributes)
SELECT SHA2(CONCAT_WS('||',
    COALESCE(first_name, ''),
    COALESCE(last_name, ''),
    COALESCE(email, ''),
    COALESCE(phone, '')
), 256) AS hash_diff;
```

### Hash Key Rules

- Always use the same hash algorithm across the entire vault (SHA-256 recommended)
- Preprocess inputs identically: TRIM, UPPER, COALESCE to empty string
- Use a consistent delimiter (`||`) between concatenated fields
- Document the hash recipe for each entity in a metadata catalog
- Never change the hash algorithm after initial load

---

## Point-in-Time (PIT) Tables

PIT tables pre-join hub and satellite timestamps for efficient querying. They answer "what was the state of all attributes at a given point in time?"

```sql
-- Point-in-time table for customer
CREATE TABLE business_vault.pit_customer (
    hub_customer_hk                 BINARY(32)      NOT NULL,
    pit_timestamp                   TIMESTAMP_NTZ   NOT NULL,
    sat_customer_details_lt         TIMESTAMP_NTZ,
    sat_customer_preferences_lt     TIMESTAMP_NTZ,
    sat_customer_credit_lt          TIMESTAMP_NTZ,
    CONSTRAINT pk_pit_customer PRIMARY KEY (hub_customer_hk, pit_timestamp)
);

-- Populate PIT table (typically run daily or hourly)
INSERT INTO business_vault.pit_customer
SELECT
    hub.hub_customer_hk,
    snap.snap_timestamp                     AS pit_timestamp,
    MAX(det.load_timestamp)                 AS sat_customer_details_lt,
    MAX(pref.load_timestamp)                AS sat_customer_preferences_lt,
    MAX(cred.load_timestamp)                AS sat_customer_credit_lt
FROM raw_vault.hub_customer hub
CROSS JOIN (
    -- Generate snapshot timestamps (one per day for the last 30 days)
    SELECT DATEADD(DAY, -seq4(), CURRENT_DATE())::TIMESTAMP_NTZ AS snap_timestamp
    FROM TABLE(GENERATOR(ROWCOUNT => 30))
) snap
LEFT JOIN raw_vault.sat_customer_details det
    ON hub.hub_customer_hk = det.hub_customer_hk
    AND det.load_timestamp <= snap.snap_timestamp
LEFT JOIN raw_vault.sat_customer_preferences pref
    ON hub.hub_customer_hk = pref.hub_customer_hk
    AND pref.load_timestamp <= snap.snap_timestamp
LEFT JOIN raw_vault.sat_customer_credit cred
    ON hub.hub_customer_hk = cred.hub_customer_hk
    AND cred.load_timestamp <= snap.snap_timestamp
GROUP BY hub.hub_customer_hk, snap.snap_timestamp;

-- Query using PIT table (efficient single-pass join)
SELECT
    hub.customer_bk,
    pit.pit_timestamp,
    det.first_name,
    det.last_name,
    det.email,
    cred.credit_score,
    cred.credit_limit
FROM business_vault.pit_customer pit
JOIN raw_vault.hub_customer hub
    ON pit.hub_customer_hk = hub.hub_customer_hk
JOIN raw_vault.sat_customer_details det
    ON pit.hub_customer_hk = det.hub_customer_hk
    AND pit.sat_customer_details_lt = det.load_timestamp
JOIN raw_vault.sat_customer_credit cred
    ON pit.hub_customer_hk = cred.hub_customer_hk
    AND pit.sat_customer_credit_lt = cred.load_timestamp
WHERE pit.pit_timestamp = '2026-02-14'::TIMESTAMP_NTZ;
```

---

## Bridge Tables

Bridge tables pre-resolve link traversals for complex queries that would otherwise require many joins.

```sql
-- Bridge table: Customer -> Order -> Product
CREATE TABLE business_vault.bridge_customer_product (
    hub_customer_hk         BINARY(32)      NOT NULL,
    link_customer_order_hk  BINARY(32)      NOT NULL,
    hub_order_hk            BINARY(32)      NOT NULL,
    link_order_product_hk   BINARY(32)      NOT NULL,
    hub_product_hk          BINARY(32)      NOT NULL,
    snapshot_date           DATE            NOT NULL,
    CONSTRAINT pk_bridge_cp PRIMARY KEY (hub_customer_hk, hub_product_hk, hub_order_hk, snapshot_date)
);

-- Populate bridge daily
INSERT INTO business_vault.bridge_customer_product
SELECT
    lco.hub_customer_hk,
    lco.link_customer_order_hk,
    lco.hub_order_hk,
    lop.link_order_product_hk,
    lop.hub_product_hk,
    CURRENT_DATE()                  AS snapshot_date
FROM raw_vault.link_customer_order lco
JOIN raw_vault.link_order_product lop
    ON lco.hub_order_hk = lop.hub_order_hk;
```

---

## Business Vault

The business vault adds derived calculations and business rules on top of the raw vault. It follows the same hub/link/satellite structure but contains computed values.

```sql
-- Business satellite: computed customer lifetime value
CREATE TABLE business_vault.bsat_customer_ltv (
    hub_customer_hk     BINARY(32)      NOT NULL,
    load_timestamp      TIMESTAMP_NTZ   NOT NULL,
    total_orders        INTEGER,
    total_revenue       DECIMAL(14,2),
    avg_order_value     DECIMAL(10,2),
    first_order_date    DATE,
    last_order_date     DATE,
    customer_tenure_days INTEGER,
    ltv_segment         VARCHAR(32),    -- 'high', 'medium', 'low'
    record_source       VARCHAR(128)    DEFAULT 'business_vault_calc',
    CONSTRAINT pk_bsat_cust_ltv PRIMARY KEY (hub_customer_hk, load_timestamp)
);
```
