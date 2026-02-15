# SQLAlchemy Patterns

Reference for SQLAlchemy 2.0: engine configuration, ORM models, relationships, session management, queries, and raw SQL.

---

## Engine Configuration

```python
from sqlalchemy import create_engine

engine = create_engine(
    "postgresql+psycopg://user:pass@host:5432/dbname",
    pool_size=10, max_overflow=5, pool_pre_ping=True, pool_recycle=1800,
    echo=False,
    connect_args={"options": "-c statement_timeout=30000"},
)

# Engine from environment variables
import os
from sqlalchemy import URL

url = URL.create(
    drivername="postgresql+psycopg",
    username=os.environ["DB_USER"], password=os.environ["DB_PASSWORD"],
    host=os.environ["DB_HOST"], port=int(os.environ.get("DB_PORT", 5432)),
    database=os.environ["DB_NAME"],
)
engine = create_engine(url, pool_pre_ping=True)
```

---

## ORM Models -- Declarative Mapping (2.0 Style)

```python
from datetime import datetime
from decimal import Decimal
from typing import Optional
from sqlalchemy import String, Numeric, ForeignKey, text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship

class Base(DeclarativeBase):
    pass

class Customer(Base):
    __tablename__ = "customers"
    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(100))
    segment: Mapped[Optional[str]] = mapped_column(String(50), default=None)
    created_at: Mapped[datetime] = mapped_column(server_default=text("now()"))
    orders: Mapped[list["Order"]] = relationship(back_populates="customer", cascade="all, delete-orphan")

class Order(Base):
    __tablename__ = "orders"
    id: Mapped[int] = mapped_column(primary_key=True)
    customer_id: Mapped[int] = mapped_column(ForeignKey("customers.id"))
    status: Mapped[str] = mapped_column(String(20), default="pending")
    total: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    ordered_at: Mapped[datetime] = mapped_column(server_default=text("now()"))
    customer: Mapped["Customer"] = relationship(back_populates="orders")
    line_items: Mapped[list["LineItem"]] = relationship(back_populates="order")

class LineItem(Base):
    __tablename__ = "line_items"
    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"))
    product_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    quantity: Mapped[int]
    unit_price: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    order: Mapped["Order"] = relationship(back_populates="line_items")
    product: Mapped["Product"] = relationship()

class Product(Base):
    __tablename__ = "products"
    id: Mapped[int] = mapped_column(primary_key=True)
    sku: Mapped[str] = mapped_column(String(50), unique=True)
    name: Mapped[str] = mapped_column(String(200))
    price: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    is_active: Mapped[bool] = mapped_column(default=True)
```

---

## Session Lifecycle

```python
from sqlalchemy.orm import Session, sessionmaker

# Context manager (preferred)
with Session(engine) as session:
    customer = Customer(email="alice@corp.com", name="Alice")
    session.add(customer)
    session.commit()

# sessionmaker for repeated use
SessionLocal = sessionmaker(bind=engine)

# begin() auto-commits on success, rolls back on exception
with Session(engine) as session, session.begin():
    session.add(Order(customer_id=1, total=Decimal("150.00")))
```

### FastAPI dependency injection

```python
from fastapi import Depends, FastAPI

app = FastAPI()

def get_db():
    with SessionLocal() as session:
        yield session

@app.get("/customers/{customer_id}")
def read_customer(customer_id: int, db: Session = Depends(get_db)):
    stmt = select(Customer).where(Customer.id == customer_id)
    return db.scalars(stmt).one_or_none()
```

---

## Querying -- 2.0 Select Style

```python
from sqlalchemy import select, func, and_, desc, exists

# Filter and aggregate
stmt = (
    select(Customer.segment, func.count(Order.id).label("order_count"),
           func.sum(Order.total).label("revenue"))
    .join(Order, Customer.id == Order.customer_id)
    .group_by(Customer.segment)
    .order_by(desc("revenue"))
)
rows = session.execute(stmt).all()

# Subquery
high_value = select(Order.customer_id).where(Order.total > 1000).distinct().subquery()
stmt = select(Customer).where(Customer.id.in_(select(high_value.c.customer_id)))

# Exists
has_orders = exists().where(Order.customer_id == Customer.id)
stmt = select(Customer).where(has_orders)
```

---

## Eager Loading -- Avoiding N+1 Queries

```python
from sqlalchemy.orm import joinedload, selectinload

# joinedload: single JOIN -- best for many-to-one
stmt = select(Order).options(joinedload(Order.customer)).where(Order.id == 42)

# selectinload: separate IN query -- best for one-to-many
stmt = select(Customer).options(selectinload(Customer.orders)).where(Customer.segment == "enterprise")

# Nested eager loading
stmt = select(Customer).options(
    selectinload(Customer.orders).selectinload(Order.line_items).joinedload(LineItem.product)
)
```

---

## Raw SQL Execution

```python
from sqlalchemy import text

with Session(engine) as session:
    result = session.execute(
        text("""
            SELECT date_trunc('month', ordered_at) AS month, count(*) AS orders, sum(total) AS revenue
            FROM orders WHERE status = :status AND ordered_at >= :start
            GROUP BY 1 ORDER BY 1
        """),
        {"status": "shipped", "start": datetime(2025, 1, 1)},
    )
    for row in result:
        print(row.month, row.orders, row.revenue)
```

---

## Alembic Migrations

```bash
alembic init alembic
alembic revision --autogenerate -m "add segment column"
alembic upgrade head
alembic downgrade -1
```

```python
from alembic import op
import sqlalchemy as sa

def upgrade():
    op.add_column("customers", sa.Column("segment", sa.String(50), nullable=True))
    op.create_index("ix_customers_segment", "customers", ["segment"])

def downgrade():
    op.drop_index("ix_customers_segment", table_name="customers")
    op.drop_column("customers", "segment")
```

---

## Bulk Operations

```python
from sqlalchemy import insert, update

# Bulk insert with Core
with engine.begin() as conn:
    conn.execute(insert(Product), [
        {"sku": "W-001", "name": "Widget A", "price": Decimal("9.99")},
        {"sku": "W-002", "name": "Widget B", "price": Decimal("14.99")},
    ])

# Bulk update
with Session(engine) as session, session.begin():
    session.execute(update(Product).where(Product.is_active == False).values(price=Decimal("0.00")))
```

---

## Edge Cases

- **DetachedInstanceError**: Accessing lazy-loaded relationships after session close. Eagerly load what you need.
- **Implicit autoflush**: Session flushes before queries by default. Use `autoflush=False` if this causes issues.
- **Connection exhaustion**: `TimeoutError` on pool means connections are not being returned. Use context managers.
- **PostgreSQL enums**: Adding values requires raw `ALTER TYPE ... ADD VALUE` in Alembic.
- **Schema reflection**: Use `automap_base()` to reflect existing tables you do not control.
