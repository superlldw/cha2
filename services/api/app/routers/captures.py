from datetime import datetime
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models import (
    CaptureMediaORM,
    CaptureRecordORM,
    InspectionEvidenceORM,
    InspectionResultORM,
    InspectionTaskORM,
    ProjectStructureInstanceORM,
)
from app.db.session import get_db
from app.models.enums import CaptureMediaType, CaptureReviewStatus
from app.schemas.captures import (
    CaptureDetailData,
    CaptureListData,
    CaptureListItem,
    CaptureMediaItem,
    ConfirmCaptureData,
    ConfirmCaptureRequest,
    CreateCaptureData,
    CreateCaptureRequest,
    UpdateCaptureSpeechData,
    UpdateCaptureSpeechRequest,
    UploadCaptureMediaData,
)
from app.schemas.response import ApiResponse
from app.services.evidence_storage import save_capture_media_file
from app.services.project_structures import get_part_name
from app.services.template_store import get_task_template_tree, get_template_item

router = APIRouter(prefix="/api/v1", tags=["captures"])


def _soft_delete_capture(capture_id: str, db: Session) -> ApiResponse[dict[str, str]]:
    capture = db.scalar(
        select(CaptureRecordORM).where(
            CaptureRecordORM.capture_id == capture_id,
            CaptureRecordORM.deleted_at.is_(None),
        )
    )
    if capture is None:
        raise HTTPException(status_code=404, detail="capture not found")
    if capture.review_status == CaptureReviewStatus.confirmed.value:
        raise HTTPException(status_code=400, detail="confirmed capture cannot be deleted")

    media_rows = db.scalars(
        select(CaptureMediaORM).where(
            CaptureMediaORM.capture_id == capture_id,
            CaptureMediaORM.deleted_at.is_(None),
        )
    ).all()
    for media in media_rows:
        media.deleted_at = datetime.utcnow()

    capture.deleted_at = datetime.utcnow()
    db.commit()
    return ApiResponse(data={"capture_id": capture_id})


def _purge_capture_with_linked_result(capture_id: str, db: Session) -> ApiResponse[dict[str, str]]:
    capture = db.scalar(
        select(CaptureRecordORM).where(
            CaptureRecordORM.capture_id == capture_id,
            CaptureRecordORM.deleted_at.is_(None),
        )
    )
    if capture is None:
        raise HTTPException(status_code=404, detail="capture not found")

    now = datetime.utcnow()
    media_rows = db.scalars(
        select(CaptureMediaORM).where(
            CaptureMediaORM.capture_id == capture_id,
            CaptureMediaORM.deleted_at.is_(None),
        )
    ).all()
    for media in media_rows:
        media.deleted_at = now

    linked_result_id = (capture.linked_result_id or "").strip()
    if linked_result_id:
        evidence_rows = db.scalars(
            select(InspectionEvidenceORM).where(
                InspectionEvidenceORM.result_id == linked_result_id,
                InspectionEvidenceORM.deleted_at.is_(None),
            )
        ).all()
        for evidence in evidence_rows:
            evidence.deleted_at = now

        result = db.scalar(
            select(InspectionResultORM).where(
                InspectionResultORM.result_id == linked_result_id,
                InspectionResultORM.deleted_at.is_(None),
            )
        )
        if result is not None:
            result.deleted_at = now

    capture.deleted_at = now
    db.commit()
    return ApiResponse(data={"capture_id": capture_id})


@router.post("/captures", response_model=ApiResponse[CreateCaptureData])
def create_capture(payload: CreateCaptureRequest, db: Session = Depends(get_db)) -> ApiResponse[CreateCaptureData]:
    task = db.scalar(
        select(InspectionTaskORM).where(
            InspectionTaskORM.task_id == payload.task_id,
            InspectionTaskORM.deleted_at.is_(None),
        )
    )
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")

    structure_instance = db.scalar(
        select(ProjectStructureInstanceORM).where(
            ProjectStructureInstanceORM.instance_id == payload.structure_instance_id,
            ProjectStructureInstanceORM.project_id == task.project_id,
            ProjectStructureInstanceORM.deleted_at.is_(None),
            ProjectStructureInstanceORM.enabled_for_capture.is_(True),
        )
    )
    if structure_instance is None:
        raise HTTPException(status_code=400, detail="invalid structure_instance_id")

    part_name = get_part_name(
        object_type=structure_instance.template_source_type,
        part_code=payload.part_code,
    )
    if part_name is None:
        raise HTTPException(status_code=400, detail="invalid part_code for structure instance")

    capture = CaptureRecordORM(
        capture_id=f"cap_{uuid4().hex[:12]}",
        task_id=payload.task_id,
        structure_instance_id=payload.structure_instance_id,
        part_code=payload.part_code,
        created_by=payload.created_by,
        gps_lat=payload.gps_lat,
        gps_lng=payload.gps_lng,
        location_desc=payload.location_desc,
        quick_part_tag=payload.quick_part_tag.value,
        quick_status=payload.quick_status.value,
        raw_note=payload.raw_note,
        speech_text=payload.speech_text,
        review_status=CaptureReviewStatus.pending.value,
    )
    db.add(capture)
    db.commit()
    return ApiResponse(data=CreateCaptureData(capture_id=capture.capture_id))


@router.post("/captures/{capture_id}/media", response_model=ApiResponse[UploadCaptureMediaData])
def upload_capture_media(
    capture_id: str,
    file: UploadFile = File(...),
    media_type: CaptureMediaType = Form(default=CaptureMediaType.photo),
    shot_time: datetime | None = Form(default=None),
    db: Session = Depends(get_db),
) -> ApiResponse[UploadCaptureMediaData]:
    capture = db.scalar(
        select(CaptureRecordORM).where(
            CaptureRecordORM.capture_id == capture_id,
            CaptureRecordORM.deleted_at.is_(None),
        )
    )
    if capture is None:
        raise HTTPException(status_code=404, detail="capture not found")

    storage_root = db.info.get("storage_root")
    if storage_root is None:
        raise HTTPException(status_code=500, detail="storage not configured")

    _, file_url = save_capture_media_file(storage_root=storage_root, capture_id=capture_id, upload=file)
    media = CaptureMediaORM(
        media_id=f"cmed_{uuid4().hex[:12]}",
        capture_id=capture_id,
        media_type=media_type.value,
        local_path=None,
        server_url=file_url,
        shot_time=shot_time,
        sync_status="synced",
    )
    db.add(media)
    db.commit()
    return ApiResponse(
        data=UploadCaptureMediaData(media_id=media.media_id, media_type=media_type, server_url=file_url)
    )


@router.post("/captures/{capture_id}/speech-transcribe", response_model=ApiResponse[UpdateCaptureSpeechData])
def update_capture_speech_text(
    capture_id: str,
    payload: UpdateCaptureSpeechRequest,
    db: Session = Depends(get_db),
) -> ApiResponse[UpdateCaptureSpeechData]:
    capture = db.scalar(
        select(CaptureRecordORM).where(
            CaptureRecordORM.capture_id == capture_id,
            CaptureRecordORM.deleted_at.is_(None),
        )
    )
    if capture is None:
        raise HTTPException(status_code=404, detail="capture not found")

    capture.speech_text = payload.speech_text.strip()
    db.commit()
    return ApiResponse(
        data=UpdateCaptureSpeechData(capture_id=capture.capture_id, speech_text=capture.speech_text)
    )


@router.delete("/captures/{capture_id}", response_model=ApiResponse[dict[str, str]])
def delete_capture(capture_id: str, db: Session = Depends(get_db)) -> ApiResponse[dict[str, str]]:
    return _soft_delete_capture(capture_id, db)


@router.post("/captures/{capture_id}/delete", response_model=ApiResponse[dict[str, str]])
def delete_capture_compat(capture_id: str, db: Session = Depends(get_db)) -> ApiResponse[dict[str, str]]:
    # Compatibility endpoint for web/dev environments where DELETE may lag behind client updates.
    return _soft_delete_capture(capture_id, db)


@router.post("/captures/{capture_id}/purge", response_model=ApiResponse[dict[str, str]])
def purge_capture(capture_id: str, db: Session = Depends(get_db)) -> ApiResponse[dict[str, str]]:
    return _purge_capture_with_linked_result(capture_id, db)


@router.get("/tasks/{task_id}/captures", response_model=ApiResponse[CaptureListData])
def list_task_captures(
    task_id: str,
    review_status: CaptureReviewStatus | None = Query(default=CaptureReviewStatus.pending),
    db: Session = Depends(get_db),
) -> ApiResponse[CaptureListData]:
    task = db.scalar(
        select(InspectionTaskORM).where(
            InspectionTaskORM.task_id == task_id,
            InspectionTaskORM.deleted_at.is_(None),
        )
    )
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")

    query = select(CaptureRecordORM).where(
        CaptureRecordORM.task_id == task_id,
        CaptureRecordORM.deleted_at.is_(None),
    )
    if review_status is not None:
        query = query.where(CaptureRecordORM.review_status == review_status.value)
    rows = db.scalars(query.order_by(CaptureRecordORM.created_at.desc())).all()
    instance_ids = [r.structure_instance_id for r in rows]
    instance_rows = db.scalars(
        select(ProjectStructureInstanceORM).where(
            ProjectStructureInstanceORM.instance_id.in_(instance_ids),
            ProjectStructureInstanceORM.deleted_at.is_(None),
        )
    ).all() if instance_ids else []
    instance_map = {x.instance_id: x for x in instance_rows}

    media_counts: dict[str, int] = {}
    if rows:
        cnt_rows = db.execute(
            select(CaptureMediaORM.capture_id, func.count(CaptureMediaORM.media_id))
            .where(
                CaptureMediaORM.capture_id.in_([r.capture_id for r in rows]),
                CaptureMediaORM.media_type == CaptureMediaType.photo.value,
                CaptureMediaORM.deleted_at.is_(None),
            )
            .group_by(CaptureMediaORM.capture_id)
        ).all()
        media_counts = {capture_id: cnt for capture_id, cnt in cnt_rows}

    items = [
        CaptureListItem(
            capture_id=row.capture_id,
            task_id=row.task_id,
            created_at=row.created_at,
            structure_instance_id=row.structure_instance_id,
            structure_instance_name=instance_map.get(row.structure_instance_id).instance_name
            if instance_map.get(row.structure_instance_id)
            else row.structure_instance_id,
            part_code=row.part_code,
            part_name=(
                get_part_name(instance_map[row.structure_instance_id].template_source_type, row.part_code)
                if row.structure_instance_id in instance_map
                else row.part_code
            )
            or row.part_code,
            quick_part_tag=row.quick_part_tag,
            quick_status=row.quick_status,
            speech_text=row.speech_text,
            raw_note=row.raw_note,
            review_status=row.review_status,
            linked_result_id=row.linked_result_id,
            photo_count=media_counts.get(row.capture_id, 0),
        )
        for row in rows
    ]
    return ApiResponse(data=CaptureListData(items=items))


@router.get("/captures/{capture_id}", response_model=ApiResponse[CaptureDetailData])
def get_capture_detail(capture_id: str, db: Session = Depends(get_db)) -> ApiResponse[CaptureDetailData]:
    capture = db.scalar(
        select(CaptureRecordORM).where(
            CaptureRecordORM.capture_id == capture_id,
            CaptureRecordORM.deleted_at.is_(None),
        )
    )
    if capture is None:
        raise HTTPException(status_code=404, detail="capture not found")
    structure_instance = db.scalar(
        select(ProjectStructureInstanceORM).where(
            ProjectStructureInstanceORM.instance_id == capture.structure_instance_id,
            ProjectStructureInstanceORM.deleted_at.is_(None),
        )
    )

    media_rows = db.scalars(
        select(CaptureMediaORM)
        .where(
            CaptureMediaORM.capture_id == capture_id,
            CaptureMediaORM.deleted_at.is_(None),
        )
        .order_by(CaptureMediaORM.created_at.asc())
    ).all()

    data = CaptureDetailData(
        capture_id=capture.capture_id,
        task_id=capture.task_id,
        created_at=capture.created_at,
        created_by=capture.created_by,
        structure_instance_id=capture.structure_instance_id,
        structure_instance_name=structure_instance.instance_name if structure_instance else capture.structure_instance_id,
        part_code=capture.part_code,
        part_name=(
            get_part_name(structure_instance.template_source_type, capture.part_code) if structure_instance else None
        )
        or capture.part_code,
        gps_lat=capture.gps_lat,
        gps_lng=capture.gps_lng,
        location_desc=capture.location_desc,
        quick_part_tag=capture.quick_part_tag,
        quick_status=capture.quick_status,
        raw_note=capture.raw_note,
        speech_text=capture.speech_text,
        review_status=capture.review_status,
        reviewed_by=capture.reviewed_by,
        reviewed_at=capture.reviewed_at,
        linked_result_id=capture.linked_result_id,
        media=[
            CaptureMediaItem(
                media_id=row.media_id,
                media_type=row.media_type,
                local_path=row.local_path,
                server_url=row.server_url,
                shot_time=row.shot_time,
            )
            for row in media_rows
        ],
    )
    return ApiResponse(data=data)


@router.post("/captures/{capture_id}/confirm", response_model=ApiResponse[ConfirmCaptureData])
def confirm_capture(
    capture_id: str,
    payload: ConfirmCaptureRequest,
    db: Session = Depends(get_db),
) -> ApiResponse[ConfirmCaptureData]:
    capture = db.scalar(
        select(CaptureRecordORM).where(
            CaptureRecordORM.capture_id == capture_id,
            CaptureRecordORM.deleted_at.is_(None),
        )
    )
    if capture is None:
        raise HTTPException(status_code=404, detail="capture not found")

    has_raw = bool((capture.raw_note or "").strip())
    has_speech = bool((capture.speech_text or "").strip())
    if not (has_raw or has_speech):
        raise HTTPException(status_code=400, detail="capture requires speech_text or raw_note")

    task = db.scalar(
        select(InspectionTaskORM).where(
            InspectionTaskORM.task_id == capture.task_id,
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
            InspectionResultORM.task_id == task.task_id,
            InspectionResultORM.item_code == payload.item_code,
            InspectionResultORM.deleted_at.is_(None),
        )
    )
    if existing is None:
        result = InspectionResultORM(
            result_id=f"result_{uuid4().hex[:12]}",
            task_id=task.task_id,
            item_code=payload.item_code,
            check_status=payload.check_status.value,
            issue_flag=payload.issue_flag,
            issue_type=payload.issue_type if payload.issue_flag else [],
            severity_level=payload.severity_level.value if payload.issue_flag and payload.severity_level else None,
            check_record=payload.check_record or capture.speech_text or capture.raw_note,
            suggestion=payload.suggestion,
            location_desc=capture.location_desc,
            gps_lat=capture.gps_lat,
            gps_lng=capture.gps_lng,
            checked_at=datetime.utcnow(),
            checked_by=payload.checked_by or capture.created_by,
        )
        db.add(result)
        result_id = result.result_id
    else:
        existing.check_status = payload.check_status.value
        existing.issue_flag = payload.issue_flag
        existing.issue_type = payload.issue_type if payload.issue_flag else []
        existing.severity_level = payload.severity_level.value if payload.issue_flag and payload.severity_level else None
        existing.check_record = payload.check_record or capture.speech_text or capture.raw_note
        existing.suggestion = payload.suggestion
        existing.location_desc = capture.location_desc
        existing.gps_lat = capture.gps_lat
        existing.gps_lng = capture.gps_lng
        existing.checked_at = datetime.utcnow()
        existing.checked_by = payload.checked_by or capture.created_by
        result_id = existing.result_id

    capture.review_status = CaptureReviewStatus.confirmed.value
    capture.reviewed_by = payload.checked_by or capture.created_by
    capture.reviewed_at = datetime.utcnow()
    capture.linked_result_id = result_id
    db.commit()
    return ApiResponse(data=ConfirmCaptureData(capture_id=capture.capture_id, result_id=result_id))
