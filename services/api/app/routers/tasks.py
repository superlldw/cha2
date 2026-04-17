from datetime import datetime
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db.models import InspectionResultORM, InspectionTaskORM, ProjectORM
from app.db.session import get_db
from app.schemas.response import ApiResponse
from app.schemas.exports import ExportFileData
from app.schemas.tasks import (
    CreateTaskData,
    CreateTaskRequest,
    TaskDetailData,
    TaskListData,
    TaskListItem,
    TemplateTreeChapterNode,
)
from app.services.export_service import (
    export_inspection_docx,
    export_issue_list_csv,
    export_photo_package_zip,
    export_photo_sheet_csv,
)
from app.services.template_store import get_task_template_tree

router = APIRouter(prefix="/api/v1", tags=["tasks"])


@router.post("/tasks", response_model=ApiResponse[CreateTaskData])
def create_task(payload: CreateTaskRequest, db: Session = Depends(get_db)) -> ApiResponse[CreateTaskData]:
    project = db.scalar(
        select(ProjectORM).where(
            ProjectORM.project_id == payload.project_id,
            ProjectORM.deleted_at.is_(None),
        )
    )
    if project is None:
        raise HTTPException(status_code=404, detail="project not found")
    task_id = f"task_{uuid4().hex[:12]}"
    task = InspectionTaskORM(
        task_id=task_id,
        project_id=payload.project_id,
        reservoir_name=project.reservoir_name,
        dam_type=project.dam_type,
        inspection_type=payload.inspection_type.value,
        inspection_date=payload.inspection_date,
        weather=payload.weather,
        inspectors=payload.inspectors,
        water_level=payload.water_level,
        storage=payload.storage,
        hub_main_structures=payload.hub_main_structures,
        flood_protect_obj=payload.flood_protect_obj,
        main_problem_desc=payload.main_problem_desc,
        enabled_chapters=payload.enabled_chapters,
        status="in_progress",
    )
    db.add(task)
    db.commit()
    return ApiResponse(data=CreateTaskData(task_id=task_id))


@router.delete("/tasks/{task_id}", response_model=ApiResponse[dict[str, str]])
def delete_task(task_id: str, db: Session = Depends(get_db)) -> ApiResponse[dict[str, str]]:
    task = db.scalar(
        select(InspectionTaskORM).where(
            InspectionTaskORM.task_id == task_id,
            InspectionTaskORM.deleted_at.is_(None),
        )
    )
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")
    task.deleted_at = datetime.utcnow()
    db.commit()
    return ApiResponse(data={"task_id": task_id})


@router.get("/tasks", response_model=ApiResponse[TaskListData])
def get_tasks(
    page: int = 1,
    page_size: int = 20,
    db: Session = Depends(get_db),
) -> ApiResponse[TaskListData]:
    page = max(page, 1)
    page_size = max(min(page_size, 200), 1)
    offset = (page - 1) * page_size

    total = db.scalar(select(func.count()).select_from(InspectionTaskORM).where(InspectionTaskORM.deleted_at.is_(None)))
    rows = db.scalars(
        select(InspectionTaskORM)
        .where(InspectionTaskORM.deleted_at.is_(None))
        .order_by(InspectionTaskORM.created_at.desc())
        .offset(offset)
        .limit(page_size)
    ).all()

    issue_map: dict[str, int] = {}
    if rows:
        issue_rows = db.execute(
            select(InspectionResultORM.task_id, func.count(InspectionResultORM.result_id))
            .where(
                InspectionResultORM.deleted_at.is_(None),
                InspectionResultORM.issue_flag.is_(True),
                InspectionResultORM.task_id.in_([r.task_id for r in rows]),
            )
            .group_by(InspectionResultORM.task_id)
        ).all()
        issue_map = {task_id: cnt for task_id, cnt in issue_rows}

    items = [
        TaskListItem(
            task_id=row.task_id,
            project_id=row.project_id,
            reservoir_name=row.reservoir_name,
            dam_type=row.dam_type,
            inspection_date=row.inspection_date,
            status=row.status,
            issue_count=issue_map.get(row.task_id, 0),
        )
        for row in rows
    ]
    return ApiResponse(
        data=TaskListData(
            items=items,
            page=page,
            page_size=page_size,
            total=total or 0,
        )
    )


@router.get("/tasks/{task_id}", response_model=ApiResponse[TaskDetailData])
def get_task_detail(task_id: str, db: Session = Depends(get_db)) -> ApiResponse[TaskDetailData]:
    task = db.scalar(
        select(InspectionTaskORM).where(
            InspectionTaskORM.task_id == task_id,
            InspectionTaskORM.deleted_at.is_(None),
        )
    )
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")

    return ApiResponse(
        data=TaskDetailData(
            task_id=task.task_id,
            project_id=task.project_id,
            reservoir_name=task.reservoir_name,
            dam_type=task.dam_type,
            inspection_type=task.inspection_type,
            inspection_date=task.inspection_date,
            weather=task.weather,
            inspectors=task.inspectors or [],
            water_level=task.water_level,
            storage=task.storage,
            hub_main_structures=task.hub_main_structures,
            flood_protect_obj=task.flood_protect_obj,
            main_problem_desc=task.main_problem_desc,
            enabled_chapters=task.enabled_chapters or [],
            status=task.status,
        )
    )


@router.get("/tasks/{task_id}/template-tree", response_model=ApiResponse[list[TemplateTreeChapterNode]])
def get_template_tree(task_id: str, db: Session = Depends(get_db)) -> ApiResponse[list[TemplateTreeChapterNode]]:
    task = db.scalar(
        select(InspectionTaskORM).where(InspectionTaskORM.task_id == task_id, InspectionTaskORM.deleted_at.is_(None))
    )
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")

    tree = get_task_template_tree(dam_type=task.dam_type, enabled_chapters=task.enabled_chapters)
    return ApiResponse(data=[TemplateTreeChapterNode.model_validate(node) for node in tree])


@router.get("/tasks/{task_id}/exports/issues-list", response_model=ApiResponse[ExportFileData])
def export_issue_list(task_id: str, db: Session = Depends(get_db)) -> ApiResponse[ExportFileData]:
    task = db.scalar(
        select(InspectionTaskORM).where(
            InspectionTaskORM.task_id == task_id,
            InspectionTaskORM.deleted_at.is_(None),
        )
    )
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")

    storage_root = db.info.get("storage_root")
    if storage_root is None:
        raise HTTPException(status_code=500, detail="storage not configured")

    file_name, file_url = export_issue_list_csv(db=db, task=task, storage_root=storage_root)
    return ApiResponse(data=ExportFileData(file_name=file_name, file_url=file_url, format="csv"))


@router.get("/tasks/{task_id}/exports/photo-sheet", response_model=ApiResponse[ExportFileData])
def export_photo_sheet(task_id: str, db: Session = Depends(get_db)) -> ApiResponse[ExportFileData]:
    task = db.scalar(
        select(InspectionTaskORM).where(
            InspectionTaskORM.task_id == task_id,
            InspectionTaskORM.deleted_at.is_(None),
        )
    )
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")

    storage_root = db.info.get("storage_root")
    if storage_root is None:
        raise HTTPException(status_code=500, detail="storage not configured")

    file_name, file_url = export_photo_sheet_csv(db=db, task=task, storage_root=storage_root)
    return ApiResponse(data=ExportFileData(file_name=file_name, file_url=file_url, format="csv"))


@router.get("/tasks/{task_id}/exports/photo-package", response_model=ApiResponse[ExportFileData])
def export_photo_package(task_id: str, db: Session = Depends(get_db)) -> ApiResponse[ExportFileData]:
    task = db.scalar(
        select(InspectionTaskORM).where(
            InspectionTaskORM.task_id == task_id,
            InspectionTaskORM.deleted_at.is_(None),
        )
    )
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")

    storage_root = db.info.get("storage_root")
    if storage_root is None:
        raise HTTPException(status_code=500, detail="storage not configured")

    file_name, file_url = export_photo_package_zip(db=db, task=task, storage_root=storage_root)
    return ApiResponse(data=ExportFileData(file_name=file_name, file_url=file_url, format="zip"))


@router.get("/tasks/{task_id}/exports/inspection-doc", response_model=ApiResponse[ExportFileData])
def export_inspection_doc(task_id: str, db: Session = Depends(get_db)) -> ApiResponse[ExportFileData]:
    task = db.scalar(
        select(InspectionTaskORM).where(
            InspectionTaskORM.task_id == task_id,
            InspectionTaskORM.deleted_at.is_(None),
        )
    )
    if task is None:
        raise HTTPException(status_code=404, detail="task not found")

    storage_root = db.info.get("storage_root")
    if storage_root is None:
        raise HTTPException(status_code=500, detail="storage not configured")

    file_name, file_url = export_inspection_docx(db=db, task=task, storage_root=storage_root)
    return ApiResponse(data=ExportFileData(file_name=file_name, file_url=file_url, format="docx"))
