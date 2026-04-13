from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models import InspectionEvidenceORM, InspectionResultORM, InspectionTaskORM
from app.db.session import get_db
from app.models.enums import CheckStatus
from app.schemas.response import ApiResponse
from app.schemas.results import (
    ProgressChapterItem,
    ProgressData,
    ProgressOverall,
    ResultListData,
    ResultListItem,
    SaveResultData,
    SaveResultRequest,
)
from app.services.template_store import get_enabled_inspection_items, get_task_template_tree, get_template_item

router = APIRouter(prefix="/api/v1", tags=["results"])


@router.post("/results", response_model=ApiResponse[SaveResultData])
def save_result(payload: SaveResultRequest, db: Session = Depends(get_db)) -> ApiResponse[SaveResultData]:
    task = db.scalar(
        select(InspectionTaskORM).where(
            InspectionTaskORM.task_id == payload.task_id,
            InspectionTaskORM.deleted_at.is_(None),
        )
    )
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")

    item = get_template_item(payload.item_code)
    if item is None or item["item_type"] != "inspection_item":
        raise HTTPException(status_code=400, detail="invalid item_code")

    allowed_tree = get_task_template_tree(task.dam_type, task.enabled_chapters)
    allowed_codes = {
        leaf["item_code"]
        for chapter in allowed_tree
        for section in chapter["children"]
        for leaf in section["children"]
    }
    if payload.item_code not in allowed_codes:
        raise HTTPException(status_code=400, detail="item_code not enabled for task")

    existing = db.scalar(
        select(InspectionResultORM).where(
            InspectionResultORM.task_id == payload.task_id,
            InspectionResultORM.item_code == payload.item_code,
            InspectionResultORM.deleted_at.is_(None),
        )
    )
    if existing is None:
        result = InspectionResultORM(
            result_id=f"result_{uuid4().hex[:12]}",
            task_id=payload.task_id,
            item_code=payload.item_code,
            check_status=payload.check_status.value,
            issue_flag=payload.issue_flag,
            issue_type=payload.issue_type if payload.issue_flag else [],
            severity_level=payload.severity_level.value if payload.issue_flag and payload.severity_level else None,
            check_record=payload.check_record,
            suggestion=payload.suggestion,
            location_desc=payload.location_desc,
            gps_lat=payload.gps_lat,
            gps_lng=payload.gps_lng,
            checked_at=payload.checked_at,
            checked_by=payload.checked_by,
        )
        db.add(result)
        db.commit()
        return ApiResponse(data=SaveResultData(result_id=result.result_id))

    existing.check_status = payload.check_status.value
    existing.issue_flag = payload.issue_flag
    existing.issue_type = payload.issue_type if payload.issue_flag else []
    existing.severity_level = payload.severity_level.value if payload.issue_flag and payload.severity_level else None
    existing.check_record = payload.check_record
    existing.suggestion = payload.suggestion
    existing.location_desc = payload.location_desc
    existing.gps_lat = payload.gps_lat
    existing.gps_lng = payload.gps_lng
    existing.checked_at = payload.checked_at
    existing.checked_by = payload.checked_by
    db.commit()
    return ApiResponse(data=SaveResultData(result_id=existing.result_id))


@router.get("/tasks/{task_id}/results", response_model=ApiResponse[ResultListData])
def get_task_results(
    task_id: str,
    chapter_code: str | None = None,
    issue_flag: bool | None = None,
    check_status: CheckStatus | None = Query(default=None),
    db: Session = Depends(get_db),
) -> ApiResponse[ResultListData]:
    task = db.scalar(
        select(InspectionTaskORM).where(
            InspectionTaskORM.task_id == task_id,
            InspectionTaskORM.deleted_at.is_(None),
        )
    )
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")

    enabled_items = get_enabled_inspection_items(task.dam_type, task.enabled_chapters)
    item_meta_by_code = {item["item_code"]: item for item in enabled_items}

    query = select(InspectionResultORM).where(
        InspectionResultORM.task_id == task_id,
        InspectionResultORM.deleted_at.is_(None),
    )
    if issue_flag is not None:
        query = query.where(InspectionResultORM.issue_flag == issue_flag)
    if check_status is not None:
        query = query.where(InspectionResultORM.check_status == check_status.value)
    rows = db.scalars(query).all()
    evidence_counts = {}
    if rows:
        result_ids = [r.result_id for r in rows]
        count_rows = db.execute(
            select(
                InspectionEvidenceORM.result_id,
                func.count(InspectionEvidenceORM.evidence_id),
            )
            .where(
                InspectionEvidenceORM.result_id.in_(result_ids),
                InspectionEvidenceORM.deleted_at.is_(None),
            )
            .group_by(InspectionEvidenceORM.result_id)
        ).all()
        evidence_counts = {rid: cnt for rid, cnt in count_rows}

    items: list[ResultListItem] = []
    for row in rows:
        meta = item_meta_by_code.get(row.item_code)
        if meta is None:
            continue
        if chapter_code is not None and meta["chapter_code"] != chapter_code:
            continue
        items.append(
            ResultListItem(
                result_id=row.result_id,
                item_code=row.item_code,
                item_name=meta["item_name"],
                chapter_code=meta["chapter_code"],
                check_status=CheckStatus(row.check_status),
                issue_flag=row.issue_flag,
                issue_type=row.issue_type or [],
                severity_level=row.severity_level,
                check_record=row.check_record,
                suggestion=row.suggestion,
                evidence_count=evidence_counts.get(row.result_id, 0),
            )
        )
    return ApiResponse(data=ResultListData(items=items))


@router.get("/tasks/{task_id}/progress", response_model=ApiResponse[ProgressData])
def get_task_progress(task_id: str, db: Session = Depends(get_db)) -> ApiResponse[ProgressData]:
    task = db.scalar(
        select(InspectionTaskORM).where(
            InspectionTaskORM.task_id == task_id,
            InspectionTaskORM.deleted_at.is_(None),
        )
    )
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")

    enabled_items = get_enabled_inspection_items(task.dam_type, task.enabled_chapters)
    chapter_order = list(dict.fromkeys(item["chapter_code"] for item in enabled_items))
    enabled_codes = {item["item_code"] for item in enabled_items}
    chapter_by_code = {item["item_code"]: item["chapter_code"] for item in enabled_items}

    results = db.scalars(
        select(InspectionResultORM).where(
            InspectionResultORM.task_id == task_id,
            InspectionResultORM.deleted_at.is_(None),
        )
    ).all()
    result_by_item = {r.item_code: r for r in results if r.item_code in enabled_codes}

    chapter_total_map: dict[str, int] = {ch: 0 for ch in chapter_order}
    chapter_completed_map: dict[str, int] = {ch: 0 for ch in chapter_order}
    chapter_issue_map: dict[str, int] = {ch: 0 for ch in chapter_order}

    for item in enabled_items:
        ch = item["chapter_code"]
        chapter_total_map[ch] += 1
        row = result_by_item.get(item["item_code"])
        if row is not None and row.check_status != CheckStatus.unchecked.value:
            chapter_completed_map[ch] += 1

    for row in result_by_item.values():
        if row.issue_flag:
            chapter_issue_map[chapter_by_code[row.item_code]] += 1

    overall_total = len(enabled_items)
    overall_completed = sum(chapter_completed_map.values())
    percent = round((overall_completed / overall_total) * 100, 1) if overall_total > 0 else 0.0

    chapters = [
        ProgressChapterItem(
            chapter_code=ch,
            completed=chapter_completed_map[ch],
            total=chapter_total_map[ch],
            issue_count=chapter_issue_map[ch],
        )
        for ch in chapter_order
    ]
    data = ProgressData(
        overall=ProgressOverall(completed=overall_completed, total=overall_total, percent=percent),
        chapters=chapters,
    )
    return ApiResponse(data=data)
