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

## 4. A2A 两步触发

Agent 之间的协作需要一个特殊机制，因为所有 Agent 共用一个 Slack bot 身份——bot 自己发的消息不会触发自己。

### 为什么需要两步？

```
问题：CTO 在 #build 发了一条消息给 Builder
      → Slack 认为这是 bot 发的
      → Bot 默认忽略自己的消息
      → Builder 没收到
```

### 两步触发怎么工作

**Step 1：在目标频道创建可见的 root message（锚点）**

CTO 在 `#build` 发一条消息，格式如：

```
A2A cto→builder | 实现登录功能 | TID:20260210-1430-login
---
目标：在用户系统中增加 OAuth 登录
完成标准：单元测试通过、兼容 Google/GitHub
```

这条消息是给你看的——你随时能在 Slack 里看到"CTO 给 Builder 派了什么活"。

**Step 2：用 sessions_send 触发 Builder**

CTO 调用 `sessions_send()`，把消息推给 Builder 在该 thread 的 session。这才是真正让 Builder "动起来"的信号。

### 防循环保护

三层保护，防止 Agent 互相触发导致消息风暴：

| 保护层 | 机制 | 配置位置 |
|--------|------|---------|
| 权限矩阵 | 只有 CoS/CTO/Ops 能发起 A2A | `tools.agentToAgent.allow` |
| 来回上限 | 最多 4 次 ping-pong | `maxPingPongTurns = 4` |
| 子 Agent 限制 | 被 spawn 的子 Agent 不能再发起 A2A | `tools.subagents.tools.deny` |

### 权限矩阵

不是所有 Agent 都能给所有人派活。遵循组织纪律：

```
CoS → CTO（战略指导）
CTO → Builder / Research / KO（任务分发）
Ops → 所有人（审计权限）
Builder → 不能派单（只接单执行）
CIO → 独立运作（必要时与 CoS 同步）
```

### A2A 的两种模式：Delegation 与 Discussion

上面描述的两步触发是 **Delegation（委派）** 模式——一个 Agent 通过 `sessions_send` 把结构化任务交给另一个 Agent。这是 A2A 的基础，所有平台都支持，流程清晰、单向可控。

v2 引入了第二种模式：**Discussion（讨论）**。少数高价值 Agent（如 Orchestrator）拥有独立 Slack App，直接进入其他 Agent 的频道进行实时讨论。

**核心思路：选择性独立化。** 不需要每个 Agent 都有独立 App——执行层（CTO、Builder、CIO 等）继续共享一个 Slack App。只让需要跨域协作的 Agent（如 Orchestrator）拥有独立 App，把它拉进目标频道就能直接对话。

这里借鉴了 **Anthropic Harness Design** 的核心洞察：当一个 AI 既做执行又做 QA 时，它倾向于宽容自己的错误；既做规划又做执行时，倾向于投机取巧。将"想"和"做"分给不同 Agent——Orchestrator 负责规划和评估，执行层 Agent 负责实现——是解决 AI 自评失效最有效的杠杆。

**什么时候用哪个？**

| | Delegation（委派） | Discussion（讨论） |
|--|-------------------|-------------------|
| 场景 | "CTO 给 Builder 派一个具体任务" | "Orchestrator 进 #cto 跟 CTO 讨论方案，然后去 #build 跟 Builder 确认可行性" |
| 触发方式 | `sessions_send` | 显式 @mention |
| 方向性 | 单向，一对一 | 多向，多对多 |
| 平台 | Slack / Discord / Feishu | 仅 Slack（需独立 App） |

两种模式共存，不互相替代。Delegation 是"给任务"，Discussion 是"一起想"。

**为什么需要 Discussion？** Delegation 是任务分发：CTO 说做什么，Builder 照做。但真实团队不只是派活——他们讨论。Orchestrator 走进 CTO 的办公室说"这个方向你怎么看？"，CTO 说"技术上可以但成本高"，Orchestrator 又去问 Builder"你觉得多久能做完？"。Discussion 模式让 Agent 也能这样协作——Orchestrator-Bot 被拉进 #cto 频道，直接在 CTO 的地盘上对话，你可以实时旁观、随时插话。

### 平台能力对比

| 能力 | Slack | Discord | Feishu |
|------|-------|---------|--------|
| Delegation（sessions_send） | ✅ | ✅ | ✅ |
| Discussion（跨 bot 对话）| ✅ 已验证 | 不支持（OpenClaw 代码层 bug） | 不支持（飞书平台限制） |
| Thread / Topic 隔离 | 原生 thread | Thread（自动归档） | groupSessionScope（>= 2026.3.1） |

**为什么 Discord 和 Feishu 不支持 Discussion？**

- **Discord**：平台本身支持跨 bot 消息可见，但 OpenClaw 的 bot 消息过滤代码存在 bug（Issue #11199），把所有已配置的 bot 都当作"自己"并丢弃消息。属于代码层问题，理论上可修复，但修复 PR 均已关闭。
- **Feishu**：飞书的 `im.message.receive_v1` 事件**只投递用户发送的消息**——bot 发的消息对其他 bot 完全不可见。这是飞书平台 API 的设计决策，无法通过配置绕过。

### Discussion 模式的当前状态

Discussion 模式已通过端到端验证（2026-04-02）。两个独立 bot 可以在同一频道互相看到消息并进行结构化讨论。

通过 OpenClaw 源码验证 + 实测确认：
- Self-loop 过滤是 per-account 的（不同 Slack App 不互相过滤）✅
- `allowBots` 支持三级 fallback（per-channel > per-account > global）✅
- Per-account channel config 可以给同一频道的不同 bot 设置不同的 `requireMention` ✅
- 多账号配置需要**同时声明 `accounts.default`**（否则主 bot 断连）⚠️

**实战发现的限制**：
- `requireMention: true` 在 Thread 内被 `implicitMention` 绕过——需要 Prompt 规则配合
- `allowBots: "mentions"` 在 Slack 无效（仅 Discord 支持）
- Input token 无法避免——所有消息送达所有 bot，只能让 agent 回复 NO_REPLY

详细配置指南和陷阱清单见 [Discussion Mode 实操指南](A2A_SETUP_GUIDE.md)。完整协议见 `shared/A2A_PROTOCOL.md`。

---

## 5. 结构化产物：Closeout 和 Checkpoint

### Closeout — 任务结束时的结构化总结

每个 A/P/S 类任务完成后，执行者必须写一份 10-15 行的 Closeout：

```
CLOSEOUT A | 实现速率限制 | TID:20260210-1400-ratelimit
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
CHECKPOINT P | 数据库迁移 | TID:20260210-0900-dbmigrate | Progress: 40%
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
| `A2A_PROTOCOL.md` | 跨 Agent 协作的两步触发 + 权限矩阵 |
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
| A2A 发起权限 | 硬约束 | `tools.agentToAgent.allow` | 防止所有人都能派单 |
| A2A 循环上限 | 硬约束 | `maxPingPongTurns` | 防止消息风暴 |
| Subagent 权限 | 硬约束 | `tools.subagents.tools.deny` | 子 Agent 不能再 spawn |
| 频道隔离 | 硬约束 | `groupPolicy = "allowlist"` | 只响应允许的频道 |
| Thread 隔离 | 硬约束 | `historyScope = "thread"` | 每个 thread 独立 session |
| 回复模式 | 硬约束 | `replyToMode = "all"` | 回复自动进 thread |
| Ops 降噪 | 可选 | `requireMention = true` | 建议对 #ops/#know 开启 |

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
  ├─ Agent 之间通过 A2A 协作
  │   ├─ Delegation：两步触发 + 权限矩阵
  │   └─ Discussion：@mention 多 Agent 讨论 [已验证]
  │
  └─ 知识通过三层沉淀积累
      └─ 对话 → Closeout → KO 抽象知识
```

---

> 📖 下一步 → [架构设计详解](ARCHITECTURE.md) · [自定义 Agent](CUSTOMIZATION.md) · [已知问题](KNOWN_ISSUES.md)
