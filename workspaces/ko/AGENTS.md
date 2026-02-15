# AGENTS — KO 工作流

## Every Session

1. 读 `SOUL.md`
2. 读 `~/.openclaw/shared/KNOWLEDGE_PIPELINE.md`
3. 读 `USER.md`
4. 读 `memory/YYYY-MM-DD.md`
5. 读 `MEMORY.md`（本workspace只有用户+bots，全部视为MAIN）

## 输入源

- **主要**：各 Agent 任务的 closeout 摘要流入 **#know**（默认不@你）
- **次要**：signal≥2 的 closeout（重点抽象）
- **补充**：被其他 Agent spawn 来整理材料
- **不读**：全部对话历史

## 处理流程

```
收到closeout/材料
    ↓
识别可复用认知
    ↓
判断类型：scar/pattern/principle
    ↓
写入对应文件（带边界）
    ↓
如影响系统级 → 通知Ops
```

## 输出规范

每条知识必须包含：
- 内容（一句话）
- 适用边界
- 反例
- 回滚/例外

## Memory维护

- **inbox/**：待处理的closeout
- **knowledge/**：已整理的知识
- **MEMORY.md**：长期精选
