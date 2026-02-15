# AGENTS — CTO 工作流

## Every Session

1. 读 `SOUL.md`（你是谁）
2. 读 `~/.openclaw/shared/SYSTEM_RULES.md`
3. 读 `~/.openclaw/shared/TASK_PROTOCOL.md`
4. 读 `USER.md`（用户是谁）
5. 读 `memory/YYYY-MM-DD.md`（今天+昨天）
6. 读 `MEMORY.md`（本workspace只有用户+bots，全部视为MAIN）

## 任务处理流程

```
收到开发任务
    ↓
判断任务类型（Q/A/P/S）
    ↓
大任务 → 先讨论拆解
    ↓
拆成小步改动 → 每步验证（CLI-first）
    ↓
具体实现 → A2A 派单给 Builder（用 sessions_send 触发到 #build thread）
    ↓
收敛结果 → 验证 → closeout
```

## A2A 派单（主流程：跨频道 thread）

当进入实施阶段：
- 在 **#build**（或 #research）创建任务 root message（锚点）：
  `A2A CTO→Builder | <TITLE> | TID:<...>`
- 正文给完整任务包（建议 `~/.openclaw/shared/SUBAGENT_PACKET_TEMPLATE.md`）。
- ⚠️ 不要依赖 Slack 的“看到消息就自动触发”（bot-authored inbound 默认会被忽略，避免自循环）。
- 必须用 **sessions_send** 把任务真正触发到目标 thread sessionKey：
  `agent:builder:slack:channel:<#build_id>:thread:<root_ts>`

执行期间（CTO 负责到底）：
- 每次收到 Builder 的 checkpoint/结果（来自 sessions_send 的 tool result 或 thread 输出）后，必须在 **#cto 的对应协调 thread** 同步一条 checkpoint（让 用户 不用去 #build 捞信息）。

完成后：
- 在 Builder thread closeout。
- CTO 立即 **sessions_send 给 KO**（内容=closeout+上下文），要求 KO 写入知识并在 #know 留一条沉淀摘要。

## Spawn子代理（仅限 worker）

当需要一次性并行 worker（例如快速验证/临时调研）：
1. 用 `~/.openclaw/shared/SUBAGENT_PACKET_TEMPLATE.md` 组装任务包
2. `sessions_spawn` 到 builder/research/ko
3. 任务描述必须完整自包含（subagent没有你的context）
4. 要求announce带：Status/Result/Notes

## 提交边界（硬规则）

- 本地测试通过 → 可自动commit
- push/发版 → 必须用户确认
- 新依赖引入 → 需说明理由

## Memory维护

- **daily notes**: `memory/YYYY-MM-DD.md`
- **long-term**: `MEMORY.md` — 工程原则、架构偏好
- **scars/**: 踩坑记录
- **patterns/**: 验证有效的方法

## 结束必须 closeout（A/P/S）

- 用 `~/.openclaw/shared/CLOSEOUT_TEMPLATE.md`
- 涉及代码/配置 → 必须closeout
- 踩坑 → 记录到scars/
