from datetime import date, datetime
from decimal import Decimal

from pydantic import BaseModel, Field

from .enums import (
    CheckStatus,
    DamType,
    EvidenceType,
    ExportType,
    FileFormat,
    InspectionType,
    ItemType,
    SeverityLevel,
    TaskStatus,
)


class InspectionTask(BaseModel):
    task_id: str
    reservoir_name: str
    dam_type: DamType
    inspection_type: InspectionType
    inspection_date: date
    weather: str | None = None
    inspectors: list[str] = Field(default_factory=list)
    water_level: Decimal | None = None
    storage: Decimal | None = None
    hub_main_structures: str | None = None
    flood_protect_obj: str | None = None
    main_problem_desc: str | None = None
    enabled_chapters: list[str] = Field(default_factory=list)
    status: TaskStatus = TaskStatus.in_progress
    created_at: datetime | None = None
    updated_at: datetime | None = None
    deleted_at: datetime | None = None


class InspectionTemplateItem(BaseModel):
    item_id: str
    item_code: str
    chapter_code: str
    parent_code: str | None = None
    item_name: str
    item_type: ItemType
    applicable_dam_type: list[DamType] = Field(default_factory=list)
    supports_photo: bool = False
    supports_audio: bool = False
    supports_location: bool = False
    supports_attachment: bool = False
    sort_order: int
    deleted_at: datetime | None = None


class InspectionResult(BaseModel):
    result_id: str
    task_id: str
    item_code: str
    check_status: CheckStatus = CheckStatus.unchecked
    issue_flag: bool = False
    issue_type: list[str] = Field(default_factory=list)
    severity_level: SeverityLevel | None = None
    check_record: str | None = None
    suggestion: str | None = None
    photo_count: int = 0
    audio_count: int = 0
    video_count: int = 0
    attachment_count: int = 0
    gps_lat: float | None = None
    gps_lng: float | None = None
    location_desc: str | None = None
    checked_at: datetime | None = None
    checked_by: str | None = None
    deleted_at: datetime | None = None


class InspectionEvidence(BaseModel):
    evidence_id: str
    result_id: str
    evidence_type: EvidenceType
    file_url: str
    file_name: str
    caption: str | None = None
    shot_time: datetime | None = None
    gps_lat: float | None = None
    gps_lng: float | None = None
    deleted_at: datetime | None = None


class ExportSnapshot(BaseModel):
    export_id: str
    task_id: str
    export_type: ExportType
    file_format: FileFormat
    file_url: str | None = None
    version_no: int = 1
    created_at: datetime | None = None
    deleted_at: datetime | None = None

