# 下一步开发建议（阶段一后）

## 1. API 最小闭环（优先）

1. 基于 `InspectionTask`、`InspectionResult` 建立 SQLAlchemy ORM 与迁移脚本。
2. 先落地 `POST /tasks`、`GET /tasks/{task_id}`、`POST /results` 三个核心接口。
3. `POST /results` 做幂等保存：同 `task_id + item_code` 重复提交转更新。

## 2. 模板树接口

1. 读取 `inspection_template_items.json` 作为初始化数据源。
2. 实现 `GET /templates/tree`，支持 `dam_type` + `enabled_chapters` 过滤。
3. 严格执行 A.2/A.3 按坝型二选一。

## 3. 移动端最小录入链路

1. 完成任务列表页、任务详情页、章节列表页骨架。
2. 先实现文本字段离线保存（SQLite）。
3. 再挂接拍照/录音/定位入口，不做复杂 UI 动画。

## 4. 离线同步队列

1. 定义本地 `sync_queue`：`local_id/sync_status/retry_count/last_error`。
2. 先实现手动触发同步，再做自动重试策略。
3. 保持“本地优先写入，服务端最终一致”。

## 5. 导出准备

1. 提前固定导出字段顺序与章节顺序。
2. 问题清单仅取 `issue_flag=true`。
3. 保留原始记录文本，不覆盖用户原文。
