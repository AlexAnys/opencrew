> 📖 [README](../README.md) → **完整上手指南** → [核心概念](CONCEPTS.md) → [架构设计](ARCHITECTURE.md) → [自定义](CUSTOMIZATION.md)

# 完整上手指南 — 从零到多 Agent 协作跑通

本文是完整的分步指南。如果你只想快速跑通，回 [README 的 10 分钟上手](../README.md#10-分钟上手)。

---

## 前置条件

在开始前，请确认：

- **OpenClaw 已安装并可用**：运行 `openclaw status` 能看到正常输出
- **Slack workspace 已创建**：你有管理员权限
- **基本命令行能力**：能在终端里复制粘贴命令执行（或者让你现有的 OpenClaw 代为执行）

> 不确定 OpenClaw 怎么装？参考 [OpenClaw 官方文档](https://docs.openclaw.ai/)

---

## Phase 1：Slack 准备（约 20 分钟）

### 1.1 如果你还没把 Slack 接入 OpenClaw

按 [SLACK_SETUP.md](SLACK_SETUP.md) 创建 Slack App（Socket Mode），拿到两个 token：

- `xapp-...`（App-Level Token）
- `xoxb-...`（Bot Token）

然后执行：

```bash
openclaw channels add --channel slack --app-token "xapp-..." --bot-token "xoxb-..."
openclaw gateway restart
```

验证：在 Slack 任意频道 @你的bot → 它回复了 → ✅

### 1.2 创建 Agent 频道

在 Slack 里创建以下频道（名字可自定义，但建议保持简短）：

**最小配置（3 个频道）：**

| 频道 | 对应 Agent | 说明 |
|------|-----------|------|
| `#hq` | CoS 幕僚长 | 你的主要对话窗口，战略对齐 |
| `#cto` | CTO 技术合伙人 | 技术方向和任务拆解 |
| `#build` | Builder 执行者 | 具体实现和交付 |

**推荐扩展（按需添加）：**

| 频道 | 对应 Agent | 什么时候加 |
|------|-----------|-----------|
| `#invest` | CIO 领域专家 | 需要投资/法律/营销等领域分工时 |
| `#know` | KO 知识官 | 发现经验在流失、踩过的坑反复踩时 |
| `#ops` | Ops 运维官 | 发现 Agent 行为在慢慢"跑偏"时 |
| `#research` | Research 调研员 | 需要按需 spawn 调研任务时 |

### 1.3 邀请 bot 并记录 Channel ID

```
1. 在每个频道里输入：/invite @你的bot名
2. 记录每个频道的 Channel ID：
   右键频道名 → View channel details → 底部 Channel ID（以 C 开头）
```

> 所有频道建议设为**公开**——单用户工作区没有隐私问题，公开频道便于审计和追踪。

---

## Phase 2：部署 OpenCrew 文件（约 10 分钟）

### 2.1 复制 shared 协议 + workspace 文件

**方式 A：让你现有的 OpenClaw 代你部署（推荐，零命令行）**

把下面这段话发给你现有的 OpenClaw：

```
我要部署 OpenCrew。请帮我执行以下操作：

1) 备份 ~/.openclaw/openclaw.json（加时间戳）
2) 把 <仓库路径>/shared/ 下所有 .md 文件复制到 ~/.openclaw/shared/
3) 对于 cos、cto、builder 三个 Agent（最小配置）：
   - 创建 ~/.openclaw/workspace-<agent>/memory/ 目录
   - 把 <仓库路径>/workspaces/<agent>/ 下的文件复制过去（不覆盖已有文件）
   - 创建软链接：~/.openclaw/workspace-<agent>/shared → ~/.openclaw/shared
4) 每一步告诉我你做了什么

边界：不要改我的 models/auth/gateway 相关配置，只做 OpenCrew 的增量。
```

**方式 B：手动执行**

```bash
# 0. 备份
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak-$(date +%Y%m%d%H%M)

# 1. 复制全局协议
mkdir -p ~/.openclaw/shared
cp shared/*.md ~/.openclaw/shared/

# 2. 复制 workspace（最小 3 个 Agent）
for a in cos cto builder; do
  mkdir -p ~/.openclaw/workspace-$a/memory
  rsync -a --ignore-existing "workspaces/$a/" "$HOME/.openclaw/workspace-$a/"
done

# 3. 软链接 shared（让 Agent 能读到全局协议）
for a in cos cto builder; do
  if [ ! -e "$HOME/.openclaw/workspace-$a/shared" ]; then
    ln -s "$HOME/.openclaw/shared" "$HOME/.openclaw/workspace-$a/shared"
  fi
done

# 4. 验证
ls ~/.openclaw/workspace-cto/SOUL.md && echo "✅ workspace 就位"
ls ~/.openclaw/shared/SYSTEM_RULES.md && echo "✅ shared 协议就位"
```

### 2.2 如果你要部署全部 7 个 Agent

把上面 `for a in cos cto builder` 替换为 `for a in cos cto builder cio ko ops research`，并额外执行：

```bash
# KO 和 CIO 的特殊子目录
mkdir -p ~/.openclaw/workspace-ko/{inbox,knowledge}
mkdir -p ~/.openclaw/workspace-cto/{scars,patterns}
mkdir -p ~/.openclaw/workspace-cio/{decisions,principles,signals,watchlist}
```

---

## Phase 3：写入配置（约 5 分钟）

### 3.1 合并最小增量配置

按 [CONFIG_SNIPPET_2026.2.9.md](CONFIG_SNIPPET_2026.2.9.md) 操作。它包含：

- 新增的 agents 条目（ID、workspace 路径）
- Slack 频道绑定（Channel ID → Agent）
- Slack allowlist（只允许这些频道触发 Agent）
- A2A 保护（maxPingPongTurns、发起权限、subagent 限制）

**关键配置项说明**（帮你理解每项在做什么）：

| 配置项 | 作用 | 为什么需要 |
|--------|------|-----------|
| `agents.list` | 注册每个 Agent 的 ID 和 workspace | 没有这个，Agent 不存在 |
| `bindings` | Channel ID → Agent 的映射 | 没有这个，频道里的消息不会被路由到 Agent |
| `channels.slack.channels.allowlist` | 只允许指定频道触发 | 防止 bot 在其他频道被意外触发 |
| `maxPingPongTurns = 4` | A2A 来回上限 | 防止两个 Agent 互相触发导致消息风暴 |
| `tools.agentToAgent.allow` | 只允许 CoS/CTO/Ops 发起 A2A | 组织纪律，不是所有人都能派单 |
| `thread.historyScope = "thread"` | thread 内历史隔离 | 每个任务的上下文互不污染 |
| `replyToMode = "all"` | 所有回复进 thread | 频道不会被刷屏 |

### 3.2 Token 安全

**重要**：不要把 Slack token 硬编码在配置文件里。

推荐方式：
- **本地开发**：使用 `~/.openclaw/.env` 文件（权限设为 600）
- **生产环境**：使用 Bitwarden Secrets Manager 或等效工具

```bash
# 创建 .env
touch ~/.openclaw/.env
chmod 600 ~/.openclaw/.env

# 写入 token（替换为你的真实值）
echo 'SLACK_APP_TOKEN=xapp-1-你的token' >> ~/.openclaw/.env
echo 'SLACK_BOT_TOKEN=xoxb-你的token' >> ~/.openclaw/.env
```

### 3.3 重启

```bash
openclaw gateway restart
openclaw status
```

---

## Phase 4：验证（约 5 分钟）

### 基础验证

```
Test 1：在 #hq 发一句话 → CoS 回复 → ✅
Test 2：在 #cto 发一句话 → CTO 回复 → ✅
Test 3：在 #cto 让 CTO 派任务给 Builder
        → #build 出现 thread → Builder 在 thread 内回复 → ✅
```

### A2A 验证（如果 Test 3 成功就已经验证了）

在 #cto 对 CTO 说："帮我让 Builder 写一个 hello world 脚本"。观察：

1. CTO 在 `#build` 创建了一条 root message（A2A 锚点）
2. Builder 在该 thread 内回复并执行
3. CTO 在 `#cto` 同步了 Builder 的进展

如果以上都正常，恭喜——你的多 Agent 系统已经跑通了 🎉

---

## 常见问题排查

### Bot 没有响应

| 检查项 | 命令 |
|--------|------|
| Gateway 是否在线 | `openclaw gateway status` |
| Bot 是否被邀请到频道 | 在频道里看成员列表 |
| Channel ID 是否正确 | 对比配置里的 ID 和 Slack 里的 |
| requireMention 设置 | `#ops` 默认需要 @mention |

### not_in_channel 错误

Bot 没被邀请到目标频道。在频道里执行 `/invite @你的bot名`。

### A2A 派单后目标 Agent 没回复

这是已知问题（[KNOWN_ISSUES.md](KNOWN_ISSUES.md) P1）。当前最佳实践：

1. 确认目标 Agent 的频道 ID 和 binding 正确
2. 检查 `sessions_send` 的 sessionKey 是否包含正确的 thread ts
3. 如果偶发，Agent 通常会在下次消息时恢复

### zsh 中变量展开问题

在 zsh 里，双引号内的 `$variable` 会被展开。用单引号包裹含 `$` 的参数。

### 权限不足

```bash
# 检查目录权限
ls -la ~/.openclaw/
# 修复
sudo chown -R $USER ~/.openclaw/
```

---

## 常用命令速查

```bash
# 系统状态
openclaw status
openclaw gateway status
openclaw gateway restart

# Agent 管理
openclaw agents list

# 配置查询
openclaw config get agents
openclaw config get slack.channels

# 日志
openclaw logs tail -f
```

---

## 部署后的下一步

1. **先用 3 个 Agent 跑几天**，感受协作节奏
2. **观察 Closeout 产出**——CTO 和 Builder 是否在写结构化总结？
3. **按需添加 KO/Ops**——当你觉得"经验在丢失"或"Agent 行为在变"的时候
4. **阅读[核心概念](CONCEPTS.md)**——深度理解系统的运转逻辑
5. **读[开发历程](JOURNEY.md)**——了解每个设计决策背后的"为什么"

---

> 📖 下一步 → [核心概念详解](CONCEPTS.md) · [架构设计](ARCHITECTURE.md) · [自定义 Agent](CUSTOMIZATION.md)
