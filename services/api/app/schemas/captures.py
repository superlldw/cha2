from datetime import datetime

from pydantic import BaseModel, Field, model_validator

from app.models.enums import (
    CaptureMediaType,
    CapturePartTag,
    CaptureQuickStatus,
    CaptureReviewStatus,
    CheckStatus,
    SeverityLevel,
)


class CreateCaptureRequest(BaseModel):
    task_id: str
    structure_instance_id: str
    part_code: str
    created_by: str | None = None
    gps_lat: float | None = None
    gps_lng: float | None = None
    location_desc: str | None = None
    quick_part_tag: CapturePartTag = CapturePartTag.other
    quick_status: CaptureQuickStatus
    raw_note: str | None = None
    speech_text: str | None = None

    @model_validator(mode="after")
    def validate_text(self) -> "CreateCaptureRequest":
        has_raw = bool((self.raw_note or "").strip())
        has_speech = bool((self.speech_text or "").strip())
        if not (has_raw or has_speech):
            raise ValueError("speech_text or raw_note is required")
        return self


class CreateCaptureData(BaseModel):
    capture_id: str


class UpdateCaptureSpeechRequest(BaseModel):
    speech_text: str = Field(min_length=1)


class UpdateCaptureSpeechData(BaseModel):
    capture_id: str
    speech_text: str


class UploadCaptureMediaData(BaseModel):
    media_id: str
    media_type: CaptureMediaType
    server_url: str


class CaptureListItem(BaseModel):
    capture_id: str
    task_id: str
    created_at: datetime
    structure_instance_id: str
    structure_instance_name: str
    part_code: str
    part_name: str
    quick_part_tag: CapturePartTag
    quick_status: CaptureQuickStatus
    speech_text: str | None = None
    raw_note: str | None = None
    review_status: CaptureReviewStatus
    linked_result_id: str | None = None
    photo_count: int = 0


class CaptureListData(BaseModel):
    items: list[CaptureListItem] = Field(default_factory=list)


class CaptureMediaItem(BaseModel):
    media_id: str
    media_type: CaptureMediaType
    local_path: str | None = None
    server_url: str | None = None
    shot_time: datetime | None = None


class CaptureDetailData(BaseModel):
    capture_id: str
    task_id: str
    created_at: datetime
    created_by: str | None = None
    gps_lat: float | None = None
    gps_lng: float | None = None
    location_desc: str | None = None
    structure_instance_id: str
    structure_instance_name: str
    part_code: str
    part_name: str
    quick_part_tag: CapturePartTag
    quick_status: CaptureQuickStatus
    raw_note: str | None = None
    speech_text: str | None = None
    review_status: CaptureReviewStatus
    reviewed_by: str | None = None
    reviewed_at: datetime | None = None
    linked_result_id: str | None = None
    media: list[CaptureMediaItem] = Field(default_factory=list)


class ConfirmCaptureRequest(BaseModel):
    item_code: str
    check_status: CheckStatus
    issue_flag: bool
    issue_type: list[str] = Field(default_factory=list)
    severity_level: SeverityLevel | None = None
    check_record: str | None = None
    suggestion: str | None = None
    checked_by: str | None = None


class ConfirmCaptureData(BaseModel):
    capture_id: str
    result_id: str
