# mobile 工程（Flutter）

当前为最小可用原型，已接入真实后端接口，并增加离线 SQLite 最小闭环。

## 已完成页面
1. 任务列表页（含手动同步、重试失败同步、同步状态摘要）
2. 新建任务页（最小字段）
3. 任务详情页（含最小导出入口）
4. 章节/检查项列表页
5. 检查项详情页（含图片证据最小 UI：选图 + 拍照 + 状态提示）

## 已接入接口
- `POST /api/v1/tasks`
- `GET /api/v1/tasks`
- `GET /api/v1/tasks/{task_id}`
- `GET /api/v1/tasks/{task_id}/template-tree`
- `GET /api/v1/tasks/{task_id}/results`
- `GET /api/v1/tasks/{task_id}/progress`
- `POST /api/v1/results`
- `POST /api/v1/evidence/upload`（仅 `photo`）
- `GET /api/v1/results/{result_id}/evidence`
- `DELETE /api/v1/evidence/{evidence_id}`
- `GET /api/v1/tasks/{task_id}/exports/issues-list`
- `GET /api/v1/tasks/{task_id}/exports/photo-sheet`

## 导出能力（本阶段）
- 任务详情页提供两个最小导出入口：
  - 问题清单导出
  - 照片附表导出
- 当前导出格式为 **CSV**（不是 XLSX），取舍原因：
  - MVP 阶段实现更轻量、依赖更少
  - 文件可直接下载和查看
- 不包含完整规范检查表导出，不包含 PDF。

## 同步状态可视化（本阶段）
- 任务列表页显示同步状态摘要：
  - `pending`
  - `failed`
  - `synced`
- 检查项详情页显示：
  - 当前结果 `sync_status`
  - 当前证据状态统计（pending/failed/synced）
  - 每条证据的 `sync_status`

## 手动同步与重试（本阶段）
- 任务列表页右上角：
  - `手动同步`：同步 pending + failed
  - `重试失败同步`：仅同步 failed
- 每次同步完成后会反馈：
  - 成功多少条
  - 失败多少条

## 离线能力（本阶段）

### SQLite 本地缓存范围
- `tasks`
- `template_tree`
- `inspection_results`
- `evidence_metadata`
- `sync_queue`

### 同步状态
- `pending`
- `synced`
- `failed`

### 无网可用能力
- 查看已缓存任务列表
- 查看已缓存模板树
- 保存检查项结果（写入本地 + 入队）
- 保存图片证据元数据（写入本地 + 入队）

说明：无网时拍照/选图后先保存本地图片路径与元数据，手动同步时再上传。

## API base URL 配置
App 优先读取 `--dart-define=API_BASE_URL=...`。

默认值：
- Android 模拟器：`http://10.0.2.2:8000/api/v1`
- 其他平台：`http://127.0.0.1:8000/api/v1`

## 运行步骤
1. 启动后端（目录 `E:\codex_project\xianchangjianchaapp\services\api`）
   - `uvicorn app.main:app --host 0.0.0.0 --port 8000`
2. 启动 Flutter（目录 `E:\codex_project\xianchangjianchaapp\apps\mobile`）
   - `flutter pub get`
   - Android 模拟器：`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1`
   - Android 真机示例：`flutter run --dart-define=API_BASE_URL=http://<你的电脑局域网IP>:8000/api/v1`

## 已知限制
- 仅支持 `photo` 类型证据前端 UI（不含音频/视频/附件）
- 导出当前仅支持 CSV，不支持 XLSX/PDF
- 不做图片压缩、水印、标注、裁剪
- 不做复杂冲突解决
- 不含完整规范检查表导出
- 不含语音转写
- 不含权限系统
- 不做复杂 UI 美化
