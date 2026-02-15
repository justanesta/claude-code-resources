# Django ORM Patterns

Reference for Django model definitions, QuerySet operations, select_related/prefetch_related, F/Q expressions, annotations, and migrations.

---

## Model Definitions

Django models map Python classes to database tables. Each field becomes a column with appropriate constraints.

```python
from django.db import models
from django.core.validators import MinValueValidator
from decimal import Decimal

class Customer(models.Model):
    email = models.EmailField(unique=True, db_index=True)
    name = models.CharField(max_length=100)
    segment = models.CharField(
        max_length=20,
        choices=[("starter", "Starter"), ("growth", "Growth"), ("enterprise", "Enterprise")],
        default="starter",
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "customers"
        ordering = ["-created_at"]
        indexes = [models.Index(fields=["segment", "is_active"])]

class Order(models.Model):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        SHIPPED = "shipped", "Shipped"
        DELIVERED = "delivered", "Delivered"
        CANCELLED = "cancelled", "Cancelled"

    customer = models.ForeignKey(Customer, on_delete=models.CASCADE, related_name="orders")
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING, db_index=True)
    total = models.DecimalField(max_digits=10, decimal_places=2, validators=[MinValueValidator(Decimal("0.00"))])
    ordered_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "orders"
        indexes = [models.Index(fields=["customer", "status"]), models.Index(fields=["-ordered_at"])]

class LineItem(models.Model):
    order = models.ForeignKey(Order, on_delete=models.CASCADE, related_name="line_items")
    product = models.ForeignKey("Product", on_delete=models.PROTECT, related_name="line_items")
    quantity = models.PositiveIntegerField(default=1)
    unit_price = models.DecimalField(max_digits=10, decimal_places=2)

class Product(models.Model):
    sku = models.CharField(max_length=50, unique=True)
    name = models.CharField(max_length=200)
    price = models.DecimalField(max_digits=10, decimal_places=2)
    category = models.CharField(max_length=50, db_index=True)
    is_active = models.BooleanField(default=True)
```

---

## QuerySet Operations

QuerySets are lazy -- they do not hit the database until evaluated.

```python
from django.db.models import Q, F, Sum, Count, Avg, Max
from datetime import datetime

# Filtering, chaining, excluding
active_enterprise = Customer.objects.filter(is_active=True, segment="enterprise")
non_cancelled = Order.objects.exclude(status="cancelled")
large_recent = Order.objects.filter(total__gte=1000, ordered_at__gte=datetime(2025, 1, 1))

# Ordering, slicing, values
top_10 = Order.objects.order_by("-total")[:10]
emails = Customer.objects.values_list("email", flat=True)

# Efficient existence and count checks
has_enterprise = Customer.objects.filter(segment="enterprise").exists()
shipped_count = Order.objects.filter(status="shipped").count()
```

---

## select_related and prefetch_related

```python
from django.db.models import Prefetch

# select_related: single JOIN — for ForeignKey / OneToOneField
orders = Order.objects.select_related("customer").filter(status="shipped")
for order in orders:
    print(order.customer.email)  # no additional query

# prefetch_related: separate IN query — for reverse FK / ManyToMany
customers = Customer.objects.prefetch_related("orders").filter(segment="enterprise")

# Nested prefetch with custom queryset
customers = Customer.objects.prefetch_related(
    Prefetch(
        "orders",
        queryset=Order.objects.filter(status="shipped").order_by("-ordered_at"),
        to_attr="shipped_orders",
    ),
    Prefetch("orders__line_items", queryset=LineItem.objects.select_related("product")),
)
```

---

## F Expressions and Q Objects

```python
from django.db.models import F, Q, Subquery, OuterRef, Avg

# Atomic update without race condition
Order.objects.filter(pk=42).update(total=F("total") * Decimal("1.10"))

# Q objects — OR conditions and negation
results = Order.objects.filter(
    Q(status="shipped") | Q(status="delivered"),
    ~Q(customer__segment="starter"),
    ordered_at__gte=datetime(2025, 1, 1),
)

# Dynamic Q building for search/filter APIs
conditions = Q()
if region:
    conditions &= Q(region=region)
if min_total:
    conditions &= Q(total__gte=min_total)
orders = Order.objects.filter(conditions)
```

---

## Annotations and Aggregations

```python
from django.db.models import Sum, Count, Avg, Case, When, Value, DecimalField
from django.db.models.functions import TruncMonth, Coalesce

# Annotate customers with order stats
customers_with_stats = Customer.objects.annotate(
    order_count=Count("orders"),
    total_spent=Coalesce(Sum("orders__total"), Value(0), output_field=DecimalField()),
    last_order_date=Max("orders__ordered_at"),
).filter(order_count__gt=0).order_by("-total_spent")

# Monthly revenue
monthly_revenue = (
    Order.objects.filter(status__in=["shipped", "delivered"])
    .annotate(month=TruncMonth("ordered_at"))
    .values("month")
    .annotate(revenue=Sum("total"), order_count=Count("id"))
    .order_by("month")
)

# Conditional aggregation
segment_breakdown = Customer.objects.aggregate(
    total=Count("id"),
    enterprise=Count("id", filter=Q(segment="enterprise")),
    active_pct=Avg(Case(When(is_active=True, then=1.0), default=0.0, output_field=DecimalField())),
)
```

---

## Raw SQL

```python
# raw() returns model instances
orders = Order.objects.raw("SELECT * FROM orders WHERE total > %s LIMIT %s", [1000, 50])

# cursor for non-model queries
from django.db import connection
with connection.cursor() as cursor:
    cursor.execute("""
        SELECT date_trunc('month', ordered_at) AS month, count(*) AS orders, sum(total) AS revenue
        FROM orders WHERE status = %s GROUP BY 1 ORDER BY 1
    """, ["shipped"])
    columns = [col[0] for col in cursor.description]
    rows = [dict(zip(columns, row)) for row in cursor.fetchall()]
```

---

## Migrations

```bash
python manage.py makemigrations           # generate from model changes
python manage.py migrate                  # apply pending migrations
python manage.py makemigrations app --empty -n backfill  # empty migration for custom SQL
```

### Data migration

```python
from django.db import migrations

def backfill_segments(apps, schema_editor):
    Customer = apps.get_model("myapp", "Customer")
    Customer.objects.filter(segment__isnull=True).update(segment="starter")

class Migration(migrations.Migration):
    dependencies = [("myapp", "0004_add_segment_field")]
    operations = [migrations.RunPython(backfill_segments, migrations.RunPython.noop)]
```

### Custom SQL migration (concurrent index)

```python
from django.db import migrations

class Migration(migrations.Migration):
    dependencies = [("myapp", "0005_backfill")]
    operations = [
        migrations.RunSQL(
            sql="CREATE INDEX CONCURRENTLY idx_orders_cust_status ON orders (customer_id, status);",
            reverse_sql="DROP INDEX idx_orders_cust_status;",
        ),
    ]
```

---

## Custom Manager and QuerySet

```python
class OrderQuerySet(models.QuerySet):
    def shipped(self):
        return self.filter(status=Order.Status.SHIPPED)
    def high_value(self, threshold=1000):
        return self.filter(total__gte=threshold)
    def with_customer(self):
        return self.select_related("customer")

class Order(models.Model):
    # ... fields ...
    objects = OrderQuerySet.as_manager()

# Usage: Order.objects.shipped().high_value(500).with_customer()
```

---

## Edge Cases

- **N+1 queries**: Profile with `django-debug-toolbar`. Use `select_related` for forward FK, `prefetch_related` for reverse/M2M.
- **update() vs save()**: `queryset.update()` runs one SQL UPDATE, skips `save()` and signals. Use for bulk ops.
- **get_or_create races**: Under concurrency, wrap with `try/except IntegrityError`.
- **Large iterations**: Use `iterator(chunk_size=2000)` to avoid loading full result sets into memory.
- **Timezone**: With `USE_TZ=True`, always use `timezone.now()` instead of `datetime.now()`.
- **Large table migrations**: Use `RunSQL` with `CONCURRENTLY` for index creation on PostgreSQL.
