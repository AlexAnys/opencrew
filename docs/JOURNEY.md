> 📖 [README](../README.md) → **开发历程**

# 开发历程 — 从一个人的痛点到一支虚拟团队

> 这个项目源自一个真实 OpenClaw 重度用户的实践：从个人痛点出发，在真实工作流里不断试错迭代。以下是踩坑记录和设计决策。

## 为什么要做这个

用了几周 OpenClaw 之后，发现一个核心矛盾：**OpenClaw 的能力上限很高，但单 Agent 架构下的使用体验有天花板**。

具体来说：
- 开发项目 A 积累的上下文，在切换到理财任务 B 时变成了噪音
- 多个项目并行时，不同 session 之间切换的认知成本非常高
- 有价值的经验（踩过的坑、做过的决策）散落在各个聊天记录里，无法系统复用
- Agent 每一步都要我确认，但很多判断其实我也不比它专业

核心洞察：**问题不是 OpenClaw 不够强，而是一个 Agent 不够用**。需要一个团队。

## Phase 1：角色设计（从 3 到 7）

最初只设想了 3 个角色：CoS（总管）、CTO（技术）、Builder（执行）。

很快发现不够：
- 知识沉淀没人管，做过的事情很快被遗忘
- 系统规则改了没人审计，Agent 的行为在慢慢漂移
- 投资相关的任务跟开发任务混在一起

于是扩展到 7 个：加入了 KO（知识）、Ops（治理）、CIO（投资/领域）、Research（调研）。

**教训**：角色数量的 sweet spot 取决于你的实际需求多样性。3 个太少（上下文还是会膨胀），10 个太多（协调成本爆炸）。建议从核心 3 个开始，按需添加。

## Phase 2：协作机制（A2A 两步触发）

最大的技术挑战是让 Agent 之间能协作。

**踩坑 1：bot 消息自循环**
一开始以为在 Slack 里 Agent A 发消息，Agent B 会自动处理。结果发现 OpenClaw 的 Slack 集成中，bot 发出的消息默认被自己忽略——因为所有 Agent 共用一个 bot 身份。

**解法：两步触发**
1. Slack 消息（人看到的可见锚点）
2. `sessions_send`（真正的执行触发）

**踩坑 2：deliveryContext 漂移**
sessions_send 触发后，目标 Agent 有时不在 Slack thread 里回复，而是跑到了 webchat 上下文。排查发现是 sessionKey 的构造方式会影响 deliveryContext。

**解法：可见性契约**
发送前校验 sessionKey，发送后检查 thread latest_reply。没回复就标记 failed-delivery。

**踩坑 3：A2A 循环风暴**
早期没设 maxPingPongTurns，两个 Agent 互相触发导致消息风暴和 token 爆炸。

**解法**：`maxPingPongTurns = 4` + 只允许 CoS/CTO/Ops 发起 A2A。

## Phase 3：信息流和知识沉淀

**核心问题**：Agent 做了很多事，但经验没有积累下来。

**v1 方案：强制 Closeout**
每个 A/P/S 类任务必须产出 10-15 行的结构化总结。包含：做了什么、做了什么决策、踩了什么坑、信号评分。

**效果**：信息压缩比约 25x。一个 50k token 的 session，Closeout 只有 1-2k。

**v2 方案：Signal 评分过滤**
不是所有 Closeout 都值得进入知识库。用 0-3 的 signal 评分过滤：
- 0-1：Agent 自留，不传播
- 2-3：进入 #know，KO 提取

## Phase 4：治理和自演化

**问题**：Agent 可以修改自己的 SOUL.md 和 MEMORY.md，但如果没人审计，行为会慢慢漂移。

**解法**：
- Self-Update Template：每次自我修改都要记录动机、变更、回滚方式
- Ops Review：S 类变更五维审计
- `#ops requireMention = true`：降低 Ops 频道的噪音

## 关键经验总结

### 设计层
- **角色文件拆分很重要**：SOUL（你是谁）和 AGENTS（你怎么做）分开，防止流程细节稀释角色定位
- **SOUL.md 必须放在最前面读**：这是优先级最高的上下文
- **shared 协议要少而精**：太多没人看，太少没约束。9 个文件是当前版本，v2 在探索压缩到 3 个

### 技术层
- **配置层硬约束 > 文档层软约束**：allowAgents、maxPingPongTurns、requireMention 这些是真正起作用的
- **Thread 隔离是核心**：historyScope = "thread" 是整个系统能工作的基础
- **A2A 是最脆弱的环节**：deliveryContext 漂移问题至今没有根治

### 运营层
- **从简单开始**：先跑通 CoS → CTO → Builder 链路，再加 KO/Ops
- **信任但验证**：给 Agent 自主权，但通过 Closeout 和审计保持可见性
- **完美是迭代的敌人**：这个系统不完美，但已经在解决真实问题

---

> 📖 准备开始？→ [完整上手指南](GETTING_STARTED.md) · [核心概念](CONCEPTS.md) · [FAQ](FAQ.md)
