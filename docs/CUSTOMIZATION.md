**中文** | [English](en/CUSTOMIZATION.md)

> 📖 [README](../README.md) → [完整上手指南](GETTING_STARTED.md) → [核心概念](CONCEPTS.md) → [架构设计](ARCHITECTURE.md) → **自定义指南**

# 自定义指南 — 增删改 Agent

## 添加一个新的领域 Agent

以 CIO（投资官）为例，说明如何添加任何领域的专家 Agent。

### Step 1：创建 workspace 目录

```bash
mkdir -p ~/.openclaw/workspace-<your-agent-id>
```

### Step 2：创建 profile 文件

最少需要 3 个文件：

**IDENTITY.md**
```markdown
# <Agent Name>
Emoji: <选一个>
One-liner: <一句话说清这个角色做什么>
```

**SOUL.md**（最重要）
```markdown
# <Agent Name> — Role Directives

## Role
<这个 Agent 负责什么领域>

## Core Principles
- <原则 1>
- <原则 2>

## Autonomy
- ✅ <可以自主做的事>
- ❌ <必须确认的事（L3）>

## Spawn Capability
- Research (如果需要调研能力)
```

**AGENTS.md**
```markdown
# <Agent Name> — Workflow

## Session Startup
1. Read SOUL.md
2. Read USER.md
3. Read MEMORY.md

## Task Processing
<描述这个 Agent 收到任务后的处理流程>

## Closeout
使用标准 CLOSEOUT_TEMPLATE。
```

### Step 3：修改 openclaw.json

在 `agents.list` 添加：
```json
{
  "id": "<your-agent-id>",
  "name": "<Agent Display Name>",
  "workspace": "~/.openclaw/workspace-<your-agent-id>",
  "allowAgents": ["<your-agent-id>", "research", "ko"]
}
```

在 `bindings` 添加：
```json
{
  "agentId": "<your-agent-id>",
  "match": { "channel": "slack", "peer": { "kind": "channel", "id": "<YOUR_CHANNEL_ID>" } }
}
```

在 `channels.slack.channels` 添加：
```json
"<YOUR_CHANNEL_ID>": { "allow": true, "requireMention": false }
```

### Step 4：重启 OpenClaw

```bash
openclaw gateway restart
```

---

## 删除一个 Agent

### Step 1：从 openclaw.json 删除

- 从 `agents.list` 删除该 Agent 条目
- 从 `bindings` 删除对应绑定
- 从 `channels.slack.channels` 删除对应频道
- 从其他 Agent 的 `allowAgents` 中删除（如果有引用）

### Step 2：重启 OpenClaw

workspace 目录可以保留（不影响系统），也可以删除。

---

## 修改 Agent 行为

### 改角色定位
编辑 `workspace-<agent>/SOUL.md` — 这是优先级最高的文件。

### 改工作流程
编辑 `workspace-<agent>/AGENTS.md` — 任务处理逻辑在这里。

### 改长期记忆
编辑 `workspace-<agent>/MEMORY.md` — 稳定的偏好和原则。

### 改用户画像
编辑 `workspace-<agent>/USER.md` — Agent 对你的理解。

> 提示：你也可以让你的 OpenClaw agent 帮你修改这些文件。直接告诉它你想改什么，它会编辑对应文件。

---

## 最小可用配置

如果 7 个 Agent 太多，最小可用版本是 **3 个**：

| Agent | 必要性 |
|-------|--------|
| CoS | 推荐 — 深度意图对齐 + 代为推进（不必经，可直接跟 CTO 对话）|
| CTO | 必须 — 技术方向和任务拆解 |
| Builder | 必须 — 实际执行 |
| KO | 推荐 — 没有知识沉淀，经验不积累 |
| Ops | 推荐 — 没有治理，系统会漂移 |
| Research | 可选 — 可以用 Spawn 替代 |
| CIO | 可选 — 按需添加领域 Agent |

---

## 替换 CIO 为其他领域的示例

### 法律顾问
```markdown
# Legal — Role Directives
## Role
法律风险评估、合同审查、合规建议。
## Autonomy
- ✅ 法律研究、风险分析、合同标注
- ❌ 签署任何法律文件、发送法律函件
```

### 市场负责人
```markdown
# Marketing — Role Directives
## Role
市场分析、内容策略、竞品研究。
## Autonomy
- ✅ 市场调研、内容草稿、数据分析
- ❌ 发布内容到公开渠道、投放广告
```

### 产品经理
```markdown
# PM — Role Directives
## Role
需求分析、产品规划、用户故事编写。
## Autonomy
- ✅ 需求文档、优先级排序、原型描述
- ❌ 发布产品路线图到外部
```

关键模式是一样的：**L1/L2 自主推进，L3（不可逆/对外）必须确认**。

---

> 📖 相关文档 → [核心概念](CONCEPTS.md) · [架构设计](ARCHITECTURE.md) · [配置参考](CONFIG_SNIPPET_2026.2.9.md)
