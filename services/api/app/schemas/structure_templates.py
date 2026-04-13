from pydantic import BaseModel, Field

from app.models.enums import StructureObjectType


class StructurePartTemplateItem(BaseModel):
    template_code: str
    object_type: StructureObjectType
    part_code: str
    part_name: str
    sort_order: int


class StructurePartTemplateListData(BaseModel):
    items: list[StructurePartTemplateItem] = Field(default_factory=list)
