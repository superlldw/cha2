from datetime import datetime

from pydantic import BaseModel, Field

from app.models.enums import EvidenceType


class UploadEvidenceData(BaseModel):
    evidence_id: str
    file_url: str


class DeleteEvidenceData(BaseModel):
    evidence_id: str


class EvidenceListItem(BaseModel):
    evidence_id: str
    evidence_type: EvidenceType
    file_url: str
    caption: str | None = None
    gps_lat: float | None = None
    gps_lng: float | None = None
    shot_time: datetime | None = None


class EvidenceListData(BaseModel):
    items: list[EvidenceListItem] = Field(default_factory=list)
