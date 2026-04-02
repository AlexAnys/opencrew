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

diff --git a/.harness/reports/architecture_collab_r1.md b/.harness/reports/architecture_collab_r1.md
new file mode 100644
index 0000000..8ff71a1
--- /dev/null
+++ b/.harness/reports/architecture_collab_r1.md
@@ -0,0 +1,1066 @@
+# Architecture Report: Multi-Agent Collaboration Patterns (U0/U3, Round 1)
+
+> Architect: Claude Opus 4.6 | Date: 2026-03-27 | Contract: `.harness/contracts/architecture-a2a.md`
+
+---
+
+## Executive Summary
+
+本报告定义了 OpenCrew 从"委派式 A2A"演化为"协作式 A2A"的完整架构设计。核心洞察：当前 A2A 是**单向委派**（A 发任务包给 B，B 执行后汇报），我们需要的是**多方协作**（多个 Agent 在同一 thread 中各自带入领域判断，互相挑战和完善）。
+
+设计产出五个部分：
+1. **协作模式目录** -- 5 种可落地的协作模式，每种含完整机制描述
+2. **编排模型** -- 3 级编排层次，从人工驱动到事件驱动
+3. **共享 Thread 协议** -- 多 Agent thread 的命名、轮次、终止、升级规范
+4. **Harness 集成** -- 文件式（harness）与聊天式（OpenCrew）协作的映射关系
+5. **配置模板** -- 可直接使用的 Slack 多账号配置片段
+
+**平台支持矩阵**（贯穿全文）：
+
+| 平台 | 多方协作 | 阻塞因素 | 替代方案 |
+|------|---------|---------|---------|
+| **Slack** | NOW | 无 -- `allowBots` + `requireMention` + multi-account 已就绪 | -- |
+| **Discord** | BLOCKED | Issue #11199（同实例 bot 消息互相过滤） | `sessions_send` 委派模式可用 |
+| **Feishu** | NOT POSSIBLE | 平台限制：`im.message.receive_v1` 仅投递用户消息，bot 消息对其他 bot 不可见 | `sessions_send` + 话题隔离可用 |
+
+---
+
+## 1. Collaboration Patterns Catalog
+
+### Pattern 1: Architecture Review（架构评审）
+
+**描述**：CTO 提出技术方案，Builder 从可行性角度质疑，QA/Ops 识别风险，迭代至收敛。这是"提案-挑战-精炼"循环。
+
+**适用场景**：
+- 实现重大功能前的技术方案评审
+- 引入新依赖或架构变更
+- 跨系统集成方案论证
+
+**参与者**：
+| Agent | 角色 | 贡献 |
+|-------|------|------|
+| CTO | 提案者 | 提出架构方案、回应质疑、迭代设计 |
+| Builder | 可行性评审者 | 从实现角度评估复杂度、工期、技术债 |
+| Ops | 风险评审者 | 评估运维影响、安全风险、回滚策略 |
+| 用户 | 决策者 | 定目标、验收、在分歧时拍板 |
+
+**机制（step-by-step）**：
+
+```
+Step 1: 用户（或 CoS）在 #collab 频道发帖
+        "我们需要评审 X 功能的技术方案"
+        → CTO 作为频道绑定 Agent 自动收到（或被 @mention）
+
+Step 2: CTO 发布架构提案（在 thread 中）
+        格式：[CTO] Proposal: <标题>
+        内容：目标、方案、技术选型、风险评估
+
+Step 3: 用户 @mention Builder
+        "@Builder 请从实现角度评估这个方案"
+        → Builder 的 bot 收到 mention event
+        → Builder 加载 thread 历史（通过 initialHistoryLimit）
+        → Builder 发布可行性评估
+
+Step 4: 用户 @mention Ops（如需要）
+        "@Ops 请评估运维和安全影响"
+        → Ops 加载 thread 历史，看到 CTO 提案 + Builder 评估
+        → Ops 发布风险评估
+
+Step 5: 用户 @mention CTO
+        "@CTO 请回应 Builder 和 Ops 的反馈"
+        → CTO 看到所有历史，发布修订方案或反驳
+
+Step 6: 重复 Step 3-5 直到收敛
+        收敛标志：所有参与者表示"无进一步反对"或用户拍板
+
+Step 7: CTO 发布最终决议总结（thread 内）
+        格式：[CTO] DECISION: <结论>
+        内容：最终方案、遗留风险、下一步 action
+```
+
+**平台支持**：
+- **Slack**: NOW -- 多账号 + `allowBots: true` + `requireMention: true`
+- **Discord**: AFTER #11199 -- 修复后机制完全相同
+- **Feishu**: NOT SUPPORTED -- bot 消息对其他 bot 不可见；替代：用户手动转述或 `sessions_send` 逐步委派
+
+**防护栏**：
+- **循环防护**：设定 `maxDiscussionTurns = 5`（AGENTS.md 指令层）。超过 5 轮未收敛，必须升级到用户拍板
+- **噪音防护**：所有共享频道 `requireMention: true`，Agent 不被 @mention 就不响应
+- **上下文溢出防护**：每位 Agent 的发言不超过 500 字。超过时拆分为"摘要 + 详细附件链接"
+- **发散防护**：每轮必须聚焦 1 个议题。CTO 作为提案者负责"下一轮聚焦什么"
+
+**示例场景**：
+
+> 用户想给 OpenCrew 增加"自动 PR 创建"功能。
+>
+> 1. 用户在 #collab: "评审自动 PR 创建功能的技术方案"
+> 2. CTO: "建议用 GitHub API + Builder Agent 的 bash tool 实现。架构：CoS 收到用户请求 → 转 CTO 拆解 → Builder 执行 git/gh 命令 → Builder closeout 含 PR URL"
+> 3. @Builder: "git 操作需要 repo 写权限。当前 Builder 的 tool 配置没有 gh auth。需要增加 GITHUB_TOKEN 环境变量。工期估计：配置 30 分钟，测试 1 小时"
+> 4. @Ops: "风险：GITHUB_TOKEN 泄露到 closeout 日志。建议：使用 SecretRef 而非明文。另外需要 L3 用户确认（创建 PR 是可回滚但影响较大的动作）"
+> 5. @CTO: "接受两点反馈。修订：使用 SecretRef 管理 token；PR 创建前在 thread 里 WAIT 用户确认（L2→L3 升级）"
+> 6. 用户: "APPROVED。CTO 请拆解任务给 Builder"
+> 7. CTO 发布 DECISION 总结 → 转入 A2A v1 委派流程给 Builder
+
+---
+
+### Pattern 2: Strategic Alignment（战略对齐）
+
+**描述**：用户表达高层目标，CoS 解读深层意图，CTO 规划技术路径，CIO 补充领域约束，多方收敛出可执行计划。
+
+**适用场景**：
+- 新项目/新方向启动
+- 季度 OKR 拆解
+- 重大方向转变（pivot）
+
+**参与者**：
+| Agent | 角色 | 贡献 |
+|-------|------|------|
+| CoS | 意图解读者 | 澄清用户真实意图、优先级、价值判断 |
+| CTO | 技术规划者 | 将意图转化为技术路径、评估可行性 |
+| CIO | 领域约束者 | 补充领域知识、市场约束、合规要求 |
+| 用户 | 决策者 | 定方向、校正偏差 |
+
+**机制（step-by-step）**：
+
+```
+Step 1: 用户在 #hq 频道发布目标
+        "我想做 X，因为 Y"（可以是模糊的一句话）
+        → CoS 作为 #hq 绑定 Agent 首先响应
+
+Step 2: CoS 解读意图
+        格式：[CoS] Intent Alignment
+        内容：我理解的目标、隐含假设、需要确认的点
+        → 用户确认/校正
+
+Step 3: CoS @mention CTO（在同一 thread）
+        "@CTO 基于以上对齐的目标，请规划技术路径"
+        → CTO 加载 thread（看到用户原始目标 + CoS 解读 + 用户确认）
+        → CTO 发布技术方案草案
+
+Step 4: CoS @mention CIO（如涉及领域）
+        "@CIO 请补充领域约束和市场视角"
+        → CIO 加载 thread，看到全部上下文
+        → CIO 发布领域分析
+
+Step 5: CoS 综合所有输入，产出对齐摘要
+        格式：[CoS] Alignment Summary
+        内容：确认的目标、技术路径、领域约束、优先级排序、下一步
+        → 用户最终确认
+
+Step 6: 确认后，CoS 通过 A2A v1 委派给 CTO 执行拆解
+```
+
+**关键设计决策**：CoS 作为编排者而非信息中转。CoS 的价值不是"传话"，而是在每一轮中加入自己的判断——"用户说了 X，但我认为真正的需求是 Y"。这与 ARCHITECTURE.md 中"CoS 是战略伙伴不是秘书"的定位一致。
+
+**平台支持**：
+- **Slack**: NOW
+- **Discord**: AFTER #11199
+- **Feishu**: NOT SUPPORTED（替代：CoS 在各 Agent 群组间用 `sessions_send` 逐步推进，手动综合）
+
+**防护栏**：
+- **意图漂移防护**：CoS 每轮输出必须包含"与用户原始目标的对齐度"评估
+- **过度规划防护**：战略对齐最多 3 轮。3 轮后必须产出可执行的 next action
+- **CTO/CIO 范围防护**：CTO 只谈技术、CIO 只谈领域。越界时 CoS 有权引导回正题
+
+**示例场景**：
+
+> 用户: "我想让 OpenCrew 支持自动处理 GitHub Issues"
+>
+> 1. CoS: "理解目标。我的解读：你想让 Agent 自动 triage issues、分类、分配。但我想确认——是全自动（Agent 直接处理）还是半自动（Agent 分析后等你确认）？另外范围是所有 repo 还是特定 repo？"
+> 2. 用户: "先做半自动，只针对 opencrew repo"
+> 3. CoS @CTO: "目标确认：半自动 GitHub Issues triage for opencrew repo。请规划技术路径。"
+> 4. CTO: "方案：用 GitHub Webhook → OpenClaw channel → Ops Agent 接收。Ops 分析 issue 后产出建议（分类 + 优先级 + 建议处理者），发到 #ops 等用户确认。技术需要：新增 GitHub channel 配置、Ops AGENTS.md 增加 triage 指令。"
+> 5. CoS @CIO: "从项目管理视角，有什么分类标准建议？"
+> 6. CIO: "建议分类：bug/feature/docs/question。优先级用 impact x urgency 矩阵。注意：外部贡献者的 issue 应该比内部的优先响应（社区建设）"
+> 7. CoS 综合: "Alignment Summary: 目标=半自动 issue triage for opencrew。路径=GitHub Webhook + Ops Agent。分类=bug/feature/docs/question。优先级=impact x urgency。社区 issue 优先。下一步：CTO 拆解任务。" → 用户确认 → 委派
+
+---
+
+### Pattern 3: Code/Design Review（代码/设计评审）
+
+**描述**：Builder 产出代码或设计文档，CTO 评审架构合理性，QA/Ops 评审正确性和安全性，KO 检查知识一致性。这是"生产-多维评审-修订"循环。
+
+**适用场景**：
+- PR 合并前评审
+- 设计文档评审
+- 配置变更评审
+- 知识库内容评审
+
+**参与者**：
+| Agent | 角色 | 贡献 |
+|-------|------|------|
+| Builder | 生产者 | 产出代码/文档，根据反馈修订 |
+| CTO | 架构评审者 | 评审架构合理性、设计模式、长期可维护性 |
+| Ops | 正确性/安全评审者 | 评审安全风险、运维影响、合规性 |
+| KO | 知识一致性评审者 | 检查与已有知识（principles/patterns/scars）的一致性 |
+
+**机制（step-by-step）**：
+
+```
+Step 1: Builder 在 #build thread 完成实现，产出 closeout
+        closeout 包含：产出物路径、变更摘要、验证命令
+
+Step 2: CTO 在 #build thread 中 @mention（或 CTO 主动发起评审 thread）
+        → 评审在一个"评审 thread"中进行（可以在 #collab 或 #cto）
+        → CTO 发布架构评审
+
+Step 3: @Ops 评审安全/运维
+        → Ops 看到 Builder 的 closeout + CTO 的评审
+        → 发布安全/运维评估
+
+Step 4: @KO 评审知识一致性（如涉及系统变更）
+        → KO 看到全部上下文
+        → 检查是否与 principles.md/patterns.md/scars.md 冲突
+        → 如有冲突则指出
+
+Step 5: CTO 综合所有评审意见
+        格式：[CTO] Review Summary
+        状态：APPROVED / NEEDS_REVISION / REJECTED
+        如 NEEDS_REVISION：列出具体修改项 → 回到 Builder
+
+Step 6: Builder 修订后重新提交（thread 内）
+        → 重复 Step 2-5（通常 1-2 轮即可收敛）
+```
+
+**与 Harness Evaluator 的对比**：
+
+Anthropic harness 设计中的 Evaluator 是单一评审者，采用"Generator vs Evaluator"对抗模式。OpenCrew 的评审是**多维度评审**——不同 Agent 从不同维度审查同一产出。这更接近真实团队中"架构师看设计、安全团队看漏洞、文档团队看一致性"的工作方式。
+
+**平台支持**：
+- **Slack**: NOW
+- **Discord**: AFTER #11199
+- **Feishu**: NOT SUPPORTED（替代：CTO 手动在各群组间转述评审结论，或人工触发 `sessions_send`）
+
+**防护栏**：
+- **评审范围限定**：每位评审者只评审自己领域。CTO 不评审安全，Ops 不评审架构
+- **评审轮次限制**：最多 3 轮修订。3 轮后要么 APPROVED 要么升级到用户决策
+- **上下文容量管理**：`initialHistoryLimit` 建议设为 80-100（评审 thread 内容较多）
+- **评审格式标准化**：每条评审必须包含 `severity: [BLOCKER|MAJOR|MINOR|NITPICK]` + `具体修改建议`
+
+**示例场景**：
+
+> Builder 完成了 A2A_PROTOCOL.md v2 的草案。
+>
+> 1. Builder closeout: "A2A_PROTOCOL_V2.md 已产出，路径 shared/A2A_PROTOCOL_V2.md。变更：新增多 bot 模式、简化触发流程、新增协作模式引用。"
+> 2. @CTO: "架构评审：新增的 multi-bot 模式逻辑清晰。但第 3 节协作模式引用缺少 Feishu 的降级方案。MAJOR：请补充。另外命名建议：A2A v1/v2 改为 delegation-mode/discussion-mode，避免暗示 v1 被废弃。MINOR。"
+> 3. @Ops: "安全评审：multi-bot 配置示例中 botToken 是明文。BLOCKER：必须改为 SecretRef 或环境变量引用。另外 allowBots: true 的安全含义需要在文档中明确警告。MAJOR。"
+> 4. @KO: "知识一致性检查：与 scars.md 中'sessions_send timeout 不等于未送达'的记录一致。与 patterns.md 中'一个任务 = 一个 thread = 一个 session'的原则需要更新——discussion-mode 中一个 thread 可能对应多个 Agent 的 session。MAJOR：建议更新 patterns.md。"
+> 5. CTO Review Summary: "NEEDS_REVISION。3 项需修改：Feishu 降级方案、token 安全化、patterns.md 更新。"
+> 6. Builder 修订 → 重新提交 → 第二轮评审 → APPROVED
+
+---
+
+### Pattern 4: Incident Response（事件响应）
+
+**描述**：Ops 检测到异常，CTO 诊断根因，Builder 提出修复方案，QA 验证修复。快速迭代直至解决。
+
+**适用场景**：
+- 生产环境异常（Agent 无响应、消息路由错误、配置漂移）
+- A2A 通信故障
+- 安全事件
+
+**参与者**：
+| Agent | 角色 | 贡献 |
+|-------|------|------|
+| Ops | 检测 + 初步分析 | 发现问题、收集初步证据、触发响应流程 |
+| CTO | 诊断者 | 分析根因、确定影响范围、决定修复策略 |
+| Builder | 修复者 | 实施修复、验证修复 |
+| 用户 | 审批者 | L3 动作审批（如需要） |
+
+**机制（step-by-step）**：
+
+```
+Step 1: Ops 在 #ops 检测到异常（手动或自动）
+        → Ops 在 #collab 创建事件响应 thread
+        格式：[Ops] INCIDENT: <标题> | Severity: P1/P2/P3
+        内容：症状描述、初步证据（日志/错误信息）、影响范围
+
+Step 2: @CTO 诊断
+        → CTO 加载 thread，分析 Ops 提供的证据
+        → 发布诊断结果：根因假设、影响范围评估、建议修复策略
+        → 如需更多信息：@Ops "请补充 X 日志"
+
+Step 3: @Builder 修复（如诊断明确）
+        → CTO 在 thread 中 @Builder 并附带修复方案
+        → Builder 实施修复、在 thread 中报告修复步骤和验证结果
+
+Step 4: @Ops 验证
+        → Ops 验证修复后系统状态
+        → 发布验证结果：修复有效 / 部分有效 / 无效
+
+Step 5: 如修复无效 → 回到 Step 2
+        如修复有效 → CTO 发布事件总结
+
+Step 6: CTO 发布 INCIDENT RESOLVED
+        格式：[CTO] INCIDENT RESOLVED: <标题>
+        内容：根因、修复措施、遗留风险、防复发建议
+        → 同步到 KO（signal ≥ 2，记入 scars.md）
+```
+
+**紧急性设计**：事件响应与其他协作模式的关键区别是**时间压力**。机制设计体现为：
+- **快速启动**：Ops 直接 @mention CTO，不需要 CoS 中转
+- **并行诊断**：CTO 可以同时 @mention Builder 准备修复环境
+- **简化格式**：允许短消息，不强制完整的任务包格式
+- **L3 快速通道**：P1 事件中，用户可以预授权"Builder 可以执行通常需要确认的操作"
+
+**平台支持**：
+- **Slack**: NOW
+- **Discord**: AFTER #11199（事件响应对实时性要求最高，Discord 解决后应优先支持此模式）
+- **Feishu**: PARTIAL -- Ops 可以在各群组间用 `sessions_send` 分步协调，但缺乏所有参与者共同可见的统一 thread
+
+**防护栏**：
+- **升级时限**：P1 事件如果 3 轮内未解决（约 15 分钟），自动升级到用户
+- **操作审计**：所有修复操作必须在 thread 中明文记录（命令 + 输出）
+- **回滚预案**：Builder 每次修复前必须声明回滚步骤
+- **事后复盘**：INCIDENT RESOLVED 后 24 小时内必须完成 postmortem（可由 KO 协助）
+
+**示例场景**：
+
+> Ops 发现 Builder Agent 在 #build 频道不响应。
+>
+> 1. Ops: "INCIDENT: Builder Agent 无响应 | Severity: P2。症状：#build 频道 @Builder 无反应已 30 分钟。初步检查：gateway 进程正常、Slack WebSocket 连接正常。"
+> 2. @CTO: "诊断：可能原因：(1) Builder 的 session 卡在长任务中 (2) binding 配置问题 (3) Slack app token 过期。请 @Ops 检查 sessions_list 中 Builder 的活跃 session 数量和最近活动时间。"
+> 3. @Ops: "sessions_list 结果：Builder 有 3 个活跃 session，最近一个 45 分钟前创建，状态 active。看起来是卡在长任务。"
+> 4. CTO: "确认根因：Builder session 卡在长任务。修复策略：(A) 等待当前任务完成 (B) 重置卡住的 session。建议 A，如果 30 分钟后仍无响应再执行 B。@Builder 你当前在执行什么任务？"
+> 5. Builder（恢复后）: "刚完成一个大文件的 git 操作，耗时 40 分钟。已恢复正常。"
+> 6. CTO: "INCIDENT RESOLVED: Builder 因长任务阻塞导致短暂无响应。根因：大文件 git 操作超过预期耗时。防复发：在 Builder AGENTS.md 中增加'长任务必须每 10 分钟发 checkpoint'的指令。"
+
+---
+
+### Pattern 5: Knowledge Synthesis（知识综合）
+
+**描述**：KO 呈现提炼后的知识（从 closeout 中提取），CTO 验证技术准确性，CIO 验证领域准确性，CoS 评估战略相关性。
+
+**适用场景**：
+- 周期性知识复盘（每周/每月）
+- 新知识条目入库前的交叉验证
+- 知识库重大更新
+
+**参与者**：
+| Agent | 角色 | 贡献 |
+|-------|------|------|
+| KO | 呈现者 | 提炼知识、组织结构、提出入库建议 |
+| CTO | 技术验证者 | 验证技术内容的准确性和时效性 |
+| CIO | 领域验证者 | 验证领域知识的准确性和适用性 |
+| CoS | 战略评估者 | 评估知识的战略相关性和优先级 |
+
+**机制（step-by-step）**：
+
+```
+Step 1: KO 在 #know 或 #collab 创建知识综合 thread
+        格式：[KO] Knowledge Synthesis: <主题/周期>
+        内容：
+        - 新增原则（candidates for principles.md）
+        - 新增模式（candidates for patterns.md）
+        - 新增教训（candidates for scars.md）
+        - 建议变更（对现有条目的更新）
+
+Step 2: @CTO 技术验证
+        → CTO 逐条验证技术内容
+        → 标注：ACCURATE / OUTDATED / NEEDS_CONTEXT / INCORRECT
+        → 对 NEEDS_CONTEXT 和 INCORRECT 提供修正建议
+
+Step 3: @CIO 领域验证（如涉及领域知识）
+        → CIO 验证领域内容
+        → 同样标注 + 修正建议
+
+Step 4: @CoS 战略评估
+        → CoS 评估每条知识的战略权重
+        → 标注：HIGH_VALUE / USEFUL / LOW_VALUE / IRRELEVANT
+        → 对 HIGH_VALUE 建议"升级为原则"或"影响后续规划"
+
+Step 5: KO 综合所有反馈
+        → 发布最终版本：哪些入库、哪些修改、哪些丢弃
+        → 执行知识库更新
+        → 发布 closeout（signal ≥ 2）
+```
+
+**与现有知识管道的集成**：
+
+当前 KNOWLEDGE_PIPELINE.md 定义了 closeout → KO ingest 的单向流。Knowledge Synthesis 模式将其扩展为**双向验证**：KO 不仅是接收者，还是综合者，主动发起交叉验证。这增加了知识库的可靠性。
+
+**平台支持**：
+- **Slack**: NOW
+- **Discord**: AFTER #11199
+- **Feishu**: NOT SUPPORTED（替代：KO 在各 Agent 群组逐一发送验证请求，手动综合结果）
+
+**防护栏**：
+- **验证粒度**：每次综合不超过 10 条知识条目（避免评审者认知过载）
+- **频率控制**：每周最多 1 次全面综合。临时入库可以走简化流程（KO 自行决定，signal < 2 不需要交叉验证）
+- **否决权**：CTO 对技术内容有否决权，CIO 对领域内容有否决权。被否决的条目不入库
+
+**示例场景**：
+
+> KO 每周五执行知识综合。
+>
+> 1. KO: "Knowledge Synthesis: Week 12。新增候选条目：(1) Principle: 'A2A sessions_send timeout 不等于失败，必须有兜底消息' (2) Pattern: '多 Agent 评审用 severity 标签分级' (3) Scar: 'Feishu bot 消息对其他 bot 不可见，跨 bot 触发必须走 sessions_send'"
+> 2. @CTO: "(1) ACCURATE，已在实战中多次验证。(2) ACCURATE，建议补充 severity 定义。(3) ACCURATE，这是 Feishu 平台限制非 OpenClaw bug。"
+> 3. @CIO: "本周无领域相关条目，SKIP。"
+> 4. @CoS: "(1) HIGH_VALUE — 影响所有 A2A 流程设计。(2) USEFUL — 评审效率提升。(3) HIGH_VALUE — 影响 Feishu 多 Agent 架构决策。"
+> 5. KO: "综合结果：3 条全部入库。(1) → principles.md (2) → patterns.md，补充 severity 定义后入库 (3) → scars.md。已更新。"
+
+---
+
+## 2. Orchestration Model
+
+### Level 1: Human Orchestrated（人工编排）
+
+**描述**：用户手动 @mention Agent 驱动讨论。用户完全控制节奏、话题、参与者顺序。
+
+**机制**：
+1. 用户在共享频道/thread 中发帖
+2. 用户通过 @mention 指定下一位发言的 Agent
+3. Agent 响应后 WAIT——不主动 @mention 其他 Agent
+4. 用户阅读响应后，决定下一步：@mention 另一位 Agent、要求当前 Agent 深入、或结束讨论
+
+**配置要求**：
+```json
+{
+  "channels": {
+    "slack": {
+      "channels": {
+        "<COLLAB_CHANNEL_ID>": {
+          "allow": true,
+          "requireMention": true,
+          "allowBots": true
+        }
+      }
+    }
+  }
+}
+```
+
+**防护栏**：
+- 所有 Agent 的 AGENTS.md 中增加指令：`"在协作 thread 中，响应后 WAIT。不要主动 @mention 其他 Agent，除非处于 Level 2 编排模式。"`
+- `requireMention: true` 是硬约束——即使 Agent "想"响应也触发不了（无 mention = 无 event）
+
+**推荐成熟度**：初始部署阶段。建立信任期。用户需要理解每位 Agent 的判断质量和领域能力。
+
+**优势**：完全可控、零风险无限循环、用户随时可以重定向讨论
+**劣势**：用户成为瓶颈——每一步都需要人工输入
+
+---
+
+### Level 2: Agent Orchestrated（Agent 编排）
+
+**描述**：指定一位"编排 Agent"（CTO 负责技术讨论、CoS 负责战略讨论），该 Agent 有权 @mention 其他 Agent 并管理讨论节奏。
+
+**机制**：
+1. 用户启动讨论并指定编排者："@CTO 请主持这次架构评审，涉及 @Builder 和 @Ops"
+2. 编排 Agent（CTO）分析需求，决定第一步找谁
+3. CTO @mention Builder: "请评估可行性"
+4. Builder 响应后（`allowBots: true` 使 CTO 能看到 Builder 的消息），CTO 决定下一步
+5. CTO @mention Ops: "请评估安全影响"
+6. CTO 综合后发布结论或继续迭代
+7. 如需用户决策，CTO @mention 用户
+
+**配置要求**：
+```json
+// 编排者 Agent 的 AGENTS.md 增加以下指令段：
+// ## 协作编排模式（Level 2）
+// 当用户指定你为编排者时：
+// 1. 分析参与者列表和讨论目标
+// 2. 按逻辑顺序 @mention 参与者
+// 3. 每位参与者响应后，判断：需要更多输入？收敛了？有分歧需要用户裁决？
+// 4. 最多 {maxOrchestratedRounds} 轮后必须产出结论或升级到用户
+// 5. 每轮 @mention 最多 1 位 Agent（避免并发冲突）
+```
+
+技术实现的关键点——编排者如何看到其他 Agent 的响应：
+- 编排者的 bot 在共享频道中，`allowBots: true` 使其收到其他 bot 的消息
+- `requireMention: true` 确保编排者不会对非相关消息响应
+- 编排者的 AGENTS.md 指令决定何时主动 @mention 下一位参与者
+
+**防护栏**：
+- **轮次硬限制**：`maxOrchestratedRounds = 8`（AGENTS.md 指令层）。超过时编排者必须产出"当前最佳结论 + 遗留分歧"
+- **沉默检测**：如果被 @mention 的 Agent 30 秒内无响应，编排者应在 thread 中标注 `[TIMEOUT: <Agent> 未响应]` 并继续
+- **用户干预**：用户随时可以在 thread 中发言，所有 Agent 看到用户消息后应暂停自动编排，等待用户指示
+- **编排者不自封**：编排者角色由用户指定，Agent 不能自行升级为编排者
+
+**推荐成熟度**：经过 Level 1 验证 Agent 判断质量后。适合重复性高的协作模式（如每周评审）。
+
+**优势**：减少用户参与频率，Agent 自主推进讨论
+**劣势**：编排者可能引入偏见（总是先问某个 Agent），讨论可能偏离用户预期
+
+---
+
+### Level 3: Event-Driven（事件驱动）
+
+**描述**：Agent 基于"相关性信号"自主决定是否加入讨论。不需要被 @mention，而是检测到与自身领域相关的内容时主动贡献。
+
+**机制**：
+1. 用户或 Agent 在 thread 中发言
+2. 所有参与频道的 Agent 收到消息（`allowBots: true` + `requireMention: false`）
+3. 每位 Agent 内部评估"这条消息与我的领域相关吗？"
+4. 如果相关度高于阈值，Agent 主动发言
+5. 如果相关度低，Agent 保持沉默
+
+**配置要求**：
+```json
+{
+  "channels": {
+    "slack": {
+      "channels": {
+        "<COLLAB_CHANNEL_ID>": {
+          "allow": true,
+          "requireMention": false,  // 关键：不需要 mention 即可触发
+          "allowBots": true
+        }
+      }
+    }
+  }
+}
+
+// 每位 Agent 的 AGENTS.md 增加：
+// ## 事件驱动参与（Level 3）
+// 当你在协作频道收到非 @mention 消息时：
+// 1. 评估与你领域的相关性（0-10）
+// 2. 相关性 < 7：不响应
+// 3. 相关性 >= 7 且你有独特视角：发言，前缀 "[proactive]"
+// 4. 相关性 >= 7 但已有其他 Agent 覆盖：不响应
+// 5. 每个 thread 最多主动发言 2 次（避免噪音）
+```
+
+**为什么列为 FUTURE**：
+
+Event-Driven 模式的核心挑战是**相关性判断的可靠性**。当前 LLM 在"是否应该发言"这个元判断上不够稳定——可能过度参与（噪音）或遗漏关键时刻（静默错误）。需要以下前置条件成熟后再启用：
+1. 通过 Level 1/2 积累足够多的"Agent 应该在什么时候发言"的实战数据
+2. 在 AGENTS.md 中精炼出每位 Agent 的"触发条件清单"
+3. 建立"proactive 发言质量"的评估机制
+
+**防护栏**：
+- **频率限制**：每位 Agent 在每个 thread 中最多主动发言 2 次
+- **冷却期**：同一 Agent 在同一 thread 中两次主动发言间隔至少 3 分钟
+- **[proactive] 前缀**：主动发言必须标注，方便用户区分"被要求的"和"自主的"
+- **用户静音**：用户可以在 thread 中发 `@Agent MUTE` 让特定 Agent 在该 thread 中保持沉默
+- **紧急刹车**：如果一个 thread 中 Agent 消息数超过 20 且无用户参与，所有 Agent 自动进入 WAIT
+
+**推荐成熟度**：远期目标。需要 Level 2 运行稳定 + 相关性判断经过充分验证。
+
+**优势**：最接近"真实团队"的讨论体验，Agent 主动贡献洞察
+**劣势**：噪音风险最高，调试困难，用户可能感到"Agent 在自说自话"
+
+---
+
+## 3. Shared Thread Protocol
+
+### 3.1 Thread 命名规范
+
+多 Agent 协作 thread 的 root message 必须包含以下前缀：
+
+```
+COLLAB <TYPE> | <TITLE> | <DATE>
+```
+
+其中 TYPE 对应协作模式：
+
+| TYPE | 对应模式 | 示例 |
+|------|---------|------|
+| `REVIEW` | Architecture Review / Code Review | `COLLAB REVIEW \| A2A v2 协议草案评审 \| 2026-03-27` |
+| `ALIGN` | Strategic Alignment | `COLLAB ALIGN \| GitHub Issues 自动化方向 \| 2026-03-27` |
+| `INCIDENT` | Incident Response | `COLLAB INCIDENT \| Builder 无响应 P2 \| 2026-03-27` |
+| `SYNTH` | Knowledge Synthesis | `COLLAB SYNTH \| Week 12 知识综合 \| 2026-03-27` |
+| `DISCUSS` | 通用讨论（不匹配以上模式） | `COLLAB DISCUSS \| 是否引入 MCP 支持 \| 2026-03-27` |
+
+**与现有 A2A 前缀的共存**：
+- 委派式 A2A 继续使用 `A2A <FROM>→<TO> | <TITLE> | TID:<timestamp>` 前缀
+- 协作式 thread 使用 `COLLAB <TYPE>` 前缀
+- 两种前缀可以在同一频道共存——人和 Agent 都能快速区分"委派任务"和"协作讨论"
+
+### 3.2 Turn Structure（轮次格式）
+
+每位 Agent 在协作 thread 中的发言遵循以下格式：
+
+```
+[<角色>] <动作类型>
+<内容>
+[STATUS: <状态>]
+```
+
+**动作类型**：
+
+| 动作 | 含义 | 使用者 |
+|------|------|-------|
+| `Proposal` | 提出方案 | 任何提案者 |
+| `Review` | 评审意见 | 评审者 |
+| `Response` | 回应他人意见 | 被评审者 |
+| `Diagnosis` | 诊断分析 | 技术角色 |
+| `Fix` | 修复方案 | 实施者 |
+| `Synthesis` | 综合总结 | 编排者/KO |
+| `Escalation` | 升级到用户 | 任何 Agent |
+| `[proactive]` | 主动发言 | Level 3 模式 |
+
+**状态标签**：
+
+| STATUS | 含义 |
+|--------|------|
+| `WAIT` | 等待下一步指令 |
+| `NEEDS_INPUT:<Agent/User>` | 需要特定方的输入 |
+| `CONVERGED` | 认为讨论已收敛 |
+| `BLOCKED:<原因>` | 被阻塞 |
+| `DECISION:<结论>` | 最终决策（通常由编排者/用户发出） |
+
+**示例**：
+
+```
+[CTO] Proposal
+建议使用 multi-account Slack 配置实现多 Agent 协作。
+核心变更：3 个 Slack app（CoS/CTO/Builder），共享 #collab 频道，allowBots + requireMention。
+[STATUS: NEEDS_INPUT:Builder]
+```
+
+```
+[Builder] Review
+可行性评估：multi-account 配置本身简单（已有文档），但需要创建 3 个 Slack app + 配置 OAuth。
+工期估计：2 小时配置 + 1 小时验证。
+风险：Socket Mode 下 3 个 app 的连接稳定性未验证。
+severity: MINOR（风险可控）
+[STATUS: WAIT]
+```
+
+### 3.3 Context Management（上下文管理）
+
+**Thread 历史控制**：
+
+| 场景 | `initialHistoryLimit` 建议值 | 理由 |
+|------|---------------------------|------|
+| Architecture Review | 50 | 方案文本通常较长 |
+| Strategic Alignment | 30 | 对话式，轮次多但每轮短 |
+| Code Review | 80-100 | 代码/配置内容占用大量 token |
+| Incident Response | 30 | 快速迭代，每轮短 |
+| Knowledge Synthesis | 50 | 条目列表 + 评审意见 |
+
+**上下文压缩策略**：
+
+当 thread 超过 `initialHistoryLimit` 时，后加入的 Agent 只能看到最近 N 条消息。为此：
+
+1. **编排者摘要责任**：每 5 轮，编排者发布一条 `[<角色>] Synthesis: Thread Summary`，概括到目前为止的关键决策和未决问题
+2. **"到此为止"锚点**：编排者可以发布 `--- CONTEXT ANCHOR ---`，后续 Agent 只需要从这个锚点开始阅读
+3. **附件而非内联**：超过 200 字的内容（代码块、配置文件、日志）应该放在 Slack 文件附件或外部链接中，而非内联到 thread 消息
+
+### 3.4 Termination Criteria（终止条件）
+
+讨论"完成"的判定标准：
+
+**显式终止**（推荐）：
+1. **用户宣布**：用户在 thread 中发布 `RESOLVED` 或 `APPROVED`
+2. **编排者宣布**：编排者发布 `[<角色>] DECISION: <结论>` + `[STATUS: CONVERGED]`
+3. **所有参与者同意**：每位参与 Agent 发布 `[STATUS: CONVERGED]`
+
+**隐式终止**（防护栏触发）：
+1. **轮次上限**：达到 `maxDiscussionTurns`（默认 5 轮 for Level 1, 8 轮 for Level 2）
+2. **时间上限**：thread 最后一条消息超过 4 小时无新内容
+3. **Agent 消息上限**：thread 中 Agent 消息总数超过 20 条（Level 3 的紧急刹车）
+
+**终止后动作**：
+1. 编排者（或最后发言的 Agent）发布 discussion closeout（精简版 CLOSEOUT_TEMPLATE）
+2. 如果讨论产生了可执行任务 → 转入 A2A v1 委派流程
+3. 如果讨论产生了知识 → 同步到 #know
+4. Thread 保留为可搜索的组织记忆
+
+### 3.5 Escalation（升级到人类）
+
+以下情况 Agent 必须升级到用户：
+
+| 触发条件 | 升级方式 | 升级消息格式 |
+|---------|---------|------------|
+| Agent 间分歧无法收敛（2+ 轮） | Thread 内 @mention 用户 | `[<角色>] Escalation: <Agent-A> 认为 X，<Agent-B> 认为 Y。需要你裁决。` |
+| 涉及 L3 动作 | Thread 内 @mention 用户 | `[<角色>] Escalation: 需要 L3 审批——<具体动作>。` |
+| 讨论偏离原始目标 | Thread 内 @mention 用户 | `[<角色>] Escalation: 讨论已偏离 "<原始目标>"。请确认是否调整方向。` |
+| 编排 Agent 不确定下一步 | Thread 内 @mention 用户 | `[<角色>] Escalation: 不确定应该咨询哪位 Agent 或是否可以结论。` |
+
+### 3.6 与现有模板的集成
+
+**Discussion Closeout**（讨论收尾，基于 CLOSEOUT_TEMPLATE 精简版）：
+
+```
+## Discussion Closeout
+- Thread: [COLLAB <TYPE> | <TITLE> | <DATE>]
+- Participants: [Agent 列表]
+- Rounds: [轮次数]
+
+## Decisions
+1. ...
+2. ...
+
+## Dissent（未达成共识的点）
+- ...
+
+## Next Actions
+| Action | Owner | Type |
+|--------|-------|------|
+| ... | ... | A2A v1 委派 / 用户确认 / 知识入库 |
+
+## Signal Score
+- [0-3]
+```
+
+**Discussion Checkpoint**（讨论中间切割，当讨论跨天或上下文膨胀时）：
+
+```
+## Discussion Checkpoint #N
+- Thread: [COLLAB <TYPE> | <TITLE> | <DATE>]
+- Current Round: [M/max]
+
+## 到目前为止的决策
+- ...
+
+## 未决问题
+- ...
+
+## 下一步
+- 继续讨论：@<Agent> <问题>
+- 或：升级到用户
+```
+
+---
+
+## 4. Integration with Harness Design
+
+### 4.1 模式映射
+
+Anthropic 的 harness 设计使用 Planner → Builder → QA 的流水线。OpenCrew 的协作模式可以映射到 harness 的角色：
+
+| Harness 角色 | OpenCrew 对应 | 协作模式中的体现 |
+|-------------|-------------|----------------|
+| **Planner** | CoS + CTO | Strategic Alignment (Pattern 2) 中 CoS 解读意图、CTO 规划路径 |
+| **Builder/Generator** | Builder | 所有模式中作为实施者/生产者 |
+| **Evaluator/QA** | CTO + Ops + KO | Code Review (Pattern 3) 中的多维评审 |
+| **Orchestrator/Harness** | CoS (Level 2) / 用户 (Level 1) | 编排模型中的编排者角色 |
+
+**关键差异**：
+
+1. **Harness 的 Evaluator 是单一的，OpenCrew 的评审是多维的**。Harness 的 GAN-inspired 模式是"Generator 产出 → Evaluator 挑战 → 迭代"。OpenCrew 的评审是"Builder 产出 → CTO 评架构 → Ops 评安全 → KO 评知识一致性"。多维评审能发现单一评审者的盲区。
+
+2. **Harness 的 Planner 是预先规划的，OpenCrew 的对齐是协商的**。Harness 的 Planner 独立写 spec，其他 Agent 执行。OpenCrew 的 Strategic Alignment 中，CTO 和 CIO 可以挑战 CoS 的解读——方案是讨论出来的，不是单方面决定的。
+
+3. **Harness 是批处理的，OpenCrew 是流式的**。Harness 中 Planner 写完 spec 文件再由 Builder 读取。OpenCrew 中 Agent 可以在 thread 中实时看到其他 Agent 的思路演化，实时调整自己的判断。
+
+### 4.2 Slack Thread 作为"Live Blackboard"
+
+Harness 设计中的核心通信模式是 **Blackboard Pattern**：Agent 写文件到共享空间，其他 Agent 读取。
+
+Slack thread 可以视为**实时版 Blackboard**：
+
+| Blackboard 概念 | 文件式（Harness） | 聊天式（OpenCrew Slack） |
+|----------------|-----------------|------------------------|
+| 写入 | Agent 写文件到 `output/` | Agent 在 thread 中发消息 |
+| 读取 | Agent 读取 `output/` 中的文件 | Agent 加载 thread 历史（`initialHistoryLimit`） |
+| 结构 | 文件名 + 文件内容 | 消息前缀 `[角色] 动作类型` + 内容 |
+| 持久化 | Git 仓库 | Slack 搜索（免费版 90 天） |
+| 版本控制 | Git diff | Thread 消息时间线 |
+| 访问控制 | 文件系统权限 | Slack 频道权限 + `requireMention` |
+
+**优势**：
+- **人可读**：Slack thread 是人类自然使用的界面。不需要"打开文件查看 Agent 在做什么"
+- **可介入**：人在 thread 中发消息等于"实时写入 Blackboard"，Agent 立即可见
+- **可搜索**：Slack 的全文搜索等于 Blackboard 的历史索引
+
+**劣势**：
+- **结构松散**：文件可以有精确的 schema，thread 消息是自由文本
+- **上下文窗口受限**：文件可以无限大，thread 受 `initialHistoryLimit` 限制
+- **持久性不足**：Slack 免费版 90 天历史限制（Harness 的 Git 是永久的）
+
+### 4.3 文件式 vs 聊天式：何时用哪个
+
+**用文件式（Harness）**：
+- 纯代码生成/修改任务（Builder 在仓库中工作）
+- 需要精确结构的产出物（配置文件、协议文档）
+- 需要 Git 版本控制的内容
+- 长期运行的自动化流水线（无人值守）
+
+**用聊天式（OpenCrew Slack）**：
+- 需要多方判断的决策（架构评审、战略对齐）
+- 需要实时人类参与的场景（事件响应、方向校正）
+- 需要跨领域视角的综合（知识综合）
+- 需要渐进式信任建设的场景（先 Level 1 再 Level 2）
+
+**混合使用**：
+- 一次 Strategic Alignment（聊天式）产出结论后 → CTO 创建 Harness spec（文件式）→ Builder 在 Harness 中执行 → 产出通过 Code Review（聊天式）评审
+- 这是"讨论决定做什么，Harness 执行怎么做，讨论验证做对了"的闭环
+
+### 4.4 Harness Evaluator 与 OpenCrew 多维评审的融合
+
+Harness 设计的最强概念之一是"Generator-Evaluator 对抗循环"：Generator 倾向于创造，Evaluator 倾向于挑战，两者对抗产出高质量结果。
+
+OpenCrew 可以将这个概念泛化：
+
+```
+[Builder 产出]
+    ↓
+[CTO 评架构] ← 对抗维度 1：设计合理性
+    ↓
+[Ops 评安全]  ← 对抗维度 2：运维风险
+    ↓
+[KO 评一致性] ← 对抗维度 3：知识冲突
+    ↓
+[综合反馈 → Builder 修订]
+    ↓
+[重复直到收敛]
+```
+
+这不是简单的"一个 Evaluator 说好或不好"，而是"多个 Evaluator 从不同角度挑战，Builder 必须同时满足所有维度"。质量上限更高，但收敛时间更长——这就是为什么防护栏中设了评审轮次上限。
+
+---
+
+## 5. Config Template
+
+### 5.1 Multi-Account Slack 配置（3 核心 Agent）
+
+以下是启用多 Agent 协作的完整配置片段。基于 research_slack_r1.md 中确认的 OpenClaw 能力。
+
+```jsonc
+{
+  "channels": {
+    "slack": {
+      // ===== 多账号配置 =====
+      // 每个 Agent 一个独立的 Slack App，拥有独立的 bot identity
+      "accounts": {
+        "cos": {
+          "botToken": "${SLACK_BOT_TOKEN_COS}",      // 环境变量引用，不明文
+          "appToken": "${SLACK_APP_TOKEN_COS}",
+          "name": "CoS"
+        },
+        "cto": {
+          "botToken": "${SLACK_BOT_TOKEN_CTO}",
+          "appToken": "${SLACK_APP_TOKEN_CTO}",
+          "name": "CTO"
+        },
+        "builder": {
+          "botToken": "${SLACK_BOT_TOKEN_BUILDER}",
+          "appToken": "${SLACK_APP_TOKEN_BUILDER}",
+          "name": "Builder"
+        }
+      },
+
+      // ===== 频道配置 =====
+      "channels": {
+        // --- 协作频道（多 Agent 讨论发生在这里） ---
+        "<COLLAB_CHANNEL_ID>": {
+          "allow": true,
+          "requireMention": true,    // 必须 @mention 才触发（循环防护）
+          "allowBots": true          // 允许处理其他 bot 的消息（协作核心）
+        },
+
+        // --- 各 Agent 专属频道（保持现有行为） ---
+        "<HQ_CHANNEL_ID>": {
+          "allow": true,
+          "requireMention": false,   // CoS 在自己频道不需要 mention
+          "allowBots": false         // 专属频道不接受 bot 消息
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
+        }
+      },
+
+      // ===== Thread 配置 =====
+      "thread": {
+        "historyScope": "thread",    // 每个 thread 独立 session
+        "inheritParent": true,       // thread 继承 root message 上下文
+        "initialHistoryLimit": 50    // 加入 thread 时加载最近 50 条消息
+      }
+    }
+  },
+
+  // ===== Agent 绑定 =====
+  "bindings": [
+    // CoS: 绑定到 cos 账号
+    {
+      "agentId": "cos",
+      "match": {
+        "channel": "slack",
+        "accountId": "cos"
+      }
+    },
+    // CTO: 绑定到 cto 账号
+    {
+      "agentId": "cto",
+      "match": {
+        "channel": "slack",
+        "accountId": "cto"
+      }
+    },
+    // Builder: 绑定到 builder 账号
+    {
+      "agentId": "builder",
+      "match": {
+        "channel": "slack",
+        "accountId": "builder"
+      }
+    }
+  ]
+}
+```
+
+### 5.2 Slack App 创建清单（每个 Agent 重复）
+
+每个 Slack App 需要以下配置：
+
+**Bot Token Scopes**（OAuth & Permissions）：
+- `channels:history` -- 读取频道历史
+- `channels:read` -- 读取频道信息
+- `chat:write` -- 发送消息
+- `chat:write.customize` -- 自定义发送者名称/图标（可选，multi-account 下不需要）
+- `users:read` -- 读取用户信息
+
+**Event Subscriptions**：
+- `message.channels` -- 接收频道消息事件
+- `app_mention` -- 接收 @mention 事件
+
+**Socket Mode**：
+- 启用 Socket Mode
+- App-level token scope: `connections:write`
+
+**注意事项**：
+- 每个 App 必须被邀请进所有需要参与的频道（专属频道 + 共享协作频道）
+- Socket Mode 连接数：3 个 App = 3 个持久 WebSocket 连接。研究报告指出这在正常范围内，但如果扩展到 5-7 个 App，建议考虑切换到 HTTP Events API 模式（每个 account 配置不同的 `webhookPath`）
+
+### 5.3 AGENTS.md 协作指令段（追加到现有 AGENTS.md）
+
+以下指令段应追加到参与协作的 Agent 的 AGENTS.md 中：
+
+```markdown
+## 多 Agent 协作协议（追加段）
+
+### 识别协作 Thread
+- 以 `COLLAB <TYPE>` 开头的 thread 是协作讨论
+- 以 `A2A <FROM>→<TO>` 开头的 thread 是委派任务
+- 在协作 thread 中，你是讨论参与者，不是任务执行者
+
+### 发言格式
+- 每条发言以 `[<你的角色>] <动作类型>` 开头
+- 结尾标注 `[STATUS: <状态>]`
+- 动作类型：Proposal / Review / Response / Diagnosis / Fix / Synthesis / Escalation
+- 状态：WAIT / NEEDS_INPUT:<谁> / CONVERGED / BLOCKED:<原因> / DECISION:<结论>
+
+### 编排纪律
+- Level 1（默认）：响应后 WAIT。不主动 @mention 其他 Agent
+- Level 2（用户指定你为编排者时）：可以 @mention 其他 Agent 推进讨论。最多 8 轮后必须收敛或升级
+- 未被 @mention 的协作 thread 消息：不响应（由 requireMention 硬约束保证）
+
+### 防护栏
+- 每条发言不超过 500 字。超过时拆分为"摘要 + 链接"
+- 每个 thread 最多参与 5 轮讨论。超过时发布 `[STATUS: CONVERGED]` 或 `Escalation`
+- 如果发现讨论偏离原始目标，发布 Escalation 提醒用户
+```
+
+### 5.4 迁移策略（从单 bot 到多 bot）
+
+```
+Phase 0: 准备（无风险）
+  - 创建 3 个 Slack App（CoS/CTO/Builder）
+  - 获取 token，配置环境变量
+  - 不修改 openclaw 配置
+
+Phase 1: 创建协作频道（低风险）
+  - 创建 #collab 频道
+  - 邀请 3 个 bot 进入 #collab
+  - 在 openclaw 配置中添加 #collab 的频道配置（allowBots + requireMention）
+  - 原有频道配置不变
+
+Phase 2: 切换 Agent 绑定（中风险，可回滚）
+  - 修改 bindings 为 multi-account 模式
+  - 保留原 bot 作为 fallback（如果用了新 App Token 后出问题）
+  - 逐个 Agent 切换：先 CTO → 验证 → 再 Builder → 验证 → 最后 CoS
+  - 每步验证：在专属频道和 #collab 分别测试响应
+
+Phase 3: 验证协作模式（低风险）
+  - 在 #collab 中手动测试 Architecture Review 模式
+  - 验证：Agent A 的消息 Agent B 是否能看到
+  - 验证：requireMention 是否正确过滤非相关消息
+  - 验证：thread 历史加载是否完整
+
+Phase 4: 启用 Level 2 编排（中风险）
+  - 在 CTO/CoS 的 AGENTS.md 中追加协作指令段
+  - 测试 Agent 编排模式
+  - 观察是否有无限循环或噪音问题
+```
+
+---
+
+## 6. Open Questions & Risks
+
+### 确认度高的发现
+
+1. **Slack multi-account 支持一切所需能力** -- `allowBots: true` + `requireMention: true` + `initialHistoryLimit` 组合已被 OpenClaw 官方文档和社区实践确认
+2. **Feishu 无法支持实时多 Agent 讨论** -- 平台限制（bot 消息不触发其他 bot 事件），这是 Feishu Open Platform 的设计决策，非 bug
+3. **Discord 等待 #11199 修复** -- 修复后机制与 Slack 类似
+
+### 需要验证的假设
+
+1. **Agent @mention 其他 bot 的可靠性**：当 CTO 的 LLM 在消息中输出 "@Builder" 时，OpenClaw 是否会将其转换为 Slack 的原生 mention 格式（`<@BOT_USER_ID>`）？如果只是纯文本 "@Builder"，接收方的 bot 可能不会识别为 mention。**这是 Level 2 编排的关键前提，需要实测。**
+
+2. **Thread 历史中 bot 消息的呈现**：当 Agent 加载 thread 历史时，其他 bot 的消息是否以可理解的方式呈现（包含发送者身份）？还是所有 bot 消息都显示为同一个"bot"？
+
+3. **Socket Mode 多连接稳定性**：3 个 Slack App 各自维持 WebSocket 连接。在网络波动时是否存在重连竞争或消息丢失？研究报告建议 5+ App 时切换 HTTP 模式。
+
+4. **`allowBots: "mentions"` 模式的可用性**：DeepWiki 分析提到这个值但官方文档未明确列出。需要确认是否可用——如果可用，它比 `allowBots: true` 更安全（只处理 @mention 自己的 bot 消息）。
+
+### 架构风险
+
+| 风险 | 影响 | 缓解 |
+|------|------|------|
+| Agent 讨论质量不够（废话多、不收敛） | 用户体验差，噪音 > 信号 | 严格的发言格式 + 轮次限制 + 持续迭代 AGENTS.md |
+| 上下文窗口不够（长讨论后 Agent 忘记早期内容） | 讨论循环、重复、遗漏 | Context Anchor 机制 + 编排者摘要 |
+| Slack 免费版 90 天历史限制 | 历史讨论不可回溯 | 重要讨论的结论同步到 Git（closeout → 仓库） |
+| 多 bot 配置复杂度高 | 上手门槛增加 | 分阶段迁移 + 详细配置文档 |
+| Level 2 编排者偏见 | 讨论结论受编排者立场影响 | 多种编排者可选（CoS 主持战略、CTO 主持技术）+ 用户随时可介入 |
+
+---
+
+## Appendix A: Quick Reference Card
+
+### 选择协作模式
+
+```
+需要做什么？
+├─ 评审技术方案 → Pattern 1: Architecture Review
+├─ 对齐新方向 → Pattern 2: Strategic Alignment
+├─ 评审已完成的工作 → Pattern 3: Code/Design Review
+├─ 处理紧急问题 → Pattern 4: Incident Response
+├─ 验证知识准确性 → Pattern 5: Knowledge Synthesis
+└─ 以上都不是 → COLLAB DISCUSS（通用讨论）
+```
+
+### 选择编排级别
+
+```
+对 Agent 判断质量有信心吗？
+├─ 不确定 → Level 1: Human Orchestrated
+├─ 有信心，但想保持监督 → Level 2: Agent Orchestrated
+└─ 完全信任 + 已验证 → Level 3: Event-Driven (FUTURE)
+```
+
+### 讨论何时结束？
+
+```
+是否达到以下任一条件？
+├─ 用户说 RESOLVED/APPROVED → 结束
+├─ 编排者发布 DECISION + CONVERGED → 结束
+├─ 所有参与者都 CONVERGED → 结束
+├─ 超过 maxDiscussionTurns → 强制结束，产出当前最佳结论
+├─ 超过 4 小时无新消息 → 隐式结束
+└─ 以上都没有 → 继续讨论
+```
+
+## Appendix B: Collaboration vs Delegation Decision Matrix
+
+| 维度 | 用 Delegation (A2A v1) | 用 Collaboration (A2A v2) |
+|------|----------------------|--------------------------|
+| 任务清晰度 | 高（DoD 明确） | 低（需要讨论才能明确） |
+| 参与者数量 | 2（指派方 + 执行方） | 3+（多方讨论） |
+| 是否需要对抗/挑战 | 否（执行即可） | 是（需要不同视角） |
+| 人类参与需求 | 低（启动 + 验收） | 高（引导讨论 + 裁决分歧） |
+| 适用任务类型 | A/P（执行型） | P/S（决策型、评审型） |
+| 平台要求 | 所有平台均支持 | Slack NOW / Discord AFTER #11199 / Feishu NOT SUPPORTED |
+
+---
+
+> 本报告基于 research_slack_r1.md、research_discord_r1.md、research_feishu_r1.md 的发现，以及 ARCHITECTURE.md、A2A_PROTOCOL.md、SYSTEM_RULES.md 的现有架构设计。所有协作模式在 Slack 上仅需配置变更即可实现，无需上游代码修改。
