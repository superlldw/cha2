# API_SPEC.md

# 水库现场安全检查 App API 接口说明（MVP）

## 1. 文档目的

本文档用于定义水库现场安全检查 App 的前后端接口约定，供以下角色共同使用：

- Flutter 移动端开发
- FastAPI 后端开发
- Codex 辅助开发
- 测试与联调人员
- 后续导出与 AI 模块开发人员

## 2. 设计原则

1. 接口命名清晰、稳定
2. 字段命名统一使用 snake_case
3. 所有接口返回 JSON
4. 模板项和检查结果分离
5. 文件上传与业务保存分离
6. 统一错误返回结构
7. 支持移动端离线同步场景

## 3. 通用约定

### 3.1 Base URL

开发环境示例：

```text
http://localhost:8000/api/v1
```

### 3.2 鉴权方式

MVP 阶段建议使用简单 Bearer Token：

```http
Authorization: Bearer <token>
```

MVP 可先使用 mock 鉴权。

### 3.3 通用响应格式

#### 成功响应
```json
{
  "success": true,
  "message": "ok",
  "data": {}
}
```

#### 失败响应
```json
{
  "success": false,
  "message": "validation error",
  "error_code": "VALIDATION_ERROR",
  "errors": [
    {
      "field": "reservoir_name",
      "message": "required"
    }
  ]
}
```

### 3.4 通用分页参数

```json
{
  "page": 1,
  "page_size": 20
}
```

分页返回建议：

```json
{
  "items": [],
  "page": 1,
  "page_size": 20,
  "total": 120
}
```

### 3.5 时间格式

统一使用 ISO 8601：

```text
2026-04-11T09:30:00Z
```

前端展示时可转换本地时区。

## 4. 数据对象说明

### 4.1 inspection_task
一次现场检查任务。

### 4.2 inspection_template_item
附录A规范中的模板项。

### 4.3 inspection_result
某次任务中某个检查项的检查结果。

### 4.4 inspection_evidence
某条检查结果下挂接的照片、语音、视频、附件。

### 4.5 export_snapshot
某次导出生成的文件记录。

## 5. 接口总览

### 任务接口
- POST /tasks
- GET /tasks
- GET /tasks/{task_id}
- PUT /tasks/{task_id}

### 模板接口
- GET /templates/tree
- GET /tasks/{task_id}/template-tree

### 检查结果接口
- POST /results
- PUT /results/{result_id}
- GET /tasks/{task_id}/results
- GET /tasks/{task_id}/issues
- GET /tasks/{task_id}/progress

### 证据接口
- POST /evidence/upload
- GET /results/{result_id}/evidence
- DELETE /evidence/{evidence_id}

### 语音转写接口
- POST /speech/transcribe

### 导出接口
- POST /exports
- GET /tasks/{task_id}/exports

## 6. 任务接口

---

## 6.1 创建检查任务

### POST /tasks

### 作用
创建一条新的现场检查任务。

### 请求体
```json
{
  "reservoir_name": "某某水库",
  "dam_type": "earthfill",
  "inspection_type": "routine",
  "inspection_date": "2026-04-11",
  "weather": "晴",
  "inspectors": ["张三", "李四"],
  "water_level": 123.45,
  "storage": 5600000,
  "hub_main_structures": "大坝、溢洪道、输水洞",
  "flood_protect_obj": "下游村庄、农田、道路",
  "main_problem_desc": "",
  "enabled_chapters": ["A1", "A2", "A4", "A6", "A7", "A8"]
}
```

### 字段说明
- reservoir_name: 水库名称
- dam_type: 坝型，建议值：
  - earthfill
  - rockfill
  - concrete
  - masonry
- inspection_type: 检查类型，建议值：
  - routine
  - pre_flood
  - post_flood
  - special
  - safety_review
- inspection_date: 检查日期
- weather: 天气
- inspectors: 检查人员列表
- enabled_chapters: 本任务启用章节

### 成功响应
```json
{
  "success": true,
  "message": "ok",
  "data": {
    "task_id": "task_001"
  }
}
```

---

## 6.2 获取任务列表

### GET /tasks

### 查询参数
- page
- page_size
- keyword
- dam_type
- inspection_type
- status

### 示例响应
```json
{
  "success": true,
  "message": "ok",
  "data": {
    "items": [
      {
        "task_id": "task_001",
        "reservoir_name": "某某水库",
        "dam_type": "earthfill",
        "inspection_date": "2026-04-11",
        "status": "in_progress",
        "issue_count": 5
      }
    ],
    "page": 1,
    "page_size": 20,
    "total": 1
  }
}
```

---

## 6.3 获取任务详情

### GET /tasks/{task_id}

### 响应示例
```json
{
  "success": true,
  "message": "ok",
  "data": {
    "task_id": "task_001",
    "reservoir_name": "某某水库",
    "dam_type": "earthfill",
    "inspection_type": "routine",
    "inspection_date": "2026-04-11",
    "weather": "晴",
    "inspectors": ["张三", "李四"],
    "water_level": 123.45,
    "storage": 5600000,
    "hub_main_structures": "大坝、溢洪道、输水洞",
    "flood_protect_obj": "下游村庄、农田、道路",
    "main_problem_desc": "",
    "enabled_chapters": ["A1", "A2", "A4", "A6", "A7", "A8"],
    "status": "in_progress"
  }
}
```

---

## 6.4 更新任务

### PUT /tasks/{task_id}

### 请求体
允许更新：
- weather
- inspectors
- water_level
- storage
- main_problem_desc
- status

### 示例请求
```json
{
  "weather": "多云",
  "main_problem_desc": "下游右坝坡发现局部裂缝。",
  "status": "completed"
}
```

## 7. 模板接口

---

## 7.1 获取模板树（通用）

### GET /templates/tree

### 查询参数
- dam_type
- enabled_chapters

### 作用
按坝型和启用章节返回附录A模板树。

### 示例响应
```json
{
  "success": true,
  "message": "ok",
  "data": [
    {
      "chapter_code": "A2",
      "chapter_name": "挡水建筑物现场检查情况——土石坝",
      "children": [
        {
          "item_code": "A2_CREST",
          "item_name": "坝顶",
          "item_type": "section",
          "children": [
            {
              "item_code": "A2_CREST_ROAD",
              "item_name": "坝顶路面",
              "item_type": "inspection_item",
              "supports_photo": true,
              "supports_audio": true,
              "supports_location": true,
              "supports_attachment": false
            }
          ]
        }
      ]
    }
  ]
}
```

---

## 7.2 获取某任务模板树

### GET /tasks/{task_id}/template-tree

### 作用
返回该任务实际启用的检查模板树。

### 说明
后端应根据任务的 dam_type 和 enabled_chapters 自动过滤：
- A.2 和 A.3 二选一
- 仅返回当前任务需要的章节

## 8. 检查结果接口

---

## 8.1 创建检查结果

### POST /results

### 作用
为某个模板项创建或保存检查结果。

### 请求体
```json
{
  "task_id": "task_001",
  "item_code": "A2_CREST_ROAD",
  "check_status": "normal",
  "issue_flag": false,
  "issue_type": [],
  "severity_level": null,
  "check_record": "坝顶路面整体完好，未见明显异常。",
  "suggestion": "",
  "location_desc": "坝顶中段",
  "gps_lat": 26.123456,
  "gps_lng": 118.123456,
  "checked_at": "2026-04-11T09:30:00Z",
  "checked_by": "张三"
}
```

### check_status 建议值
- unchecked
- normal
- basically_normal
- abnormal
- not_applicable

### severity_level 建议值
- minor
- moderate
- serious
- critical

### 成功响应
```json
{
  "success": true,
  "message": "ok",
  "data": {
    "result_id": "result_001"
  }
}
```

---

## 8.2 更新检查结果

### PUT /results/{result_id}

### 作用
更新某一检查结果。

### 请求体
与 POST /results 基本一致。

---

## 8.3 获取任务下全部检查结果

### GET /tasks/{task_id}/results

### 查询参数
- chapter_code
- issue_flag
- check_status
- keyword

### 示例响应
```json
{
  "success": true,
  "message": "ok",
  "data": {
    "items": [
      {
        "result_id": "result_001",
        "item_code": "A2_CREST_ROAD",
        "item_name": "坝顶路面",
        "chapter_code": "A2",
        "check_status": "normal",
        "issue_flag": false,
        "check_record": "坝顶路面整体完好，未见明显异常。",
        "evidence_count": 2
      }
    ]
  }
}
```

---

## 8.4 获取异常项清单

### GET /tasks/{task_id}/issues

### 作用
仅返回 issue_flag=true 的检查结果。

### 示例响应
```json
{
  "success": true,
  "message": "ok",
  "data": [
    {
      "result_id": "result_010",
      "chapter_code": "A2",
      "item_code": "A2_BODY_DOWN_PROTECT",
      "item_name": "下游护坡设施",
      "issue_type": ["crack"],
      "severity_level": "moderate",
      "check_record": "下游右坝坡局部发现裂缝。",
      "suggestion": "建议复查并持续观测。"
    }
  ]
}
```

---

## 8.5 获取任务完成度

### GET /tasks/{task_id}/progress

### 作用
统计各章节完成情况。

### 示例响应
```json
{
  "success": true,
  "message": "ok",
  "data": {
    "overall": {
      "completed": 80,
      "total": 120,
      "percent": 66.7
    },
    "chapters": [
      {
        "chapter_code": "A1",
        "completed": 10,
        "total": 10,
        "issue_count": 0
      },
      {
        "chapter_code": "A2",
        "completed": 20,
        "total": 24,
        "issue_count": 2
      }
    ]
  }
}
```

## 9. 证据接口

---

## 9.1 上传证据

### POST /evidence/upload

### 作用
上传照片、语音、视频或附件。

### Content-Type
`multipart/form-data`

### 表单字段
- file: 文件
- result_id: 对应检查结果 ID
- evidence_type: photo / audio / video / attachment
- caption: 可选说明
- gps_lat: 可选
- gps_lng: 可选
- shot_time: 可选

### 成功响应
```json
{
  "success": true,
  "message": "ok",
  "data": {
    "evidence_id": "evi_001",
    "file_url": "https://example.com/file.jpg"
  }
}
```

---

## 9.2 获取某检查结果的证据列表

### GET /results/{result_id}/evidence

### 示例响应
```json
{
  "success": true,
  "message": "ok",
  "data": [
    {
      "evidence_id": "evi_001",
      "evidence_type": "photo",
      "file_url": "https://example.com/file.jpg",
      "caption": "坝顶路面现状",
      "gps_lat": 26.123456,
      "gps_lng": 118.123456,
      "shot_time": "2026-04-11T09:32:00Z"
    }
  ]
}
```

---

## 9.3 删除证据

### DELETE /evidence/{evidence_id}

### 作用
删除某个证据。

### 响应
```json
{
  "success": true,
  "message": "deleted",
  "data": {
    "evidence_id": "evi_001"
  }
}
```

## 10. 语音转写接口

---

## 10.1 上传音频并转写

### POST /speech/transcribe

### Content-Type
`multipart/form-data`

### 表单字段
- file: 音频文件
- language: zh-CN
- result_id: 可选，若提供则可自动回填对应结果

### 响应示例
```json
{
  "success": true,
  "message": "ok",
  "data": {
    "text": "下游右坝坡局部发现裂缝，建议后续复查。"
  }
}
```

## 11. 导出接口

---

## 11.1 创建导出任务

### POST /exports

### 作用
创建导出。

### 请求体
```json
{
  "task_id": "task_001",
  "export_type": "inspection_form",
  "file_format": "docx"
}
```

### export_type 建议值
- inspection_form
- issue_list
- photo_appendix

### file_format 建议值
- docx
- xlsx
- pdf

### 成功响应
```json
{
  "success": true,
  "message": "ok",
  "data": {
    "export_id": "exp_001",
    "status": "processing"
  }
}
```

---

## 11.2 获取某任务导出记录

### GET /tasks/{task_id}/exports

### 示例响应
```json
{
  "success": true,
  "message": "ok",
  "data": [
    {
      "export_id": "exp_001",
      "export_type": "inspection_form",
      "file_format": "docx",
      "status": "done",
      "file_url": "https://example.com/export.docx",
      "created_at": "2026-04-11T12:00:00Z"
    }
  ]
}
```

## 12. 错误码建议

- VALIDATION_ERROR
- NOT_FOUND
- UNAUTHORIZED
- FORBIDDEN
- FILE_UPLOAD_ERROR
- TRANSCRIBE_ERROR
- EXPORT_ERROR
- INTERNAL_ERROR

## 13. 移动端离线同步建议

移动端本地应缓存：

- tasks
- templates
- results
- evidence_metadata
- sync_queue

建议每条待同步记录有：
- local_id
- sync_status
- retry_count
- last_error

sync_status 建议值：
- pending
- synced
- failed

## 14. 开发备注

1. A.2 和 A.3 只能按坝型启用其一
2. A.7 部分检查项需支持资料类附件
3. A.8 可为后续地图模式预留扩展字段
4. 语音转写先使用 provider abstraction，不直接写死厂商
5. 导出内容优先保留用户原始记录
