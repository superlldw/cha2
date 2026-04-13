from datetime import datetime

from pydantic import BaseModel, Field

from app.models.enums import CheckStatus, SeverityLevel


class SaveResultRequest(BaseModel):
    task_id: str
    item_code: str
    check_status: CheckStatus
    issue_flag: bool
    issue_type: list[str] = Field(default_factory=list)
    severity_level: SeverityLevel | None = None
    check_record: str | None = None
    suggestion: str | None = None
    location_desc: str | None = None
    gps_lat: float | None = None
    gps_lng: float | None = None
    checked_at: datetime | None = None
    checked_by: str | None = None


class SaveResultData(BaseModel):
    result_id: str


class ResultListItem(BaseModel):
    result_id: str
    item_code: str
    item_name: str
    chapter_code: str
    check_status: CheckStatus
    issue_flag: bool
    issue_type: list[str] = Field(default_factory=list)
    severity_level: SeverityLevel | None = None
    check_record: str | None = None
    suggestion: str | None = None
    evidence_count: int = 0


class ResultListData(BaseModel):
    items: list[ResultListItem] = Field(default_factory=list)


class ProgressOverall(BaseModel):
    completed: int
    total: int
    percent: float


class ProgressChapterItem(BaseModel):
    chapter_code: str
    completed: int
    total: int
    issue_count: int


class ProgressData(BaseModel):
    overall: ProgressOverall
    chapters: list[ProgressChapterItem] = Field(default_factory=list)
