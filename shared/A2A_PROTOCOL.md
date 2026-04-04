# A2A 协作协议 v2 — 原生 Agent 协作

> Agent 之间通过独立 Slack App + @mention 直接对话。
> 配置指南：[Discussion Mode 实操指南](../docs/A2A_SETUP_GUIDE.md)

---

## 1. 核心概念

### 什么是 A2A v2

OpenCrew 默认所有 Agent 共享一个 Slack App（一个 bot user）。这意味着 Agent 之间无法在 Slack 中直接对话——bot 自己发的消息会被自己忽略。

v2 的解决方案是**选择性独立化**：让少数 Agent 拥有独立 Slack App，然后拉进其他 Agent 的频道直接对话。

```
         独立 Slack App              共享 Slack App (现有)
         ┌──────────────┐           ┌─────────────────┐
         │ Orchestrator │           │   Default-Bot   │
         └──────┬───────┘           └───┬───┬───┬─────┘
                │                       │   │   │
频道：  #home  #cto  #build          #cto #build #invest ...
        ──────────────────────────────────────────────────
Agent：  Orch  ← 进入协作 →          CTO  Builder  CIO ...
```

### 术语

| 术语 | 含义 |
|------|------|
| **Discussion** | 多 Agent 在同一 Slack thread 中通过 @mention 进行实时协作 |
| **Orchestrator** | 控制讨论节奏、评估产出、决定终止的角色（融合 Planner + Evaluator） |
| **Worker** | 执行具体工作的 Agent（Generator），不自评通过 |
| **Multi-Account** | 同一 OpenClaw 实例管理多个独立 Slack App |
| **DISCUSSION_CLOSE** | 讨论终止标记 |

### 为什么要分离 Orchestrator 和 Worker

源自 Anthropic Harness Design 的核心洞察：

- 当一个 AI **既做执行又做 QA** 时，它倾向于宽容自己的错误
- 当一个 AI **既做规划又做执行** 时，它倾向于投机取巧

将"想"和"做"分给不同 Agent，是解决 AI 自评失效最有效的杠杆。

---

## 2. 技术原理

### 为什么能工作（源码验证）

1. **Self-loop 按 account 隔离**：每个 Slack App 有独立 `botUserId`，OpenClaw 只过滤来自自己的消息，不同 App 之间不互相过滤
2. **`allowBots: true`**：允许处理其他 bot 的消息（须在频道 config 中开启）
3. **Per-account channel config**：同一频道可以给不同 account 设置不同的 `requireMention`

### Thread 内的隐式触发问题

`requireMention: true` 只在 **Channel 根消息** 有效。一旦 bot 在 thread 中回复过，`implicitMention` 永远为 true，绕过 `requireMention`。

```js
// 源码：resolveMentionGating
implicitMention = !isDirectMessage && botUserId && message.thread_ts &&
    (message.parent_user_id === botUserId || hasSlackThreadParticipation(...))
```

### 两层防线

| 层级 | 机制 | 作用范围 | 类型 |
|------|------|----------|------|
| Config | `requireMention: true` | Channel 根消息 | 硬约束 |
| Prompt | 显式 @mention 协议 | Thread 内 | 软约束 |

---

## 3. @mention 协议

每个参与 Discussion 的 Agent 必须在 workspace 文件中包含此规则：

```markdown
## Multi-Agent Thread 协作规则

在 Slack thread 中如果有其他 bot 也在参与：

1. **收到消息时**：检查消息文本是否包含 `<@你的BotID>`。
   如果没有 → 整条回复只输出 `NO_REPLY`，不解释、不叙述。

2. **发送消息时**：`<@目标BotID>` 显式 mention 目标。
   不 @ 任何 bot = 对话终止信号。

3. **角色**：
   - Orchestrator：选择 @Worker / @Human / 不@（结束）
   - Worker：每次回复必须 @ Orchestrator

4. **终止**：说"完毕/done"后不再发送，除非被重新 @。

5. **轮次上限**：同一 thread 内最多 N 轮（建议 5-8），超过后暂停并向人类汇报。
```

---

## 4. 协作流程

```
Human → @Orchestrator: "讨论 X"

Phase 0（展开 spec）:
  Orchestrator → Thread: DISCUSSION SPEC
    - 目标
    - 验收标准（逐条列出）
    - 终止条件
    - 最大轮次
  Orchestrator → @Worker: 第一个问题

Round 1/M:
  Worker → @Orchestrator: 摘要（Thread）+ 📁 详细分析（文件）
  Orchestrator 评估 → 继续 @Worker / 终止

Round N/M:
  ...

终止（三选一）:
  ✅ 验收标准满足 → DISCUSSION_CLOSE
  ⚠️ 达到最大轮次 → 请人类介入
  🔄 连续 2 轮无进展 → 请人类介入
```

### 关键原则

1. **先 spec 再讨论**——Phase 0 定义验收标准，不能跳过
2. **文件是主通信通道**——Thread 只放摘要和 @mention 路由，详细内容写文件
3. **自评失效，必须分离**——Orchestrator 不生成方案，只协调和评估
4. **Orchestrator 默认太宽松**——需刻意严格，逐条对照标准判断

### 终止协议

讨论结束时，Orchestrator 发送：

```
DISCUSSION_CLOSE
Topic: <主题>
Consensus: <共识 / "未达成共识，原因：...">
Criteria Status:
  1. ✅/❌ <标准 1>: <状态>
  2. ✅/❌ <标准 2>: <状态>
Actions: <后续任务，含负责人>
Participants: <参与 Agent>
Rounds Used: N/M
```

---

## 5. 可见性

- 讨论发生在 Slack thread 中，用户可实时旁观
- 详细分析写文件，Thread 只放摘要
- Orchestrator 进入其他 Agent 的频道进行协作，无需创建共享频道
- 讨论结束后 DISCUSSION_CLOSE 留在 Thread 作为结论记录

---

## 6. 故障处理

| 故障 | 回退 |
|------|------|
| Agent 未响应 @mention | 检查 `allowBots` + `requireMention` 配置；确认 bot 已被邀请到频道 |
| 讨论死循环 | Orchestrator 强制 DISCUSSION_CLOSE；或人类介入 |
| 双响应（两个 bot 同时回复） | 检查 @mention 协议是否正确配置在 Agent workspace 中 |
| 新 bot 加入后原有 Agent 断连 | 检查 `accounts.default` 是否声明（见配置指南） |

---

## 7. 已知限制

1. **`allowBots: "mentions"` 仅 Discord 可用**：Slack provider 只做 truthy/falsy 检查，`"mentions"` 等同于 `true`
2. **`requireMention: true` 在 Thread 内被绕过**：`implicitMention` 会永久绕过。需 OpenClaw 增加 `thread.requireExplicitMention` 选项
3. **Input token 无法避免**：Thread 中所有消息都会送达所有 bot，NO_REPLY 不阻止 input token 消耗
4. **多账号 `accounts.default` 必须显式声明**：遗漏会导致全 Agent 断连（详见[配置指南](../docs/A2A_SETUP_GUIDE.md)）
5. **仅 Slack 支持**：Discord 因 OpenClaw bug（#11199、#45300）不可用；Feishu 因平台限制（bot 消息不投递给其他 bot）不可用

### 平台能力对比

| 能力 | Slack | Discord | Feishu |
|------|-------|---------|--------|
| A2A v2 Discussion | ✅ 已验证 | ❌ OpenClaw bug | ❌ 平台限制 |
| Multi-Account | ✅ | ✅ | ✅ |
| Thread 隔离 | ✅ 原生 | ✅ 自动归档 | ✅ groupSessionScope |

> Discord/Feishu 用户如需 Agent 间协作，可参考[旧版 A2A（附录 C）](#附录-c旧版-a2a-v1delegation-模式)。

---

## 附录 A：配置指南（精简版）

> 完整指南见 [A2A_SETUP_GUIDE.md](../docs/A2A_SETUP_GUIDE.md)。

### 人工操作

1. 创建独立 Slack App（使用配置指南中的 manifest）
2. 在目标频道 `/invite @Bot-Name`

### Agent 配置（参数化流程）

```
Step 0: 读取当前 openclaw.json，确认 accounts 状态
Step 1: 备份 config
Step 2: accounts.default 守卫（必须存在，否则停止）
Step 3: 添加新 account（含 channels: requireMention + allowBots）
Step 4: 目标频道全局 config 加 allowBots: true
Step 5: 添加 binding
Step 6: 等待热重载
Step 7: 验证日志（两个 provider + channels resolved + socket connected）
```

详细步骤和模板见 [A2A_SETUP_GUIDE.md](../docs/A2A_SETUP_GUIDE.md)。

---

## 附录 B：验证步骤

```
测试 1：基础消息传递
  - 人类 @mention 新 bot → 验证响应
  - 验证同频道原有 Agent 不会抢答

测试 2：Thread 内对话
  - 新 bot 在 thread 中 @mention 原有 Agent → 验证回复
  - 验证新 bot 收到回复（隐式 mention）→ 对话可持续

测试 3：终止控制
  - 设定 maxRounds → 验证 DISCUSSION_CLOSE 在到限后触发

测试 4：多频道协作
  - 新 bot 进入第二个频道 → 验证跨频道协作
```

---

## 附录 C：旧版 A2A v1（Delegation 模式）

> **适用场景**：Discord/Feishu 平台（不支持 Discussion），或不需要实时讨论的单向任务委派。
> 旧版使用 `sessions_send` 进行跨 Agent 触发，所有 Agent 共享一个 bot。

### 工作方式

由于所有 Agent 共用一个 bot 身份，bot 发的消息默认被自己忽略（防自循环）。因此需要"两步触发"：

```
Step 1: Agent A 在 Agent B 的频道创建 root message（Slack 可见锚点）
Step 2: Agent A 调用 sessions_send(sessionKey=...) 触发 Agent B
```

### 主要配置

```jsonc
{
  "tools": {
    "agentToAgent": {
      "allow": ["cos", "cto", "ops"]  // 只允许部分 Agent 发起
    }
  },
  "session": {
    "maxPingPongTurns": 4  // 限制来回次数
  }
}
```

### 局限

- 所有协作依赖 `sessions_send`，非原生 Slack 交互
- 需要手动构造 Session Key
- `deliveryContext` 漂移可能导致回复到错误上下文
- 权限矩阵（谁能给谁派单）需要 config 层硬约束
- 用户无法在 Slack 中实时旁观讨论过程

### 与 v2 的对比

| | v1 Delegation | v2 Discussion |
|--|---------------|---------------|
| 触发方式 | `sessions_send` | @mention |
| Bot 身份 | 所有 Agent 共享一个 | Orchestrator 独立 App |
| 用户可见性 | 只看到 root message | 实时在 Thread 旁观 |
| 防循环 | `maxPingPongTurns` config | @mention 协议 + requireMention |
| 多方协作 | 需要链式 sessions_send | 直接 @mention 多个 Agent |
| 平台支持 | Slack / Discord / Feishu | 仅 Slack |
