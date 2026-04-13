from datetime import datetime
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db.models import InspectionTaskORM, ProjectORM, ProjectStructureInstanceORM
from app.db.session import get_db
from app.models.enums import StructureCategory, StructureObjectType
from app.schemas.projects import (
    BatchInitStructureInstancesData,
    BatchInitStructureInstancesRequest,
    CreateProjectData,
    CreateProjectRequest,
    CreateStructureInstanceRequest,
    ProjectDetailData,
    ProjectListData,
    ProjectListItem,
    StructureInstanceData,
    StructureInstanceListData,
    UpdateProjectRequest,
    UpdateStructureInstanceRequest,
)
from app.schemas.response import ApiResponse
from app.schemas.structure_templates import (
    StructurePartTemplateItem,
    StructurePartTemplateListData,
)
from app.services.project_structures import (
    build_default_instance_names,
    get_object_meta,
    list_structure_part_templates,
)

router = APIRouter(prefix="/api/v1", tags=["projects"])


def _serialize_instance(row: ProjectStructureInstanceORM) -> StructureInstanceData:
    return StructureInstanceData(
        instance_id=row.instance_id,
        project_id=row.project_id,
        category_code=StructureCategory(row.category_code),
        object_type=StructureObjectType(row.object_type),
        instance_name=row.instance_name,
        template_source_type=StructureObjectType(row.template_source_type),
        enabled_for_capture=row.enabled_for_capture,
        enabled_for_report=row.enabled_for_report,
        default_part_template_code=row.default_part_template_code,
        sort_order=row.sort_order,
        created_at=row.created_at,
        updated_at=row.updated_at,
    )


def _next_sort_order(db: Session, project_id: str) -> int:
    rows = db.scalars(
        select(ProjectStructureInstanceORM)
        .where(
            ProjectStructureInstanceORM.project_id == project_id,
            ProjectStructureInstanceORM.deleted_at.is_(None),
        )
        .order_by(ProjectStructureInstanceORM.sort_order.desc())
        .limit(1)
    ).all()
    return (rows[0].sort_order + 10) if rows else 10


def _build_instance_row(
    *,
    project_id: str,
    object_type: StructureObjectType,
    instance_name: str,
    category_code: StructureCategory | None,
    template_source_type: StructureObjectType | None,
    sort_order: int,
) -> ProjectStructureInstanceORM:
    meta = get_object_meta(object_type)
    resolved_template = template_source_type or StructureObjectType(str(meta["template"]))
    resolved_category = category_code or StructureCategory(str(meta["category"]))

    return ProjectStructureInstanceORM(
        instance_id=f"psi_{uuid4().hex[:12]}",
        project_id=project_id,
        category_code=resolved_category.value,
        object_type=object_type.value,
        instance_name=instance_name.strip(),
        structure_type=object_type.value,
        template_source_type=resolved_template.value,
        alias_names=[],
        enabled_for_capture=True,
        enabled_for_report=True,
        default_part_template_code=resolved_template.value,
        sort_order=sort_order,
    )


@router.post("/projects", response_model=ApiResponse[CreateProjectData])
def create_project(payload: CreateProjectRequest, db: Session = Depends(get_db)) -> ApiResponse[CreateProjectData]:
    reservoir_name = payload.reservoir_name.strip()
    if not reservoir_name:
        raise HTTPException(status_code=400, detail="reservoir_name is required")
    project = ProjectORM(
        project_id=f"proj_{uuid4().hex[:12]}",
        project_name=reservoir_name,
        reservoir_name=reservoir_name,
        dam_type=payload.dam_type.value,
        description=payload.description,
    )
    db.add(project)
    db.commit()
    return ApiResponse(data=CreateProjectData(project_id=project.project_id))


@router.get("/projects", response_model=ApiResponse[ProjectListData])
def list_projects(
    include_archived: bool = False,
    db: Session = Depends(get_db),
) -> ApiResponse[ProjectListData]:
    query = select(ProjectORM).where(ProjectORM.deleted_at.is_(None))
    if not include_archived:
        query = query.where(ProjectORM.archived_at.is_(None))
    rows = db.scalars(query.order_by(ProjectORM.created_at.desc())).all()
    return ApiResponse(
        data=ProjectListData(
            items=[
                ProjectListItem(
                    project_id=row.project_id,
                    project_name=row.project_name,
                    reservoir_name=row.reservoir_name,
                    dam_type=row.dam_type,
                    created_at=row.created_at,
                    archived_at=row.archived_at,
                )
                for row in rows
            ]
        )
    )


@router.get("/projects/{project_id}", response_model=ApiResponse[ProjectDetailData])
def get_project(project_id: str, db: Session = Depends(get_db)) -> ApiResponse[ProjectDetailData]:
    row = db.scalar(
        select(ProjectORM).where(
            ProjectORM.project_id == project_id,
            ProjectORM.deleted_at.is_(None),
        )
    )
    if row is None:
        raise HTTPException(status_code=404, detail="project not found")

    return ApiResponse(
        data=ProjectDetailData(
            project_id=row.project_id,
            project_name=row.project_name,
            reservoir_name=row.reservoir_name,
            dam_type=row.dam_type,
            description=row.description,
            created_at=row.created_at,
            updated_at=row.updated_at,
            archived_at=row.archived_at,
        )
    )


@router.patch("/projects/{project_id}", response_model=ApiResponse[ProjectDetailData])
def patch_project(
    project_id: str,
    payload: UpdateProjectRequest,
    db: Session = Depends(get_db),
) -> ApiResponse[ProjectDetailData]:
    row = db.scalar(
        select(ProjectORM).where(
            ProjectORM.project_id == project_id,
            ProjectORM.deleted_at.is_(None),
        )
    )
    if row is None:
        raise HTTPException(status_code=404, detail="project not found")

    if payload.reservoir_name is not None:
        name = payload.reservoir_name.strip()
        if not name:
            raise HTTPException(status_code=400, detail="reservoir_name cannot be empty")
        row.reservoir_name = name
        row.project_name = name
    if payload.dam_type is not None:
        row.dam_type = payload.dam_type.value
    if payload.description is not None:
        row.description = payload.description
    row.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(row)

    return ApiResponse(
        data=ProjectDetailData(
            project_id=row.project_id,
            project_name=row.project_name,
            reservoir_name=row.reservoir_name,
            dam_type=row.dam_type,
            description=row.description,
            created_at=row.created_at,
            updated_at=row.updated_at,
            archived_at=row.archived_at,
        )
    )


@router.delete("/projects/{project_id}", response_model=ApiResponse[dict[str, str]])
def delete_project(
    project_id: str,
    force: bool = False,
    db: Session = Depends(get_db),
) -> ApiResponse[dict[str, str]]:
    row = db.scalar(
        select(ProjectORM).where(
            ProjectORM.project_id == project_id,
            ProjectORM.deleted_at.is_(None),
        )
    )
    if row is None:
        raise HTTPException(status_code=404, detail="project not found")

    has_task = db.scalar(
        select(InspectionTaskORM).where(
            InspectionTaskORM.project_id == project_id,
            InspectionTaskORM.deleted_at.is_(None),
        )
    )
    if has_task is not None and not force:
        raise HTTPException(status_code=400, detail="project has tasks, delete tasks first")
    if force:
        task_rows = db.scalars(
            select(InspectionTaskORM).where(
                InspectionTaskORM.project_id == project_id,
                InspectionTaskORM.deleted_at.is_(None),
            )
        ).all()
        for task in task_rows:
            task.deleted_at = datetime.utcnow()

    row.deleted_at = datetime.utcnow()
    db.commit()
    return ApiResponse(data={"project_id": project_id})


@router.patch("/projects/{project_id}/archive", response_model=ApiResponse[dict[str, str]])
def archive_project(project_id: str, db: Session = Depends(get_db)) -> ApiResponse[dict[str, str]]:
    row = db.scalar(
        select(ProjectORM).where(
            ProjectORM.project_id == project_id,
            ProjectORM.deleted_at.is_(None),
        )
    )
    if row is None:
        raise HTTPException(status_code=404, detail="project not found")
    row.archived_at = datetime.utcnow()
    db.commit()
    return ApiResponse(data={"project_id": project_id})


@router.post(
    "/projects/{project_id}/structure-instances/batch-init",
    response_model=ApiResponse[BatchInitStructureInstancesData],
)
def batch_init_structure_instances(
    project_id: str,
    payload: BatchInitStructureInstancesRequest,
    db: Session = Depends(get_db),
) -> ApiResponse[BatchInitStructureInstancesData]:
    project = db.scalar(
        select(ProjectORM).where(
            ProjectORM.project_id == project_id,
            ProjectORM.deleted_at.is_(None),
        )
    )
    if project is None:
        raise HTTPException(status_code=404, detail="project not found")

    existing = db.scalar(
        select(ProjectStructureInstanceORM).where(
            ProjectStructureInstanceORM.project_id == project_id,
            ProjectStructureInstanceORM.deleted_at.is_(None),
        )
    )
    if existing is not None:
        raise HTTPException(status_code=409, detail="batch-init can only run once")

    rows: list[ProjectStructureInstanceORM] = []
    preset_count_map = {preset.object_type: preset.count for preset in payload.presets}
    aux_count = preset_count_map.get(StructureObjectType.aux_dam, 0)
    sort_order = 10
    for preset in payload.presets:
        names = build_default_instance_names(preset.object_type, preset.count)
        if preset.object_type == StructureObjectType.main_dam and aux_count == 0:
            names = ["大坝"]
        for name in names:
            rows.append(
                _build_instance_row(
                    project_id=project_id,
                    object_type=preset.object_type,
                    instance_name=name,
                    category_code=None,
                    template_source_type=None,
                    sort_order=sort_order,
                )
            )
            sort_order += 10

    for custom in payload.custom_instances:
        rows.append(
            _build_instance_row(
                project_id=project_id,
                object_type=custom.object_type,
                instance_name=custom.instance_name,
                category_code=custom.category_code,
                template_source_type=custom.template_source_type,
                sort_order=sort_order,
            )
        )
        sort_order += 10

    db.add_all(rows)
    db.commit()
    return ApiResponse(
        data=BatchInitStructureInstancesData(
            initialized_count=len(rows),
            items=[_serialize_instance(row) for row in rows],
        )
    )


@router.post(
    "/projects/{project_id}/structure-instances",
    response_model=ApiResponse[StructureInstanceData],
)
def create_structure_instance(
    project_id: str,
    payload: CreateStructureInstanceRequest,
    db: Session = Depends(get_db),
) -> ApiResponse[StructureInstanceData]:
    project = db.scalar(
        select(ProjectORM).where(
            ProjectORM.project_id == project_id,
            ProjectORM.deleted_at.is_(None),
        )
    )
    if project is None:
        raise HTTPException(status_code=404, detail="project not found")

    row = _build_instance_row(
        project_id=project_id,
        object_type=payload.object_type,
        instance_name=payload.instance_name,
        category_code=payload.category_code,
        template_source_type=payload.template_source_type,
        sort_order=payload.sort_order if payload.sort_order is not None else _next_sort_order(db, project_id),
    )
    db.add(row)
    db.commit()
    db.refresh(row)
    return ApiResponse(data=_serialize_instance(row))


@router.patch(
    "/projects/{project_id}/structure-instances/{instance_id}",
    response_model=ApiResponse[StructureInstanceData],
)
def patch_structure_instance(
    project_id: str,
    instance_id: str,
    payload: UpdateStructureInstanceRequest,
    db: Session = Depends(get_db),
) -> ApiResponse[StructureInstanceData]:
    row = db.scalar(
        select(ProjectStructureInstanceORM).where(
            ProjectStructureInstanceORM.project_id == project_id,
            ProjectStructureInstanceORM.instance_id == instance_id,
            ProjectStructureInstanceORM.deleted_at.is_(None),
        )
    )
    if row is None:
        raise HTTPException(status_code=404, detail="structure instance not found")

    if payload.instance_name is not None and payload.instance_name.strip():
        row.instance_name = payload.instance_name.strip()
    if payload.enabled_for_capture is not None:
        row.enabled_for_capture = payload.enabled_for_capture
    if payload.enabled_for_report is not None:
        row.enabled_for_report = payload.enabled_for_report
    if payload.sort_order is not None:
        row.sort_order = payload.sort_order
    row.updated_at = datetime.utcnow()

    db.commit()
    db.refresh(row)
    return ApiResponse(data=_serialize_instance(row))


@router.get(
    "/projects/{project_id}/structure-instances",
    response_model=ApiResponse[StructureInstanceListData],
)
def list_structure_instances(project_id: str, db: Session = Depends(get_db)) -> ApiResponse[StructureInstanceListData]:
    rows = db.scalars(
        select(ProjectStructureInstanceORM)
        .where(
            ProjectStructureInstanceORM.project_id == project_id,
            ProjectStructureInstanceORM.deleted_at.is_(None),
        )
        .order_by(ProjectStructureInstanceORM.sort_order.asc(), ProjectStructureInstanceORM.created_at.asc())
    ).all()
    return ApiResponse(data=StructureInstanceListData(items=[_serialize_instance(row) for row in rows]))


@router.get("/structure-part-templates", response_model=ApiResponse[StructurePartTemplateListData])
def get_structure_part_templates(
    object_type: StructureObjectType | None = None,
) -> ApiResponse[StructurePartTemplateListData]:
    rows = list_structure_part_templates(object_type)
    return ApiResponse(data=StructurePartTemplateListData(items=[StructurePartTemplateItem(**row) for row in rows]))
