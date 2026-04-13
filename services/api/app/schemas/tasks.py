from datetime import date
from decimal import Decimal

from pydantic import BaseModel, Field

from app.models.enums import DamType, InspectionType


class CreateTaskRequest(BaseModel):
    project_id: str
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


class CreateTaskData(BaseModel):
    task_id: str


class TaskListItem(BaseModel):
    task_id: str
    project_id: str
    reservoir_name: str
    dam_type: DamType
    inspection_date: date
    status: str
    issue_count: int = 0


class TaskListData(BaseModel):
    items: list[TaskListItem] = Field(default_factory=list)
    page: int = 1
    page_size: int = 20
    total: int = 0


class TaskDetailData(BaseModel):
    task_id: str
    project_id: str
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
    status: str


class TemplateTreeInspectionItemNode(BaseModel):
    item_code: str
    item_name: str
    item_type: str
    supports_photo: bool
    supports_audio: bool
    supports_location: bool
    supports_attachment: bool


class TemplateTreeSectionNode(BaseModel):
    item_code: str
    item_name: str
    item_type: str
    children: list[TemplateTreeInspectionItemNode]


class TemplateTreeChapterNode(BaseModel):
    chapter_code: str
    chapter_name: str
    children: list[TemplateTreeSectionNode]
