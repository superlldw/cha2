from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile


def save_uploaded_file(storage_root: Path, result_id: str, upload: UploadFile) -> tuple[str, str]:
    file_name = upload.filename or "unnamed.bin"
    safe_name = file_name.replace("\\", "_").replace("/", "_")
    suffix = Path(safe_name).suffix
    generated_name = f"{uuid4().hex}{suffix}"

    target_dir = storage_root / "evidence" / result_id
    target_dir.mkdir(parents=True, exist_ok=True)
    target_file = target_dir / generated_name

    content = upload.file.read()
    target_file.write_bytes(content)

    file_url = f"/storage/evidence/{result_id}/{generated_name}"
    return safe_name, file_url


def save_capture_media_file(storage_root: Path, capture_id: str, upload: UploadFile) -> tuple[str, str]:
    file_name = upload.filename or "unnamed.bin"
    safe_name = file_name.replace("\\", "_").replace("/", "_")
    suffix = Path(safe_name).suffix
    generated_name = f"{uuid4().hex}{suffix}"

    target_dir = storage_root / "capture_media" / capture_id
    target_dir.mkdir(parents=True, exist_ok=True)
    target_file = target_dir / generated_name

    content = upload.file.read()
    target_file.write_bytes(content)

    file_url = f"/storage/capture_media/{capture_id}/{generated_name}"
    return safe_name, file_url
