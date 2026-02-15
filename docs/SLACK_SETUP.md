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
- `files:write`

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

## 参考

- [OpenClaw Slack 集成文档](https://docs.openclaw.ai/zh-CN/channels/slack)

---

> 📖 下一步 → [完整上手指南](GETTING_STARTED.md) · [配置参考](CONFIG_SNIPPET_2026.2.9.md)
