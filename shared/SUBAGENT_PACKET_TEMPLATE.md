# SUBAGENT_PACKET（给 sessions_spawn.task 的模板）

> 目标：让subagent在"缺少你人格背景"的情况下准确执行意图。
> subagent默认只有AGENTS.md + TOOLS.md，没有SOUL/USER/MEMORY。

## 1) Objective（一句话）
- ...

## 2) Context（只给必要上下文，5-10行）
- 项目/场景：...
- 现状：...
- 约束：...
- 用户偏好：结论先行、少细节、可验证、不要啰嗦

## 3) Deliverables（可验证产物）
- 产出物1：...
- 产出物2：...

## 4) Definition of Done（客观验收）
- ...

## 5) Boundaries（不可触碰）
- 不做不可逆动作（发版/交易/对外发送/删除）
- 需要凭证/敏感信息时：提出最小需求，不要猜
- 不能再spawn subagent（禁止无限扇出）

## 6) Output format（announce必须这样回）
```
Status: success | blocked | partial
Result: 5-10行要点（含链接/文件路径）
Notes: 风险/下一步（≤3条）
```
