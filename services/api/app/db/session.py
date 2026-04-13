from collections.abc import Generator
from pathlib import Path

from sqlalchemy import create_engine
from sqlalchemy import text
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.base import Base
from app.db import models  # noqa: F401

DEFAULT_DB_PATH = Path(__file__).resolve().parents[2] / "data" / "app.db"
DEFAULT_DATABASE_URL = f"sqlite+pysqlite:///{DEFAULT_DB_PATH.as_posix()}"
DEFAULT_STORAGE_ROOT = Path(__file__).resolve().parents[2] / "storage"

_ENGINE = None
_SESSION_LOCAL = None
_CURRENT_DB_URL = None
_STORAGE_ROOT = DEFAULT_STORAGE_ROOT


def _ensure_sqlite_column(engine, table: str, column: str, ddl_sql: str, fill_sql: str | None = None) -> None:
    with engine.begin() as conn:
        cols = conn.execute(text(f"PRAGMA table_info('{table}')")).fetchall()
        names = {row[1] for row in cols}
        if column in names:
            return
        conn.execute(text(ddl_sql))
        if fill_sql:
            conn.execute(text(fill_sql))


def _run_sqlite_compat_migration(engine) -> None:
    _ensure_sqlite_column(
        engine=engine,
        table="inspection_task",
        column="project_id",
        ddl_sql="ALTER TABLE inspection_task ADD COLUMN project_id VARCHAR(64)",
        fill_sql="UPDATE inspection_task SET project_id = '' WHERE project_id IS NULL",
    )
    _ensure_sqlite_column(
        engine=engine,
        table="capture_record",
        column="structure_instance_id",
        ddl_sql="ALTER TABLE capture_record ADD COLUMN structure_instance_id VARCHAR(64)",
        fill_sql="UPDATE capture_record SET structure_instance_id = '' WHERE structure_instance_id IS NULL",
    )
    _ensure_sqlite_column(
        engine=engine,
        table="capture_record",
        column="part_code",
        ddl_sql="ALTER TABLE capture_record ADD COLUMN part_code VARCHAR(64)",
        fill_sql="UPDATE capture_record SET part_code = '' WHERE part_code IS NULL",
    )
    _ensure_sqlite_column(
        engine=engine,
        table="project",
        column="archived_at",
        ddl_sql="ALTER TABLE project ADD COLUMN archived_at DATETIME",
    )


def _create_engine(database_url: str):
    is_sqlite = database_url.startswith("sqlite")
    if database_url.endswith(":memory:"):
        return create_engine(
            database_url,
            connect_args={"check_same_thread": False},
            poolclass=StaticPool,
            future=True,
        )
    if is_sqlite:
        return create_engine(database_url, connect_args={"check_same_thread": False}, future=True)
    return create_engine(database_url, future=True)


def init_db(database_url: str | None = None) -> None:
    global _ENGINE, _SESSION_LOCAL, _CURRENT_DB_URL

    db_url = database_url or DEFAULT_DATABASE_URL
    if _ENGINE is not None and _CURRENT_DB_URL == db_url:
        return

    if db_url.startswith("sqlite") and not db_url.endswith(":memory:"):
        DEFAULT_DB_PATH.parent.mkdir(parents=True, exist_ok=True)

    _ENGINE = _create_engine(db_url)
    _SESSION_LOCAL = sessionmaker(bind=_ENGINE, autoflush=False, autocommit=False, future=True)
    _CURRENT_DB_URL = db_url

    Base.metadata.create_all(bind=_ENGINE)
    if db_url.startswith("sqlite") and not db_url.endswith(":memory:"):
        _run_sqlite_compat_migration(_ENGINE)


def set_storage_root(storage_root: Path) -> None:
    global _STORAGE_ROOT
    _STORAGE_ROOT = storage_root
    _STORAGE_ROOT.mkdir(parents=True, exist_ok=True)


def get_db() -> Generator[Session, None, None]:
    if _SESSION_LOCAL is None:
        init_db()
    db = _SESSION_LOCAL()
    db.info["storage_root"] = _STORAGE_ROOT
    try:
        yield db
    finally:
        db.close()
