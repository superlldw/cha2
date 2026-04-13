# api 工程（FastAPI）

当前包含任务、模板、结果、证据和最小导出能力。

## 已实现接口（核心）
- `POST /api/v1/tasks`
- `GET /api/v1/tasks`
- `GET /api/v1/tasks/{task_id}`
- `GET /api/v1/tasks/{task_id}/template-tree`
- `POST /api/v1/results`
- `GET /api/v1/tasks/{task_id}/results`
- `GET /api/v1/tasks/{task_id}/progress`
- `POST /api/v1/evidence/upload`
- `GET /api/v1/results/{result_id}/evidence`
- `DELETE /api/v1/evidence/{evidence_id}`

## 最小导出接口（本阶段）
- `GET /api/v1/tasks/{task_id}/exports/issues-list`
- `GET /api/v1/tasks/{task_id}/exports/photo-sheet`

说明：当前导出格式为 CSV，导出文件写入 `storage/exports/{task_id}/` 并通过 `/storage/...` 访问。

## 快速启动
```bash
pip install -r requirements.txt
python scripts/generate_template_seed.py
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
