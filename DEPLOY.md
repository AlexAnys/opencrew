**中文** | [English](DEPLOY.en.md)

# 部署指南（精简版）

> **本文适合直接发给你的 OpenClaw，让它代你执行部署。** 完整的人工操作指南（含详细说明、常见报错、验证清单）见 → [完整上手指南](docs/GETTING_STARTED.md)
>
> 原则：**不依赖"一键脚本"**、不提供"完整 openclaw.json"，用最小增量 + 可回滚的方式，把 OpenCrew 加进你现有的 OpenClaw。

---

## 0. 前置要求（新手请按顺序做）

1. 你能正常运行 OpenClaw（本机）
   - 能执行：`openclaw status`
2. 你有一个 Slack workspace
3. 你准备使用 **一个 Slack App** 来管理所有 OpenCrew Agent（后续增减 Agent 就是增减频道 + 配置绑定）

如果你还没把 Slack 接入 OpenClaw：先完成 [`docs/SLACK_SETUP.md`](docs/SLACK_SETUP.md)。

---

## 1. 创建 Slack 频道（岗位）

建议先创建这 7 个频道（名字可自定义）：
- #hq（CoS）
- #cto（CTO）
- #build（Builder）
- #invest（CIO，可选，可替换为你的领域）
- #know（KO，建议开启 requireMention 降噪；开源版默认关闭，先保证跑通）
- #ops（Ops，建议开启 requireMention 降噪；开源版默认关闭，先保证跑通）
- #research（Research，可选，通常只 spawn）

然后把 bot 邀请进这些频道：`/invite @<bot>`。

---

## 2. 把 OpenCrew 文件放进你的 `~/.openclaw/`

你有两种方式：

### 方式 A（推荐）：让你现有的 OpenClaw 代你完成复制

把下面这段话发给你的 OpenClaw（你平时用的那个 Agent）：

```
我要部署 OpenCrew（多 Agent 协作框架）。请你按下面步骤在我的本机执行，并且每一步都告诉我你做了什么：

1) 读取我下载的 opencrew 仓库（路径：<填你的本地路径>）
2) 备份 ~/.openclaw/openclaw.json（带时间戳）
3) 把仓库里的 shared/*.md 复制到 ~/.openclaw/shared/
4) 把仓库里的 workspaces/<agent>/*.md 复制到 ~/.openclaw/workspace-<agent>/
   - 如果目录不存在就创建
   - 不要覆盖我已有的同名文件；如遇冲突先停下来问我
   - （推荐）为每个 workspace 创建软链接：~/.openclaw/workspace-<agent>/shared → ~/.openclaw/shared（若已存在则跳过）
5) 提醒我提供 Slack Channel ID，然后按 docs/CONFIG_SNIPPET_2026.2.9.md 把最小增量合并到 ~/.openclaw/openclaw.json
6) 重启 openclaw gateway，并验证 #cto/#hq 是否能正常响应

边界：不要改我的 models/auth/gateway 相关配置；只做 OpenCrew 的增量。
```

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

## 3. 写入最小增量配置（OpenClaw 2026.2.9）

请按这个文件操作：[`docs/CONFIG_SNIPPET_2026.2.9.md`](docs/CONFIG_SNIPPET_2026.2.9.md)

它包含：
- 需要新增的 agents（以及各自 workspace 路径）
- Slack 频道 bindings（频道=岗位）
- Slack allowlist（安全：只允许这些频道触发）
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
