from pathlib import Path

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles

from app.db.session import init_db, set_storage_root
from app.routers.captures import router as captures_router
from app.routers.evidence import router as evidence_router
from app.routers.projects import router as projects_router
from app.routers.results import router as results_router
from app.routers.tasks import router as tasks_router
from app.schemas.response import ApiResponse


def create_app(database_url: str | None = None, storage_root: str | None = None) -> FastAPI:
    init_db(database_url)
    resolved_storage_root = Path(storage_root) if storage_root else (Path(__file__).resolve().parents[1] / "storage")
    set_storage_root(resolved_storage_root)

    app = FastAPI(
        title="Reservoir Inspection API",
        version="0.2.0",
        openapi_url="/api/v1/openapi.json",
        docs_url="/api/v1/docs",
    )
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            "http://127.0.0.1:7212",
            "http://localhost:7212",
        ],
        allow_origin_regex=r"https?://(127\.0\.0\.1|localhost)(:\d+)?",
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.exception_handler(HTTPException)
    async def http_exception_handler(_: Request, exc: HTTPException) -> JSONResponse:
        body = ApiResponse(
            success=False,
            message=str(exc.detail),
            error_code=f"HTTP_{exc.status_code}",
            data=None,
        ).model_dump()
        return JSONResponse(status_code=exc.status_code, content=body)

    @app.exception_handler(RequestValidationError)
    async def validation_exception_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
        errors = [
            {
                "field": ".".join(str(part) for part in e["loc"]),
                "message": e["msg"],
            }
            for e in exc.errors()
        ]
        body = ApiResponse(
            success=False,
            message="validation error",
            error_code="VALIDATION_ERROR",
            errors=errors,  # type: ignore[arg-type]
            data=None,
        ).model_dump()
        return JSONResponse(status_code=422, content=body)

    @app.get("/api/v1/health", response_model=ApiResponse[dict[str, str]])
    def health_check() -> ApiResponse[dict[str, str]]:
        return ApiResponse(success=True, message="ok", data={"status": "healthy"})

    app.include_router(tasks_router)
    app.include_router(projects_router)
    app.include_router(results_router)
    app.include_router(evidence_router)
    app.include_router(captures_router)
    app.mount("/storage", StaticFiles(directory=str(resolved_storage_root)), name="storage")
    return app


app = create_app()
