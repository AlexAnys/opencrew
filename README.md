# OpenCrew

> 用 OpenClaw + Slack 搭建一支 AI 团队：**专业分工、可审计协作、稳定迭代**。你负责方向与验收，其余交给团队推进。

## Start here

- **Slack 接入（先做这个）** → [`docs/SLACK_SETUP.md`](docs/SLACK_SETUP.md)
- **部署到本机**（复制 shared/ + workspaces/ + 建软链接）→ [`DEPLOY.md`](DEPLOY.md)
- **最小增量配置**（OpenClaw 2026.2.9）→ [`docs/CONFIG_SNIPPET_2026.2.9.md`](docs/CONFIG_SNIPPET_2026.2.9.md)
- **架构与工作方式** → [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)
- **已知边界 / Workarounds** → [`docs/KNOWN_ISSUES.md`](docs/KNOWN_ISSUES.md)
- **截图** → [`docs/SCREENSHOTS.md`](docs/SCREENSHOTS.md)

---

## Quickstart (≈ 10 minutes)

**你需要：**
- 本机已安装并能运行 OpenClaw：`openclaw status`
- 一个 Slack workspace（建议新建一套频道给 OpenCrew）

### 1) 创建最小频道

创建 3 个频道：`#hq` / `#cto` / `#build`，把你的 bot 邀请进频道（`/invite @<bot>`）。

> 可选频道：`#know`（KO）、`#ops`（Ops）、`#invest`（CIO）、`#research`（Research）。

### 2) 连接 Slack → OpenClaw

按 [`docs/SLACK_SETUP.md`](docs/SLACK_SETUP.md) 创建 Slack App（Socket Mode），然后：

```bash
openclaw channels add --channel slack --app-token "xapp-..." --bot-token "xoxb-..."
openclaw gateway restart
```

### 3) 部署 OpenCrew 文件（shared + workspaces + symlink）

按 [`DEPLOY.md`](DEPLOY.md) 把：
- `shared/*.md` → `~/.openclaw/shared/`
- `workspaces/<agent>/...` → `~/.openclaw/workspace-<agent>/...`
- 并推荐创建软链接：`~/.openclaw/workspace-<agent>/shared -> ~/.openclaw/shared`

### 4) 合并最小增量配置（安全可回滚）

按 [`docs/CONFIG_SNIPPET_2026.2.9.md`](docs/CONFIG_SNIPPET_2026.2.9.md) 把以下内容合并进你的 `~/.openclaw/openclaw.json`：
- 新增 agents（cos/cto/builder/ko/ops…）
- Slack bindings（频道=岗位）
- Slack allowlist（只允许这些频道触发）
- A2A 保护（allowlist + pingpong 上限）
- （默认开启）CoS + KO heartbeat（12h）

应用后：

```bash
openclaw gateway restart
openclaw status
```

### 5) 验证

1) 在 `#cto` 发一句话 → CTO 回复
2) 在 `#cto` 让 CTO 派一个实现任务给 Builder → `#build` 出现 thread，Builder 在 thread 内回复

---

## What problem does OpenCrew solve?

当你把"开发、投资、生活管理……"都塞进同一个 Agent：
- profile 会越来越厚，上下文浪费越来越多
- 意图更容易模糊，Agent 反而变慢
- 多项目并行时，你需要频繁切换 session，进展难追踪
- 长对话里有价值经验容易被淹没，系统会漂移且难审计

另一个洞察：在长链任务里，**人往往是 loop 中最慢的部分**。AI 可以持续推进，但如果每一步都要人切换 session、分配任务、追踪进展，效率瓶颈仍然在人。

OpenCrew 的核心解法：把"一个万能 Agent"拆成**一支可管理的团队**。

| 痛点 | 单 Agent 常见结果 | OpenCrew 的解法 |
|---|---|---|
| 上下文膨胀 | 不同领域经验混在一起 | **专业分工**：多个 Agent 各管各的上下文 |
| 多 Session 切换低效 | 进度分散、难追踪 | **Slack 频道=岗位，thread=任务/session** |
| 主动性受限 | 小事也要等人 | **自主等级 L0–L3**：可逆操作自动推进 |
| 信息噪音 | 关键结论沉没 | **结构化产物**：Checkpoint/Closeout |
| 经验不沉淀 | 踩坑重复发生 | **知识沉淀链路**：记录 → closeout → principles/patterns/scars |
| 系统漂移 | 改着改着不可信 | **KO + Ops**：沉淀与治理闭环 |

---

## How it works (mental model)

- **Slack 是通信基础设施**
  - `#channel = 岗位/角色`
  - `thread = 一次任务的 session（天然隔离上下文）`
- **OpenClaw 是执行与工具层**
  - 每个 Agent 对应一个 workspace（自己的记忆、协议、产物）
- **shared/ 是全系统协议层**
  - 所有 Agent 共享同一套规则/模板，避免漂移

### Key mechanisms

- **Autonomy Ladder (L0–L3)**：可逆自动推进，不可逆必须确认
- **Q/A/P/S 分类**：一次性问答 / 交付物 / 项目 / 系统变更（带审计与回滚）
- **A2A 两步触发**：Slack 可见锚点 + `sessions_send` 真正触发（可审计、可控）
- **KO / Ops**：把"协作产出"变成"可复用资产"，把"系统变更"变成"可治理演进"

---

## Architecture

- 预览图（PNG）：[`docs/OpenCrew-Architecture-with-slack.png`](docs/OpenCrew-Architecture-with-slack.png)
- 源文件（Excalidraw）：[`docs/OpenCrew-Architecture-with-slack.excalidraw`](docs/OpenCrew-Architecture-with-slack.excalidraw)

![](docs/OpenCrew-Architecture-with-slack.png)

> 最小可用：CoS + CTO + Builder。

### 三层架构

**深度意图对齐层 — YOU + CoS**

你是决策者，定方向、验收结果。CoS（幕僚长）跟你对齐深层目标和价值判断，在你不方便时代为你推进任务。

> CoS **不是网关、不必经**。你想聊技术直接进 #cto，想聊投资直接进 #invest。

**执行层 — CTO / CIO / Builder / Research**

CTO 负责技术架构和拆解，Builder 负责具体实现（通常由 CTO 指派）。CIO 是领域专家（默认投资方向，可替换为任何领域）。Research 按需 spawn。

**系统维护层 — KO + Ops**

KO 从 closeout 中提炼可复用知识；Ops 审计系统变更、防漂移。

---

## Repository layout

```text
opencrew/
├── README.md
├── DEPLOY.md
├── shared/                      # 全系统协议与模板（所有 Agent 共享）
├── workspaces/                  # 各 Agent 工作空间（SOUL/AGENTS/MEMORY/...）
├── docs/                        # 安装、配置、架构、已知边界
├── patches/                     # 高级：可选 workaround（默认不需要）
├── assets/                      # 图片/架构图/截图（请避免泄露隐私）
└── v2-lite/                     # 精简版探索（实验性）
```

---

## Why open source now?

OpenCrew 的起点很简单：**当一个 Agent 同时承担太多领域时，profile 不断膨胀**，上下文浪费变多、意图变模糊，Agent 反而更"迟钝"。

我们选择的不是"更强的单体 Agent"，而是一支**可管理的 AI 团队**：每个 Agent 专注自己的领域，用户只做方向与验收；协作过程在 Slack 上显性可审计，靠结构化产物沉淀可复用经验。

这次开源刻意选择 **"轻量但完整"**：
- ✅ **提供**：可运行的多 Agent 协作骨架（Slack=岗位、thread=任务、shared 机制、QAPS、L0-L3、Closeout/Checkpoint、KO/Ops 沉淀与治理）
- ❌ **不提供**：个性化偏好硬编码、真实 token/ID（你按自己情况改）

系统已经在真实使用中跑通并稳定迭代，但仍有边界问题需要在实践中打磨（例如 Slack root message 的 session 隔离、更好的跨 session 知识召回）。与其等"完美"，不如先把可用框架公开，一起反馈、共建、进化。

---

## Related resources

- OpenClaw Docs（Slack）：https://docs.openclaw.ai/zh-CN/channels/slack
- OpenClaw Docs（Heartbeat）：https://docs.openclaw.ai/zh-CN/gateway/heartbeat

---

## Contributing

欢迎提 Issue / PR。建议每次改动都附：
- 变更目的（why）
- 验证方式（how to verify）
- 回滚方式（rollback）

（维护者参考：[`docs/DECISIONS.md`](docs/DECISIONS.md)、`CHANGELOG.md`、`docs/maintainers/`）

---

## License

MIT
