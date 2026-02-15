**中文** | [English](en/FAQ.md)

> 📖 [README](../README.md) → [完整上手指南](GETTING_STARTED.md) → [核心概念](CONCEPTS.md) → **FAQ**

# 常见问题

---

## 基础问题

### OpenCrew 是什么？

OpenCrew 是一个基于 OpenClaw 的多智能体协作框架。它把你的 OpenClaw 从"一个 AI 助手"变成"一支 AI 团队"——多个 Agent 各有专业领域，通过 Slack 协作，经验自动沉淀。你作为决策者只需要定方向和验收结果。

### 我需要会写代码吗？

不需要。OpenCrew 由一个经济学/MBA 背景的非技术用户设计和部署。你需要的能力是在终端里复制粘贴命令执行——或者更简单地，把部署指令发给你现有的 OpenClaw 让它帮你做。

### OpenCrew 和 CrewAI / AutoGen / LangGraph 有什么区别？

它们是给开发者用的编排 SDK——你需要写 Python 代码来定义 Agent 和工作流。OpenCrew 是给决策者用的管理系统——你通过 Slack 管理 AI 团队，不写一行代码。

简单说：CrewAI 解决"怎么用代码编排 Agent"，OpenCrew 解决"怎么管理一支 AI 团队"。

### 为什么基于 OpenClaw？

OpenClaw 提供了强大的单 Agent 能力（工具调用、长期记忆、多平台集成）。OpenCrew 在这个基础上解决单 Agent 架构的天花板——上下文膨胀、经验不沉淀、多任务并行困难。

---

## 架构问题

### 最少需要几个 Agent？

3 个：CoS（幕僚长）+ CTO（技术合伙人）+ Builder（执行者）。这是最小可用配置。

推荐后续添加：
- **KO** — 当你发现"踩过的坑又踩了"、经验在流失
- **Ops** — 当你发现 Agent 行为在慢慢变化、不像以前那么靠谱
- **CIO** — 当你需要一个专门的领域专家（投资、法律、营销等）

### 7 个 Agent 会不会太多？

7 个是当前的平衡点。3 个太少（上下文还是会膨胀），10 个太多（Agent 之间的协调成本爆炸：10 个 Agent 有 45 条潜在通道）。建议从 3 个开始，按需添加。

### CoS 是不是所有任务的入口？必须经过它吗？

不是。CoS 不是网关，你想跟谁聊直接进哪个频道。CoS 的价值是"深度意图对齐"和"你不在时代为推进"，不是做信息中转站。

### 为什么用 Slack 而不是 Discord / 飞书 / 微信？

Slack 的产品特性天然匹配多 Agent 协作：Thread 提供任务级隔离、Unreads 变成待办清单、频道映射岗位、手机端体验优秀。OpenClaw 也原生支持 Slack 集成。

其他平台在 roadmap 上，但需要找到等价的"频道+thread"映射方案。

---

## 使用问题

### Token 消耗会很高吗？

会比单 Agent 多，因为每个 Agent 有独立上下文。但两个因素降低实际成本：

1. **领域隔离**：每个 Agent 只看自己领域的信息，单次对话的上下文更短
2. **Closeout 压缩**：经验通过 10-15 行的结构化总结传递（~25x 压缩），而不是让下游 Agent 读完整对话

### Slack 免费版够用吗？

够用。OpenCrew 使用的 Socket Mode API 在免费版完全可用。消息历史的 90 天限制不影响——重要信息已经通过 Closeout 和知识库沉淀了。

### Agent 之间的协作是即时的吗？

取决于 OpenClaw 的响应速度，通常在几秒到几十秒内完成一次 A2A 触发。但长任务可能跨数小时甚至数天——这时 Checkpoint 机制帮你追踪进展。

### 如果 Agent "跑偏了"怎么办？

这正是 Ops 存在的原因。Ops 会审计所有 Agent 的自我修改（Self-Update），发现异常会标记并建议回滚。如果还没部署 Ops，你可以手动检查各 Agent 的 SOUL.md 是否被意外修改。

---

## 部署问题

### 部署大概需要多久？

如果 Slack 已接入 OpenClaw：约 10 分钟。
如果 Slack 还没接入：约 30-40 分钟（主要花在创建 Slack App 和配置 token 上）。

详细步骤见 → [完整上手指南](GETTING_STARTED.md)

### 部署会影响我现有的 OpenClaw 吗？

不会。OpenCrew 采用增量部署——只添加新的 Agent、workspace 和配置项，不修改你现有的配置。部署前会备份 `openclaw.json`，任何时候都可以回滚。

### 我能在远程服务器上部署吗？

可以。只要服务器能运行 OpenClaw 和连接 Slack API（需要出站网络），就能部署。通过 SSH 执行部署命令或让你的 OpenClaw agent 远程操作。

---

## 知识系统问题

### Closeout 和普通的聊天总结有什么区别？

Closeout 是强制的、结构化的。它有固定模板（做了什么、决策、踩坑、Signal 评分），确保关键信息不丢失。普通总结是随意的，容易遗漏关键细节。

### Signal 评分是 Agent 自己打的，靠谱吗？

目前是。但通过 Ops 审计和 KO 的二次过滤，不太靠谱的评分会被纠正。长期来看，Signal 评分的准确性会随着系统使用逐步校准。

### 跨 session 的知识检索能力如何？

这是当前的主要局限。v1 依赖 Closeout + KO 手动提炼，没有跨 session 的语义检索。这个方向在探索中，欢迎贡献。

---

> 📖 [README](../README.md) · [完整上手指南](GETTING_STARTED.md) · [核心概念](CONCEPTS.md) · [架构设计](ARCHITECTURE.md)
