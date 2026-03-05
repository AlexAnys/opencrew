**中文** | [English](en/CONFIG_SNIPPET_DISCORD.md)

> 📖 [README](../README.md) → [Discord 接入指南](DISCORD_SETUP.md) → **Discord 配置参考**

# OpenCrew Discord 最小增量配置

> 适用：已经在本机安装并能运行 OpenClaw（能执行 `openclaw status`），且 Discord 已接入（完成了 [Discord 接入指南](DISCORD_SETUP.md)）。
>
> 原则：
> - 不提供"完整 openclaw.json"（避免误覆盖 `auth/models/gateway`）
> - 只提供 **最小增量**：新增 Agents + Discord 频道绑定 + A2A 限制
> - 可回滚：删除我们新增的片段 + 删除新建的 workspace 目录

---

## 改之前先做备份（强烈建议）

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.$(date +%Y%m%d-%H%M%S)
```

---

## 你需要准备的占位符

- **Discord Guild ID**（服务器 ID）：`<DISCORD_GUILD_ID>`
- Discord Channel IDs（频道 ID）：
  - `<DISCORD_CHANNEL_ID_HQ>`（#hq → CoS）
  - `<DISCORD_CHANNEL_ID_CTO>`（#cto → CTO）
  - `<DISCORD_CHANNEL_ID_BUILD>`（#build → Builder）
  - `<DISCORD_CHANNEL_ID_INVEST>`（#invest → CIO，可选）
  - `<DISCORD_CHANNEL_ID_KNOW>`（#know → KO）
  - `<DISCORD_CHANNEL_ID_OPS>`（#ops → Ops）
  - `<DISCORD_CHANNEL_ID_RESEARCH>`（#research → Research，可选）

获取方法见：[Discord 接入指南 Step 6](./DISCORD_SETUP.md#step-6获取频道-id两种方法)

---

## 需要加到 `~/.openclaw/openclaw.json` 的最小增量

> 说明：以下片段假设你已经有自己的 `openclaw.json`。你只需要把这些**新增项**合并进去即可。
>
> 如果你已经有同名 agent id（例如已存在 `cos`/`cto`），请改成不冲突的 id（例如 `crew-cos`），并同步修改 bindings。

### A) 新增 Agents（`agents.list`）

把这些 agent 追加到你现有的 `agents.list` 里（不要删除你原来的 `main`）：

```json
{
  "agents": {
    "list": [
      {
        "id": "cos",
        "name": "Chief of Staff",
        "workspace": "~/.openclaw/workspace-cos",
        "subagents": { "allowAgents": ["cos", "cto", "research", "ko", "builder"] },
        "heartbeat": { "every": "12h", "target": "discord", "to": "channel:<DISCORD_CHANNEL_ID_HQ>" }
      },
      {
        "id": "cto",
        "name": "CTO / Tech Partner",
        "workspace": "~/.openclaw/workspace-cto",
        "subagents": { "allowAgents": ["cto", "builder", "research", "ko"] }
      },
      {
        "id": "builder",
        "name": "Builder / Executor",
        "workspace": "~/.openclaw/workspace-builder",
        "subagents": { "allowAgents": ["builder"] }
      },
      {
        "id": "cio",
        "name": "CIO / Domain Specialist (Optional)",
        "workspace": "~/.openclaw/workspace-cio",
        "subagents": { "allowAgents": ["cio", "research", "ko"] }
      },
      {
        "id": "ko",
        "name": "Knowledge Officer",
        "workspace": "~/.openclaw/workspace-ko",
        "subagents": { "allowAgents": ["ko"] },
        "heartbeat": { "every": "12h", "target": "discord", "to": "channel:<DISCORD_CHANNEL_ID_KNOW>" }
      },
      {
        "id": "ops",
        "name": "Operations / Governance",
        "workspace": "~/.openclaw/workspace-ops",
        "subagents": { "allowAgents": ["ops", "ko"] }
      },
      {
        "id": "research",
        "name": "Research Worker (Spawn-only)",
        "workspace": "~/.openclaw/workspace-research",
        "subagents": { "allowAgents": [] }
      }
    ]
  }
}
```

### B) A2A / 子智能体保护（`tools` + `session`）

```json
{
  "tools": {
    "agentToAgent": { "enabled": true, "allow": ["cos", "cto", "ops"] },
    "subagents": { "tools": { "deny": ["group:sessions"] } }
  },
  "session": {
    "agentToAgent": { "maxPingPongTurns": 4 }
  }
}
```

### C) Discord 频道绑定（`bindings`）

Discord 使用 Guild ID + Channel ID 的路由模型。每条 binding 指定一个 Agent 绑定到一个 Discord 频道：

```json
{
  "bindings": [
    { "agentId": "cos", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_HQ>" } } },
    { "agentId": "cto", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_CTO>" } } },
    { "agentId": "builder", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_BUILD>" } } },
    { "agentId": "cio", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_INVEST>" } } },
    { "agentId": "ko", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_KNOW>" } } },
    { "agentId": "ops", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_OPS>" } } },
    { "agentId": "research", "match": { "channel": "discord", "guildId": "<DISCORD_GUILD_ID>", "peer": { "kind": "channel", "id": "<DISCORD_CHANNEL_ID_RESEARCH>" } } }
  ]
}
```

### D) Discord allowlist + thread 隔离（`channels.discord`）

Discord 的 thread 会自动继承所在频道的配置（Agent 绑定、requireMention 等），除非你为某个 thread ID 单独配置。

```json
{
  "channels": {
    "discord": {
      "groupPolicy": "allowlist",
      "guilds": {
        "<DISCORD_GUILD_ID>": {
          "requireMention": false,
          "channels": {
            "<DISCORD_CHANNEL_ID_HQ>": { "allow": true },
            "<DISCORD_CHANNEL_ID_CTO>": { "allow": true },
            "<DISCORD_CHANNEL_ID_BUILD>": { "allow": true },
            "<DISCORD_CHANNEL_ID_INVEST>": { "allow": true },
            "<DISCORD_CHANNEL_ID_KNOW>": { "allow": true },
            "<DISCORD_CHANNEL_ID_OPS>": { "allow": true },
            "<DISCORD_CHANNEL_ID_RESEARCH>": { "allow": true }
          }
        }
      }
    }
  }
}
```

> **关于 bot 外观**：所有 Agent 共享同一个 Discord Bot 的头像和名称。如需让不同 Agent 显示不同外观，可使用 webhook relay 方案（高级配置，参考 [openclaw-discord-spoof-avatar](https://github.com/Yvvvan/openclaw-discord-spoof-avatar)）。

### 可选：开启 @mention gate（降噪；建议你跑通后再开）

开源版默认 `requireMention: false`，优先保证"照着做就能跑起来"。

如果你希望某些频道更安静（只在 @mention 时触发），在 guild 级别或频道级别设置 `requireMention: true`：

```json
{
  "channels": {
    "discord": {
      "guilds": {
        "<DISCORD_GUILD_ID>": {
          "channels": {
            "<DISCORD_CHANNEL_ID_KNOW>": { "allow": true, "requireMention": true },
            "<DISCORD_CHANNEL_ID_OPS>": { "allow": true, "requireMention": true }
          }
        }
      }
    }
  }
}
```

### E) Heartbeat（推荐默认开启：本 snippet 已为 CoS/KO 开启）

很多人以为"有了 `HEARTBEAT.md` 文件就会自动跑心跳"，但 **心跳是否运行由 `openclaw.json` 决定**。

在上面的 `agents.list` 示例里，我们已经为 `cos` / `ko` 加了：
- `heartbeat.every = "12h"`（≈每天 2 次）
- `heartbeat.target = "discord"` + `to = "channel:<...>"`

> 重要规则（来自 OpenClaw 文档）：
> 如果 `agents.list[]` 里**任何一个** agent 配了 `heartbeat` 块，那么**只有**配置了 `heartbeat` 的 agents 才会运行心跳。
> 因此：如果你原本依赖 `agents.defaults.heartbeat` 跑"全局心跳"，引入 per-agent heartbeat 后行为会变化。

如果你不想让 CoS/KO 运行心跳：删除这两个 agent 条目中的 `heartbeat` 块即可。
验证心跳是否在跑：

```bash
openclaw system heartbeat last
# 需要时可手动启用/禁用
openclaw system heartbeat enable
openclaw system heartbeat disable
```

### F) 工作区目录准备（强烈建议）

OpenCrew 的工作流会用到一些子目录（用于 daily memory、KO inbox/knowledge、CTO scars/patterns）。
建议先创建（不会影响你现有配置）：

```bash
mkdir -p ~/.openclaw/workspace-{cos,cto,builder,cio,ko,ops,research}/memory
mkdir -p ~/.openclaw/workspace-ko/{inbox,knowledge}
mkdir -p ~/.openclaw/workspace-cto/{scars,patterns}
```

---

## 应用后：重启 + 验证

```bash
openclaw gateway restart
openclaw status
```

验证建议：
1) 在 #cto 发消息 → CTO 应答
2) 让 CTO 在 #build 新开 thread 派给 Builder（两步 A2A）→ Builder 在 thread 内回复

---

## 回滚方式（很重要）

1) 直接恢复备份：

```bash
cp ~/.openclaw/openclaw.json.bak.<timestamp> ~/.openclaw/openclaw.json
openclaw gateway restart
```

2) 或手动回滚：
- 从 `openclaw.json` 删除本文件中新增的：
  - `agents.list` 里新增的 OpenCrew agents
  - `bindings` 新增条目
  - `channels.discord.guilds` 的 allowlist 条目
  - `tools.agentToAgent` / `session.agentToAgent` 的增量
- （可选）删除新建目录：`~/.openclaw/workspace-{cos,cto,builder,cio,ko,ops,research}`
