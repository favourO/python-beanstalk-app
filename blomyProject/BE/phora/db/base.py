import os

from sqlalchemy import MetaData
from sqlalchemy.orm import DeclarativeBase


def active_schema(env_var: str, default: str) -> str | None:
    database_url = os.getenv("PHORA_DATABASE_URL", "sqlite:///./phora.db")
    if database_url.startswith("sqlite"):
        return None
    return os.getenv(env_var, default)


HEALTH_SCHEMA = active_schema("PHORA_HEALTH_SCHEMA", "health")
BILLING_SCHEMA = active_schema("PHORA_BILLING_SCHEMA", "billing")
AUDIT_SCHEMA = active_schema("PHORA_AUDIT_SCHEMA", "audit")


def schema_table_args(schema: str | None) -> dict[str, str]:
    return {"schema": schema} if schema else {}


class Base(DeclarativeBase):
    metadata = MetaData()

