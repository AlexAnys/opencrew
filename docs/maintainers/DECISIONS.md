# 决策日志

> 目的：记录关键设计决策的**原因**，避免后续迭代意外推翻原始意图。
>
> 格式：日期 · 决策 · 背景 · 理由 · 备选方案

---

## 2026-02-15 · 发布"最小增量配置片段"而非完整 openclaw.json

- **背景**：非技术用户通常已有可用的 OpenClaw 安装（auth/models/gateway 已配好）。提供完整配置文件风险很高。
- **理由**：最小增量合并更安全，且方便回滚。
- **备选**：提供一键安装脚本（已否决：影响范围大，路径脆弱）。

## 2026-02-15 · 推荐用 symlink 共享 shared/ 目录

- **决策**：推荐 `~/.openclaw/workspace-<agent>/shared -> ~/.openclaw/shared`。
- **背景**：shared 协议至关重要，但如果每个 workspace 各复制一份，很容易漂移。
- **理由**：symlink 避免重复，提高 Agent 和用户发现协议的概率。

## 2026-02-15 · 默认 KO/Ops requireMention = false，附"后续开启"建议

- **背景**：首次部署应该"照着做就能跑"，不要因为没加 @mention 就报"KO/Ops 不响应"。
- **理由**：降低新手误判为 bug 的概率。
- **备选**：默认 requireMention=true 以控制噪音（保留为可选建议）。

## 2026-02-15 · 默认开启 CoS + KO 心跳（12h 间隔）

- **背景**：主动推进是 OpenCrew 的核心承诺之一；很多用户误以为有了 `HEARTBEAT.md` 就会自动跑心跳。
- **理由**：配置片段里显式启用心跳，让协调和知识两个角色保持主动。
- **注意**：一旦任何 Agent 配了 per-agent heartbeat，OpenClaw 的行为会变化——只有配了的才跑心跳。

## 2026-02-15 · patches/ 仅面向高级用户

- **背景**：Slack thread routing / session 隔离有边界情况；对新手打 patch 风险大。
- **理由**：记录已知问题，但默认部署不依赖 patch。
