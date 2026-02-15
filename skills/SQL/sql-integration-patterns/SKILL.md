---
name: SQL Integration Patterns
description: Patterns for connecting to databases from Python, R, and dbt — covering ORMs, connection management, parameterized queries, and data pipeline best practices.
---

# SQL Integration Patterns

## Core Principles

1. **Always use parameterized queries** — Never interpolate user input into SQL strings. Use bind parameters to prevent SQL injection and improve query plan caching.
2. **Manage connections explicitly** — Open connections late, close them early. Use context managers or connection pools to prevent resource leaks.
3. **Use ORMs for application logic, raw SQL for analytics** — ORMs like SQLAlchemy and Django ORM excel at CRUD operations with business rules. Raw SQL is better for complex analytical queries and bulk operations.
4. **Separate transformation logic from connection logic** — Keep database credentials, connection setup, and query execution in distinct layers so each can be tested and maintained independently.
5. **Prefer declarative over imperative** — Tools like dbt, SQLAlchemy's declarative base, and dbplyr let you express *what* you want rather than *how* to get it, reducing bugs and improving readability.

---

## Python Database Connections

Python offers multiple libraries for database access, each suited to different use cases. The core pattern is always the same: establish a connection, execute parameterized queries, and clean up resources.

```python
import psycopg  # psycopg 3
import pandas as pd

# Context manager ensures connection closes even on error
conn_string = "host=warehouse.internal dbname=analytics user=etl_svc"

with psycopg.connect(conn_string) as conn:
    # Parameterized query — %s placeholders, tuple of values
    result = conn.execute(
        "SELECT order_id, total FROM orders WHERE region = %s AND status = %s",
        ("us-west", "shipped"),
    ).fetchall()

    # pandas integration for analytical workflows
    df = pd.read_sql(
        "SELECT date_trunc('month', order_date) AS month, sum(total) AS revenue "
        "FROM orders WHERE region = %(region)s GROUP BY 1",
        conn,
        params={"region": "us-west"},
    )
```

See [python-db-connectors](references/python-db-connectors.md) for: psycopg3 async patterns, pyodbc for SQL Server, mysql-connector, bulk inserts with COPY, and error handling strategies.

---

## SQLAlchemy ORM Patterns

SQLAlchemy provides both a high-level ORM and a lower-level Core expression language. Modern SQLAlchemy 2.0 uses a unified approach with `select()` statements and type-annotated models.

```python
from sqlalchemy import create_engine, select, ForeignKey
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship, Session

class Base(DeclarativeBase):
    pass

class Customer(Base):
    __tablename__ = "customers"
    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(unique=True)
    orders: Mapped[list["Order"]] = relationship(back_populates="customer")

class Order(Base):
    __tablename__ = "orders"
    id: Mapped[int] = mapped_column(primary_key=True)
    customer_id: Mapped[int] = mapped_column(ForeignKey("customers.id"))
    total: Mapped[float]
    customer: Mapped["Customer"] = relationship(back_populates="orders")

engine = create_engine("postgresql+psycopg://etl_svc@warehouse.internal/analytics")

with Session(engine) as session:
    stmt = select(Customer).where(Customer.email.like("%@corp.com"))
    customers = session.scalars(stmt).all()
```

See [sqlalchemy-patterns](references/sqlalchemy-patterns.md) for: engine configuration, session lifecycle, eager loading, raw SQL execution, and migration patterns with Alembic.

---

## dbt Fundamentals

dbt (data build tool) transforms raw data in the warehouse using SQL SELECT statements organized as models. Models are layered: staging cleans raw sources, intermediate models join and reshape, and mart models serve final business entities.

```sql
-- models/staging/stg_orders.sql
-- Staging models clean and rename source columns
with source as (
    select * from {{ source('ecommerce', 'raw_orders') }}
),

renamed as (
    select
        id          as order_id,
        user_id     as customer_id,
        status,
        amount      as order_total,
        created_at  as ordered_at
    from source
    where id is not null  -- filter known bad records
)

select * from renamed
```

See [dbt-model-patterns](references/dbt-model-patterns.md) for: intermediate and mart models, ref() and source() usage, incremental models, and snapshot patterns.

See [dbt-project-structure](references/dbt-project-structure.md) for: directory layout, YAML configuration, seeds, macros, packages, and testing strategies.

---

## dbt Advanced Patterns

Incremental models process only new or changed data, dramatically reducing build times on large tables. Snapshots capture slowly changing dimensions by tracking row-level changes over time.

```sql
-- models/intermediate/int_orders_enriched.sql
{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge'
    )
}}

select
    o.order_id,
    o.customer_id,
    c.segment       as customer_segment,
    o.order_total,
    o.ordered_at
from {{ ref('stg_orders') }} o
inner join {{ ref('stg_customers') }} c on o.customer_id = c.customer_id

{% if is_incremental() %}
    where o.ordered_at > (select max(ordered_at) from {{ this }})
{% endif %}
```

See [dbt-model-patterns](references/dbt-model-patterns.md) for: snapshot configuration, custom materializations, and test patterns.

---

## R Database Connections

R connects to databases through the DBI interface, with backend packages like RPostgres and odbc. The dbplyr package translates dplyr verbs into SQL, enabling analysis without writing raw queries.

```r
library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)

con <- dbConnect(
  Postgres(),
  host = "warehouse.internal",
  dbname = "analytics",
  user = "analyst_svc"
)

# dbplyr: write dplyr, execute SQL
monthly_revenue <- tbl(con, "orders") |>
  filter(region == "us-west", status == "shipped") |>
  mutate(month = date_trunc("month", order_date)) |>
  group_by(month) |>
  summarise(revenue = sum(total, na.rm = TRUE)) |>
  collect()  # pulls results into local tibble

# Parameterized raw SQL via DBI
region_summary <- dbGetQuery(con, "
  SELECT region, count(*) AS order_count
  FROM orders WHERE status = $1
", params = list("shipped"))

dbDisconnect(con)
```

See [r-db-connectors](references/r-db-connectors.md) for: connection pooling with the pool package, odbc setup, writing back to the database, and Shiny app integration.

---

## Connection Pooling and Management

Applications that handle concurrent requests must pool database connections rather than creating one per request. Pools maintain a set of reusable connections, reducing latency and preventing resource exhaustion.

```python
from sqlalchemy import create_engine

# Production pool configuration
engine = create_engine(
    "postgresql+psycopg://app_svc@db.internal/production",
    pool_size=10,          # persistent connections
    max_overflow=5,        # temporary connections above pool_size
    pool_timeout=30,       # seconds to wait for a connection
    pool_recycle=1800,     # recycle connections after 30 minutes
    pool_pre_ping=True,    # verify connection is alive before use
)
```

---

## Anti-Patterns

| Avoid | Use Instead | Why |
|---|---|---|
| `f"SELECT * FROM t WHERE id = {user_id}"` | `cursor.execute("SELECT ... WHERE id = %s", (user_id,))` | String interpolation enables SQL injection; parameterized queries are safe and allow plan caching |
| Opening a new connection per query in a web app | SQLAlchemy connection pool or pgBouncer | Connection setup is expensive (TCP + TLS + auth); pooling amortizes that cost across requests |
| `SELECT *` in production application queries | Explicit column lists: `SELECT id, name, email` | Selecting all columns wastes bandwidth, breaks when schema changes, and prevents covering indexes |
| Running dbt models with no tests | Add `not_null`, `unique`, and `accepted_values` tests | Untested models silently propagate bad data downstream; tests catch regressions before they reach dashboards |
| Storing credentials in source code | Environment variables or secrets manager (Vault, AWS SSM) | Credentials in code get committed to version control and leak; externalized secrets can be rotated independently |
| Using ORM for bulk inserts (row-by-row) | `COPY`, `executemany`, or `bulk_save_objects` | Row-by-row ORM inserts generate one INSERT per row; bulk methods are 10-100x faster for large datasets |
| `dbplyr` collect() before filtering | Filter with dplyr verbs before collect() | Collecting first pulls the entire table into R memory; filtering first pushes the WHERE clause to the database |

---

## Performance

- **Batch operations**: Use `executemany()`, `COPY FROM`, or `bulk_insert_mappings()` for inserting more than a few hundred rows. Row-by-row inserts create excessive round-trips.
- **Connection pooling**: Size pools based on expected concurrency. A pool of 10 connections with 5 overflow handles most web applications; data pipelines may need larger pools during parallel task execution.
- **Read replicas**: Route analytical queries to read replicas to keep the primary database responsive for writes. SQLAlchemy supports multiple bind engines for this pattern.
- **Lazy loading vs. eager loading**: ORM default lazy loading causes N+1 query problems. Use `joinedload()` or `selectinload()` when you know you will access related objects.
- **dbt incremental models**: Partition incremental models on the timestamp column used in the `is_incremental()` filter. This lets the warehouse prune partitions and scan only new data.
- **Query result caching**: For repeated analytical queries, cache results in Redis or application memory with a TTL rather than hitting the database on every request.
- **Connection recycling**: Set `pool_recycle` below your database's connection timeout to prevent errors from stale connections, especially behind load balancers or in cloud environments.

source: Practical patterns drawn from psycopg3, SQLAlchemy 2.0, dbt-core 1.7+, DBI/dbplyr, and Django 5.x documentation and production usage.
