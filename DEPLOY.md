**中文** | [English](DEPLOY.en.md)

# 部署指南（精简版）

> **本文适合直接发给你的 OpenClaw，让它代你执行部署。** 完整的人工操作指南（含详细说明、常见报错、验证清单）见 → [完整上手指南](docs/GETTING_STARTED.md)
>
> 原则：**不依赖"一键脚本"**、不提供"完整 openclaw.json"，用最小增量 + 可回滚的方式，把 OpenCrew 加进你现有的 OpenClaw。

---

## 0. 前置要求（新手请按顺序做）

1. 你能正常运行 OpenClaw（本机）
   - 能执行：`openclaw status`
2. 你有一个消息平台（Slack / 飞书 / Discord 任选其一）
3. 你准备使用 **一个 App/Bot** 来管理所有 OpenCrew Agent（后续增减 Agent 就是增减频道/群组 + 配置绑定）

如果你还没接入消息平台：
- Slack → [`docs/SLACK_SETUP.md`](docs/SLACK_SETUP.md)
- 飞书 → [`docs/FEISHU_SETUP.md`](docs/FEISHU_SETUP.md)
- Discord → [`docs/DISCORD_SETUP.md`](docs/DISCORD_SETUP.md)

---

## 1. 创建频道/群组（岗位）

在你的消息平台上创建以下频道或群组（名字可自定义）：
- #hq / 总部群（CoS）
- #cto / 技术群（CTO）
- #build / 执行群（Builder）
- #invest / 投资群（CIO，可选，可替换为你的领域）
- #know / 知识群（KO，建议开启 requireMention 降噪；开源版默认关闭，先保证跑通）
- #ops / 运维群（Ops，建议开启 requireMention 降噪；开源版默认关闭，先保证跑通）
- #research / 调研群（Research，可选，通常只 spawn）

然后把 bot 邀请进去：
- Slack：`/invite @<bot>`
- 飞书：群设置 → 添加机器人
- Discord：频道权限中确认 bot 可见

---

## 给 OpenClaw 的执行提示

> 以下信息面向执行部署的 OpenClaw Agent。如果你是人工阅读，可跳过这一节。

当用户让你部署 OpenCrew 时，按以下流程执行：

### 执行流程

```
Step 1: 备份
  cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.$(date +%s)

Step 2: 复制文件（见下方"方式 B"的 bash 命令，照搬即可）
  - shared/*.md → ~/.openclaw/shared/
  - workspaces/<agent>/ → ~/.openclaw/workspace-<agent>/（不覆盖已有文件）
  - 为每个 workspace 创建软链接：shared → ~/.openclaw/shared
  - 创建子目录：memory/, ko/inbox, ko/knowledge, cto/scars, cto/patterns

Step 3: 获取频道/群组 ID
  按用户使用的平台获取 ID：
  - Slack：用户已提供 Bot Token，用 Slack API 自动获取：
    curl -s -H "Authorization: Bearer <botToken>" \
      "https://slack.com/api/conversations.list?types=public_channel&limit=200"
    匹配 is_member=true 的频道名拿到 Channel ID。
  - 飞书：用 openclaw channels resolve 或从日志中获取 chat_id（oc_xxx 格式）。
    详见 docs/FEISHU_SETUP.md Step 6。
  - Discord：开启开发者模式后右键频道复制 ID，或从日志获取。
    详见 docs/DISCORD_SETUP.md Step 6。

Step 4: 写入平台配置
  按平台把凭证写入对应的 channels 配置：
  - Slack：botToken + appToken → channels.slack（Socket Mode）
  - 飞书：appId + appSecret → channels.feishu
  - Discord：botToken → channels.discord

Step 5: 合并 Agent 配置
  按用户使用的平台，读对应的配置参考文件：
  - Slack → docs/CONFIG_SNIPPET_2026.2.9.md
  - 飞书 → docs/CONFIG_SNIPPET_FEISHU.md
  - Discord → docs/CONFIG_SNIPPET_DISCORD.md
  按其结构把以下增量合并到 openclaw.json：
  - agents.list（新增 Agent 条目，保留用户原有的 main agent）
  - bindings（频道/群组 → Agent 映射）
  - channels 白名单（allowlist + requireMention）
  - tools.agentToAgent + session.agentToAgent（A2A 保护）

Step 6: 重启并验证
  openclaw gateway restart
  openclaw status（确认 Agent 数量和平台连接状态正常）
```

### 边界（不要做的事）

- **不要修改**用户的 `models` / `auth` / `gateway` 相关配置
- **不要删除**用户已有的 agents、bindings 或 channels 条目
- 遇到冲突（如用户已有同名 agent id）先停下来问用户

---

## 2. 把 OpenCrew 文件放进你的 `~/.openclaw/`

你有两种方式：

### 方式 A（推荐）：让你现有的 OpenClaw 代你完成部署

把下面这段话发给你的 OpenClaw（替换 `<>` 里的内容）：

```
帮我部署 OpenCrew 多 Agent 团队。

仓库：请 clone https://github.com/AlexAnys/opencrew.git 到 /tmp/opencrew
（如果已下载，仓库路径：<你的本地路径>）

我使用的平台：<Slack / 飞书 / Discord>（选一个）

平台凭证（请写入配置，不要回显）：
- Slack: Bot Token (xoxb-) + App Token (xapp-)
- 飞书: App ID (cli_xxx) + App Secret
- Discord: Bot Token

我已创建以下频道/群组并邀请了 bot：
- #hq / 总部群 → CoS
- #cto / 技术群 → CTO
- #build / 执行群 → Builder

请读仓库里的 DEPLOY.md，按流程完成部署。
不要改我的 models / auth / gateway 配置，只做 OpenCrew 的增量。
```

你的 OpenClaw 会读取本文件和对应平台的 CONFIG_SNIPPET 文件，自动完成备份、文件复制、配置合并、重启和验证。

### 方式 B：手动复制（透明但需要一点命令行）

```bash
mkdir -p ~/.openclaw/shared
cp shared/*.md ~/.openclaw/shared/

for a in cos cto builder cio ko ops research; do
  mkdir -p ~/.openclaw/workspace-$a
  # 推荐递归复制（包含 ko/knowledge、cto/scars 等子目录模板）
  rsync -a --ignore-existing "workspaces/$a/" "$HOME/.openclaw/workspace-$a/"
done

# （推荐）把 shared/ 以软链接方式挂到每个 workspace 下，让 shared 规则更容易被 Agent“看见”。
# - 不会复制多份文件，避免 shared 漂移
# - 如果你的 workspace 下已经有 shared/ 目录，则跳过（你可以手动处理）
for a in cos cto builder cio ko ops research; do
  if [ ! -e "$HOME/.openclaw/workspace-$a/shared" ]; then
    ln -s "$HOME/.openclaw/shared" "$HOME/.openclaw/workspace-$a/shared"
  fi
done

# 推荐：创建 OpenCrew 会用到的工作区子目录（避免后续写文件失败）
mkdir -p ~/.openclaw/workspace-{cos,cto,builder,cio,ko,ops,research}/memory
mkdir -p ~/.openclaw/workspace-ko/{inbox,knowledge}
mkdir -p ~/.openclaw/workspace-cto/{scars,patterns}
```

> 说明：这里使用 `rsync --ignore-existing` 是为了尽量避免覆盖你已经在用的 workspace 文件。
---

## 3. 写入最小增量配置

按你使用的平台选择对应的配置参考：
- **Slack** → [`docs/CONFIG_SNIPPET_2026.2.9.md`](docs/CONFIG_SNIPPET_2026.2.9.md)
- **飞书** → [`docs/CONFIG_SNIPPET_FEISHU.md`](docs/CONFIG_SNIPPET_FEISHU.md)
- **Discord** → [`docs/CONFIG_SNIPPET_DISCORD.md`](docs/CONFIG_SNIPPET_DISCORD.md)

每个文件都包含：
- 需要新增的 agents（以及各自 workspace 路径）
- 平台频道/群组 bindings（频道=岗位）
- 平台 allowlist（安全：只允许这些频道/群组触发）
- A2A 保护（maxPingPongTurns / 发起权限 / subagent 禁止 sessions）
- 回滚方式

---

## 4. 重启并验证

```bash
openclaw gateway restart
openclaw status
```

验证建议：
1) 在 #hq 发一句话 → CoS 响应
2) 在 #cto 发一句话 → CTO 响应
3) 在 #cto 让 CTO 派一个实现任务给 Builder → #build 出现 thread，Builder 在 thread 内回复

---

## 5. 可选项：如果你不需要 CIO / Research

- 不需要 CIO：可以不创建 #invest，也不添加 CIO 的 binding/allowlist/agent 条目。
- Research 通常 spawn-only：可以不绑定 #research，或者只在需要时添加。

---

## 重要说明：关于“一键脚本”和 Slack routing patch

- 本 repo **不提供/不推荐**“一键脚本直接改你的系统配置”（每个人安装路径/现有配置不同，风险大）。推荐用你现有的 OpenClaw 按步骤做可回滚的增量部署。
- Slack 的“每条 root message 自动独立 session”目前没有纯配置级别的完美解法；高级用户可参考 `patches/`（见 docs/KNOWN_ISSUES.md）。
