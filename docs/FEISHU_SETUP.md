**中文** | [English](en/FEISHU_SETUP.md)

> 📖 [README](../README.md) → [完整上手指南](GETTING_STARTED.md) → **飞书接入指南**

# 飞书接入指南

> 目标：用 **一个飞书自建应用** 连接 OpenClaw，然后用"群组=岗位"绑定多个 Agent；后续增减 Agent 只需要增减群组 + 配置绑定。

OpenCrew 使用飞书 **WebSocket 长连接**（不需要公网服务器）。

> Lark（国际版）用户请看 [Lark 专区](#lark国际版用户)。

### 与 Slack 的关键差异：Thread（话题）

OpenCrew 在 Slack 上的核心模型是"频道=岗位，Thread=任务"——每个任务在 thread 中独立推进，互不干扰。

飞书虽然有"话题"功能，但 **OpenClaw 的飞书插件目前不支持 thread 隔离**。这意味着：

- **"群组=岗位"完全成立** — 每个群组绑定一个 Agent，消息路由正常工作
- **"话题=任务"暂不可用** — 同一个群组内的所有对话是平铺的，不能按 thread 隔离不同任务
- 实际影响：当一个 Agent 同时处理多个任务时，对话会混在一起。对于轻量使用（一次一个任务）影响不大；高频并行任务场景下体验会打折扣

> 这是 OpenClaw 飞书插件的已知限制（[Issue #10242](https://github.com/openclaw/openclaw/issues/10242)），不是飞书平台本身的限制。后续插件更新可能会解决。

---

## 你会得到什么

完成后你将拥有：
- 一个飞书自建应用（包含一个机器人）
- 两个凭证：
  - **App ID**：`cli_xxxxxxxxx`
  - **App Secret**（妥善保管，不要分享）
- OpenClaw 已连接飞书，并且机器人被添加进你希望使用的群组

---

## Step 1：创建飞书应用 + 开启机器人能力（~10 分钟）

1. 打开 [飞书开放平台](https://open.feishu.cn/app)，用飞书账号登录
2. 点击 **创建企业自建应用**（不要选"自定义机器人"——那是 webhook-only，功能受限）
3. 填写应用名称（如"OpenCrew 助手"）和描述，选一个图标
4. 进入应用后，左侧菜单 **添加应用能力** → 找到 **机器人** → 点击 **添加**
5. 给机器人起个名字，保存

> 建议用飞书**管理员账号**创建应用——管理员创建的应用发布时自动通过审批，无需等待。

---

## Step 2：配置权限 + 事件订阅

### 2a. 批量导入权限

左侧菜单 **权限管理** → 点击 **批量导入** → 粘贴以下 JSON：

```json
{
  "scopes": {
    "tenant": [
      "im:chat",
      "im:chat.members:bot_access",
      "im:message",
      "im:message.group_at_msg:readonly",
      "im:message.group_msg",
      "im:message.p2p_msg:readonly",
      "im:message:readonly",
      "im:message:send_as_bot",
      "im:resource",
      "contact:user.employee_id:readonly"
    ],
    "user": [
      "im:chat.access_event.bot_p2p_chat:read"
    ]
  }
}
```

> 已有的权限会自动跳过，不会重复添加。如果需要图片/文件/文档等高级功能，可参考 [openclaw-feishu 完整权限列表](https://github.com/AlexAnys/openclaw-feishu)。

### 2b. 配置事件订阅

左侧菜单 **事件与回调** → **事件配置**：

1. 订阅方式选择：**使用长连接接收事件**（关键！不需要公网服务器）
2. 点击 **添加事件**，搜索并添加：`im.message.receive_v1`（接收消息）

---

## Step 3：记下凭证 + 发布应用

### 3a. 复制凭证

左侧菜单 **凭证与基础信息**，复制：
- **App ID**（格式：`cli_xxxxxxxxx`）
- **App Secret**

### 3b. 发布

左侧菜单 **版本管理与发布** → **创建版本** → 填写版本说明 → **提交**

- 管理员创建的应用：自动通过，几秒生效
- 非管理员创建的应用：需要管理员在飞书"工作台 → 应用管理"中审批

---

## Step 4：把飞书接入 OpenClaw

在终端执行：

```bash
openclaw channels add --channel feishu \
  --app-id "cli_xxxxxxxxx" \
  --app-secret "你的AppSecret"
```

> 也可以用交互式方式：`openclaw channels add`，选择 Feishu，按提示粘贴凭证。

然后重启 gateway：

```bash
openclaw gateway restart
```

验证飞书是否在线：

```bash
openclaw channels status --probe
# 或
openclaw status
```

日志中看到 `feishu ws connected` 或 `feishu provider ready` 即连接成功。

---

## Step 5：创建 OpenCrew 群组并添加机器人

**最小配置（3 个群组，推荐先从这里开始）：**
- 总部群（CoS 幕僚长）
- 技术群（CTO 技术合伙人）
- 执行群（Builder 执行者）

**按需扩展：**
- 投资群（CIO 领域专家，可选）
- 知识群（KO 知识官，可选）
- 运维群（Ops 运维官，可选）
- 调研群（Research 调研员，可选）

在每个群组中：点击群设置 → **添加机器人** → 搜索你的机器人名 → 添加。

---

## Step 6：获取群组 ID（两种方法）

### 方法 A：用 OpenClaw 解析

```bash
openclaw channels resolve --channel feishu "总部群" --json
```

### 方法 B：看日志

```bash
openclaw logs --follow
```

在群组中 @机器人 发一条消息，日志中会显示 `chat_id`（格式：`oc_xxxxxxxxxxxxxxxx`），这就是群组 ID。

---

## 常见问题

### 没有消息发送框？

事件订阅没有配置。去飞书开放平台 → 你的应用 → 事件与回调 → 添加 `im.message.receive_v1` → 订阅方式选"长连接" → 创建新版本 → 发布。

### 机器人完全没反应？

按顺序检查：
1. **网关在运行吗？** `openclaw gateway status`
2. **应用发布了吗？** 飞书开放平台 → 版本管理，确认有已发布版本
3. **事件订阅配了吗？** 确认选了"长连接"且添加了 `im.message.receive_v1`
4. **权限够吗？** 至少需要 `im:message`、`im:message.p2p_msg:readonly`、`im:message:send_as_bot`
5. **看日志** `openclaw logs --follow`，发消息看有没有反应

### 群聊中机器人不回复？

默认需要 @机器人 才会回复。确认机器人已被添加到群组。

### 收到配对码？

首次对话时，出于安全考虑机器人会回复配对码。在终端执行：

```bash
openclaw pairing approve feishu <配对码>
```

授权后即可正常对话，这是一次性操作。

### 审批不通过？

让飞书管理员创建应用（管理员创建的应用自动通过审批），或让管理员在"工作台 → 应用管理"中手动审批。

---

## 进阶：为每个 Agent 配置独立 Bot（多应用模式）

> 默认的"单 Bot"模式已经能满足大多数场景。以下情况才需要多应用模式：
> - 希望每个 Agent 有独立的名字和头像（在群聊中一眼区分）
> - 需要独立的 API 限速配额（飞书按应用计费）
> - 需要权限隔离（不同 Agent 访问不同范围的数据）

### 单 Bot vs 多 Bot 对比

| 维度 | 单 Bot（默认） | 多 Bot（进阶） |
|------|--------------|---------------|
| 配置复杂度 | 低（1 个应用） | 中（每 Agent 一个应用） |
| Agent 外观 | 共享名称和头像 | 各自独立身份 |
| API 配额 | 共享 | 独立（N 倍容量） |
| 权限隔离 | 共享 | 独立 |
| 适用场景 | 快速上手 | 正式生产环境 |

### 配置方式

1. **为每个 Agent 创建独立应用** — 步骤同前面的 [Step 1](#step-1创建飞书应用--开启机器人能力10-分钟) ~ [Step 3](#step-3记下凭证--发布应用)，每个应用对应一个 Agent
2. **OpenClaw 配置使用 `accounts` 多账户格式：**

```yaml
channels:
  feishu:
    domain: feishu
    connectionMode: websocket
    accounts:
      cos-bot:
        name: "CoS 幕僚长"
        appId: "cli_cos_xxxxx"
        appSecret: "your-cos-secret"
        enabled: true
      cto-bot:
        name: "CTO 技术合伙人"
        appId: "cli_cto_xxxxx"
        appSecret: "your-cto-secret"
        enabled: true
```

3. **Agent 绑定中使用 `accountId` 指定对应的 Bot：**

```yaml
agents:
  - name: cos
    bindings:
      - channel: feishu
        accountId: cos-bot
        peer:
          kind: group
          id: "oc_xxx"
```

### 注意事项

- 每个应用需独立配置事件订阅（`im.message.receive_v1`）和权限（参考 [Step 2](#step-2配置权限--事件订阅)）
- "一群一 Agent"模式下，每个群只添加对应的 bot，避免消息重复
- A2A 通信不受影响 — 走 OpenClaw 内部 `sessions_send`，与 bot 数量无关

---

## Lark（国际版）用户

Lark 后台不支持 WebSocket 长连接，需要使用 **Webhook 模式** + 公网隧道。

完整 Lark 接入教程请参考 [openclaw-feishu 项目的 Lark 指南](https://github.com/AlexAnys/openclaw-feishu#-lark国际版接入指南)。

核心差异：
- 开发者平台：[open.larksuite.com](https://open.larksuite.com)（而非 open.feishu.cn）
- 连接方式：Webhook HTTP 回调（需要公网 URL，推荐 Cloudflare Tunnel）
- 配置中需要设置 `domain: "lark"` 和 `connectionMode: "webhook"`

---

## 参考

- [飞书开放平台文档](https://open.feishu.cn/document)
- [OpenClaw 飞书集成文档](https://docs.openclaw.ai/zh-CN/channels/feishu)
- [openclaw-feishu：飞书配置指南 & 社区支持](https://github.com/AlexAnys/openclaw-feishu)

---

> 📖 下一步 → [完整上手指南](GETTING_STARTED.md) · [飞书配置参考](CONFIG_SNIPPET_FEISHU.md)
