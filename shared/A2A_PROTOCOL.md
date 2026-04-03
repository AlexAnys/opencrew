# A2A 协作协议 v2（跨平台多 Agent）

> 目标：让 Agent 之间的协作 **自动发生在正确的频道/线程里**，做到：
> - 可见（用户 能在频道里看到）
> - 可追踪（每个任务一个 thread/session）
> - 不串上下文（thread 级隔离 + 任务包完整）
>
> v2 覆盖平台：Slack / Feishu / Discord
> v2 协作模式：**Delegation**（全平台）+ **Discussion**（Slack 多 Bot）[已验证]
>
> 配置指南：[Discussion Mode 实操指南](../docs/A2A_SETUP_GUIDE.md)

---

## 0. 术语

- **A2A**：Agent-to-Agent 协作流程总称，包含 Delegation 和 Discussion 两种模式。
- **Task Thread**：在目标 Agent 频道里创建的任务线程；该线程即该任务的独立 Session。
- **Delegation（委派）**：由 `sessions_send` 触发的结构化任务委派，全平台可用。
- **Discussion（讨论）**：由 @mention 触发的多 Agent 实时讨论，仅 Slack 多 Bot [已验证]。
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

## 2b) Discussion Mode（讨论模式 — Slack 多 Bot）[已验证]

> Discussion 是 Delegation 的增强，不是替代。适用于需要多方实时讨论的场景。
> 仅 Slack 平台支持。原因见 §7。
> 完整配置指南见 [A2A_SETUP_GUIDE.md](../docs/A2A_SETUP_GUIDE.md)。

### 核心思路：选择性独立化

不需要每个 Agent 都有独立 Slack App。只需让**少数高价值的横向 Agent**（如 Orchestrator）拥有独立 App，然后**把它们拉进现有 Agent 的频道**进行协作：

```
                 独立 Slack App              共享 Slack App (现有)
                 ┌──────────────┐           ┌─────────────────┐
                 │ Orchestrator │           │   Default-Bot   │
                 └──────┬───────┘           └───┬───┬───┬─────┘
                        │                       │   │   │
  频道：  #hq(home)  #cto  #build          #cto #build #invest ...
          ──────────────────────────────────────────────────────
  Agent：  Orchestrator ← 进入协作 →        CTO  Builder  CIO ...
```

这里的 Orchestrator 融合了 Anthropic Harness Design 中 **Planner + Evaluator** 的职责：
- 展开需求为验收标准（Planner）
- 评估参与者的产出（Evaluator）
- 控制讨论节奏和终止（Orchestrator）

执行层 Agent（CTO/Builder 等）是 **Generator**：执行具体工作，不自评通过。

> **为什么要分离？** 当一个 AI 既做执行又做 QA 时，它倾向于宽容自己的错误；既做规划又做执行时，倾向于投机取巧。将"想"和"做"分给不同 Agent，是解决 AI 自评失效最有效的杠杆。

### 技术原理（源码验证）

1. **Self-loop 按 account 隔离**：每个 Slack App 有独立 `botUserId`，OpenClaw 只过滤来自自己的消息（`message.user === ctx.botUserId`），不同 App 之间不互相过滤。
2. **`allowBots: true`**：允许处理其他 bot 的消息。须在目标频道的 channel config 中开启。
3. **Per-account channel config**：同一频道可以给不同 account 设置不同的 `requireMention`。

### ⚠️ Thread 内的隐式触发问题（实战发现）

`requireMention: true` 只在 **Channel 根消息**（非 thread）有效。一旦 bot 在 thread 中回复过，`implicitMention` 永远为 true，绕过 `requireMention`。

源码证据（`resolveMentionGating`）：

```js
implicitMention = !isDirectMessage && botUserId && message.thread_ts &&
    (message.parent_user_id === botUserId || hasSlackThreadParticipation(...))
```

**影响**：Thread 内所有消息都会触发已参与的 bot，可能导致双响应或循环。

**解决：两层防线**

| 层级 | 机制 | 效果 | 类型 |
|------|------|------|------|
| Config | `requireMention: true` | 防止 Channel 根消息双触发 | 硬约束 |
| Prompt | 显式 @mention 协议（见下文） | 防止 Thread 内双响应和循环 | 软约束 |

### 显式 @mention 协议（Multi-Agent Thread 规则）

每个参与 Discussion Mode 的 Agent 必须在 workspace 文件中包含此规则：

```markdown
## Multi-Agent Thread 协作规则

在 Slack thread 中如果有其他 bot 也在参与：

1. **显式 @mention 检查**：检查消息文本是否包含 `<@你的BotID>`。
   如果没有 → 整条回复只输出 `NO_REPLY`，不解释、不叙述。

2. **发送消息时必须 @mention 目标**：`<@目标BotID>` 显式 mention。
   不 @ 任何 bot = 对话终止信号。

3. **角色分工**：
   - Orchestrator（编排者）：选择 @Worker / @Human / 不@（结束）
   - Worker（执行方）：每次回复必须 @ Orchestrator

4. **终止**：说"完毕/done/结论"后不再发送，除非被重新 @。

5. **轮次上限**：同一 thread 内最多 8 轮，超过后暂停并向人类汇报。
```

### 协作流程（融合 Anthropic Harness Design）

```
用户 → @Orchestrator: "讨论 X 议题"

Phase 0（Orchestrator 展开 spec）:
  → 📁 discussions/<topic>/spec.md（目标 + 验收标准 + 终止条件）
  → Thread: 「DISCUSSION SPEC: 目标...验收标准 N 条。@Worker 请先...」

Round 1/M:
  Orchestrator → @Worker: 具体问题
  Worker → @Orchestrator: 摘要 + 📁 round-1.md（详细分析）

Round 2/M:
  Orchestrator 评估 → 📁 review-1.md → @Worker 反馈
  ...

终止（三选一）:
  ✅ 所有验收标准满足 → DISCUSSION_CLOSE
  ⚠️ 达到最大轮次 → WARNING，请人类介入
  🔄 连续 2 轮无进展 → 请人类介入
```

**关键原则**（源自 Anthropic Harness Design）：
1. **先 spec 再讨论**——Phase 0 定义验收标准，不能跳过
2. **文件是主通信通道**——Thread 只放摘要和 @mention 路由，详细内容写文件
3. **自评失效，必须分离**——Orchestrator 不生成方案，只协调和评估
4. **Orchestrator 默认太宽松**——需刻意严格，逐条对照标准判断
5. **正式任务走 `sessions_send`**——Discussion 的 Action Item 通过 Delegation 执行

### Discussion 终止协议

讨论结束时，Orchestrator 发送：

```
DISCUSSION_CLOSE
Topic: <讨论主题>
Consensus: <共识 / "未达成共识，原因：...">
Criteria Status:
  1. ✅/❌ <标准 1>: <状态>
  2. ✅/❌ <标准 2>: <状态>
Actions: <后续 Delegation 任务列表，含负责人>
Participants: <参与 Agent>
Rounds Used: N/M
```

---

## 2c) 平台能力矩阵

| 能力 | Slack | Discord | Feishu |
|------|-------|---------|--------|
| Delegation | YES | YES | YES |
| Discussion | ✅ 已验证 | NO（OpenClaw 代码层阻塞） | NO（飞书平台限制） |
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

## 7) 已知限制

1. **Slack Discussion [已验证]**：端到端链路已通过实测验证（2026-04-02）。两个 bot 可在同一频道互相看到消息并进行结构化讨论。但 Thread 内的隐式触发需要 Prompt 规则配合（见 §2b）。
2. **Discord Discussion [NO]**：OpenClaw Issues #11199（bot filter 全局化）+ #45300（requireMention 多账户失效），均已关闭未修复。
3. **Feishu Discussion [NO]**：飞书 `im.message.receive_v1` 仅投递用户消息（平台限制，非 OpenClaw bug）。
4. **Issue #15836**：OpenClaw 关闭了 Slack A2A routing 请求（NOT_PLANNED）。`sessions_send` 仍是官方推荐方式。Discussion 作为增强，非替代。
5. **`allowBots: "mentions"` 仅 Discord 可用**：Slack provider 只做 truthy/falsy 检查，`"mentions"` 等同于 `true`。需要 OpenClaw 代码改动才能在 Slack 支持。
6. **`requireMention: true` 在 Thread 内被绕过**：`implicitMention`（thread participation）会永久绕过 `requireMention`。需要 OpenClaw 增加 `thread.requireExplicitMention` 选项才能从系统层解决。
7. **Input token 无法避免**：Thread 中所有消息都会送达所有 bot，Prompt 规则只让 agent 回复 NO_REPLY，但 input token 消耗不可避免。
8. **多账号 `accounts.default` 必须显式声明**：详见附录 A 的警告。实战中因遗漏导致过 ~13h 全 Agent 断连。
9. **模型兼容性**：Discussion 模式的协作纪律（显式 @mention 检查、NO_REPLY、轮次计数、终止判断）完全依赖 Agent 对 Prompt 规则的遵循能力，并非 OpenClaw 配置层强制。使用 Claude Opus 4.6 实测从未出现失控循环，但不同模型的 instruction following 能力有差异。建议首次使用时在低风险频道测试，留意 Agent 是否出现重复对话或忽略 NO_REPLY 的情况。

---

## 附录 A：Discussion Mode 配置指南（Slack）

> 详细实操指南见 [A2A_SETUP_GUIDE.md](../docs/A2A_SETUP_GUIDE.md)，包含完整 manifest、陷阱清单和回滚方式。
> 以下是精简版。

### 人工操作（一次性）

1. **创建独立 Slack App**：前往 [api.slack.com/apps](https://api.slack.com/apps) → Create New App → **From manifest**
   - 使用 [A2A_SETUP_GUIDE.md](../docs/A2A_SETUP_GUIDE.md) 中的完整 manifest（含所有必要 scope 和 event）
   - 创建后：Basic Information → App-Level Tokens → Generate（scope: `connections:write`）→ 拿到 `xapp-`
   - Install to Workspace → 拿到 `xoxb-`

2. **邀请 Bot 到目标频道**：`/invite @Bot-Name`

### Agent 可执行的配置

> ⚠️ **硬性要求：必须同时声明 `accounts.default`**
>
> OpenClaw 的 `account-helpers.ts:listAccountIds()` 逻辑：一旦 `accounts` 对象存在且有任何 key，
> 只启动显式声明的账号。漏掉 `accounts.default` = 主 bot 断连，所有现有 Agent 失联。
>
> 这是设计如此，不是 bug。实战中因此导致过约 13 小时的全 Agent 断连事故。

将以下配置提示发给你的 OpenClaw agent（替换凭证）：

```
请帮我配置 Discussion Mode。

Bot 凭证（写入配置，不要回显）：
- Bot Token: xoxb-xxx
- App Token: xapp-xxx

请在 openclaw.json 中执行以下增量修改：

1. 在 channels.slack.accounts 下：
   ★ 必须同时声明 accounts.default（用现有顶层 token）
   - accounts.default = { botToken: 现有, appToken: 现有 }
   - accounts.<new-bot> = { botToken: 新的, appToken: 新的, channels: {...} }

2. 在目标频道开启双向 allowBots:
   - 全局 channel config: allowBots: true（让原有 Agent 看到新 bot）
   - 新 account channel config: allowBots: true, requireMention: true

3. 添加 binding（accountId + peer，放在现有 peer binding 之前）

4. 等待热重载，不要立即 SIGTERM

5. 验证日志：两个 provider 都 starting + channels resolved 无 missing_scope
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
