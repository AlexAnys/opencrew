**中文** | [English](en/SLACK_SETUP.md)

> 📖 [README](../README.md) → [完整上手指南](GETTING_STARTED.md) → **Slack 接入指南** → [配置参考](CONFIG_SNIPPET_2026.2.9.md)

# Slack 接入指南

> 目标：用 **一个 Slack App** 连接 OpenClaw，然后用"频道=岗位"绑定多个 Agent；后续增减 Agent 只需要增减频道 + 配置绑定。

OpenCrew 默认使用 Slack **Socket Mode**（不需要公网 webhook）。

---

## 你会得到什么

完成后你将拥有：
- 一个 Slack App（包含一个 bot）
- 两个 token：
  - **App Token**：`xapp-...`（Socket Mode 需要）
  - **Bot Token**：`xoxb-...`
- OpenClaw 已连接 Slack，并且 bot 被邀请进你希望使用的频道

---

## Step 1：在 Slack 创建 App + 开启 Socket Mode

1. 打开 https://api.slack.com/apps → **Create New App**（From scratch）
2. **Socket Mode** → Enable
3. **Basic Information** → **App-Level Tokens** → Generate Token and Scopes
   - 添加 scope：`connections:write`
   - 生成并复制 **App Token**（`xapp-...`）

---

## Step 2：配置 Bot 权限（Scopes）并安装到 Workspace

在 **OAuth & Permissions** → Bot Token Scopes 添加（OpenClaw 官方建议的最小集合）：

- `chat:write`
- `im:write`
- `channels:history`, `groups:history`, `im:history`, `mpim:history`
- `channels:read`, `groups:read`, `im:read`, `mpim:read`
- `users:read`
- `reactions:read`, `reactions:write`
- `pins:read`, `pins:write`
- `emoji:read`
- `files:write` `files:read`

然后点击 **Install to Workspace**，复制 **Bot User OAuth Token**（`xoxb-...`）。

---

## Step 3：开启事件订阅（Event Subscriptions）

在 **Event Subscriptions** → Enable Events，订阅以下事件（OpenClaw 文档建议）：

- `message.*`（包括编辑/删除/线程广播）
- `app_mention`
- `reaction_added`, `reaction_removed`
- `member_joined_channel`, `member_left_channel`
- `channel_rename`
- `pin_added`, `pin_removed`

在 **Install App** 重新加载应用，获得bot-token (App-token在 **Basic Information** 中的 App-Level Tokens 里) 
---

## Step 4：把 Slack 账号接入 OpenClaw（推荐用 CLI 写入配置）

在本机终端执行（把 token 换成你自己的）：

```bash
openclaw channels add --channel slack \
  --app-token "xapp-..." \
  --bot-token "xoxb-..."
```

> 这一步会把 Slack 配置写入 `~/.openclaw/openclaw.json`（比手动编辑更稳）。

然后重启 gateway：

```bash
openclaw gateway restart
```

验证 Slack 是否在线：

```bash
openclaw channels status --probe
# 或
openclaw status
```

---

## Step 5：创建 OpenCrew 频道并邀请 bot

**最小配置（3 个频道，推荐先从这里开始）：**
- `#hq`（CoS 幕僚长）
- `#cto`（CTO 技术合伙人）
- `#build`（Builder 执行者）

**按需扩展：**
- `#invest`（CIO 领域专家，可选）
- `#know`（KO 知识官，可选）
- `#ops`（Ops 运维官，可选）
- `#research`（Research 调研员，可选）

然后在每个频道里 `/invite @<你的bot名字>`。

> 如果 bot 没在频道里，通常无法读取历史/也可能无法发言（除非你额外配置 `chat:write.public`，不建议给新手用）。

---

## Step 6：获取 Channel ID（两种方法）

### 方法 A（最简单）：Slack 里 Copy link
右键频道名 → **Copy link** → 链接中的 `C0XXXXXXXX` 就是 Channel ID。

### 方法 B（可选）：用 OpenClaw 解析

```bash
openclaw channels resolve --channel slack "#hq" --json
```

---

---

## 推荐配置：频道 Session 自动隔离

### 问题

默认情况下，同一个 Slack 频道里所有消息共用一个 session，且 idle 超时很长（默认数天）。这意味着你在 `#cto` 频道先聊了一个技术方案，过了一小时又聊另一个完全不同的话题——AI 仍然带着上一个话题的完整上下文在回复，导致**上下文污染**和**token 浪费**。

Thread 内的对话不受影响（每个 thread 有独立 session），但频道级的 root message 会互相干扰。

### 解决方案

在 `openclaw.json` 的 `session` 中按类型设置不同的 idle 超时：

```jsonc
"session": {
  "reset": {
    "mode": "idle",
    "idleMinutes": 43200          // 全局默认 30 天
  },
  "resetByType": {
    "group": {
      "mode": "idle",
      "idleMinutes": 5            // 频道/群聊：5 分钟后自动重置
    },
    "dm": {
      "mode": "idle",
      "idleMinutes": 43200        // DM：30 天，保持长上下文
    },
    "thread": {
      "mode": "idle",
      "idleMinutes": 43200        // Thread：30 天，保持任务连续性
    }
  }
}
```

**效果**：频道里超过 5 分钟没有新消息，下一条消息会开启全新 session，不再携带旧上下文。DM 和 Thread 不受影响，保持 30 天的长上下文。

> **技术细节**：OpenClaw 内部将 Slack channel（session key 含 `:channel:`）和 group DM（含 `:group:`）统一归类为 `"group"` 类型，因此设置 `resetByType.group` 即可同时覆盖两者。这不会影响 Thread 和 DM 的 session 策略。

### 什么时候需要这个配置？

- 你在同一个频道里讨论多个不相关的话题
- Agent 回复时引用了很久之前的无关对话
- 你使用 OpenCrew 的多频道架构（每个频道绑定一个 Agent）

### 不需要这个配置的场景

- 你只用 DM 和 Thread 与 Agent 交流
- 频道内的对话始终围绕同一个主题

---

## 参考

- [OpenClaw Slack 集成文档](https://docs.openclaw.ai/zh-CN/channels/slack)

---

> 📖 下一步 → [完整上手指南](GETTING_STARTED.md) · [配置参考](CONFIG_SNIPPET_2026.2.9.md)
