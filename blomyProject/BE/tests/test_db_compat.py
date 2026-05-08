from sqlalchemy import text

from phora.api.app import create_app
from phora.db.session import get_engine, reset_db_state


def test_startup_backfills_missing_account_mode_column(tmp_path, monkeypatch):
    monkeypatch.setenv("PHORA_DATABASE_URL", f"sqlite:///{tmp_path / 'compat.db'}")
    monkeypatch.setenv("PHORA_SECRET_KEY", "compat-test-secret")
    monkeypatch.setenv("PHORA_AUTO_CREATE_TABLES", "true")
    reset_db_state()

    create_app()

    engine = get_engine()
    with engine.begin() as connection:
        connection.execute(text("DROP INDEX IF EXISTS ix_users_account_mode"))
        connection.execute(text("DROP INDEX IF EXISTS ix_users_email_verified"))
        connection.execute(text("ALTER TABLE users DROP COLUMN account_mode"))
        connection.execute(text("ALTER TABLE users DROP COLUMN token_generation"))
        connection.execute(text("ALTER TABLE users DROP COLUMN email_verified"))

    reset_db_state()
    create_app()

    with get_engine().begin() as connection:
        columns = [row[1] for row in connection.execute(text("PRAGMA table_info(users)"))]

    assert "account_mode" in columns
    assert "token_generation" in columns
    assert "email_verified" in columns
