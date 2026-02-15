# Python Database Connectors

Reference for connecting Python to relational databases using psycopg3, mysql-connector-python, pyodbc, and parameterized query patterns.

---

## psycopg 3 (PostgreSQL)

### Basic connection and queries

```python
import psycopg
from psycopg.rows import dict_row, class_row
from dataclasses import dataclass

with psycopg.connect(
    "host=warehouse.internal dbname=analytics user=etl_svc",
    row_factory=dict_row,
) as conn:
    # Parameterized SELECT — %s positional, %(name)s named
    rows = conn.execute(
        "SELECT order_id, total FROM orders WHERE region = %s AND status = %s",
        ("us-west", "shipped"),
    ).fetchall()

    # Named parameters
    row = conn.execute(
        "SELECT * FROM customers WHERE email = %(email)s",
        {"email": "alice@corp.com"},
    ).fetchone()

    # Returning dataclass instances
    @dataclass
    class Order:
        order_id: int
        customer_id: int
        total: float

    with conn.cursor(row_factory=class_row(Order)) as cur:
        cur.execute("SELECT order_id, customer_id, total FROM orders LIMIT 10")
        orders: list[Order] = cur.fetchall()
```

### Async connections

```python
import asyncio
import psycopg

async def fetch_active_customers():
    async with await psycopg.AsyncConnection.connect(
        "host=warehouse.internal dbname=analytics user=etl_svc"
    ) as conn:
        async with conn.cursor() as cur:
            await cur.execute("SELECT id, email FROM customers WHERE is_active = %s", (True,))
            return await cur.fetchall()

customers = asyncio.run(fetch_active_customers())
```

### Connection pooling

```python
from psycopg_pool import ConnectionPool

pool = ConnectionPool(
    conninfo="host=warehouse.internal dbname=analytics user=app_svc",
    min_size=5, max_size=20, max_idle=300, max_lifetime=1800,
)

def handle_request(user_id: int):
    with pool.connection() as conn:
        return conn.execute("SELECT * FROM users WHERE id = %s", (user_id,)).fetchone()
```

### COPY for bulk data loading

```python
with psycopg.connect(conninfo) as conn:
    records = [(1001, 42, 150.00), (1002, 43, 275.50)]
    with conn.cursor() as cur:
        with cur.copy("COPY orders (order_id, customer_id, total) FROM STDIN") as copy:
            for record in records:
                copy.write_row(record)
    conn.commit()
```

---

## mysql-connector-python (MySQL / MariaDB)

```python
import mysql.connector

config = {
    "host": "mysql.internal", "database": "app_db",
    "user": "app_svc", "password": "secret",
    "charset": "utf8mb4", "autocommit": False,
}

with mysql.connector.connect(**config) as conn:
    with conn.cursor(dictionary=True) as cur:
        cur.execute("SELECT id, name FROM users WHERE status = %s LIMIT %s", ("active", 100))
        users = cur.fetchall()

    # Bulk insert
    with conn.cursor() as cur:
        cur.executemany(
            "INSERT INTO products (sku, name, price) VALUES (%s, %s, %s)",
            [("W-001", "Widget A", 9.99), ("W-002", "Widget B", 14.99)],
        )
        conn.commit()
```

---

## pyodbc (SQL Server, ODBC Sources)

```python
import pyodbc

conn_str = (
    "DRIVER={ODBC Driver 18 for SQL Server};"
    "SERVER=sqlserver.internal,1433;DATABASE=app_db;"
    "UID=app_svc;PWD=secret;Encrypt=yes;"
)

with pyodbc.connect(conn_str) as conn:
    cursor = conn.cursor()
    # pyodbc uses ? for parameter placeholders
    cursor.execute("SELECT order_id, total FROM orders WHERE region = ? AND status = ?", "us-west", "shipped")
    rows = cursor.fetchall()

    # Stored procedure
    cursor.execute("EXEC usp_GetCustomerOrders @CustomerId = ?, @StartDate = ?", 42, "2025-01-01")

    # Fast bulk insert
    cursor.fast_executemany = True
    cursor.executemany("INSERT INTO products (sku, name, price) VALUES (?, ?, ?)",
                       [("W-001", "Widget A", 9.99), ("W-002", "Widget B", 14.99)])
    conn.commit()
```

---

## pandas Integration

```python
import pandas as pd
from sqlalchemy import create_engine

engine = create_engine("postgresql+psycopg://etl@warehouse/analytics")

# Read with parameterized query
df = pd.read_sql("SELECT * FROM orders WHERE status = %(s)s", engine, params={"s": "shipped"})

# Write DataFrame to database
df.to_sql("monthly_revenue", engine, schema="reporting", if_exists="replace",
          index=False, method="multi", chunksize=5000)

# Chunked reading for large tables
for chunk in pd.read_sql("SELECT * FROM large_table", engine, chunksize=50_000):
    process(chunk)
```

---

## Parameterized Query Reference

| Library | Placeholder | Example |
|---|---|---|
| psycopg 3 | `%s` / `%(name)s` | `execute("... WHERE id = %s", (42,))` |
| mysql-connector | `%s` | `execute("... WHERE id = %s", (42,))` |
| pyodbc | `?` | `execute("... WHERE id = ?", 42)` |
| SQLAlchemy text() | `:name` | `execute(text("... WHERE id = :id"), {"id": 42})` |
| sqlite3 | `?` / `:name` | `execute("... WHERE id = ?", (42,))` |

---

## Error Handling

```python
import psycopg
from psycopg import errors as pg_errors

def safe_insert_customer(conn, email: str, name: str) -> int | None:
    try:
        row = conn.execute(
            "INSERT INTO customers (email, name) VALUES (%s, %s) RETURNING id",
            (email, name),
        ).fetchone()
        conn.commit()
        return row[0]
    except pg_errors.UniqueViolation:
        conn.rollback()
        row = conn.execute("SELECT id FROM customers WHERE email = %s", (email,)).fetchone()
        return row[0] if row else None
    except pg_errors.OperationalError as e:
        conn.rollback()
        raise
```

---

## Connection String Security

```python
import os

# Environment variables
conn = psycopg.connect(
    host=os.environ["DB_HOST"], dbname=os.environ["DB_NAME"],
    user=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"],
)

# AWS Secrets Manager
import boto3, json

def get_db_credentials(secret_name: str) -> dict:
    client = boto3.client("secretsmanager")
    response = client.get_secret_value(SecretId=secret_name)
    return json.loads(response["SecretString"])

creds = get_db_credentials("prod/analytics/db")
conn = psycopg.connect(host=creds["host"], dbname=creds["dbname"],
                        user=creds["username"], password=creds["password"])
```
