# 系统架构说明

## 1. 总体架构

本项目采用前后端分离架构：

- apps/mobile: Flutter 移动端
- services/api: FastAPI 后端
- services/export: 导出服务
- services/ai: AI 文本整理与语音后处理

## 2. 设计原则

1. 模板先行
2. 数据结构统一
3. 离线优先
4. 检查项与证据分离
5. 导出基于规范模板

## 3. 核心数据结构

### 3.1 inspection_task
表示一次检查任务。

主要字段：
- task_id
- reservoir_name
- dam_type
- inspection_date
- weather
- inspectors
- water_level
- storage
- main_problem_desc
- enabled_chapters

### 3.2 inspection_template_item
表示规范模板项。

主要字段：
- item_id
- item_code
- chapter_code
- parent_code
- item_name
- item_type
- applicable_dam_type
- supports_photo
- supports_audio
- supports_location
- supports_attachment
- sort_order

### 3.3 inspection_result
表示某次任务中某个检查项的结果。

主要字段：
- result_id
- task_id
- item_code
- check_status
- issue_flag
- issue_type
- severity_level
- check_record
- suggestion
- location_desc
- gps_lat
- gps_lng
- checked_at
- checked_by

### 3.4 inspection_evidence
表示挂在某个检查结果下的证据。

主要字段：
- evidence_id
- result_id
- evidence_type
- file_url
- file_name
- shot_time
- gps_lat
- gps_lng
- caption

### 3.5 export_snapshot
表示导出成果版本。

主要字段：
- export_id
- task_id
- export_type
- file_url
- version_no
- created_at

## 4. 离线架构

移动端采用 SQLite 保存：

- task cache
- template cache
- result cache
- evidence metadata
- sync queue

同步状态：
- pending
- synced
- failed

## 5. API 范围（MVP）

- POST /tasks
- GET /tasks/{id}
- GET /tasks/{id}/template-tree
- POST /results
- PUT /results/{id}
- POST /evidence/upload
- GET /tasks/{id}/issues
- GET /tasks/{id}/progress
- POST /exports

## 6. 语音转写设计

MVP 不直接绑定厂商。

采用 provider abstraction：
- SpeechProvider interface
- MockSpeechProvider
- CloudSpeechProvider（后续接入）

流程：
1. 移动端录音
2. 上传音频
3. 后端调用 provider
4. 返回文本
5. 回填 check_record

## 7. 导出设计

导出三类成果：

1. 规范检查表
2. 问题清单
3. 照片附表

导出逻辑：
- A.1 填表头
- A.2/A.3 根据坝型二选一
- A.4～A.8 按模板树展开
- 问题清单从 issue_flag=true 中提取
- 照片附表按章节和检查项聚合

## 8. 开发顺序

1. 文档和字段清单
2. 模板种子数据
3. 后端模型和 API
4. Flutter 页面骨架
5. SQLite 离线
6. 证据上传
7. 语音转写
8. 导出
