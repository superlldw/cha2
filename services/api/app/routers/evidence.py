from datetime import datetime
from uuid import uuid4

from fastapi import APIRouter, Depends, File, Form, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import InspectionEvidenceORM, InspectionResultORM
from app.db.session import get_db
from app.models.enums import EvidenceType
from app.schemas.evidence import DeleteEvidenceData, EvidenceListData, EvidenceListItem, UploadEvidenceData
from app.schemas.response import ApiResponse
from app.services.evidence_storage import save_uploaded_file

router = APIRouter(prefix="/api/v1", tags=["evidence"])


@router.post("/evidence/upload", response_model=ApiResponse[UploadEvidenceData])
def upload_evidence(
    file: UploadFile = File(...),
    result_id: str = Form(...),
    evidence_type: EvidenceType = Form(...),
    caption: str | None = Form(default=None),
    gps_lat: float | None = Form(default=None),
    gps_lng: float | None = Form(default=None),
    shot_time: datetime | None = Form(default=None),
    db: Session = Depends(get_db),
) -> ApiResponse[UploadEvidenceData]:
    result = db.scalar(
        select(InspectionResultORM).where(
            InspectionResultORM.result_id == result_id,
            InspectionResultORM.deleted_at.is_(None),
        )
    )
    if result is None:
        raise HTTPException(status_code=404, detail="result not found")

    storage_root = db.info.get("storage_root")
    if storage_root is None:
        raise HTTPException(status_code=500, detail="storage not configured")

    file_name, file_url = save_uploaded_file(storage_root=storage_root, result_id=result_id, upload=file)
    evidence = InspectionEvidenceORM(
        evidence_id=f"evi_{uuid4().hex[:12]}",
        result_id=result_id,
        evidence_type=evidence_type.value,
        file_url=file_url,
        file_name=file_name,
        caption=caption,
        gps_lat=gps_lat,
        gps_lng=gps_lng,
        shot_time=shot_time,
    )
    db.add(evidence)
    db.commit()
    return ApiResponse(data=UploadEvidenceData(evidence_id=evidence.evidence_id, file_url=evidence.file_url))


@router.get("/results/{result_id}/evidence", response_model=ApiResponse[EvidenceListData])
def get_result_evidence(result_id: str, db: Session = Depends(get_db)) -> ApiResponse[EvidenceListData]:
    result = db.scalar(
        select(InspectionResultORM).where(
            InspectionResultORM.result_id == result_id,
            InspectionResultORM.deleted_at.is_(None),
        )
    )
    if result is None:
        raise HTTPException(status_code=404, detail="result not found")

    rows = db.scalars(
        select(InspectionEvidenceORM)
        .where(
            InspectionEvidenceORM.result_id == result_id,
            InspectionEvidenceORM.deleted_at.is_(None),
        )
        .order_by(InspectionEvidenceORM.created_at.asc())
    ).all()
    items = [
        EvidenceListItem(
            evidence_id=row.evidence_id,
            evidence_type=EvidenceType(row.evidence_type),
            file_url=row.file_url,
            caption=row.caption,
            gps_lat=row.gps_lat,
            gps_lng=row.gps_lng,
            shot_time=row.shot_time,
        )
        for row in rows
    ]
    return ApiResponse(data=EvidenceListData(items=items))


@router.delete("/evidence/{evidence_id}", response_model=ApiResponse[DeleteEvidenceData])
def delete_evidence(evidence_id: str, db: Session = Depends(get_db)) -> ApiResponse[DeleteEvidenceData]:
    evidence = db.scalar(
        select(InspectionEvidenceORM).where(
            InspectionEvidenceORM.evidence_id == evidence_id,
            InspectionEvidenceORM.deleted_at.is_(None),
        )
    )
    if evidence is None:
        raise HTTPException(status_code=404, detail="evidence not found")

    evidence.deleted_at = datetime.utcnow()
    db.commit()
    return ApiResponse(message="deleted", data=DeleteEvidenceData(evidence_id=evidence_id))
