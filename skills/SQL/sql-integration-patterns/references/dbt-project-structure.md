# dbt Project Structure

Reference for organizing a dbt project: directory layout, YAML configuration, seeds, macros, packages, and environment management.

---

## Standard Directory Layout

```
my_dbt_project/
├── dbt_project.yml
├── packages.yml
├── models/
│   ├── staging/
│   │   ├── ecommerce/
│   │   │   ├── _ecommerce__sources.yml
│   │   │   ├── _ecommerce__models.yml
│   │   │   ├── stg_ecommerce__orders.sql
│   │   │   └── stg_ecommerce__customers.sql
│   │   └── stripe/
│   │       ├── _stripe__sources.yml
│   │       └── stg_stripe__payments.sql
│   ├── intermediate/
│   │   └── finance/
│   │       ├── _finance__models.yml
│   │       └── int_orders_with_payments.sql
│   └── marts/
│       ├── finance/
│       │   ├── _finance__models.yml
│       │   ├── fct_orders.sql
│       │   └── dim_customers.sql
│       └── marketing/
│           └── fct_sessions.sql
├── seeds/
│   └── country_codes.csv
├── snapshots/
│   └── snap_customers.sql
├── macros/
│   ├── generate_schema_name.sql
│   └── cents_to_dollars.sql
├── tests/
│   └── assert_orders_have_items.sql
└── analyses/
    └── ad_hoc_revenue_query.sql
```

---

## dbt_project.yml

```yaml
name: 'my_analytics'
version: '1.0.0'
config-version: 2
profile: 'analytics_warehouse'

model-paths: ["models"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]
test-paths: ["tests"]
analysis-paths: ["analyses"]
clean-targets: ["target", "dbt_packages"]

models:
  my_analytics:
    staging:
      +materialized: view
      +schema: staging
    intermediate:
      +materialized: ephemeral
    marts:
      +materialized: table
      finance:
        +schema: finance
        +tags: ['finance']
      marketing:
        +schema: marketing

seeds:
  my_analytics:
    +schema: seeds
    country_codes:
      +column_types:
        country_code: varchar(2)

snapshots:
  my_analytics:
    +target_schema: snapshots

vars:
  start_date: '2020-01-01'
  enable_marketing_models: true
```

---

## profiles.yml

Typically in `~/.dbt/profiles.yml`, not committed to version control.

```yaml
analytics_warehouse:
  target: dev
  outputs:
    dev:
      type: postgres
      host: "{{ env_var('DBT_HOST') }}"
      port: 5432
      user: "{{ env_var('DBT_USER') }}"
      password: "{{ env_var('DBT_PASSWORD') }}"
      dbname: analytics
      schema: "dbt_{{ env_var('DBT_USER') }}"
      threads: 4
    prod:
      type: postgres
      host: "{{ env_var('DBT_PROD_HOST') }}"
      port: 5432
      user: "{{ env_var('DBT_PROD_USER') }}"
      password: "{{ env_var('DBT_PROD_PASSWORD') }}"
      dbname: analytics
      schema: analytics
      threads: 8
```

---

## Seeds

Seeds load small CSV files into the warehouse as tables.

```csv
country_code,country_name,region
US,United States,North America
CA,Canada,North America
GB,United Kingdom,Europe
DE,Germany,Europe
```

```sql
-- Using a seed in a model
select o.*, c.country_name, c.region
from {{ ref('stg_ecommerce__orders') }} o
left join {{ ref('country_codes') }} c on o.country_code = c.country_code
```

```bash
dbt seed                        # load all seeds
dbt seed --select country_codes # load one seed
```

---

## Macros

### Utility macro

```sql
{% macro cents_to_dollars(column_name, precision=2) %}
    round({{ column_name }} / 100.0, {{ precision }})
{% endmacro %}

-- Usage: {{ cents_to_dollars('amount_cents') }} as amount_dollars
```

### Schema name override

```sql
{% macro generate_schema_name(custom_schema_name, node) %}
    {% if target.name == 'prod' and custom_schema_name is not none %}
        {{ custom_schema_name | trim }}
    {% elif custom_schema_name is not none %}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {% else %}
        {{ default_schema }}
    {% endif %}
{% endmacro %}
```

### Grant access post-hook

```yaml
# In dbt_project.yml
models:
  my_analytics:
    marts:
      +post-hook:
        - "{{ grant_select(this.schema, 'ANALYTICS_READERS') }}"
```

---

## Packages

```yaml
# packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: [">=1.1.0", "<2.0.0"]
  - package: dbt-labs/codegen
    version: ">=0.12.0"
  - package: calogica/dbt_expectations
    version: ">=0.10.0"
  - git: "https://github.com/our-org/dbt-shared-macros.git"
    revision: v0.5.0
```

### Commonly used dbt_utils

```sql
-- Surrogate key
{{ dbt_utils.generate_surrogate_key(['order_id', 'product_id']) }} as line_item_key

-- Date spine
{{ dbt_utils.date_spine(datepart="day", start_date="cast('2020-01-01' as date)", end_date="current_date") }}
```

```bash
dbt deps  # install packages
```

---

## CLI Commands

```bash
dbt run                                # run all models
dbt run --select +fct_orders           # model + upstream deps
dbt run --select stg_ecommerce__orders+ # model + downstream
dbt run --select tag:finance           # by tag
dbt test                               # run all tests
dbt test --select fct_orders           # test one model
dbt docs generate && dbt docs serve    # documentation
dbt compile --select fct_orders        # render Jinja without executing
dbt snapshot                           # run snapshots
dbt ls --resource-type model           # list models in DAG
```

---

## Environment Separation

```sql
-- Target-based data limiting for dev speed
{% if target.name == 'dev' %}
    where ordered_at >= dateadd(month, -3, current_date)
{% endif %}
```

```sql
-- Variable-based feature flags
{{ config(enabled=var('enable_marketing_models', false)) }}
select * from {{ ref('int_sessions_attributed') }}
```

---

## CI/CD Integration

```yaml
# .github/workflows/dbt_ci.yml
name: dbt CI
on:
  pull_request:
    paths: ['models/**', 'macros/**', 'tests/**']

jobs:
  dbt-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      - run: pip install dbt-postgres
      - run: dbt deps
      - run: dbt build --select state:modified+ --defer --state ./prod-manifest
        env:
          DBT_HOST: ${{ secrets.DBT_CI_HOST }}
          DBT_USER: ${{ secrets.DBT_CI_USER }}
          DBT_PASSWORD: ${{ secrets.DBT_CI_PASSWORD }}
```
