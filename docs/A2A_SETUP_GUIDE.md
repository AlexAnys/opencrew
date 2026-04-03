# Discussion Mode 实操指南 — 独立 Bot 引入 + 协作机制

> 供审计用。基于 2026-03-30 ~ 2026-04-02 实战测试。
> PR: https://github.com/AlexAnys/opencrew/pull/38

---

## 第一部分：如何引入独立 Bot

### 背景

OpenCrew 默认所有 Agent 共享一个 Slack App（一个 bot user）。这意味着 Bot A 发到 Bot B 频道的消息会被 self-reply filter 忽略（同一个 bot user）。

**Discussion Mode** 的前提是"选择性独立化"：让少数高价值 Agent（如 Orchestrator）拥有独立 Slack App，然后拉进其他 Agent 的频道直接对话。

### Step 1：创建独立 Slack App

在 [api.slack.com/apps](https://api.slack.com/apps) → Create New App → **From manifest**：

```json
{
    "display_information": {
        "name": "Ali-Bot",
        "description": "OpenClaw Discussion Mode agent"
    },
    "features": {
        "bot_user": {
            "display_name": "Ali-Bot",
            "always_online": true
        },
        "app_home": {
            "messages_tab_enabled": true,
            "messages_tab_read_only_enabled": false
        }
    },
    "oauth_config": {
        "scopes": {
            "bot": [
                "chat:write",
                "im:write",
                "channels:history",
                "groups:history",
                "groups:read",
                "im:history",
                "im:read",
                "mpim:history",
                "mpim:read",
                "channels:read",
                "users:read",
                "app_mentions:read",
                "assistant:write",
                "reactions:read",
                "reactions:write",
                "pins:read",
                "pins:write",
                "emoji:read",
                "files:read",
                "files:write"
            ]
        }
    },
    "settings": {
        "event_subscriptions": {
            "bot_events": [
                "app_mention",
                "message.channels",
                "message.groups",
                "message.im",
                "message.mpim",
                "reaction_added",
                "reaction_removed",
                "member_joined_channel",
                "member_left_channel",
                "channel_rename",
                "pin_added",
                "pin_removed"
            ]
        },
        "socket_mode_enabled": true,
        "org_deploy_enabled": false,
        "is_hosted": false,
        "token_rotation_enabled": false
    }
}
```

创建后：
1. Basic Information → App-Level Tokens → Generate Token（scope: `connections:write`）→ 拿到 `xapp-...`
2. Install to Workspace → 拿到 `xoxb-...`
3. 记录 Bot User ID（Settings → Basic Info 或在 Slack 中查看 bot profile）

### Step 2：配置 OpenClaw 多账号

> ⚠️ **硬性要求：必须同时声明 `accounts.default`**
>
> `account-helpers.ts:listAccountIds()` 的逻辑：一旦 `accounts` 对象存在且有任何 key，OpenClaw **只启动显式声明的账号**，不再隐式创建 default。
>
> 如果只添加 `accounts.ali-bot` 而不添加 `accounts.default`，主 bot 的 provider 不会启动，所有现有 Agent 的 Slack 连接将断开。
>
> 这不是 bug，是设计如此。

**正确配置**（增量修改 `openclaw.json`）：

```jsonc
{
  "channels": {
    "slack": {
      // 顶层 token 保留为 fallback
      "botToken": "xoxb-main-...",
      "appToken": "xapp-main-...",

      // ★ 关键：显式声明 accounts.default
      "accounts": {
        "default": {
          "botToken": "xoxb-main-...",   // 与顶层相同
          "appToken": "xapp-main-..."    // 与顶层相同
        },
        "ali-bot": {
          "botToken": "xoxb-ali-...",
          "appToken": "xapp-ali-...",
          "channels": {
            "<TARGET_CHANNEL_ID>": {
              "allow": true,
              "requireMention": true,    // 只响应显式 @mention
              "allowBots": true          // 能看到其他 bot 的消息
            }
          }
        }
      },

      // 目标频道开启 allowBots（让原有 Agent 看到 Ali-Bot 的消息）
      "channels": {
        "<TARGET_CHANNEL_ID>": {
          "allow": true,
          "requireMention": true,        // 建议改为 true（见第二部分）
          "allowBots": true
        }
      }
    }
  },

  // Ali-Bot 的路由绑定
  "bindings": [
    // ★ 放在目标频道的 peer binding 之前（更具体的匹配优先）
    {
      "agentId": "main",
      "match": {
        "channel": "slack",
        "accountId": "ali-bot",
        "peer": { "kind": "channel", "id": "<TARGET_CHANNEL_ID>" }
      }
    },
    // 现有 binding 不变
    {
      "agentId": "ops",
      "match": {
        "channel": "slack",
        "peer": { "kind": "channel", "id": "<TARGET_CHANNEL_ID>" }
      }
    }
  ]
}
```

### Step 3：邀请 Bot 并验证

1. 在目标频道执行 `/invite @Ali-Bot`
2. 写入 config 后**等待热重载**（不要立即 SIGTERM，热重载会自动检测变更）
3. 检查 gateway 日志确认两个 provider 都启动：

```
[slack] [default] starting provider     ✅
[slack] [ali-bot] starting provider     ✅
channels resolved: ...（无 missing_scope）  ✅
socket mode connected                    ✅（出现两次）
```

### 回滚

```bash
cp ~/.openclaw/openclaw.json.bak-before-xxx ~/.openclaw/openclaw.json
# 等待热重载，或：
launchctl kill SIGTERM gui/501/ai.openclaw.gateway
```

### 已知陷阱

| 陷阱 | 后果 | 防范 |
|------|------|------|
| 只加 `accounts.ali-bot` 不加 `accounts.default` | 主 bot 断连，所有 Agent 失联 | 必须同时声明 default |
| config 写入后立即 SIGTERM | 热重载的 in-memory 修复被杀掉 | 等热重载完成再验证 |
| Ali-Bot Slack App 缺 scope | `channels resolved` 报 `missing_scope` | 用完整 manifest 创建 |
| Binding 顺序错误 | ali-bot 的消息路由到错误的 agent | accountId+peer binding 放在 peer-only binding 之前 |

---

## 第二部分：引入后的协作机制

### 核心挑战

两个 bot 在同一 Slack thread 中，会遇到三个问题：
1. **双响应**：人类发一条消息，两个 bot 都回复
2. **循环**：Bot A 回复 → Bot B 被触发也回复 → Bot A 又被触发 → ∞
3. **无路由**：没有机制决定"谁该回复、谁该沉默"

### 为什么 Config 不够（源码验证）

| Config 选项 | 预期 | 实际 |
|---|---|---|
| `requireMention: true` | Thread 内只响应显式 @mention | ❌ 一旦 bot 在 thread 中回复过，`implicitMention` 永远为 true，绕过 requireMention |
| `allowBots: "mentions"` | 只处理显式 @mention 自己的 bot 消息 | ❌ Slack provider 只做 truthy/falsy 检查，`"mentions"` 等同于 `true`（仅 Discord 有效） |

**源码证据**（`resolveMentionGating`）：

```js
implicitMention = !isDirectMessage && botUserId && message.thread_ts && 
    (message.parent_user_id === botUserId || hasSlackThreadParticipation(...))
// → 一旦 bot 参与过 thread，implicitMention 永远 true
// → requireMention: true 被永久绕过
```

### 解决方案：两层防线

#### 第 1 层：Config — `requireMention: true`（Channel 级生效）

```jsonc
"<CHANNEL_ID>": {
  "allow": true,
  "requireMention": true,   // 对 channel 根消息有效
  "allowBots": true
}
```

**效果**：Channel 根消息必须显式 @ 才触发 → 只有被 @ 的 bot 进入 thread。
**局限**：Thread 内无效（implicitMention 绕过）。

#### 第 2 层：Prompt 规则 — 显式 @mention 协议（Thread 级生效）

在每个参与 Discussion Mode 的 Agent 的 workspace 文件中加入：

```markdown
## Multi-Agent Thread 协作规则

在 Slack thread 中如果有其他 bot 也在参与：

1. **显式 @mention 检查**：检查消息文本是否包含 `<@你的BotID>`。
   如果没有 → 整条回复只输出 `NO_REPLY`，不解释、不叙述、不加任何其他文字。

2. **发送消息时必须 @mention 目标**：`<@目标BotID>` 显式 mention 目标 bot。
   不 @ 任何 bot = 对话终止信号。

3. **角色分工**：
   - Coordinator（发起方）：选择 @Worker / @Human / 不@（结束）
   - Worker（执行方）：每次回复必须 @ Coordinator

4. **终止**：说"完毕/done/结论"后不再发送，除非被重新 @。

5. **轮次上限**：同一 thread 内最多 8 轮回复，超过后暂停并向人类汇报。

Bot ID 速查：
- Ali-Bot: U0AP8JFFD7Z
- Default Bot (Ops/CTO/Builder 等): U0AD60Q0EKU
```

### 协作流程（文件 + 频道）

借鉴 Anthropic Harness Design 的**双角色架构**：

```
Alex → @Orchestrator: "调查 XXX"

Orchestrator 输出 DISCUSSION SPEC（Phase 0）：
  → 📁 discussions/<topic>/spec.md（目标 + 验收标准 + 终止条件）
  → Thread 消息：「展开了 spec，N 条验收标准。@Worker 请先...」

Round 1:
  Orchestrator → @Worker: 具体问题
  Worker → @Orchestrator: 回复 + 📁 round-1.md（详细分析）
  Thread 消息只放摘要

Round 2:
  Orchestrator 评估 → 📁 review-1.md → @Worker 反馈
  ...

终止（三选一）：
  ✅ 达成共识 → DISCUSSION_CLOSE
  ⚠️ 达到最大轮次 → 请人类介入
  🔄 连续 2 轮无进展 → 请人类介入
```

**关键原则**：
1. **文件是主通信通道**——Slack thread 只放摘要和 @mention 路由，详细分析/方案写文件
2. **先 spec 再讨论**——Orchestrator 第一条消息必须定义验收标准和终止条件
3. **自评失效，必须分离**——Orchestrator 不生成方案，只协调和评估
4. **正式 A2A 任务走 `sessions_send`**——有硬性 `maxPingPongTurns` (0-5)，Slack thread 仅做留痕

### 终止机制

| 层级 | 机制 | 类型 |
|------|------|------|
| Prompt | @mention 协议 + Round N/M 计数 + DISCUSSION_CLOSE | 软约束（指令遵从） |
| Config | `requireMention: true`（Channel 根消息） | 硬约束（系统级） |
| Config | `loopDetection.pingPong: true` | 硬约束（tool-call 级别） |
| A2A | `maxPingPongTurns` (sessions_send) | 硬约束（系统级） |

### 已知局限

1. **Input token 仍消耗**——消息被送达所有 bot，只是 agent 选择 NO_REPLY；无法从 config 阻止送达
2. **Prompt 是软约束**——LLM 可能偶尔违反（特别在复杂上下文中）
3. **`allowBots: "mentions"` 仅 Discord 可用**——Slack 需要 OpenClaw 代码改动
4. **`requireMention: true` 在 thread 内被绕过**——需要 OpenClaw 增加 `thread.requireExplicitMention` 才能系统级解决

---

## 平台能力对比

| 能力 | Slack | Discord | Feishu |
|------|-------|---------|--------|
| Delegation (sessions_send) | ✅ | ✅ | ✅ |
| Discussion (跨 bot 对话) | ✅ 已验证 | ❌ (OpenClaw bug) | ❌ (平台限制) |
| `allowBots: "mentions"` | ❌ (不支持) | ✅ | N/A |
| `requireMention` 在 thread | ❌ (implicitMention 绕过) | ❌ (同理) | N/A |
| Multi-Account | ✅ | ✅ | ✅ |
| 硬性轮次控制 | 仅 sessions_send | 仅 sessions_send | 仅 sessions_send |
