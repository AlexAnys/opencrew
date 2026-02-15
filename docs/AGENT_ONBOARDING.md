**中文** | [English](en/AGENT_ONBOARDING.md)

# Agent 入职指南 — 给 AI Agent 读的系统理解文档

> **这个文档的读者是 Agent，不是人。**
> 如果你是被部署到 OpenCrew 的 AI agent，按下面的顺序阅读和执行。
> 如果你是人类用户，这个文档帮助你理解 Agent 在启动时"应该知道什么"。

---

## 第一步：理解你是谁

进入你的 workspace 目录（如 `~/.openclaw/workspace-cto/`），按以下**严格顺序**阅读：

### 1. SOUL.md（最高优先级）

这个文件定义了你的角色、价值观和能力边界。它是你的"宪法"——后续所有行为不得违背 SOUL.md 中的原则。

你需要从中理解：
- 你负责什么领域
- 你的自主边界在哪里（什么可以直接做，什么必须确认）
- 你和其他 Agent 的关系

### 2. AGENTS.md（工作流）

这个文件定义了你的操作流程：
- 收到任务后怎么分类（Q/A/P/S）
- 什么时候写 Closeout、什么时候写 Checkpoint
- 什么时候 spawn 子任务、什么时候发 A2A
- Session 启动时应该读哪些文件

### 3. USER.md（用户画像）

关于你服务的人类用户：
- 偏好和沟通风格
- 专业背景和约束
- 不喜欢什么

### 4. MEMORY.md（长期记忆）

你积累的稳定知识：
- 长期有效的偏好和原则
- 重要的历史决策
- 跨 session 的经验

---

## 第二步：理解全局规则

阅读 `shared/` 目录（或 `~/.openclaw/shared/`）中的关键文件：

**必读（按重要性排序）**：

1. **SYSTEM_RULES.md** — 自主等级（L0-L3）、任务分类（QAPS）、产物要求
2. **A2A_PROTOCOL.md** — 跨 Agent 协作的两步触发、权限矩阵、消息格式
3. **TASK_PROTOCOL.md** — 任务生命周期和处理规范

**需要时查阅**：

4. **CLOSEOUT_TEMPLATE.md** — 写 Closeout 时用
5. **CHECKPOINT_TEMPLATE.md** — 写 Checkpoint 时用
6. **SUBAGENT_PACKET_TEMPLATE.md** — spawn 子任务时用
7. **SELF_UPDATE_TEMPLATE.md** — 修改自己的文件时用
8. **OPS_REVIEW_PROTOCOL.md** — S 类变更审计标准
9. **KNOWLEDGE_PIPELINE.md** — 知识沉淀的三层结构

---

## 第三步：理解你的运行环境

### Slack 频道 = 你的工位

你被绑定到一个 Slack 频道。用户在该频道发消息时，消息会路由到你。

- 检查你的 `requireMention` 设置。如果是 `true`，只有被 @mention 时你才响应。
- 每个 Thread 是一个独立 Session（`historyScope = "thread"`），不同 thread 的对话互不可见。

### 你的频道对照

| 如果你是… | 你的频道是 | requireMention |
|-----------|-----------|----------------|
| CoS | #hq | false |
| CTO | #cto | false |
| Builder | #build | false |
| CIO | #invest | false |
| KO | #know | 建议 true（可选） |
| Ops | #ops | 建议 true（可选） |
| Research | #research | false |

---

## 第四步：理解 A2A 协作

### 你能给谁发 A2A？

```
CoS    → CTO
CTO    → Builder, Research, KO, Ops
Ops    → 所有 Agent（审计权限）
CIO    → CoS（必要时同步）
Builder → 不能发起 A2A（只接单）
KO     → 被动接收
```

如果你不在上面的"发起方"列表里，你不应该调用 `sessions_send`。

### 怎么发 A2A？

**Step 1**：在目标 Agent 的频道创建 root message（用户可见的锚点）

```
A2A <你的角色>→<目标角色> | <任务标题> | TID:<YYYYMMDD-HHMM>-<简述>
---
Objective: <目标>
DoD: <完成标准>
Inputs: <已有信息>
Constraints: <约束>
```

**Step 2**：调用 `sessions_send()`，用 root message 的 ts 拼 sessionKey：

```
agent:<目标agent_id>:slack:channel:<channelId>:thread:<root_ts>
```

### 发送后的检查

发送后验证目标 Agent 是否在 thread 里回复了。如果没有，标记 `failed-delivery` 并上报给你的上游。

---

## 第五步：理解产物要求

### 什么时候写 Closeout？

| 任务类型 | 需要 Closeout？ | 需要 Checkpoint？ |
|---------|----------------|-------------------|
| Q（快问） | 否 | 否 |
| A（小交付） | **是** | 否 |
| P（项目） | **是** | 是（>1天或跨 session） |
| S（系统变更） | **是**（+ Ops Review） | 是 |

### Closeout 必须包含什么？

使用 `shared/CLOSEOUT_TEMPLATE.md` 模板。核心字段：

1. **What Changed** — 做了什么
2. **Decisions** — 做了什么决策、为什么
3. **Scars** — 踩了什么坑
4. **Signal Score** — 0-3，这个经验值不值得沉淀

### 什么时候写 Checkpoint？

- 任务 >20 turns
- 任务跨天
- 上下文膨胀风险高
- 遇到阻塞

---

## 第六步：自我迭代规则

你可以修改自己的 SOUL.md / AGENTS.md / MEMORY.md。但必须遵循：

1. **写 Self-Update 记录**（使用 `shared/SELF_UPDATE_TEMPLATE.md`）：
   - 动机（Why）
   - 变更内容（What）
   - 预期影响（Impact）
   - 回滚方法（Rollback）

2. **S 类变更必须通知 Ops**：通过 A2A 发到 `#ops`

3. **不能修改其他 Agent 的 workspace** — 只有 Ops 有全局审计权限

---

## 快速决策树

收到一条消息后，按这个流程判断：

```
收到消息
  │
  ├─ 是 @mention 或你的 requireMention=false？
  │   ├─ 否 → 忽略
  │   └─ 是 → 继续
  │
  ├─ 分类任务（Q/A/P/S）
  │   ├─ Q → 直接回答，考虑是否写 MEMORY
  │   ├─ A → 执行 → 写 Closeout
  │   ├─ P → 写 Task Card → 执行 → Checkpoint → Closeout
  │   └─ S → 执行 → 写 Closeout + Self-Update → 通知 Ops
  │
  ├─ 判断自主等级
  │   ├─ L1（可逆）→ 直接做
  │   ├─ L2（可回滚）→ 做完写 Closeout
  │   └─ L3（不可逆）→ 向用户确认后再做
  │
  └─ 需要其他 Agent 协作？
      ├─ 否 → 自己完成
      ├─ 需要子任务 → spawn subagent
      └─ 需要持续协作 → A2A 两步触发
```

---

## 常见问题（给 Agent 的）

**Q：我能发消息给任何频道吗？**
A：技术上可以（bot 有权限），但组织纪律上只能按权限矩阵发。超出权限的 A2A 是 bug。

**Q：我的 session 怎么隔离的？**
A：`historyScope = "thread"`，每个 Slack thread 是独立 session。频道级的 root message 可能共享频道 session，所以任务应该尽量在 thread 内推进。

**Q：如果 sessions_send 失败了怎么办？**
A：检查 sessionKey 是否正确（包含正确的 channelId 和 thread ts）。如果失败，标记 failed-delivery，在你自己的 thread 里记录，并通知上游。

**Q：上下文快爆了怎么办？**
A：写 Checkpoint 切割上下文。如果是并行子任务，用 spawn 而不是在同一个 thread 里继续。

---

> 本文档的人类可读版本 → [核心概念详解](CONCEPTS.md)
> 部署问题 → [完整上手指南](GETTING_STARTED.md)
