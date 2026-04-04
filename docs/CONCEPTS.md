**中文** | [English](en/CONCEPTS.md)

> 📖 [README](../README.md) → [完整上手指南](GETTING_STARTED.md) → **核心概念** → [架构设计](ARCHITECTURE.md) → [自定义](CUSTOMIZATION.md)

# 核心概念详解

这个页面把 OpenCrew 的所有关键机制集中在一处。你不需要一次看完——遇到不理解的概念时回来查就行。

---

## 1. 频道 = 岗位，Thread = 任务

这是 OpenCrew 最基础的映射关系，理解了这个，后面全都顺了。

**频道就是岗位。** 每个 Slack 频道对应一个 Agent 的"工位"。你想跟 CTO 聊，就进 `#cto`；想让 Builder 干活，就在 `#build` 里开 thread。

**Thread 就是任务。** 一个 thread = 一个任务 = 一个独立 session。不同 thread 的上下文互不污染。你可以在同一个频道里同时开多个 thread（即多个任务并行）。

**Unreads 就是你的待办。** Slack 的未读消息自动变成你的决策清单——哪些 thread 有更新、哪些 Agent 在等你确认，打开手机一目了然。

| Slack 特性 | 在 OpenCrew 里的含义 |
|-----------|-------------------|
| 频道 | Agent 的岗位 |
| Thread | 独立任务 / Session |
| Unreads / Later | 你的决策待办 |
| Root message | 任务锚点（A2A 可见性保障） |
| 手机端 | 碎片时间 = 管理时间 |

---

## 2. 自主等级（Autonomy Ladder）

Agent 不是所有事都要问你。Autonomy Ladder 定义了"什么时候 Agent 该自己做，什么时候必须找你"。

| 等级 | 含义 | Agent 行为 | 举例 |
|------|------|-----------|------|
| **L0** | 只建议 | 不执行任何操作 | "我建议这样做，你确认后我再动手" |
| **L1** | 可逆操作 | 直接做 ✅ | 写草稿、做调研、整理文档、编辑代码 |
| **L2** | 有影响但可回滚 | 做完写 Closeout ✅ | 提 PR、改配置文件、写投资分析 |
| **L3** | 不可逆操作 | **必须你确认** ❌ | 发布版本、执行交易、删除数据、对外发送 |

**设计原则**：默认 L1/L2 自主推进，L3 必须人确认。这让 Agent 在安全范围内最大化产出，同时在关键节点把控制权交给你。

每个 Agent 的 SOUL.md 里会写明它的自主边界。例如 Builder：

```
✅ 可以直接做：写代码、提 PR、跑测试
❌ 必须确认：merge 到 main、发版、删除分支
```

---

## 3. 任务分类（QAPS）

不同类型的任务，处理规范不同。QAPS 让 Agent 知道每个任务需要"认真到什么程度"。

| 类型 | 全称 | 特征 | 产出要求 | 典型场景 |
|------|------|------|---------|---------|
| **Q** | Query | 一次性问答 | 无需 Closeout | "什么是 Socket Mode？" |
| **A** | Artifact | 有交付物的小任务 | 必须 Closeout | "帮我写个 API 文档" |
| **P** | Project | 多步骤、可能跨天 | Task Card + Checkpoint + Closeout | "迁移数据库架构" |
| **S** | System | 系统级变更 | Ops Review + Closeout + 回滚方案 | "修改 Agent 的 SOUL.md" |

**为什么需要分类？** 如果所有任务都用同样的规范，小问题会被过度处理（浪费），大问题会被轻率对待（风险）。QAPS 让"认真程度"和"任务重要性"匹配。

---

## 4. A2A — Agent 之间的原生协作

OpenCrew 默认所有 Agent 共享一个 Slack bot 身份，bot 自己发的消息会被自己忽略（防自循环）。这导致 Agent 之间无法在 Slack 中直接对话。

### 解决方案：选择性独立化

让少数 Agent 拥有**独立 Slack App**，然后拉进其他 Agent 的频道直接对话：

```
         独立 Slack App              共享 Slack App (现有)
         ┌──────────────┐           ┌─────────────────┐
         │ Orchestrator │           │   Default-Bot   │
         └──────┬───────┘           └───┬───┬───┬─────┘
                │                       │   │   │
频道：  #home  #cto  #build          #cto #build #invest ...
        ──────────────────────────────────────────────────
Agent：  Orch  ← 进入协作 →          CTO  Builder  CIO ...
```

不需要每个 Agent 都有独立 App——执行层继续共享。只让需要跨域协作的 Agent（如 Orchestrator）拥有独立 App，把它拉进目标频道就能直接对话。你可以在 Slack 中实时旁观讨论、随时插话。

### 为什么要分离 Orchestrator 和 Worker

借鉴 **Anthropic Harness Design** 的核心洞察：

- 当一个 AI **既做执行又做 QA** 时，它倾向于宽容自己的错误
- 当一个 AI **既做规划又做执行** 时，它倾向于投机取巧

将"想"和"做"分给不同 Agent——Orchestrator 负责规划和评估，Worker 负责实现——是解决 AI 自评失效最有效的杠杆。

### 协作流程

```
你 → @Orchestrator: "讨论 X 方案"

Phase 0: Orchestrator 展开 DISCUSSION SPEC（目标 + 验收标准）
Round 1: Orchestrator → @Worker: 问题
         Worker → @Orchestrator: 回答
Round 2: Orchestrator 评估 → 继续 / 终止
...
终止: ✅ 标准满足 | ⚠️ 到限 | 🔄 无进展 → DISCUSSION_CLOSE
```

### 防循环：两层防线

| 层级 | 机制 | 作用范围 | 类型 |
|------|------|----------|------|
| Config | `requireMention: true` | Channel 根消息 | 硬约束 |
| Prompt | 显式 @mention 协议 | Thread 内 | 软约束 |

Thread 内 `requireMention` 会被 `implicitMention` 绕过（bot 参与过 thread 后永远为 true）。因此每个参与讨论的 Agent 还需要 Prompt 规则：收到消息时检查是否有显式 `<@自己的BotID>`，没有就回复 NO_REPLY。

### 平台支持

| 平台 | A2A v2（原生协作） |
|------|-------------------|
| **Slack** | ✅ 已验证 |
| **Discord** | ❌ OpenClaw 代码层 bug（#11199、#45300） |
| **Feishu** | ❌ 平台限制（bot 消息不投递给其他 bot） |

> Discord/Feishu 用户如需 Agent 间协作，可参考 `shared/A2A_PROTOCOL.md` 附录 C（旧版 Delegation 模式）。

详细配置指南见 [Discussion Mode 实操指南](A2A_SETUP_GUIDE.md)。完整协议见 `shared/A2A_PROTOCOL.md`。

---

## 5. 结构化产物：Closeout 和 Checkpoint

### Closeout — 任务结束时的结构化总结

每个 A/P/S 类任务完成后，执行者必须写一份 10-15 行的 Closeout：

```
CLOSEOUT A | 实现速率限制 | 20260210
---
## 做了什么
- 在 API gateway 中新增 Token Bucket 限流
- 测试覆盖率 89%

## 关键决策
1. 选择 Token Bucket 而非 Sliding Window（原因：分布式场景更简单）
2. 限制值 100 req/sec per IP（基于容量模型）

## 踩坑
- Redis 同步延迟导致竞态 → 改用 in-memory + graceful degradation

## Signal: 3（通用技术模式，值得沉淀）
```

**为什么需要 Closeout？**

- 信息压缩：50K token 的对话 → 1-2K 的总结（约 25x 压缩）
- KO 只读 Closeout，不读海量对话
- 你只看 Closeout 就知道发生了什么

### Checkpoint — 长任务的中间汇报

对于跨天的 P 类任务，每天或每个关键节点写一次：

```
CHECKPOINT P | 数据库迁移 | 20260210 | Progress: 40%
---
已完成：✅ schema 设计 ✅ 测试环境搭建
进行中：🔄 数据迁移脚本（50%）
阻塞项：⚠️ 等待 DBA 审批（预计 2/12）
```

---

## 6. 三层知识沉淀

经验怎么从"聊天记录"变成"组织资产"？靠三层过滤：

```
Layer 0: 原始对话
  │ 全量保留，用于审计，不直接复用
  │
  ↓ Closeout 压缩（~25x）
  │
Layer 1: Closeout（结构化总结）
  │ 所有 A/P/S 任务的产出
  │ Signal 评分 0-3
  │
  ↓ KO 提炼（Signal ≥ 2 才进入）
  │
Layer 2: 抽象知识
  ├── Principles（原则）："在 X 场景下应该 Y"
  ├── Patterns（模式）："这种问题的通用解法是 Z"
  └── Scars（伤疤）："绝对不要做 W，因为…"
```

### Signal 评分

不是所有 Closeout 都值得进知识库。Signal 评分做过滤：

| 分数 | 含义 | 处理方式 |
|------|------|---------|
| 0 | 一次性修复，无复用价值 | Agent 自留 |
| 1 | 特定场景有用，难以泛化 | Agent 自留 |
| 2 | 可能被其他任务复用 | KO 提炼 → 知识库 |
| 3 | 通用模式，多领域适用 | KO 重点提炼 → 知识库 |

---

## 7. Workspace 文件结构

每个 Agent 的 workspace 就是它的"脑"：

| 文件 | 作用 | 读取优先级 | 更新频率 |
|------|------|-----------|---------|
| **SOUL.md** | 角色定位、核心原则、自主边界 | **最高**（启动必读） | 极低 |
| **AGENTS.md** | 工作流程、任务处理逻辑 | 高 | 中 |
| **USER.md** | 用户画像：偏好、风格、约束 | 中 | 低 |
| **MEMORY.md** | 长期记忆：稳定偏好、原则、经验 | 中 | 中 |
| **IDENTITY.md** | 名字、emoji、一句话定位 | 低 | 极低 |
| **TOOLS.md** | 工具和环境配置 | 低 | 低 |
| **TASKS.md** | 当前任务看板 | 按需 | 高 |
| **HEARTBEAT.md** | 周期性检查清单 | 按需 | 按需 |

**关键设计**：SOUL.md 在最前面读，确保"你是谁"的优先级高于"你怎么做"。把角色定位和操作流程分开（SOUL vs AGENTS），是为了防止流程细节稀释角色定位。

---

## 8. shared/ 全局协议

`shared/` 目录放的是所有 Agent 共享的"员工手册"——统一的协议和模板，避免每个 Agent 各写一套导致漂移。

| 文件 | 内容 |
|------|------|
| `SYSTEM_RULES.md` | Autonomy Ladder + QAPS + 产物要求 |
| `A2A_PROTOCOL.md` | 原生 Agent 协作协议（独立 Bot + @mention） |
| `TASK_PROTOCOL.md` | 任务分类和处理规范 |
| `CLOSEOUT_TEMPLATE.md` | Closeout 模板 |
| `CHECKPOINT_TEMPLATE.md` | Checkpoint 模板 |
| `OPS_REVIEW_PROTOCOL.md` | S 类变更的五维审计 |
| `KNOWLEDGE_PIPELINE.md` | 知识沉淀管道 |
| `SUBAGENT_PACKET_TEMPLATE.md` | spawn 子任务的任务包模板 |
| `SELF_UPDATE_TEMPLATE.md` | Agent 自我迭代记录模板 |

> 这些文件不是文档摆设——它们被各 Agent 的 AGENTS.md 作为工作流引用，关键约束同时下沉到 OpenClaw 配置层（硬约束 > 软约束）。

---

## 9. 配置层硬约束

有些规则靠"Agent 自觉遵守"（文档层），有些直接在配置里强制执行（配置层）。后者更可靠。

| 约束 | 类型 | 配置项 | 为什么需要 |
|------|------|--------|-----------|
| Bot 消息可见 | 硬约束 | `allowBots: true` | Agent 间协作的前提 |
| 显式触发 | 硬约束 | `requireMention: true` | 防止 Channel 根消息双触发 |
| Subagent 权限 | 硬约束 | `tools.subagents.tools.deny` | 子 Agent 不能再 spawn |
| 频道隔离 | 硬约束 | `groupPolicy = "allowlist"` | 只响应允许的频道 |
| Thread 隔离 | 硬约束 | `historyScope = "thread"` | 每个 thread 独立 session |
| 回复模式 | 硬约束 | `replyToMode = "all"` | 回复自动进 thread |
| 多账号安全 | 硬约束 | `accounts.default` 必须显式声明 | 防止主 bot 断连 |

**实践建议**：能写进 config 的约束就不要只写在文档里。文档层的规则 Agent 可能"忘记"，配置层的规则无法绕过。

---

## 概念关系图

```
你（决策者）
  │
  ├─ 在 Slack 频道（=岗位）中对话
  │   └─ 每个 Thread（=任务）是独立 Session
  │
  ├─ Agent 按 Autonomy Ladder 自主推进
  │   └─ L1/L2 直接做，L3 找你确认
  │
  ├─ 任务按 QAPS 分类处理
  │   └─ Q 轻量处理，A/P/S 必须 Closeout
  │
  ├─ Agent 之间通过 A2A 原生协作
  │   └─ 独立 Bot + @mention 协议 [已验证]
  │
  └─ 知识通过三层沉淀积累
      └─ 对话 → Closeout → KO 抽象知识
```

---

> 📖 下一步 → [架构设计详解](ARCHITECTURE.md) · [自定义 Agent](CUSTOMIZATION.md) · [已知问题](KNOWN_ISSUES.md)
