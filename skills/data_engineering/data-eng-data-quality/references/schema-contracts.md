# Schema Contracts

## Contract Definition Framework

Define schemas as versioned, enforceable contracts between data producers and consumers.

```python
from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Optional
import json
from pathlib import Path

class DataType(Enum):
    STRING = "string"
    INTEGER = "integer"
    FLOAT = "float"
    BOOLEAN = "boolean"
    TIMESTAMP = "timestamp"
    DATE = "date"
    DECIMAL = "decimal"
    ARRAY = "array"
    MAP = "map"

class CompatibilityMode(Enum):
    BACKWARD = "backward"       # New schema reads old data
    FORWARD = "forward"         # Old schema reads new data
    FULL = "full"               # Both directions
    NONE = "none"               # No compatibility guarantee

@dataclass
class ColumnContract:
    name: str
    data_type: DataType
    nullable: bool = False
    description: str = ""
    constraints: dict[str, Any] = field(default_factory=dict)
    # constraints can include: min_value, max_value, pattern, enum_values, etc.

@dataclass
class SchemaContract:
    name: str
    version: int
    owner: str                  # Team or service that owns the schema
    compatibility: CompatibilityMode
    columns: list[ColumnContract]
    primary_key: list[str] = field(default_factory=list)
    description: str = ""

    def to_dict(self) -> dict:
        return {
            "name": self.name,
            "version": self.version,
            "owner": self.owner,
            "compatibility": self.compatibility.value,
            "primary_key": self.primary_key,
            "columns": [
                {
                    "name": c.name,
                    "data_type": c.data_type.value,
                    "nullable": c.nullable,
                    "description": c.description,
                    "constraints": c.constraints,
                }
                for c in self.columns
            ],
        }

    def save(self, path: Path):
        path.write_text(json.dumps(self.to_dict(), indent=2))

    @classmethod
    def load(cls, path: Path) -> "SchemaContract":
        data = json.loads(path.read_text())
        columns = [
            ColumnContract(
                name=c["name"],
                data_type=DataType(c["data_type"]),
                nullable=c.get("nullable", False),
                description=c.get("description", ""),
                constraints=c.get("constraints", {}),
            )
            for c in data["columns"]
        ]
        return cls(
            name=data["name"],
            version=data["version"],
            owner=data["owner"],
            compatibility=CompatibilityMode(data["compatibility"]),
            columns=columns,
            primary_key=data.get("primary_key", []),
        )
```

## Contract Validation Against DataFrames

```python
import pandas as pd
from dataclasses import dataclass

TYPE_MAPPING = {
    DataType.STRING: ["object", "string"],
    DataType.INTEGER: ["int64", "int32", "Int64", "Int32"],
    DataType.FLOAT: ["float64", "float32", "Float64"],
    DataType.BOOLEAN: ["bool", "boolean"],
    DataType.TIMESTAMP: ["datetime64[ns]", "datetime64[ns, UTC]"],
    DataType.DATE: ["object", "datetime64[ns]"],  # dates often stored as object
    DataType.DECIMAL: ["float64", "object"],       # Decimal type varies
}

@dataclass
class ContractViolation:
    column: str
    violation_type: str
    message: str
    severity: str  # "error" or "warning"

def validate_dataframe(
    df: pd.DataFrame, contract: SchemaContract
) -> list[ContractViolation]:
    """Validate a DataFrame against a schema contract."""
    violations = []

    # Check required columns exist
    contract_cols = {c.name for c in contract.columns}
    df_cols = set(df.columns)

    missing = contract_cols - df_cols
    for col in missing:
        col_contract = next(c for c in contract.columns if c.name == col)
        if not col_contract.nullable:
            violations.append(ContractViolation(
                column=col,
                violation_type="missing_column",
                message=f"Required column '{col}' is missing",
                severity="error",
            ))

    # Check for unexpected columns
    extra = df_cols - contract_cols
    if extra and contract.compatibility != CompatibilityMode.FORWARD:
        violations.append(ContractViolation(
            column="*",
            violation_type="extra_columns",
            message=f"Unexpected columns not in contract: {extra}",
            severity="warning",
        ))

    # Validate types and constraints for present columns
    for col_contract in contract.columns:
        if col_contract.name not in df.columns:
            continue

        col = col_contract.name
        series = df[col]

        # Type check
        valid_types = TYPE_MAPPING.get(col_contract.data_type, [])
        if str(series.dtype) not in valid_types:
            violations.append(ContractViolation(
                column=col,
                violation_type="wrong_type",
                message=f"Expected {col_contract.data_type.value}, got {series.dtype}",
                severity="error",
            ))

        # Nullability check
        if not col_contract.nullable and series.isna().any():
            null_count = series.isna().sum()
            violations.append(ContractViolation(
                column=col,
                violation_type="unexpected_nulls",
                message=f"Found {null_count} nulls in non-nullable column",
                severity="error",
            ))

        # Constraint checks
        constraints = col_contract.constraints
        if "min_value" in constraints and series.min() < constraints["min_value"]:
            violations.append(ContractViolation(
                column=col,
                violation_type="constraint_violation",
                message=f"Min value {series.min()} < {constraints['min_value']}",
                severity="error",
            ))
        if "max_value" in constraints and series.max() > constraints["max_value"]:
            violations.append(ContractViolation(
                column=col,
                violation_type="constraint_violation",
                message=f"Max value {series.max()} > {constraints['max_value']}",
                severity="error",
            ))
        if "enum_values" in constraints:
            invalid = set(series.dropna().unique()) - set(constraints["enum_values"])
            if invalid:
                violations.append(ContractViolation(
                    column=col,
                    violation_type="constraint_violation",
                    message=f"Invalid values: {invalid}",
                    severity="error",
                ))

    # Primary key validation
    if contract.primary_key:
        pk_cols = [c for c in contract.primary_key if c in df.columns]
        if pk_cols:
            duplicates = df.duplicated(subset=pk_cols, keep=False).sum()
            if duplicates > 0:
                violations.append(ContractViolation(
                    column=",".join(pk_cols),
                    violation_type="pk_violation",
                    message=f"Primary key has {duplicates} duplicate rows",
                    severity="error",
                ))

    return violations
```

## Schema Evolution Checker

Validate that schema changes respect the declared compatibility mode.

```python
def check_schema_evolution(
    old: SchemaContract, new: SchemaContract
) -> list[str]:
    """Check if evolving from old to new schema is safe."""
    issues = []
    compat = old.compatibility

    old_cols = {c.name: c for c in old.columns}
    new_cols = {c.name: c for c in new.columns}

    # Removed columns
    removed = set(old_cols) - set(new_cols)
    if removed:
        if compat in (CompatibilityMode.FORWARD, CompatibilityMode.FULL):
            issues.append(
                f"BREAKING: Removing columns {removed} violates {compat.value} "
                f"compatibility. Old consumers still expect these columns."
            )

    # Added required (non-nullable) columns
    added = set(new_cols) - set(old_cols)
    for col_name in added:
        col = new_cols[col_name]
        if not col.nullable:
            if compat in (CompatibilityMode.BACKWARD, CompatibilityMode.FULL):
                issues.append(
                    f"BREAKING: Adding required column '{col_name}' violates "
                    f"{compat.value} compatibility. Old data won't have this column. "
                    f"Make it nullable or provide a default."
                )

    # Type changes
    for col_name in set(old_cols) & set(new_cols):
        old_type = old_cols[col_name].data_type
        new_type = new_cols[col_name].data_type
        if old_type != new_type:
            if is_safe_widening(old_type, new_type):
                if compat in (CompatibilityMode.FORWARD, CompatibilityMode.FULL):
                    issues.append(
                        f"WARNING: Widening '{col_name}' from {old_type.value} to "
                        f"{new_type.value} may break old consumers in {compat.value} mode."
                    )
            else:
                issues.append(
                    f"BREAKING: Changing '{col_name}' from {old_type.value} to "
                    f"{new_type.value} is not a safe type change."
                )

    # Nullability changes
    for col_name in set(old_cols) & set(new_cols):
        was_nullable = old_cols[col_name].nullable
        now_nullable = new_cols[col_name].nullable
        if was_nullable and not now_nullable:
            issues.append(
                f"BREAKING: Making '{col_name}' non-nullable. "
                f"Existing data may contain nulls."
            )

    return issues


SAFE_WIDENINGS = {
    (DataType.INTEGER, DataType.FLOAT),
    (DataType.INTEGER, DataType.DECIMAL),
    (DataType.FLOAT, DataType.DECIMAL),
    (DataType.DATE, DataType.TIMESTAMP),
}

def is_safe_widening(old_type: DataType, new_type: DataType) -> bool:
    """Check if a type change is a safe widening conversion."""
    return (old_type, new_type) in SAFE_WIDENINGS
```

## Contract Testing in CI/CD

Run schema contract tests as part of your CI pipeline to catch breaking changes before deployment.

```python
import pytest
from pathlib import Path

class TestSchemaContracts:
    """Run as part of CI to validate schema changes."""

    @pytest.fixture
    def current_contract(self) -> SchemaContract:
        return SchemaContract.load(Path("contracts/customers_v3.json"))

    @pytest.fixture
    def proposed_contract(self) -> SchemaContract:
        return SchemaContract.load(Path("contracts/customers_v4.json"))

    def test_backward_compatibility(self, current_contract, proposed_contract):
        """New schema must be able to read old data."""
        issues = check_schema_evolution(current_contract, proposed_contract)
        breaking = [i for i in issues if i.startswith("BREAKING")]
        assert not breaking, f"Breaking changes detected:\n" + "\n".join(breaking)

    def test_no_removed_required_columns(self, current_contract, proposed_contract):
        """Required columns cannot be removed."""
        old_required = {
            c.name for c in current_contract.columns if not c.nullable
        }
        new_cols = {c.name for c in proposed_contract.columns}
        removed_required = old_required - new_cols
        assert not removed_required, (
            f"Required columns removed: {removed_required}"
        )

    def test_new_columns_have_defaults(self, current_contract, proposed_contract):
        """New required columns must have a default or be nullable."""
        old_cols = {c.name for c in current_contract.columns}
        for col in proposed_contract.columns:
            if col.name not in old_cols and not col.nullable:
                assert "default" in col.constraints, (
                    f"New required column '{col.name}' must have a default value"
                )

    def test_primary_key_unchanged(self, current_contract, proposed_contract):
        """Primary key columns should not change."""
        assert current_contract.primary_key == proposed_contract.primary_key, (
            f"Primary key changed from {current_contract.primary_key} "
            f"to {proposed_contract.primary_key}"
        )

    def test_contract_validates_sample_data(self, proposed_contract):
        """Proposed contract must validate against sample data."""
        import pandas as pd
        sample = pd.read_parquet("tests/fixtures/customers_sample.parquet")
        violations = validate_dataframe(sample, proposed_contract)
        errors = [v for v in violations if v.severity == "error"]
        assert not errors, (
            f"Contract violations on sample data:\n"
            + "\n".join(f"  {v.column}: {v.message}" for v in errors)
        )
```

## Avro Schema Registry Integration

Use a schema registry for centralized contract management with Kafka-based pipelines.

```python
from confluent_kafka.schema_registry import SchemaRegistryClient, Schema
from confluent_kafka.schema_registry.avro import AvroSerializer
import json

class SchemaRegistryContractManager:
    """Manage schema contracts via Confluent Schema Registry."""

    def __init__(self, registry_url: str):
        self.client = SchemaRegistryClient({"url": registry_url})

    def register_contract(
        self, subject: str, schema_dict: dict, compatibility: str = "BACKWARD"
    ) -> int:
        """Register a new schema version for a subject."""
        # Set compatibility level
        self.client.set_compatibility(subject_name=subject, level=compatibility)

        avro_schema = Schema(json.dumps(schema_dict), schema_type="AVRO")
        schema_id = self.client.register_schema(subject, avro_schema)
        return schema_id

    def check_compatibility(self, subject: str, new_schema: dict) -> bool:
        """Check if a new schema is compatible with existing versions."""
        avro_schema = Schema(json.dumps(new_schema), schema_type="AVRO")
        return self.client.test_compatibility(subject, avro_schema)

    def get_latest_contract(self, subject: str) -> dict:
        """Get the latest schema version for a subject."""
        registered = self.client.get_latest_version(subject)
        return json.loads(registered.schema.schema_str)


# Example: Customer event schema
customer_avro_schema = {
    "type": "record",
    "name": "CustomerEvent",
    "namespace": "com.example.events",
    "fields": [
        {"name": "customer_id", "type": "long"},
        {"name": "email", "type": "string"},
        {"name": "event_type", "type": {
            "type": "enum",
            "name": "EventType",
            "symbols": ["CREATED", "UPDATED", "DELETED"]
        }},
        {"name": "timestamp", "type": {"type": "long", "logicalType": "timestamp-millis"}},
        # Optional field with default -- backward compatible addition
        {"name": "source_system", "type": ["null", "string"], "default": None},
    ],
}

registry = SchemaRegistryContractManager("http://schema-registry:8081")
schema_id = registry.register_contract(
    "customer-events-value", customer_avro_schema, "BACKWARD"
)
```

## Handling Nullable and Default Value Evolution

Safe patterns for adding and modifying columns without breaking consumers.

```python
def safe_add_column(
    contract: SchemaContract,
    column: ColumnContract,
) -> SchemaContract:
    """Safely add a column to a contract respecting compatibility."""
    if contract.compatibility in (
        CompatibilityMode.BACKWARD, CompatibilityMode.FULL
    ):
        if not column.nullable and "default" not in column.constraints:
            raise ValueError(
                f"Cannot add required column '{column.name}' without a default "
                f"value under {contract.compatibility.value} compatibility. "
                f"Either make it nullable or provide a default."
            )

    new_columns = contract.columns + [column]
    return SchemaContract(
        name=contract.name,
        version=contract.version + 1,
        owner=contract.owner,
        compatibility=contract.compatibility,
        columns=new_columns,
        primary_key=contract.primary_key,
    )


def safe_deprecate_column(
    contract: SchemaContract,
    column_name: str,
    deprecation_version: int,
    removal_version: int,
) -> SchemaContract:
    """Mark a column as deprecated with a planned removal version."""
    new_columns = []
    for col in contract.columns:
        if col.name == column_name:
            col.description = (
                f"[DEPRECATED v{deprecation_version}] "
                f"Will be removed in v{removal_version}. "
                f"{col.description}"
            )
            col.nullable = True  # Make nullable during deprecation
        new_columns.append(col)

    return SchemaContract(
        name=contract.name,
        version=contract.version + 1,
        owner=contract.owner,
        compatibility=contract.compatibility,
        columns=new_columns,
        primary_key=contract.primary_key,
    )
```

## Edge Cases

### Nested Schema Contracts (JSON Columns)

```python
@dataclass
class NestedColumnContract(ColumnContract):
    """Contract for a JSON/struct column with nested fields."""
    nested_schema: dict[str, ColumnContract] = field(default_factory=dict)

    def validate_nested(self, value: dict) -> list[str]:
        violations = []
        for field_name, field_contract in self.nested_schema.items():
            if field_name not in value:
                if not field_contract.nullable:
                    violations.append(f"Missing nested field: {self.name}.{field_name}")
            else:
                # Type check nested value
                actual_type = type(value[field_name]).__name__
                # ... validate recursively
        return violations
```

### Cross-System Schema Alignment

```python
def align_schemas(
    source_contract: SchemaContract,
    target_contract: SchemaContract,
) -> dict:
    """Compare schemas across systems to identify mapping gaps."""
    source_cols = {c.name: c for c in source_contract.columns}
    target_cols = {c.name: c for c in target_contract.columns}

    return {
        "mapped": [
            {"name": n, "source_type": source_cols[n].data_type.value,
             "target_type": target_cols[n].data_type.value}
            for n in set(source_cols) & set(target_cols)
        ],
        "source_only": list(set(source_cols) - set(target_cols)),
        "target_only": list(set(target_cols) - set(source_cols)),
        "type_mismatches": [
            n for n in set(source_cols) & set(target_cols)
            if source_cols[n].data_type != target_cols[n].data_type
        ],
    }
```
