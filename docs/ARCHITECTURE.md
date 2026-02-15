**中文** | [English](en/ARCHITECTURE.md)

> 📖 [README](../README.md) → [完整上手指南](GETTING_STARTED.md) → [核心概念](CONCEPTS.md) → **架构设计** → [自定义](CUSTOMIZATION.md)

# 架构设计

> 本文聚焦"为什么这么设计"。各机制的具体规则和参数见 → [核心概念详解](CONCEPTS.md)

## 设计目标

1. **领域专业分工**：不同类型的任务由专门的 Agent 处理，避免上下文污染
2. **结构化协作**：通过协议和模板让协作可追踪、可复用
3. **知识沉淀**：三层结构让经验从"聊天记录"变成"可复用资产"
4. **治理闭环**：系统可以自我迭代，但每一步可审计、可回滚

## 系统结构：三层架构

> 可视化架构图见：
> - 源文件（可编辑）：[OpenCrew-Architecture-with-slack.excalidraw](./OpenCrew-Architecture-with-slack.excalidraw)
> - （可选）导出一张 PNG：`docs/OpenCrew-Architecture-with-slack.png` 方便 GitHub 预览

OpenCrew 的架构分为三层，每层有明确的职责边界：

### 第一层：深度意图对齐层

用户和 CoS 并列。用户是决策者（定方向、验收结果），CoS 是战略伙伴（深度意图对齐、代用户推进）。

| Agent | 职责 | Slack 频道 | 说明 |
|-------|------|-----------|------|
| **YOU** 👤 | 定方向、验收结果 | 所有频道均可直接对话 | 想跟谁聊进哪个频道 |
| **CoS** 💎 | 深度意图对齐、代为推进 | #hq | 战略伙伴，**不是网关、不必经** |

CoS 的价值在于：跟用户对齐深层目标和价值判断，在用户不方便时代为推进任务给 CTO/CIO（虚线路径，可选）。用户完全可以绕过 CoS 直接跟任何 Agent 对话。

### 第二层：执行层

实际干活的 Agent。用户可以直接跟 CTO/CIO 对话，也可以通过 CoS 代为推进。

| Agent | 职责 | Slack 频道 | 关系 |
|-------|------|-----------|------|
| **CTO** 🛠️ | 技术架构、拆解、交付稳定性 | #cto | 用户直接对话 |
| **CIO** 📈 | 领域专家（**可替换为其他专业分工**）| #invest | 可选，虚线边框 |
| **Builder** 🧱 | 具体实现、测试、交付 | #build | CTO 指派 |
| **Research** 🔎 | 信息收集和分析 | #research | **可选**，按需 spawn，CTO/CIO 均可调度 |

CIO 默认是投资方向，但设计上它是一个**可替换插槽**——可以换成法律、营销、产品等任何领域专家。Research 是临时 worker，任务完成即释放。

### 第三层：系统维护层

不做业务，专职服务于系统健康。接收**所有 Agent 的产出**，负责知识沉淀和可控迭代。

| Agent | 职责 | Slack 频道 | 服务范围 |
|-------|------|-----------|---------|
| **KO** 🧠 | 从所有 Agent 的 closeout 提炼可复用知识 | #know（建议需@，可选） | 全系统知识沉淀 |
| **Ops** ⚙️ | 审计所有 Agent 的变更、防漂移 | #ops（建议需@，可选） | 全系统治理 |

建议将 #know/#ops 配成 `requireMention=true` 以降低噪音；但开源版默认关闭（优先保证新手“按步骤就能跑起来”），你可以在跑通后再打开。

### 外部：用户原有的 OpenClaw

用户现有的 OpenClaw Agent（webchat/terminal）与 OpenCrew 完全独立、互不影响。原有 Agent 可以协助部署和运维 OpenCrew。

### 为什么用 Slack 作为通信基础设施？

Slack 的产品特性天然匹配多 Agent 协作需求：

| Slack 特性 | 对应价值 |
|-----------|---------|
| 频道 | = Agent 岗位，一个 App 管所有 Agent |
| Thread | = 独立 Session，天然上下文隔离 |
| Unreads / Later | = 决策待办清单，一目了然 |
| A2A 跨频道输出 | 所有协作过程可见、完全可审计 |
| 草稿 / 已发送追踪 | Thread 回溯完整链路 |
| 手机端 | 随时审批·随地决策，碎片时间=管理时间 |
| 增减频道 | Agent↔频道即插即拔，灵活扩缩 |

## A2A 两步触发机制

### 为什么需要两步？

OpenClaw 的 Slack 集成中，所有 Agent 共用一个 bot 身份。bot 发出的消息默认被自己忽略（防自循环）。因此 Agent A 在 Slack 里发的消息，Agent B 不会自动处理。

解法是**两步触发**：

```
Step 1: Agent A 在 Agent B 的频道创建 root message（Slack 可见锚点）
Step 2: Agent A 调用 sessions_send() 触发 Agent B（真正的执行信号）
```

### Session Key 结构

```
agent:<target_agent_id>:slack:channel:<channelId>:thread:<root_ts>
```

这个 key 确保 Agent B 在该 thread 的上下文中执行，实现了 thread 级别的 session 隔离。

### 防循环三层保护

1. **权限矩阵**：只有 CoS/CTO/Ops 可以发起 sessions_send（config 层硬约束）
2. **maxPingPongTurns = 4**：限制 A2A 来回次数（config 层硬约束）
3. **Subagent deny sessions**：子 Agent 不能再 spawn sessions（config 层硬约束）

## 信息流

### 任务分派流（多种路径并存）

```
路径 1（直接）：User → #cto (CTO) → 拆解 → A2A → #build (Builder)
路径 2（经 CoS）：User → #hq (CoS) → 评估/指派 → A2A → #cto (CTO) → ...
路径 3（领域）：User → #invest (CIO) → 独立处理或 spawn Research
路径 4（CoS 代推）：CoS 主动推进 → A2A → CTO/CIO（用户授权或不在时）
```

用户不必经过 CoS——想跟谁聊就直接进那个频道。

### 结果汇报流

```
Builder closeout → CTO 同步到 #cto → User 在 #cto 可见（如经 CoS 则 CoS 同步到 #hq）
```

### 知识沉淀流

```
任何 Agent 的 closeout (signal ≥ 2) → #know → KO 提取 → knowledge/{principles,patterns,scars}.md
```

### 治理审计流

```
S 类 closeout / Self-Update → #ops → Ops 五维审计 → Approved / Needs-revision / Rejected
```

## Workspace 与 Shared 协议

> 完整的文件清单和字段说明见 → [核心概念详解 §7-§9](CONCEPTS.md#7-workspace-文件结构)

**关键设计决策**：
- **SOUL.md 优先级最高**：Agent 启动时第一个读取，确保"你是谁"高于"你怎么做"
- **SOUL 与 AGENTS 分离**：防止操作流程稀释角色定位
- **shared/ 通过 symlink 共享**：避免多份拷贝导致协议漂移

## 配置层硬约束

> 完整配置项清单见 → [核心概念详解 §9](CONCEPTS.md#9-配置层硬约束)

**核心原则**：能写进 config 的约束就不要只写在文档里。文档层的规则 Agent 可能"忘记"，配置层的规则无法绕过。

## 设计取舍

### 为什么是 7 个 Agent 而不是 3 或 10？
7 是当前的平衡点：足够的领域分化 + 可管理的协作复杂度。3 个太少（上下文还是会膨胀），10 个太多（A2A 协调成本爆炸：N*(N-1)/2 = 45 条通道）。

### 为什么用 Slack 而不是其他方式？
- Slack thread 天然支持任务级隔离
- 人可以随时看到 Agent 在做什么（显性可审计）
- OpenClaw 原生支持 Slack 集成
- 免费版够用

### 为什么 KO 和 Ops 是独立 Agent？
知识沉淀和系统治理是"元任务"——它们不服务于某个具体业务，而是服务于整个系统的健康。如果混在执行 Agent 里，要么被业务优先级挤掉，要么跟业务上下文冲突。独立出来让它们专注且不被干扰。这也是为什么它们的频道设置了 requireMention——降低噪音，只在需要时被唤起。

### 为什么 CoS 不是网关？
CoS 的价值在于**深度意图对齐**和**用户不在时代为推进**，而不是做信息中转。如果所有任务都经过 CoS，会造成意图损失和效率下降。用户直接跟 CTO/CIO 对话，意图传递最短路径，效率最高。CoS 是你的战略伙伴，不是你的秘书。

### SOUL.md 为什么和 AGENTS.md 分开？
SOUL 是角色的核心定位和原则（"你是谁，你的底线是什么"），AGENTS 是操作流程（"遇到任务怎么处理"）。分开防止流程细节稀释角色定位的优先级。

---

> 📖 下一步 → [自定义 Agent](CUSTOMIZATION.md) · [已知问题](KNOWN_ISSUES.md) · [核心概念详解](CONCEPTS.md)
