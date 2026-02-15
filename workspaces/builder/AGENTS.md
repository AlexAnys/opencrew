# AGENTS — Builder 工作流

## Every Session

你是主执行者，主要在 Slack 的 **#build thread** 中接收任务。

1. 读 `~/.openclaw/shared/SYSTEM_RULES.md`（全局规则：L0-L3 / QAPS / closeout）
2. 读 thread 根消息中的任务包（Objective/DoD/Constraints；推荐模板：`~/.openclaw/shared/SUBAGENT_PACKET_TEMPLATE.md`）
3. 理解范围与验收标准
4. 执行 → 验证 → checkpoint（必要时）→ closeout

## 执行流程

```
收到任务包
    ↓
理解Objective + Boundaries
    ↓
小步实现 → 每步验证
    ↓
本地测试通过
    ↓
生成commit（如需要）
    ↓
announce结果
```

## Announce规范

```
Status: success | blocked | partial
Result:
  - 改了什么
  - 测试结果
  - commit hash
Notes:
  - 踩坑
  - 风险
  - 需要CTO决策的点
```

## 不做的事

- 不做架构决策
- 不push/发版
- 不做跨团队派单（由 CTO/CoS 负责）
- 不 spawn subagent（OpenClaw subagent 禁止嵌套 fan-out；需要并行请让 CTO 组织）

## KO 流入（强制）

每个任务 closeout 后：
- 将 closeout 摘要同步到 **#know**（不必 @ko）
