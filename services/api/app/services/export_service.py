import csv
from datetime import datetime
from pathlib import Path

from sqlalchemy.orm import Session

from app.db.models import InspectionEvidenceORM, InspectionResultORM, InspectionTaskORM
from app.services.template_store import get_enabled_inspection_items


def _ensure_export_dir(storage_root: Path, task_id: str) -> Path:
    export_dir = storage_root / "exports" / task_id
    export_dir.mkdir(parents=True, exist_ok=True)
    return export_dir


def _now_suffix() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def _item_meta_map(task: InspectionTaskORM) -> dict[str, dict[str, str]]:
    items = get_enabled_inspection_items(task.dam_type, task.enabled_chapters)
    return {
        item["item_code"]: {
            "chapter_code": item["chapter_code"],
            "item_name": item["item_name"],
        }
        for item in items
    }


def export_issue_list_csv(db: Session, task: InspectionTaskORM, storage_root: Path) -> tuple[str, str]:
    rows = db.query(InspectionResultORM).filter(
        InspectionResultORM.task_id == task.task_id,
        InspectionResultORM.deleted_at.is_(None),
        InspectionResultORM.issue_flag.is_(True),
    ).all()

    meta_map = _item_meta_map(task)
    export_dir = _ensure_export_dir(storage_root, task.task_id)
    file_name = f"issue_list_{task.task_id}_{_now_suffix()}.csv"
    file_path = export_dir / file_name

    with file_path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(
            [
                "chapter_code",
                "item_code",
                "item_name",
                "issue_type",
                "severity_level",
                "check_record",
                "suggestion",
            ]
        )
        for row in rows:
            meta = meta_map.get(row.item_code, {})
            writer.writerow(
                [
                    meta.get("chapter_code", ""),
                    row.item_code,
                    meta.get("item_name", row.item_code),
                    ",".join(row.issue_type or []),
                    row.severity_level or "",
                    row.check_record or "",
                    row.suggestion or "",
                ]
            )

    file_url = f"/storage/exports/{task.task_id}/{file_name}"
    return file_name, file_url


def export_photo_sheet_csv(db: Session, task: InspectionTaskORM, storage_root: Path) -> tuple[str, str]:
    results = db.query(InspectionResultORM).filter(
        InspectionResultORM.task_id == task.task_id,
        InspectionResultORM.deleted_at.is_(None),
    ).all()
    result_map = {r.result_id: r for r in results}
    meta_map = _item_meta_map(task)

    evidence_rows = db.query(InspectionEvidenceORM).filter(
        InspectionEvidenceORM.result_id.in_(list(result_map.keys()) if result_map else [""]),
        InspectionEvidenceORM.deleted_at.is_(None),
        InspectionEvidenceORM.evidence_type == "photo",
    ).all()

    export_dir = _ensure_export_dir(storage_root, task.task_id)
    file_name = f"photo_sheet_{task.task_id}_{_now_suffix()}.csv"
    file_path = export_dir / file_name

    with file_path.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(
            [
                "chapter_code",
                "item_code",
                "item_name",
                "evidence_id",
                "evidence_type",
                "caption",
                "shot_time",
                "file_url",
            ]
        )
        for evi in evidence_rows:
            result = result_map.get(evi.result_id)
            if result is None:
                continue
            meta = meta_map.get(result.item_code, {})
            writer.writerow(
                [
                    meta.get("chapter_code", ""),
                    result.item_code,
                    meta.get("item_name", result.item_code),
                    evi.evidence_id,
                    evi.evidence_type,
                    evi.caption or "",
                    evi.shot_time.isoformat() if evi.shot_time else "",
                    evi.file_url,
                ]
            )

    file_url = f"/storage/exports/{task.task_id}/{file_name}"
    return file_name, file_url
