# Discussion Mode 配置指南

> 基于 2026-03-30 ~ 2026-04-02 实战测试，覆盖配置流程 + 协作机制 + 已知陷阱。
> PR: https://github.com/AlexAnys/opencrew/pull/38

本指南分三部分：
- **Part 1**：Agent 配置指引（通用、参数化，供任何 OpenClaw agent 执行）
- **Part 2**：人工操作（创建 Slack App，一次性）
- **Part 3**：引入后的协作机制

---

## Part 1：Agent 配置指引（To Agent）

> 以下是 OpenClaw agent 在帮用户配置 Discussion Mode 时应遵循的完整流程。
> 所有标识都是参数化的——根据用户的实际 config 动态填充。

### 前置条件（用户需提前完成）

用户必须提供：
- 新 Slack App 的 Bot Token (`xoxb-...`) 和 App Token (`xapp-...`)
- 新 Bot 要关联的 agent ID（如 `orchestrator`、`cos`、`ali` 等）
- 新 Bot 要进入的目标频道（一个或多个）
- 用户已在 Slack 中 `/invite @新Bot` 到目标频道

### Step 0：读取当前配置（必须先做）

在修改任何配置之前，读取 `openclaw.json` 并记录：

```
需要确认的信息：
1. channels.slack.botToken 和 appToken 是否存在？（主 bot 凭证）
2. channels.slack.accounts 是否已存在？
   - 如果存在：有哪些 key？是否已有 accounts.default？
   - 如果不存在：当前是单账号模式
3. channels.slack.channels 中有哪些频道及其当前配置？
4. bindings 中有哪些现有绑定？
```

### Step 1：备份

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak-before-<描述>-<YYYYMMDD>
```

### Step 2：accounts.default 守卫（硬性规则）

> ⛔ **这是不可跳过的守卫。违反将导致所有现有 Agent 断连。**
>
> OpenClaw 的 `listAccountIds()` 逻辑：一旦 `accounts` 对象存在且有任何 key，
> **只启动显式声明的账号**，不再隐式创建 default provider。
>
> 实战教训：遗漏 accounts.default 导致过约 13 小时全 Agent 断连。

**判断逻辑**：

```
IF channels.slack.accounts 不存在（单账号模式）:
    → 创建 accounts 对象时，必须同时包含 accounts.default
    → accounts.default.botToken = 当前 channels.slack.botToken
    → accounts.default.appToken = 当前 channels.slack.appToken

IF channels.slack.accounts 已存在:
    IF accounts.default 已存在:
        → ✅ 安全，继续
    ELSE:
        → ⛔ 停止！先补 accounts.default 再继续
```

### Step 3：添加新账号

在 `channels.slack.accounts` 下添加新 account：

```jsonc
"accounts": {
    "default": { ... },  // ← Step 2 确保它存在
    "<ACCOUNT_ID>": {     // ← 用户指定的账号标识（如 "orchestrator"）
        "botToken": "<用户提供的 xoxb-...>",
        "appToken": "<用户提供的 xapp-...>",
        "channels": {
            // 对每个目标频道：
            "<CHANNEL_ID_1>": {
                "allow": true,
                "requireMention": true,  // 新 bot 只响应显式 @mention
                "allowBots": true        // 新 bot 能看到其他 bot 的消息
            },
            "<CHANNEL_ID_2>": {
                "allow": true,
                "requireMention": true,
                "allowBots": true
            }
            // ... 用户指定的所有频道
        }
    }
}
```

### Step 4：修改目标频道的全局配置

对每个新 bot 要进入的频道，在 `channels.slack.channels` 中添加 `allowBots: true`：

```jsonc
"channels": {
    "<CHANNEL_ID_1>": {
        "allow": true,       // 保留原值
        // ... 保留其他现有配置
        "allowBots": true    // ← 新增：让该频道的原有 agent 能看到新 bot 的消息
    }
}
```

**注意**：不要覆盖频道的其他现有配置（`requireMention`、`users`、`systemPrompt` 等）。只增量添加 `allowBots`。

### Step 5：添加路由 Binding

为新 account 的每个目标频道添加 binding。

**Binding 类型选择**：

```
如果新 bot 在所有频道都路由到同一个 agent：
    → 用一条 account-level binding（不含 peer）
    { "agentId": "<AGENT_ID>", "match": { "channel": "slack", "accountId": "<ACCOUNT_ID>" } }

如果新 bot 在不同频道路由到不同 agent：
    → 每个频道一条 accountId+peer binding
    { "agentId": "<AGENT_ID>", "match": { "channel": "slack", "accountId": "<ACCOUNT_ID>", "peer": { "kind": "channel", "id": "<CHANNEL_ID>" } } }
```

**Binding 顺序**：新 binding 插入到 `bindings` 数组的**现有同频道 binding 之前**（更具体的匹配优先）。

### Step 6：写入配置并等待热重载

```bash
# 写入 openclaw.json（确保 JSON 有效）
# 不要 SIGTERM，等待热重载自动生效
```

### Step 7：验证

检查 gateway 日志（`~/.openclaw/logs/gateway.log`），确认以下条件**全部满足**：

```
✅ [slack] [default] starting provider        — 主 bot 仍在运行
✅ [slack] [<ACCOUNT_ID>] starting provider   — 新 bot 已启动
✅ channels resolved: ...（无 missing_scope） — 所有频道权限正常
✅ socket mode connected（出现 N 次，N = 账号数）— 连接成功
```

**如果验证失败**：

```
如果只有 default provider 启动，新 account 没有：
    → 检查新 account 的 token 是否正确
    → 检查新 Slack App 是否启用了 Socket Mode

如果 default provider 没有启动：
    → ⛔ accounts.default 缺失！立即回滚：
    cp ~/.openclaw/openclaw.json.bak-before-... ~/.openclaw/openclaw.json

如果出现 missing_scope：
    → 用户需要在 Slack App 中补充对应的 scope 并 Reinstall
```

### 配置模板（完整参考）

```jsonc
// openclaw.json — Discussion Mode 增量配置
{
    "channels": {
        "slack": {
            // 顶层 token 保留（作为 fallback）
            "botToken": "xoxb-main-...",
            "appToken": "xapp-main-...",

            "accounts": {
                // ★ 必须存在
                "default": {
                    "botToken": "xoxb-main-...",
                    "appToken": "xapp-main-..."
                },
                // ★ 新增账号
                "<ACCOUNT_ID>": {
                    "botToken": "xoxb-new-...",
                    "appToken": "xapp-new-...",
                    "channels": {
                        "<CHANNEL_ID>": {
                            "allow": true,
                            "requireMention": true,
                            "allowBots": true
                        }
                    }
                }
            },

            "channels": {
                "<CHANNEL_ID>": {
                    "allow": true,
                    "allowBots": true
                }
            }
        }
    },

    "bindings": [
        // 新 account binding（放在前面）
        {
            "agentId": "<AGENT_ID>",
            "match": {
                "channel": "slack",
                "accountId": "<ACCOUNT_ID>"
            }
        },
        // 现有 bindings（不变）
        // ...
    ]
}
```

### 回滚

```bash
# 方法 1：恢复备份（推荐）
cp ~/.openclaw/openclaw.json.bak-before-... ~/.openclaw/openclaw.json
# 等热重载或：
launchctl kill SIGTERM gui/501/ai.openclaw.gateway

# 方法 2：手动回退
# 删除 accounts.<ACCOUNT_ID>
# 如果 accounts 下只剩 default，可以删除整个 accounts 对象恢复单账号模式
# 移除对应 bindings
# 移除频道的 allowBots（如果之前没有）
```

---

## Part 2：人工操作（创建 Slack App）

用户需在 [api.slack.com/apps](https://api.slack.com/apps) 创建独立 Slack App。

### 推荐 Manifest

Create New App → **From manifest** → 粘贴以下内容（修改 `name` 和 `description`）：

```json
{
    "display_information": {
        "name": "<你的 Bot 名称>",
        "description": "OpenClaw Discussion Mode agent"
    },
    "features": {
        "bot_user": {
            "display_name": "<你的 Bot 名称>",
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
                "channels:history",
                "channels:read",
                "groups:history",
                "groups:read",
                "users:read",
                "app_mentions:read",
                "reactions:read",
                "reactions:write",
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
                "message.mpim"
            ]
        },
        "socket_mode_enabled": true,
        "org_deploy_enabled": false,
        "is_hosted": false,
        "token_rotation_enabled": false
    }
}
```

> **最小 scope 说明**：上面是 Discussion Mode 所需的最小 scope。如果需要 DM、reactions、pins 等额外功能，参考 `docs/SLACK_SETUP.md` 的完整列表补充。

创建后：
1. **App-Level Token**：Basic Information → App-Level Tokens → Generate Token（scope: `connections:write`）→ 拿到 `xapp-...`
2. **Bot Token**：Install to Workspace → 拿到 `xoxb-...`
3. **Bot User ID**（必须）：Slack App 页面 → Basic Information 或 bot 的 Slack profile 查看（格式：`U0xxxxxxx`）。@mention 协作协议要求每个 Agent 知道自己和对方的 Bot User ID

---

## Part 3：引入后的协作机制

### 核心挑战

两个 bot 在同一 Slack thread 中，会遇到三个问题：
1. **双响应**：人类发一条消息，两个 bot 都回复
2. **循环**：Bot A 回复 → Bot B 被触发也回复 → Bot A 又被触发 → ∞
3. **无路由**：没有机制决定"谁该回复、谁该沉默"

### 为什么 Config 不够

| Config 选项 | 预期 | 实际（源码验证） |
|---|---|---|
| `requireMention: true` | Thread 内只响应显式 @mention | ❌ 一旦 bot 参与过 thread，`implicitMention` 永远为 true，绕过 requireMention |
| `allowBots: "mentions"` | 只处理显式 @mention 自己的 bot 消息 | ❌ Slack provider 只做 truthy/falsy 检查，`"mentions"` 等同于 `true`（仅 Discord 有效） |

### 解决：两层防线

| 层级 | 机制 | 作用范围 | 类型 |
|------|------|----------|------|
| Config | `requireMention: true` | Channel 根消息（非 thread） | 硬约束 |
| Prompt | 显式 @mention 协议 | Thread 内所有消息 | 软约束（指令遵从） |

### 显式 @mention 协议

每个参与 Discussion Mode 的 Agent 的 workspace 文件中应包含：

```markdown
## Multi-Agent Thread 协作规则

在 Slack thread 中如果有其他 bot 也在参与：

1. **收到消息时**：检查消息文本是否包含 `<@你的BotID>`。
   如果没有 → 整条回复只输出 `NO_REPLY`。

2. **发送消息时**：`<@目标BotID>` 显式 mention 目标。
   不 @ 任何 bot = 对话终止信号。

3. **角色**：
   - Orchestrator：选择 @Worker / @Human / 不@（结束）
   - Worker：每次回复必须 @ Orchestrator

4. **终止**：说"完毕/done"后不再发送，除非被重新 @。

5. **轮次上限**：同一 thread 内最多 N 轮（建议 5-8），超过后暂停并向人类汇报。
```

### 协作流程

```
Human → @Orchestrator: "讨论 X"

Phase 0（展开 spec）:
  Orchestrator → Thread: DISCUSSION SPEC（目标 + 验收标准 + 终止条件）
  Orchestrator → @Worker: 第一个问题

Round 1/M:
  Worker → @Orchestrator: 回复（摘要在 thread，详细写文件）
  Orchestrator 评估 → 继续 / 终止

终止（三选一）:
  ✅ 验收标准满足 → DISCUSSION_CLOSE
  ⚠️ 达到最大轮次 → 请人类介入
  🔄 连续 2 轮无进展 → 请人类介入
```

### 终止协议

```
DISCUSSION_CLOSE
Topic: <主题>
Consensus: <共识 / "未达成共识，原因：...">
Actions: <后续任务>
Rounds Used: N/M
```

### 已知局限

1. **Input token 仍消耗**——消息送达所有 bot，NO_REPLY 不阻止 input token 消耗
2. **Prompt 是软约束**——LLM 可能偶尔违反
3. **`allowBots: "mentions"` 仅 Discord 可用**——Slack 无法从 config 层面过滤 bot 消息
4. **`requireMention: true` 在 thread 内被绕过**——需 OpenClaw 增加 `thread.requireExplicitMention` 才能系统级解决

---

## 平台能力对比

| 能力 | Slack | Discord | Feishu |
|------|-------|---------|--------|
| Delegation (sessions_send) | ✅ | ✅ | ✅ |
| Discussion (跨 bot 对话) | ✅ 已验证 | ❌ (OpenClaw bug) | ❌ (平台限制) |
| `allowBots: "mentions"` | ❌ | ✅ | N/A |
| Multi-Account | ✅ | ✅ | ✅ |
