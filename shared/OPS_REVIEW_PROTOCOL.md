# OPS_REVIEW_PROTOCOL（Ops审核协议）

## 审核范围

### 必须审核
- 所有S类任务的closeout
- 任何Agent的Self-Update（涉及SOUL/AGENTS修改）
- gateway.config.json5变更
- 跨Agent权限/路由变更

### 抽查审核
- signal≥2的closeout
- 周期性随机抽取任务检查

### 不需要审核
- signal=0的日常A类任务
- Q类查询
- 纯MEMORY更新（不涉及规则）

## 审核维度

1. **一致性**：变更是否与系统规则冲突？
2. **影响范围**：是否影响其他Agent？
3. **可回滚**：是否有回滚方案？
4. **成本**：是否产生额外API/资源消耗？
5. **安全**：是否暴露敏感信息/凭证？

## 审核结果

- **Approved**：直接生效
- **Approved with notes**：生效但需记录注意事项
- **Needs revision**：退回修改
- **Rejected**：不生效，说明原因

## 周期性任务

- **每日**：检查前一天的S类closeout
- **每周**：汇总Self-Update，固化有效改动
- **每月**：清理漂移内容，更新SYSTEM_RULES
