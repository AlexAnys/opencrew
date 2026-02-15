# OpenCrew — 基于 OpenClaw 的多智能体协作框架

> 用 OpenClaw + Slack 搭建一支 AI 智能体团队，让不同领域的 Agent 专业分工、高效协同、稳定自主迭代、与你深度意图对齐，加速超级个体诞生

---

## 这个项目解决什么问题？

如果你正在使用 OpenClaw，你大概率遇到过这些痛点：

| 痛点 | 单 Agent 的现实 | OpenCrew 的解法 |
|------|----------------|----------------|
| **上下文膨胀** | 一个 Agent 处理所有事务，开发经验和理财经验混在一起，越用越糊 | 领域专业分工：多个 Agent 各管各的上下文 |
| **多 Session 切换低效** | 多个项目并行时，在不同 session 之间跳来跳去，无法高效追踪 | Slack 频道=岗位，thread=任务（session），一目了然 |
| **Agent 主动性受限** | 每一步都需要你确认，非关键判断也在等你 | 自主等级机制（L0-L3）：可逆操作自动推进，不可逆才找你 |
| **信息噪音** | 长对话后，有价值的经验淹没在聊天记录里 | 强制结构化产物（Closeout）+ Signal 评分过滤 |
| **经验不沉淀** | 踩过的坑下次还会踩，没有系统性的知识积累 | 三层知识沉淀：原始记录 → Closeout → 抽象知识（原则/模式/伤疤） |
| **系统漂移** | Agent 自我调整后行为不可预测，没人审计 | Ops + KO 两个非执行 Agent 专职维护系统健康 |

---

## 为什么现在开源？为什么是“轻量但完整”的版本？

OpenCrew 的起点非常简单：**当一个 Agent 同时承担太多领域（开发、投资、生活管理……）时，它的 profile 会不断膨胀**，上下文浪费变多、意图变模糊，结果反而更“迟钝”。

另一个洞察是：在长链任务里，**人往往是 loop 中最慢的部分**。AI 可以持续推进，但如果每一步都要人切换 session、分配任务、追踪进展，效率瓶颈仍然在人。

因此 OpenCrew 选择的不是“更强的单体 Agent”，而是一支**可管理的 AI 团队**：每个 Agent 专注自己的领域，用户只做方向与验收；协作过程尽量在 Slack 上显性可审计，靠结构化产物（Closeout/Checkpoint）沉淀可复用经验。

这次开源我们刻意选择 **“轻量但完整”**：
- ✅ **提供**：可运行的多 Agent 协作骨架（Slack=岗位、thread=任务、shared 机制、QAPS、L0-L3、自主推进、Closeout/Checkpoint、KO/Ops 的沉淀与治理）。
- ❌ **不提供**：强个性化偏好、特定行业的“最佳实践”硬编码、任何真实 token/ID（你应当按自己的情况改）。

为什么是现在：系统已经在真实使用中跑通并稳定迭代，**但仍有未完全解决的边界问题**（例如 Slack root message 的 session 隔离更优解、知识系统的跨 session 召回）。与其等到“完美”，不如先把可用框架公开，让更多使用者一起反馈、共建、进化。

---

## 架构一览（核心理解：频道=岗位，thread=任务/session）

> 架构图：
> - 预览（PNG）：[`docs/OpenCrew-Architecture-with-slack.png`](docs/OpenCrew-Architecture-with-slack.png)

![](docs/OpenCrew-Architecture-with-slack.png)

```text
  🤖 你原有的 OpenClaw Agent                        💬 Slack（通信基础设施）
  ┌─────────────────────┐                           ┌──────────────────────────┐
  │  独立共存            │  独立运行                  │ 📌 频道=岗位 Thread=Session│
  │  协助部署维护        │  协助用户维护               │    天然上下文隔离          │
  └─────────┬───────────┘       ↘                   │ 🧩 一个App分频道          │
            │                    ╔══════════════╗    │    Agent↔频道 即插即拔     │
            │(独立)              ║  OpenCrew    ║    │ 🔗 A2A跨频道显式输出      │
            │                    ╚══════════════╝    │    所有协作完全可审计      │
            │                                        │ 📥 Unreads/Later         │
  ╔═══════════════════════════════════════════════╗  │    决策待办一目了然        │
  ║                                               ║  │ 📝 草稿/已发送追踪        │
  ║  ┌─ ─ ─ ─ ─ ─ ─ 深度意图对齐层 ─ ─ ─ ─ ─ ┐  ║  │    Thread回溯完整链路      │
  ║  │                                         │  ║  │ 📱 手机端极佳优化          │
  ║    ┌──────────────┐     ┌──────────────┐      ║──│    碎片时间=管理时间       │
  ║  │ │ 👤 YOU       │ ──→ │ 💎 CoS 幕僚长│  │  ║  └──────────────────────────┘
  ║    │ 决策者        │     │ #hq          │      ║
  ║  │ │ 定方向·验收结果│     │ 深度意图对齐  │  │  ║
  ║    │ 代用户推进    │      └───┬──────┬───┘      ║
  ║  │  └──┬────────┬──┘       ┊代推进┊ ┊代推进┊  │  ║
  ║  └ ─ ─│─ ─ ─ ─ │─ ─ ─ ─┊─ ─ ─┊─┊─ ─ ─┊┘  ║
  ║       │        │        ┊     ┊ ┊     ┊      ║
  ║  ┌─ ─ ┼ ─ ─ ─ ─┼─ ─ ─ 执行层 ─ ─ ─ ─ ─ ┐  ║
  ║       ▼        ▼        ▼     ▼ ▼     ▼      ║
  ║  │ ┌──────────┐   ┌──────────────────┐   │  ║
  ║    │ 🛠 CTO   │   │ 📈 CIO [按需替换] │      ║
  ║  │ │ 技术合伙人│   │ #invest           │  │  ║
  ║    │ #cto     │   │ 可替换为其他专业分工│      ║
  ║  │ └────┬─────┘   └────────┬─────────┘│  ║
  ║         │                  │              ║
  ║  │      ▼                  ▼           │  ║
  ║    ┌──────────┐   ┌──────────────────┐    ║
  ║  │ │ 🧱Builder│   │ 🔎 Research [可选]││  ║
  ║    │ 执行者    │   │ 调研员·按需spawn  │    ║
  ║  │ │ #build   │   │ CTO/CIO均可调度  ││  ║
  ║    └──────────┘   └──────────────────┘    ║
  ║  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘  ║
  ║                                               ║
  ║  ┌╌╌╌╌╌ 系统维护层（← 所有Agent的产出）╌╌╌┐  ║
  ║  ╎  知识沉淀 · 可控迭代                    ╎  ║
  ║  ╎  ┌──────────────┐  ┌──────────────┐   ╎  ║
  ║  ╎  │ 🧠 KO 知识官  │  │ ⚙ Ops 运维官 │   ╎  ║
  ║  ╎  │ #know        │  │ #ops         │   ╎  ║
  ║  ╎  │ 沉淀经验      │  │ 审计变更      │   ╎  ║
  ║  ╎  │ 为可复用知识   │  │ 防止漂移      │   ╎  ║
  ║  ╎  └──────────────┘  └──────────────┘   ╎  ║
  ║  └╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌┘  ║
  ╚═══════════════════════════════════════════════╝
```

> 注：CIO/Research/KO/Ops 都是可选按需启用；最小可用是 CoS + CTO + Builder。

---

## 三层架构

**第一层：深度意图对齐层 — YOU + CoS**

你是决策者，定方向、验收结果。CoS（幕僚长）是你的战略伙伴——跟你对齐深层目标和价值判断，在你不方便时代为你推进任务给 CTO/CIO。

> CoS **不是网关、不必经**。你想聊技术直接进 #cto，想聊投资直接进 #invest，想跟谁聊就进哪个频道。

**第二层：执行层 — CTO / CIO / Builder / Research**

CTO 负责技术架构和拆解，Builder 负责具体实现（通常由 CTO 指派）。CIO 是领域专家（默认投资方向，可替换为法律、营销等任何领域）。Research 是按需 spawn 的调研员。

**第三层：系统维护层 — KO + Ops**

KO 负责从 closeout 中提炼可复用知识；Ops 负责审计系统变更、防漂移。**建议**对 #know / #ops 开启 `requireMention` 降噪（开源版默认关闭，先保证上手顺滑；后续可按需开启）。

---

## 全局 shared/ 机制（为什么它能在所有 Agent 生效）

OpenCrew 额外引入了一个 `~/.openclaw/shared/` 目录，放“全系统统一机制”。

它的作用是：**让所有 Agent 共享同一套协议/模板**，避免每个 workspace 各写一套导致漂移。

你会在本仓库的 `shared/` 看到这些文件（部署时复制到 `~/.openclaw/shared/`）：
- `SYSTEM_RULES.md`：Autonomy Ladder + Q/A/P/S + 产物要求
- `A2A_PROTOCOL.md`：跨频道协作的两步触发（可见锚点 + sessions_send）
- `TASK_PROTOCOL.md`：Task Card / Checkpoint / Closeout 规则
- `CLOSEOUT_TEMPLATE.md` / `CHECKPOINT_TEMPLATE.md`：结构化产物模板
- `OPS_REVIEW_PROTOCOL.md`：S 类变更的五维审计
- `KNOWLEDGE_PIPELINE.md`：closeout → KO → principles/patterns/scars
- `SUBAGENT_PACKET_TEMPLATE.md`：spawn 子任务的“任务包”（自包含）
- `SELF_UPDATE_TEMPLATE.md`：自我迭代记录（动机/变更/回滚）

> 这些文件不是“文档摆设”：它们会被各 Agent 的 `AGENTS.md` 作为工作流引用；
> 同时关键 guardrails 也会下沉到 OpenClaw 配置（A2A allowlist / pingpong 上限 / requireMention）。
>
> 实践建议：部署时把 `~/.openclaw/shared` 软链接到每个 `workspace-*/shared`（见 [DEPLOY.md](DEPLOY.md)），可以显著降低“shared 机制看起来没生效”的错觉。
## 核心机制（最小但够用）

### 自主等级（Autonomy Ladder）
- **L0**: 只建议，不行动
- **L1**: 可逆操作（草稿、研究、文档）→ 直接做
- **L2**: 有影响但可回滚（分支、PR、配置草案）→ 做完写 Closeout
- **L3**: 不可逆操作（发布、交易、删除、对外发送）→ **必须你确认**

### 任务分类（QAPS）
- **Q**: 一次性问题
- **A**: 交付物（必须 Closeout）
- **P**: 项目（Task Card + Checkpoint + Closeout）
- **S**: 系统变更（Ops Review + Closeout + 回滚）

### 知识三层沉淀
- Layer 0：原始对话记录（审计用）
- Layer 1：Closeout（10-15 行结构化总结）
- Layer 2：KO 抽象知识（Principles / Patterns / Scars）

---

## 10 分钟上手（Checklist，面向非技术用户）

> 你只需要记住一句话：**一个 Slack App + 多个频道（岗位） + thread（任务） + 多个 workspace（Agent 的“脑”）**。

### A. 如果你已经能用 OpenClaw + Slack（≈ 10 分钟）

- [ ] `openclaw status` 能正常运行
- [ ] 创建 3 个最小频道：`#hq` / `#cto` / `#build`
- [ ] 把 bot 邀请进频道：`/invite @<bot>`
- [ ] 拿到 3 个 Channel ID（右键频道 → Copy link → `C0...`）
- [ ] 把本仓库的 `shared/` + `workspaces/` 复制进 `~/.openclaw/`（或让你现有 OpenClaw 代你复制，见 DEPLOY）
- [ ] 按 `docs/CONFIG_SNIPPET_2026.2.9.md` 把最小增量合并进 `~/.openclaw/openclaw.json`
- [ ] `openclaw gateway restart`
- [ ] 验证：在 `#cto` 发一句话 → CTO 回复；让 CTO 派任务给 Builder → `#build` 出 thread

### B. 如果你还没把 Slack 接入 OpenClaw（≈ 20–40 分钟）

- [ ] 按 [`docs/SLACK_SETUP.md`](docs/SLACK_SETUP.md) 创建 Slack App（Socket Mode）并拿到 `xapp-...` + `xoxb-...`
- [ ] `openclaw channels add --channel slack --app-token "xapp-..." --bot-token "xoxb-..."`
- [ ] `openclaw gateway restart` 后再回到 A

---

## 快速开始（面向非技术用户：稳妥、可回滚）

OpenCrew 默认部署形态是：**一个 `.openclaw`、一个 Gateway、多 Agent、多 workspace**（类似你现有的 Ali + multi-agent 的关系），不会要求你“开多个 OpenClaw”。

### Step 1：把 Slack 接入 OpenClaw
- 只需要 **一个 Slack App**（后续增减 Agent 就是增减频道 + 配置绑定）
- 按 [`docs/SLACK_SETUP.md`](docs/SLACK_SETUP.md) 完成 Socket Mode 配置、拿到 token，并用 `openclaw channels add --channel slack ...` 连接

### Step 2：部署 OpenCrew（推荐让你现有 OpenClaw 代你部署）
- 按 [DEPLOY.md](DEPLOY.md) 操作
- 我们不提供“完整 openclaw.json”，只提供 **OpenClaw 2026.2.9 的最小增量 snippet**：
  - [`docs/CONFIG_SNIPPET_2026.2.9.md`](docs/CONFIG_SNIPPET_2026.2.9.md)

---

## 目录结构

```text
opencrew/
├── README.md
├── DEPLOY.md
├── LICENSE
├── shared/                      ← 全局协议和模板（所有 Agent 共享）
├── workspaces/                  ← 每个 Agent 的工作空间（SOUL/AGENTS/MEMORY 等）
├── docs/
│   ├── SLACK_SETUP.md           ← 新手：Slack App + OpenClaw 连接
│   ├── CONFIG_SNIPPET_2026.2.9.md ← 最小增量配置（可回滚）
│   ├── ARCHITECTURE.md
│   ├── CUSTOMIZATION.md
│   ├── KNOWN_ISSUES.md
│   └── JOURNEY.md
├── patches/                     ← 高级：可选 workaround（不推荐新手使用）
└── v2-lite/                     ← 精简版探索方向（实验性）
```

---

## 已解决 vs 探索中

### ✅ 已稳定运行
- 多 Agent 领域分工 + Slack 频道绑定
- A2A 两步触发（Slack 可见锚点 + sessions_send）
- Closeout/Checkpoint 强制结构化产物
- Autonomy Ladder (L0-L3)
- Ops Review 治理闭环
- Signal 评分 + KO 知识沉淀

### 🔄 探索中
- 更好的知识系统（跨 session 语义检索）
- 更轻量的架构（v2-lite）
- Slack “每条 root message 独立 session” 的更稳定解决方式（不改源码）

---

## 参与贡献

欢迎提 Issue / PR，尤其欢迎：
- 多 Agent 协作架构的改进建议
- 知识系统（检索/索引/记忆）实践
- Slack/线程/session 的稳定性优化思路

---

## License

MIT
