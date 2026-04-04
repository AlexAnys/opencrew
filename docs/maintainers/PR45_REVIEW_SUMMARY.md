# PR #45 Review Summary — A2A v2 文档重构

> 供 Alex review 参考。梳理本轮需求、review 发现、以及最终改动。

---

## 一、需求来源

### 需求 1：配置方式通用化

**Alex 原话**：把独立引入 Slack bot 并拉到每台实例（Instance）等配置方式进行一般化处理，确保大家在不同环境、不同 Agent 下都能完成类似的配置。

**展开**：原有 `A2A_SETUP_GUIDE.md` 将"Ali-Bot"、"CoS"、具体 channel ID 等硬编码在文档中，其他用户无法直接参考。需要将配置流程抽象为参数化的 Agent 可执行指引——任何用户指定任意 agent、任意频道、任意新 Slack App 时，Agent 都能根据通用流程完成配置。

**核心要求**：
- 配置文档中不出现硬编码标识，全部用 `<ACCOUNT_ID>`、`<CHANNEL_ID>` 等占位符
- Agent 在修改配置前必须先读取当前 `openclaw.json`，了解用户现有环境（是否已有 accounts、有多少频道、什么 bindings）
- `accounts.default` 守卫必须是流程中的硬性门槛（不是一个 warning），带明确判断逻辑

### 需求 2：新旧 A2A 文档彻底分离

**Alex 原话**：在 README 中涉及新版 A2A 的文件里，一定要将新版的配置及描述与旧版区分开，不要混入旧版内容。否则用户会非常困惑。新版更新主要关注原生的 A2A 实现。

**展开**：PR #38 merge 后，`A2A_PROTOCOL.md`、`CONCEPTS.md`、`ARCHITECTURE.md` 中同时存在旧版 Delegation（sessions_send 两步触发）和新版 Discussion（@mention 原生协作）的内容，读者无法分辨哪些是当前推荐方案、哪些是历史遗留。

**核心要求**：
- v2 相关文件中只保留新版 Discussion 内容
- 旧版 Delegation 统一移到独立的附录或 section，明确标注"Legacy"
- `sessions_send` 在 v2 主文档中完全弃用
- Discord/Feishu 用户可指向旧版附录，但不在 v2 主流程中提及

---

## 二、Review 发现

对现有 A2A 相关文件逐一 review 后发现的问题：

### `A2A_PROTOCOL.md`（主协议文件）

| # | 问题 | 影响 |
|---|------|------|
| 1 | §2a Delegation Mode 占据主体篇幅 | 读者以为 sessions_send 是推荐方式 |
| 2 | §2.5 多轮 WAIT 纪律（Round0 握手、REPLY_SKIP） | 纯旧版概念，与 v2 无关 |
| 3 | TID 格式（`A2A FROM→TO \| TITLE \| TID:YYYYMMDD`） | 旧版任务标识，v2 不需要 |
| 4 | §1 权限矩阵（`tools.agentToAgent.allow`） | 围绕 sessions_send 设计，v2 用 requireMention + @mention |
| 5 | §5 Session Key 格式 | sessions_send 专用，v2 不需手动构造 |
| 6 | §3 可见性规则提及"A2A reply"和"双通道留痕" | 旧版概念 |

### `docs/A2A_SETUP_GUIDE.md`（配置指南）

| # | 问题 | 影响 |
|---|------|------|
| 1 | 硬编码 "Ali-Bot"、"CoS" 标识 | 其他用户无法直接参考 |
| 2 | 缺少 Step 0（读取当前 config） | Agent 不了解用户现状就改配置 |
| 3 | accounts.default 只是一个 warning | 容易被跳过 |
| 4 | Manifest 过度授权（21 个 scope） | 最小化原则 |
| 5 | 人工操作和 Agent 操作混合 | Agent 不知道哪些自己该做 |
| 6 | 没处理 accounts 已存在的情况 | 第二次添加独立 bot 时缺指引 |
| 7 | Binding 类型选择缺失 | 用户可能用错结构 |

### `docs/CONCEPTS.md`（核心概念）

| # | 问题 | 影响 |
|---|------|------|
| 1 | §4 标题"A2A 两步触发"——整个 section 围绕旧版 | 读者第一印象是 sessions_send |
| 2 | 防循环三层保护（maxPingPongTurns + agentToAgent.allow） | 全是旧版配置 |
| 3 | "Delegation vs Discussion" 并列对比 | 暗示两者等重，实际 v2 只推荐 Discussion |
| 4 | §9 配置层硬约束表仍列 `agentToAgent.allow` 和 `maxPingPongTurns` | 旧版配置项 |

### `docs/ARCHITECTURE.md`

| # | 问题 | 影响 |
|---|------|------|
| 1 | "A2A 两步触发机制"独立 section | 旧版核心叙述 |
| 2 | Session Key 结构说明 | sessions_send 专用 |
| 3 | 任务分派流中的"A2A →"箭头 | 暗示 sessions_send 路径 |

### 其他文件

| 文件 | 问题 |
|------|------|
| `CLOSEOUT_TEMPLATE.md` | TID 字段残留 |
| `SYSTEM_RULES.md` §7 | "必要时A2A：sessions_send 持续状态协作" |

---

## 三、最终改动（PR #45 各 commit）

### Commit 1: `fix: add A2A v2 architecture SVG`
- 新增架构图 SVG

### Commit 2: `refactor: A2A_SETUP_GUIDE — generalized agent-facing config guidance`
**对应需求 1（配置通用化）**

`docs/A2A_SETUP_GUIDE.md` 重写为三部分：
- **Part 1 (To Agent)**：参数化的 Agent 配置指引
  - 新增 Step 0：必须先读取当前 config
  - Step 2：accounts.default 守卫改为硬性门槛（带三种起始状态判断逻辑）
  - 新增 Binding 类型选择（account-level vs per-channel）
  - 所有标识参数化（`<ACCOUNT_ID>`、`<CHANNEL_ID>`）
- **Part 2 (Human)**：人工操作（精简 manifest，11 个最小 scope）
- **Part 3**：协作机制（两层防线 + @mention 协议）

### Commit 3: `refactor: clean separation of A2A v2 from legacy Delegation`
**对应需求 2（新旧分离）**

| 文件 | 改动 |
|------|------|
| `A2A_PROTOCOL.md` | Discussion 成为唯一 v2 模式（§1-7）；旧版 Delegation 整体移到**附录 C**，标注 Legacy |
| `CONCEPTS.md` (中文) | §4 从"A2A 两步触发"重写为"A2A — Agent 之间的原生协作"；删除 sessions_send、TID、权限矩阵、防循环三层；§8 shared/ 表格更新描述；§9 配置约束表替换为 allowBots/requireMention/accounts.default |
| `CONCEPTS.md` (英文) | 同步中文版改动 |
| `ARCHITECTURE.md` | "A2A 两步触发机制"替换为"A2A 原生协作"；任务分派流中 "A2A →" 改为 "@mention" |
| `SYSTEM_RULES.md` §7 | "必要时A2A：sessions_send" → "A2A（@mention 协作）" |
| `CLOSEOUT_TEMPLATE.md` | 移除 TID 字段 |

### Commit 4-5: README 更新
- 英文 README 同步中文
- A2A section 重构：Discussion 在前，旧版 Delegation 归档

### Merge commit: 冲突解决
- `README.md`：保留 main 的双图表格布局
- `A2A_PROTOCOL.md`：保留 v2 清洁版本（丢弃 main 上的旧版混合内容）

---

## 四、Review 建议

### 重点关注
1. **`A2A_PROTOCOL.md`** — 变动最大的文件。建议对照旧版确认：
   - 附录 C（Legacy Delegation）是否完整保留了旧版关键信息
   - §3 @mention 协议是否足够清晰
2. **`docs/A2A_SETUP_GUIDE.md` Part 1** — Agent 配置指引。建议确认：
   - Step 0-7 的流程是否覆盖了所有场景
   - accounts.default 守卫逻辑是否严谨

### 可快速过的
- `CLOSEOUT_TEMPLATE.md`：只删了 TID 一个字段
- `SYSTEM_RULES.md`：只改了 §7 三行
- README commits：Ali 的改动 + 冲突解决
