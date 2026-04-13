from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import Date, DateTime, JSON, Numeric, String, Text, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class InspectionTaskORM(Base):
    __tablename__ = "inspection_task"

    task_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    project_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    reservoir_name: Mapped[str] = mapped_column(String(255), nullable=False)
    dam_type: Mapped[str] = mapped_column(String(32), nullable=False)
    inspection_type: Mapped[str] = mapped_column(String(32), nullable=False)
    inspection_date: Mapped[date] = mapped_column(Date, nullable=False)
    weather: Mapped[str | None] = mapped_column(String(64), nullable=True)
    inspectors: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    water_level: Mapped[Decimal | None] = mapped_column(Numeric(18, 3), nullable=True)
    storage: Mapped[Decimal | None] = mapped_column(Numeric(18, 3), nullable=True)
    hub_main_structures: Mapped[str | None] = mapped_column(Text, nullable=True)
    flood_protect_obj: Mapped[str | None] = mapped_column(Text, nullable=True)
    main_problem_desc: Mapped[str | None] = mapped_column(Text, nullable=True)
    enabled_chapters: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    status: Mapped[str] = mapped_column(String(32), nullable=False, default="in_progress")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class InspectionResultORM(Base):
    __tablename__ = "inspection_result"
    __table_args__ = (UniqueConstraint("task_id", "item_code", name="uq_result_task_item"),)

    result_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    task_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    item_code: Mapped[str] = mapped_column(String(128), nullable=False, index=True)
    check_status: Mapped[str] = mapped_column(String(32), nullable=False, default="unchecked")
    issue_flag: Mapped[bool] = mapped_column(nullable=False, default=False)
    issue_type: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    severity_level: Mapped[str | None] = mapped_column(String(32), nullable=True)
    check_record: Mapped[str | None] = mapped_column(Text, nullable=True)
    suggestion: Mapped[str | None] = mapped_column(Text, nullable=True)
    location_desc: Mapped[str | None] = mapped_column(String(255), nullable=True)
    gps_lat: Mapped[float | None] = mapped_column(nullable=True)
    gps_lng: Mapped[float | None] = mapped_column(nullable=True)
    checked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    checked_by: Mapped[str | None] = mapped_column(String(64), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class InspectionEvidenceORM(Base):
    __tablename__ = "inspection_evidence"

    evidence_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    result_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    evidence_type: Mapped[str] = mapped_column(String(32), nullable=False)
    file_url: Mapped[str] = mapped_column(String(512), nullable=False)
    file_name: Mapped[str] = mapped_column(String(255), nullable=False)
    caption: Mapped[str | None] = mapped_column(Text, nullable=True)
    shot_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    gps_lat: Mapped[float | None] = mapped_column(nullable=True)
    gps_lng: Mapped[float | None] = mapped_column(nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class CaptureRecordORM(Base):
    __tablename__ = "capture_record"

    capture_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    task_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    structure_instance_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    part_code: Mapped[str] = mapped_column(String(64), nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    created_by: Mapped[str | None] = mapped_column(String(64), nullable=True)
    gps_lat: Mapped[float | None] = mapped_column(nullable=True)
    gps_lng: Mapped[float | None] = mapped_column(nullable=True)
    location_desc: Mapped[str | None] = mapped_column(String(255), nullable=True)
    quick_part_tag: Mapped[str] = mapped_column(String(64), nullable=False)
    quick_status: Mapped[str] = mapped_column(String(32), nullable=False)
    raw_note: Mapped[str | None] = mapped_column(Text, nullable=True)
    speech_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    review_status: Mapped[str] = mapped_column(String(32), nullable=False, default="pending")
    reviewed_by: Mapped[str | None] = mapped_column(String(64), nullable=True)
    reviewed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    linked_result_id: Mapped[str | None] = mapped_column(String(64), nullable=True, index=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class CaptureMediaORM(Base):
    __tablename__ = "capture_media"

    media_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    capture_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    media_type: Mapped[str] = mapped_column(String(32), nullable=False)
    local_path: Mapped[str | None] = mapped_column(String(512), nullable=True)
    server_url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    shot_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    sync_status: Mapped[str] = mapped_column(String(32), nullable=False, default="synced")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class ProjectORM(Base):
    __tablename__ = "project"

    project_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    project_name: Mapped[str] = mapped_column(String(255), nullable=False)
    reservoir_name: Mapped[str] = mapped_column(String(255), nullable=False)
    dam_type: Mapped[str] = mapped_column(String(32), nullable=False)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )
    archived_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)


class ProjectStructureInstanceORM(Base):
    __tablename__ = "project_structure_instance"

    instance_id: Mapped[str] = mapped_column(String(64), primary_key=True)
    project_id: Mapped[str] = mapped_column(String(64), nullable=False, index=True)
    category_code: Mapped[str] = mapped_column(String(64), nullable=False)
    object_type: Mapped[str] = mapped_column(String(64), nullable=False)
    instance_name: Mapped[str] = mapped_column(String(255), nullable=False)
    structure_type: Mapped[str | None] = mapped_column(String(64), nullable=True)
    template_source_type: Mapped[str] = mapped_column(String(64), nullable=False)
    alias_names: Mapped[list[str]] = mapped_column(JSON, default=list, nullable=False)
    enabled_for_capture: Mapped[bool] = mapped_column(nullable=False, default=True)
    enabled_for_report: Mapped[bool] = mapped_column(nullable=False, default=True)
    default_part_template_code: Mapped[str] = mapped_column(String(64), nullable=False)
    sort_order: Mapped[int] = mapped_column(nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=datetime.utcnow, onupdate=datetime.utcnow
    )
    deleted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
