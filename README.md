**中文** | [English](README.en.md)

# OpenCrew - 高效协同、稳定迭代的Openclaw团队

> 适合所有人易上手的多智能体操作系统。
> 把你的 OpenClaw 变成一支可管理的 AI 团队——领域专家各司其职，经验自动沉淀，Slack 就是你的指挥中心。

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Built on OpenClaw](https://img.shields.io/badge/Built_on-OpenClaw-purple)](https://github.com/openclaw/openclaw)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](#参与贡献)

---

## 目录

- [这个项目解决什么问题](#这个项目解决什么问题)
- [架构一览](#架构一览)
- [10 分钟上手](#10-分钟上手)
- [核心概念速览](#核心概念速览)
- [文档导航](#文档导航)
- [已稳定 vs 探索中](#已稳定-vs-探索中)
- [常见问题](#常见问题)
- [参与贡献](#参与贡献)
- [开发历程](#开发历程)

---

## 这个项目解决什么问题

如果你在用 OpenClaw，你大概率已经遇到了这些问题：

| 你的痛点 | 根本原因 | OpenCrew 怎么解 |
|---------|---------|----------------|
| 聊着聊着 Agent 变"迟钝"了 | 一个 Agent 承担所有领域，上下文膨胀 | 多个 Agent 各管各的领域，互不污染 |
| 多项目并行，来回切 session | 没有可视化的任务总览 | Slack 频道=岗位，thread=任务，一目了然 |
| 每一步都要你确认，累 | Agent 不知道哪些该自主做 | 深度意图对齐 + 自主等级机制 |
| 踩过的坑下次还踩 | 经验散落在聊天记录里 | 三层知识沉淀：对话→结构化总结→可复用知识 |
| Agent 越用越"跑偏" | 自我调整没人审计 | 专职维护 Agent 负责审计和防漂移 |

**一句话总结**：问题不是 OpenClaw 不够强，而是一个 Agent 不够用。你需要的是一支团队。

---

## 架构一览

> 核心理解：**频道 = 岗位，Thread = 任务，#hq = Slack hq（headquarters）频道 **

![OpenCrew Architecture](docs/OpenCrew-Architecture-with-slack.png)

OpenCrew 分为三层，每层职责清晰：

| 层级 | 角色 | 职责 |
|------|------|------|
| **意图对齐** | 你 + CoS（幕僚长） | 定方向、验收结果。CoS 帮你对齐深层目标，你不在时代为推进。**CoS 不是网关，你想跟谁聊直接进哪个频道。** |
| **执行** | CTO / Builder / CIO / Research | CTO 拆解架构，Builder 实现，CIO 是可替换的领域专家（投资/法律/营销），Research 按需调研。 |
| **系统维护** | KO + Ops | KO 从产出中提炼可复用知识；Ops 审计变更、防止漂移。不做业务，只维护系统健康。 |

> 最小可用：CoS + CTO + Builder（3 个 Agent 就能跑起来）。KO/Ops/CIO/Research 按需添加。

### 实际运行效果

<table>
<tr>
<td width="33%"><img src="assets/screenshots/mac-1.jpg" alt="多频道协作总览"><br><sub><b>多频道协作总览</b>：频道=岗位，帖子=session</sub></td>
<td width="33%"><img src="assets/screenshots/mac-4-search.jpg" alt="Slack 搜索"><br><sub><b>Slack 搜索</b>：跨对话或指定频道快速搜索</sub></td>
<td width="33%"><img src="assets/screenshots/mobile-1.jpg" alt="未读列表（移动端）"><br><sub><b>未读列表</b>：高效处理未读信息（A2A 指派）</sub></td>
</tr>
</table>

> 更多截图 → [截图展示](docs/SCREENSHOTS.md)

---

## 10 分钟上手

> 前提：你已经能正常使用 OpenClaw（`openclaw status` 能跑通），且 Slack 已接入。
> 如果 Slack 还没接入，先看 → [Slack 接入指南](docs/SLACK_SETUP.md)（约 20 分钟）

### Step 1：创建 Slack 频道 + 邀请 bot

在你的 Slack 工作区创建频道，然后在每个频道里 `/invite @你的bot名`：

| 频道 | Agent | 说明 |
|------|-------|------|
| `#hq` | CoS 幕僚长 | 你的主要对话窗口 |
| `#cto` | CTO 技术合伙人 | 技术方向和任务拆解 |
| `#build` | Builder 执行者 | 具体实现和交付 |

> 按需扩展：`#invest`（CIO）`#know`（KO）`#ops`（Ops）`#research`（Research）

### Step 2：让你的 OpenClaw 完成部署

把下面这段话发给你现有的 OpenClaw（替换 `<>` 里的内容）：

```
帮我部署 OpenCrew 多 Agent 团队。

仓库：请 clone https://github.com/AlexAnys/opencrew.git 到 /tmp/opencrew
（如果已下载，仓库路径：<你的本地路径>）

Slack tokens（请写入配置，不要回显）：
- Bot Token: <你的 xoxb- token>
- App Token: <你的 xapp- token>

我已创建以下频道并邀请了 bot：
- #hq → CoS
- #cto → CTO
- #build → Builder

请读仓库里的 DEPLOY.md，按流程完成部署。
不要改我的 models / auth / gateway 配置，只做 OpenCrew 的增量。
```

你的 OpenClaw 会自动完成：备份现有配置 → 复制 Agent 文件 → 获取 Channel ID → 合并配置 → 重启。

> 想手动部署？→ [DEPLOY.md](DEPLOY.md) 里有完整的手动命令

### Step 3：验证

在 Slack 里测试：

1. 在 `#hq` 发一句话 → CoS 回复 ✅
2. 在 `#cto` 发一句话 → CTO 回复 ✅
3. 在 `#cto` 让 CTO 派个任务给 Builder → `#build` 出现 thread，Builder 回复 ✅

> 详细的分步指南（含常见报错、排查清单）→ [完整上手指南](docs/GETTING_STARTED.md)

---

## 核心概念速览

OpenCrew 的运转靠几个关键机制。下面是 30 秒速览，详细说明见 → [核心概念详解](docs/CONCEPTS.md)

**自主等级（Autonomy Ladder）** — Agent 什么时候该自己做，什么时候必须问你

| 等级 | 含义 | 举例 |
|------|------|------|
| L0 | 只建议，不动手 | — |
| L1 | 可逆操作，直接做 | 写草稿、做调研、整理文档 |
| L2 | 有影响但可回滚，做完汇报 | 提 PR、改配置、写分析 |
| L3 | 不可逆操作，必须你确认 | 发布、交易、删除、对外发送 |

**任务分类（QAPS）** — 不同类型的任务，不同的处理规范

| 类型 | 含义 | 需要 Closeout？ |
|------|------|----------------|
| Q | 一次性问题 | 不需要 |
| A | 有交付物的小任务 | 需要 |
| P | 项目（多步骤、跨天） | 需要 + Checkpoint |
| S | 系统变更 | 需要 + Ops 审计 |

**A2A 两步触发** — Agent 之间怎么协作

因为所有 Agent 共用一个 Slack bot，bot 自己发的消息不会触发自己。所以跨 Agent 协作需要两步：先在目标频道发一条可见消息（锚点），再用 `sessions_send` 真正触发对方。细节见 → [A2A 协议](shared/A2A_PROTOCOL.md)

**三层知识沉淀** — 经验怎么从聊天记录变成组织资产

```
Layer 0: 原始对话（审计用，不直接复用）
Layer 1: Closeout（10-15 行结构化总结，压缩比 ~25x）
Layer 2: KO 提炼的抽象知识（原则 / 模式 / 踩坑记录）
```

---

## 文档导航

### 给你（用户）看的

| 文档 | 内容 | 什么时候读 |
|------|------|-----------|
| **[完整上手指南](docs/GETTING_STARTED.md)** | 从零到跑通的详细步骤 + 常见问题 | 第一次部署 |
| **[核心概念详解](docs/CONCEPTS.md)** | 自主等级、QAPS、A2A、知识沉淀的完整说明 | 想深度理解系统 |
| **[架构设计](docs/ARCHITECTURE.md)** | 三层架构、设计取舍、为什么这么做 | 想理解设计思路 |
| **[自定义指南](docs/CUSTOMIZATION.md)** | 增删改 Agent、替换领域专家 | 想调整团队配置 |
| **[已知问题](docs/KNOWN_ISSUES.md)** | 系统的真实边界和当前最佳实践 | 遇到奇怪行为时 |
| **[开发历程](docs/JOURNEY.md)** | 从一个人的痛点到一支虚拟团队 | 想了解来龙去脉 |
| **[常见问题](docs/FAQ.md)** | 高频问答 | 快速查疑 |

### 给你的 Agent 看的（部署时 Agent 需要理解的）

| 文档 | 内容 | 谁读 |
|------|------|------|
| **[Agent 入职指南](docs/AGENT_ONBOARDING.md)** | Agent 首次启动时应读什么、怎么理解系统 | 新部署的 Agent |
| **shared/** 目录下所有文件 | 全局协议和模板（Agent 的"员工手册"） | 所有 Agent |
| 各 workspace 的 SOUL.md / AGENTS.md | 角色定义和工作流 | 对应 Agent |

---

## 已稳定 vs 探索中

### ✅ 已稳定运行

- 多 Agent 领域分工 + Slack 频道绑定
- A2A 两步触发（Slack 可见锚点 + sessions_send）
- Closeout / Checkpoint 强制结构化产物
- Autonomy Ladder（L0-L3）
- Ops Review 治理闭环
- Signal 评分 + KO 知识沉淀

### 🔄 探索中

- 更好的知识系统（跨 session 语义检索）
- 更轻量的架构（v2-lite：7 Agent → 5，9 个 shared 文件 → 3）
- Slack root message 独立 session 的更稳定方案

---

## 常见问题

**Q：我需要会写代码吗？**

不需要。OpenCrew 由一个经济学/MBA 背景的非技术用户设计和部署。你需要的是能敲几行命令行——或者直接让你现有的 OpenClaw 帮你执行部署命令。

**Q：最少需要几个 Agent？**

3 个：CoS + CTO + Builder。这是最小可用配置。当你发现经验在流失（加 KO）或系统在漂移（加 Ops）时再扩展。

**Q：和 CrewAI / AutoGen 这些框架有什么区别？**

那些是给开发者写代码用的 SDK。OpenCrew 是给决策者管团队用的系统——你通过 Slack 管理 AI 团队，不用写一行代码。它们解决"怎么编排 Agent"，OpenCrew 解决"怎么管理一支 AI 团队"。

**Q：不用 Slack 行不行？**

目前 Slack 是主要界面。架构设计围绕"频道=岗位、thread=任务"展开，Slack 的特性（thread 隔离、Unreads、手机端）天然匹配。其他平台在 roadmap 上。

**Q：会不会消耗很多 token？**

会比单 Agent 多，因为每个 Agent 有独立上下文。但 Closeout 机制（25x 压缩比）和领域隔离（每个 Agent 只看自己领域的信息）实际上让单次对话的 token 消耗更少。总量增加，但每个 Agent 的效率更高。

**Q：Slack 免费版够用吗？**

够用。OpenCrew 使用的 Slack API（Socket Mode）在免费版中完全可用。唯一限制是消息历史保留 90 天，但重要信息已经通过 Closeout 和知识库沉淀了。

更多问答 → [FAQ](docs/FAQ.md)

---

## 参与贡献

欢迎提 Issue / PR，尤其欢迎：

- 多 Agent 协作架构的改进建议
- 知识系统（检索/索引/记忆）的实践经验
- Slack thread / session 的稳定性优化思路
- 非 Slack 平台（Discord / Telegram / 飞书）的适配方案
- 英文文档的改进与扩展（[English docs](README.en.md) 已可用）

---

## 开发历程

这个项目由一个经济学/MBA 背景、非技术出身的 OpenClaw 用户独立开发。

从最初发现"一个 Agent 承担所有领域时上下文会膨胀"，到设计出 7 个 Agent 的协作架构，再到解决 A2A 循环风暴、deliveryContext 漂移等一系列技术挑战——完整的踩坑记录和设计决策见 → [开发历程](docs/JOURNEY.md)

**为什么现在开源？** 系统已经在真实使用中跑通并稳定迭代，但仍有未完全解决的边界问题。与其等到"完美"，不如先把可用框架公开，让更多使用者一起反馈、共建、进化。

---

## 目录结构

```
opencrew/
├── README.md                         ← 你在这里
├── DEPLOY.md                         ← 部署指南（精简版）
├── LICENSE                           ← MIT
├── shared/                           ← 全局协议和模板（所有 Agent 共享）
├── workspaces/                       ← 每个 Agent 的工作空间
├── docs/
│   ├── GETTING_STARTED.md            ← 完整上手指南
│   ├── CONCEPTS.md                   ← 核心概念详解
│   ├── ARCHITECTURE.md               ← 架构设计
│   ├── CUSTOMIZATION.md              ← 自定义指南
│   ├── AGENT_ONBOARDING.md           ← Agent 入职指南（给 Agent 读的）
│   ├── FAQ.md                        ← 常见问题
│   ├── KNOWN_ISSUES.md               ← 已知问题
│   ├── JOURNEY.md                    ← 开发历程
│   ├── SLACK_SETUP.md                ← Slack App 创建指南
│   └── CONFIG_SNIPPET_2026.2.9.md    ← 最小增量配置
├── patches/                          ← 高级 workaround（不推荐新手）
└── v2-lite/                          ← 精简版探索方向（实验性）
```

---

## 相关资源

- [OpenClaw 官方文档](https://docs.openclaw.ai/)
- [OpenClaw Slack 集成文档](https://docs.openclaw.ai/zh-CN/channels/slack)
- [OpenClaw Heartbeat 文档](https://docs.openclaw.ai/zh-CN/gateway/heartbeat)

---

## License

MIT
