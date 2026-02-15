# Skills（OpenClaw 能力包）

## 结论
- 你**不需要**在 OpenCrew 的 workspace 里创建 `skills/` 文件夹。
- Skills 是 OpenClaw 安装好的“能力包”（例如 GitHub、天气、Apple Reminders 等）。

## 怎么看你现在有哪些 skills？

```bash
openclaw skills list
openclaw skills check
```

## OpenCrew 如何用 skills？
- **CTO / Builder**：更多使用 coding/工程类能力（文件、命令行、GitHub 等）。
- **CIO / Research**：更多使用信息检索（webSearch/webFetch）与结构化输出。
- **KO / Ops**：更多使用审计与整理能力。

当某个任务需要专用能力时，在对应 agent 的频道里直接说：
> “请按 <skill-name> 的工作流执行，并在 closeout 里给出你用了哪些工具/命令。”
