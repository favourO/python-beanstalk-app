from collections.abc import Generator
from functools import lru_cache

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.engine import Engine
from sqlalchemy.orm import Session, sessionmaker

from phora.core.config import get_settings
from phora.db.base import AUDIT_SCHEMA, BILLING_SCHEMA, HEALTH_SCHEMA


@lru_cache(maxsize=1)
def get_engine() -> Engine:
    settings = get_settings()
    connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}
    return create_engine(settings.database_url, future=True, connect_args=connect_args)


@lru_cache(maxsize=1)
def get_session_factory() -> sessionmaker:
    return sessionmaker(bind=get_engine(), autoflush=False, autocommit=False, expire_on_commit=False)


def reset_db_state() -> None:
    get_engine.cache_clear()
    get_session_factory.cache_clear()


def ensure_postgres_schemas() -> None:
    settings = get_settings()
    sqlite = settings.database_url.startswith("sqlite")
    with get_engine().begin() as connection:
        if not sqlite:
            for schema in (HEALTH_SCHEMA, BILLING_SCHEMA, AUDIT_SCHEMA):
                if schema:
                    connection.execute(text(f'CREATE SCHEMA IF NOT EXISTS "{schema}"'))
            _ensure_postgres_enum_value(connection, enum_name="wearabletype", enum_value="GTL1")
        _ensure_audit_tables(connection, sqlite=sqlite)
        _ensure_compat_columns(connection, sqlite=sqlite)


def _ensure_audit_tables(connection, *, sqlite: bool) -> None:
    """Guarantee audit-schema tables exist; safe to run on every startup."""
    schema_prefix = "" if sqlite else (f'"{AUDIT_SCHEMA}".' if AUDIT_SCHEMA else "")
    connection.execute(text(
        f"""
        CREATE TABLE IF NOT EXISTS {schema_prefix}contact_messages (
            id          VARCHAR(36)               PRIMARY KEY,
            name        VARCHAR(120)              NOT NULL,
            email       VARCHAR(255)              NOT NULL,
            subject     VARCHAR(200)              NOT NULL,
            message     TEXT                      NOT NULL,
            read        BOOLEAN                   NOT NULL DEFAULT FALSE,
            replied_at  TIMESTAMP WITH TIME ZONE,
            created_at  TIMESTAMP WITH TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    ))
    connection.execute(text(
        f"""
        CREATE TABLE IF NOT EXISTS {schema_prefix}download_requests (
            id         VARCHAR(36)               PRIMARY KEY,
            email      VARCHAR(255)              NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP
        )
        """
    ))


def ensure_stage_wearable_inventory() -> None:
    settings = get_settings()
    if settings.environment not in {"stage", "staging"}:
        return

    schema_prefix = f'"{BILLING_SCHEMA}".' if BILLING_SCHEMA and not settings.database_url.startswith("sqlite") else ""
    with get_engine().begin() as connection:
        connection.execute(
            text(
                f"""
                INSERT INTO {schema_prefix}wearable_inventory (
                    id,
                    product_name,
                    sku,
                    total_stock,
                    available_stock,
                    reserved_stock,
                    price_minor,
                    currency,
                    currency_symbol,
                    low_stock_threshold,
                    is_active,
                    allowed_country_codes,
                    created_at,
                    updated_at
                )
                VALUES (
                    '00000000-0000-0000-0000-000000000501',
                    'Vyla Wearable',
                    'VYLA-WEARABLE-V1',
                    50,
                    50,
                    0,
                    2500,
                    'GBP',
                    '£',
                    5,
                    true,
                    '["GB"]',
                    CURRENT_TIMESTAMP,
                    CURRENT_TIMESTAMP
                )
                ON CONFLICT (sku) DO UPDATE SET
                    product_name = EXCLUDED.product_name,
                    total_stock = 50,
                    available_stock = 50,
                    reserved_stock = 0,
                    price_minor = 2500,
                    currency = 'GBP',
                    currency_symbol = '£',
                    low_stock_threshold = 5,
                    is_active = true,
                    allowed_country_codes = '["GB"]',
                    updated_at = CURRENT_TIMESTAMP
                """
            )
        )


def _ensure_postgres_enum_value(connection, *, enum_name: str, enum_value: str) -> None:
    enum_schema = connection.execute(
        text(
            """
            SELECT ns.nspname
            FROM pg_type t
            JOIN pg_namespace ns ON ns.oid = t.typnamespace
            WHERE t.typname = :enum_name
            ORDER BY CASE WHEN ns.nspname = :preferred_schema THEN 0 ELSE 1 END, ns.nspname
            LIMIT 1
            """
        ),
        {"enum_name": enum_name, "preferred_schema": HEALTH_SCHEMA or "public"},
    ).scalar_one_or_none()
    if not enum_schema:
        return

    connection.execute(text(f'ALTER TYPE "{enum_schema}"."{enum_name}" ADD VALUE IF NOT EXISTS \'{enum_value}\''))


def _ensure_compat_columns(connection, *, sqlite: bool) -> None:
    inspector = inspect(connection)
    _ensure_missing_columns(
        connection,
        inspector=inspector,
        sqlite=sqlite,
        schema=None if sqlite else HEALTH_SCHEMA,
        table_name="users",
        missing_column_sql={
            "account_mode": "VARCHAR(32) NOT NULL DEFAULT 'registered'",
            "token_generation": "INTEGER NOT NULL DEFAULT 0",
            "email_verified": "BOOLEAN NOT NULL DEFAULT FALSE",
            "is_admin": "BOOLEAN NOT NULL DEFAULT FALSE",
            "deleted_at": "TIMESTAMP WITH TIME ZONE",
            "created_at": "TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP",
        },
        new_indexes=("account_mode",),
    )
    _ensure_missing_columns(
        connection,
        inspector=inspector,
        sqlite=sqlite,
        schema=None if sqlite else HEALTH_SCHEMA,
        table_name="onboarding_progress",
        missing_column_sql={
            "current_step": "INTEGER",
            "completed": "BOOLEAN NOT NULL DEFAULT FALSE",
            "period_length": "INTEGER",
            "last_period_start": "DATE",
            "last_period_end": "DATE",
            "goal": "VARCHAR(16)",
            "health_conditions": "JSON NOT NULL DEFAULT '[]'",
            "updated_at": "TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP",
        },
    )
    _ensure_missing_columns(
        connection,
        inspector=inspector,
        sqlite=sqlite,
        schema=None if sqlite else BILLING_SCHEMA,
        table_name="subscriptions",
        missing_column_sql={
            "provider_subscription_id": "VARCHAR(255)",
            "provider_customer_id": "VARCHAR(255)",
            "provider_price_id": "VARCHAR(255)",
            "currency": "VARCHAR(8)",
            "billing_interval": "VARCHAR(16)",
            "current_period_end": "TIMESTAMP WITH TIME ZONE",
            "cancel_at_period_end": "BOOLEAN NOT NULL DEFAULT FALSE",
            "pending_billing_interval": "VARCHAR(16)",
            "pending_provider_price_id": "VARCHAR(255)",
            "pending_amount": "FLOAT",
            "pending_currency": "VARCHAR(8)",
            "pending_change_effective_at": "TIMESTAMP WITH TIME ZONE",
            "updated_at": "TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP",
        },
        new_indexes=("provider_subscription_id", "provider_customer_id"),
    )
    _ensure_missing_columns(
        connection,
        inspector=inspector,
        sqlite=sqlite,
        schema=None if sqlite else BILLING_SCHEMA,
        table_name="invoices",
        missing_column_sql={
            "provider_invoice_id": "VARCHAR(255)",
            "provider_customer_id": "VARCHAR(255)",
            "provider_payment_intent_id": "VARCHAR(255)",
            "updated_at": "TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP",
        },
        new_indexes=("provider_invoice_id", "provider_customer_id"),
    )
    _ensure_missing_columns(
        connection,
        inspector=inspector,
        sqlite=sqlite,
        schema=None if sqlite else BILLING_SCHEMA,
        table_name="billing_activities",
        missing_column_sql={
            "subscription_id": "VARCHAR(36)",
            "event_type": "VARCHAR(64)",
            "title": "VARCHAR(128)",
            "subtitle": "VARCHAR(512)",
            "created_at": "TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP",
        },
        new_indexes=("user_id", "event_type"),
    )
    _ensure_missing_columns(
        connection,
        inspector=inspector,
        sqlite=sqlite,
        schema=None if sqlite else HEALTH_SCHEMA,
        table_name="notification_preferences",
        missing_column_sql={
            "all_notifications": "BOOLEAN NOT NULL DEFAULT TRUE",
            "period_detected": "BOOLEAN NOT NULL DEFAULT TRUE",
            "cycle_delay_alert": "BOOLEAN NOT NULL DEFAULT TRUE",
            "cycle_pattern_change": "BOOLEAN NOT NULL DEFAULT TRUE",
            "unusual_symptom": "BOOLEAN NOT NULL DEFAULT TRUE",
            "stress_alert": "BOOLEAN NOT NULL DEFAULT TRUE",
            "sleep_alert": "BOOLEAN NOT NULL DEFAULT FALSE",
            "daily_symptom_reminder": "BOOLEAN NOT NULL DEFAULT FALSE",
            "bangle_sync_reminder": "BOOLEAN NOT NULL DEFAULT FALSE",
            "temperature_logging_reminder": "BOOLEAN NOT NULL DEFAULT FALSE",
            "weekly_summary": "BOOLEAN NOT NULL DEFAULT TRUE",
            "feature_tips": "BOOLEAN NOT NULL DEFAULT TRUE",
            "blog_posts": "BOOLEAN NOT NULL DEFAULT TRUE",
            "wearable_ovulation_reminder": "BOOLEAN NOT NULL DEFAULT TRUE",
            "update_reminders": "BOOLEAN NOT NULL DEFAULT TRUE",
            "quiet_hours_enabled": "BOOLEAN NOT NULL DEFAULT TRUE",
            "quiet_hours_start": "VARCHAR(5) NOT NULL DEFAULT '22:00'",
            "quiet_hours_end": "VARCHAR(5) NOT NULL DEFAULT '08:00'",
            "allow_critical_in_quiet_hours": "BOOLEAN NOT NULL DEFAULT TRUE",
            "lock_screen_preview": "BOOLEAN NOT NULL DEFAULT FALSE",
            "push_enabled": "BOOLEAN NOT NULL DEFAULT TRUE",
            "in_app_enabled": "BOOLEAN NOT NULL DEFAULT TRUE",
            "email_enabled": "BOOLEAN NOT NULL DEFAULT FALSE",
            "sms_enabled": "BOOLEAN NOT NULL DEFAULT FALSE",
            "created_at": "TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP",
            "updated_at": "TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP",
        },
    )
    _ensure_missing_columns(
        connection,
        inspector=inspector,
        sqlite=sqlite,
        schema=None if sqlite else BILLING_SCHEMA,
        table_name="wearable_inventory",
        missing_column_sql={
            "price_minor": "INTEGER NOT NULL DEFAULT 2500",
            "currency": "VARCHAR(8) NOT NULL DEFAULT 'GBP'",
            "currency_symbol": "VARCHAR(4) NOT NULL DEFAULT '£'",
            "allowed_country_codes": "JSON NOT NULL DEFAULT '[\"GB\"]'",
        },
    )
    _ensure_missing_columns(
        connection,
        inspector=inspector,
        sqlite=sqlite,
        schema=None if sqlite else BILLING_SCHEMA,
        table_name="wearable_orders",
        missing_column_sql={
            "wearable_currency": "VARCHAR(8) NOT NULL DEFAULT 'GBP'",
            "provider_payment_intent_id": "VARCHAR(255)",
        },
        new_indexes=("provider_payment_intent_id",),
    )
    _ensure_missing_columns(
        connection,
        inspector=inspector,
        sqlite=sqlite,
        schema=None if sqlite else HEALTH_SCHEMA,
        table_name="notification_history",
        missing_column_sql={
            "category": "VARCHAR(32) NOT NULL DEFAULT 'general'",
            "channel": "VARCHAR(16) NOT NULL DEFAULT 'in_app'",
            "title": "VARCHAR(120) NOT NULL DEFAULT ''",
            "body": "TEXT NOT NULL DEFAULT ''",
            "lock_screen_title": "VARCHAR(120) NOT NULL DEFAULT 'Vyla update'",
            "lock_screen_body": "VARCHAR(120) NOT NULL DEFAULT ''",
            "status": "VARCHAR(32) NOT NULL DEFAULT 'pending'",
            "priority": "VARCHAR(16) NOT NULL DEFAULT 'low'",
            "batch_key": "VARCHAR(64)",
            "dedupe_key": "VARCHAR(128)",
            "action_url": "VARCHAR(255)",
            "action_labels": "JSON NOT NULL DEFAULT '[]'",
            "scheduled_for": "TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP",
            "delivered_at": "TIMESTAMP WITH TIME ZONE",
            "metadata": "JSON NOT NULL DEFAULT '{}'",
            "delivery_attempts": "INTEGER NOT NULL DEFAULT 0",
        },
        new_indexes=("batch_key", "dedupe_key", "scheduled_for"),
    )
    _ensure_missing_columns(
        connection,
        inspector=inspector,
        sqlite=sqlite,
        schema=None if sqlite else HEALTH_SCHEMA,
        table_name="wearable_metrics",
        missing_column_sql={
            "data_source": "VARCHAR(50) NOT NULL DEFAULT 'vyla_wearable'",
            "external_id": "VARCHAR(255)",
        },
        new_indexes=("data_source",),
    )
    _ensure_missing_columns(
        connection,
        inspector=inspector,
        sqlite=sqlite,
        schema=None if sqlite else HEALTH_SCHEMA,
        table_name="ai_memory_documents",
        missing_column_sql={
            "embedding": "JSON",
            "embedding_model": "VARCHAR(128)",
        },
        new_indexes=("embedding_model",),
    )
    if not sqlite:
        _ensure_pgvector_embedding(connection)
    _ensure_missing_columns(
        connection,
        inspector=inspector,
        sqlite=sqlite,
        schema=None if sqlite else AUDIT_SCHEMA,
        table_name="contact_messages",
        missing_column_sql={
            "replied_at": "TIMESTAMP WITH TIME ZONE",
        },
    )
    _ensure_wearable_metrics_composite_index(connection, sqlite=sqlite)


def _ensure_pgvector_embedding(connection) -> None:
    """Enable pgvector and safely backfill vector search support for AI memory."""
    schema = HEALTH_SCHEMA or "public"
    schema_prefix = f'"{HEALTH_SCHEMA}".' if HEALTH_SCHEMA else ""
    table = f'{schema_prefix}ai_memory_documents'

    connection.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))

    table_exists = connection.execute(
        text(
            "SELECT 1 FROM information_schema.tables "
            "WHERE table_schema = :schema AND table_name = 'ai_memory_documents'"
        ),
        {"schema": schema},
    ).fetchone()
    if table_exists is None:
        return

    result = connection.execute(
        text(
            "SELECT 1 FROM information_schema.columns "
            "WHERE table_schema = :schema "
            "AND table_name = 'ai_memory_documents' "
            "AND column_name = 'embedding_vec'"
        ),
        {"schema": schema},
    ).fetchone()
    if result is None:
        connection.execute(text(f"ALTER TABLE {table} ADD COLUMN embedding_vec vector(1536)"))

    index_name = "ix_ai_memory_embedding_vec_hnsw"
    existing = connection.execute(
        text(
            "SELECT 1 FROM pg_indexes "
            "WHERE schemaname = :schema AND indexname = :name"
        ),
        {"schema": schema, "name": index_name},
    ).fetchone()
    if existing is None:
        connection.execute(
            text(
                f"CREATE INDEX IF NOT EXISTS {index_name} ON {table} "
                "USING hnsw (embedding_vec vector_cosine_ops)"
            )
        )


def _ensure_wearable_metrics_composite_index(connection, *, sqlite: bool) -> None:
    inspector = inspect(connection)
    if not inspector.has_table("wearable_metrics", schema=None if sqlite else HEALTH_SCHEMA):
        return
    qualified_table = "wearable_metrics" if sqlite or not HEALTH_SCHEMA else f'"{HEALTH_SCHEMA}"."wearable_metrics"'
    index_name = "ix_wearable_metrics_user_source_type_time"
    connection.execute(
        text(
            f"CREATE INDEX IF NOT EXISTS {index_name} ON {qualified_table} "
            f"(user_id, data_source, metric_type, measured_at)"
        )
    )


def _ensure_missing_columns(
    connection,
    *,
    inspector,
    sqlite: bool,
    schema: str | None,
    table_name: str,
    missing_column_sql: dict[str, str],
    new_indexes: tuple[str, ...] = (),
) -> None:
    if not inspector.has_table(table_name, schema=schema):
        return

    existing_columns = {column["name"] for column in inspector.get_columns(table_name, schema=schema)}
    qualified_table = table_name if sqlite or not schema else f'"{schema}"."{table_name}"'

    for column_name, column_sql in missing_column_sql.items():
        if column_name not in existing_columns:
            connection.execute(text(f"ALTER TABLE {qualified_table} ADD COLUMN {column_name} {column_sql}"))

    for column_name in new_indexes:
        if column_name in existing_columns:
            continue
        index_name = f"ix_{table_name}_{column_name}" if sqlite or not schema else f"ix_{schema}_{table_name}_{column_name}"
        connection.execute(text(f"CREATE INDEX IF NOT EXISTS {index_name} ON {qualified_table} ({column_name})"))


def get_db() -> Generator[Session, None, None]:
    session = get_session_factory()()
    try:
        yield session
    finally:
        session.close()
