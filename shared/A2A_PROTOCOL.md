# A2A 协作协议 v2（跨平台多 Agent）

> 目标：让 Agent 之间的协作 **自动发生在正确的频道/线程里**，做到：
> - 可见（用户 能在频道里看到）
> - 可追踪（每个任务一个 thread/session）
> - 不串上下文（thread 级隔离 + 任务包完整）
>
> v2 覆盖平台：Slack / Feishu / Discord
> v2 协作模式：**Delegation**（全平台）+ **Discussion**（Slack 多 Bot）[待 POC 验证]

---

## 0. 术语

- **A2A**：Agent-to-Agent 协作流程总称，包含 Delegation 和 Discussion 两种模式。
- **Task Thread**：在目标 Agent 频道里创建的任务线程；该线程即该任务的独立 Session。
- **Delegation（委派）**：由 `sessions_send` 触发的结构化任务委派，全平台可用。
- **Discussion（讨论）**：由 @mention 触发的多 Agent 实时讨论，仅 Slack 多 Bot [待 POC 验证]。
- **Multi-Account（多账户）**：每个 Agent 使用独立 Slack App（独立 bot token / app token / bot user ID）。
- **Orchestrator（编排者）**：控制讨论节奏的角色。默认是 CoS（代表用户推进），也可以是人类。

---

## 1) 权限矩阵（必须遵守）

- CoS → CTO（默认不直达 Builder）；Discussion 模式中 CoS 是编排者
- CTO → Builder / Research / KO / Ops
- Builder → 只接单执行；需要澄清时回到 CTO thread 提问
- CIO → 尽量独立；仅必要时与 CoS/KO 同步
- KO/Ops → 作为审计/沉淀，通常不主动派单

（注：技术上 bot 可以给任意频道发消息，但这是组织纪律，不遵守视为 bug。）

---

## 2a) Delegation Mode（委派模式 — 全平台）

当 A 想让 B 开工时（**不允许人工复制粘贴**）：

> ⚠️ 重要现实：单 Bot 模式下所有 Agent 共用一个 bot 身份。
> **bot 自己发到别的频道的消息，默认不会触发对方 Agent**（OpenClaw 忽略 bot-authored inbound，防自循环）。
> 因此：跨 Agent 触发必须通过 **sessions_send** 完成；频道消息仅作"可见性锚点"。

### Step 1 - 在目标频道创建可见的 root message（锚点）
A 在 B 的频道创建 root message，第一行固定前缀：

```
A2A <FROM>→<TO> | <TITLE> | TID:<YYYYMMDD-HHMM>-<short>
```

正文必须是完整任务包（建议使用 `~/.openclaw/shared/SUBAGENT_PACKET_TEMPLATE.md`）：
- Objective / DoD / Inputs / Constraints / Output format / CC

> 前置条件：bot 必须已加入目标频道，否则报 `not_in_channel`。

### Step 2 - 用 sessions_send 触发目标 Agent
A 读取 root message 的 message id（ts），拼出 thread sessionKey：

| 平台 | Session Key 格式 |
|------|-----------------|
| Slack | `agent:<B>:slack:channel:<channelId>:thread:<root_ts>` |
| Discord | `agent:<B>:discord:channel:<channelId>:thread:<root_ts>` |
| Feishu | `agent:<B>:feishu:group:<chatId>:topic:<root_id>` |

然后 A 用 `sessions_send(sessionKey=..., message=<完整任务包>)` 触发 B。

> ⚠️ **timeout ≠ 失败**。消息可能已送达。规避：在 thread 里补发兜底消息。
> ⚠️ **SessionKey 不要手打**。从 `sessions_list` 复制 `deliveryContext` 匹配的 key。

### Step 3 — 执行与汇报
- B 的执行与产出都留在该 thread。
- 上游在自己的协调 thread 里同步 checkpoint/closeout。

---

## 2.5) 多轮 WAIT 纪律（实战验证）

当 A2A 任务需要多轮迭代时：

- **每轮只聚焦 1-2 个改动点**，完成后**必须 WAIT**。
- **禁止一次性做完所有步骤**——等上游指令后再继续。
- 每轮输出格式：
  ```
  [<角色>] Round N/M
  Done: <做了什么>
  Run: <执行了什么命令>
  Output: <关键输出>
  WAIT: 等待上游指令
  ```
- 最终轮贴 closeout，A2A reply 中回复 `REPLY_SKIP`。

### Round0 审计握手（推荐）
在 Round1 前，先验证审计链路：要求目标 Agent 执行 `pwd` 并贴到 thread。看不到回传就停止。

---

## 2b) Discussion Mode（讨论模式 — Slack 多 Bot）[待 POC 验证]

> Discussion 是 Delegation 的增强，不是替代。适用于需要多方实时讨论的场景。
> 仅 Slack 平台支持。原因见 §7。

### 核心思路：选择性独立化

不需要每个 Agent 都有独立 Slack App。只需让**少数高价值的横向 Agent**（如 CoS、QA）拥有独立 App，然后**把它们拉进现有 Agent 的频道**进行协作：

```
                 独立 Slack App              共享 Slack App (现有)
                 ┌─────────┐               ┌─────────────────┐
                 │ CoS-Bot │               │   Default-Bot   │
                 └────┬────┘               └───┬───┬───┬─────┘
                      │                        │   │   │
  频道：  #hq(home)  #cto  #build         #cto #build #invest ...
          ──────────────────────────────────────────────────────
  Agent：    CoS      ← 进入协作 →          CTO  Builder  CIO ...
```

**CoS-Bot 被拉进 #cto** → 直接在 CTO 的地盘对话 → 像两个人在同一间办公室讨论。

### 技术原理（源码验证）

1. **Self-loop 按 account 隔离**：每个 Slack App 有独立 `botUserId`，OpenClaw 只过滤来自自己的消息（`message.user === ctx.botUserId`），不同 App 之间不互相过滤。
2. **`allowBots: true`**：允许处理其他 bot 的消息。须在目标频道的 channel config 中开启。
3. **Per-account channel config**：同一频道可以给不同 account 设置不同的 `requireMention`。例如 #cto 频道：CTO 的 account → `requireMention: false`（照常响应所有消息）；CoS 的 account → `requireMention: true`（只在被 @mention 时响应）。
4. **Thread participation 隐式 mention**：CoS-Bot 一旦在某个 thread 中发过消息，后续该 thread 的消息会触发 CoS 的隐式 mention，让对话可以持续进行。

### 协作流程

```
用户在 #cto: "@CoS 请协调评审 X 功能的架构方案"

CoS-Bot 收到 @mention → 进入 #cto thread
  → CoS: "好的，我来协调。@CTO 请先提出你的方案。"

CTO (Default-Bot) 收到消息（requireMention: false，在自己频道）
  → CTO: "方案如下：... 建议用方案 A。"

CoS-Bot 收到（thread participation 隐式 mention）
  → CoS: "@CTO 方案 A 的成本如何？另外 @Builder 请评估可行性。"
  （CoS 决定下一个参与者——编排者角色）

Builder (Default-Bot) 在 #cto 收到 @mention → 加载 thread 历史
  → Builder: "方案 A 工期约 2 周，有一个依赖需要先解决。"

CoS-Bot 收到 → 综合意见
  → CoS: "DISCUSSION_CLOSE | 共识：采用方案 A，Builder 先处理依赖。"
  → CoS 用 Delegation (sessions_send) 给 CTO 派正式任务
```

### 关键约束

- **CoS 是编排者**：决定讨论节奏，谁下一个发言。CTO/Builder 是参与者，不主动 @mention 其他 Agent。
- **轮次上限**：CoS 的 AGENTS.md 写明 `maxDiscussionTurns: 5`。到限后必须结束。
- **Thread 隔离**：每个讨论 = 一个 thread。
- **讨论后转 Delegation**：Discussion 的 Action Item 通过 Delegation 执行。

### Discussion 终止协议

讨论结束时，Orchestrator 发送：

```
DISCUSSION_CLOSE
Topic: <讨论主题>
Consensus: <共识 / "未达成共识">
Actions: <后续 Delegation 任务列表，含 TID>
Participants: <参与 Agent 列表>
```

---

## 2c) 平台能力矩阵

| 能力 | Slack | Discord | Feishu |
|------|-------|---------|--------|
| Delegation | YES | YES | YES |
| Discussion | 待 POC 验证 | NO（OpenClaw 代码层阻塞） | NO（飞书平台限制） |
| Multi-Account | YES | YES | YES（注意 #47436） |
| Thread/Topic 隔离 | YES (native) | YES (auto-archive) | YES (groupSessionScope >= 2026.3.1) |

**为什么 Discord 和 Feishu 不能用 Discussion？**

- **Discord**：平台层面支持跨 bot 消息可见，但 OpenClaw 的 bot 消息过滤器（Issue #11199）将所有已配置 bot 视为"自己"并丢弃，导致 Bot-A 的消息被 Bot-B 的 handler 忽略。此外 `requireMention` 在多账户下也失效（Issue #45300）。两个 issue 均已关闭但未修复——属于 OpenClaw 代码层 bug，非平台限制。
- **Feishu**：飞书 `im.message.receive_v1` 事件**仅投递用户发送的消息**，bot 发送的消息对其他 bot 完全不可见。这是飞书平台的 API 设计，无法通过 OpenClaw 配置绕过。

---

## 3) 可见性（用户 必须能看到）

- 任务根消息必须在目标频道可见。
- 关键 checkpoint 至少更新 1 次。
- **上游负责到底**：派单方在自己的频道同步 checkpoint。
- **双通道留痕**：A2A reply（上游可见）+ Thread message（用户可见），两者都要做。
- 完成后必须 closeout：
  1. 在目标 thread 贴 closeout
  2. 上游本机复核（CLI-first）
  3. 回发起方频道汇报（**不做视为未完成**）
  4. 通知 KO 沉淀

---

## 4) 频道映射

- #hq → CoS（home）
- #cto → CTO
- #build → Builder
- #invest → CIO
- #know → KO
- #ops → Ops
- #research → Research

Discussion 模式下，CoS-Bot 进入其他 Agent 的频道（如 #cto、#build）进行协作，无需额外创建共享频道。

---

## 5) Session Key 格式与命名

**一个任务 = 一个 thread = 一个 session。**

| 平台 | Session Key |
|------|------------|
| Slack (thread) | `agent:<B>:slack:channel:<channelId>:thread:<root_ts>` |
| Discord (thread) | `agent:<B>:discord:channel:<channelId>:thread:<root_ts>` |
| Feishu (topic) | `agent:<B>:feishu:group:<chatId>:topic:<root_id>` |

---

## 6) 失败回退

| 模式 | 故障 | 回退 |
|------|------|------|
| Delegation | `sessions_send` timeout | 在 thread 补兜底消息；检查 session key |
| Delegation | Agent 无回复 | Round0 审计握手可提前发现；检查 deliveryContext |
| Discussion | Agent 未响应 @mention | 检查 `allowBots` + `requireMention` 配置；检查 bot 是否在频道 |
| Discussion | 讨论死循环 | Orchestrator 强制 DISCUSSION_CLOSE |
| Discussion | 平台不支持 | 降级为 Delegation（`sessions_send` 串联意见） |

---

## 7) 已知限制与待验证

1. **Slack Discussion [待 POC 验证]**：各组件已通过源码验证（self-loop per-account、allowBots 三级 fallback、per-account channel config），但端到端链路尚无实测记录。
2. **Discord Discussion [NO]**：OpenClaw Issues #11199（bot filter 全局化）+ #45300（requireMention 多账户失效），均已关闭未修复。
3. **Feishu Discussion [NO]**：飞书 `im.message.receive_v1` 仅投递用户消息（平台限制，非 OpenClaw bug）。
4. **Issue #15836**：OpenClaw 关闭了 Slack A2A routing 请求（NOT_PLANNED）。`sessions_send` 仍是官方推荐方式。Discussion 作为增强，非替代。

---

## 附录 A：Discussion Mode 配置指南（Slack）

> 以下配置可由你的 OpenClaw agent 协助完成。人工操作仅需创建 Slack App 和邀请 bot。

### 人工操作（一次性）

1. **创建独立 Slack App**（如 CoS-Bot）：
   - 前往 [api.slack.com/apps](https://api.slack.com/apps) → Create New App
   - 启用 Socket Mode，获取 App Token (`xapp-`)
   - 添加 Bot Token Scopes: `channels:history`, `channels:read`, `chat:write`, `users:read`
   - 添加 Event Subscriptions: `message.channels`, `app_mention`
   - 获取 Bot Token (`xoxb-`)
   - 记录 Bot User ID（Settings → Basic Info → App Credentials，或在 Slack 中查看 bot 的 profile）

2. **邀请 CoS-Bot 到目标频道**：在 #cto、#build 等频道中运行 `/invite @CoS-Bot`

### Agent 可执行的配置（发给你的 OpenClaw）

> 以下是给 OpenClaw agent 的执行提示。将凭证替换为实际值后，发送给你的 agent。

```
请帮我配置 Discussion Mode。

CoS-Bot 凭证（写入配置，不要回显）：
- Bot Token: xoxb-cos-xxx
- App Token: xapp-cos-xxx

请在 openclaw.json 中执行以下增量修改（不要覆盖现有配置）：

1. 在 channels.slack 下添加 accounts 块：
   - 将现有的 botToken/appToken 移入 accounts.default
   - 添加 accounts.cos（使用上面的凭证）

2. 添加 CoS 的 account binding：
   { "agentId": "cos", "match": { "channel": "slack", "accountId": "cos" } }

3. 在需要跨 bot 协作的频道配置中添加 allowBots: true：
   channels.slack.accounts.default.channels.<CTO_CHANNEL_ID>.allowBots = true
   channels.slack.accounts.cos.channels.<CTO_CHANNEL_ID>.requireMention = true
   channels.slack.accounts.cos.channels.<CTO_CHANNEL_ID>.allowBots = true

4. 不要修改现有的 agent bindings、models、auth、gateway 配置。

5. 重启 gateway 并验证 CoS-Bot 在 #cto 中可以被 @mention 触发。
```

### 配置结构参考

```jsonc
{
  "channels": {
    "slack": {
      "accounts": {
        "default": {
          "botToken": "${SLACK_BOT_TOKEN}",
          "appToken": "${SLACK_APP_TOKEN}"
        },
        "cos": {
          "botToken": "${SLACK_BOT_TOKEN_COS}",
          "appToken": "${SLACK_APP_TOKEN_COS}",
          "channels": {
            "<CTO_CHANNEL_ID>": {
              "requireMention": true,  // CoS 在 #cto 只响应 @mention
              "allowBots": true        // CoS 能看到 CTO 的回复
            }
          }
        }
      },
      "channels": {
        "<CTO_CHANNEL_ID>": {
          "allow": true,
          "allowBots": true   // CTO 能看到 CoS-Bot 的消息
        }
      },
      "thread": {
        "historyScope": "thread",
        "initialHistoryLimit": 50
      }
    }
  },
  "bindings": [
    // CoS: account-level binding
    { "agentId": "cos", "match": { "channel": "slack", "accountId": "cos" } },
    // 执行层 agents: peer-level binding（现有，不变）
    { "agentId": "cto", "match": { "channel": "slack", "peer": { "kind": "channel", "id": "<CTO_CHANNEL_ID>" } } }
    // ... builder, cio, ko, ops, research 同理
  ]
}
```

---

## 附录 B：POC 验证步骤

```
测试 1：基础跨 bot 消息传递
  - 在 #cto 中用人类账号 @mention CoS-Bot
  - 验证 CoS 响应
  - 验证 CTO 不会"抢答"（如果 CTO 也回复了，属正常——requireMention: false）

测试 2：CoS 和 CTO 在 thread 中对话
  - CoS 在 #cto thread 中 @mention CTO（或直接发消息，CTO 的 requireMention 为 false）
  - 验证 CTO 回复
  - 验证 CoS 收到 CTO 的回复（thread participation 隐式 mention）
  - 验证 CoS 可以继续对话（第二轮）

测试 3：轮次控制
  - 在 CoS 的 AGENTS.md 中设定 maxDiscussionTurns: 3
  - 发起讨论
  - 验证 CoS 在第 3 轮后发布 DISCUSSION_CLOSE

测试 4：多 Agent 讨论
  - 邀请 CoS-Bot 到 #build
  - 在 #cto thread 中 CoS @mention Builder
  - 验证 Builder 收到并响应
  - 验证 CoS 能综合 CTO + Builder 的意见
```
