**中文** | [English](en/A2A_SETUP_GUIDE.md)

# A2A 跑通指南 — 给 Agent 读的设置文档

> **这个文档的读者是 Agent（推荐由 Ops 执行），不是人。**
> 目标：用最小必要变更，让你的 OpenCrew 的 A2A 闭环真正跑通。
> 如果你是人类用户，可以直接把 [README 里的 prompt](#快速-prompt) 发给你的 Ops / CTO / 任一 Agent。

---

## 0. 前置条件

- OpenCrew 已部署（最小可用：CoS + CTO + Builder，各自能在 Slack 频道正常回复）
- 如果部署了 Ops，Ops 可以执行本指南；否则可由 CTO 或任一 Agent 执行
- `openclaw.json` 中 `tools.agentToAgent.enabled: true`
- Agent 间的 Slack 频道绑定（bindings）已配好

---

## 1. 关键认知：为什么 A2A 需要"设置"

OpenCrew 部署完成后，每个 Agent 都能独立回答问题。但 **跨 Agent 协作（A2A）** 需要额外条件：

| 问题 | 原因 | 解法 |
|------|------|------|
| CTO 在 #build 发消息，Builder 不响应 | 同一个 bot 的消息默认被忽略（防自循环） | 两步触发：Slack 锚点 + `sessions_send` |
| `sessions_send` 返回 timeout | OpenClaw 默认超时较短 | timeout ≠ 失败；需要 thread 兜底消息 |
| Builder 做完了但用户不知道 | 结果只在 A2A 内部流转 | 双通道：A2A reply + Slack thread 留痕 |
| 任务做完但没人汇报 | 没有闭环规则 | DoD 硬规则：回发起频道汇报 |

---

## 2. 配置层变更（openclaw.json）

以下是跑通 A2A 的**最小必要配置变更**。用 `config.patch` 或手动编辑均可。

### 2.1 agentToAgent.allow — 谁能发起 A2A

```json
{
  "tools": {
    "agentToAgent": {
      "enabled": true,
      "allow": ["cos", "cto", "ops", "ko", "builder"]
    }
  }
}
```

> **为什么 builder 也在里面？** Builder 需要能用 `sessions_send` 回复 CTO 的多轮指导。如果你的 Builder 仅通过 Slack thread 回复（不走 A2A reply），可以不加 builder。

### 2.2 maxPingPongTurns — 多轮迭代上限

```json
{
  "session": {
    "agentToAgent": {
      "maxPingPongTurns": 5
    }
  }
}
```

> 默认 4 轮。建议 5 轮（给 Round0 握手 + 3-4 轮实际工作留空间）。

### 2.3 subagents 防无限扇出（通常已默认配好）

```json
{
  "tools": {
    "subagents": {
      "tools": {
        "deny": ["group:sessions"]
      }
    }
  }
}
```

---

## 3. Workspace 文件变更（最小必要）

以下是需要在各 Agent 的 `AGENTS.md` 中**追加**的内容。不需要重写整个文件，只需在合适位置加入对应 section。

### 3.1 CTO 的 AGENTS.md — 追加 A2A 派单 section

在 CTO 的 `AGENTS.md` 中，找到任务处理流程之后，追加：

```markdown
## A2A 派单（主流程：跨频道 thread）

当进入实施阶段：
- 在 **#build**（或 #research）创建任务 root message（锚点）：
  `A2A CTO→Builder | <TITLE> | TID:<...>`
- 正文给完整任务包（建议 `shared/SUBAGENT_PACKET_TEMPLATE.md`）。
- ⚠️ 不要依赖 Slack 的"看到消息就自动触发"（bot-authored inbound 默认会被忽略，避免自循环）。
- 必须用 **sessions_send** 把任务真正触发到目标 thread sessionKey：
  `agent:builder:slack:channel:<#build_id>:thread:<root_ts>`

执行期间（CTO 负责到底）：
- **#build thread 留痕**：每轮 ping-pong 中，用 `message(send, channel=slack, target=<#build_id>, threadId=<root_ts>)` 把你这轮的指令/反馈贴到 #build thread，格式 `[CTO] 内容...`。Builder 也会在 thread 里贴它的进展。
- **#cto checkpoint**：每次收到 Builder 的 checkpoint/结果后，在 #cto 的对应协调 thread 同步一条 checkpoint（让用户不用去 #build 捞信息）。

sessions_send timeout 容错：
- `sessions_send` 返回 timeout **≠ 没送达**。
- 规避：在 thread 里补发一条兜底消息（"已通过 A2A 发送，如未收到可在此查看全文"）。

完成后（DoD 硬规则，缺一不可）：
1. 在 Builder thread 贴 closeout（产物路径 + 验证命令）。
2. **CTO 本机复核**（CLI-first）：至少执行关键命令 + 贴 exit code，确认产出可用。
3. **回 #cto 汇报**：在 #cto 发起 thread 同步最终结果 + 如何验证 + 风险遗留。**这是闭环关键，不做视为任务未完成**。
```

### 3.2 Builder 的 AGENTS.md — 追加 A2A 协作 section

在 Builder 的 `AGENTS.md` 中，执行流程之后追加：

```markdown
## A2A 协作（收到 sessions_send 任务时）

当通过 `sessions_send` 收到来自 CTO 的 A2A 任务：

1. **识别 thread_id**：A2A 消息中会包含 `#build thread_id`（message_id）
2. **多轮 WAIT 纪律**：
   - 每轮只聚焦 1-2 个改动点，完成后**必须 WAIT**
   - 输出格式固定：`Done: ... / Run: ... / Output: ... / WAIT`
   - **禁止一次性做完所有步骤**——等 CTO 下一轮指令后再继续
3. **贴进展到 thread**：每轮回复前，先用 `message(send, channel=slack, target=<#build_id>, threadId=<thread_id>)` 把本轮进展/结果贴到 #build thread，格式 `[Builder] 内容...`
4. **返回 A2A reply**：正常返回结果给 CTO（sessions_send 的 ping-pong 机制）
5. **最终轮**：贴 closeout 到 thread（产物路径 + 验证命令），A2A reply 中回复 `REPLY_SKIP` 表示完成

> ⚠️ thread 留痕是为了用户能在 #build 直接看到完整过程。A2A reply 是给 CTO 的结构化回复。两者都要做。
```

### 3.3 CoS 的 AGENTS.md — 追加 A2A 指派 section

CoS 是用户的主入口，向 CTO/CIO 指派任务是常见路径：

```markdown
## A2A 指派（CoS → CTO / CIO）

当需要让 CTO 处理技术任务：
- 在 **#cto** 创建任务 root message：
  `A2A CoS→CTO | <TITLE> | TID:<...>`
- 正文给完整任务包（建议 `shared/SUBAGENT_PACKET_TEMPLATE.md`）。
- 用 `sessions_send` 触发 CTO：
  `agent:cto:slack:channel:<#cto_id>:thread:<root_ts>`
- 等待 CTO 在 #cto 的结果汇报，收到后同步到 #hq 向用户汇报。

当需要让 CIO 处理领域任务（如投资分析）：
- 同理在 **#invest** 创建 root message 并用 `sessions_send` 触发。

sessions_send timeout 容错：同 CTO（timeout ≠ 失败，需 thread 兜底）。
```

---

## 4. 验证步骤（跑通检查清单）

### 4.1 配置验证

```bash
# 检查 agentToAgent 是否启用
# 在 openclaw.json 中确认：
# tools.agentToAgent.enabled = true
# tools.agentToAgent.allow 包含 cos, cto, ops
# session.agentToAgent.maxPingPongTurns >= 5
```

### 4.2 CTO → Builder 闭环验证

在 `#cto` 频道告诉 CTO：

```
请执行一次 A2A 闭环测试：
1. 在 #build 创建一个测试任务（让 Builder 执行 `pwd && ls -la | head` 并回报）
2. 用 sessions_send 触发 Builder
3. 确认 Builder 在 Slack thread 里回复了（Round0 握手）
4. 完成后回 #cto 汇报结果
```

**验收标准**：
- ✅ #build 出现了 root message（A2A CTO→Builder | ...）
- ✅ Builder 在该 thread 里回复了（`[Builder] Done: ... / WAIT`）
- ✅ CTO 回到 #cto 汇报了结果

### 4.3 CoS → CTO 闭环验证

在 `#hq` 频道告诉 CoS：

```
请执行一次 A2A 闭环测试：
1. 在 #cto 创建一个任务 root message（让 CTO 检查当前 workspace 目录结构并回报）
2. 用 sessions_send 触发 CTO
3. 确认 CTO 在 Slack thread 里回复了
4. CTO 完成后，回 #hq 向我汇报结果
```

**验收标准**：
- ✅ #cto 出现了 root message（A2A CoS→CTO | ...）
- ✅ CTO 在该 thread 里回复了
- ✅ CoS 回到 #hq 汇报了结果

---

## 5. 已验证的关键模式（从实战中沉淀）

这些模式经过 CTO↔Builder 和 CTO↔Ops 的真实 A2A 闭环验证：

### 5.1 Round0 审计握手

在正式任务前，先做一个**极小的真实动作**验证审计链路：
- 要求目标 Agent 执行 `pwd` 并把结果贴到 Slack thread
- **看不到 Round0 回传就停止**——说明目标 Agent 的 session 可能没绑定 Slack

### 5.2 多轮 WAIT 纪律

每轮只做 1-2 个改动点，输出后 WAIT：
```
[Builder] Round 1/3
Done: 创建了 xxx 文件
Run: node xxx.js
Output: exit 0
WAIT: 等待 CTO 指令
```

**禁止一次性做完所有步骤**——这会跳过指导链路，失去多轮迭代的审计和纠错价值。

### 5.3 sessions_send timeout 容错

`sessions_send` 返回 timeout **不等于失败**。消息可能已送达。
规避：在 Slack thread 里补发一条兜底消息。

### 5.4 闭环 DoD（Definition of Done）

任务完成的标准不是"Builder 做完了"，而是：
1. Builder thread closeout ✅
2. CTO 本机复核（CLI-first）✅
3. **回 #cto 汇报**（这一步是闭环关键）✅
4. 通知 KO 沉淀（可选）✅

### 5.5 SessionKey 注意事项

- 不要手打 sessionKey，从 `sessions_list` 复制
- 注意 channel ID 大小写一致性（大小写不一致可能导致 session 路由到 webchat）

---

## 6. 常见问题

**Q：配置改完需要重启吗？**
A：用 `config.patch` 会自动重启。手动编辑需要 `openclaw gateway restart`。⚠️ **注意**：gateway 重启会中断所有 Agent 的当前会话。首次 A2A 设置时这是预期行为（一次性），重启后 Agent 会自动恢复。如果 Agent 在设置过程中"突然停止工作"，大概率是重启导致的——等恢复后重新发起验证即可。

**Q：Builder 在 thread 里没回复怎么办？**
A：检查 `bindings` 是否正确、频道是否 `allow: true`、Builder 的 session 是否绑定了 Slack（而非 webchat）。

**Q：可以让 Builder 直接给 CTO 发 A2A 吗？**
A：可以，但组织纪律上 Builder 是"只接单执行"。如果 Builder 需要澄清，建议在 Slack thread 里直接提问（CTO 能看到）。

**Q：CIO 也需要 A2A 吗？**
A：取决于你的使用场景。CIO 通常独立运作，只在需要 Research 时用 spawn。如果需要 CoS→CIO 派单，按同样模式配即可。

---

> 📖 相关文档 → [A2A 协议](../shared/A2A_PROTOCOL.md) · [核心概念](CONCEPTS.md) · [Agent 入职指南](AGENT_ONBOARDING.md) · [自定义指南](CUSTOMIZATION.md)
