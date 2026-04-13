from typing import Generic, TypeVar

from pydantic import BaseModel, Field
from pydantic.generics import GenericModel

T = TypeVar("T")


class ApiErrorItem(BaseModel):
    field: str
    message: str


class ApiResponse(GenericModel, Generic[T]):
    success: bool = True
    message: str = "ok"
    data: T | None = None
    error_code: str | None = None
    errors: list[ApiErrorItem] = Field(default_factory=list)

