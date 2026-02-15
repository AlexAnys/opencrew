> 📖 [README](../README.md) → [核心概念](CONCEPTS.md) → [架构设计](ARCHITECTURE.md) → **已知问题**

# 已知问题与当前最佳实践

> 目的：诚实交代"系统的真实边界"，并给出 **不改源码** 的稳定工作方式。

---

## P0：Slack 频道内 root message 默认共享一个 session（上下文可能互相污染）

### 现象
在 OpenClaw 的 Slack 路由中，**频道会话键**默认是：

- `agent:<agentId>:slack:channel:<channelId>`

这意味着：同一个频道里多条**不相关的 root message**，可能共享同一个频道级 session 上下文。

### 已有配置能做到什么？
- `replyToMode: "all"` 可以确保回复进 thread
- `channels.slack.thread.historyScope = "thread"` + `inheritParent=false` 可以确保 thread 内历史隔离

但它们**无法把“每条新的 root message”自动变成一个新 session**。

### 当前稳定做法（不改源码，推荐）
- **把“任务”定义为 thread**：每个任务都在一个 thread 里推进
- 在频道里只发“很短的 root message”当作锚点（标题/任务一句话），立刻在 thread 里继续对话
- 同一频道并行多个任务：开多个 thread

### 高级（不推荐新手）：dist-level patch
本 repo 的 `patches/slack-thread-routing.sh` 仅提供思路和回滚骨架，并不保证对所有版本有效。
原因：OpenClaw 的 dist 打包结构会随版本变化，可靠的 patch 需要版本检测 + 精确定位代码。

结论：**开源版默认不依赖 patch**。如果你能提供稳定可复现的实现方式，欢迎 PR。

---

## P1：A2A 可见性断裂（派单后 Slack thread 没有回复）

### 现象
`sessions_send` 触发后，目标 Agent 偶尔不在预期的 Slack thread 内回复，导致用户看到“派了任务但没人做”。

### 当前机制：A2A 可见性契约（文档级兜底）
OpenCrew 采用“两步触发”：
1) 在目标频道创建 Slack root message（可见锚点）
2) 用 `sessions_send` 触发目标 agent，在该 thread 的 sessionKey 内执行

并要求发起方在发送后检查 thread 是否出现回复，失败则标记 `failed-delivery` 并上报。

> 这是“契约兜底”，不是根治；根治需要上游在 Slack deliveryContext 方面更强的确定性。

---

## P1：长任务上下文压力（context overflow）

### 现象
长时间 thread + 大量 tool outputs 可能导致上下文爆满。

### 当前最佳实践
- >20 turns 或跨天：写 Checkpoint
- 每个 A/P/S 任务必须 Closeout（10–15 行）
- 用 spawn 做并行子任务（隔离上下文）

---

## P2：知识系统“跨 session 语义检索”仍在探索

当前 v1 依赖 Closeout + KO 提炼；跨 session 的语义检索/索引属于探索方向（欢迎贡献）。

---

> 📖 相关文档 → [FAQ](FAQ.md) · [核心概念](CONCEPTS.md) · [架构设计](ARCHITECTURE.md)
