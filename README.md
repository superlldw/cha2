# 水库现场安全检查 App

一个基于规范附录A的水库现场安全检查与取证 App。

## 项目目标

本项目用于支持水库现场检查工作，围绕“规范检查表 + 现场证据 + 自动整理 + 导出成果”开展开发。

App 核心能力包括：

1. 创建检查任务
2. 按 A.1～A.8 章节开展检查
3. 每个检查项记录状态、问题、描述、建议
4. 绑定照片、语音、定位、附件
5. 支持离线保存
6. 支持导出规范检查表、问题清单、照片附表

## 目标用户

- 水库现场检查人员
- 安全鉴定技术人员
- 项目负责人
- 内业整理人员

## 当前阶段

MVP（最小可用版本）

本阶段重点解决：

- 现场拍照和记录同步完成
- 检查项结构化录入
- 回办公室后减少人工整理
- 自动导出基础成果

## 项目结构

```text
dam-inspection-app/
├─ apps/
│  └─ mobile/               # Flutter 移动端
├─ services/
│  ├─ api/                  # FastAPI 后端
│  ├─ export/               # 导出服务
│  └─ ai/                   # AI文本整理/语音后处理
├─ docs/
│  ├─ PRD.md
│  ├─ FIELD_MAP.md
│  ├─ ARCHITECTURE.md
│  └─ API_SPEC.md
├─ skills/
│  ├─ domain_terms.md
│  ├─ backend_rules.md
│  ├─ mobile_ui.md
│  └─ export_rules.md
└─ README.md
```

## 技术栈

- Mobile: Flutter
- API: FastAPI
- Database: PostgreSQL
- Offline cache: SQLite
- File storage: 对象存储
- Speech-to-text: 预留 provider 接口
- AI: 文本规范化、字段抽取、章节总结

## 核心设计原则

1. 以规范检查表为主线
2. 以章节和检查项为基本单元
3. 照片、语音、定位、附件作为证据挂接
4. 离线优先
5. 先模板、再模型、再接口、再页面、再导出

## 非目标（MVP 暂不做）

- 图像自动识别裂缝
- 完整商业化 SaaS
- 复杂权限体系
- GIS 高级地图分析
- 自动生成完整鉴定报告正文

## 开发方式

本项目使用 Codex 辅助开发：
- 先阅读 docs/ 和 skills/
- 再按模块小步实现
- 每次只做一个子任务
- 修改后必须自检和运行验证

## 阶段一交付（本次）

- 初始化 monorepo 目录结构（`apps/`、`services/`、`packages/`）
- 创建 `apps/mobile` Flutter 骨架
- 创建 `services/api` FastAPI 骨架
- 定义核心数据模型（task/template/result/evidence/export）
- 生成 `inspection_template_item` 种子数据结构脚本
- 输出下一步开发建议：`docs/NEXT_STEPS.md`
