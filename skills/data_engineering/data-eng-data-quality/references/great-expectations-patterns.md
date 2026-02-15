# Great Expectations Patterns

## Expectation Suite Construction

Build suites programmatically for repeatable, version-controlled validation.

```python
import great_expectations as gx

context = gx.get_context()

# Create a suite for financial transaction validation
suite = context.suites.add(
    gx.ExpectationSuite(name="transaction_validation_suite")
)

# Completeness checks -- no nulls in critical fields
for column in ["transaction_id", "account_id", "amount", "timestamp"]:
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToNotBeNull(column=column)
    )

# Uniqueness
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeUnique(column="transaction_id")
)

# Range validation
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeBetween(
        column="amount", min_value=-1_000_000, max_value=1_000_000
    )
)

# Value set validation
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeInSet(
        column="transaction_type",
        value_set=["credit", "debit", "transfer", "refund"],
    )
)

# Row count bounds
suite.add_expectation(
    gx.expectations.ExpectTableRowCountToBeBetween(
        min_value=1000, max_value=5_000_000
    )
)

# Column count stability
suite.add_expectation(
    gx.expectations.ExpectTableColumnCountToEqual(value=12)
)
```

## Multi-Datasource Checkpoint

Validate data across multiple sources in a single checkpoint run.

```python
import great_expectations as gx

context = gx.get_context()

# Postgres source
pg_datasource = context.data_sources.add_postgres(
    name="warehouse",
    connection_string="postgresql+psycopg2://user:pass@host:5432/warehouse",
)
pg_asset = pg_datasource.add_table_asset(
    name="orders", table_name="orders"
)
pg_batch = pg_asset.add_batch_definition_whole_table("orders_full")

# S3 Parquet source
s3_datasource = context.data_sources.add_pandas_s3(
    name="data_lake",
    bucket="analytics-lake",
    boto3_options={"region_name": "us-east-1"},
)
s3_asset = s3_datasource.add_csv_asset(
    name="events",
    prefix="raw/events/",
)
s3_batch = s3_asset.add_batch_definition_whole_dataframe("events_full")

# Create validation definitions for each
orders_validation = context.validation_definitions.add(
    gx.ValidationDefinition(
        name="orders_validation",
        data=pg_batch,
        suite=context.suites.get("orders_suite"),
    )
)

events_validation = context.validation_definitions.add(
    gx.ValidationDefinition(
        name="events_validation",
        data=s3_batch,
        suite=context.suites.get("events_suite"),
    )
)

# Single checkpoint runs both validations
checkpoint = context.checkpoints.add(
    gx.Checkpoint(
        name="cross_source_checkpoint",
        validation_definitions=[orders_validation, events_validation],
    )
)

result = checkpoint.run()
print(f"Overall success: {result.success}")
for name, run_result in result.run_results.items():
    print(f"  {name}: {'PASS' if run_result.success else 'FAIL'}")
```

## Custom Expectations

Create domain-specific expectations for business logic that built-in expectations cannot cover.

```python
from great_expectations.expectations import ExpectColumnValuesToNotBeNull
from great_expectations.core import ExpectationConfiguration
import great_expectations as gx


class ExpectColumnCurrencyCodeToBeValid(gx.expectations.Expectation):
    """Validate ISO 4217 currency codes."""

    column: str
    valid_currencies: list[str] = [
        "USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF", "CNY",
    ]

    description = "Expect column values to be valid ISO 4217 currency codes"

    def _validate(self, metrics, runtime_configuration=None, execution_engine=None):
        column_values = metrics.get("column_values.nonnull")
        invalid = [v for v in column_values if v not in self.valid_currencies]
        success = len(invalid) == 0
        return {
            "success": success,
            "result": {
                "observed_value": f"{len(invalid)} invalid codes found",
                "unexpected_list": invalid[:20],
            },
        }


class ExpectTransactionAmountConsistency(gx.expectations.Expectation):
    """Validate that debit amounts are negative and credit amounts are positive."""

    amount_column: str
    type_column: str
    description = "Expect transaction amounts to match transaction type sign convention"

    def _validate(self, metrics, runtime_configuration=None, execution_engine=None):
        # Access batch data for multi-column validation
        df = metrics.get("table.head", n=None)
        violations = []
        for _, row in df.iterrows():
            if row[self.type_column] == "debit" and row[self.amount_column] > 0:
                violations.append(
                    f"Row {row.name}: debit with positive amount {row[self.amount_column]}"
                )
            elif row[self.type_column] == "credit" and row[self.amount_column] < 0:
                violations.append(
                    f"Row {row.name}: credit with negative amount {row[self.amount_column]}"
                )
        return {
            "success": len(violations) == 0,
            "result": {
                "observed_value": f"{len(violations)} inconsistencies",
                "unexpected_list": violations[:10],
            },
        }
```

## Conditional and Parameterized Expectations

Apply expectations that adapt based on data context or runtime parameters.

```python
import great_expectations as gx

context = gx.get_context()

# Different suites for different data segments
def build_regional_suite(region: str) -> gx.ExpectationSuite:
    """Build region-specific validation rules."""
    suite = context.suites.add(
        gx.ExpectationSuite(name=f"orders_{region}_suite")
    )

    # Universal checks
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToNotBeNull(column="order_id")
    )
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToBeUnique(column="order_id")
    )

    # Region-specific checks
    if region == "us":
        suite.add_expectation(
            gx.expectations.ExpectColumnValuesToMatchRegex(
                column="zip_code", regex=r"^\d{5}(-\d{4})?$"
            )
        )
        suite.add_expectation(
            gx.expectations.ExpectColumnValuesToBeInSet(
                column="currency", value_set=["USD"]
            )
        )
    elif region == "eu":
        suite.add_expectation(
            gx.expectations.ExpectColumnValuesToBeInSet(
                column="currency",
                value_set=["EUR", "GBP", "CHF", "SEK", "NOK", "DKK", "PLN"],
            )
        )
        # EU orders require GDPR consent flag
        suite.add_expectation(
            gx.expectations.ExpectColumnValuesToNotBeNull(column="gdpr_consent")
        )

    return suite
```

## Data Docs Configuration

Generate and serve human-readable validation reports for stakeholders.

```python
import great_expectations as gx

context = gx.get_context()

# Data Docs are configured in great_expectations.yml:
# data_docs_sites:
#   local_site:
#     class_name: SiteBuilder
#     store_backend:
#       class_name: TupleFilesystemStoreBackend
#       base_directory: uncommitted/data_docs/local_site/
#   s3_site:
#     class_name: SiteBuilder
#     store_backend:
#       class_name: TupleS3StoreBackend
#       bucket: my-data-docs-bucket
#       prefix: data_docs/

# Build docs after checkpoint run
checkpoint = context.checkpoints.get("daily_checkpoint")
result = checkpoint.run()

# Build and optionally open Data Docs
context.build_data_docs()

# Programmatic access to results for downstream reporting
for validation_id, run_result in result.run_results.items():
    stats = run_result.statistics
    print(f"Suite: {validation_id}")
    print(f"  Evaluated: {stats['evaluated_expectations']}")
    print(f"  Successful: {stats['successful_expectations']}")
    print(f"  Failed: {stats['unsuccessful_expectations']}")
    print(f"  Success rate: {stats['success_percent']:.1f}%")
```

## Pipeline Integration Pattern

Integrate Great Expectations checkpoints into orchestrated pipelines with proper error handling.

```python
from prefect import task, flow
import great_expectations as gx
import pandas as pd

@task(retries=2, retry_delay_seconds=30)
def run_quality_checkpoint(
    checkpoint_name: str,
    batch_parameters: dict | None = None,
) -> dict:
    """Run a GX checkpoint and return structured results."""
    context = gx.get_context()
    checkpoint = context.checkpoints.get(checkpoint_name)
    result = checkpoint.run(batch_parameters=batch_parameters)

    summary = {
        "success": result.success,
        "checkpoint": checkpoint_name,
        "validations": {},
    }

    for name, run_result in result.run_results.items():
        summary["validations"][str(name)] = {
            "success": run_result.success,
            "statistics": run_result.statistics,
        }

    return summary


@flow(name="Validated Ingestion Pipeline")
def validated_ingestion(source_path: str, target_table: str):
    """Ingest data with pre- and post-load quality checks."""

    # Pre-load: validate source data
    pre_result = run_quality_checkpoint("source_data_checkpoint")
    if not pre_result["success"]:
        raise ValueError(f"Source data quality failed: {pre_result}")

    # Load data
    df = pd.read_parquet(source_path)
    load_to_warehouse(df, target_table)

    # Post-load: validate warehouse table
    post_result = run_quality_checkpoint("warehouse_table_checkpoint")
    if not post_result["success"]:
        # Quarantine bad data instead of failing silently
        quarantine_table(target_table)
        raise ValueError(f"Post-load quality failed: {post_result}")

    return {"pre_check": pre_result, "post_check": post_result}
```

## Edge Cases and Gotchas

### Empty DataFrames

```python
# Always check for empty data before running expectations
suite.add_expectation(
    gx.expectations.ExpectTableRowCountToBeBetween(min_value=1)
)
# This should be the FIRST expectation -- if the table is empty,
# column-level expectations will pass vacuously (no rows to violate)
```

### Type Coercion Surprises

```python
# Pandas may read "123" as int64 or object depending on mixed types
# Always add explicit type expectations
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeOfType(
        column="customer_id", type_="int64"
    )
)

# For dates, validate the format before downstream parsing
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToMatchStrftimeFormat(
        column="event_date", strftime_format="%Y-%m-%d"
    )
)
```

### Mostly Parameter for Soft Expectations

```python
# Allow up to 2% nulls in non-critical fields
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToNotBeNull(
        column="phone_number", mostly=0.98
    )
)

# Allow up to 1% values outside expected set (new categories appear)
suite.add_expectation(
    gx.expectations.ExpectColumnValuesToBeInSet(
        column="product_category",
        value_set=["electronics", "clothing", "food", "home"],
        mostly=0.99,
    )
)
```
