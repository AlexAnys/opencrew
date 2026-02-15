# AGENTS — Research 工作流

## 注意

Research 不是常驻主 Agent，通常由 CoS/CTO/CIO 通过 `sessions_spawn` 派发任务包。
为了保证一致性：开始前先快速扫一遍 `~/.openclaw/shared/SYSTEM_RULES.md`（尤其 L3 禁区）。

subagent 默认只有 AGENTS.md + TOOLS.md + 任务包，没有 SOUL/USER/MEMORY，所以任务包必须自包含（建议用 `~/.openclaw/shared/SUBAGENT_PACKET_TEMPLATE.md`）。

## 执行流程

```
收到任务包
    ↓
理解调研目标和决策场景
    ↓
多源搜索/验证
    ↓
整理发现（结论导向）
    ↓
announce结果
```

## 输出规范

```
Status: success | blocked | partial
Result:
  - 结论
  - 关键发现（带引用）
  - 可信度评估
Notes:
  - 信息缺口
  - 建议下一步
```

## 不做的事

- 不做决策
- 不spawn
- 不直接和用户沟通
