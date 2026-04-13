from pydantic import BaseModel


class ExportFileData(BaseModel):
    file_name: str
    file_url: str
    format: str
