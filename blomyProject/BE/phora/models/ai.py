import uuid
from datetime import UTC, datetime

from sqlalchemy import JSON, DateTime, ForeignKey, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from phora.db.base import Base, HEALTH_SCHEMA, schema_table_args

try:
    from pgvector.sqlalchemy import Vector as PgVector
except ImportError:  # pragma: no cover - local SQLite test environments may not install optional prod deps.
    PgVector = None


def _embedding_vector_type():
    return PgVector(1536) if PgVector is not None else JSON


class MedicalChatThread(Base):
    __tablename__ = "medical_chat_threads"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"),
        index=True,
    )
    title: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(UTC),
        onupdate=lambda: datetime.now(UTC),
    )


class MedicalChatMessage(Base):
    __tablename__ = "medical_chat_messages"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    thread_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}medical_chat_threads.id"),
        index=True,
    )
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"),
        index=True,
    )
    role: Mapped[str] = mapped_column(String(16), index=True)
    content: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC), index=True)


class AiMemoryDocument(Base):
    __tablename__ = "ai_memory_documents"
    __table_args__ = schema_table_args(HEALTH_SCHEMA)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}users.id"),
        index=True,
    )
    thread_id: Mapped[str | None] = mapped_column(
        String(36),
        ForeignKey(f"{HEALTH_SCHEMA + '.' if HEALTH_SCHEMA else ''}medical_chat_threads.id"),
        nullable=True,
        index=True,
    )
    doc_type: Mapped[str] = mapped_column(String(64), index=True)
    data_scope: Mapped[str] = mapped_column(String(64), index=True)
    sensitivity: Mapped[str] = mapped_column(String(16), index=True)
    summary_text: Mapped[str] = mapped_column(Text)
    embedding: Mapped[list | None] = mapped_column(JSON, nullable=True)
    embedding_vec: Mapped[list[float] | None] = mapped_column(_embedding_vector_type(), nullable=True)
    embedding_model: Mapped[str | None] = mapped_column(String(128), nullable=True)
    source_refs: Mapped[list] = mapped_column(JSON, default=list)
    memory_metadata: Mapped[dict] = mapped_column("metadata", JSON, default=dict)
    redaction_version: Mapped[str] = mapped_column(String(64))
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(UTC), index=True)
