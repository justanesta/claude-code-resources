# dbt Model Patterns

Reference for dbt model types, Jinja functions, incremental strategies, snapshots, and testing patterns.

---

## Model Layers

| Layer | Purpose | Materialization | Naming Convention |
|---|---|---|---|
| Staging | Clean and rename source columns | View | `stg_{source}_{table}` |
| Intermediate | Join and reshape across staging models | View or ephemeral | `int_{entity}_{verb}` |
| Mart | Final business entities for consumption | Table or incremental | `fct_{event}` / `dim_{entity}` |

---

## ref() and source()

### Source definition

```yaml
# models/staging/_sources.yml
version: 2
sources:
  - name: ecommerce
    database: raw_db
    schema: ecommerce
    freshness:
      warn_after: { count: 12, period: hour }
      error_after: { count: 24, period: hour }
    loaded_at_field: _etl_loaded_at
    tables:
      - name: raw_orders
        columns:
          - name: id
            tests: [not_null, unique]
      - name: raw_customers
      - name: raw_products
```

### Staging model using source()

```sql
-- models/staging/stg_ecommerce__orders.sql
with source as (
    select * from {{ source('ecommerce', 'raw_orders') }}
),
renamed as (
    select
        id                    as order_id,
        user_id               as customer_id,
        lower(trim(status))   as order_status,
        amount / 100.0        as order_total,
        created_at            as ordered_at
    from source
    where id is not null
)
select * from renamed
```

### Intermediate model using ref()

```sql
-- models/intermediate/int_order_items_enriched.sql
with orders as (select * from {{ ref('stg_ecommerce__orders') }}),
items as (select * from {{ ref('stg_ecommerce__order_items') }}),
products as (select * from {{ ref('stg_ecommerce__products') }})

select
    items.order_item_id, items.order_id, orders.customer_id, orders.ordered_at,
    products.product_name, products.category, items.quantity, items.unit_price,
    items.quantity * items.unit_price as line_total
from items
inner join orders on items.order_id = orders.order_id
inner join products on items.product_id = products.product_id
```

### Mart model

```sql
-- models/marts/fct_orders.sql
{{ config(materialized='table', tags=['finance', 'daily']) }}

with order_items as (select * from {{ ref('int_order_items_enriched') }})
select
    order_id, customer_id, ordered_at,
    count(*) as item_count,
    sum(line_total) as order_total
from order_items
group by 1, 2, 3
```

---

## Incremental Models

### Merge strategy (upsert)

```sql
{{
    config(
        materialized='incremental',
        unique_key='subscription_id',
        incremental_strategy='merge',
        merge_update_columns=['status', 'plan_name', 'updated_at']
    )
}}

select subscription_id, customer_id, plan_name, status, started_at, updated_at
from {{ ref('stg_billing__subscriptions') }}

{% if is_incremental() %}
    where updated_at > (select max(updated_at) from {{ this }})
{% endif %}
```

### Delete+insert strategy (for warehouses without MERGE)

```sql
{{
    config(
        materialized='incremental',
        unique_key='event_date',
        incremental_strategy='delete+insert',
        partition_by={"field": "event_date", "data_type": "date", "granularity": "day"}
    )
}}

select event_date, event_type, count(*) as event_count
from {{ ref('stg_events') }}
{% if is_incremental() %}
    where event_date >= (select max(event_date) from {{ this }})
{% endif %}
group by 1, 2
```

```bash
dbt run --select fct_page_views --full-refresh  # force full rebuild
```

---

## Snapshots

SCD Type 2 tracking of row-level changes.

### Timestamp strategy

```sql
{% snapshot snap_customers %}
{{ config(target_schema='snapshots', unique_key='customer_id',
          strategy='timestamp', updated_at='updated_at', invalidate_hard_deletes=True) }}

select customer_id, email, name, segment, is_active, updated_at
from {{ source('ecommerce', 'raw_customers') }}
{% endsnapshot %}
```

### Check strategy (no reliable timestamp)

```sql
{% snapshot snap_product_prices %}
{{ config(target_schema='snapshots', unique_key='product_id',
          strategy='check', check_cols=['price', 'is_active']) }}

select product_id, sku, name, price, is_active
from {{ source('ecommerce', 'raw_products') }}
{% endsnapshot %}
```

Output includes `dbt_valid_from`, `dbt_valid_to`, and `dbt_scd_id` columns.

---

## Testing Patterns

### Schema tests in YAML

```yaml
version: 2
models:
  - name: fct_orders
    columns:
      - name: order_id
        tests: [not_null, unique]
      - name: customer_id
        tests:
          - not_null
          - relationships:
              to: ref('dim_customers')
              field: customer_id
      - name: order_total
        tests:
          - not_null
          - dbt_utils.accepted_range:
              min_value: 0
              inclusive: true
      - name: order_status
        tests:
          - accepted_values:
              values: ['pending', 'shipped', 'delivered', 'cancelled']
```

### Singular test

```sql
-- tests/assert_orders_have_items.sql
select o.order_id
from {{ ref('fct_orders') }} o
left join {{ ref('int_order_items_enriched') }} i on o.order_id = i.order_id
where i.order_item_id is null
```

### Generic test (reusable)

```sql
-- tests/generic/test_is_positive.sql
{% test is_positive(model, column_name) %}
select {{ column_name }} from {{ model }} where {{ column_name }} < 0
{% endtest %}
```

---

## Edge Cases

- **Late-arriving data**: Use a lookback window: `where ordered_at > (select dateadd(hour, -6, max(ordered_at)) from {{ this }})`.
- **Schema changes**: Adding columns to incremental models requires `--full-refresh` or `on_schema_change='append_new_columns'`.
- **Hard deletes**: Snapshots ignore deleted rows by default. Set `invalidate_hard_deletes=True`.
- **Circular refs**: Not allowed. Restructure models to break the cycle.
- **Ephemeral models**: Cannot be selected with `dbt run --select`. They inline as CTEs in downstream models.
