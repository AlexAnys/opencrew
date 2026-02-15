# TASK_PROTOCOL（任务分类、台账、完成定义）

## 1) Task Card（仅对 A/P/S）
在 `TASKS.md` 新建一条任务卡：
- id：YYYYMMDD-序号
- type：A/P/S
- owner：cos/cto/builder/cio/ko/ops
- objective：一句话
- definition_of_done：可验证条件（必须客观）
- risks：1-3条
- next_action：下一步（可执行）
- signal：0-3（是否需要KO/Ops复盘）

## 2) 完成判定（Definition of Done）
任务完成必须同时满足：
- DoD条件全部满足
- 关键产物已落盘（链接/文件/PR/笔记）
- 已写closeout（A/P/S）

## 3) 何时写 Closeout
- A：涉及代码/配置/投资框架/长期原则 → 必须
- P：必须
- S：必须
- Q：默认不写；若形成"可复用认知/原则/坑" → 写入MEMORY并打signal≥2

## 4) 何时写 Checkpoint（切割长任务）
任一触发即可：
- 任务跨天仍未完成
- 对话轮次 > 20轮
- 工具返回大量数据（如搜索结果 > 50条）
- 你预计用户可能中断/忘记回到此任务
- 需要把主线拆成多个并行子任务（spawn）

Checkpoint的结果：
- 刷新TASKS.md：把下一步明确化
- 必要时：生成"子任务列表"，由主Agent spawn执行

## 5) Spawn子任务
当需要并行/隔离/非阻塞执行：
- 用 SUBAGENT_PACKET_TEMPLATE.md 组装自包含任务包
- subagent没有你的SOUL/USER/MEMORY，任务描述必须完整
- 要求announce必须带：Status/Result/Notes
