# 后端开发规则

## 通用规则

1. 所有字段使用 snake_case
2. 所有 API 返回统一 response model
3. 路由层只做参数校验和调度，不写复杂业务逻辑
4. 模板项与检查结果必须分表
5. 证据统一挂接到 inspection_evidence
6. 删除优先采用软删除
7. 时间统一存 UTC，展示时再转本地时区
8. 导出逻辑不要写在 controller 中

## 数据建模规则

1. inspection_task 表示任务
2. inspection_template_item 表示规范模板
3. inspection_result 表示任务中的检查结果
4. inspection_evidence 表示证据
5. export_snapshot 表示导出结果

## API 规则

1. 路由使用复数名词
2. 查询接口支持分页
3. 详情接口返回完整树或扁平结构说明
4. 保存检查结果支持幂等更新
5. 上传接口与业务字段分离

## 测试规则

1. 每个核心接口至少有一个成功用例
2. 每个重要校验至少有一个失败用例
3. 不为无业务价值的小函数过度编写测试
