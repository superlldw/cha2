from datetime import datetime

from pydantic import BaseModel, Field, model_validator

from app.models.enums import DamType, StructureCategory, StructureObjectType


class CreateProjectRequest(BaseModel):
    reservoir_name: str
    dam_type: DamType
    description: str | None = None


class CreateProjectData(BaseModel):
    project_id: str


class ProjectListItem(BaseModel):
    project_id: str
    project_name: str
    reservoir_name: str
    dam_type: DamType
    created_at: datetime
    archived_at: datetime | None = None


class ProjectListData(BaseModel):
    items: list[ProjectListItem] = Field(default_factory=list)


class ProjectDetailData(BaseModel):
    project_id: str
    project_name: str
    reservoir_name: str
    dam_type: DamType
    description: str | None = None
    created_at: datetime
    updated_at: datetime
    archived_at: datetime | None = None


class UpdateProjectRequest(BaseModel):
    reservoir_name: str | None = None
    dam_type: DamType | None = None
    description: str | None = None


class BatchInitPresetConfig(BaseModel):
    object_type: StructureObjectType
    count: int = Field(default=1, ge=1, le=99)


class CreateStructureInstanceRequest(BaseModel):
    object_type: StructureObjectType
    instance_name: str
    category_code: StructureCategory | None = None
    template_source_type: StructureObjectType | None = None
    sort_order: int | None = None

    @model_validator(mode="after")
    def validate_custom(self) -> "CreateStructureInstanceRequest":
        if self.object_type == StructureObjectType.custom:
            if self.category_code is None:
                raise ValueError("custom object requires category_code")
            if self.template_source_type is None or self.template_source_type == StructureObjectType.custom:
                raise ValueError("custom object requires template_source_type")
        return self


class BatchInitStructureInstancesRequest(BaseModel):
    presets: list[BatchInitPresetConfig] = Field(default_factory=list)
    custom_instances: list[CreateStructureInstanceRequest] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_payload(self) -> "BatchInitStructureInstancesRequest":
        if not self.presets and not self.custom_instances:
            raise ValueError("presets or custom_instances is required")
        return self


class UpdateStructureInstanceRequest(BaseModel):
    instance_name: str | None = None
    enabled_for_capture: bool | None = None
    enabled_for_report: bool | None = None
    sort_order: int | None = None


class StructureInstanceData(BaseModel):
    instance_id: str
    project_id: str
    category_code: StructureCategory
    object_type: StructureObjectType
    instance_name: str
    template_source_type: StructureObjectType
    enabled_for_capture: bool
    enabled_for_report: bool
    default_part_template_code: str
    sort_order: int
    created_at: datetime
    updated_at: datetime


class StructureInstanceListData(BaseModel):
    items: list[StructureInstanceData] = Field(default_factory=list)


class BatchInitStructureInstancesData(BaseModel):
    initialized_count: int
    items: list[StructureInstanceData] = Field(default_factory=list)
