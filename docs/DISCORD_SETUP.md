**中文** | [English](en/DISCORD_SETUP.md)

> 📖 [README](../README.md) → [完整上手指南](GETTING_STARTED.md) → **Discord 接入指南**

# Discord 接入指南

> 目标：用 **一个 Discord Bot** 连接 OpenClaw，然后用"频道=岗位"绑定多个 Agent；后续增减 Agent 只需要增减频道 + 配置绑定。

OpenCrew 使用 Discord **Gateway**（WebSocket 长连接，不需要公网服务器）。

---

## 你会得到什么

完成后你将拥有：
- 一个 Discord Application（包含一个 bot）
- 一个 **Bot Token**（`MTxxx...`）
- OpenClaw 已连接 Discord，并且 bot 被邀请进你的服务器

---

## Step 1：创建 Discord 应用 + Bot（~5 分钟）

1. 打开 [Discord Developer Portal](https://discord.com/developers/applications) → **New Application**
2. 输入应用名（如"OpenCrew"）→ 勾选同意条款 → **Create**
3. 左侧菜单点击 **Bot**
4. 点击 **Reset Token** → 确认 → **复制 Bot Token** 并妥善保管

> Bot Token 只显示一次。如果丢失需要重新 Reset。

---

## Step 2：开启 Privileged Intents（关键！）

仍在 **Bot** 页面，向下滚动到 **Privileged Gateway Intents**，开启以下三项：

| Intent | 说明 |
|--------|------|
| **Server Members Intent** | 追踪成员加入/离开 |
| **Presence Intent** | 在线状态（可选） |
| **Message Content Intent** | **必须开启** — 否则 bot 无法读取消息内容 |

点击 **Save Changes**。

> 小于 100 个服务器的 bot 无需审核，直接开启即可。

---

## Step 3：邀请 Bot 到你的服务器（~3 分钟）

### 3a. 生成邀请链接

左侧菜单 **OAuth2** → **URL Generator**：

1. **Scopes** 勾选：`bot`、`applications.commands`
2. **Bot Permissions** 勾选：

| 权限 | 用途 |
|------|------|
| View Channels | 看到频道 |
| Send Messages | 发送消息 |
| Send Messages in Threads | 在线程中发消息 |
| Create Public Threads | 创建公开线程 |
| Create Private Threads | 创建私有线程 |
| Manage Threads | 管理线程（归档/锁定） |
| Read Message History | 读取历史消息 |
| Manage Channels | 创建/管理频道 |
| Add Reactions | 添加表情回应 |
| Mention Everyone | 使用 @提及 |

3. 复制底部生成的 **URL**

### 3b. 授权加入

1. 在浏览器打开复制的 URL
2. 选择你的 Discord 服务器
3. 确认权限 → 完成验证
4. Bot 出现在服务器成员列表中（显示为离线，连接后上线）

---

## Step 4：把 Discord 接入 OpenClaw

在终端执行：

```bash
openclaw channels add --channel discord \
  --bot-token "你的BotToken"
```

> 也可以用交互式方式：`openclaw channels add`，选择 Discord，按提示粘贴 Token。

然后重启 gateway：

```bash
openclaw gateway restart
```

验证 Discord 是否在线：

```bash
openclaw channels status --probe
# 或
openclaw status
```

Bot 在 Discord 中显示为"在线"即连接成功。

---

## Step 5：创建 OpenCrew 频道并确认 Bot 可见

在你的 Discord 服务器中创建频道：

**最小配置（3 个频道，推荐先从这里开始）：**
- `#hq`（CoS 幕僚长）
- `#cto`（CTO 技术合伙人）
- `#build`（Builder 执行者）

**按需扩展：**
- `#invest`（CIO 领域专家，可选）
- `#know`（KO 知识官，可选）
- `#ops`（Ops 运维官，可选）
- `#research`（Research 调研员，可选）

> 推荐创建一个 **频道分类**（Category）如"AI Agents"，把所有 Agent 频道归在一起。

确认 bot 在每个频道的权限设置中有"查看频道"和"发送消息"权限（如果 bot 有 Manage Channels 权限，通常自动满足）。

---

## Step 6：获取 Channel ID（两种方法）

### 方法 A（推荐）：开启开发者模式复制

1. Discord 设置 → **高级** → 开启 **开发者模式**
2. 右键点击频道名 → **复制频道 ID**

### 方法 B：用 OpenClaw 解析

```bash
openclaw channels resolve --channel discord "#hq" --json
```

---

## 常见问题

### Bot 不回复消息？

最常见原因：**Message Content Intent 没有开启**。

去 [Developer Portal](https://discord.com/developers/applications) → 你的应用 → Bot → 确认 **Message Content Intent** 已开启 → Save Changes → 重启 gateway。

### Bot 在服务器里显示离线？

1. **网关在运行吗？** `openclaw gateway status`
2. **Token 正确吗？** 重新检查 Bot Token
3. **看日志** `openclaw logs --follow`

### Thread（线程）怎么用？

Discord 的线程对应 OpenCrew 的"任务/会话"概念。Agent 在频道中发起任务时会自动创建线程。

线程会在一段时间无活动后自动归档（1 天 / 3 天 / 7 天），归档后仍可查看和重新打开。

### 一个 Bot 还是多个 Bot？

OpenCrew 使用 **一个 Bot** 管理所有 Agent（和 Slack 的模式一致）。不同 Agent 通过不同频道区分。

### 需要服务器（VPS）吗？

不需要。Discord Gateway 使用 WebSocket 出站连接，你的电脑直接连 Discord 服务器，不需要公网 IP。

---

## 参考

- [Discord Developer Portal](https://discord.com/developers/applications)
- [Discord Bot 官方文档](https://discord.com/developers/docs/quick-start/getting-started)
- [OpenClaw Discord 集成文档](https://docs.openclaw.ai/channels/discord)

---

> 📖 下一步 → [完整上手指南](GETTING_STARTED.md) · [配置参考](CONFIG_SNIPPET_2026.2.9.md)
