commit 7e825263db36aef68792a050c324daef598b4c56
Author: Alex's Mac <alexmac@AlexsdeMac-mini-2.local>
Date:   Sat Mar 28 17:38:48 2026 +0800

    feat: add A2A v2 research harness, architecture, and agent definitions
    
    Multi-agent harness for researching and designing A2A v2 protocol:
    
    Research reports (Phase 1):
    - Slack: true multi-agent collaboration via multi-account + @mention
    - Feishu: groupSessionScope + platform limitation analysis
    - Discord: multi-bot routing + Issue #11199 blocker analysis
    
    Architecture designs (Phase 2):
    - A2A v2 Protocol: Delegation (v1) + Discussion (v2) dual-mode
    - 5 collaboration patterns: Architecture Review, Strategic Alignment,
      Code Review, Incident Response, Knowledge Synthesis
    - 3-level orchestration: Human → Agent → Event-Driven
    - Platform configs, migration guides, 6 ADRs
    
    Agent definitions for Claude Code Agent Teams:
    - researcher.md, architect.md, doc-fixer.md, qa.md
    
    QA verification: all issues resolved, PASS verdict after fixes.
    
    Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>

diff --git a/.harness/reports/architecture_protocol_r1.md b/.harness/reports/architecture_protocol_r1.md
new file mode 100644
index 0000000..6afaa80
--- /dev/null
+++ b/.harness/reports/architecture_protocol_r1.md
@@ -0,0 +1,885 @@
+# A2A 协作协议 v2（跨平台多 Agent）
+
+> **版本**: v2.0-draft | **日期**: 2026-03-27 | **作者**: Architecture Agent
+>
+> 目标：统一 Slack / Feishu / Discord 三平台的 Agent-to-Agent 协作，同时支持：
+> - **Delegation（委派模式）**：结构化任务包 + `sessions_send` 触发（v1 继承，全平台可用）
+> - **Discussion（讨论模式）**：@mention 驱动的多方对话（v2 新增，Slack 立即可用，Discord 待修复）
+>
+> 设计原则：
+> 1. 单 bot 用户不受破坏（向后兼容）
+> 2. 多 bot 解锁新能力（渐进增强）
+> 3. 不同平台不同能力（平台感知）
+> 4. 两种模式共存，互补而非替代
+
+---
+
+## 0. 术语 Terminology
+
+| 术语 | 定义 |
+|------|------|
+| **A2A** | Agent-to-Agent 协作流程总称，包含 Delegation 和 Discussion 两种模式 |
+| **Delegation（委派）** | v1 模式。Agent-A 构造完整任务包，通过 `sessions_send` 触发 Agent-B 执行。单向、结构化、全平台可用 |
+| **Discussion（讨论）** | v2 模式。多个 Agent 在同一 thread/topic 中通过 @mention 参与多方对话。多向、自然语言、平台受限 |
+| **Task Thread** | 在目标 Agent 的频道/群组/channel 里创建的任务线程。该线程即该任务的独立 Session |
+| **Anchor Message（锚点消息）** | 在目标频道发布的可见 root message，作为任务的人类审计入口 |
+| **Multi-Account（多账户）** | OpenClaw 特性：每个 Agent 使用独立的 bot app（独立 token/identity/quota） |
+| **Cross-Bot Visibility（跨 bot 可见性）** | 平台层面：Bot-A 的消息是否能被 Bot-B 的事件处理器接收 |
+| **Self-Loop Filter（自循环过滤）** | OpenClaw 层面：忽略"自己发出的消息"以防止无限循环 |
+| **Session Key** | OpenClaw 用于标识一次对话会话的唯一键，格式因平台和配置而异 |
+| **Turn** | 一次 Agent 响应周期。Discussion 模式中由 @mention 触发，Delegation 模式中由 `sessions_send` 触发 |
+| **Orchestrator** | 控制讨论节奏的角色（人类或指定 Agent），决定下一个发言者 |
+
+---
+
+## 1. 权限矩阵 Permission Matrix（必须遵守）
+
+> 本节与 v1 完全一致。技术上 bot 可以给任意频道发消息，但这是组织纪律，不遵守视为 bug。
+
+| 角色 | 可派单/发起讨论 | 约束 |
+|------|----------------|------|
+| CoS | CTO（默认不直达 Builder） | 方向对齐、战略决策 |
+| CTO | Builder / Research / KO / Ops | 技术决策、任务分解 |
+| Builder | 不主动派单；需澄清时回 CTO thread | 执行、实现 |
+| CIO | 尽量独立；必要时与 CoS/KO 同步 | 领域专长 |
+| KO/Ops | 通常不主动派单 | 审计、沉淀 |
+
+**v2 补充（Discussion 模式）**：
+- Discussion 中的 @mention 也必须遵守权限矩阵。Builder 不应 @mention CoS 发起战略讨论。
+- Orchestrator（通常是发起讨论的角色或 CTO）控制 @mention 顺序，间接执行权限。
+- Agent SOUL.md/AGENTS.md 中须写明："在 Discussion 中只回应自己被 @mention 的消息，不主动跨域发言。"
+
+---
+
+## 2. 触发模式 Trigger Modes
+
+### 2a. Delegation Mode（委派模式 -- v1 继承）
+
+> 全平台可用。适用于：结构化任务委派、需要完整任务包的执行型工作。
+
+**触发流程（三步）**：
+
+#### Step 1 -- 创建可见锚点消息 Anchor Message
+
+A 在 B 的频道/群组创建 root message，第一行固定前缀：
+
+```
+A2A <FROM>-><TO> | <TITLE> | TID:<YYYYMMDD-HHMM>-<short>
+```
+
+正文必须是完整任务包（使用 `SUBAGENT_PACKET_TEMPLATE.md`）：
+- Objective / DoD / Inputs / Constraints / Output format / CC
+
+> 前置条件：bot 必须已加入目标频道/群组。Slack 报 `not_in_channel`；Feishu 需手动拉 bot 进群；Discord 需 bot 有 View Channel 权限。
+
+#### Step 2 -- `sessions_send` 触发目标 Agent
+
+A 读取 root message 的消息 ID，拼出 thread/topic sessionKey：
+
+| 平台 | Session Key 格式 |
+|------|-----------------|
+| Slack | `agent:<B>:slack:channel:<channelId>:thread:<root_ts>` |
+| Feishu | `agent:<B>:feishu:group:<chatId>:topic:<root_id>` （需 `groupSessionScope: "group_topic"`） |
+| Discord | `agent:<B>:discord:channel:<channelId>` （thread 继承父 channel） |
+
+然后 A 用 `sessions_send(sessionKey=..., message=<完整任务包>)` 触发 B。
+
+> **timeout 容错**：`sessions_send` 返回 timeout 不等于没送达。消息可能已送达并被处理。
+> 规避：在 thread 里补发兜底消息。
+>
+> **SessionKey 注意**：不要手打。优先从 `sessions_list` 复制 `deliveryContext` 匹配的 key。注意大小写一致性。
+
+#### Step 3 -- 执行与汇报
+
+- B 的执行与产出都留在该 thread/topic。
+- 上游（如 CTO）在自己的协调 thread 里同步 checkpoint/closeout。
+- 完成后必须 closeout（见第 4 节）。
+
+### 2b. Discussion Mode（讨论模式 -- v2 新增）
+
+> 仅在支持跨 bot 可见性的平台可用。适用于：多方讨论、设计评审、头脑风暴。
+
+**前提条件**：
+1. Multi-Account 已配置（每个参与讨论的 Agent 有独立 bot app）
+2. 共享频道配置了 `allowBots: true`（或 `"mentions"`）+ `requireMention: true`
+3. 平台支持跨 bot 消息可见性（见 2c 平台能力矩阵）
+
+**触发流程（单步）**：
+
+#### Step 1 -- 在共享 thread 中 @mention 目标 Agent
+
+Orchestrator（人类或指定 Agent）在 thread 中发送包含 @mention 的消息：
+
+```
+@CTO 这个架构方案的可行性如何？请从技术角度评估。
+```
+
+目标 Agent 的 bot 收到 mention 事件，加载 thread history 作为上下文，然后响应。
+
+#### Step 2 -- 多轮迭代
+
+Orchestrator 根据回复决定下一步：
+- @mention 另一个 Agent 获取不同视角
+- @mention 同一个 Agent 追问
+- 人类直接介入修正方向
+- 达成共识后总结并结束讨论
+
+**关键配置**：
+- `thread.historyScope: "thread"` -- 确保 Agent 看到完整 thread 历史
+- `thread.initialHistoryLimit >= 50` -- 讨论可能较长，需要足够历史
+- `thread.inheritParent: true` -- thread 参与者继承 root message 上下文
+
+**Discussion 专用规则**：
+- 每个 Agent 只在被 @mention 时响应（`requireMention: true` 强制）
+- 响应格式：`[角色] 内容...`（与 Delegation 模式保持一致的审计格式）
+- Agent 不得在 Discussion 中自行 @mention 其他 Agent，除非其 SOUL.md 明确授权为 Orchestrator
+- 讨论必须有明确的发起者和终止者（通常是同一个角色）
+
+### 2c. 平台能力矩阵 Platform Capability Matrix
+
+| 能力 | Slack | Discord | Feishu |
+|------|-------|---------|--------|
+| **Multi-Account** | YES | YES (PR #3672) | YES (已知 bug #47436) |
+| **跨 bot 消息可见性** | YES (Events API) | YES (MESSAGE_CREATE) 但 OpenClaw 过滤 (#11199) | NO (平台限制) |
+| **Delegation Mode** | YES | YES | YES |
+| **Discussion Mode** | **YES (NOW)** | **BLOCKED** (待 #11199 修复) | **NO** (平台不支持) |
+| **Self-loop 隔离** | 每 bot 独立 user ID | 全局过滤所有配置 bot (bug) | N/A (bot 消息不触发事件) |
+| **Thread/Topic 隔离** | `historyScope: "thread"` | Thread 继承 parent channel | `groupSessionScope: "group_topic"` |
+| **视觉身份** | 多 bot = 多身份 | 多 bot = 多身份 | 多 bot = 多身份 |
+
+**平台特性详解**：
+
+**Slack（能力最强）**：
+- Slack Events API 将所有频道消息投递给所有已加入的 bot app，不区分来源
+- OpenClaw 的 self-loop 过滤是 per-bot-user-ID：Bot-CTO 的消息不会被 Bot-Builder 过滤
+- `allowBots: true` + `requireMention: true` 即可实现安全的跨 bot 讨论
+- **一步触发 @mention 现在就能用**，无需代码修改
+
+**Discord（待修复后接近 Slack）**：
+- Discord MESSAGE_CREATE 事件在平台层面支持跨 bot 可见
+- **BLOCKER**: OpenClaw Issue #11199 -- bot 消息过滤器将所有已配置的 bot 视为"自己"，Bot-A 的消息被 Bot-B 的 handler 丢弃
+- 相关修复 PR: #11644, #22611, #35479（状态待确认）
+- 另有 Issue #45300: `requireMention` 在多账户配置下可能失效
+- **修复后**：Discord 的 Discussion 能力将与 Slack 接近
+
+**Feishu（仅支持 Delegation）**：
+- **平台硬限制**：`im.message.receive_v1` 事件仅对用户发送的消息触发，bot 消息对其他 bot 不可见
+- 这不是 OpenClaw 的问题，是飞书平台的设计
+- 两步触发（anchor + `sessions_send`）无法简化
+- Multi-Account 的价值：视觉身份、API 配额独立、权限隔离
+
+### 2d. 模式选择指南 Mode Selection Guide
+
+| 场景 | 推荐模式 | 原因 |
+|------|---------|------|
+| CTO 给 Builder 派具体任务 | Delegation | 结构化任务包，明确 DoD |
+| 架构方案多方评审 | Discussion (Slack) / Delegation chain (Feishu, Discord) | 多方观点汇聚 |
+| 紧急故障协同 | Discussion (Slack) / Human-in-loop (all) | 实时交互需求 |
+| 长期项目多阶段交付 | Delegation | 需要 checkpoint/closeout 完整链路 |
+| 知识整理、复盘 | Delegation (KO) | 结构化产出 |
+
+---
+
+## 3. 可见性契约 Visibility Contract
+
+> 用户必须能在聊天 UI 中看到所有关键信息。Agent 之间的内部通信（`sessions_send`）对用户不可见，因此必须有配套的可见性保证。
+
+### 3.1 基础可见性（全模式、全平台）
+
+1. **任务根消息可见**：每个任务的 anchor message 必须在目标频道可见
+2. **关键 checkpoint 可见**：开始/阻塞/完成 至少更新 1 次到 thread
+3. **上游负责到底**：谁派单谁在自己的协调 thread 跟进（避免用户跨频道"捞信息"）
+4. **双通道留痕**：
+   - A2A reply（给上游的结构化回复）-- 仅上游能看到
+   - Thread/topic message（给用户可见的审计日志）-- 用户能看到
+   - **两者都要做**
+
+### 3.2 Delegation 模式可见性
+
+- Step 1 的 anchor message 是用户的唯一入口
+- 所有执行过程在 anchor message 的 thread/topic 内进行
+- 完成后必须 closeout（见第 4 节 closeout 规则）
+- `sessions_send` 触发后，发送方应等待并验证 thread 内出现回复
+- 如果未收到回复，标记 `failed-delivery` 并上报
+
+### 3.3 Discussion 模式可见性（v2 新增）
+
+- Discussion 天然可见 -- 所有对话都在共享 thread 中，用户直接可读
+- 每个 Agent 的消息附带视觉身份（多 bot 模式下，各 bot 有独立头像/名称）
+- **Discussion 可见性优势**：
+  - 用户实时看到讨论过程，可随时介入
+  - 不存在 Delegation 中"A2A reply 对用户不可见"的问题
+  - Thread 本身即审计日志
+- **Discussion 可见性要求**：
+  - 讨论结束后，Orchestrator 必须在 thread 中发布结论摘要
+  - 如果 Discussion 产生了后续 Delegation 任务，必须在摘要中注明 TID 关联
+
+### 3.4 Multi-Bot 视觉身份
+
+| 平台 | 单 bot 模式 | 多 bot 模式 |
+|------|-----------|-----------|
+| Slack | 所有 Agent 共享一个 bot 名称/头像 | 每个 Agent 有独立 Slack app 身份 |
+| Feishu | 所有 Agent 共享一个飞书应用身份 | 每个 Agent 有独立飞书应用身份 |
+| Discord | 所有 Agent 共享一个 bot 身份 | 每个 Agent 有独立 Discord bot 身份 |
+
+多 bot 模式下的视觉身份不需要额外配置 -- 每个 bot app 的 profile（名称、头像）即是 Agent 身份。Slack 额外支持 `chat:write.customize` 做运行时身份覆盖，但多 bot 模式下不需要。
+
+---
+
+## 4. 多轮纪律 Multi-Round Discipline
+
+> 本节适用于 Delegation 和 Discussion 两种模式。
+
+### 4.1 Delegation 模式多轮规则（v1 继承）
+
+当 Delegation 任务需要多轮迭代时：
+
+- **每轮只聚焦 1-2 个改动点**，完成后**必须 WAIT**
+- **禁止一次性做完所有步骤** -- 等上游下一轮指令后再继续
+- 每轮输出格式固定：
+  ```
+  [<角色>] Round N/M
+  Done: <做了什么>
+  Run: <执行了什么命令>
+  Output: <关键输出，允许截断>
+  WAIT: 等待上游指令
+  ```
+- 最终轮贴 closeout 到 thread，A2A reply 中回复 `REPLY_SKIP` 表示完成
+
+#### Round0 审计握手（推荐）
+
+在正式 Round1 前，先做一个极小的真实动作验证审计链路：
+- 要求目标 Agent 执行一个无副作用命令（如 `pwd`）并把结果贴到 thread
+- **看不到 Round0 回传就停止** -- 说明 session 可能没绑定到正确的 deliveryContext
+
+### 4.2 Discussion 模式多轮规则（v2 新增）
+
+讨论模式的多轮控制更加关键 -- 没有控制的 Agent 讨论可能无限循环。
+
+**Orchestrator 控制原则**：
+- 每次只 @mention 一个 Agent（避免并发响应冲突）
+- 收到回复后，由 Orchestrator 决定下一步：继续讨论 / 切换 Agent / 结束
+- Orchestrator 可以是人类，也可以是指定 Agent（如 CTO 主持技术讨论）
+
+**讨论轮次上限**：
+- `maxDiscussionTurns`：建议值 = 5（Level 1 人工编排） / 8（Level 2 Agent 编排）
+- 达到上限后，Orchestrator 必须总结当前状态并决定：结束 / 转为 Delegation / 请人类介入
+- 此限制由 Orchestrator 在 SOUL.md/AGENTS.md 中自律执行（不是系统级强制）
+
+> 与 Delegation 的 `maxPingPongTurns = 4` 类似，Discussion 的轮次限制防止失控循环。
+> Delegation 的 `maxPingPongTurns` 是 OpenClaw 系统级参数；Discussion 的 `maxDiscussionTurns` 是协议级约定，由 Agent 自律。
+
+**Agent 响应规则**：
+- 只在被 @mention 时响应（`requireMention: true` 强制）
+- 响应必须包含明确的观点或建议（不允许"我同意"这样的空回复）
+- 如果 Agent 认为自己没有有价值的补充，应回复 `[角色] PASS: <一句话原因>`
+- 如果 Agent 认为讨论已达成共识，应在回复末尾标注 `CONSENSUS: <一句话共识>`
+
+**讨论结束协议**：
+- Orchestrator 发布 `DISCUSSION_CLOSE`：
+  ```
+  DISCUSSION_CLOSE
+  Topic: <讨论主题>
+  Consensus: <共识 / "未达成共识">
+  Actions: <后续 Delegation 任务列表，含 TID>
+  Participants: <参与 Agent 列表>
+  ```
+
+### 4.3 Closeout 规则（全模式通用）
+
+完成后必须 closeout（DoD 硬规则，缺一不可）：
+1. 在目标 Agent thread/topic 贴 closeout（产物路径 + 验证命令）
+2. **上游本机复核**（CLI-first）：至少执行关键命令 + 贴 exit code
+3. **回发起方频道汇报**：同步最终结果 + 如何验证 + 风险遗留。**不做视为任务未完成**
+4. 通知 KO 沉淀（默认：同步到 #know / KO 群组 + 触发 KO ingest）
+
+Discussion 模式的 closeout 等价物是 `DISCUSSION_CLOSE` 摘要。如果讨论产生了 Delegation 任务，各 Delegation 任务各自 closeout。
+
+---
+
+## 5. 频道/群组映射 Channel & Group Mapping
+
+### 5.1 标准映射
+
+| 角色 | Slack Channel | Feishu Group | Discord Channel |
+|------|--------------|-------------|----------------|
+| CoS | #hq | HQ 群 | #hq |
+| CTO | #cto | CTO 群 | #cto |
+| Builder | #build | Build 群 | #build |
+| CIO | #invest | Invest 群 | #invest |
+| KO | #know | Know 群 | #know |
+| Ops | #ops | Ops 群 | #ops |
+| Research | #research | Research 群 | #research |
+
+### 5.2 Discussion 专用频道（v2 新增，可选）
+
+多 bot Discussion 模式建议增设共享频道：
+
+| 频道 | 用途 | 参与 bot |
+|------|------|---------|
+| #collab / 协作群 / #collab | 跨域讨论（架构评审、方案对齐） | CoS, CTO, Builder, CIO |
+| #war-room / 战情群 / #war-room | 紧急事件协同 | 全部 |
+
+**共享频道配置要点**：
+- 所有参与 bot 必须加入该频道/群组
+- `requireMention: true` -- 防止所有 bot 同时响应
+- `allowBots: true` 或 `"mentions"` -- 允许 bot 看到其他 bot 的消息
+- 每个 Agent 对该频道的 binding 都需要显式配置
+
+### 5.3 Session Key 格式总览
+
+**Slack**：
+```
+# 频道级
+agent:<agentId>:slack:channel:<channelId>
+# Thread 级（推荐）
+agent:<agentId>:slack:channel:<channelId>:thread:<root_ts>
+# 多账户（accountId 不影响 session key 格式）
+```
+
+**Feishu**：
+```
+# 群组级（默认）
+agent:<agentId>:feishu:group:<chatId>
+# Topic 级（启用 groupSessionScope: "group_topic"）
+agent:<agentId>:feishu:group:<chatId>:topic:<root_id>
+```
+
+**Discord**：
+```
+# Channel 级
+agent:<agentId>:discord:channel:<channelId>
+# 多账户（session key 含 accountId）
+agent:<agentId>:discord:<accountId>:channel:<channelId>
+```
+
+### 5.4 并行规则
+
+- **一个任务 = 一个 thread/topic = 一个 session**
+- 同一个频道可以并行多个任务 thread/topic；不要在频道主线里混聊多个任务
+- Discussion 和 Delegation 可以在同一频道的不同 thread 中并行进行
+
+---
+
+## 6. 失败与回退 Failure & Fallback
+
+### 6.1 Delegation 失败回退
+
+| 故障 | 表现 | 回退方案 |
+|------|------|---------|
+| `sessions_send` timeout | 工具返回超时 | 不代表失败。在 thread 补发兜底消息；等待并检查回复 |
+| 目标 Agent 无响应 | Thread 中无 Round0 回传 | 停止后续步骤；标记 `failed-delivery`；检查 session key 和 deliveryContext |
+| Session 路由到 webchat | Agent 在跑但 thread 无可见输出 | Round0 审计握手可提前发现；重新检查 session key 大小写 |
+| bot 未加入频道 | `not_in_channel` / 发送失败 | 手动邀请 bot 进入频道/群组 |
+| Thread 行为异常 | 消息进错 thread 或不进 thread | 退回到"频道主线单任务"模式；或发 /new 重置 session |
+
+### 6.2 Discussion 失败回退
+
+| 故障 | 表现 | 回退方案 |
+|------|------|---------|
+| Agent 未响应 @mention | Thread 中无回复 | 检查 `allowBots` / `requireMention` 配置；检查 bot 是否已加入频道 |
+| Agent 响应了错误 thread | 回复出现在意外位置 | 检查 `thread.historyScope` 和 `inheritParent` 配置 |
+| 讨论进入死循环 | Agent 互相重复类似观点 | Orchestrator 强制 `DISCUSSION_CLOSE`；转为 Delegation |
+| 超出轮次上限 | 达到 `maxDiscussionTurns` | Orchestrator 总结并决定：结束 / 人类接管 / 拆分为子任务 |
+| 平台不支持 Discussion | Feishu；Discord 未修复 #11199 | 降级为 Delegation mode。用 `sessions_send` 串联多个 Agent 意见 |
+
+### 6.3 跨平台降级策略
+
+```
+Discussion Mode 可用？
+├── YES (Slack) → 使用 @mention 驱动讨论
+├── BLOCKED (Discord) → 降级为 Delegation chain
+│   └── Orchestrator 用 sessions_send 逐个征求 Agent 意见
+│       → 每个 Agent 的回复在共享 thread 中发布（可见性锚点）
+│       → Orchestrator 汇总后发布结论
+└── NO (Feishu) → 同上 Delegation chain 方案
+```
+
+---
+
+## 7. 平台配置片段 Platform Config Snippets
+
+### 7.1 Slack 配置（多账户 + Discussion 模式）
+
+```json
+{
+  "channels": {
+    "slack": {
+      "accounts": {
+        "default": {
+          "botToken": "xoxb-cos-...",
+          "appToken": "xapp-cos-...",
+          "name": "CoS"
+        },
+        "cto": {
+          "botToken": "xoxb-cto-...",
+          "appToken": "xapp-cto-...",
+          "name": "CTO"
+        },
+        "builder": {
+          "botToken": "xoxb-bld-...",
+          "appToken": "xapp-bld-...",
+          "name": "Builder"
+        }
+      },
+      "channels": {
+        "<HQ_CHANNEL_ID>": {
+          "allow": true,
+          "requireMention": false,
+          "allowBots": false
+        },
+        "<CTO_CHANNEL_ID>": {
+          "allow": true,
+          "requireMention": false,
+          "allowBots": false
+        },
+        "<BUILD_CHANNEL_ID>": {
+          "allow": true,
+          "requireMention": false,
+          "allowBots": false
+        },
+        "<COLLAB_CHANNEL_ID>": {
+          "allow": true,
+          "requireMention": true,
+          "allowBots": true
+        }
+      },
+      "thread": {
+        "historyScope": "thread",
+        "inheritParent": true,
+        "initialHistoryLimit": 50
+      }
+    }
+  },
+  "bindings": [
+    { "agentId": "cos",     "match": { "channel": "slack", "accountId": "default" } },
+    { "agentId": "cto",     "match": { "channel": "slack", "accountId": "cto" } },
+    { "agentId": "builder", "match": { "channel": "slack", "accountId": "builder" } }
+  ]
+}
+```
+
+**配置要点**：
+- 每个 Agent 专属频道：`requireMention: false`（该频道只有一个 bot 响应，无需 mention 门控）
+- 共享频道 #collab：`requireMention: true` + `allowBots: true`（多 bot 安全协作）
+- `thread.initialHistoryLimit: 50` -- Discussion 模式需要较大的历史窗口
+- 每个 Slack app 需要 Bot Token Scopes: `channels:history`, `channels:read`, `chat:write`, `users:read`
+- Event Subscriptions: `message.channels`, `app_mention`
+- Socket Mode: 每个 app 需要独立的 app-level token (`xapp-`)
+
+### 7.2 Feishu 配置（多账户 + Topic 隔离）
+
+```json
+{
+  "channels": {
+    "feishu": {
+      "domain": "feishu",
+      "connectionMode": "websocket",
+      "groupSessionScope": "group_topic",
+      "accounts": {
+        "cos-bot": {
+          "name": "CoS",
+          "appId": "cli_cos_xxxxx",
+          "appSecret": "your-cos-secret",
+          "enabled": true
+        },
+        "cto-bot": {
+          "name": "CTO",
+          "appId": "cli_cto_xxxxx",
+          "appSecret": "your-cto-secret",
+          "enabled": true
+        },
+        "builder-bot": {
+          "name": "Builder",
+          "appId": "cli_build_xxxxx",
+          "appSecret": "your-builder-secret",
+          "enabled": true
+        }
+      }
+    }
+  },
+  "bindings": [
+    {
+      "agentId": "cos",
+      "match": {
+        "channel": "feishu",
+        "accountId": "cos-bot",
+        "peer": { "kind": "group", "id": "<FEISHU_GROUP_ID_HQ>" }
+      }
+    },
+    {
+      "agentId": "cto",
+      "match": {
+        "channel": "feishu",
+        "accountId": "cto-bot",
+        "peer": { "kind": "group", "id": "<FEISHU_GROUP_ID_CTO>" }
+      }
+    },
+    {
+      "agentId": "builder",
+      "match": {
+        "channel": "feishu",
+        "accountId": "builder-bot",
+        "peer": { "kind": "group", "id": "<FEISHU_GROUP_ID_BUILD>" }
+      }
+    }
+  ]
+}
+```
+
+**配置要点**：
+- `groupSessionScope: "group_topic"` -- 核心配置，实现 topic 级 session 隔离
+- 每个群组只拉入对应的 bot（避免跨账户 dedup 竞争）
+- 建议使用"话题群"(topic group) 类型 -- 强制所有消息必须属于 topic，更契合 OpenCrew 工作流
+- **已知问题**：Issue #47436 -- 第二个账户使用 SecretRef 时 plugin crash。PR #47652 已提交修复。在合并前使用明文 secret 或等待 patch
+
+**Feishu 无法使用 Discussion 模式**：
+- 原因：`im.message.receive_v1` 仅对用户消息触发，bot 消息对其他 bot 不可见
+- 替代方案：所有跨 Agent 协作使用 Delegation（`sessions_send`）
+
+### 7.3 Discord 配置（多账户 + 频道权限隔离）
+
+```json
+{
+  "channels": {
+    "discord": {
+      "accounts": {
+        "default": {
+          "token": "BOT_TOKEN_COS"
+        },
+        "cto": {
+          "token": "BOT_TOKEN_CTO"
+        },
+        "builder": {
+          "token": "BOT_TOKEN_BUILDER"
+        }
+      }
+    }
+  },
+  "bindings": [
+    {
+      "agentId": "cos",
+      "match": {
+        "channel": "discord",
+        "accountId": "default",
+        "guildId": "<GUILD_ID>",
+        "peer": { "kind": "channel", "id": "<CHANNEL_ID_HQ>" }
+      }
+    },
+    {
+      "agentId": "cto",
+      "match": {
+        "channel": "discord",
+        "accountId": "cto",
+        "guildId": "<GUILD_ID>",
+        "peer": { "kind": "channel", "id": "<CHANNEL_ID_CTO>" }
+      }
+    },
+    {
+      "agentId": "builder",
+      "match": {
+        "channel": "discord",
+        "accountId": "builder",
+        "guildId": "<GUILD_ID>",
+        "peer": { "kind": "channel", "id": "<CHANNEL_ID_BUILD>" }
+      }
+    }
+  ]
+}
+```
+
+**Discord 频道权限隔离（必须配置）**：
+
+由于单 bot 模式下 Issue #34 的教训（cos/ops 对话混淆），**必须**配置频道权限隔离：
+
+1. 每个 bot 创建独立 Role（如 "CoS Bot", "CTO Bot", "Builder Bot"）
+2. Server 级权限：仅授予 View Channels + Read Message History，**不授予 Send Messages**
+3. 逐频道授权：
+   - #hq: "CoS Bot" role -> Allow Send Messages + Send Messages in Threads
+   - #cto: "CTO Bot" role -> Allow Send Messages + Send Messages in Threads
+   - #build: "Builder Bot" role -> Allow Send Messages + Send Messages in Threads
+4. **确保 bot role 没有 Administrator 权限**（否则所有 channel-level override 失效）
+
+**Thread 注意事项**：
+- Discord thread 会自动归档（默认 24h 无活动）
+- Bot 需要 Manage Threads 权限以 unarchive
+- 已完成任务的 thread 自然归档是可接受的行为
+
+**当前限制**：
+- Issue #11199 未修复前，Discussion 模式不可用
+- Issue #45300: `requireMention` 在多账户配置下可能失效
+- 所有跨 Agent 协作使用 Delegation（`sessions_send`）
+
+---
+
+## 8. 迁移指南 Migration Guide
+
+### 8.1 通用原则
+
+- **增量迁移**：一次只改一个 Agent，验证后再继续
+- **保留单 bot**：原有单 bot 配置作为 `default` 账户保留，新 bot 逐个添加
+- **可回滚**：每步都能通过恢复配置 + 重启 gateway 回退
+- **Session 注意**：多账户迁移可能导致 session key 格式变化，旧 session 可能孤立
+
+### 8.2 Slack 迁移：单 bot -> 多 bot
+
+**Phase 0 -- 准备（不影响运行）**
+
+1. 为每个需要独立身份的 Agent 创建新的 Slack app（参照 SLACK_SETUP.md）
+   - 建议先创建 3 个核心 app: CoS, CTO, Builder
+   - 配置 Bot Token Scopes, Event Subscriptions, Socket Mode
+2. 将新 bot 邀请进对应频道
+3. 备份当前 `openclaw.json`
+
+**Phase 1 -- 切换到多账户配置**
+
+1. 修改 `channels.slack` 从单 token 改为 `accounts` 格式：
+   ```json
+   // Before:
+   { "channels": { "slack": { "botToken": "xoxb-...", "appToken": "xapp-..." } } }
+
+   // After:
+   { "channels": { "slack": { "accounts": { "default": { "botToken": "xoxb-...", "appToken": "xapp-..." } } } } }
+   ```
+2. 添加 `accountId` 到 bindings
+3. 重启 gateway 验证：原有功能不受影响
+
+**Phase 2 -- 添加新 bot 账户**
+
+1. 逐个添加新 Agent 的账户到 `accounts`
+2. 更新对应 binding 的 `accountId`
+3. 每添加一个，重启验证
+
+**Phase 3 -- 启用 Discussion 模式**
+
+1. 创建 #collab 频道，邀请所有参与 bot
+2. 配置 #collab: `requireMention: true` + `allowBots: true`
+3. 为 #collab 频道添加每个 Agent 的 binding
+4. 测试：人类在 #collab 发帖，@mention 不同 Agent，验证各 Agent 独立响应
+
+**回滚**：任何阶段恢复备份 `openclaw.json` + 重启 gateway 即可回到单 bot 模式。
+
+### 8.3 Feishu 迁移：单 app -> 多 app + Topic 隔离
+
+**Phase 0 -- 启用 Topic 隔离（独立于多 app，可先做）**
+
+1. 在 `openclaw.json` 中添加 `groupSessionScope: "group_topic"`
+2. 重启 gateway
+3. 验证：在群组中创建 topic 发消息，检查 session key 包含 `:topic:` 后缀
+4. 注意：主线（非 topic）消息仍使用群组级 session key，向后兼容
+
+**Phase 1 -- 创建新飞书应用**
+
+1. 在飞书开放平台创建新应用（每个 Agent 一个）
+2. 配置事件订阅：`im.message.receive_v1`
+3. 启用 WebSocket 连接模式
+4. **注意 Bug #47436**：在 PR #47652 合并前，避免使用 SecretRef，改用明文 secret
+
+**Phase 2 -- 切换到多账户配置**
+
+1. 保留原 app 为 `legacy` 账户
+2. 逐个添加新账户 + 更新 binding
+3. 将新 bot 拉入对应群组（每个群组只需拉入对应 bot）
+4. 验证每个 Agent 在其专属群组正常响应
+
+**回滚**：恢复配置 + 重启。原 bot 保留在群组中，随时可切回。
+
+### 8.4 Discord 迁移：单 bot -> 多 bot + 权限隔离
+
+**Phase 0 -- 修复 Issue #34（单 bot 下也应做）**
+
+1. 创建 bot-specific role（如 "OpenCrew Bot"）
+2. Server 级：授予 View Channels + Read Message History，不授予 Send Messages
+3. 逐频道授权 Send Messages
+4. 验证：bot 只能在授权频道发送消息
+
+**Phase 1 -- 创建新 Discord bot**
+
+1. 在 Discord Developer Portal 创建新 Application（每个 Agent 一个）
+2. 启用 Message Content Intent
+3. 生成 bot token，邀请 bot 进 server
+4. 为每个 bot 创建独立 role 并配置频道权限
+
+**Phase 2 -- 切换到多账户配置**
+
+1. 修改 `channels.discord` 为 `accounts` 格式
+2. 原 token 作为 `default` 账户
+3. 逐个添加新账户 + binding
+4. 验证每个 Agent 在正确频道响应
+
+**Phase 3 -- 等待 Discussion 模式解锁**
+
+- 跟踪 Issue #11199 修复状态（PR #11644, #22611, #35479）
+- 修复合并后，配置 `allowBots: true` + `requireMention: true` 在共享频道
+- 测试跨 bot 可见性
+
+**回滚**：恢复配置 + 重启。移除新 bot 的频道权限即可。
+
+---
+
+## 9. 架构决策记录 Architecture Decision Records
+
+### ADR-001: 两种模式共存而非替代
+
+**Context**: A2A v1 使用 `sessions_send` 两步触发。Slack 多 bot 支持一步 @mention 触发。需要决定是否用 v2 替代 v1。
+
+**Decision**: 两种模式共存。Delegation（v1）用于结构化任务委派，Discussion（v2）用于多方讨论。
+
+**Consequences**:
+- (+) 向后兼容：单 bot 用户不受影响，仍使用 Delegation
+- (+) 渐进增强：多 bot 用户解锁 Discussion 作为额外能力
+- (+) 全平台覆盖：Feishu 只能用 Delegation，不被排除在外
+- (-) 认知负担：Agent 需要理解两种模式的适用场景
+- (-) 协议复杂度增加：SOUL.md/AGENTS.md 需要更多规则
+
+**Grounding**: Slack 研究确认 Discussion 模式仅需配置变更（no code changes）。Feishu 研究确认平台硬限制导致 Discussion 不可能。Discord 研究确认 Discussion 被 bug 阻断但修复后可用。三平台能力差异决定了不能用单一模式覆盖所有场景。
+
+### ADR-002: Orchestrator 控制讨论节奏而非自由讨论
+
+**Context**: Discussion 模式中，Agent 可以被动响应（等 @mention）或主动参与（看到相关消息就发言）。需要决定讨论模式。
+
+**Decision**: 采用 Orchestrator 控制模式。每次由人类或指定 Agent @mention 下一个发言者。Agent 只在被 @mention 时响应。
+
+**Consequences**:
+- (+) 防止 Agent 讨论失控循环
+- (+) 人类可随时介入控制节奏
+- (+) `requireMention: true` 在系统层面强制执行
+- (+) 轮次计数可控（`maxDiscussionTurns`）
+- (-) 无法实现完全自主的 Agent 圆桌讨论
+- (-) Orchestrator 成为瓶颈（每轮需等待 Orchestrator 决定下一步）
+
+**Grounding**: Slack 研究指出 Agent-orchestrated turn management 需要验证 mention-parsing 可靠性（Open Question #2）。人类控制是最安全的起步模式（Phase 1）。`maxPingPongTurns` 已证明轮次限制对防止循环的价值。
+
+### ADR-003: 共享频道而非 DM 进行 Discussion
+
+**Context**: 多 Agent 讨论可以在共享频道 thread（如 #collab）或通过 DM/私信进行。需要决定讨论场所。
+
+**Decision**: Discussion 必须在共享频道的 thread 中进行。不允许 Agent 间 DM 讨论。
+
+**Consequences**:
+- (+) 用户可见性：所有讨论对用户透明
+- (+) 审计友好：thread 即审计日志
+- (+) 与 SYSTEM_RULES 一致："可见、可追踪、不串上下文"
+- (-) 需要创建额外的共享频道（如 #collab）
+- (-) 多 bot 都需要加入共享频道，增加配置工作量
+
+**Grounding**: SYSTEM_RULES.md 要求"通过结构化产物而非海量对话实现演化"。A2A_PROTOCOL v1 要求"用户必须能在频道里看到"。Discussion 在共享频道中天然满足这些要求。
+
+### ADR-004: `requireMention: true` 作为 Discussion 安全阀
+
+**Context**: 多 bot 在共享频道时，`allowBots: true` 意味着每个 bot 都能看到其他 bot 的消息。如果没有门控，所有 bot 可能同时响应同一条消息。
+
+**Decision**: 共享频道必须配置 `requireMention: true`。Agent 只响应 @mention 自己的消息。
+
+**Consequences**:
+- (+) 系统级循环防护（不依赖 Agent 自律）
+- (+) 用户/Orchestrator 精确控制哪个 Agent 参与
+- (+) 即使 Agent SOUL.md 规则被忽略，系统仍安全
+- (-) 无法实现"Agent 自主判断是否参与"的高级模式
+- (-) Discord Issue #45300 报告 `requireMention` 在多账户下可能失效
+
+**Grounding**: Slack 研究确认 `allowBots: true` + `requireMention: true` 是官方推荐的安全组合。OpenClaw 文档明确推荐此组合用于多 Agent 场景。
+
+### ADR-005: Feishu 采用 `groupSessionScope: "group_topic"` 实现 Session 隔离
+
+**Context**: Feishu 群组默认共享单一 session（P0 问题）。需要决定隔离方案。
+
+**Decision**: 使用 `groupSessionScope: "group_topic"`，每个 topic thread 获得独立 session key。
+
+**Consequences**:
+- (+) 直接解决 P0 session 共享问题
+- (+) 向后兼容：非 topic 消息仍使用群组级 session
+- (+) 与 Slack "thread = task = session" 模型对齐
+- (+) 纯配置变更，不改代码
+- (-) Session key 格式变化：`sessions_send` 时需要包含 topic 后缀
+- (-) 需要 OpenClaw >= 2026.2（PR #29791）
+
+**Grounding**: Feishu 研究确认 `buildFeishuConversationId` 函数在 `group_topic` 模式下生成 `chatId:topic:topicId` 格式的 session key。PR #29791 已合并，功能可用。
+
+### ADR-006: Discord 频道权限隔离作为必须配置
+
+**Context**: Issue #34 暴露了单 bot 模式下缺少频道权限隔离导致对话混淆的问题。
+
+**Decision**: Discord 部署必须配置频道级 Send Messages 权限隔离，无论单 bot 还是多 bot。
+
+**Consequences**:
+- (+) 根治 Issue #34
+- (+) 多 bot 模式下每个 bot 天然隔离（只在自己频道有发送权限）
+- (+) 即使 OpenClaw binding 有 edge case，Discord 权限层提供兜底
+- (-) 配置步骤增加
+- (-) bot role 不能有 Administrator 权限（否则 override 失效）
+
+**Grounding**: Discord 研究确认 Issue #34 root cause 是 "single-bot + missing channel permission overrides"。Reporter 自己确认了解决方案。
+
+---
+
+## Appendix A: Discussion 模式分阶段上线路线图
+
+```
+Phase 1 -- Human Orchestrated (NOW, Slack only)
+├── 人类在 #collab thread 中 @mention Agent
+├── Agent 响应后，人类决定下一步
+├── 最安全，零协议风险
+└── 验证点：各 Agent 独立响应、thread history 正确加载
+
+Phase 2 -- Agent Orchestrated (NEAR, Slack only)
+├── CTO/CoS 在 SOUL.md 中被授权为 Orchestrator
+├── Orchestrator Agent 可以 @mention 其他 Agent
+├── maxDiscussionTurns = 8 作为安全阀
+└── 验证点：Orchestrator mention 被目标 Agent 正确识别
+
+Phase 3 -- Cross-Platform (FUTURE, Slack + Discord)
+├── Discord Issue #11199 修复后启用
+├── 统一 Discussion 协议在 Slack 和 Discord
+└── Feishu 保持 Delegation-only（平台限制）
+
+Phase 4 -- Proactive Mode (EXPLORATION)
+├── Agent 不需要 @mention 即可判断相关性并参与
+├── 需要 allowBots: "mentions" → allowBots: true 升级
+├── 需要 Agent 端的 relevance filtering
+└── 参考：SlackAgents (EMNLP 2025) proactive mode
+```
+
+## Appendix B: 与 Anthropic Harness 模式对比
+
+| 维度 | Harness（文件协作） | OpenCrew Delegation（消息协作） | OpenCrew Discussion（讨论协作） |
+|------|--------------------|-----------------------------|-------------------------------|
+| 通信介质 | 磁盘文件 | `sessions_send` 内部消息 + thread 锚点 | Thread 消息（直接在聊天 UI） |
+| 持久性 | Git 可追踪 | Session 内存 + thread 日志 | Thread 日志 |
+| 结构化 | 高（sprint contract, spec 文件） | 高（任务包模板、closeout 模板） | 中（自然语言 + 格式约定） |
+| 延迟 | ~0（本地文件系统） | ~1-3s（内部 RPC + 平台 API） | ~1-3s（平台 API） |
+| 人类可见性 | 需要主动检查文件 | Thread 可见但需跟踪多频道 | **天然可见**（讨论就在 UI 中） |
+| 上下文窗口 | 完整文件内容 | Session history | Thread history（`initialHistoryLimit`） |
+| 轮次管理 | Harness 代码控制 | `maxPingPongTurns` | Orchestrator + `maxDiscussionTurns` |
+| 对抗式审查 | Generator vs Evaluator | 无内建（由上游人工审查） | **天然支持**（多 Agent 在同一 thread 辩论） |
+
+**结论**：Delegation 适合执行型任务（Builder 写代码），Discussion 适合决策型任务（架构评审、方案对齐）。两者与 Harness 模式互补而非竞争 -- Harness 适合纯自动化 CI 管线，OpenCrew 适合需要人类参与和可见性的组织协作。
+
+## Appendix C: 配置 Quick Reference
+
+### 最小配置（单 bot，仅 Delegation）
+
+```json
+{
+  "channels": {
+    "slack": { "botToken": "xoxb-...", "appToken": "xapp-..." }
+  }
+}
+```
+
+### 推荐配置（多 bot，Delegation + Discussion）
+
+见第 7 节各平台配置片段。
+
+### 关键配置参数速查
+
+| 参数 | 值 | 用途 | 适用平台 |
+|------|-----|------|---------|
+| `allowBots` | `false` / `true` / `"mentions"` | 控制 bot 消息是否被处理 | Slack, Discord |
+| `requireMention` | `true` / `false` | 要求 @mention 才触发 Agent | Slack, Discord |
+| `thread.historyScope` | `"thread"` | Thread 级历史隔离 | Slack |
+| `thread.inheritParent` | `true` / `false` | Thread 是否继承 root message 上下文 | Slack |
+| `thread.initialHistoryLimit` | 数字 | Agent 加载的历史消息数 | Slack |
+| `groupSessionScope` | `"group"` / `"group_topic"` / `"group_sender"` / `"group_topic_sender"` | 群组 session 隔离粒度 | Feishu |
+| `maxPingPongTurns` | 数字 | Delegation A2A 最大往返轮数 | 全平台 |
+| `maxDiscussionTurns` | 5 (Level 1) / 8 (Level 2)（协议约定，非系统参数） | Discussion 最大 Agent 响应次数 | Slack (Discord future) |
